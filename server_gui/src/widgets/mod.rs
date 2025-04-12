use ratatui::{
    layout::Rect,
    widgets::{Block, Padding},
};

// makes it easier to centre content inside a block without having to write out the whole padding struct
pub trait Centre {
    fn centre(self, area: Rect) -> Self;
}
impl Centre for Block<'_> {
    fn centre(self, area: Rect) -> Self {
        self.padding(Padding::new(0, 0, area.height / 2 - 3, 0))
    }
}
