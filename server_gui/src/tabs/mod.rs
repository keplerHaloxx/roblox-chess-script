use crossterm::event::{KeyCode, KeyEvent};
use ratatui::{
    Frame,
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Modifier, Style, Stylize},
    symbols::border,
    text::Line,
    widgets::{Block, Borders, Tabs},
};
use std::fmt::Debug;

use crate::keybindings::KeyBindings;

pub mod counter;
pub mod greeting;

pub trait Tab: Debug {
    fn name(&self) -> &'static str;
    fn render(&self, frame: &mut Frame, chunk: Rect, footer: Rect);
    fn handle_key_event(&mut self, key: KeyEvent);
    fn keybindings(&self) -> KeyBindings;
}

#[derive(Debug)]
pub struct TabManager {
    pub tabs: Vec<Box<dyn Tab>>,
    pub current_tab: usize,
}

impl TabManager {
    pub fn new() -> Self {
        Self {
            tabs: Vec::new(),
            current_tab: 0,
        }
    }

    pub fn add_tab<T: Tab + 'static>(&mut self, tab: T) {
        self.tabs.push(Box::new(tab));
    }

    pub fn tab_names(&self) -> Vec<String> {
        self.tabs.iter().map(|tab| tab.name().to_string()).collect()
    }

    pub fn render(&self, frame: &mut Frame) {
        // outer layer
        let main_layout = Layout::new(
            Direction::Vertical,
            [
                Constraint::Length(1),
                Constraint::Min(1),
                Constraint::Length(1),
            ],
        )
        .split(frame.area());

        // "roblox-chess-script" header
        let header = Block::new()
            .title(Line::from(vec![
                "*".into(),
                " roblox-chess-script ".light_yellow(),
                "*".into(),
            ]))
            .add_modifier(Modifier::BOLD)
            .add_modifier(Modifier::ITALIC)
            .title_alignment(Alignment::Center)
            .borders(Borders::TOP)
            .border_style(Style::default().light_blue());
        frame.render_widget(header, main_layout[0]);

        // inner layer
        let inner_layer = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(3), Constraint::Min(0)])
            .split(main_layout[1]);

        let tabs = Tabs::new(self.tab_names())
            .block(
                Block::bordered()
                    .title("Tabs")
                    .border_set(border::THICK)
                    .title_bottom(
                        Line::from(vec![
                            " Left ".blue().bold(),
                            "and ".into(),
                            "Right ".blue().bold(),
                            "arrow keys to change tabs ".into(),
                            "| Quit ".into(),
                            "[Q] ".blue().bold(),
                        ])
                        .right_aligned(),
                    ),
            )
            .highlight_style(Style::default().yellow())
            .select(self.current_tab);
        frame.render_widget(tabs, inner_layer[0]);

        if let Some(tab) = self.tabs.get(self.current_tab) {
            tab.render(frame, inner_layer[1], main_layout[2]);

            // Render keybindings in footer
            let keybindings = tab.keybindings();
            frame.render_widget(keybindings.to_footer(), main_layout[2]);
        }
    }

    pub fn handle_key_event(&mut self, key: KeyEvent) {
        match (key.modifiers, key.code) {
            (_, KeyCode::Right) => self.next_tab(),
            (_, KeyCode::Left) => self.previous_tab(),
            _ => {
                if let Some(tab) = self.tabs.get_mut(self.current_tab) {
                    tab.handle_key_event(key);
                }
            }
        }
    }

    pub fn next_tab(&mut self) {
        if self.tabs.is_empty() {
            return;
        }

        self.current_tab = (self.current_tab + 1) % self.tabs.len(); // roll back tabs
    }

    pub fn previous_tab(&mut self) {
        if self.tabs.is_empty() {
            return;
        }

        self.current_tab = if self.current_tab == 0 {
            self.tabs.len() - 1 // roll back tabs
        } else {
            self.current_tab - 1
        };
    }
}
