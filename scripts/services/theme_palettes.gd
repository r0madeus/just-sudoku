extends RefCounted

## Colour tables for the built-in themes. ThemeManager keeps the live, editable
## copy in ThemeManager.PALETTES; this builds a fresh one. The keys are the values of
## ThemeManager.THEME_DARK / _AMOLED / _LIGHT / _SEPIA / _FOREST.

static func create() -> Dictionary:
	return {
		"Dark": {
			# Canvas & Surfaces (Architectural Neutral Slate)
			"bg": Color("#11141a"),
			"surface": Color("#171b23"),
			"surface_elevated": Color("#1e232e"),
			"border_subtle": Color("#2a313d"),
			"border_focus": Color("#3b82f6"),

			# Sudoku Grid & Lines (Crisp 3x3 boundaries, subtle hairlines, visible crosshair & selection)
			"grid_major": Color("#6b7d99"),
			"grid_minor": Color("#252e3d"),
			"cell_bg": Color("#13161d"),
			"cell_selected": Color("#1d4a7a"),
			"cell_peer": Color("#1c2433"),
			"cell_same_num": Color("#263952"),

			# Typography
			"text_given": Color("#f8fafc"),
			"text_user": Color("#60a5fa"),
			"text_conflict": Color("#ef4444"),
			"text_wrong": Color("#dc2626"),
			"text_notes": Color("#7e899b"),
			"text_secondary": Color("#7e899b"),

			# Interactive & Brand (Quiet Precision: Focused Accent)
			"accent": Color("#3b82f6"),
			"accent_blue": Color("#2563eb"),
			"accent_text": Color("#ffffff"),
			"button_normal": Color("#1c212a"),
			"button_hover": Color("#262c38"),
			"button_pressed": Color("#151820"),
			"button_disabled": Color("#15182080"),
			"button_text": Color("#e2e8f0"),
			"button_text_disabled": Color("#475569")
		},
		"AMOLED": {
			# Canvas & Surfaces (Pure Black Precision Instrument)
			"bg": Color("#000000"),
			"surface": Color("#0a0a0a"),
			"surface_elevated": Color("#121212"),
			"border_subtle": Color("#202020"),
			"border_focus": Color("#3b82f6"),

			# Sudoku Grid & Lines
			"grid_major": Color("#7a7a7a"),
			"grid_minor": Color("#222222"),
			"cell_bg": Color("#000000"),
			"cell_selected": Color("#1e3a5f"),
			"cell_peer": Color("#111824"),
			"cell_same_num": Color("#1a2b3d"),

			# Typography
			"text_given": Color("#ffffff"),
			"text_user": Color("#60a5fa"),
			"text_conflict": Color("#ef4444"),
			"text_wrong": Color("#dc2626"),
			"text_notes": Color("#7c7c7c"),
			"text_secondary": Color("#7c7c7c"),

			# Interactive & Brand
			"accent": Color("#3b82f6"),
			"accent_blue": Color("#2563eb"),
			"accent_text": Color("#ffffff"),
			"button_normal": Color("#101010"),
			"button_hover": Color("#1a1a1a"),
			"button_pressed": Color("#0d0d0d"),
			"button_disabled": Color("#080808"),
			"button_text": Color("#f5f5f5"),
			"button_text_disabled": Color("#404040")
		},
		"Light": {
			# Canvas & Surfaces (Swiss Editorial Paper)
			"bg": Color("#f8f9fa"),
			"surface": Color("#ffffff"),
			"surface_elevated": Color("#ffffff"),
			"border_subtle": Color("#e2e5e9"),
			"border_focus": Color("#2563eb"),

			# Sudoku Grid & Lines
			"grid_major": Color("#0f172a"),
			"grid_minor": Color("#cbd5e1"),
			"cell_bg": Color("#ffffff"),
			"cell_selected": Color("#bfdbfe"),
			"cell_peer": Color("#f1f5f9"),
			"cell_same_num": Color("#dbeafe"),

			# Typography
			"text_given": Color("#0f172a"),
			"text_user": Color("#1d4ed8"),
			"text_conflict": Color("#dc2626"),
			"text_wrong": Color("#b91c1c"),
			"text_notes": Color("#64748b"),
			"text_secondary": Color("#64748b"),

			# Interactive & Brand
			"accent": Color("#1d4ed8"),
			"accent_blue": Color("#2563eb"),
			"accent_text": Color("#ffffff"),
			"button_normal": Color("#f1f3f5"),
			"button_hover": Color("#e5e8ec"),
			"button_pressed": Color("#dce0e5"),
			"button_disabled": Color("#f1f3f580"),
			"button_text": Color("#1e293b"),
			"button_text_disabled": Color("#94a3b8")
		},
		"Sepia": {
			# Canvas & Surfaces (Warm Parchment / Paper)
			"bg": Color("#f4ecd8"),
			"surface": Color("#ede2c8"),
			"surface_elevated": Color("#fbf7ed"),
			"border_subtle": Color("#d5c4a1"),
			"border_focus": Color("#b57614"),

			# Sudoku Grid & Lines
			"grid_major": Color("#504945"),
			"grid_minor": Color("#d5c4a1"),
			"cell_bg": Color("#fbf7ed"),
			"cell_selected": Color("#e2d3b2"),
			"cell_peer": Color("#f0e4c8"),
			"cell_same_num": Color("#e5d5b5"),

			# Typography
			"text_given": Color("#3c3836"),
			"text_user": Color("#af3a03"),
			"text_conflict": Color("#cc241d"),
			"text_wrong": Color("#9d0006"),
			"text_notes": Color("#6a5e54"),
			"text_secondary": Color("#6a5e54"),

			# Interactive & Brand
			"accent": Color("#8c590c"),
			"accent_blue": Color("#af3a03"),
			"accent_text": Color("#ffffff"),
			"button_normal": Color("#ede2c8"),
			"button_hover": Color("#e2d3b2"),
			"button_pressed": Color("#d5c4a1"),
			"button_disabled": Color("#ede2c880"),
			"button_text": Color("#3c3836"),
			"button_text_disabled": Color("#928374")
		},
		"Forest": {
			# Canvas & Surfaces (Dark Sage / Nordic Mint)
			"bg": Color("#101a14"),
			"surface": Color("#18261e"),
			"surface_elevated": Color("#203328"),
			"border_subtle": Color("#2b4235"),
			"border_focus": Color("#34d399"),

			# Sudoku Grid & Lines
			"grid_major": Color("#6f8875"),
			"grid_minor": Color("#253a2e"),
			"cell_bg": Color("#142119"),
			"cell_selected": Color("#274f39"),
			"cell_peer": Color("#1a2e22"),
			"cell_same_num": Color("#2f5b42"),

			# Typography
			"text_given": Color("#e6f4ec"),
			"text_user": Color("#34d399"),
			"text_conflict": Color("#f87171"),
			"text_wrong": Color("#ef4444"),
			"text_notes": Color("#7da58e"),
			"text_secondary": Color("#7da58e"),

			# Interactive & Brand
			"accent": Color("#10b981"),
			"accent_blue": Color("#059669"),
			"accent_text": Color("#ffffff"),
			"button_normal": Color("#1c2d23"),
			"button_hover": Color("#253d2f"),
			"button_pressed": Color("#15231b"),
			"button_disabled": Color("#1c2d2380"),
			"button_text": Color("#d1fae5"),
			"button_text_disabled": Color("#4e7962")
		}
	}
