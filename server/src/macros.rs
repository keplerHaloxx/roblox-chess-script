pub mod styled {
    /// A quicker way of doing `format!()`
    macro_rules! f {
        ($($arg:tt)*) => {
            format!($($arg)*)
        };
    }

    pub(crate) use f;
}
