// Taken from https://crates.io/crates/uci. Modified a little

use std;
use std::convert::From;
use std::fmt;
use std::io;

/// The error type for any errors encountered with the engine.
#[derive(Debug)]
pub enum EngineError {
    /// Wrapper around any io errors encountered while trying to communicate with the engine.
    Io(io::Error),

    /// Engine doesn't recognize the specified option.
    UnknownOption(String),
    Message(String),
}

impl fmt::Display for EngineError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            EngineError::Io(ref err) => write!(f, "IO error: {}", err),
            EngineError::UnknownOption(ref option) => {
                write!(f, "No such option: '{}'", option.as_str())
            },
            EngineError::Message(ref msg) => {
                write!(f, "Error: '{}'", msg.as_str())
            }
        }
    }
}

impl From<io::Error> for EngineError {
    fn from(err: io::Error) -> EngineError {
        EngineError::Io(err)
    }
}

/// A Result type which uses [`EngineError`] for representing errors.
///
/// [`EngineError`]: enum.EngineError.html
pub type EngineResult<T> = std::result::Result<T, EngineError>;
