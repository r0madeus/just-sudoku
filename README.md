# Just Sudoku

**A calm, focused Sudoku: no ads, no account, no internet, nothing collected. Free and open source.**

[![Tests](https://github.com/r0madeus/just-sudoku/actions/workflows/tests.yml/badge.svg)](https://github.com/r0madeus/just-sudoku/actions/workflows/tests.yml)
[![Android APK](https://github.com/r0madeus/just-sudoku/actions/workflows/android.yml/badge.svg)](https://github.com/r0madeus/just-sudoku/actions/workflows/android.yml)
[![License: GPL v3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)

[Türkçe](README.tr.md)

<p>
  <img src="docs/screenshots/en_menu.png" width="200" alt="Main menu">
  <img src="docs/screenshots/en_game.png" width="200" alt="A game in progress, with notes and a wrong digit marked">
  <img src="docs/screenshots/en_result.png" width="200" alt="Puzzle solved, with new achievements">
  <img src="docs/screenshots/en_statistics.png" width="200" alt="Statistics">
</p>

## Features

**Puzzles**
- Four levels (Easy, Medium, Hard, Expert), rated by the techniques a person needs to solve them: from Naked Singles to X-Wing, Swordfish, XYZ-Wing, Simple Coloring and XY-Chain. Every puzzle has exactly one solution and can be solved by logic alone, without guessing, so a hint can always explain the next step.
- A new puzzle opens at once. Medium, Hard and Expert come from a bank of puzzles rated in advance, each shown in a different disguise (digits relabelled, rows and columns shuffled), which keeps its difficulty exactly.
- **Daily Sudoku**: the same puzzle for everyone each day, with a streak.
- Replay any puzzle from your history, or share it as a number or an 81-character code and import someone else's.

**Solving**
- Notes, with *Fill notes*, automatic note removal and optional smart candidates.
- Undo and redo, a number pad that dims the digits that cannot go in the selected cell, and clash highlighting.
- Hints in three steps: where to look, which technique, then the move itself. A step-by-step solution viewer when you are stuck.
- Check the board, or have wrong digits shown as you place them.

**Progress**
- A score out of 100 for each solve (time, mistakes, hints), with your record and average at each level.
- History with filters, statistics per level, and 13 quiet achievements.
- Unfinished games are saved as you play, and several can be kept side by side.

**For everyone**
- Five themes (Dark, AMOLED, Light, Sepia, Forest) plus your own colours; three typefaces.
- Text size setting; wrong digits are marked by shape as well as colour, for colour-blind players; the text in every built-in theme meets WCAG AA contrast.
- English and Turkish.
- Phone and tablet layouts, including side-by-side layouts on a tablet in landscape.

<p>
  <img src="docs/screenshots/en_game_light.png" width="200" alt="Light theme">
  <img src="docs/screenshots/en_settings.png" width="200" alt="Settings">
</p>
<img src="docs/screenshots/en_tablet_statistics.jpg" width="620" alt="Statistics on a tablet in landscape">

## Privacy

Just Sudoku asks for no permission except vibration. It has no internet permission at all, so it cannot send anything anywhere: no ads, no analytics, no account. Your games, history and settings stay on your device (Android backup is off as well). To move a game to another device, export it and import it there.

## Download

Version 0.1.0; not yet in an app store.

- **Test APK (Android 7.0 and up, 64-bit ARM):** open the latest successful run of [Android APK (slim engine)](https://github.com/r0madeus/just-sudoku/actions/workflows/android.yml) and download `JustSudoku-slim-apk` under *Artifacts* (you need to be signed in to GitHub). It is signed with a test key: for installing and trying out, not for the Play Store.
- Installing it on a phone, and a checklist of what to try: [docs/android.md](docs/android.md).

## Building from source

1. Install [Godot 4.7](https://godotengine.org/download/archive/) (the standard build; the project uses the Compatibility renderer).
2. Open `project.godot` in Godot and press *Run*. It runs on Linux, Windows and macOS as well, which is handy for development.
3. For Android, export from *Project → Export → Android*; setup and signing are in [docs/android.md](docs/android.md).

The Android build uses a Godot export template built with only what the game needs ([engine/custom.py](engine/custom.py)): no 3D, physics, Vulkan or unused modules. That halves the APK, from 28.2 MB to 14.5 MB. GitHub builds the template and the APK automatically; how to build it yourself is in [docs/android.md](docs/android.md#küçültülmüş-motor-daha-küçük-apk).

## Tests

```
GODOT=/path/to/godot tools/run_tests.sh
```

Runs all 44 test suites, four at a time, each with its own empty save folder (under a minute). They also run on every pull request. [docs/testing.md](docs/testing.md) explains them, and how `tools/mutation_audit.py` checks that the tests really catch mistakes: it breaks 28 behaviours one at a time and all 28 are caught.

## Project layout

| Folder | What is in it |
|---|---|
| `scripts/core/` | Sudoku itself: board, solver, generator, difficulty rating |
| `scripts/gameplay/` | A game in progress: moves, hints, undo, timer, score |
| `scripts/data/` | Saved games, history, statistics, Daily Sudoku, achievements |
| `scripts/services/` | Theme, fonts, translations, layout, sound, sharing |
| `scenes/` | Screens and UI components (built in code) |
| `assets/` | Fonts, icons, app icon |
| `tests/` | The test suites |
| `engine/` | The slimmed Godot build profile for Android |
| `tools/` | Test runner, mutation audit, README screenshots |
| `docs/` | Android, testing and these screenshots |

The design document, `Just Sudoku GDD.md`, is in Turkish. `addons/godot_mcp/` is an editor add-on used during development; it is not part of the game.

## Contributing

Issues and pull requests are welcome. Please keep to what makes the game what it is: calm, offline, no ads or tracking. A change comes with tests (and the suites pass), and new text comes in both English and Turkish.

## License

Just Sudoku is free software under the [GNU General Public License v3.0](LICENSE).

It uses:
- [Godot Engine](https://godotengine.org) (MIT)
- The fonts [Inter](https://rsms.me/inter/), [Nunito](https://github.com/googlefonts/nunito), [Source Serif 4](https://github.com/adobe-fonts/source-serif) and [IBM Plex Mono](https://github.com/IBM/plex), under the SIL Open Font License ([assets/fonts/licenses](assets/fonts/licenses))
- [Lucide](https://lucide.dev) icons (ISC, [assets/icons/LICENSE-lucide.txt](assets/icons/LICENSE-lucide.txt))
