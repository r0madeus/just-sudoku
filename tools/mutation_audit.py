#!/usr/bin/env python3
"""Checks that the tests catch real mistakes: each mutation below breaks one behaviour a player
relies on, the whole suite runs against it (tools/run_tests.sh), and the mutation counts as
caught when some suite fails. A mutation nothing catches is a behaviour no test guards.
    GODOT=/path/to/godot python3 tools/mutation_audit.py [M01 M05 ...]
Every file is restored after its run, also when interrupted."""
import os, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (id, file, original text, broken text, what breaks)
MUTATIONS = [
 ("M01", "scripts/gameplay/game_state.gd", "\t\tmistakes_count += 1\n\t\tis_placement_valid = false\n\telif", "\t\tis_placement_valid = false\n\telif", "A clashing digit is not counted as a mistake"),
 ("M02", "scripts/gameplay/game_state.gd", "\t\t\t\tcurrent_board.remove_candidate(peer_idx, new_val)\n", "\t\t\t\tpass\n", "Placing a digit leaves it in the peers' notes"),
 ("M03", "scripts/gameplay/game_state.gd", "\t\tcurrent_board.set_cell(idx, int(move[\"prev_val\"]), false)\n", "\t\tpass\n", "Undo does not restore the cell"),
 ("M04", "scripts/gameplay/game_state.gd", "\tis_completed = true\n\tvar score", "\tis_completed = false\n\tvar score", "A solved board is never complete"),
 ("M05", "scripts/gameplay/performance_scorer.gd", "mistakes * 6.0", "mistakes * 0.0", "Mistakes do not lower the score"),
 ("M06", "scripts/gameplay/performance_scorer.gd", "\t\traw_score += 5.0", "\t\traw_score += 0.0", "No bonus for a clean solve"),
 ("M07", "scripts/gameplay/game_state.gd", "\t\thints_used += 1\n\t\tif step.digit", "\t\tif step.digit", "Applied hints are not counted"),
 ("M08", "scripts/core/sudoku_validator.gd", "static func get_conflicts(board: SudokuBoard) -> Array[int]:\n", "static func get_conflicts(board: SudokuBoard) -> Array[int]:\n\treturn []\n", "Clashing digits are never found"),
 ("M09", "scripts/core/sudoku_validator.gd", "\tcounter.search()\n\treturn counter.count", "\tcounter.search()\n\treturn 1", "Every puzzle passes as uniquely solvable"),
 ("M10", "scripts/data/daily_manager.gd", "\t\t\tif diff_days == 1:", "\t\t\tif diff_days == 2:", "The Daily streak never continues"),
 ("M11", "scripts/data/daily_manager.gd", "year * 10000 + month * 100 + day", "year * 10000 + month * 100", "Every day of a month has the same Daily"),
 ("M12", "scripts/data/save_manager.gd", "\tvar success := safe_write_active(data)", "\tvar success := true", "The game in progress is not saved"),
 ("M13", "scripts/gameplay/game_state.gd", "\telapsed_time = float(data.get(\"elapsed_time\", 0.0))", "\telapsed_time = 0.0", "A loaded game restarts its clock"),
 ("M14", "scripts/gameplay/game_state.gd", "\tif is_completed or is_paused:\n\t\treturn false\n\tif idx < 0", "\tif is_completed:\n\t\treturn false\n\tif idx < 0", "Cells can be changed while paused"),
 ("M15", "scripts/data/statistics_manager.gd", "if t < entry[\"best_time\"]:", "if t > entry[\"best_time\"]:", "Best time keeps the slowest"),
 ("M16", "scripts/data/achievement_manager.gd", "\t\tif r.get(\"assisted\", false):\n\t\t\tcontinue", "\t\tif false:\n\t\t\tcontinue", "A shown solution earns achievements"),
 ("M17", "scripts/services/theme_manager.gd", "\treturn roundi(px * (1.0 + (text_scale - 1.0) * weight))", "\treturn roundi(px)", "Text size setting does nothing"),
 ("M18", "scenes/gameplay/sudoku_cell.gd", "\t\tvar marked: bool = is_conflict or is_wrong", "\t\tvar marked: bool = false", "Wrong digits lose their shape mark"),
 ("M19", "scenes/gameplay/game_screen.gd", "\t\tDailyManager.mark_today_completed()\n", "\t\tpass\n", "Solving the Daily does not mark the day"),
 ("M20", "scenes/gameplay/game_screen.gd", "\tHistoryManager.add_record(summary)\n", "\tpass\n", "A finished game is not recorded"),
 ("M21", "scenes/menus/settings_screen.gd", "\t\tfile.store_string(JSON.stringify(data, \"\\t\"))\n\t\tfile.close()\n\t_notify_listeners()", "\t\tfile.close()\n\t_notify_listeners()", "Settings are not saved"),
 ("M22", "scripts/gameplay/game_state.gd", "\t\t\tset_number(step.cells[0], step.digit, true)", "\t\t\tset_number(step.cells[0], step.digit % 9 + 1, true)", "A hint places the wrong digit"),
 ("M23", "scripts/services/puzzle_share_service.gd", "seed_label, seed_val, code_label", "seed_label, seed_val + 1, code_label", "A shared puzzle has the wrong number"),
 ("M24", "scenes/gameplay/game_screen.gd", "\t\tgame_timer.pause()\n", "\t\tpass\n", "The clock runs while paused"),
 ("M25", "scenes/gameplay/sudoku_grid.gd", "var is_same: bool = (idx != selected_idx and sel_val != 0 and val == sel_val)", "var is_same: bool = false", "Same digits are not highlighted"),
]

def main():
    only = set(sys.argv[1:])
    missed = 0
    for mid, rel, old, new, what in MUTATIONS:
        if only and mid not in only:
            continue
        path = os.path.join(REPO, rel)
        src = open(path, encoding="utf-8").read()
        if src.count(old) != 1:
            print(f"{mid} STALE  {what}: the original text is no longer in {rel}; update the mutation")
            missed += 1
            continue
        open(path, "w", encoding="utf-8").write(src.replace(old, new))
        try:
            run = subprocess.run(["bash", os.path.join(REPO, "tools/run_tests.sh")], capture_output=True, text=True)
        finally:
            open(path, "w", encoding="utf-8").write(src)
        fails = [l.split()[1] for l in run.stdout.splitlines() if l.startswith("FAIL ")]
        print(f"{mid} {'CAUGHT' if fails else 'MISSED'} {what}" + (f"  ({', '.join(fails)})" if fails else ""), flush=True)
        missed += 0 if fails else 1
    sys.exit(1 if missed else 0)

if __name__ == "__main__":
    main()
