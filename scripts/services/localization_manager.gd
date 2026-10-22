class_name LocalizationManager
extends Node

## Localization & Internationalization Manager (GDD §44, §49)
## Integrates Godot TranslationServer with dynamic runtime UI hot-swapping.

const LOCALE_TR: String = "tr"
const LOCALE_EN: String = "en"
const SUPPORTED_LOCALES: Array[String] = [LOCALE_TR, LOCALE_EN]

const LOCALE_NAMES: Dictionary = {
	LOCALE_TR: "Türkçe",
	LOCALE_EN: "English"
}

static var current_locale: String = LOCALE_TR
static var _listeners: Array[Callable] = []
static var _initialized: bool = false

# In-memory dictionary for 100% reliable translations across headless tests and runtime
static var DICTIONARY_EN: Dictionary = {
	"KEY_APP_TITLE": "Just Sudoku",
	"KEY_APP_SUBTITLE": "Just Sudoku. But done right.",
	"BTN_CONTINUE": "Continue",
	"BTN_NEW_GAME": "New Game",
	"BTN_LOAD_GAME": "Saved Games",
	"BTN_DAILY_SUDOKU": "Daily Sudoku",
	"BTN_DAILY_COMPLETED": "Completed",
	"BTN_HISTORY": "History",
	"BTN_STATS": "Statistics",
	"BTN_SETTINGS": "Settings",
	"BTN_BACK": "Back",
	"BTN_MENU": "Menu",
	"BTN_START": "Start",
	"BTN_CANCEL": "Cancel",
	"BTN_CLOSE": "Close",
	"BTN_APPLY": "Apply",
	"BTN_PLAY": "Play",
	"BTN_DELETE": "Delete",
	"BTN_SHARE": "Share",
	"BTN_IMPORT": "Import",
	"BTN_PASTE": "Paste from Clipboard",
	"BTN_CLEAR": "Clear",
	"BTN_REPLAY": "Solve Again",
	"DIFF_EASY": "Easy",
	"DIFF_MEDIUM": "Medium",
	"DIFF_HARD": "Hard",
	"DIFF_EXPERT": "Expert",
	"DIFF_ALL": "All",
	"DIFF_SELECT_PROMPT": "Difficulty",
	"BTN_UNDO": "Undo",
	"BTN_REDO": "Redo",
	"BTN_NOTES": "Notes",
	"BTN_NOTES_ON": "Notes: On",
	"BTN_ERASE": "Erase",
	"BTN_CHECK": "Check",
	"BTN_HINT": "Hint",
	"PAUSE_TITLE": "Paused",
	"BTN_RESUME": "Resume",
	"BTN_SHARE_PUZZLE": "Share Puzzle",
	"BTN_COPY_SAVE": "Export Game",
	"TOAST_PUZZLE_COPIED": "Puzzle copied. Paste it anywhere to share it.",
	"TOAST_SAVE_COPIED": "Game copied. Open it on another device with Import.",
	"HINT_DIALOG_TITLE": "Hint",
	"HINT_APPLY_MOVE": "Apply Move",
	"CELL_COORD": "R%dC%d",
	"UNIT_ROW": "Row %d",
	"UNIT_COL": "Column %d",
	"UNIT_BOX": "Box %d",
	"EXPL_FULL_HOUSE": "%s already has 8 digits; its last empty cell, %s, can only be %d.",
	"EXPL_NAKED_SINGLE": "Looking at the row, column and box of %s, the only digit it can take is %d.",
	"EXPL_HIDDEN_SINGLE": "In %s, the digit %d fits in only one cell: %s.",
	"EXPL_DIRECT": "No standard technique applies to the board right now. The solution for %s is %d.",
	"EXPL_DEDUCTION": "Once the other candidates for %s are ruled out, %d is the only value left.",
	"EXPL_POINTING_ROW": "In %s, the digit %d can only go in one row, so %d is removed from the rest of that row.",
	"EXPL_POINTING_COL": "In %s, the digit %d can only go in one column, so %d is removed from the rest of that column.",
	"EXPL_CLAIMING": "In %s, the digit %d can only go in one box, so %d is removed from that box's other cells.",
	"EXPL_NAKED_PAIR": "%s and %s can only hold {%d, %d}, so these two digits are removed from the other cells they share a row, column or box with.",
	"EXPL_HIDDEN_PAIR": "In this area {%d, %d} can only go in %s and %s, so the other candidates in those two cells are removed.",
	"EXPL_NAKED_TRIPLE": "%s, %s and %s only hold {%s} between them, so these digits are removed from the area's other cells.",
	"EXPL_HIDDEN_TRIPLE": "In this area {%d, %d, %d} can only go in three cells, so the other candidates in those cells are removed.",
	"EXPL_X_WING_ROWS": "The %d candidates in rows %d and %d form an X-Wing, so %d is removed from the rest of columns %d and %d.",
	"EXPL_X_WING_COLS": "The %d candidates in columns %d and %d form an X-Wing, so %d is removed from the rest of rows %d and %d.",
	"EXPL_XY_WING": "%s (pivot) with %s and %s (wings) form an XY-Wing, so %d is removed from cells that see both wings.",
	"EXPL_XYZ_WING": "With %s as the pivot, an XYZ-Wing removes %d from the cells that see all three.",
	"EXPL_SWORDFISH": "The %d candidates in rows %d, %d and %d form a Swordfish, so the other candidates in those columns are removed.",
	"HINT_FOCUS_TEXT": "Look closely at this area: %s. The next logical step is there.\n\nNeed more? The next level names the technique.",
	"HINT_SHOW_TECHNIQUE": "Show Technique",
	"WIN_DIALOG_TITLE": "Puzzle Solved!",
	"CHECK_ALL_CORRECT": "All digits are correct.",
	"CHECK_MISTAKES_FOUND": "%d wrong digits marked in red.",
	"CHECK_MISTAKES_FOUND_ONE": "%d wrong digit marked in red.",
	"NEW_GAME_TITLE": "New Game",
	"LOADING_PUZZLE": "Preparing a %s puzzle…",
	"SEED_LABEL": "Puzzle No. %d",
	"ESTIMATED_TIME": "Estimated time: about %d min",
	"KEY_TECHNIQUES": "Techniques: %s",
	"BTN_COPY_SEED": "Copy",
	"BTN_REGEN_SEED": "Another Puzzle",
	"BTN_IMPORT_NEW_GAME": "Open a Shared Puzzle",
	"COPIED_FEEDBACK": "Copied",
	"IMPORT_DIALOG_TITLE": "Import",
	"IMPORT_INSTRUCTION": "Paste a puzzle number, an 81-character puzzle code or an exported game:",
	"IMPORT_PLACEHOLDER": "E.g. 123456789 or 53..7....6..195...",
	"BTN_START_IMPORTED": "Start",
	"STATUS_VALID_PUZZLE": "Valid puzzle code (%d starting digits)",
	"STATUS_VALID_SEED": "Puzzle No. %d",
	"STATUS_VALID_SAVE": "Exported game (%s • %s)",
	"ERROR_EMPTY_INPUT": "Paste a puzzle number, puzzle code or exported game.",
	"ERROR_INVALID_INPUT": "This doesn't look like a puzzle number, puzzle code or exported game.",
	"SETTINGS_TITLE": "Settings",
	"SETTINGS_SEC_APPEARANCE": "Appearance",
	"SETTINGS_SEC_GAMEPLAY": "Gameplay",
	"SETTINGS_SEC_FEEDBACK": "Feedback & Sound",
	"THEME_GROUP_BOARD": "Board & Surfaces",
	"THEME_GROUP_NUMBERS": "Numbers & Accents",
	"SETTING_LANGUAGE": "Language / Dil",
	"SETTING_THEME": "Theme",
	"SETTING_FONT": "Font",
	"FONT_MODERN_SANS": "Modern",
	"FONT_ROUNDED_SANS": "Rounded",
	"FONT_CLASSIC_SERIF": "Classic",
	"SETTING_AUTO_OPEN": "Resume last game on launch",
	"SETTING_SMART_NUMPAD": "Smart numpad",
	"SETTING_AUTO_NOTES": "Auto-remove notes",
	"SETTING_SMART_CANDIDATES": "Smart candidates",
	"SETTING_SHOW_CONFLICTS": "Highlight conflicts",
	"SETTING_ANIMATIONS": "Animations",
	"SETTING_SOUNDS": "Sounds",
	"STATS_TITLE": "Statistics",
	"STAT_COMPLETED_GAMES": "Completed Games",
	"STAT_CURRENT_STREAK": "Daily Streak",
	"STAT_LONGEST_STREAK": "Longest Streak",
	"STAT_BEST_SCORE": "Best Score",
	"STAT_AVG_TIME": "Average Time",
	"STAT_PERF_BY_DIFF": "Performance by Difficulty",
	"STAT_GAMES_COUNT": "%d games completed",
	"STAT_GAMES_COUNT_ONE": "%d game completed",
	"STAT_AVG_MISTAKES": "Avg. Mistakes: %.1f",
	"STAT_BEST_TIME": "Best Time: %s",
	"STAT_DAYS": "%d Days",
	"STAT_DAYS_ONE": "%d Day",
	"HISTORY_TITLE": "History",
	"HISTORY_DIFF_FILTER": "Difficulty",
	"HISTORY_SORT_FILTER": "Sort",
	"SORT_NEWEST": "Newest",
	"SORT_OLDEST": "Oldest",
	"SORT_FASTEST": "Fastest",
	"SORT_BEST_SCORE": "Best Score",
	"HISTORY_RECORD_INFO": "Date: %s • Time: %s • Mistakes: %d • Hints: %d • Score: %d",
	"SAVED_GAMES_TITLE": "Saved Games",
	"NO_ACTIVE_GAMES": "No unfinished games. Start a new one from the menu.",
	"PROGRESS_LABEL": "Progress: %s",
	"RESUME_PROGRESS": "%d%% filled",
	"RESUME_EMPTY_TITLE": "Ready to play",
	"RESUME_EMPTY_BODY": "Start a new puzzle or try today's Daily Sudoku.",
	"TECH_FULL_HOUSE": "Full House",
	"TECH_NAKED_SINGLE": "Naked Single",
	"TECH_HIDDEN_SINGLE": "Hidden Single",
	"TECH_LOCKED_CANDIDATES": "Locked Candidates",
	"TECH_NAKED_PAIR": "Naked Pair",
	"TECH_HIDDEN_PAIR": "Hidden Pair",
	"TECH_NAKED_TRIPLE": "Naked Triple",
	"TECH_HIDDEN_TRIPLE": "Hidden Triple",
	"TECH_X_WING": "X-Wing",
	"TECH_SWORDFISH": "Swordfish",
	"TECH_XY_WING": "XY-Wing",
	"TECH_XYZ_WING": "XYZ-Wing",
	"TECH_BACKTRACKING": "Direct Solution",
	"Full House": "Full House",
	"Naked Single": "Naked Single",
	"Hidden Single": "Hidden Single",
	"Locked Candidates": "Locked Candidates",
	"Naked Pair": "Naked Pair",
	"Hidden Pair": "Hidden Pair",
	"Naked Triple": "Naked Triple",
	"Hidden Triple": "Hidden Triple",
	"Logical Guess / Backtracking": "Direct Solution",
	"Solution Hint": "Direct Solution",
	"STAT_COMPLETION_RATE": "Completion Rate",
	"STAT_DAILY_STREAK_BANNER": "Daily Sudoku Streak",
	"STAT_DAILY_STREAK_DESC": "Solve the Daily Sudoku every day to keep your streak.",
	"STATS_SUBTITLE": "Performance summary, completion rates, and records.",
	"STAT_NO_GAMES_YET": "No solved puzzles yet. Solve one and your stats will show up here.",
	"STAT_ALL_TIME": "Overview",
	"STAT_STREAKS": "Daily Streaks",
	"STAT_DIFFICULTIES": "By Difficulty",
	"THEME_DARK": "Dark",
	"THEME_AMOLED": "AMOLED Black",
	"THEME_LIGHT": "Light",
	"THEME_SEPIA": "Sepia",
	"THEME_FOREST": "Forest",
	"THEME_CUSTOM": "Custom Theme",
	"CUSTOM_THEME_TITLE": "Custom Theme",
	"BTN_EDIT_CUSTOM_THEME": "Customize Theme",
	"PREVIEW_MINI_GRID": "Preview",
	"COLOR_BG": "Background",
	"COLOR_GRID": "Grid Lines",
	"COLOR_CELL": "Cell Background",
	"COLOR_SELECTED": "Selected Cell",
	"COLOR_TEXT_GIVEN": "Starting Digits",
	"COLOR_TEXT_USER": "Your Digits",
	"COLOR_ACCENT": "Accent Color",
	"COLOR_ERROR": "Mistakes",
	"COLOR_NOTES": "Notes",
	"PRESET_BASE_PROMPT": "Start from:",
	"BTN_SAVE_APPLY": "Save & Apply",
	"BTN_SOLUTION": "Show Solution",
	"BTN_FULL_SOLUTION": "Full Solution",
	"BTN_STEP_BY_STEP": "Step-by-Step",
	"BTN_APPLY_SOLUTION": "Apply to Board",
	"STEP_COUNTER": "Step %d / %d",
	"STEP_INITIAL_BOARD": "Start",
	"STEP_INITIAL_DESC": "The starting digits. Press Next to go through the solution step by step.",
	"SOLUTION_TITLE": "Puzzle Solution",
	"SOLUTION_APPLY_CONFIRM": "Fill in the whole solution? The puzzle will count as solved with help.",
	"BTN_FIRST_STEP": "First",
	"BTN_PREV_STEP": "Prev",
	"BTN_NEXT_STEP": "Next",
	"BTN_LAST_STEP": "Last",
	"SOLUTION_SUMMARY_GIVENS": "Starting digits: %d",
	"SOLUTION_SUMMARY_SOLVED": "Solved cells: %d",
	"SOLUTION_UNIQUE_VERIFIED": "Unique solution verified",
	"BTN_MASTER_AGAIN": "Solve Again",
	"BADGE_REPLAY": "Replay",
	"HISTORY_STATUS_FILTER": "Status",
	"STATUS_ALL": "All",
	"STATUS_STANDARD": "Standard",
	"STATUS_REPLAY": "Replay",
	"SCORE_BEST_COMPARISON": "Your best: %d • This solve: %d",
	"NEW_BEST_SCORE": "New best score!",
	"SETTING_DESC_LANGUAGE": "Display language",
	"SETTING_DESC_THEME": "App color palette",
	"SETTING_DESC_CUSTOM_THEME": "Pick your own colors",
	"SETTING_DESC_FONT": "Typography and digit style",
	"SETTING_DESC_AUTO_OPEN": "Opens your unfinished game straight away",
	"SETTING_DESC_SMART_NUMPAD": "Dims digits that can't go in the selected cell",
	"SETTING_DESC_AUTO_NOTES": "Clears matching notes in the same row, column and box when you place a digit",
	"SETTING_DESC_SMART_CANDIDATES": "Shows every valid candidate in empty cells",
	"SETTING_DESC_SHOW_CONFLICTS": "Marks duplicate digits in red right away",
	"SETTING_SHOW_WRONG": "Show wrong digits right away",
	"SETTING_DESC_SHOW_WRONG": "Marks a digit that does not match the solution as soon as you place it; each one counts as a mistake",
	"BTN_FILL_NOTES": "Fill notes",
	"SETTING_DESC_ANIMATIONS": "Cell pops, screen transitions and the victory wave",
	"SETTING_DESC_SOUNDS": "Taps, mistakes and completion sounds",
	"SETTING_HAPTICS": "Vibration",
	"SETTING_DESC_HAPTICS": "Short vibrations on taps, mistakes and completions",
	"DAILY_SUBTITLE": "Daily handcrafted puzzle",
	"DAILY_PREPARING": "Preparing…",
	"DAILY_STREAK_FORMAT": "Streak: %d Days",
	"DAILY_STREAK_FORMAT_ONE": "Streak: %d Day",
	"SUBTITLE_CALM": "Calm, focused Sudoku",
	"STATS_OVERVIEW": "Overview",
	"STATS_BY_DIFFICULTY": "By Difficulty",
	"STAT_BEST_TIME_LABEL": "Best Time",
	"STAT_AVG_TIME_LABEL": "Average Time",
	"STAT_BEST_SCORE_LABEL": "Best Score",
	"STAT_AVG_MISTAKES_LABEL": "Average Mistakes",
	"STAT_AVG_HINTS_LABEL": "Average Hints",
	"HISTORY_EMPTY": "No solved puzzles yet.",
	"RECORD_SCORE": "Score: %d",
	"RECORD_BEST_SCORE": "(Best: %d)",
	"RECORD_TIME": "Time: %s",
	"RECORD_MISTAKES": "Mistakes: %d",
	"RECORD_HINTS": "Hints: %d",
	"BTN_REPLAY_ACTION": "Solve Again",
	"THEME_SYSTEM": "System (Auto)",
	"SHARE_CARD_HEADER": "Just Sudoku",
	"SHARE_DIFF_LABEL": "Difficulty",
	"SHARE_SEED_LABEL": "Puzzle No",
	"SHARE_CODE_LABEL": "Puzzle code",
	"SHARE_INFO_SAVE": "Exported game (%s, time %s, progress %s).",
	"SHARE_ERR_SAVE": "This exported game is damaged and can't be opened.",
	"SHARE_ERR_CONFLICT": "This puzzle breaks the rules: a digit repeats in a row, column or box (%d conflicts).",
	"SHARE_ERR_CONFLICT_ONE": "This puzzle breaks the rules: a digit repeats in a row, column or box (%d conflict).",
	"SHARE_ERR_NO_UNIQUE": "This puzzle doesn't have exactly one solution.",
	"SHARE_INFO_CODE": "Valid puzzle code (%s, difficulty score %d).",
	"SHARE_INFO_SEED": "Puzzle No. %d (%s).",
	"SHARE_ERR_UNKNOWN": "This doesn't look like a puzzle number, puzzle code or exported game.",
	"PUZZLE_NUMBER": "No. %d",
	"DELETE_GAME_TITLE": "Delete This Game?",
	"DELETE_GAME_BODY": "Your progress in this puzzle will be lost. This can't be undone.",
	"BTN_NEW_SAME_LEVEL": "New %s Puzzle",
	"RESULT_SCORE": "Score",
	"RESULT_TIME": "Time",
	"RESULT_MISTAKES": "Mistakes",
	"RESULT_HINTS": "Hints",
	"RESULT_FIRST_AT_LEVEL": "Your first solve at this level.",
	"RESULT_FASTEST": "Your fastest solve at this level!",
	"RESULT_FASTER_THAN_AVG": "%s faster than your average",
	"RESULT_SLOWER_THAN_AVG": "%s slower than your average",
	"RESULT_ON_AVG": "Right on your average",
	"RESULT_ASSISTED": "Finished by showing the solution.",
	"RESULT_DAILY": "Daily Sudoku done • %s",
	"DURATION_MIN_SEC": "%d min %d s",
	"DURATION_MIN": "%d min",
	"DURATION_SEC": "%d s",
	"BTN_MORE_ACTIONS": "More"
}

static var DICTIONARY_TR: Dictionary = {
	"KEY_APP_TITLE": "Just Sudoku",
	"KEY_APP_SUBTITLE": "Sadece Sudoku. Ama doğru yapılmış.",
	"BTN_CONTINUE": "Devam Et",
	"BTN_NEW_GAME": "Yeni Oyun",
	"BTN_LOAD_GAME": "Kayıtlı Oyunlar",
	"BTN_DAILY_SUDOKU": "Günün Sudokusu",
	"BTN_DAILY_COMPLETED": "Tamamlandı",
	"BTN_HISTORY": "Geçmiş",
	"BTN_STATS": "İstatistikler",
	"BTN_SETTINGS": "Ayarlar",
	"BTN_BACK": "Geri",
	"BTN_MENU": "Menü",
	"BTN_START": "Başla",
	"BTN_CANCEL": "İptal",
	"BTN_CLOSE": "Kapat",
	"BTN_APPLY": "Uygula",
	"BTN_PLAY": "Oyna",
	"BTN_DELETE": "Sil",
	"BTN_SHARE": "Paylaş",
	"BTN_IMPORT": "İçe Aktar",
	"BTN_PASTE": "Panodan Yapıştır",
	"BTN_CLEAR": "Temizle",
	"BTN_REPLAY": "Yeniden Çöz",
	"DIFF_EASY": "Kolay",
	"DIFF_MEDIUM": "Orta",
	"DIFF_HARD": "Zor",
	"DIFF_EXPERT": "Uzman",
	"DIFF_ALL": "Tümü",
	"DIFF_SELECT_PROMPT": "Zorluk",
	"BTN_UNDO": "Geri Al",
	"BTN_REDO": "İleri Al",
	"BTN_NOTES": "Not",
	"BTN_NOTES_ON": "Not: Açık",
	"BTN_ERASE": "Sil",
	"BTN_CHECK": "Kontrol Et",
	"BTN_HINT": "İpucu",
	"PAUSE_TITLE": "Duraklatıldı",
	"BTN_RESUME": "Devam Et",
	"BTN_SHARE_PUZZLE": "Bulmacayı Paylaş",
	"BTN_COPY_SAVE": "Oyunu Dışa Aktar",
	"TOAST_PUZZLE_COPIED": "Bulmaca kopyalandı. Paylaşmak için istediğin yere yapıştır.",
	"TOAST_SAVE_COPIED": "Oyun kopyalandı. Başka bir cihazda İçe Aktar ile açabilirsin.",
	"HINT_DIALOG_TITLE": "İpucu",
	"HINT_APPLY_MOVE": "Hamleyi Uygula",
	"CELL_COORD": "%d. satır %d. sütun",
	"UNIT_ROW": "%d. satır",
	"UNIT_COL": "%d. sütun",
	"UNIT_BOX": "%d. kutu",
	"EXPL_FULL_HOUSE": "%s içinde 8 rakam yerleşmiş; kalan son boş hücreye (%s) yalnızca %d gelebilir.",
	"EXPL_NAKED_SINGLE": "%s hücresinin satırı, sütunu ve kutusu incelendiğinde yazılabilecek tek rakam %d.",
	"EXPL_HIDDEN_SINGLE": "%s içinde %d sayısının gelebileceği tek yer %s hücresi.",
	"EXPL_DIRECT": "Tahtanın şu anki durumunda standart bir teknik uygulanamıyor. %s hücresinin çözümü %d.",
	"EXPL_DEDUCTION": "%s hücresi için diğer adaylar elendiğinde geriye kalan tek değer %d.",
	"EXPL_POINTING_ROW": "%s içinde %d sayısı yalnızca tek bir satıra gelebiliyor; bu yüzden o satırın geri kalanından %d adayı silinir.",
	"EXPL_POINTING_COL": "%s içinde %d sayısı yalnızca tek bir sütuna gelebiliyor; bu yüzden o sütunun geri kalanından %d adayı silinir.",
	"EXPL_CLAIMING": "%s içinde %d sayısı yalnızca tek bir kutuya gelebiliyor; bu yüzden o kutunun diğer hücrelerinden %d adayı silinir.",
	"EXPL_NAKED_PAIR": "%s ve %s hücrelerine yalnızca {%d, %d} gelebiliyor; bu iki sayı ortak satır, sütun ya da kutudaki diğer hücrelerden silinir.",
	"EXPL_HIDDEN_PAIR": "Bu bölgede {%d, %d} yalnızca %s ve %s hücrelerine gelebiliyor; bu iki hücredeki diğer adaylar silinir.",
	"EXPL_NAKED_TRIPLE": "%s, %s ve %s hücrelerine yalnızca {%s} gelebiliyor; bu sayılar bölgenin diğer hücrelerinden silinir.",
	"EXPL_HIDDEN_TRIPLE": "Bu bölgede {%d, %d, %d} yalnızca üç hücreye gelebiliyor; o hücrelerdeki diğer adaylar silinir.",
	"EXPL_X_WING_ROWS": "%d adayları %d. ve %d. satırda X-Wing oluşturuyor; bu yüzden %d adayı %d. ve %d. sütunların geri kalanından silinir.",
	"EXPL_X_WING_COLS": "%d adayları %d. ve %d. sütunda X-Wing oluşturuyor; bu yüzden %d adayı %d. ve %d. satırların geri kalanından silinir.",
	"EXPL_XY_WING": "%s (pivot) ile %s ve %s (kanatlar) XY-Wing oluşturuyor; iki kanadı da gören hücrelerden %d silinir.",
	"EXPL_XYZ_WING": "%s hücresi pivot olan bir XYZ-Wing, üçünü de gören hücrelerden %d sayısını siler.",
	"EXPL_SWORDFISH": "%d adayları %d., %d. ve %d. satırda Swordfish oluşturuyor; bu sütunlardaki diğer adaylar silinir.",
	"HINT_FOCUS_TEXT": "Şu bölgeye dikkatlice bak: %s. Sıradaki mantıksal adım orada.\n\nDaha fazlası gerekirse sonraki kademe tekniği söyler.",
	"HINT_SHOW_TECHNIQUE": "Tekniği Göster",
	"WIN_DIALOG_TITLE": "Bulmaca Çözüldü!",
	"CHECK_ALL_CORRECT": "Tüm rakamlar doğru.",
	"CHECK_MISTAKES_FOUND": "%d yanlış rakam kırmızıyla işaretlendi.",
	"NEW_GAME_TITLE": "Yeni Oyun",
	"LOADING_PUZZLE": "%s bulmaca hazırlanıyor…",
	"SEED_LABEL": "Bulmaca No. %d",
	"ESTIMATED_TIME": "Tahmini süre: yaklaşık %d dk",
	"KEY_TECHNIQUES": "Teknikler: %s",
	"BTN_COPY_SEED": "Kopyala",
	"BTN_REGEN_SEED": "Başka Bulmaca",
	"BTN_IMPORT_NEW_GAME": "Paylaşılan Bulmacayı Aç",
	"COPIED_FEEDBACK": "Kopyalandı",
	"IMPORT_DIALOG_TITLE": "İçe Aktar",
	"IMPORT_INSTRUCTION": "Bulmaca numarası, 81 karakterlik bulmaca kodu ya da dışa aktarılmış bir oyun yapıştır:",
	"IMPORT_PLACEHOLDER": "Örn. 123456789 ya da 53..7....6..195...",
	"BTN_START_IMPORTED": "Başla",
	"STATUS_VALID_PUZZLE": "Geçerli bulmaca kodu (%d başlangıç rakamı)",
	"STATUS_VALID_SEED": "Bulmaca No. %d",
	"STATUS_VALID_SAVE": "Dışa aktarılmış oyun (%s • %s)",
	"ERROR_EMPTY_INPUT": "Bir bulmaca numarası, bulmaca kodu ya da dışa aktarılmış oyun yapıştır.",
	"ERROR_INVALID_INPUT": "Bu bir bulmaca numarası, bulmaca kodu ya da dışa aktarılmış oyun gibi görünmüyor.",
	"SETTINGS_TITLE": "Ayarlar",
	"SETTINGS_SEC_APPEARANCE": "Görünüm",
	"SETTINGS_SEC_GAMEPLAY": "Oynanış",
	"SETTINGS_SEC_FEEDBACK": "Geri Bildirim ve Ses",
	"THEME_GROUP_BOARD": "Tahta ve Yüzeyler",
	"THEME_GROUP_NUMBERS": "Sayılar ve Vurgular",
	"SETTING_LANGUAGE": "Dil / Language",
	"SETTING_THEME": "Tema",
	"SETTING_FONT": "Yazı tipi",
	"FONT_MODERN_SANS": "Modern",
	"FONT_ROUNDED_SANS": "Yuvarlak",
	"FONT_CLASSIC_SERIF": "Klasik",
	"SETTING_AUTO_OPEN": "Son oyunu açılışta sürdür",
	"SETTING_SMART_NUMPAD": "Akıllı tuş takımı",
	"SETTING_AUTO_NOTES": "Notları otomatik sil",
	"SETTING_SMART_CANDIDATES": "Akıllı adaylar",
	"SETTING_SHOW_CONFLICTS": "Çakışmaları vurgula",
	"SETTING_ANIMATIONS": "Animasyonlar",
	"SETTING_SOUNDS": "Sesler",
	"STATS_TITLE": "İstatistikler",
	"STAT_COMPLETED_GAMES": "Tamamlanan Oyunlar",
	"STAT_CURRENT_STREAK": "Günlük Seri",
	"STAT_LONGEST_STREAK": "En Uzun Seri",
	"STAT_BEST_SCORE": "En İyi Skor",
	"STAT_AVG_TIME": "Ortalama Süre",
	"STAT_PERF_BY_DIFF": "Zorluk Bazında Performans",
	"STAT_GAMES_COUNT": "%d oyun tamamlandı",
	"STAT_AVG_MISTAKES": "Ort. Hata: %.1f",
	"STAT_BEST_TIME": "En İyi Süre: %s",
	"STAT_DAYS": "%d Gün",
	"HISTORY_TITLE": "Geçmiş",
	"HISTORY_DIFF_FILTER": "Zorluk",
	"HISTORY_SORT_FILTER": "Sıralama",
	"SORT_NEWEST": "En Yeni",
	"SORT_OLDEST": "En Eski",
	"SORT_FASTEST": "En Hızlı",
	"SORT_BEST_SCORE": "En İyi Skor",
	"HISTORY_RECORD_INFO": "Tarih: %s • Süre: %s • Hata: %d • İpucu: %d • Skor: %d",
	"SAVED_GAMES_TITLE": "Kayıtlı Oyunlar",
	"NO_ACTIVE_GAMES": "Yarım kalmış oyun yok. Menüden yeni bir oyun başlatabilirsin.",
	"PROGRESS_LABEL": "İlerleme: %s",
	"RESUME_PROGRESS": "%%%d dolu",
	"RESUME_EMPTY_TITLE": "Başlamaya hazır",
	"RESUME_EMPTY_BODY": "Yeni bir bulmaca başlat ya da Günün Sudokusu'nu dene.",
	"TECH_FULL_HOUSE": "Son Hücre",
	"TECH_NAKED_SINGLE": "Açık Tekli",
	"TECH_HIDDEN_SINGLE": "Gizli Tekli",
	"TECH_LOCKED_CANDIDATES": "Kilitli Adaylar",
	"TECH_NAKED_PAIR": "Açık İkili",
	"TECH_HIDDEN_PAIR": "Gizli İkili",
	"TECH_NAKED_TRIPLE": "Açık Üçlü",
	"TECH_HIDDEN_TRIPLE": "Gizli Üçlü",
	"TECH_X_WING": "X-Wing",
	"TECH_SWORDFISH": "Swordfish",
	"TECH_XY_WING": "XY-Wing",
	"TECH_XYZ_WING": "XYZ-Wing",
	"TECH_BACKTRACKING": "Doğrudan Çözüm",
	"Full House": "Son Hücre",
	"Naked Single": "Açık Tekli",
	"Hidden Single": "Gizli Tekli",
	"Locked Candidates": "Kilitli Adaylar",
	"Naked Pair": "Açık İkili",
	"Hidden Pair": "Gizli İkili",
	"Naked Triple": "Açık Üçlü",
	"Hidden Triple": "Gizli Üçlü",
	"Logical Guess / Backtracking": "Doğrudan Çözüm",
	"Solution Hint": "Doğrudan Çözüm",
	"STAT_COMPLETION_RATE": "Tamamlama Oranı",
	"STAT_DAILY_STREAK_BANNER": "Günün Sudokusu Serisi",
	"STAT_DAILY_STREAK_DESC": "Serini korumak için her gün Günün Sudokusu'nu çöz.",
	"STATS_SUBTITLE": "Performans özeti, tamamlama oranları ve rekorlar.",
	"STAT_NO_GAMES_YET": "Henüz çözülmüş bulmaca yok. Bir bulmaca çözdüğünde istatistiklerin burada görünecek.",
	"STAT_ALL_TIME": "Genel Bakış",
	"STAT_STREAKS": "Günlük Seriler",
	"STAT_DIFFICULTIES": "Zorluğa Göre",
	"THEME_DARK": "Koyu",
	"THEME_AMOLED": "AMOLED Siyah",
	"THEME_LIGHT": "Açık",
	"THEME_SEPIA": "Sepya",
	"THEME_FOREST": "Orman",
	"THEME_CUSTOM": "Özel Tema",
	"CUSTOM_THEME_TITLE": "Özel Tema",
	"BTN_EDIT_CUSTOM_THEME": "Özel Temayı Düzenle",
	"PREVIEW_MINI_GRID": "Önizleme",
	"COLOR_BG": "Arka Plan",
	"COLOR_GRID": "Izgara Çizgileri",
	"COLOR_CELL": "Hücre Arka Planı",
	"COLOR_SELECTED": "Seçili Hücre",
	"COLOR_TEXT_GIVEN": "Başlangıç Rakamları",
	"COLOR_TEXT_USER": "Senin Rakamların",
	"COLOR_ACCENT": "Vurgu Rengi",
	"COLOR_ERROR": "Hatalar",
	"COLOR_NOTES": "Notlar",
	"PRESET_BASE_PROMPT": "Şundan başla:",
	"BTN_SAVE_APPLY": "Kaydet ve Uygula",
	"BTN_SOLUTION": "Çözümü Göster",
	"BTN_FULL_SOLUTION": "Tam Çözüm",
	"BTN_STEP_BY_STEP": "Adım Adım",
	"BTN_APPLY_SOLUTION": "Çözümü Tahtaya Uygula",
	"STEP_COUNTER": "Adım %d / %d",
	"STEP_INITIAL_BOARD": "Başlangıç",
	"STEP_INITIAL_DESC": "Başlangıç rakamları. Çözümü adım adım izlemek için Sonraki'ye bas.",
	"SOLUTION_TITLE": "Bulmaca Çözümü",
	"SOLUTION_APPLY_CONFIRM": "Çözümün tamamı tahtaya yazılsın mı? Bulmaca yardımla çözülmüş sayılır.",
	"BTN_FIRST_STEP": "Başa",
	"BTN_PREV_STEP": "Önceki",
	"BTN_NEXT_STEP": "Sonraki",
	"BTN_LAST_STEP": "Sona",
	"SOLUTION_SUMMARY_GIVENS": "Başlangıç rakamı: %d",
	"SOLUTION_SUMMARY_SOLVED": "Çözülen hücre: %d",
	"SOLUTION_UNIQUE_VERIFIED": "Tek çözüm doğrulandı",
	"BTN_MASTER_AGAIN": "Yeniden Çöz",
	"BADGE_REPLAY": "Tekrar",
	"HISTORY_STATUS_FILTER": "Durum",
	"STATUS_ALL": "Tümü",
	"STATUS_STANDARD": "Standart",
	"STATUS_REPLAY": "Tekrar",
	"SCORE_BEST_COMPARISON": "En iyi skorun: %d • Bu çözüm: %d",
	"NEW_BEST_SCORE": "Yeni en iyi skor!",
	"SETTING_DESC_LANGUAGE": "Arayüz dili",
	"SETTING_DESC_THEME": "Uygulama renk paleti",
	"SETTING_DESC_CUSTOM_THEME": "Kendi renklerini seç",
	"SETTING_DESC_FONT": "Tipografi ve rakam stili",
	"SETTING_DESC_AUTO_OPEN": "Yarım kalan oyunu doğrudan açar",
	"SETTING_DESC_SMART_NUMPAD": "Seçili hücreye giremeyen rakamları soluklaştırır",
	"SETTING_DESC_AUTO_NOTES": "Rakam yazınca aynı satır, sütun ve kutudaki eşleşen notları temizler",
	"SETTING_DESC_SMART_CANDIDATES": "Boş hücrelerde geçerli tüm adayları gösterir",
	"SETTING_DESC_SHOW_CONFLICTS": "Tekrar eden rakamları hemen kırmızı yapar",
	"SETTING_SHOW_WRONG": "Yanlış rakamları hemen göster",
	"SETTING_DESC_SHOW_WRONG": "Çözümle uyuşmayan rakamı girer girmez işaretler; her biri hata sayılır",
	"BTN_FILL_NOTES": "Notları doldur",
	"SETTING_DESC_ANIMATIONS": "Hücre efektleri, ekran geçişleri ve kutlama dalgası",
	"SETTING_DESC_SOUNDS": "Dokunma, hata ve tamamlama sesleri",
	"SETTING_HAPTICS": "Titreşim",
	"SETTING_DESC_HAPTICS": "Dokunma, hata ve tamamlamada kısa titreşim",
	"DAILY_SUBTITLE": "Günün özel bulmacası",
	"DAILY_PREPARING": "Hazırlanıyor…",
	"DAILY_STREAK_FORMAT": "Seri: %d Gün",
	"SUBTITLE_CALM": "Sakin, odaklı Sudoku",
	"STATS_OVERVIEW": "Genel Bakış",
	"STATS_BY_DIFFICULTY": "Zorluğa Göre",
	"STAT_BEST_TIME_LABEL": "En İyi Süre",
	"STAT_AVG_TIME_LABEL": "Ortalama Süre",
	"STAT_BEST_SCORE_LABEL": "En İyi Skor",
	"STAT_AVG_MISTAKES_LABEL": "Ortalama Hata",
	"STAT_AVG_HINTS_LABEL": "Ortalama İpucu",
	"HISTORY_EMPTY": "Henüz çözülmüş bulmaca yok.",
	"RECORD_SCORE": "Skor: %d",
	"RECORD_BEST_SCORE": "(En İyi: %d)",
	"RECORD_TIME": "Süre: %s",
	"RECORD_MISTAKES": "Hata: %d",
	"RECORD_HINTS": "İpucu: %d",
	"BTN_REPLAY_ACTION": "Yeniden Çöz",
	"THEME_SYSTEM": "Sistem (Otomatik)",
	"SHARE_CARD_HEADER": "Just Sudoku",
	"SHARE_DIFF_LABEL": "Zorluk",
	"SHARE_SEED_LABEL": "Bulmaca No",
	"SHARE_CODE_LABEL": "Bulmaca kodu",
	"SHARE_INFO_SAVE": "Dışa aktarılmış oyun (%s, süre %s, ilerleme %s).",
	"SHARE_ERR_SAVE": "Bu dışa aktarılmış oyun bozuk, açılamıyor.",
	"SHARE_ERR_CONFLICT": "Bu bulmaca kurallara uymuyor: bir rakam satır, sütun ya da kutuda tekrar ediyor (%d çakışma).",
	"SHARE_ERR_NO_UNIQUE": "Bu bulmacanın tek ve kesin bir çözümü yok.",
	"SHARE_INFO_CODE": "Geçerli bulmaca kodu (%s, zorluk puanı %d).",
	"SHARE_INFO_SEED": "Bulmaca No. %d (%s).",
	"SHARE_ERR_UNKNOWN": "Bu bir bulmaca numarası, bulmaca kodu ya da dışa aktarılmış oyun gibi görünmüyor.",
	"PUZZLE_NUMBER": "No. %d",
	"DELETE_GAME_TITLE": "Bu Oyun Silinsin mi?",
	"DELETE_GAME_BODY": "Bu bulmacadaki ilerlemen kaybolacak. Bu işlem geri alınamaz.",
	"BTN_NEW_SAME_LEVEL": "Yeni %s Bulmaca",
	"RESULT_SCORE": "Skor",
	"RESULT_TIME": "Süre",
	"RESULT_MISTAKES": "Hata",
	"RESULT_HINTS": "İpucu",
	"RESULT_FIRST_AT_LEVEL": "Bu seviyedeki ilk çözümün.",
	"RESULT_FASTEST": "Bu seviyedeki en hızlı çözümün!",
	"RESULT_FASTER_THAN_AVG": "Ortalamandan %s hızlı",
	"RESULT_SLOWER_THAN_AVG": "Ortalamandan %s yavaş",
	"RESULT_ON_AVG": "Tam ortalamanda",
	"RESULT_ASSISTED": "Çözüm gösterilerek tamamlandı.",
	"RESULT_DAILY": "Günün Sudokusu tamam • %s",
	"DURATION_MIN_SEC": "%d dk %d sn",
	"DURATION_MIN": "%d dk",
	"DURATION_SEC": "%d sn",
	"BTN_MORE_ACTIONS": "Diğer"
}

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	var t_en := Translation.new()
	t_en.locale = LOCALE_EN
	for k in DICTIONARY_EN:
		t_en.add_message(k, DICTIONARY_EN[k])
	TranslationServer.add_translation(t_en)

	var t_tr := Translation.new()
	t_tr.locale = LOCALE_TR
	for k in DICTIONARY_TR:
		t_tr.add_message(k, DICTIONARY_TR[k])
	TranslationServer.add_translation(t_tr)

static func add_listener(cb: Callable) -> void:
	if not _listeners.has(cb):
		_listeners.append(cb)

static func remove_listener(cb: Callable) -> void:
	_listeners.erase(cb)

static func _notify_listeners() -> void:
	for cb in _listeners:
		if cb.is_valid():
			cb.call()

static func set_locale(loc: String) -> void:
	_ensure_initialized()
	var clean: String = loc.strip_edges().to_lower()
	if clean.begins_with(LOCALE_TR):
		current_locale = LOCALE_TR
	else:
		current_locale = LOCALE_EN

	TranslationServer.set_locale(current_locale)
	_notify_listeners()

static func get_locale() -> String:
	return current_locale

static func translate(key: String) -> String:
	_ensure_initialized()
	var res := TranslationServer.translate(key)
	if res != key:
		return str(res)

	# Fallback to in-memory dictionaries
	var dict: Dictionary = DICTIONARY_TR if current_locale == LOCALE_TR else DICTIONARY_EN
	if dict.has(key):
		return dict[key]
	if DICTIONARY_EN.has(key):
		return DICTIONARY_EN[key]
	return key

## Translates Difficulty level string (e.g. "Easy" -> "Kolay" in TR, "Easy" in EN)
## Any letter case, so older or imported records ("medium") read the same
static func get_difficulty_name(diff_key: String) -> String:
	match diff_key.strip_edges().to_lower():
		"easy", "kolay":
			return translate("DIFF_EASY")
		"medium", "orta":
			return translate("DIFF_MEDIUM")
		"hard", "zor":
			return translate("DIFF_HARD")
		"expert", "uzman":
			return translate("DIFF_EXPERT")
		_:
			return diff_key

## Translates technique title (e.g. "Naked Single" -> "Açık Tekli (Naked Single)" in TR)
static func get_technique_title(tech: String) -> String:
	match tech:
		"Full House":
			return translate("TECH_FULL_HOUSE")
		"Naked Single":
			return translate("TECH_NAKED_SINGLE")
		"Hidden Single":
			return translate("TECH_HIDDEN_SINGLE")
		"Locked Candidates":
			return translate("TECH_LOCKED_CANDIDATES")
		"Naked Pair":
			return translate("TECH_NAKED_PAIR")
		"Hidden Pair":
			return translate("TECH_HIDDEN_PAIR")
		"Naked Triple":
			return translate("TECH_NAKED_TRIPLE")
		"Hidden Triple":
			return translate("TECH_HIDDEN_TRIPLE")
		"X-Wing":
			return translate("TECH_X_WING")
		"Swordfish":
			return translate("TECH_SWORDFISH")
		"XY-Wing":
			return translate("TECH_XY_WING")
		"XYZ-Wing":
			return translate("TECH_XYZ_WING")
		"Logical Guess / Backtracking", "Solution Hint", "Advanced Logical Deduction":
			return translate("TECH_BACKTRACKING")
		_:
			return translate(tech)

## GDD §44: UI number, percentage, and date/time formatting per locale
## "1 Day" / "5 Days" (Turkish has no plural form)
static func format_days(count: int) -> String:
	return plural("STAT_DAYS", count)

## "Streak: 1 Day" / "Streak: 5 Days"
static func format_streak(count: int) -> String:
	return plural("DAILY_STREAK_FORMAT", count)

## "%d ..." text for a count: English uses the key's "_ONE" form for exactly one
## ("1 game completed"); Turkish nouns stay singular after a number, so it has no such forms
static func plural(key: String, count: int) -> String:
	if current_locale == LOCALE_EN and absi(count) == 1 and DICTIONARY_EN.has(key + "_ONE"):
		return translate(key + "_ONE") % count
	return translate(key) % count

## Upper case for small section labels (overlines). Godot's to_upper() is not locale aware,
## so Turkish "i" would become "I" instead of "İ" ("En İyi" -> "EN İYI")
static func upper(text: String) -> String:
	if current_locale == LOCALE_TR:
		text = text.replace("i", "İ").replace("ı", "I")
	return text.to_upper()

static func format_percentage(pct: int) -> String:
	if current_locale == LOCALE_TR:
		return "%%%d" % pct
	return "%d%%" % pct

static func format_number(val: int) -> String:
	var s := str(abs(val))
	var formatted := ""
	var count := 0
	var sep := "." if current_locale == LOCALE_TR else ","
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			formatted = sep + formatted
		formatted = s[i] + formatted
		count += 1
	if val < 0:
		formatted = "-" + formatted
	return formatted

static func format_date(year: int, month: int, day: int) -> String:
	if current_locale == LOCALE_TR:
		return "%02d.%02d.%04d" % [day, month, year]
	return "%04d-%02d-%02d" % [year, month, day]

## A length of time in words for comparisons ("1 dk 20 sn", "45 s")
static func format_duration_words(seconds: float) -> String:
	var sec := int(roundf(absf(seconds)))
	var m := sec / 60
	var s := sec % 60
	if m == 0:
		return translate("DURATION_SEC") % s
	if s == 0:
		return translate("DURATION_MIN") % m
	return translate("DURATION_MIN_SEC") % [m, s]

static func format_duration(seconds: float) -> String:
	var sec := int(roundf(seconds))
	var m := sec / 60
	var s := sec % 60
	return "%02d:%02d" % [m, s]

static func detect_system_locale() -> String:
	var os_loc := OS.get_locale_language().to_lower().strip_edges()
	if os_loc.is_empty():
		var full_loc := OS.get_locale().to_lower().strip_edges()
		if full_loc.begins_with(LOCALE_TR):
			return LOCALE_TR
		return LOCALE_EN
	if os_loc.begins_with(LOCALE_TR):
		return LOCALE_TR
	return LOCALE_EN

static func get_technique_name(raw_tech: String) -> String:
	return get_technique_title(raw_tech)
