extends Node

## Dev-only bridge for the Godot MCP addon's in-game services.
## The addon is excluded from release exports (see export_presets.cfg), so this resolves the
## services at runtime and does nothing when the files are absent, instead of the project
## declaring them as autoloads that a release build could not load.

const SERVICES: Dictionary = {
	"MCPGameInspector": "res://addons/godot_mcp/services/game_inspector.gd",
	"MCPGameInput": "res://addons/godot_mcp/services/game_input.gd",
}

func _ready() -> void:
	if not OS.has_feature("editor") and not OS.is_debug_build():
		return
	for node_name in SERVICES:
		var path: String = SERVICES[node_name]
		if get_tree().root.has_node(node_name) or not ResourceLoader.exists(path):
			continue
		var script: Script = load(path)
		if script == null:
			continue
		var service: Node = script.new()
		service.name = node_name
		get_tree().root.add_child.call_deferred(service)
