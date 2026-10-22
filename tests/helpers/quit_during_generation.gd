extends SceneTree

## Child process for test_clean_exit.gd: opens the app, starts a New Game preview (background
## generation) and quits while it is still running. Exit code 0 means the engine shut down cleanly.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var app := AppRoot.new()
	get_root().add_child(app)
	for i in range(5):
		await process_frame
	app.new_game_dialog.open_dialog()
	await process_frame
	quit(0)
