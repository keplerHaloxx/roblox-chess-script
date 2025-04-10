// - Taken from https://crates.io/crates/uci. Modified a little

use std::process::{Child, Command, Stdio};

use std::io::Write;
use std::io::{self, Read};

use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use std::{fmt, sync};

use log::{debug, info};

use self::EngineError::{Io, UnknownOption};

#[derive(Clone)]
pub struct Engine {
    engine: Arc<Mutex<Child>>,
    movetime: u32,
}

const DEFAULT_TIME: u32 = 100;

impl Engine {
    /// Create a new [`Engine`] instance.
    ///
    /// # Arguments
    ///
    /// * `path` - The path to the engine executable.
    ///
    /// # Panics
    ///
    /// * Panics if the engine couldn't be spawned (path is invalid, execution permission denied, etc.)
    ///
    /// # Errors
    ///
    /// Returns an `EngineError` if there's an errors while communicating with the engine.
    ///
    /// [`Engine`]: struct.Engine.html
    pub fn new(path: &str) -> Result<Engine> {

        let path = path.to_string(); // Move ownership of path into the thread
        let (sender, receiver) = sync::mpsc::channel();

        // Spawn a thread for the entire initialization process
        thread::spawn(move || {
            // Create the subprocess
            let cmd = Command::new(path)
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .spawn();

            if let Err(err) = cmd {
                let _ = sender.send(Err(EngineError::Io(err)));
                return;
            }

            let process = cmd.unwrap();
            let engine = Engine {
                engine: Arc::new(Mutex::new(process)),
                movetime: DEFAULT_TIME,
            };

            // Execute the UCI command
            let uci_result = engine.command("uci");
            match uci_result {
                Ok(response) => {
                    if !response.trim_end().ends_with("uciok") {
                        let _ = sender.send(Err(EngineError::Io(io::Error::new(
                            io::ErrorKind::InvalidInput,
                            "The selected file does not appear to be a UCI-compatible engine.",
                        ))));
                        println!("{}", response);
                    } else {
                        let _ = sender.send(Ok(engine));
                    }
                }
                Err(err) => {
                    let _ = sender.send(Err(err));
                }
            }
        });

        // Wait for the result with a timeout
        match receiver.recv_timeout(Duration::from_secs(3)) {
            Ok(result) => result,
            Err(_) => Err(EngineError::Io(io::Error::new(
                io::ErrorKind::TimedOut,
                "Engine initialization timed out.",
            ))),
        }
    }

    /// Changes the amount of time the engine spends looking for a move
    ///
    /// # Arguments
    ///
    /// * `new_movetime` - New timelimit in milliseconds
    pub fn movetime(&mut self, new_movetime: u32) {
        self.movetime = new_movetime;
    }

    /// Asks the engine to play the given moves from the initial position on it's internal board.
    ///
    /// # Arguments
    ///
    /// * `moves` - A list of moves for the engine to play. Uses Coordinate notation
    ///
    /// # Errors
    ///
    /// Returns `EngineError` if there's an error while communicating with the engine.
    ///
    /// # Examples
    ///
    /// ```
    /// let engine = uci::Engine::new("stockfish").unwrap();
    /// let moves = vec!["e2e4".to_string(), "e7e5".to_string()];
    /// engine.make_moves(&moves).unwrap();
    /// ```
    #[allow(unused)]
    pub fn make_moves(&self, moves: &[String]) -> Result<()> {
        self.write_fmt(format_args!(
            "position startpos moves {}\n",
            moves.join(" ")
        ))
    }

    /// Asks the engine to use the position represented by the given FEN string
    ///
    /// # Errors
    ///
    ///
    ///
    /// # Examples
    ///
    /// ```
    /// let engine = uci::Engine::new("stockfish").unwrap();
    /// engine.set_position("2k4R/8/3K4/8/8/8/8/8 b - - 0 1").unwrap();
    /// assert_eq!(engine.bestmove().unwrap(), "c8b7");
    /// ```
    pub fn set_position(&self, fen: &str) -> Result<()> {
        let moves: Vec<String> = vec![];
        self.make_moves_from_position(fen, &moves)
    }

    /// Asks the engine to use the position represented by the given FEN string
    /// and then play the given moves from that position
    ///
    /// # Errors
    ///
    /// Returns an `EngineError` if there's an error while communicating with the engine.
    pub fn make_moves_from_position(&self, fen: &str, moves: &[String]) -> Result<()> {
        self.write_fmt(format_args!(
            "position fen {} moves {}\n",
            fen,
            moves.join(" ")
        ))
    }

    /// Returns the best move in the current position according to the engine
    /// # Errors
    /// Returns an error if the engine is not ready to return a move
    #[allow(dead_code)]
    pub fn bestmove(&self) -> Result<String> {
        self.write_fmt(format_args!("go movetime {}\n", self.movetime))?;
        loop {
            let s = self.read_line()?;
            debug!("{}", s);
            if s.starts_with("bestmove") {
                return Ok(s.split(' ').collect::<Vec<&str>>()[1].trim().to_string());
            }
        }
    }

    /// Same as `bestmove` but it accepts a depth parameter
    pub fn bestmove_depth(&self, depth: u32, disregard_movetime: bool) -> Result<String> {
        if disregard_movetime {
            let _ = self.write_fmt(format_args!("go depth {}\n", depth));
        } else {
            let _ = self.write_fmt(format_args!(
                "go depth {} movetime {}\n",
                depth, self.movetime
            ));
        }

        loop {
            let s = self.read_line()?;
            debug!("{}", s);
            if s.starts_with("bestmove") {
                return Ok(s.split(' ').collect::<Vec<&str>>()[1].trim().to_string());
            }
        }
    }

    /// Sets an engine specific option to the given value
    ///
    /// # Arguments
    ///
    /// * `name`  - Name of the option
    /// * `value` - New value for the option
    ///
    /// # Errors
    ///
    /// Returns an `EngineError` if the engine doesn't support the option
    ///
    /// # Examples
    ///
    /// ```
    /// let engine = uci::Engine::new("stockfish").unwrap();
    /// engine.set_option("Skill Level", "5").unwrap();
    /// ```
    pub fn set_option(&self, name: &str, value: &str) -> Result<()> {
        self.write_fmt(format_args!("setoption name {name} value {value}\n"))?;
        let binding = self.read_left_output()?;
        let msg = binding.trim();

        // when changing threads option, stockfish outputs a message which violates this and errors.
        // so i'm also checking if it starts with 'info string'
        if msg.is_empty() || msg.starts_with("info string") {
            Ok(())
        } else {
            Err(EngineError::UnknownOption(name.to_string()))
        }
    }

    /// Sends a command to the engine and returns the output
    ///
    /// # Errors
    ///
    /// Returns an `EngineError` if there was an error while sending the command to the engine
    ///
    /// # Examples
    ///
    /// ```
    /// let engine = uci::Engine::new("stockfish").unwrap();
    /// let analysis = engine.command("go depth 10").unwrap();
    /// println!("{}", analysis);
    /// ```
    pub fn command(&self, cmd: &str) -> Result<String> {
        self.write_fmt(format_args!("{}\n", cmd.trim()))?;
        thread::sleep(Duration::from_millis(100));
        self.read_left_output()
    }

    /// Sends a command to the engine and waits for specified duration before returning the output
    ///
    /// # Errors
    ///
    /// Returns an `EngineError` if there was an error while sending the command to the engine
    ///
    /// # Examples
    ///
    /// ```
    /// # use std::time::Duration;
    /// let engine = uci::Engine::new("stockfish").unwrap();
    /// let analysis = engine.command_with_duration("go depth 10", Duration::from_millis(200)).unwrap();
    /// println!("{}", analysis);
    /// ```
    #[allow(unused)]
    pub fn command_with_duration(&self, cmd: &str, duration: Duration) -> Result<String> {
        self.write_fmt(format_args!("{}\n", cmd.trim()))?;
        thread::sleep(duration);
        self.read_left_output()
    }

    /// Sends a command to the engine and waits untill the engine returns a
    /// line starting with the specified prefix
    ///
    /// # Errors
    ///
    /// Returns an `EngineError` if there was an error while sending the command to the engine
    ///
    /// # Examples
    ///
    /// ```
    /// let engine = uci::Engine::new("stockfish").unwrap();
    /// let analysis = engine.command_and_wait_for("go depth 10", "bestmove").unwrap();
    /// println!("{}", analysis);
    /// ```
    #[allow(unused)]
    pub fn command_and_wait_for(&self, cmd: &str, prefix: &str) -> Result<String> {
        self.write_fmt(format_args!("{}\n", cmd.trim()))?;
        self.read_till_prefix(prefix)
    }

    fn read_left_output(&self) -> Result<String> {
        let mut s: Vec<String> = vec![];

        self.write_fmt(format_args!("isready\n"))?;
        loop {
            let next_line = self.read_line()?;
            match next_line.trim() {
                "readyok" => return Ok(s.join("\n")),
                other => s.push(other.to_string()),
            }
        }
    }

    fn read_till_prefix(&self, prefix: &str) -> Result<String> {
        let mut result: Vec<String> = vec![];

        loop {
            let next_line = self.read_line()?;
            result.push(next_line);
            if result.last().unwrap().starts_with(prefix) {
                return Ok(result.join("\n"));
            }
        }
    }

    fn write_fmt(&self, args: fmt::Arguments) -> Result<()> {
        info!("Command: {:?}", fmt::format(args));
        self.engine
            .lock()
            .map_err(|_| EngineError::Message("Failed to lock engine mutex".to_string()))?
            .stdin
            .as_mut()
            .unwrap()
            .write_fmt(args)?;
        Ok(())
    }

    fn read_line(&self) -> Result<String> {
        let mut s = String::new();
        let mut buf: Vec<u8> = vec![0];

        loop {
            let _ = self
                .engine
                .lock()
                .map_err(|_| EngineError::Message("Failed to lock engine mutex".to_string()))?
                .stdout
                .as_mut()
                .unwrap()
                .read(&mut buf)?;
            s.push(buf[0] as char);
            if buf[0] == b'\n' {
                break;
            }
        }
        Ok(s)
    }
}

unsafe impl Sync for Engine {}

/// The error type for any errors encountered with the engine.
#[derive(Debug)]
pub enum EngineError {
    /// Wrapper around any io errors encountered while trying to communicate with the engine.
    Io(io::Error),

    /// Engine doesn't recognize the specified option.
    UnknownOption(String),

    /// Simple message error.
    Message(String),
}

impl fmt::Display for EngineError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            Io(ref err) => write!(f, "IO error: {err}"),
            UnknownOption(ref option) => write!(f, "No such option: '{option}'"),
            EngineError::Message(ref msg) => write!(f, "Error: {msg}"),
        }
    }
}

impl From<io::Error> for EngineError {
    fn from(err: io::Error) -> EngineError {
        Io(err)
    }
}

/// A Result type which uses [`EngineError`] for representing errors.
///
/// [`EngineError`]: enum.EngineError.html
pub type Result<T> = std::result::Result<T, EngineError>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let mut engine = Engine::new("stockfish").unwrap();
        engine.movetime(200);
        engine.set_option("Skill Level", "15").unwrap();
        let t = engine.bestmove().unwrap();

        println!("{t}");
    }
}
