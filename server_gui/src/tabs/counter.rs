use crate::widgets::Centre;

use super::Tab;
use crossterm::event::{KeyCode, KeyEvent};
use ratatui::{
    prelude::*,
    symbols::border,
    widgets::{Block, Paragraph},
};

#[derive(Debug)]
pub struct Tab1 {
    counter: i64,
}

impl Tab1 {
    pub fn new() -> Self {
        Self { counter: 0 }
    }
}

impl Tab for Tab1 {
    fn name(&self) -> &'static str {
        "Counter"
    }

    fn render(&self, frame: &mut Frame, chunk: Rect) {
        let title = Line::from(" Counter App Tutorial ".bold());
        let instructions = Line::from(vec![
            " Decrement ".into(),
            "[A]".blue().bold(),
            " Increment ".into(),
            "[D] ".blue().bold(),
        ]);
        let block = Block::bordered()
            .title(title)
            .title_bottom(instructions)
            .border_set(border::THICK)
            .centre(frame.area());

        let counter_text = Text::from(vec![Line::from(vec![
            "Value: ".into(),
            self.counter.to_string().yellow(),
        ])]);

        let paragraph = Paragraph::new(counter_text).centered().block(block);

        frame.render_widget(paragraph, chunk);
    }

    fn handle_key_event(&mut self, key: KeyEvent) {
        match (key.modifiers, key.code) {
            // handle decrement
            (_, KeyCode::Char('a' | 'A')) => self.counter -= 1,
            // handle increment
            (_, KeyCode::Char('d' | 'D')) => self.counter += 1,
            _ => {}
        }
    }
}
