use roblox_chess_script_lib::{
    api::types::AnalysisLine,
    engine::difficulty::{calculate, DifficultyInput, DifficultyLabel},
};

fn line(rank: u8, cp: i32) -> AnalysisLine {
    AnalysisLine {
        rank,
        depth: Some(16),
        move_uci: Some(format!("move{rank}")),
        score_cp: Some(cp),
        mate: None,
        pv: vec![format!("move{rank}")],
    }
}

fn mate_line(rank: u8, mate: i32) -> AnalysisLine {
    AnalysisLine {
        rank,
        depth: Some(16),
        move_uci: Some(format!("mate{rank}")),
        score_cp: None,
        mate: Some(mate),
        pv: vec![format!("mate{rank}")],
    }
}

#[test]
fn only_legal_move_is_trivial_and_uses_min_delay() {
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
    assert_eq!(difficulty.recommended_delay_ms, 150);
    assert!(difficulty.reason.contains("forced"));
}

#[test]
fn many_close_candidate_moves_are_easy_not_hard() {
    let difficulty = calculate(DifficultyInput {
        legal_move_count: 32,
        in_check: false,
        lines: vec![line(1, 35), line(2, 28), line(3, 12), line(4, -20)],
        candidate_threshold_cp: 80,
        min_delay_ms: 100,
        max_delay_ms: 2100,
    });

    assert!(
        difficulty.score <= 0.20,
        "many close moves should be easy; score was {}",
        difficulty.score
    );
    assert!(matches!(
        difficulty.label,
        DifficultyLabel::Trivial | DifficultyLabel::Easy
    ));
    assert_eq!(difficulty.good_moves, 4);
    assert_eq!(difficulty.playable_moves, 4);
    assert_eq!(difficulty.best_second_loss_cp, Some(7));
    assert!(difficulty.recommended_delay_ms < 500);
}

#[test]
fn large_eval_gap_is_harder_than_close_candidates() {
    let hard = calculate(DifficultyInput {
        legal_move_count: 20,
        in_check: false,
        lines: vec![line(1, 500), line(2, 20), line(3, -50)],
        candidate_threshold_cp: 80,
        min_delay_ms: 100,
        max_delay_ms: 2100,
    });

    let easy = calculate(DifficultyInput {
        legal_move_count: 20,
        in_check: false,
        lines: vec![line(1, 40), line(2, 35), line(3, 20)],
        candidate_threshold_cp: 80,
        min_delay_ms: 100,
        max_delay_ms: 2100,
    });

    assert!(
        hard.score > easy.score,
        "large eval gap should be harder: hard={} easy={}",
        hard.score,
        easy.score
    );
    assert_eq!(hard.good_moves, 1);
    assert_eq!(easy.good_moves, 3);
    assert_eq!(hard.best_second_loss_cp, Some(480));
    assert_eq!(easy.best_second_loss_cp, Some(5));
}

#[test]
fn one_clearly_best_move_is_hard() {
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
        min_delay_ms: 100,
        max_delay_ms: 2100,
    });

    assert!(difficulty.score >= 0.50, "score was {}", difficulty.score);
    assert!(matches!(
        difficulty.label,
        DifficultyLabel::Hard | DifficultyLabel::VeryHard
    ));
    assert_eq!(difficulty.good_moves, 1);
    assert!(difficulty.trap_moves >= 2);
    assert_eq!(difficulty.best_second_loss_cp, Some(240));
    assert!(difficulty.recommended_delay_ms > 700);
}

#[test]
fn mate_in_one_is_not_slow_even_without_cp_score() {
    let difficulty = calculate(DifficultyInput {
        legal_move_count: 10,
        in_check: false,
        lines: vec![mate_line(1, 1), line(2, 50)],
        candidate_threshold_cp: 80,
        min_delay_ms: 100,
        max_delay_ms: 2100,
    });

    // Mate lines normally have mate: Some(_) and score_cp: None, so the current
    // implementation falls back to a conservative estimate instead of using the
    // mate line in the centipawn loss calculation.
    assert!(difficulty.score <= 0.25, "score was {}", difficulty.score);
    assert!(matches!(
        difficulty.label,
        DifficultyLabel::Easy | DifficultyLabel::Medium
    ));
    assert!(difficulty.recommended_delay_ms < 400);
}

#[test]
fn very_few_check_evasions_reduce_delay() {
    let difficulty = calculate(DifficultyInput {
        legal_move_count: 2,
        in_check: true,
        lines: vec![line(1, 40), line(2, -20)],
        candidate_threshold_cp: 80,
        min_delay_ms: 100,
        max_delay_ms: 2100,
    });

    assert!(difficulty.score <= 0.20, "score was {}", difficulty.score);
    assert!(difficulty.reason.contains("check evasions"));
}
