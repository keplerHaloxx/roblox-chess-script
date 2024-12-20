use std::fmt::Display;

use termcolor::{Color, ColorChoice, ColorSpec, StandardStream, WriteColor};

pub enum CommonColors {
    Red,
    BrightGreen,
    BrightCyan,
    BrightMagenta,
    BrightBoldYellow,
}

impl From<CommonColors> for ColorSpec {
    fn from(val: CommonColors) -> Self {
        match val {
            CommonColors::Red => {
                let mut color = ColorSpec::new();
                color.set_fg(Some(Color::Red));
                color
            }
            CommonColors::BrightGreen => {
                let mut color = ColorSpec::new();
                color.set_fg(Some(Color::Green)).set_intense(true);
                color
            }
            CommonColors::BrightCyan => {
                let mut color = ColorSpec::new();
                color.set_fg(Some(Color::Cyan)).set_intense(true);
                color
            }
            CommonColors::BrightMagenta => {
                let mut color = ColorSpec::new();
                color.set_fg(Some(Color::Magenta)).set_intense(true);
                color
            }
            CommonColors::BrightBoldYellow => {
                let mut color = ColorSpec::new();
                color
                    .set_fg(Some(Color::Yellow))
                    .set_intense(true)
                    .set_bold(true);
                color
            }
        }
    }
}

pub struct Printer;
impl Printer {
    pub fn print<T: AsRef<str> + Display>(msg: T, color: CommonColors) {
        // setup
        let mut std_stream = StandardStream::stdout(ColorChoice::Auto);
        std_stream.set_color(&color.into()).unwrap();
        // printing
        print!("{}", msg.as_ref());
        // write!(&mut std_stream, "{msg}").unwrap();
        // reset styles
        std_stream.reset().unwrap();
    }

    pub fn println<T: AsRef<str> + Display>(msg: T, color: CommonColors) {
        Self::print(msg, color);
        println!();
    }
}
