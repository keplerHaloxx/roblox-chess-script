use std::{
    io::{self, BufRead, BufReader, Write},
    path::Path,
    process::{Child, ChildStdin, Command, Stdio},
    sync::mpsc::{self, Receiver},
    thread,
    time::{Duration, Instant},
};

use thiserror::Error;

use crate::engine::{
    analysis::{AnalysisAccumulator, RawAnalysisResult},
    uci::{info_to_analysis_line, parse_bestmove_line, parse_info_line},
};

#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

#[cfg(target_os = "windows")]
const CREATE_NO_WINDOW: u32 = 0x08000000;

#[derive(Debug, Error)]
pub enum StockfishError {
    #[error("io error: {0}")]
    Io(#[from] io::Error),
    #[error("engine process has no stdin")]
    MissingStdin,
    #[error("engine process has no stdout")]
    MissingStdout,
    #[error("engine timed out waiting for {0}")]
    Timeout(&'static str),
    #[error("selected executable did not complete the UCI handshake")]
    InvalidUciEngine,
    #[error("engine exited unexpectedly")]
    EngineExited,
    #[error("engine returned no bestmove")]
    MissingBestMove,
    #[error("engine communication error: {0}")]
    Communication(String),
}

pub struct StockfishProcess {
    child: Child,
    stdin: ChildStdin,
    lines: Receiver<String>,
    pub name: Option<String>,
}

impl StockfishProcess {
    pub fn spawn(path: impl AsRef<Path>) -> Result<Self, StockfishError> {
        let mut command = Command::new(path.as_ref());

        command
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        #[cfg(target_os = "windows")]
        command.creation_flags(CREATE_NO_WINDOW);

        let mut child = command.spawn()?;

        let stdin = child.stdin.take().ok_or(StockfishError::MissingStdin)?;
        let stdout = child.stdout.take().ok_or(StockfishError::MissingStdout)?;
        let stderr = child.stderr.take();
        let (sender, receiver) = mpsc::channel::<String>();

        thread::spawn(move || {
            let reader = BufReader::new(stdout);
            for line in reader.lines() {
                match line {
                    Ok(line) => {
                        if sender.send(line).is_err() {
                            break;
                        }
                    }
                    Err(_) => break,
                }
            }
        });

        if let Some(stderr) = stderr {
            thread::spawn(move || {
                let reader = BufReader::new(stderr);
                for line in reader.lines().map_while(Result::ok) {
                    tracing::debug!(%line, "stockfish stderr");
                }
            });
        }

        let mut process = Self {
            child,
            stdin,
            lines: receiver,
            name: None,
        };

        process.handshake()?;
        Ok(process)
    }

    pub fn set_option(&mut self, name: &str, value: &str) -> Result<(), StockfishError> {
        self.write_line(&format!("setoption name {name} value {value}"))?;
        self.write_line("isready")?;
        self.wait_for_line(|line| line == "readyok", Duration::from_secs(5), "readyok")?;
        Ok(())
    }

    pub fn new_game(&mut self) -> Result<(), StockfishError> {
        self.write_line("ucinewgame")?;
        self.write_line("isready")?;
        self.wait_for_line(|line| line == "readyok", Duration::from_secs(5), "readyok")?;
        Ok(())
    }

    pub fn analyze(
        &mut self,
        fen: &str,
        depth: u32,
        max_think_time_ms: u64,
        disregard_think_time: bool,
        should_cancel: impl Fn() -> bool,
    ) -> Result<RawAnalysisResult, StockfishError> {
        self.write_line(&format!("position fen {fen}"))?;

        let command = if disregard_think_time {
            format!("go depth {depth}")
        } else {
            format!("go depth {depth} movetime {max_think_time_ms}")
        };

        self.write_line(&command)?;

        let timeout = if disregard_think_time {
            Duration::from_secs((depth as u64).saturating_mul(3).clamp(10, 90))
        } else {
            Duration::from_millis(
                max_think_time_ms
                    .saturating_add(5_000)
                    .clamp(5_000, 120_000),
            )
        };

        let deadline = Instant::now() + timeout;
        let mut accumulator = AnalysisAccumulator::default();
        let mut stop_sent = false;

        loop {
            if should_cancel() && !stop_sent {
                self.write_line("stop")?;
                stop_sent = true;
            }

            if Instant::now() >= deadline {
                let _ = self.write_line("stop");
                return Err(StockfishError::Timeout("bestmove"));
            }

            let remaining = deadline
                .saturating_duration_since(Instant::now())
                .min(Duration::from_millis(100));
            match self.lines.recv_timeout(remaining) {
                Ok(line) => {
                    tracing::debug!(%line, "uci");
                    if let Some(info) = parse_info_line(&line) {
                        accumulator.update(info_to_analysis_line(info));
                    } else if let Some((best_move, ponder)) = parse_bestmove_line(&line) {
                        return Ok(RawAnalysisResult {
                            best_move,
                            ponder,
                            lines: accumulator.into_lines(),
                        });
                    }
                }
                Err(mpsc::RecvTimeoutError::Timeout) => continue,
                Err(mpsc::RecvTimeoutError::Disconnected) => {
                    return Err(StockfishError::EngineExited)
                }
            }
        }
    }

    pub fn write_line(&mut self, command: &str) -> Result<(), StockfishError> {
        tracing::debug!(command, "sending uci command");
        writeln!(self.stdin, "{command}")?;
        self.stdin.flush()?;
        Ok(())
    }

    pub fn try_kill(&mut self) {
        let _ = self.write_line("quit");
        let _ = self.child.kill();
        let _ = self.child.wait();
    }

    fn handshake(&mut self) -> Result<(), StockfishError> {
        self.write_line("uci")?;
        let mut saw_uciok = false;
        let deadline = Instant::now() + Duration::from_secs(5);

        while Instant::now() < deadline {
            match self.lines.recv_timeout(Duration::from_millis(100)) {
                Ok(line) => {
                    if let Some(name) = line.strip_prefix("id name ") {
                        self.name = Some(name.trim().to_string());
                    }
                    if line.trim() == "uciok" {
                        saw_uciok = true;
                        break;
                    }
                }
                Err(mpsc::RecvTimeoutError::Timeout) => continue,
                Err(mpsc::RecvTimeoutError::Disconnected) => {
                    return Err(StockfishError::EngineExited)
                }
            }
        }

        if !saw_uciok {
            return Err(StockfishError::InvalidUciEngine);
        }

        self.write_line("isready")?;
        self.wait_for_line(|line| line == "readyok", Duration::from_secs(5), "readyok")?;
        Ok(())
    }

    fn wait_for_line(
        &mut self,
        predicate: impl Fn(&str) -> bool,
        timeout: Duration,
        label: &'static str,
    ) -> Result<String, StockfishError> {
        let deadline = Instant::now() + timeout;
        while Instant::now() < deadline {
            let remaining = deadline
                .saturating_duration_since(Instant::now())
                .min(Duration::from_millis(100));
            match self.lines.recv_timeout(remaining) {
                Ok(line) if predicate(line.trim()) => return Ok(line),
                Ok(line) => tracing::debug!(%line, "uci while waiting"),
                Err(mpsc::RecvTimeoutError::Timeout) => continue,
                Err(mpsc::RecvTimeoutError::Disconnected) => {
                    return Err(StockfishError::EngineExited)
                }
            }
        }
        Err(StockfishError::Timeout(label))
    }
}

impl Drop for StockfishProcess {
    fn drop(&mut self) {
        self.try_kill();
    }
}
