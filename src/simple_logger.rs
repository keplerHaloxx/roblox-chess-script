#![allow(unused)]

#[macro_export]
macro_rules! qinfo {
    ($($arg:tt)*) => {
        println!("[INFO]: {}", format!($($arg)*));
    };
}
#[macro_export]
macro_rules! qwarn {
    ($($arg:tt)*) => {
        println!("[WARN]: {}", format!($($arg)*));
    };
}

#[macro_export]
macro_rules! qerror {
    ($($arg:tt)*) => {
        println!("[ERROR]: {}", format!($($arg)*));
    };
}