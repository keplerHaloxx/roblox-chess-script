use roblox_chess_script_lib::{
    api::types::AnalysisLine,
    engine::{
        analysis::AnalysisAccumulator,
        uci::{info_to_analysis_line, parse_bestmove_line, parse_info_line, UciScore},
    },
};

#[test]
fn parses_centipawn_info_line_with_multipv_and_pv() {
    let parsed = parse_info_line(
        "info depth 18 seldepth 27 multipv 3 score cp -42 nodes 12345 nps 999 pv g1f3 d7d5 d2d4",
    )
    .expect("info line");

    assert_eq!(parsed.depth, Some(18));
    assert_eq!(parsed.multipv, 3);
    assert_eq!(parsed.score, Some(UciScore::Cp(-42)));
    assert_eq!(parsed.pv, vec!["g1f3", "d7d5", "d2d4"]);
}

#[test]
fn parses_mate_info_line() {
    let parsed = parse_info_line("info depth 21 multipv 1 score mate -3 pv h2h4 h7h5").unwrap();
    assert_eq!(parsed.score, Some(UciScore::Mate(-3)));

    let line = info_to_analysis_line(parsed);
    assert_eq!(line.rank, 1);
    assert_eq!(line.score_cp, None);
    assert_eq!(line.mate, Some(-3));
    assert_eq!(line.move_uci.as_deref(), Some("h2h4"));
}

#[test]
fn parses_bestmove_with_and_without_ponder() {
    let with_ponder = parse_bestmove_line("bestmove e2e4 ponder e7e5").unwrap();
    assert_eq!(with_ponder.0, "e2e4");
    assert_eq!(with_ponder.1.as_deref(), Some("e7e5"));

    let no_ponder = parse_bestmove_line("bestmove g1f3").unwrap();
    assert_eq!(no_ponder.0, "g1f3");
    assert_eq!(no_ponder.1, None);
}

#[test]
fn accumulator_keeps_latest_line_per_rank_and_sorts_by_rank() {
    let mut acc = AnalysisAccumulator::default();
    acc.update(AnalysisLine {
        rank: 2,
        depth: Some(10),
        move_uci: Some("d2d4".to_string()),
        score_cp: Some(20),
        mate: None,
        pv: vec!["d2d4".to_string()],
    });
    acc.update(AnalysisLine {
        rank: 1,
        depth: Some(10),
        move_uci: Some("e2e4".to_string()),
        score_cp: Some(30),
        mate: None,
        pv: vec!["e2e4".to_string()],
    });
    acc.update(AnalysisLine {
        rank: 2,
        depth: Some(12),
        move_uci: Some("c2c4".to_string()),
        score_cp: Some(25),
        mate: None,
        pv: vec!["c2c4".to_string()],
    });

    let lines = acc.into_lines();
    assert_eq!(lines.len(), 2);
    assert_eq!(lines[0].rank, 1);
    assert_eq!(lines[0].move_uci.as_deref(), Some("e2e4"));
    assert_eq!(lines[1].rank, 2);
    assert_eq!(lines[1].move_uci.as_deref(), Some("c2c4"));
    assert_eq!(lines[1].depth, Some(12));
}
