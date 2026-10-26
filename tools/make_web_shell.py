#!/usr/bin/env python3
"""Writes web/shell.html, the page the browser version loads in: Godot's own web shell with the
loading screen changed to the home screen's name, "Just Sudoku" in DM Serif Display ending in the
blue square, centred on the page, with a thin progress line under it. The few letters of the
name are embedded as a font, so the name shows before anything else has loaded.
    python3 tools/make_web_shell.py <godot.html from the web export template>   (needs fontTools, brotli)
"""
import base64, io, os, sys

from fontTools import subset
from fontTools.ttLib import TTFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(REPO, "assets", "fonts", "DMSerifDisplay-Regular.ttf")
NAME = "Just Sudoku"


def font_data_uri():
    opts = subset.Options()
    opts.flavor = "woff2"
    opts.layout_features = ["kern"]
    font = TTFont(FONT)
    sub = subset.Subsetter(opts)
    sub.populate(text=NAME)
    sub.subset(font)
    font.flavor = "woff2"
    buf = io.BytesIO()
    font.save(buf)
    return "data:font/woff2;base64," + base64.b64encode(buf.getvalue()).decode()


STYLE = """
@font-face {
	font-family: 'DM Serif Display';
	src: url(__FONT__) format('woff2');
	font-display: block;
}

#status {
	background-color: #11141a;
	gap: 1.4rem;
}

#status-name {
	margin: 0;
	font: 400 clamp(2.6rem, 11vw, 4.2rem)/1 'DM Serif Display', Georgia, serif;
	color: #f8fafc;
	letter-spacing: 0;
	white-space: nowrap;
}

/* The full stop: a rounded square a little over a quarter of the type size, its foot on the baseline */
#status-name i {
	display: inline-block;
	width: 0.27em;
	height: 0.27em;
	margin-left: 0.05em;
	border-radius: 0.075em;
	background: #2563eb;
}

#status-progress {
	position: static;
	display: none;
	width: min(40vw, 11rem);
	height: 3px;
	margin: 0;
	border: 0;
	border-radius: 2px;
	overflow: hidden;
	appearance: none;
	-webkit-appearance: none;
	background: rgba(148, 163, 184, 0.25);
	color: #2563eb;
}
#status-progress::-webkit-progress-bar { background: transparent; }
#status-progress::-webkit-progress-value { background: #2563eb; border-radius: 2px; }
#status-progress::-moz-progress-bar { background: #2563eb; border-radius: 2px; }

@media (prefers-color-scheme: light) {
	#status { background-color: #f8f9fa; }
	#status-name { color: #0f172a; }
	#status-progress { background: rgba(15, 23, 42, 0.12); }
}
"""


def main():
    src = open(sys.argv[1], encoding="utf-8").read()
    html = src
    # The default look of the loading screen stays in the page; ours comes after it and wins
    html = html.replace("\t\t</style>", STYLE.replace("__FONT__", font_data_uri()) + "\t\t</style>", 1)
    html = html.replace('\t\t\t<img id="status-splash" class="$GODOT_SPLASH_CLASSES" src="$GODOT_SPLASH" alt="">\n',
                        '\t\t\t<h1 id="status-name">Just Sudoku<i></i></h1>\n', 1)
    assert "status-name" in html and "font-face" in html
    os.makedirs(os.path.join(REPO, "web"), exist_ok=True)
    out = os.path.join(REPO, "web", "shell.html")
    open(out, "w", encoding="utf-8").write(html)
    print(out, len(html), "bytes")


if __name__ == "__main__":
    main()
