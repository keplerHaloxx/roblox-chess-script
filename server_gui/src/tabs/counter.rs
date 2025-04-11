use super::Tab;
use crossterm::event::{KeyCode, KeyEvent};
use ratatui::{
    prelude::*,
    symbols::border,
    widgets::{Block, Padding, Paragraph},
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
            "<Left>".blue().bold(),
            " Increment ".into(),
            "<Right>".blue().bold(),
        ]);
        let block = Block::bordered()
            .title(title)
            .title_bottom(instructions)
            .border_set(border::THICK)
            .padding(Padding::new(0, 0, frame.area().height / 2 - 2, 0));

        let counter_text = Text::from(vec![Line::from(vec![
            "Value: ".into(),
            self.counter.to_string().yellow(),
        ])]);

        let paragraph = Paragraph::new(counter_text).centered().block(block);

        frame.render_widget(paragraph, chunk);
    }

    fn handle_key_event(&mut self, key: KeyEvent) {
        match (key.modifiers, key.code) {
            // handle increment
            (_, KeyCode::Right) => self.counter += 1,
            // handle decrement
            (_, KeyCode::Left) => self.counter -= 1,
            _ => {}
        }
    }
}
