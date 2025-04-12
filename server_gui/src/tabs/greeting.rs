use crate::keybindings::KeyBindings;
use crate::widgets::Centre;

use super::Tab;
use ratatui::{
    prelude::*,
    symbols::border,
    widgets::{Block, Paragraph},
};

#[derive(Debug)]
pub struct Tab2;

impl Tab2 {
    pub fn new() -> Self {
        Self
    }
}

impl Tab for Tab2 {
    fn name(&self) -> &'static str {
        "Greeting"
    }

    fn render(&self, frame: &mut Frame, chunk: Rect, _: Rect) {
        let title = Line::from(" Button Testing ".bold());
        let block = Block::bordered()
            .title(title)
            .border_set(border::PLAIN)
            .centre(frame.area());

        let button = Paragraph::new("Hello!".bold().light_blue())
            .centered()
            .block(block);

        frame.render_widget(button, chunk);
    }

    fn handle_key_event(&mut self, _key: crossterm::event::KeyEvent) {}

    fn keybindings(&self) -> KeyBindings {
        KeyBindings::new()
    }
}
