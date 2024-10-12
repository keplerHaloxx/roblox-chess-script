pub mod styled {
    // #[macro_export]
    macro_rules! styled_vec_print {
        ($msg:expr, $styles:expr) => {{
            for style in $styles.iter() {
                print!("{}", style);
            }
            print!("{}{color_reset}{style_reset}", $msg);
        }};

        ($msg:expr) => {{
            print!("{}", $msg);
        }};
    }

    #[allow(unused_macros)]
    macro_rules! styled_vec_println {
        ($msg:expr, $styles:expr) => {{
            styled_vec_print!($msg, $styles);
            println!();
        }};

        ($msg:expr) => {{
            println!("{}", $msg);
        }};
    }

    macro_rules! styled_print {
        ($msg:expr, $($style:expr),*) => {
            {
                $( print!("{}", $style); )*
                print!("{}{color_reset}{style_reset}", $msg);
            }
        };

        ($msg:expr) => {
            {
                print!("{}", $msg);
            }
        };
    }

    macro_rules! styled_println {
        ($msg:expr, $($style:expr),*) => {
            {
                crate::macros::styled::styled_print!($msg, $($style),*);
                println!();
                // $( print!("{}", $style); )*
                // println!("{}{color_reset}{style_reset}", $msg);
            }
        };

        ($msg:expr) => {
            {
                // println!("{}", $msg);
                styled_print!($msg);
                println!();
            }
        };
    }

    /// A quicker way of doing `format!()`
    macro_rules! f {
    ($($arg:tt)*) => {
        format!($($arg)*)
    };
}

    pub(crate) use f;
    pub(crate) use styled_print;
    pub(crate) use styled_println;
    pub(crate) use styled_vec_print;
    #[allow(unused_imports)]
    pub(crate) use styled_vec_println;
}