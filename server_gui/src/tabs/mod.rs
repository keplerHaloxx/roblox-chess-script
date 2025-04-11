use crossterm::event::{KeyCode, KeyEvent};
use ratatui::{
    Frame,
    layout::{Constraint, Layout, Rect},
    style::{Style, Stylize},
    symbols::border,
    text::Line,
    widgets::{Block, Tabs},
};
use std::fmt::Debug;

pub mod counter;
pub mod greeting;

pub trait Tab: Debug {
    fn name(&self) -> &'static str;
    fn render(&self, frame: &mut Frame, chunk: Rect);
    fn handle_key_event(&mut self, key: KeyEvent);
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
        let chunks = Layout::default()
            .direction(ratatui::layout::Direction::Vertical)
            .constraints([Constraint::Length(3), Constraint::Min(0)])
            .split(frame.area());

        let tabs = Tabs::new(self.tab_names())
            .block(
                Block::bordered()
                    .title("Tabs")
                    .border_set(border::PLAIN)
                    .title_bottom(
                        Line::from(vec![" Quit ".into(), "<Q> ".blue().bold()]).right_aligned(),
                    ),
            )
            .highlight_style(Style::default().yellow())
            .select(self.current_tab);
        frame.render_widget(tabs, chunks[0]);

        if let Some(tab) = self.tabs.get(self.current_tab) {
            tab.render(frame, chunks[1]);
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
