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
	"BTN_REPLAY": "Play Again",
	"DIFF_EASY": "Easy",
	"DIFF_MEDIUM": "Medium",
	"DIFF_HARD": "Hard",
	"DIFF_EXPERT": "Expert",
	"DIFF_ALL": "All",
	"DIFF_SELECT_PROMPT": "Select Difficulty:",
	"BTN_UNDO": "Undo",
	"BTN_REDO": "Redo",
	"BTN_NOTES": "Notes",
	"BTN_NOTES_ON": "Notes: On",
	"BTN_ERASE": "Erase",
	"BTN_CHECK": "Check",
	"BTN_HINT": "Hint",
	"PAUSE_TITLE": "GAME PAUSED",
	"BTN_RESUME": "Resume",
	"BTN_SHARE_PUZZLE": "Share Puzzle (Seed & Code)",
	"BTN_COPY_SAVE": "Copy Save State",
	"TOAST_PUZZLE_COPIED": "Puzzle copied to clipboard!",
	"TOAST_SAVE_COPIED": "Save JSON copied to clipboard!",
	"HINT_DIALOG_TITLE": "Logical Deduction Hint",
	"HINT_APPLY_MOVE": "Apply Move",
	"HINT_FOCUS_TEXT": "Look closely at this area: %s. The next logical step is there.\n\nNeed more? The next level names the technique.",
	"HINT_SHOW_TECHNIQUE": "Show Technique",
	"WIN_DIALOG_TITLE": "Congratulations! Puzzle Solved",
	"WIN_BUTTON_AWESOME": "Awesome!",
	"CHECK_ALL_CORRECT": "All entries are correct! Great job!",
	"CHECK_MISTAKES_FOUND": "%d incorrect cells marked in red.",
	"NEW_GAME_TITLE": "New Game",
	"LOADING_PUZZLE": "Preparing %s puzzle...",
	"SEED_LABEL": "Seed: %d",
	"ESTIMATED_TIME": "Estimated Time: ~%dm %ds",
	"KEY_TECHNIQUES": "Key Techniques: %s",
	"BTN_COPY_SEED": "Copy",
	"BTN_REGEN_SEED": "Different Seed",
	"BTN_IMPORT_NEW_GAME": "Start from Seed / Code",
	"COPIED_FEEDBACK": "Copied",
	"IMPORT_DIALOG_TITLE": "Import Puzzle / Seed",
	"IMPORT_INSTRUCTION": "Paste a seed number, 81-character puzzle string, or Save JSON:",
	"IMPORT_PLACEHOLDER": "E.g. 123456789 or 53..7....6..195... or {\"version\":1,...}",
	"BTN_START_IMPORTED": "Start Game",
	"STATUS_VALID_PUZZLE": "Valid 81-character puzzle (%d starting clues)",
	"STATUS_VALID_SEED": "Valid Seed: %d",
	"STATUS_VALID_SAVE": "Valid Save State (%s • %s)",
	"ERROR_EMPTY_INPUT": "Please enter a Seed, 81-character puzzle string, or save JSON.",
	"ERROR_INVALID_INPUT": "Invalid input. Please enter a valid Seed, 81-character code, or save JSON.",
	"SETTINGS_TITLE": "Settings",
	"SETTINGS_SEC_APPEARANCE": "Appearance",
	"SETTINGS_SEC_GAMEPLAY": "Gameplay",
	"SETTINGS_SEC_FEEDBACK": "Feedback & Audio",
	"THEME_GROUP_BOARD": "Board & Surfaces",
	"THEME_GROUP_NUMBERS": "Numbers & Accents",
	"SETTING_LANGUAGE": "Language / Dil",
	"SETTING_THEME": "Visual Theme",
	"SETTING_FONT": "Font Family",
	"FONT_MODERN_SANS": "Modern Sans (Default)",
	"FONT_ROUNDED_SANS": "Rounded Sans (Soft)",
	"FONT_CLASSIC_SERIF": "Classic Serif (Traditional)",
	"SETTING_AUTO_OPEN": "Resume last game on launch",
	"SETTING_SMART_NUMPAD": "Smart Numpad",
	"SETTING_AUTO_NOTES": "Auto-remove notes",
	"SETTING_SMART_CANDIDATES": "Smart Candidates",
	"SETTING_SHOW_CONFLICTS": "Highlight conflicts",
	"SETTING_ANIMATIONS": "UI Animations",
	"SETTING_SOUNDS": "UI Sound Effects",
	"STATS_TITLE": "Statistics",
	"STAT_COMPLETED_GAMES": "Completed Games",
	"STAT_CURRENT_STREAK": "Daily Streak",
	"STAT_LONGEST_STREAK": "Longest Streak",
	"STAT_BEST_SCORE": "Best Score",
	"STAT_AVG_TIME": "Average Time",
	"STAT_PERF_BY_DIFF": "Performance by Difficulty",
	"STAT_GAMES_COUNT": "%d games completed",
	"STAT_AVG_MISTAKES": "Avg. Mistakes: %.1f",
	"STAT_BEST_TIME": "Best Time: %s",
	"STAT_DAYS": "%d Days",
	"HISTORY_TITLE": "Game History",
	"HISTORY_DIFF_FILTER": "Difficulty:",
	"HISTORY_SORT_FILTER": "Sort by:",
	"SORT_NEWEST": "Newest",
	"SORT_OLDEST": "Oldest",
	"SORT_FASTEST": "Fastest",
	"SORT_BEST_SCORE": "Best Score",
	"HISTORY_RECORD_INFO": "Date: %s • Time: %s • Mistakes: %d • Hints: %d • Score: %d",
	"SAVED_GAMES_TITLE": "Saved Games",
	"NO_ACTIVE_GAMES": "No active games found.",
	"PROGRESS_LABEL": "Progress: %s",
	"RESUME_PROGRESS": "%d%% filled",
	"RESUME_EMPTY_TITLE": "Ready when you are",
	"RESUME_EMPTY_BODY": "Start a new puzzle or try today's Daily.",
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
	"TECH_BACKTRACKING": "Direct Solution (Fallback)",
	"Full House": "Full House",
	"Naked Single": "Naked Single",
	"Hidden Single": "Hidden Single",
	"Locked Candidates": "Locked Candidates",
	"Naked Pair": "Naked Pair",
	"Hidden Pair": "Hidden Pair",
	"Naked Triple": "Naked Triple",
	"Hidden Triple": "Hidden Triple",
	"Logical Guess / Backtracking": "Direct Solution (Fallback)",
	"Solution Hint": "Direct Solution (Fallback)",
	"STAT_COMPLETION_RATE": "Completion Rate",
	"STAT_DAILY_STREAK_BANNER": "Daily Challenge Streaks",
	"STAT_DAILY_STREAK_DESC": "Solve daily puzzles every day to build and maintain your streak.",
	"STATS_SUBTITLE": "Performance summary, completion rates, and records.",
	"STAT_NO_GAMES_YET": "No completed games yet. Start a new game or daily puzzle to build your stats.",
	"STAT_ALL_TIME": "ALL TIME OVERVIEW",
	"STAT_STREAKS": "DAILY STREAKS",
	"STAT_DIFFICULTIES": "BY DIFFICULTY",
	"THEME_DARK": "Dark",
	"THEME_AMOLED": "AMOLED Black",
	"THEME_LIGHT": "Light",
	"THEME_SEPIA": "Sepia / Paper",
	"THEME_FOREST": "Forest Green",
	"THEME_CUSTOM": "Custom Theme",
	"CUSTOM_THEME_TITLE": "Custom Theme Editor",
	"BTN_EDIT_CUSTOM_THEME": "Customize Theme",
	"PREVIEW_MINI_GRID": "Live Grid Preview",
	"COLOR_BG": "Background",
	"COLOR_GRID": "Grid Lines",
	"COLOR_CELL": "Cell Background",
	"COLOR_SELECTED": "Selected Cell",
	"COLOR_TEXT_GIVEN": "Given Numbers",
	"COLOR_TEXT_USER": "User Numbers",
	"COLOR_ACCENT": "Accent Color",
	"COLOR_ERROR": "Error / Conflict",
	"COLOR_NOTES": "Candidate Notes",
	"PRESET_BASE_PROMPT": "Copy from Preset:",
	"BTN_SAVE_APPLY": "Save & Apply",
	"BTN_SOLUTION": "Solution System",
	"BTN_FULL_SOLUTION": "Full Solution",
	"BTN_STEP_BY_STEP": "Step-by-Step",
	"BTN_APPLY_SOLUTION": "Apply to Board",
	"STEP_COUNTER": "Step %d / %d",
	"STEP_INITIAL_BOARD": "Initial Board",
	"STEP_INITIAL_DESC": "Starting clues of the puzzle. Press Next to step through the logical solution.",
	"SOLUTION_TITLE": "Puzzle Solution",
	"SOLUTION_APPLY_CONFIRM": "Are you sure you want to apply the full solution to the board? The game will be marked as completed.",
	"BTN_FIRST_STEP": "First",
	"BTN_PREV_STEP": "Prev",
	"BTN_NEXT_STEP": "Next",
	"BTN_LAST_STEP": "Last",
	"SOLUTION_SUMMARY_GIVENS": "Given Clues: %d",
	"SOLUTION_SUMMARY_SOLVED": "Solved Cells: %d",
	"SOLUTION_UNIQUE_VERIFIED": "Unique Solution Verified",
	"TECHNIQUE_NAKED_SINGLE": "Naked Single",
	"TECHNIQUE_HIDDEN_SINGLE": "Hidden Single",
	"TECHNIQUE_LOCKED_CANDIDATES": "Locked Candidates",
	"TECHNIQUE_NAKED_PAIR": "Naked Pair",
	"TECHNIQUE_HIDDEN_PAIR": "Hidden Pair",
	"TECHNIQUE_NAKED_TRIPLE": "Naked Triple",
	"TECHNIQUE_HIDDEN_TRIPLE": "Hidden Triple",
	"TECHNIQUE_X_WING": "X-Wing",
	"TECHNIQUE_XY_WING": "XY-Wing",
	"TECHNIQUE_XYZ_WING": "XYZ-Wing",
	"TECHNIQUE_SWORDFISH": "Swordfish",
	"TECHNIQUE_ADVANCED_DEDUCTION": "Advanced Deduction",
	"BTN_MASTER_AGAIN": "Master it again",
	"BADGE_REPLAY": "Replay",
	"HISTORY_STATUS_FILTER": "Status:",
	"STATUS_ALL": "All",
	"STATUS_STANDARD": "Standard",
	"STATUS_REPLAY": "Replay",
	"SCORE_BEST_COMPARISON": "Best: %d • Current Replay: %d",
	"NEW_BEST_SCORE": "New Best Score!",
	"SETTING_DESC_LANGUAGE": "Display language",
	"SETTING_DESC_THEME": "App color palette",
	"SETTING_DESC_CUSTOM_THEME": "Customize your own theme",
	"SETTING_DESC_FONT": "Typography and digit style",
	"SETTING_DESC_AUTO_OPEN": "Opens your unfinished game straight away",
	"SETTING_DESC_SMART_NUMPAD": "Greys out digits that can't go in the selected cell",
	"SETTING_DESC_AUTO_NOTES": "Clears matching pencil marks when you place a digit",
	"SETTING_DESC_SMART_CANDIDATES": "Shows every valid candidate in empty cells",
	"SETTING_DESC_SHOW_CONFLICTS": "Marks duplicate digits in red right away",
	"SETTING_DESC_ANIMATIONS": "Cell pops, screen transitions and the victory wave",
	"SETTING_DESC_SOUNDS": "Taps, mistakes and completion sounds",
	"SETTING_HAPTICS": "Vibration",
	"SETTING_DESC_HAPTICS": "Short vibrations on taps, mistakes and completions",
	"DAILY_SUBTITLE": "Daily handcrafted puzzle",
	"DAILY_PREPARING": "Daily Sudoku (Preparing...)",
	"DAILY_STREAK_FORMAT": "Streak: %d Days",
	"SUBTITLE_CALM": "CALM, FOCUSED SUDOKU",
	"STATS_OVERVIEW": "OVERVIEW",
	"STATS_BY_DIFFICULTY": "BY DIFFICULTY",
	"STAT_BEST_TIME_LABEL": "Best Time",
	"STAT_AVG_TIME_LABEL": "Avg. Time",
	"STAT_BEST_SCORE_LABEL": "Best Score",
	"STAT_AVG_MISTAKES_LABEL": "Avg. Mistakes",
	"STAT_AVG_HINTS_LABEL": "Avg. Hints",
	"HISTORY_EMPTY": "No completed games found.",
	"RECORD_SCORE": "Score: %d",
	"RECORD_BEST_SCORE": "(Best: %d)",
	"RECORD_TIME": "Time: %s",
	"RECORD_MISTAKES": "Mistakes: %d",
	"RECORD_HINTS": "Hints: %d",
	"BTN_REPLAY_ACTION": "Replay",
	"WIN_SUMMARY_FORMAT": "Time: %s\nMistakes: %d\nHints: %d\n\nPerformance Score: %d / 100",
	"THEME_SYSTEM": "System (Auto)",
	"SHARE_CARD_HEADER": "Just Sudoku",
	"SHARE_DIFF_LABEL": "Difficulty",
	"SHARE_SEED_LABEL": "Seed",
	"SHARE_CODE_LABEL": "Code",
	"SHARE_INFO_SAVE": "Saved game detected successfully (%s, Time: %s, Progress: %s).",
	"SHARE_ERR_SAVE": "Invalid or corrupted save JSON format.",
	"SHARE_ERR_CONFLICT": "Invalid puzzle: duplicate numbers in row, column, or block (%d conflicts).",
	"SHARE_ERR_NO_UNIQUE": "The puzzle does not have a unique solution (unsolvable or multiple solutions).",
	"SHARE_INFO_CODE": "Valid 81-character puzzle verified (Difficulty: %s, Score: %d).",
	"SHARE_INFO_SEED": "Valid Seed detected (Seed: %d, Level: %s).",
	"SHARE_ERR_UNKNOWN": "Input not recognized. Please enter a valid Seed, 81-character puzzle code, or save JSON."
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
	"BTN_REPLAY": "Yeniden Oyna",
	"DIFF_EASY": "Kolay",
	"DIFF_MEDIUM": "Orta",
	"DIFF_HARD": "Zor",
	"DIFF_EXPERT": "Uzman",
	"DIFF_ALL": "Tümü",
	"DIFF_SELECT_PROMPT": "Zorluk Derecesi Seçin:",
	"BTN_UNDO": "Geri Al",
	"BTN_REDO": "İleri Al",
	"BTN_NOTES": "Not",
	"BTN_NOTES_ON": "Not: Açık",
	"BTN_ERASE": "Sil",
	"BTN_CHECK": "Kontrol Et",
	"BTN_HINT": "İpucu",
	"PAUSE_TITLE": "OYUN DURAKLATILDI",
	"BTN_RESUME": "Devam Et",
	"BTN_SHARE_PUZZLE": "Bulmacayı Paylaş (Seed & Kod)",
	"BTN_COPY_SAVE": "Save Durumunu Kopyala",
	"TOAST_PUZZLE_COPIED": "Bulmaca panoya kopyalandı!",
	"TOAST_SAVE_COPIED": "Kayıt JSON panoya kopyalandı!",
	"HINT_DIALOG_TITLE": "Mantıksal İpucu",
	"HINT_APPLY_MOVE": "Hamleyi Uygula",
	"HINT_FOCUS_TEXT": "Şu bölgeye dikkatlice bak: %s. Sıradaki mantıksal adım orada.\n\nDaha fazlası gerekirse sonraki kademe tekniği söyler.",
	"HINT_SHOW_TECHNIQUE": "Tekniği Göster",
	"WIN_DIALOG_TITLE": "Tebrikler! Bulmaca Çözüldü",
	"WIN_BUTTON_AWESOME": "Harika!",
	"CHECK_ALL_CORRECT": "Tüm girişler doğru! Harika!",
	"CHECK_MISTAKES_FOUND": "%d hatalı hücre kırmızı ile işaretlendi.",
	"NEW_GAME_TITLE": "Yeni Oyun",
	"LOADING_PUZZLE": "%s seviyesinde bulmaca hazırlanıyor...",
	"SEED_LABEL": "Seed: %d",
	"ESTIMATED_TIME": "Tahmini Süre: ~%ddk %dsn",
	"KEY_TECHNIQUES": "Kullanılan Teknikler: %s",
	"BTN_COPY_SEED": "Kopyala",
	"BTN_REGEN_SEED": "Farklı Seed",
	"BTN_IMPORT_NEW_GAME": "Dışarıdan Seed / Kod ile Başlat",
	"COPIED_FEEDBACK": "Kopyalandı",
	"IMPORT_DIALOG_TITLE": "Bulmaca / Seed İçe Aktar",
	"IMPORT_INSTRUCTION": "Seed numarası, 81 karakterlik bulmaca kodu veya Save metni yapıştırın:",
	"IMPORT_PLACEHOLDER": "Örn: 123456789 veya 53..7....6..195... veya {\"version\":1,...}",
	"BTN_START_IMPORTED": "Oyunu Başlat",
	"STATUS_VALID_PUZZLE": "Geçerli 81 karakterlik bulmaca (%d başlangıç ipucu)",
	"STATUS_VALID_SEED": "Geçerli Seed: %d",
	"STATUS_VALID_SAVE": "Geçerli Oyun Kaydı (%s • %s)",
	"ERROR_EMPTY_INPUT": "Lütfen bir Seed, 81 karakterlik bulmaca kodu veya kayıt metni girin.",
	"ERROR_INVALID_INPUT": "Girdiğiniz metin tanınamadı. Lütfen geçerli bir Seed sayısı, 81 karakterlik bulmaca kodu veya kayıt JSON'u girin.",
	"SETTINGS_TITLE": "Ayarlar",
	"SETTINGS_SEC_APPEARANCE": "Görünüm",
	"SETTINGS_SEC_GAMEPLAY": "Oynanış",
	"SETTINGS_SEC_FEEDBACK": "Geri Bildirim ve Sesler",
	"THEME_GROUP_BOARD": "Tahta ve Yüzeyler",
	"THEME_GROUP_NUMBERS": "Sayılar ve Vurgular",
	"SETTING_LANGUAGE": "Dil / Language",
	"SETTING_THEME": "Görsel Tema",
	"SETTING_FONT": "Yazı Tipi / Font",
	"FONT_MODERN_SANS": "Modern Sans (Varsayılan)",
	"FONT_ROUNDED_SANS": "Rounded Sans (Yumuşak)",
	"FONT_CLASSIC_SERIF": "Classic Serif (Geleneksel)",
	"SETTING_AUTO_OPEN": "Son oyunu açılışta sürdür",
	"SETTING_SMART_NUMPAD": "Akıllı tuş takımı",
	"SETTING_AUTO_NOTES": "Notları otomatik sil",
	"SETTING_SMART_CANDIDATES": "Akıllı adaylar",
	"SETTING_SHOW_CONFLICTS": "Çakışmaları vurgula",
	"SETTING_ANIMATIONS": "Arayüz animasyonları",
	"SETTING_SOUNDS": "Arayüz sesleri",
	"STATS_TITLE": "İstatistikler",
	"STAT_COMPLETED_GAMES": "Tamamlanan Oyunlar",
	"STAT_CURRENT_STREAK": "Günlük Seri",
	"STAT_LONGEST_STREAK": "En Uzun Seri",
	"STAT_BEST_SCORE": "En Yüksek Skor",
	"STAT_AVG_TIME": "Ortalama Süre",
	"STAT_PERF_BY_DIFF": "Zorluk Bazında Performans",
	"STAT_GAMES_COUNT": "%d oyun tamamlandı",
	"STAT_AVG_MISTAKES": "Ort. Hata: %.1f",
	"STAT_BEST_TIME": "En İyi Süre: %s",
	"STAT_DAYS": "%d Gün",
	"HISTORY_TITLE": "Oyun Geçmişi",
	"HISTORY_DIFF_FILTER": "Zorluk:",
	"HISTORY_SORT_FILTER": "Sıralama:",
	"SORT_NEWEST": "En Yeni",
	"SORT_OLDEST": "En Eski",
	"SORT_FASTEST": "En Hızlı",
	"SORT_BEST_SCORE": "En Yüksek Skor",
	"HISTORY_RECORD_INFO": "Tarih: %s • Süre: %s • Hata: %d • İpucu: %d • Skor: %d",
	"SAVED_GAMES_TITLE": "Kayıtlı Oyunlar",
	"NO_ACTIVE_GAMES": "Devam eden aktif oyun bulunmuyor.",
	"PROGRESS_LABEL": "İlerleme: %s",
	"RESUME_PROGRESS": "%%%d dolu",
	"RESUME_EMPTY_TITLE": "Hazır olduğunuzda",
	"RESUME_EMPTY_BODY": "Yeni bir bulmaca başlatın ya da günlük bulmacayı deneyin.",
	"TECH_FULL_HOUSE": "Tamamlanan Bölge (Full House)",
	"TECH_NAKED_SINGLE": "Açık Tekli (Naked Single)",
	"TECH_HIDDEN_SINGLE": "Gizli Tekli (Hidden Single)",
	"TECH_LOCKED_CANDIDATES": "Kilitli Adaylar (Locked Candidates)",
	"TECH_NAKED_PAIR": "Açık Çift (Naked Pair)",
	"TECH_HIDDEN_PAIR": "Gizli Çift (Hidden Pair)",
	"TECH_NAKED_TRIPLE": "Açık Üçlü (Naked Triple)",
	"TECH_HIDDEN_TRIPLE": "Gizli Üçlü (Hidden Triple)",
	"TECH_X_WING": "X-Wing",
	"TECH_SWORDFISH": "Swordfish",
	"TECH_XY_WING": "XY-Wing",
	"TECH_XYZ_WING": "XYZ-Wing",
	"TECH_BACKTRACKING": "Doğrudan Çözüm (Geri İzleme)",
	"Full House": "Tamamlanan Bölge (Full House)",
	"Naked Single": "Açık Tekli (Naked Single)",
	"Hidden Single": "Gizli Tekli (Hidden Single)",
	"Locked Candidates": "Kilitli Adaylar (Locked Candidates)",
	"Naked Pair": "Açık Çift (Naked Pair)",
	"Hidden Pair": "Gizli Çift (Hidden Pair)",
	"Naked Triple": "Açık Üçlü (Naked Triple)",
	"Hidden Triple": "Gizli Üçlü (Hidden Triple)",
	"Logical Guess / Backtracking": "Doğrudan Çözüm (Geri İzleme)",
	"Solution Hint": "Doğrudan Çözüm (Geri İzleme)",
	"STAT_COMPLETION_RATE": "Tamamlama Oranı",
	"STAT_DAILY_STREAK_BANNER": "Günün Sudokusu Seri Kayıtları",
	"STAT_DAILY_STREAK_DESC": "Her gün bir bulmaca tamamlayarak serinizi koruyun.",
	"STATS_SUBTITLE": "Performans özeti, tamamlama oranları ve rekorlar.",
	"STAT_NO_GAMES_YET": "Henüz tamamlanmış bir oyun bulunmuyor. Yeni bir bulmaca veya Günün Sudokusu çözerek istatistiklerinizi oluşturun.",
	"STAT_ALL_TIME": "GENEL BAKIŞ",
	"STAT_STREAKS": "GÜNLÜK SERİLER",
	"STAT_DIFFICULTIES": "ZORLUK SEVİYELERİ",
	"THEME_DARK": "Koyu (Dark)",
	"THEME_AMOLED": "AMOLED Siyah",
	"THEME_LIGHT": "Açık (Light)",
	"THEME_SEPIA": "Sepya / Kitap",
	"THEME_FOREST": "Orman / Yeşil",
	"THEME_CUSTOM": "Özel Tema",
	"CUSTOM_THEME_TITLE": "Özel Renk Teması Editörü",
	"BTN_EDIT_CUSTOM_THEME": "Özel Temayı Düzenle",
	"PREVIEW_MINI_GRID": "Canlı Izgara Önizlemesi",
	"COLOR_BG": "Arka Plan",
	"COLOR_GRID": "Izgara Çizgileri",
	"COLOR_CELL": "Hücre Arka Planı",
	"COLOR_SELECTED": "Seçili Hücre",
	"COLOR_TEXT_GIVEN": "Başlangıç Sayıları",
	"COLOR_TEXT_USER": "Oyuncu Sayıları",
	"COLOR_ACCENT": "Vurgu Rengi",
	"COLOR_ERROR": "Hata / Çakışma",
	"COLOR_NOTES": "Aday Notları",
	"PRESET_BASE_PROMPT": "Hazır Temadan Kopyala:",
	"BTN_SAVE_APPLY": "Kaydet ve Uygula",
	"BTN_SOLUTION": "Çözüm Sistemi",
	"BTN_FULL_SOLUTION": "Tam Çözüm",
	"BTN_STEP_BY_STEP": "Adım Adım",
	"BTN_APPLY_SOLUTION": "Çözümü Tahtaya Uygula",
	"STEP_COUNTER": "Adım %d / %d",
	"STEP_INITIAL_BOARD": "Başlangıç İpuçları",
	"STEP_INITIAL_DESC": "Bulmacanın başlangıç ipuçları. Çözüm adımlarını tek tek izlemek için İleri butonuna basın.",
	"SOLUTION_TITLE": "Bulmaca Çözümü",
	"SOLUTION_APPLY_CONFIRM": "Tam çözümü tahtaya uygulamak istediğinize emin misiniz? Oyun tamamlanmış sayılacaktır.",
	"BTN_FIRST_STEP": "Başa",
	"BTN_PREV_STEP": "Önceki",
	"BTN_NEXT_STEP": "Sonraki",
	"BTN_LAST_STEP": "Sona",
	"SOLUTION_SUMMARY_GIVENS": "Verilen İpuçları: %d",
	"SOLUTION_SUMMARY_SOLVED": "Çözülen Hücreler: %d",
	"SOLUTION_UNIQUE_VERIFIED": "Benzersiz Çözüm Doğrulandı",
	"TECHNIQUE_NAKED_SINGLE": "Açık Tek Aday (Naked Single)",
	"TECHNIQUE_HIDDEN_SINGLE": "Gizli Tek Aday (Hidden Single)",
	"TECHNIQUE_LOCKED_CANDIDATES": "Kilitli Adaylar (Locked Candidates)",
	"TECHNIQUE_NAKED_PAIR": "Açık İkili (Naked Pair)",
	"TECHNIQUE_HIDDEN_PAIR": "Gizli İkili (Hidden Pair)",
	"TECHNIQUE_NAKED_TRIPLE": "Açık Üçlü (Naked Triple)",
	"TECHNIQUE_HIDDEN_TRIPLE": "Gizli Üçlü (Hidden Triple)",
	"TECHNIQUE_X_WING": "X-Wing",
	"TECHNIQUE_XY_WING": "XY-Wing",
	"TECHNIQUE_XYZ_WING": "XYZ-Wing",
	"TECHNIQUE_SWORDFISH": "Swordfish",
	"TECHNIQUE_ADVANCED_DEDUCTION": "İleri Mantık Çıkarımı",
	"BTN_MASTER_AGAIN": "Tekrar Oyna (Master it again)",
	"BADGE_REPLAY": "Replay",
	"HISTORY_STATUS_FILTER": "Durum:",
	"STATUS_ALL": "Tümü",
	"STATUS_STANDARD": "Standart",
	"STATUS_REPLAY": "Replay",
	"SCORE_BEST_COMPARISON": "En İyi Skor: %d • Bu Replay: %d",
	"NEW_BEST_SCORE": "Yeni En İyi Skor!",
	"SETTING_DESC_LANGUAGE": "Arayüz dili",
	"SETTING_DESC_THEME": "Uygulama renk paleti",
	"SETTING_DESC_CUSTOM_THEME": "Kendi renk paletinizi düzenleyin",
	"SETTING_DESC_FONT": "Tipografi ve rakam stili",
	"SETTING_DESC_AUTO_OPEN": "Yarım kalan oyunu doğrudan açar",
	"SETTING_DESC_SMART_NUMPAD": "Seçili hücreye giremeyecek rakamları pasifleştirir",
	"SETTING_DESC_AUTO_NOTES": "Rakam yazınca aynı satır, sütun ve bloktaki notları temizler",
	"SETTING_DESC_SMART_CANDIDATES": "Boş hücrelerde geçerli tüm adayları gösterir",
	"SETTING_DESC_SHOW_CONFLICTS": "Tekrar eden rakamları hemen kırmızı yapar",
	"SETTING_DESC_ANIMATIONS": "Hücre efektleri, ekran geçişleri ve kutlama dalgası",
	"SETTING_DESC_SOUNDS": "Dokunma, hata ve tamamlama sesleri",
	"SETTING_HAPTICS": "Titreşim",
	"SETTING_DESC_HAPTICS": "Dokunma, hata ve tamamlamada kısa titreşim",
	"DAILY_SUBTITLE": "Günün özel bulmacası",
	"DAILY_PREPARING": "Günün Sudokusu (Hazırlanıyor...)",
	"DAILY_STREAK_FORMAT": "Seri: %d Gün",
	"SUBTITLE_CALM": "SAKİN, ODAKLI SUDOKU DENEYİMİ",
	"STATS_OVERVIEW": "GENEL BAKIŞ",
	"STATS_BY_DIFFICULTY": "ZORLUK BAZINDA PERFORMANS",
	"STAT_BEST_TIME_LABEL": "En İyi Süre",
	"STAT_AVG_TIME_LABEL": "Ortalama Süre",
	"STAT_BEST_SCORE_LABEL": "En Yüksek Skor",
	"STAT_AVG_MISTAKES_LABEL": "Ortalama Hata",
	"STAT_AVG_HINTS_LABEL": "Ortalama İpucu",
	"HISTORY_EMPTY": "Henüz tamamlanmış bir oyun bulunmuyor.",
	"RECORD_SCORE": "Skor: %d",
	"RECORD_BEST_SCORE": "(En İyi: %d)",
	"RECORD_TIME": "Süre: %s",
	"RECORD_MISTAKES": "Hata: %d",
	"RECORD_HINTS": "İpucu: %d",
	"BTN_REPLAY_ACTION": "Tekrar Oyna",
	"WIN_SUMMARY_FORMAT": "Süre: %s\nHata: %d\nİpucu: %d\n\nPerformans Skoru: %d / 100",
	"THEME_SYSTEM": "Sistem (Otomatik)",
	"SHARE_CARD_HEADER": "Just Sudoku",
	"SHARE_DIFF_LABEL": "Zorluk",
	"SHARE_SEED_LABEL": "Seed",
	"SHARE_CODE_LABEL": "Kod",
	"SHARE_INFO_SAVE": "Kayıtlı oyun başarıyla algılandı (%s, Süre: %s, İlerleme: %s).",
	"SHARE_ERR_SAVE": "Geçersiz veya bozuk kayıt JSON formatı.",
	"SHARE_ERR_CONFLICT": "Bulmaca geçerli değil: Satır, sütun veya blokta mükerrer sayılar var (%d çakışma).",
	"SHARE_ERR_NO_UNIQUE": "Bulmacanın tek bir çözümü yok (çözümsüz veya birden fazla çözüm var).",
	"SHARE_INFO_CODE": "Geçerli 81 karakterlik bulmaca doğrulandı (Zorluk: %s, Skor: %d).",
	"SHARE_INFO_SEED": "Geçerli Seed algılandı (Seed: %d, Seviye: %s).",
	"SHARE_ERR_UNKNOWN": "Girdiğiniz metin tanınamadı. Lütfen geçerli bir Seed sayısı, 81 karakterlik bulmaca kodu veya kayıt JSON'u girin."
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
static func get_difficulty_name(diff_key: String) -> String:
	match diff_key:
		DifficultyAnalyzer.LEVEL_EASY, "Easy", "Kolay":
			return translate("DIFF_EASY")
		DifficultyAnalyzer.LEVEL_MEDIUM, "Medium", "Orta":
			return translate("DIFF_MEDIUM")
		DifficultyAnalyzer.LEVEL_HARD, "Hard", "Zor":
			return translate("DIFF_HARD")
		DifficultyAnalyzer.LEVEL_EXPERT, "Expert", "Uzman":
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
	if current_locale == LOCALE_EN and count == 1:
		return "1 Day"
	return translate("STAT_DAYS") % count

## "Streak: 1 Day" / "Streak: 5 Days"
static func format_streak(count: int) -> String:
	if current_locale == LOCALE_EN and count == 1:
		return "Streak: 1 Day"
	return translate("DAILY_STREAK_FORMAT") % count

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
	var key: String = "TECHNIQUE_" + raw_tech.to_upper().replace(" ", "_").replace("-", "_")
	var t: String = translate(key)
	if t != key:
		return t
	return raw_tech

