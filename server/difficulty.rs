use serde::Serialize;

use crate::api::types::AnalysisLine;

/// Difficulty is intended to estimate how long a human-like bot should hesitate
/// before making a move.
///
/// Important scoring principle:
/// - Many similarly good moves should make the position easier/faster.
/// - One clearly best move among plausible alternatives should make it harder/slower.
///
/// This avoids treating the normal starting position as hard just because many
/// opening moves have similar Stockfish evaluations.
#[derive(Debug, Clone, Serialize)]
pub struct Difficulty {
    pub score: f64,
    pub label: DifficultyLabel,
    pub recommended_delay_ms: u64,
    pub reason: String,

    pub legal_move_count: usize,
    pub in_check: bool,

    /// Number of engine candidate moves actually used in the calculation.
    pub analysed_moves: usize,

    /// Moves within 25cp of the best move.
    pub excellent_moves: usize,

    /// Moves within 60cp of the best move.
    pub good_moves: usize,

    /// Moves within 120cp of the best move.
    pub playable_moves: usize,

    /// Candidate moves that look plausible but lose meaningful value.
    pub trap_moves: usize,

    /// Candidate moves that lose severe value compared with the best move.
    pub blunder_moves: usize,

    /// Centipawn loss from best move to second-best move.
    pub best_second_loss_cp: Option<i32>,

    /// Largest centipawn loss among analysed candidate moves.
    pub max_top_loss_cp: Option<i32>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum DifficultyLabel {
    Trivial,
    Easy,
    Medium,
    Hard,
    VeryHard,
}

#[derive(Debug, Clone)]
pub struct DifficultyInput {
    pub legal_move_count: usize,
    pub in_check: bool,

    /// Expected to be Stockfish MultiPV lines ordered by rank.
    ///
    /// score_cp must be normalized so that higher is better for the side to move.
    /// If your Stockfish adapter returns scores from White's perspective, normalize
    /// before calling calculate().
    pub lines: Vec<AnalysisLine>,

    /// Kept for backwards compatibility with the old call site.
    /// The new algorithm uses fixed move-loss buckets instead.
    pub candidate_threshold_cp: i32,

    pub min_delay_ms: u64,
    pub max_delay_ms: u64,
}

pub fn calculate(input: DifficultyInput) -> Difficulty {
    let mut reasons = Vec::new();

    if input.legal_move_count <= 1 {
        return Difficulty {
            score: 0.0,
            label: DifficultyLabel::Trivial,
            recommended_delay_ms: input.min_delay_ms,
            reason: "Only one legal move is available, so the move is forced.".to_string(),
            legal_move_count: input.legal_move_count,
            in_check: input.in_check,
            analysed_moves: input.lines.len(),
            excellent_moves: 1,
            good_moves: 1,
            playable_moves: 1,
            trap_moves: 0,
            blunder_moves: 0,
            best_second_loss_cp: None,
            max_top_loss_cp: None,
        };
    }

    let mut cp_scores: Vec<(u8, i32)> = input
        .lines
        .iter()
        .filter_map(|line| line.score_cp.map(|cp| (line.rank, cp)))
        .collect();

    cp_scores.sort_by_key(|(rank, _)| *rank);

    // If we do not have enough engine information, return a conservative low-medium
    // estimate instead of pretending the position is hard.
    if cp_scores.len() < 2 {
        let score = if input.in_check { 0.15 } else { 0.25 };
        return Difficulty {
            score: round2(score),
            label: label_for_score(score),
            recommended_delay_ms: human_delay_for_score(
                score,
                input.min_delay_ms,
                input.max_delay_ms,
            ),
            reason: "Not enough engine candidate moves were available, so difficulty was estimated conservatively.".to_string(),
            legal_move_count: input.legal_move_count,
            in_check: input.in_check,
            analysed_moves: cp_scores.len(),
            excellent_moves: 1,
            good_moves: 1,
            playable_moves: 1,
            trap_moves: 0,
            blunder_moves: 0,
            best_second_loss_cp: None,
            max_top_loss_cp: None,
        };
    }

    let best_cp = cp_scores[0].1;

    // Loss from the best move. Assumes cp scores are side-to-move normalized:
    // higher score = better for the player about to move.
    let losses: Vec<i32> = cp_scores
        .iter()
        .map(|(_, cp)| (best_cp - *cp).max(0))
        .collect();

    let best_second_loss_cp = losses.get(1).copied();
    let max_top_loss_cp = losses.iter().copied().max();

    let excellent_moves = losses.iter().filter(|&&loss| loss <= 25).count();
    let good_moves = losses.iter().filter(|&&loss| loss <= 60).count();
    let playable_moves = losses.iter().filter(|&&loss| loss <= 120).count();
    let trap_moves = losses
        .iter()
        .filter(|&&loss| loss > 120 && loss <= 350)
        .count();
    let blunder_moves = losses.iter().filter(|&&loss| loss > 350).count();

    let second_loss = best_second_loss_cp.unwrap_or(120) as f64;
    let max_loss = max_top_loss_cp.unwrap_or(0) as f64;

    // Precision pressure: high when the second-best move is significantly worse.
    let precision = ((second_loss - 30.0) / 220.0).clamp(0.0, 1.0);

    // Trap pressure: high when plausible MultiPV alternatives lose meaningful value.
    let trap_pressure = (trap_moves as f64 / 4.0).clamp(0.0, 1.0);

    // Blunder pressure: high when at least one top candidate is much worse.
    let blunder_pressure = ((max_loss - 150.0) / 450.0).clamp(0.0, 1.0);

    // Legal move count should matter only weakly. It represents visual/choice load,
    // not actual move difficulty.
    let branching_pressure =
        ((input.legal_move_count.saturating_sub(8)) as f64 / 28.0).clamp(0.0, 1.0);

    // The key starting-position fix: many good moves reduce difficulty.
    let good_move_relief = ((good_moves.saturating_sub(1)) as f64 / 5.0).clamp(0.0, 1.0);

    let tactical_pressure = tactical_pressure(&input.lines, &mut reasons);

    let mut score =
        0.50 * precision
        + 0.20 * trap_pressure
        + 0.15 * blunder_pressure
        + 0.10 * branching_pressure
        + 0.10 * tactical_pressure
        - 0.30 * good_move_relief;

    // Check evasions with very few legal moves usually feel more forced and faster.
    // Do not over-apply this to complicated check positions with many evasions.
    if input.in_check && input.legal_move_count <= 3 {
        score -= 0.15;
        reasons.push("there were very few check evasions".to_string());
    }

    score = score.clamp(0.0, 1.0);

    if good_moves >= 4 {
        reasons.push("many candidate moves were good, so the choice was not critical".to_string());
    }

    if precision >= 0.65 {
        reasons.push("the best move was clearly better than the alternatives".to_string());
    } else if precision <= 0.20 {
        reasons.push("the top moves were close in value".to_string());
    }

    if trap_moves >= 2 {
        reasons.push("several plausible alternatives lost significant value".to_string());
    }

    if input.legal_move_count >= 25 && good_moves <= 2 {
        reasons.push("there were many legal moves but few good ones".to_string());
    }

    if reasons.is_empty() {
        reasons.push("difficulty was estimated from engine move-loss spread".to_string());
    }

    let label = label_for_score(score);
    let recommended_delay_ms = human_delay_for_score(
        score,
        input.min_delay_ms,
        input.max_delay_ms,
    );

    Difficulty {
        score: round2(score),
        label,
        recommended_delay_ms,
        reason: reasons.join("; "),
        legal_move_count: input.legal_move_count,
        in_check: input.in_check,
        analysed_moves: cp_scores.len(),
        excellent_moves,
        good_moves,
        playable_moves,
        trap_moves,
        blunder_moves,
        best_second_loss_cp,
        max_top_loss_cp,
    }
}

fn tactical_pressure(lines: &[AnalysisLine], reasons: &mut Vec<String>) -> f64 {
    let best_mate = lines.first().and_then(|line| line.mate);
    let second_mate = lines.get(1).and_then(|line| line.mate);

    match best_mate {
        Some(mate) if mate.abs() == 1 => {
            reasons.push("mate in one was available".to_string());
            -0.25
        }
        Some(_) if second_mate.is_none() => {
            reasons.push("the best move led to a forcing mate line".to_string());
            0.35
        }
        _ => 0.0,
    }
}

fn label_for_score(score: f64) -> DifficultyLabel {
    match score {
        s if s < 0.10 => DifficultyLabel::Trivial,
        s if s < 0.28 => DifficultyLabel::Easy,
        s if s < 0.50 => DifficultyLabel::Medium,
        s if s < 0.75 => DifficultyLabel::Hard,
        _ => DifficultyLabel::VeryHard,
    }
}

/// Non-linear delay mapping.
///
/// This keeps easy moves snappy while still allowing hard decisions to produce
/// noticeable human-like hesitation.
fn human_delay_for_score(score: f64, min: u64, max: u64) -> u64 {
    let curved = score.clamp(0.0, 1.0).powf(1.7);
    let span = max.saturating_sub(min) as f64;
    min + (span * curved).round() as u64
}

/// Optional helper for callers that want less mechanical bot timing.
///
/// random_0_to_1 should be a random f64 in [0.0, 1.0].
pub fn add_delay_jitter(delay_ms: u64, score: f64, random_0_to_1: f64) -> u64 {
    let jitter_strength = 0.15 + 0.20 * score.clamp(0.0, 1.0);
    let centered = random_0_to_1.clamp(0.0, 1.0) - 0.5;
    let multiplier = 1.0 + centered * jitter_strength;

    ((delay_ms as f64) * multiplier).max(80.0).round() as u64
}

fn round2(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}

#[cfg(test)]
mod tests {
    use super::*;

    fn line(rank: u8, cp: i32) -> AnalysisLine {
        AnalysisLine {
            rank,
            depth: Some(12),
            move_uci: Some(format!("move{rank}")),
            score_cp: Some(cp),
            mate: None,
            pv: vec![format!("move{rank}")],
        }
    }

    fn mate_line(rank: u8, mate: i32) -> AnalysisLine {
        AnalysisLine {
            rank,
            depth: Some(12),
            move_uci: Some(format!("move{rank}")),
            score_cp: None,
            mate: Some(mate),
            pv: vec![format!("move{rank}")],
        }
    }

    #[test]
    fn forced_move_is_trivial() {
        let difficulty = calculate(DifficultyInput {
            legal_move_count: 1,
            in_check: true,
            lines: vec![line(1, 0)],
            candidate_threshold_cp: 80,
            min_delay_ms: 150,
            max_delay_ms: 2000,
        });

        assert!(matches!(difficulty.label, DifficultyLabel::Trivial));
        assert_eq!(difficulty.score, 0.0);
    }

    #[test]
    fn many_close_candidates_are_easy_not_hard() {
        let difficulty = calculate(DifficultyInput {
            legal_move_count: 20,
            in_check: false,
            lines: vec![
                line(1, 30),
                line(2, 25),
                line(3, 20),
                line(4, 15),
                line(5, 10),
                line(6, 5),
                line(7, 0),
                line(8, -5),
            ],
            candidate_threshold_cp: 80,
            min_delay_ms: 150,
            max_delay_ms: 2000,
        });

        assert!(difficulty.score < 0.28, "score was {}", difficulty.score);
        assert!(matches!(
            difficulty.label,
            DifficultyLabel::Trivial | DifficultyLabel::Easy
        ));
        assert!(difficulty.good_moves >= 4);
    }

    #[test]
    fn one_clearly_best_move_is_harder() {
        let difficulty = calculate(DifficultyInput {
            legal_move_count: 32,
            in_check: false,
            lines: vec![
                line(1, 120),
                line(2, -120),
                line(3, -180),
                line(4, -220),
                line(5, -300),
                line(6, -420),
            ],
            candidate_threshold_cp: 80,
            min_delay_ms: 150,
            max_delay_ms: 2000,
        });

        assert!(difficulty.score >= 0.50, "score was {}", difficulty.score);
        assert!(matches!(
            difficulty.label,
            DifficultyLabel::Hard | DifficultyLabel::VeryHard
        ));
        assert_eq!(difficulty.good_moves, 1);
    }

    #[test]
    fn mate_in_one_is_not_slow() {
        let difficulty = calculate(DifficultyInput {
            legal_move_count: 18,
            in_check: false,
            lines: vec![mate_line(1, 1), line(2, 50)],
            candidate_threshold_cp: 80,
            min_delay_ms: 150,
            max_delay_ms: 2000,
        });

        assert!(difficulty.score < 0.40, "score was {}", difficulty.score);
    }

    #[test]
    fn jitter_stays_reasonable() {
        let base = 1000;
        let low = add_delay_jitter(base, 0.5, 0.0);
        let high = add_delay_jitter(base, 0.5, 1.0);

        assert!(low >= 800);
        assert!(high <= 1200);
    }
}
