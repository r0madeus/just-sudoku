extends SceneTree

## The Android and browser builds use a slimmed engine (engine/custom.py) without 3D, physics,
## navigation, XR, Vulkan and most modules. This keeps the game honest about it: no game script may
## use a class that build leaves out, and the game's files must only need the modules it keeps.

var tests_passed: int = 0
var tests_failed: int = 0

## What each switch in the profile takes away, by the classes a script would use
const LEFT_OUT := {
	"disable_3d": ["Node3D", "Camera3D", "MeshInstance3D", "Sprite3D", "Label3D", "DirectionalLight3D",
		"OmniLight3D", "SpotLight3D", "WorldEnvironment", "GPUParticles3D", "CPUParticles3D", "SubViewport3D"],
	"disable_physics_2d": ["Area2D", "StaticBody2D", "CharacterBody2D", "RigidBody2D", "CollisionShape2D",
		"CollisionPolygon2D", "RayCast2D", "ShapeCast2D", "PhysicsServer2D", "PhysicsBody2D"],
	"disable_physics_3d": ["Area3D", "StaticBody3D", "CharacterBody3D", "RigidBody3D", "CollisionShape3D", "PhysicsServer3D"],
	"disable_navigation_2d": ["NavigationAgent2D", "NavigationRegion2D", "NavigationServer2D", "NavigationPolygon"],
	"disable_navigation_3d": ["NavigationAgent3D", "NavigationRegion3D", "NavigationServer3D", "NavigationMesh"],
	"disable_xr": ["XRServer", "XROrigin3D", "XRCamera3D", "XRInterface", "OpenXRInterface"],
	# Modules that are not kept
	"modules": ["RegEx", "RegExMatch", "JSONRPC", "WebSocketPeer", "WebRTCPeerConnection", "ENetMultiplayerPeer",
		"SceneMultiplayer", "MultiplayerSpawner", "MultiplayerSynchronizer", "UPNP", "ZIPPacker", "ZIPReader",
		"Crypto", "CryptoKey", "X509Certificate", "TLSOptions", "StreamPeerTLS", "HTTPRequest", "HTTPClient",
		"AudioStreamOggVorbis", "AudioStreamMP3", "VideoStreamTheora", "FastNoiseLite", "NoiseTexture2D",
		"GLTFDocument", "FBXDocument", "GridMap", "VisualShader", "CameraServer", "CameraFeed",
		"load_jpg_from_buffer", "load_tga_from_buffer", "load_bmp_from_buffer", "load_ktx_from_buffer"],
}

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func _files(dir_path: String, ext: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.get_extension() == ext:
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		if not d.begins_with("."):
			_files(dir_path.path_join(d), ext, out)

## The script without its comments and strings, so prose like "Navigation bar" does not count
func _code_only(text: String) -> String:
	var out := PackedStringArray()
	var strip := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"|#.*$")
	for line in text.split("\n"):
		out.append(strip.sub(line, "", true))
	return "\n".join(out)

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING ENGINE PROFILE TESTS")
	print("========================================")
	var profile := FileAccess.get_file_as_string("res://engine/custom.py")
	assert_true(not profile.is_empty(), "engine/custom.py is there")

	print("\n--- Test 1: The profile ---")
	for key in ["disable_3d", "disable_physics_2d", "disable_physics_3d", "disable_navigation_2d",
			"disable_navigation_3d", "disable_xr"]:
		assert_true(profile.contains("%s = True" % key), "%s is set" % key)
	assert_true(profile.contains("vulkan = False") and ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "gl_compatibility",
		"Vulkan left out, and the game renders with GL Compatibility")
	assert_true(profile.contains("modules_enabled_by_default = False"), "Modules are opt-in")

	print("\n--- Test 2: No game script uses what the slim engine leaves out ---")
	var scripts: Array = []
	_files("res://scenes", "gd", scripts)
	_files("res://scripts", "gd", scripts)
	var used: Array = []
	for path in scripts:
		var code := _code_only(FileAccess.get_file_as_string(path))
		for group in LEFT_OUT:
			for cls in LEFT_OUT[group]:
				if RegEx.create_from_string("\\b%s\\b" % cls).search(code) != null:
					used.append("%s uses %s (%s)" % [path.get_file(), cls, group])
	assert_true(scripts.size() > 20 and used.is_empty(), "%d scripts checked; %s" % [scripts.size(), str(used)])

	print("\n--- Test 3: The game's files need only the kept modules ---")
	var assets: Array = []
	for ext in ["ogg", "mp3", "woff2", "jpg", "jpeg", "tga", "bmp", "ktx", "exr", "hdr", "glb", "gltf", "fbx", "ogv"]:
		_files("res://assets", ext, assets)
		_files("res://scenes", ext, assets)
	assert_true(assets.is_empty(), "No sounds, fonts or images in formats the slim engine cannot read %s" % str(assets))
	var imports: Array = []
	_files("res://assets", "import", imports)
	var bad: Array = []
	for path in imports:
		var cfg := ConfigFile.new()
		cfg.load(path)
		if cfg.get_value("params", "multichannel_signed_distance_field", false):
			bad.append("%s uses MSDF fonts (msdfgen is not kept)" % path.get_file())
		if int(cfg.get_value("params", "compress/mode", 0)) != 0 and cfg.get_value("remap", "importer", "") == "texture":
			bad.append("%s is not lossless" % path.get_file())
	assert_true(bad.is_empty(), "Fonts and textures import in forms the kept modules read %s" % str(bad))

	print("\n--- Test 4: The browser build is made on the same engine ---")
	var web := FileAccess.get_file_as_string("res://.github/workflows/web.yml")
	assert_true(web.contains("platform=web target=template_release threads=no arch=wasm32") and web.contains("profile=\"$GITHUB_WORKSPACE/engine/custom.py\""),
		"The web workflow builds the single-threaded web template with the profile")
	assert_true(web.contains("hashFiles('engine/custom.py')") and web.contains("actions/cache@v4"),
		"and caches it by the profile's hash, so it is rebuilt only when the profile changes")
	assert_true(web.contains("emscripten-core/setup-emsdk") and RegEx.create_from_string("EMSCRIPTEN_VERSION: \"4\\.\\d+\\.\\d+\"").search(web) != null,
		"with a pinned Emscripten")
	assert_true(web.contains("[preset.1.options]") and web.contains("custom_template/release"),
		"The Web preset is pointed at it for the build (the committed preset keeps the official template)")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_true(presets.contains("name=\"Web\"") and not presets.contains("slim-web-template"),
		"The committed export presets do not name a CI-only path")
	assert_true(web.contains("tools/web_smoke.js") and FileAccess.file_exists("res://tools/web_smoke.js"),
		"The result is started in Chrome before it is published")
	assert_true(not profile.contains("javascript_eval = False"),
		"The profile keeps JavaScript eval, which the browser's file backup (JavaScriptBridge) needs")
	var web_files := FileAccess.get_file_as_string("res://scripts/services/web_files.gd")
	assert_true(web_files.contains("JavaScriptBridge"), "and the game does use JavaScriptBridge there")

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)
