mod tabs;
mod widgets;

use color_eyre::Result;
use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use ratatui::DefaultTerminal;
use tabs::{TabManager, counter::Tab1, greeting::Tab2};

fn main() -> color_eyre::Result<()> {
    color_eyre::install()?;
    let terminal = ratatui::init();
    let result = App::new().run(terminal);
    ratatui::restore();
    result
}

/// State logic of application
#[derive(Debug)]
pub struct App {
    tab_manager: TabManager,
    running: bool,
}

impl App {
    pub fn new() -> Self {
        let mut tab_manager = TabManager::new();

        tab_manager.add_tab(Tab1::new());
        tab_manager.add_tab(Tab2::new());

        Self {
            tab_manager,
            running: true,
        }
    }

    /// Main loop of application
    pub fn run(&mut self, mut terminal: DefaultTerminal) -> Result<()> {
        while self.running {
            terminal.draw(|frame| {
                self.tab_manager.render(frame);
            })?;
            self.handle_events()?;
        }
        Ok(())
    }

    fn handle_events(&mut self) -> Result<()> {
        let event = event::read()?;

        if let Event::Key(key) = event {
            if key.kind == KeyEventKind::Press {
                match (key.modifiers, key.code) {
                    // handle exiting
                    (_, KeyCode::Char('q' | 'Q'))
                    | (KeyModifiers::CONTROL, KeyCode::Char('c' | 'C')) => self.quit(),
                    _ => self.tab_manager.handle_key_event(key),
                }
            }
        }
        Ok(())
    }

    /// Set running to false to quit the application.
    fn quit(&mut self) {
        self.running = false;
    }
}
