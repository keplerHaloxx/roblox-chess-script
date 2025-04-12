use crossterm::event::{KeyCode, KeyModifiers};
use ratatui::{
    style::{Color, Style, Stylize},
    text::{Line, Span},
};

#[derive(Debug, Clone)]
pub struct KeyBinding {
    pub description: String,
    pub key: KeyCode,
    pub modifiers: Option<KeyModifiers>,
}

impl KeyBinding {
    pub fn new(description: impl Into<String>, key: KeyCode) -> Self {
        Self {
            description: description.into(),
            key,
            modifiers: None,
        }
    }

    pub fn with_modifiers(mut self, modifiers: KeyModifiers) -> Self {
        self.modifiers = Some(modifiers);
        self
    }

    pub fn to_line(&self) -> Line {
        let mut parts = vec![
            Span::styled(&self.description, Style::default()).bg(Color::DarkGray),
            Span::styled(" ", Style::default()),
        ];

        if let Some(modifiers) = &self.modifiers {
            if modifiers.contains(KeyModifiers::CONTROL) {
                parts.push(Span::styled("Ctrl+", Style::default().dark_gray()));
            }
            if modifiers.contains(KeyModifiers::SHIFT) {
                parts.push(Span::styled("Shift+", Style::default().dark_gray()));
            }
            if modifiers.contains(KeyModifiers::ALT) {
                parts.push(Span::styled("Alt+", Style::default().dark_gray()));
            }
        }

        let key_text = match self.key {
            KeyCode::Char(c) => c.to_string(),
            KeyCode::Left => "←".to_string(),
            KeyCode::Right => "→".to_string(),
            KeyCode::Up => "↑".to_string(),
            KeyCode::Down => "↓".to_string(),
            KeyCode::Enter => "Enter".to_string(),
            KeyCode::Esc => "Esc".to_string(),
            KeyCode::Tab => "Tab".to_string(),
            KeyCode::Backspace => "Backspace".to_string(),
            KeyCode::Delete => "Delete".to_string(),
            KeyCode::Insert => "Insert".to_string(),
            KeyCode::Home => "Home".to_string(),
            KeyCode::End => "End".to_string(),
            KeyCode::PageUp => "PgUp".to_string(),
            KeyCode::PageDown => "PgDn".to_string(),
            _ => format!("{:?}", self.key),
        };

        parts.push(Span::styled(key_text, Style::default().dim()));

        Line::from(parts)
    }
}

#[derive(Debug, Default)]
pub struct KeyBindings {
    bindings: Vec<KeyBinding>,
}

impl KeyBindings {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add(&mut self, binding: KeyBinding) {
        self.bindings.push(binding);
    }

    pub fn to_footer(&self) -> Line {
        let mut parts = vec![Span::styled(" ", Style::default())];
        for (i, binding) in self.bindings.iter().enumerate() {
            if i > 0 {
                parts.push(Span::styled(" ", Style::default()));
            }
            parts.extend(binding.to_line().spans);

            if i != self.bindings.len() - 1 {
                parts.push(" |".into());
            }
        }
        Line::from(parts)
    }
}
