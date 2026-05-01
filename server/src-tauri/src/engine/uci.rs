use crate::api::types::AnalysisLine;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum UciScore {
    Cp(i32),
    Mate(i32),
}

#[derive(Debug, Clone)]
pub struct ParsedInfo {
    pub depth: Option<u32>,
    pub multipv: u8,
    pub score: Option<UciScore>,
    pub pv: Vec<String>,
}

pub fn parse_info_line(line: &str) -> Option<ParsedInfo> {
    if !line.starts_with("info ") {
        return None;
    }

    let parts: Vec<&str> = line.split_whitespace().collect();
    let mut depth = None;
    let mut multipv = 1_u8;
    let mut score = None;
    let mut pv = Vec::new();

    let mut i = 1;
    while i < parts.len() {
        match parts[i] {
            "depth" if i + 1 < parts.len() => {
                depth = parts[i + 1].parse::<u32>().ok();
                i += 2;
            }
            "multipv" if i + 1 < parts.len() => {
                multipv = parts[i + 1].parse::<u8>().unwrap_or(1).max(1);
                i += 2;
            }
            "score" if i + 2 < parts.len() => {
                score = match parts[i + 1] {
                    "cp" => parts[i + 2].parse::<i32>().ok().map(UciScore::Cp),
                    "mate" => parts[i + 2].parse::<i32>().ok().map(UciScore::Mate),
                    _ => None,
                };
                i += 3;
            }
            "pv" => {
                pv = parts[i + 1..].iter().map(|s| s.to_string()).collect();
                break;
            }
            _ => i += 1,
        }
    }

    Some(ParsedInfo {
        depth,
        multipv,
        score,
        pv,
    })
}

pub fn parse_bestmove_line(line: &str) -> Option<(String, Option<String>)> {
    let parts: Vec<&str> = line.split_whitespace().collect();
    if parts.first().copied() != Some("bestmove") || parts.len() < 2 {
        return None;
    }

    let best_move = parts[1].to_string();
    let ponder = parts
        .windows(2)
        .find(|window| window[0] == "ponder")
        .map(|window| window[1].to_string());

    Some((best_move, ponder))
}

pub fn info_to_analysis_line(info: ParsedInfo) -> AnalysisLine {
    let (score_cp, mate) = match info.score {
        Some(UciScore::Cp(cp)) => (Some(cp), None),
        Some(UciScore::Mate(mate)) => (None, Some(mate)),
        None => (None, None),
    };

    let move_uci = info.pv.first().cloned();

    AnalysisLine {
        rank: info.multipv,
        depth: info.depth,
        move_uci,
        score_cp,
        mate,
        pv: info.pv,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_info_line() {
        let parsed =
            parse_info_line("info depth 12 seldepth 18 multipv 2 score cp 31 nodes 1 pv e2e4 e7e5")
                .unwrap();

        assert_eq!(parsed.depth, Some(12));
        assert_eq!(parsed.multipv, 2);
        assert_eq!(parsed.score, Some(UciScore::Cp(31)));
        assert_eq!(parsed.pv, vec!["e2e4", "e7e5"]);
    }

    #[test]
    fn parses_bestmove() {
        let parsed = parse_bestmove_line("bestmove e2e4 ponder e7e5").unwrap();
        assert_eq!(parsed.0, "e2e4");
        assert_eq!(parsed.1.as_deref(), Some("e7e5"));
    }
}
