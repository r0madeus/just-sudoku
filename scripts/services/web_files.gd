class_name WebFiles
extends RefCounted

## Saving and opening files in the browser version, where there is no file picker of the
## system's: a save is a download, an open is the browser's own "choose a file" window.
## Everything here is for the web export only; elsewhere `available()` is false.

## The page script that asks for a file and hands its text back
const PICK_SCRIPT: String = """
(function () {
	var input = document.createElement('input');
	input.type = 'file';
	input.accept = '.json,application/json,text/plain';
	input.onchange = function () {
		var file = input.files && input.files[0];
		if (!file) { return; }
		file.text().then(function (text) { window.justSudokuPickedText(text); });
	};
	input.click();
})();
"""

## Kept here so the callback is not freed while the browser's window is open
static var _pick_callback: JavaScriptObject = null

static func available() -> bool:
	return OS.has_feature("web")

## Offers `text` to the player as a downloaded file named `file_name`
static func download_text(file_name: String, text: String) -> void:
	if not available():
		return
	JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, "application/json")

## Opens the browser's file window; `on_text` is called with the chosen file's text
static func pick_text(on_text: Callable) -> void:
	if not available():
		return
	_pick_callback = JavaScriptBridge.create_callback(func(args: Array): on_text.call(String(args[0])))
	JavaScriptBridge.get_interface("window").justSudokuPickedText = _pick_callback
	JavaScriptBridge.eval(PICK_SCRIPT)
