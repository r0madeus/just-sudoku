# Slimmed Godot 4.7 export template for Just Sudoku: a 2D game on the Compatibility (GLES3)
# renderer, offline, with no audio files (sounds are generated in code). Build with:
#   scons platform=android target=template_release arch=arm64 profile=<this file>
# The official template carries 3D, physics, navigation, XR, Vulkan and ~40 modules the game
# never uses; leaving them out is most of the size. tests/test_engine_profile.gd checks that
# nothing the game relies on is listed here as disabled.

production = True  # static C++ runtime, link-time optimisation, no debug symbols
optimize = "size_extra"
deprecated = False

disable_3d = True
disable_physics_2d = True
disable_physics_3d = True
disable_navigation_2d = True
disable_navigation_3d = True
disable_xr = True
vulkan = False  # the game renders with GL Compatibility only
brotli = False  # only for WOFF2 fonts; the bundled fonts are TTF
swappy = False  # frame pacing for Vulkan, which is not built

# Only the modules the game uses
modules_enabled_by_default = False
module_gdscript_enabled = True
module_freetype_enabled = True  # the bundled fonts
module_text_server_adv_enabled = True  # shaping, line breaking, variable font weight
graphite = False  # Graphite shaping is for scripts the game does not show
module_svg_enabled = True  # the engine's built-in theme icons (pickers, menus) are SVG
module_webp_enabled = True  # imported textures are stored as lossless WebP
