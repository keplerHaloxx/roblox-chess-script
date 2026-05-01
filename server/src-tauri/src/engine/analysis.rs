use std::collections::BTreeMap;

use crate::api::types::AnalysisLine;

#[derive(Debug, Clone)]
pub struct RawAnalysisResult {
    pub best_move: String,
    pub ponder: Option<String>,
    pub lines: Vec<AnalysisLine>,
}

#[derive(Debug, Default)]
pub struct AnalysisAccumulator {
    lines: BTreeMap<u8, AnalysisLine>,
}

impl AnalysisAccumulator {
    pub fn update(&mut self, line: AnalysisLine) {
        self.lines.insert(line.rank, line);
    }

    pub fn into_lines(self) -> Vec<AnalysisLine> {
        self.lines.into_values().collect()
    }
}
