// Taken from https://crates.io/crates/uci. Modified a little

pub(crate) use crate::uci::error::{EngineError, EngineResult};
use std::fmt;
use std::io::{Read, Write};
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread::sleep;
use std::time::Duration;

pub struct Engine {
    engine: Arc<Mutex<Child>>,
    movetime: u32,
}

pub const DEFAULT_TIME: u32 = 100;

impl Engine {
    /// Create a new [`Engine`] instance.
    ///
    /// # Arguments
    ///
    /// * `path` - The path to the engine executable.
    ///
    /// # Errors
    ///
    /// * Returns an error if the engine couldn't be spawned (path is invalid, execution permission denied, etc.)
    ///
    /// [`Engine`]: struct.Engine.html
    pub fn new(path: &str) -> EngineResult<Engine> {
        let cmd = Command::new(path)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .map_err(|e| EngineError::Message(format!("ERROR_STOCKFISH: {}", e)))?;

        let engine = Engine {
            engine: Arc::new(Mutex::new(cmd)),
            movetime: DEFAULT_TIME,
        };

        if !engine.read_line()?.contains("Stockfish") {
            return Err(EngineError::Message(format!(
                "ERROR_STOCKFISH: Stockfish not found at {}",
                path
            )));
        }

        Ok(engine)
    }

    #[allow(dead_code)]
    /// Changes the amount of time the engine spends looking for a move.
    pub fn movetime(mut self, new_movetime: u32) -> Engine {
        self.movetime = new_movetime;
        self
    }

    pub fn set_movetime(&mut self, new_movetime: u32) {
        self.movetime = new_movetime;
    }

    #[allow(dead_code)]
    /// Asks the engine to play the given moves from the initial position on its internal board.
    pub fn make_moves(&self, moves: &[String]) -> EngineResult<()> {
        self.write_fmt(format_args!(
            "position startpos moves {}\n",
            moves.join(" ")
        ))
    }

    /// Asks the engine to use the position represented by the given FEN string.
    pub fn set_position(&self, fen: &str) -> EngineResult<()> {
        self.make_moves_from_position(fen, &[])
    }

    /// Asks the engine to use the position represented by the given FEN string
    /// and then play the given moves from that position.
    pub fn make_moves_from_position(&self, fen: &str, moves: &[String]) -> EngineResult<()> {
        self.write_fmt(format_args!(
            "position fen {} moves {}\n",
            fen,
            moves.join(" ")
        ))
    }

    /// Starts calculating the best moves with infinite depth.
    pub fn bestmove(&self, infinite_depth: bool) -> EngineResult<String> {
        if infinite_depth {
            self.command("go infinite")?;
            return Ok("Started searching".to_string());
        }

        self.write_fmt(format_args!("go movetime {}\n", self.movetime))?;
        loop {
            let s = self.read_line()?;
            if s.starts_with("bestmove") {
                return Ok(s.split_whitespace().nth(1).unwrap_or("").to_string());
            }
        }
    }

    #[allow(dead_code)]
    /// Gets the current best move (run only when [`bestmove`] function is running).
    pub fn current_best_move(&self) -> EngineResult<String> {
        loop {
            let s = self.read_line()?;
            if s.contains("depth") && !s.contains("currmove") {
                return Ok(s.split_whitespace().last().unwrap_or("").to_string());
            } else if s.contains("depth") && s.contains("currmove") {
                return Ok(s.split_whitespace().nth(4).unwrap_or("").to_string());
            }
        }
    }

    #[allow(dead_code)]
    /// Stops calculating and returns the current best move (run only when [`bestmove`] function is running).
    pub fn stop_search(&self) -> EngineResult<String> {
        self.write_fmt(format_args!("stop\n"))?;
        loop {
            let s = self.read_line()?;
            if s.starts_with("bestmove") {
                return Ok(s.split_whitespace().nth(1).unwrap_or("").to_string());
            }
        }
    }

    /// Sets an engine-specific option to the given value.
    pub fn set_option(&self, name: &str, value: &str) -> EngineResult<()> {
        self.write_fmt(format_args!("setoption name {} value {}\n", name, value))?;
        let response = self.read_left_output()?;
        if response.is_empty() || response.starts_with("info string") {
            Ok(())
        } else {
            Err(EngineError::UnknownOption(name.to_string()))
        }
    }

    /// Sends a command to the engine and returns the output.
    pub fn command(&self, cmd: &str) -> EngineResult<String> {
        self.write_fmt(format_args!("{}\n", cmd.trim()))?;
        sleep(Duration::from_millis(100));
        self.read_left_output()
    }

    fn read_left_output(&self) -> EngineResult<String> {
        let mut output = Vec::new();
        self.write_fmt(format_args!("isready\n"))?;
        loop {
            let line = self.read_line()?;
            match line.trim() {
                "readyok" => return Ok(output.join("\n")),
                other => output.push(other.to_string()),
            }
        }
    }

    fn write_fmt(&self, args: fmt::Arguments) -> EngineResult<()> {
        self.engine
            .lock()
            .map_err(|_| EngineError::Message("Failed to lock engine mutex".to_string()))?
            .stdin
            .as_mut()
            .ok_or_else(|| EngineError::Message("Failed to access stdin".to_string()))?
            .write_fmt(args)?;
        Ok(())
    }

    fn read_line(&self) -> EngineResult<String> {
        let mut s = String::new();
        let mut buf = [0; 1];

        loop {
            self.engine
                .lock()
                .map_err(|_| EngineError::Message("Failed to lock engine mutex".to_string()))?
                .stdout
                .as_mut()
                .ok_or_else(|| EngineError::Message("Failed to access stdout".to_string()))?
                .read_exact(&mut buf)?;
            s.push(buf[0] as char);
            if buf[0] == b'\n' {
                break;
            }
        }
        Ok(s)
    }
}

unsafe impl Sync for Engine {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let engine = Engine::new(r"./stockfish.exe").unwrap().movetime(200);
        engine.set_option("Skill Level", "15").unwrap();
        let best_move = engine.bestmove(false).unwrap();

        println!("{}", best_move);
        assert_eq!(best_move, "e2e4");
    }
}
