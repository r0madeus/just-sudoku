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
 ("M19", "scripts/gameplay/game_recorder.gd", "\t\tDailyManager.mark_completed(daily_date)\n", "\t\tpass\n", "Solving the Daily does not mark the day"),
 ("M20", "scripts/gameplay/game_recorder.gd", "\tHistoryManager.add_record(summary)\n", "\tpass\n", "A finished game is not recorded"),
 ("M21", "scripts/services/app_settings.gd", "\t\tfile.store_string(JSON.stringify(data, \"\\t\"))\n\t\tfile.close()\n\t_notify_listeners()", "\t\tfile.close()\n\t_notify_listeners()", "Settings are not saved"),
 ("M22", "scripts/gameplay/game_state.gd", "\t\t\tset_number(step.cells[0], step.digit, true)", "\t\t\tset_number(step.cells[0], step.digit % 9 + 1, true)", "A hint places the wrong digit"),
 ("M23", "scripts/services/puzzle_share_service.gd", "seed_label, seed_val, code_label", "seed_label, seed_val + 1, code_label", "A shared puzzle has the wrong number"),
 ("M24", "scenes/gameplay/game_screen.gd", "\t\tgame_timer.pause()\n", "\t\tpass\n", "The clock runs while paused"),
 ("M26", "scripts/core/techniques/fish_techniques.gd", "\t\tif step == null:\n\t\t\tstep = _swordfish_for(board, d, false)\n", "", "Swordfish is only looked for along rows"),
 ("M27", "scripts/core/techniques/chain_techniques.gd", "\t\t\t\tif p1_cands[0] == p2_cands[0] and p1_cands[1] == p2_cands[1]:\n\t\t\t\t\tcontinue\n", "", "XYZ-Wing accepts two identical wings (unsound)"),
 ("M28", "scripts/core/sudoku_generator.gd", "\treturn LEVEL_ORDER.find(a.level) if a.solved_logically else LEVEL_ORDER.size()", "\treturn LEVEL_ORDER.find(a.level)", "Puzzles that need guessing pass as Expert"),
 ("M25", "scenes/gameplay/sudoku_grid.gd", "var is_same: bool = (not is_sel and sel_val != 0 and val == sel_val)", "var is_same: bool = false", "Same digits are not highlighted"),
 ("M29", "scripts/gameplay/game_state.gd", "var next: int = prev | (1 << num) if add else prev & ~(1 << num)", "var next: int = prev | (1 << num)", "A note in several cells can never be taken out"),
 ("M30", "scenes/gameplay/sudoku_grid.gd", "elif event is InputEventMouseMotion and _pressing:", "elif false:", "Dragging over the board selects nothing more"),
 ("M31", "scenes/gameplay/game_screen.gd", "\t\t_apply_key(locked_digit, one)", "\t\tpass", "Digit-first taps place nothing"),
 ("M32", "scripts/gameplay/game_state.gd", "\t\t\"colors\": Array(cell_colors),\n", "", "Cell colours are not saved"),
 ("M33", "scripts/data/backup_manager.gd", "\tHistoryManager.clear_cache()\n", "", "A restore leaves the old history on screen"),
 ("M34", "scripts/data/backup_manager.gd", "if part.is_empty() or part == \".\" or part == \"..\":", "if false:", "A backup can write outside the save folder"),
 ("M35", "scenes/app_root.gd", "\tgame_screen.close_game()\n", "", "The game left open saves over a restore"),
 ("M36", "scripts/data/backup_manager.gd", "\t_remove_json(SAVES_DIR)\n", "", "A restore keeps files the backup does not have"),
 ("M37", "scripts/data/daily_manager.gd", "\tif date_str == get_today_date_string():\n\t\tmark_today_completed()", "\tif true:\n\t\tmark_today_completed()", "An archive day counts as today's Daily"),
 ("M38", "scripts/data/daily_manager.gd", "if last.is_empty() or days_between(last, get_today_date_string()) > 1:", "if last.is_empty():", "A broken streak still shows as going"),
 ("M39", "scripts/data/daily_manager.gd", "for back in range(ARCHIVE_DAYS):", "for back in range(1):", "Past Dailies are not known as Dailies"),
 ("M40", "scenes/menus/techniques_screen.gd", "\t\tTechniqueLibrary.apply_step(board, current_step)\n", "\t\tpass\n", "A technique lesson's Show the move changes nothing"),
 ("M41", "scenes/menus/techniques_screen.gd", "\tvar puzzles := TechniqueLibrary.practice(current_technique)\n", "\tvar puzzles := TechniqueLibrary.practice(TechniqueLibrary.ORDER[0])\n", "Practice starts a puzzle for another technique"),
 ("M42", "scripts/services/sound_manager.gd", "var freq: float = DIGIT_NOTES[d - 1] if d >= 1 else DIGIT_NOTES[5]", "var freq: float = DIGIT_NOTES[5]", "Every digit sounds the same"),
 ("M43", "scripts/services/sound_manager.gd", "\t\tif from_end < fade:\n", "\t\tif false:\n", "Sounds end with a click"),
 ("M44", "scripts/services/sound_manager.gd", "\t\t_prerender_task = WorkerThreadPool.add_task(_prerender, false, \"Render sounds\")\n", "\t\tpass\n", "Sounds are rendered when first played, stalling the game"),
 ("M45", "scenes/menus/settings_screen.gd", "version_label.text = \"Just Sudoku \" + AppSettings.app_version()", "version_label.text = \"Just Sudoku\"", "Settings does not show the version"),
 ("M46", "export_presets.cfg", "permissions/internet=false", "permissions/internet=true", "The app asks for the internet"),
 ("M47", "scenes/app_root.gd", "\t\t_relayout_after_resume()\n", "\t\tpass\n", "Coming back from the background keeps a broken layout"),
 ("M48", "scripts/services/responsive_manager.gd", "\tif not Rect2i(Vector2i.ZERO, window_size).encloses(safe_rect):\n\t\treturn insets\n", "", "A safe area outside the window is trusted"),
 ("M49", "scripts/services/responsive_manager.gd", "\tif maxi(left_px, right_px) > window_size.x * MAX_SIDE_INSET_SHARE \\\n", "\tif false \\\n", "Any size of safe-area margin is trusted"),
 ("M50", "scenes/gameplay/game_screen.gd", "\t\tpause_menu.close_modal()\n\t_sync_pause_icon()", "\t\tpause_menu.close_modal()\n\tpass", "A game set up after Pause → Menu shows play"),
 ("M51", "scenes/gameplay/game_screen.gd", "\tgame_state.is_paused = false\n", "", "A game left through the pause sheet comes back paused"),
 ("M52", "scenes/gameplay/dialogs/solution_dialog.gd", "\tdetail_box.custom_minimum_size.y = maxf(step_h, full_info_panel.get_combined_minimum_size().y)\n", "\tpass\n", "The solution dialog resizes between its views"),
 ("M53", "scenes/ui/touch_scroll.gd", "\t_replay(away)\n", "", "A held box is ticked by the drag that scrolls past it"),
 ("M54", "scenes/ui/touch_scroll.gd", "\t\t_down_pos.y += SLOP * signf(event.position.y - _down_pos.y)\n", "\t\t_down_pos = event.position\n", "A drag lags behind the finger by the touch slop"),
 ("M55", "scenes/ui/touch_scroll.gd", "\t\t\t_replay(_down_event)\n\t\t\t_replay(event)\n", "\t\t\tpass\n", "A quick tap on a scrolling list does nothing"),
 ("M56", "scenes/ui/touch_scroll.gd", "\tstate = State.CAUGHT if was_gliding else State.PENDING\n", "\tstate = State.PENDING\n", "Stopping a glide also presses what is under the finger"),
 ("M57", "scenes/ui/touch_scroll.gd", "\t\tif m is CanvasItem and m.visible and not m.is_ancestor_of(scroll):\n", "\t\tif false:\n", "A list scrolls under an open dialog"),
 ("M58", "scenes/ui/touch_scroll.gd", "\t\t\tvelocity = clampf(_flick_speed(), -MAX_FLING_SPEED, MAX_FLING_SPEED)\n", "\t\t\tvelocity = 0.0\n", "A flick does not glide"),
 ("M60", "scenes/gameplay/smart_numpad.gd", "\t\tbtn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS\n", "", "Number pad digits wait for the finger to lift"),
 ("M61", "scenes/menus/resume_card.gd", "\t\t\t_press_inside = true\n", "\t\t\t_press_inside = true\n\t\t\tpressed.emit()\n", "The game card opens as the finger lands, so a scroll from it opens the game"),
 ("M62", "scripts/gameplay/game_state.gd", "const AppSettings = preload(\"res://scripts/services/app_settings.gd\")\n", "const AppSettings = preload(\"res://scripts/services/app_settings.gd\")\nconst SettingsScreen = preload(\"res://scenes/menus/settings_screen.gd\")\n", "Start-up loads the Settings screen again, through the game's state"),
 ("M63", "scenes/app_root.gd", "\t_start_warm_up()\n", "", "The screens behind the menu are only made when first opened, so the first tap waits"),
 ("M64", "scenes/app_root.gd", "\t_keep_dialogs_on_top()\n\t_connect_node(key, node)\n", "\t_connect_node(key, node)\n", "A screen made after a dialog covers it"),
 ("M65", "scenes/app_root.gd", "\t\tnode.visible = false\n", "\t\tpass\n", "A screen made in the background shows over the menu"),
 ("M66", "scenes/app_root.gd", "\tif not _made.has(\"game_screen\"):\n\t\tmain_menu.refresh_buttons()\n\t\treturn\n", "", "Restoring a backup makes the game screen for nothing"),
 ("M67", "scenes/app_root.gd", "\t_connect_node(key, node)\n", "", "A screen made on demand does not answer its buttons"),
 ("M59", "scenes/ui/picker_button.gd", "\t\tif event.pressed:\n\t\t\t_press_inside = true\n", "\t\tif event.pressed:\n\t\t\t_press_inside = true\n\t\t\topen_picker()\n", "A list opens as the finger lands on it to scroll"),
 ("M68", "scenes/ui/picker_button.gd", "MOUSE_BUTTON_LEFT:\n\t\taccept_event()\n", "MOUSE_BUTTON_LEFT:\n", "Dropdowns open Godot's popup menu as well as the app's sheet"),
 ("M69", "scenes/ui/picker_button.gd", "\twhile host.get_parent() is Control:\n\t\thost = host.get_parent()\n", "", "A picker's sheet opens squeezed inside its row"),
 ("M70", "scenes/ui/picker_button.gd", "\tif index == selected:\n\t\treturn\n", "", "Picking the current choice again applies it again"),
 ("M71", "scripts/services/theme_manager.gd", " \\\n\t\t\t\tor (old_file and (t_name == THEME_DARK or t_name == THEME_LIGHT))", "", "Players of 1.0.0 keep the theme found on their first start instead of following the phone"),
 ("M72", "scripts/services/theme_manager.gd", "\"theme\": THEME_SYSTEM if follows_system else current_theme_name,", "\"theme\": current_theme_name,", "Following the phone's theme is forgotten on the next start"),
 ("M73", "scripts/services/theme_manager.gd", "\tif follows_system and detect_system_theme() != current_theme_name:\n", "\tif detect_system_theme() != current_theme_name:\n", "A theme picked is replaced by the phone's on return"),
 ("M74", "scripts/services/app_settings.gd", "\"locale\": LOCALE_SYSTEM if locale_follows_system else LocalizationManager.get_locale(),", "\"locale\": LocalizationManager.get_locale(),", "Following the phone's language is forgotten on the next start"),
 ("M75", "scripts/services/app_settings.gd", "int(json.data.get(\"version\", 1)) < CONFIG_VERSION \\\n\t\t\t\tor ", "", "Players of 1.0.0 keep the language found on their first start"),
 ("M76", "scenes/app_root.gd", "\tAppSettings.follow_system_changes()\n", "", "A language or light/dark change on the phone is missed until the app restarts"),
 ("M77", "scenes/menus/settings_screen.gd", "lang_option.selected = 0 if AppSettings.locale_follows_system else ", "lang_option.selected = ", "Settings shows the phone's language as picked, not System"),
 ("M78", "scenes/ui/setting_row.gd", "\t\tif event.pressed:\n\t\t\t_press_inside = true\n\t\telif _press_inside:\n", "\t\tif event.pressed:\n\t\t\t_press_inside = true\n\t\t\t(control_node as CheckBox).button_pressed = not (control_node as CheckBox).button_pressed\n\t\telif _press_inside:\n", "A Settings row toggles as the finger lands, so a scroll that starts on its text changes the setting"),
 ("M79", "scripts/services/theme_builder.gd", "\tvar sz := 18\n", "\tvar sz := 22\n", "Check boxes are large again"),
 ("M80", "scenes/menus/main_menu.gd", "\tcontinue_btn.add_child(continue_icon)\n", "\tcontinue_btn.add_child(continue_icon)\n\tcontinue_btn.icon = ThemeManager.get_icon(\"play\")\n", "Continue's icon pushes its label off the centre the other two share"),
 ("M81", "scenes/menus/main_menu.gd", "\tnav_grid.queue_sort()\n\tnav_glass.queue_sort()\n", "", "The navigation buttons stay as wide as a look that did not fit and run off the right edge"),
 ("M82", "scripts/services/responsive_manager.gd", "\t\tif node.is_inside_tree():\n\t\t\tnode.queue_sort()\n", "\t\tpass\n", "Laying everything out again leaves stretched containers as they were"),
 ("M83", "scenes/app_root.gd", "\t\tvar side := -1.0 if (back or target == main_menu) else 1.0\n", "\t\tvar side := 1.0\n", "Screens going back slide in from the right too"),
 ("M84", "scenes/app_root.gd", "\t\t_shift(target, TRANSITION_SLIDE * side)\n", "", "Screens do not slide in"),
 ("M85", "scenes/app_root.gd", "\tif _veiled:\n\t\tmodulate.a = 0.0\n", "\tif _veiled:\n\t\tpass\n", "The app shows its first, still settling layout"),
 ("M86", "scenes/app_root.gd", "\t\tif not first:\n\t\t\t_relayout_when_settled()\n", "\t\tif not first:\n\t\t\tpass\n", "A display that changes at start is not laid out again until the late timers"),
 ("M87", "scenes/gameplay/sudoku_cell.gd", "const SELECT_TIME: float = 0.16", "const SELECT_TIME: float = 0.05", "A tapped cell settles in 0.05 s, too fast to see"),
 ("M88", "scenes/app_root.gd", "\tcard.mini_board.modulate.a = 0.0\n\t# The game's own board waits", "\t# The game's own board waits", "The card's board shows beside the one that flies out of it"),
 ("M89", "scenes/app_root.gd", "\tgrid.modulate.a = 0.0\n\tvar fade := create_tween().set_parallel(true)\n\tfade.tween_property(main_menu, \"modulate:a\"", "\tvar fade := create_tween().set_parallel(true)\n\tfade.tween_property(main_menu, \"modulate:a\"", "Two boards show at once while the board lands"),
 ("M90", "scenes/app_root.gd", "if not _can_fly() or card == null or not card.has_game or grid == null", "if not _can_fly() or card == null or grid == null", "A board flies back to a card that has no game"),
 ("M91", "scenes/app_root.gd", "\tif _board_flying:\n\t\treturn\n", "", "Back during the flight breaks it"),
 ("M92", "scenes/app_root.gd", "is_inside_tree() and not _veiled and not _board_flying", "is_inside_tree() and not _veiled", "A second tap starts a second flight"),
 ("M93", "scenes/app_root.gd", "\tvar state := SaveManager.load_active_game()\n\tif state != null:\n\t\t_start_game_session(state)\n\telse:\n\t\tmain_menu.refresh_buttons()\n\nfunc _on_new_puzzle_generated", "\tvar state := SaveManager.load_active_game()\n\tif state != null:\n\t\t_open_game_from_card(state)\n\telse:\n\t\tmain_menu.refresh_buttons()\n\nfunc _on_new_puzzle_generated", "The Continue button flies the board too"),
 ("M94", "scenes/ui/board_flight.gd", "\tsize = _from.size.lerp(_to.size, t)\n", "\tsize = _from.size\n", "The board moves but does not grow"),
 ("M95", "scenes/app_root.gd", "\tif grid != null:\n\t\ttween.tween_property(grid, \"modulate:a\", 1.0, BOARD_HAND_OVER_TIME)\n", "", "The game's board stays hidden after the flight"),
 ("M96", "scenes/app_root.gd", "\tawait _hand_over(flight)\n\tgrid.modulate.a = 1.0\n", "\tawait _hand_over(flight)\n", "The game's board is hidden the next time the game opens"),
 ("M97", "scenes/menus/main_menu.gd", "\twordmark_dot_holder.add_theme_constant_override(\"margin_bottom\", int(roundf(font.get_descent(px))))\n", "", "The full stop floats off the baseline"),
 ("M98", "scripts/services/theme_builder.gd", "\t\ttheme.set_font(\"font\", \"Wordmark\", wordmark_font)\n", "\t\ttheme.set_font(\"font\", \"Wordmark\", brand_font)\n", "The name is back in the old serif"),
 ("M99", "scenes/menus/main_menu.gd", "\t\ttitle_label.text = \"Just Sudoku\"\n", "\t\ttitle_label.text = \"JUST SUDOKU\"\n", "The name is back in capitals"),
 ("M100", "scenes/menus/main_menu.gd", "\twordmark.add_child(wordmark_dot_holder)\n", "", "The name has no full stop"),
 ("M101", "scenes/menus/main_menu.gd", "\t\t_fit_wordmark_dot.call_deferred()\n", "\t\t_fit_wordmark_dot()\n", "The full stop is sized from a font size the label does not have yet (4 px)"),
 ("M102", "scenes/menus/main_menu.gd", "\tsb.bg_color = ThemeManager.get_color(\"accent_blue\", ThemeManager.get_color(\"accent\"))\n\tsb.set_corner_radius_all(maxi(2, int(side * 0.28)))", "\tsb.bg_color = Color.WHITE\n\tsb.set_corner_radius_all(maxi(2, int(side * 0.28)))", "The full stop is not in the accent colour"),
 ("M103", "scenes/app_root.gd", "\tif event is InputEventScreenTouch or event is InputEventScreenDrag:\n\t\tget_viewport().set_input_as_handled()\n", "\tif false:\n\t\tget_viewport().set_input_as_handled()\n", "A tap on a touch screen presses a key twice: the digit goes in and comes straight out"),
 ("M104", "scenes/ui/ambient_backdrop.gd", "\tif amoled:\n\t\tbase_strength = 0.0\n", "\tif amoled:\n\t\tbase_strength = 0.12\n", "AMOLED has glows again: not black"),
 ("M105", "scenes/ui/ambient_backdrop.gd", "0.0 if amoled else 1.0", "1.0", "AMOLED's noise lights pixels of the black page"),
 ("M106", "scenes/ui/glass_panel.gd", "\t_material.shader = _flat_shader if flat else _shader\n", "\t_material.shader = _shader\n", "AMOLED glass copies and blurs the screen again"),
 ("M107", "scenes/ui/game_action_dock.gd", "\tnotes_btn.icon = ThemeManager.get_icon(\"pencil\")\n", "\tnotes_btn.text = \"Notes\"\n", "The Notes button is a word again"),
 ("M108", "scenes/gameplay/game_screen.gd", "\tif active and not AppSettings.colors_hint_seen:\n", "\tif active:\n", "The Colours note opens every time"),
 ("M109", "scenes/gameplay/game_screen.gd", "\t\tAppSettings.colors_hint_seen = true\n\t\tAppSettings.save_config()\n", "", "The Colours note is never remembered as seen"),
 ("M110", "scripts/services/app_settings.gd", "\t\t\"colors_hint_seen\": colors_hint_seen,\n", "", "The Colours note is shown again on every start"),
 ("M111", "scripts/services/theme_builder.gd", "ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 20, 10, ThemeManager.get_shadow_color(0.14)", "ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, highlight_border, 20, 10, ThemeManager.get_shadow_color(0.14)", "The filled capsule buttons have a ring around their edge again"),
 ("M112", "scripts/services/strings_en.gd", "\"RESUME_PROGRESS\": \"%d%% complete\"", "\"RESUME_PROGRESS\": \"%d%% filled\"", "The resume card says filled again"),
 ("M113", "scripts/services/strings_tr.gd", "\"PROGRESS_LABEL\": \"%s tamamlandı\"", "\"PROGRESS_LABEL\": \"İlerleme: %s\"", "The saved games list says İlerleme again"),
 ("M114", "scenes/menus/main_menu.gd", "\t\tdaily_meta_label.visible = streak > 0\n", "\t\tdaily_meta_label.visible = true\n", "The Daily card has an empty line under its name when there is no streak"),
 ("M115", "web/shell.html", "Just Sudoku<i></i>", "Just Sudoku", "The browser's loading screen lost the blue full stop"),
 ("M116", "scripts/services/responsive_manager.gd", "\treturn clampi(mini(content_columns(viewport_size), row_count), 1, 2)", "\treturn content_columns(viewport_size)", "A lone row sits in half of a wide window with its buttons mid-screen"),
 ("M117", "scenes/gameplay/dialogs/solution_dialog.gd", "\tprimary_btn.visible = false\n", "\tprimary_btn.visible = true\n", "The solution viewer has two Close buttons"),
 ("M118", "scenes/menus/history_screen.gd", "\t_row_total = records.size()\n", "", "History is one column however many entries there are"),
 ("M119", "scenes/menus/load_game_screen.gd", "\t_row_total = games.size()\n", "", "Saved games are one column however many there are"),
 ("M120", "scenes/menus/settings_screen.gd", "\theader.add_child(github_btn)\n", "", "Settings has no GitHub link"),
 ("M121", "scenes/ui/game_action_dock.gd", "\t\t\tThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 4, 4\n", "\t\t\tThemeManager.RADIUS_PILL_SM, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 4, 4\n", "The Notes and Colours buttons are rounded squares when on, not circles"),
 ("M122", "scenes/menus/main_menu.gd", "\tresume_card.custom_minimum_size.y = actions_h\n", "", "On a wide window the resume card is shorter than the actions beside it and sits lower"),
 ("M123", "scenes/ui/game_action_dock.gd", "\t\tfor state in [\"normal\", \"hover\", \"pressed\"]:\n\t\t\tbtn.remove_theme_stylebox_override(state)\n", "\t\tbtn.add_theme_stylebox_override(\"normal\", ThemeManager.create_flat_stylebox(Color.TRANSPARENT, ThemeManager.RADIUS_PILL_SM, ThemeManager.BORDER_HAIRLINE, ThemeManager.get_color(\"border_subtle\"), 10, 4))\n", "The Notes button has an outline when off"),
 ("M124", "scenes/ui/toggle_switch.gd", "or not AppSettings.animations_enabled:\n\t\tposition_t = target", ":\n\t\tposition_t = target", "The switch slides even with animations off"),
 ("M125", "scenes/menus/settings_screen.gd", "	glass_check = ToggleSwitch.new()\n", "	glass_check = CheckBox.new()\n", "A Settings row is a check box again, not a switch"),
 ("M126", "scenes/ui/glass_panel.gd", " or not AppSettings.glass_effects\n", "\n", "Glass effects off still draws the blurred glass"),
 ("M127", "scenes/ui/app_modal.gd", "	if blur_background and AppSettings.glass_effects:\n", "	if blur_background:\n", "Glass effects off still blurs the backdrop behind dialogs"),
 ("M128", "scenes/app_root.gd", "	AppSettings.web_notice_seen = true\n	AppSettings.save_config()\n	var note := AppModal.new()", "	var note := AppModal.new()", "The browser's note about saved progress is shown on every start"),
 ("M129", "scenes/menus/backup_section.gd", "	_modal_host().add_child(_choice)\n", "	get_tree().root.add_child(_choice)\n", "The backup dialog comes out in Godot's grey default look"),
 ("M130", "export_presets.cfg", "binary_format/embed_pck=true\ntexture_format/s3tc_bptc=true\ntexture_format/etc2_astc=false\nbinary_format/architecture=\"x86_64\"\nssh_remote_deploy", "binary_format/embed_pck=false\ntexture_format/s3tc_bptc=true\ntexture_format/etc2_astc=false\nbinary_format/architecture=\"x86_64\"\nssh_remote_deploy", "The Linux export leaves the game's data in a separate file"),
 ("M132", "packaging/linux/io.github.r0madeus.JustSudoku.metainfo.xml", "<project_license>GPL-3.0-only</project_license>", "<project_license>MIT</project_license>", "The store description names another licence than the project's"),
 ("M133", "packaging/linux/io.github.r0madeus.JustSudoku.desktop", "Exec=JustSudoku\n", "Exec=just-sudoku\n", "The menu entry starts a program that is not there"),
 ("M135", "README.md", "docs/images/hero_en.jpg", "docs/images/hero_gone.jpg", "The README's first picture is a broken link"),
 ("M136", "scenes/ui/game_action_dock.gd", "Color.TRANSPARENT, 4, 4))", "Color.TRANSPARENT, 4 if on else 14, 4))", "Turning notes on makes the dock narrower, so it flips between labels and icons"),
 ("M137", "scenes/gameplay/game_screen.gd", "game_state.clear_notes() if game_state.all_notes_filled() else game_state.fill_notes()", "game_state.fill_notes()", "Pressing Fill notes again does not take the notes off"),
 ("M138", "scenes/gameplay/sudoku_cell.gd", "const DIGIT_BLINKS: int = 3", "const DIGIT_BLINKS: int = 1", "A completed digit blinks once instead of three times"),
 ("M139", "scenes/menus/settings_screen.gd", "			await get_tree().create_timer(ToggleSwitch.SLIDE_TIME + 0.03).timeout\n", "			pass\n", "The Glass effects redraw swallows the switch's slide"),
 ("M140", "scenes/menus/settings_screen.gd", "			ctl.custom_minimum_size.x = width\n", "			pass\n", "The Customize Theme button is not as wide as the drop-downs"),
 ("M141", "scenes/ui/segmented_control.gd", "	pill_t = 0.0\n	_tween = create_tween()", "	pill_t = 1.0\n	_tween = create_tween()", "The tabs' pill does not slide, it jumps"),
 ("M142", ".github/workflows/web.yml", "scons -j\"$(nproc)\" platform=web target=template_release threads=no arch=wasm32 \\\n            profile=\"$GITHUB_WORKSPACE/engine/custom.py\"", "scons -j\"$(nproc)\" platform=web target=template_release threads=no arch=wasm32", "The web template is built without the slim profile"),
 ("M143", ".github/workflows/web.yml", "hashFiles('engine/custom.py')", "hashFiles('project.godot')", "The cached web template is not rebuilt when the profile changes"),
 ("M144", ".github/workflows/windows.yml", "platform=windows target=template_release arch=x86_64 use_mingw=yes", "platform=windows target=template_release arch=x86_64", "The Windows template is not cross-compiled with MinGW"),
 ("M145", ".github/workflows/linux.yml", "template:\n    runs-on: ubuntu-22.04", "template:\n    runs-on: ubuntu-24.04", "The Linux template is built on a newer Ubuntu, so the game needs a newer glibc"),
 ("M146", "tools/use_slim_template.py", "end = start + following.start() if following else len(text)", "end = len(text)", "The preset script changes the presets after the one it was told"),
 ("M147", "export_presets.cfg", "application/modify_resources=true", "application/modify_resources=false", "The Windows exe shows Godot's robot instead of the app icon"),
 ("M148", "packaging/linux/io.github.r0madeus.JustSudoku.svg", "fill=\"#2563eb\"", "fill=\"#0e1117\"", "The Linux menu icon is not the app icon"),
 ("M149", "scenes/ui/game_action_dock.gd", "	minimum_size_changed.connect(_on_minimum_size_changed)\n", "", "A dock fitted before the fonts or theme settled stays labelled and hangs out of the screen"),
 ("M150", ".github/workflows/windows.yml", "    branches: [main]\n    tags: [\"v*\"]", "    tags: [\"v*\"]", "The Windows engine is built again for every pull request and the release"),
 ("M151", "scenes/gameplay/dialogs/solution_dialog.gd", "	if natural > room:\n		_nav_compact = true", "	if false:\n		_nav_compact = true", "The solution viewer is wider on the step tab, in Turkish"),
 ("M152", "scenes/ui/segmented_control.gd", "(plain[c] as Color).lerp(Color.WHITE, cover)", "(plain[c] as Color)", "The tab labels do not change colour with the pill"),
 ("M153", "scenes/ui/segmented_control.gd", "		ThemeManager.RADIUS_CAPSULE,\n		ThemeManager.BORDER_HAIRLINE,\n		border_col,", "		ThemeManager.RADIUS_PILL_SM,\n		ThemeManager.BORDER_HAIRLINE,\n		border_col,", "The tabs' track is a rounded rectangle around a capsule pill"),
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
