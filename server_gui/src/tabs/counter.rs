use crate::keybindings::{KeyBinding, KeyBindings};
use crate::widgets::Centre;

use super::Tab;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
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

    fn render(&self, frame: &mut Frame, chunk: Rect, _: Rect) {
        let title = Line::from(" Counter App Tutorial ".bold());
        let block = Block::bordered()
            .title(title)
            .border_set(border::PLAIN)
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

            (KeyModifiers::CONTROL, KeyCode::Char('p' | 'P')) => self.counter += 100,
            _ => {}
        }
    }

    fn keybindings(&self) -> KeyBindings {
        let mut bindings = KeyBindings::new();
        bindings.add(KeyBinding::new("Decrement", KeyCode::Char('A')));
        bindings.add(KeyBinding::new("Increment", KeyCode::Char('D')));
        bindings.add(
            KeyBinding::new("Testing", KeyCode::Char('P')).with_modifiers(KeyModifiers::CONTROL),
        );
        bindings
    }
}
