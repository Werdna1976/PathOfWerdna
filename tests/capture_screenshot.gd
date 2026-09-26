extends SceneTree
## Windowed (not headless) visual check. Run with:
##   godot --path <project> -s res://tests/capture_screenshot.gd
## Saves the game camera's view to res://tests/screenshot_m1.png.

const ARENA_PATH: String = "res://scenes/levels/test_arena.tscn"
const OUTPUT_PATH: String = "res://tests/screenshot_m1.png"
const SETTLE_FRAMES: int = 90  # let volumetric fog and shadows settle


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var arena: Node3D = (load(ARENA_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(arena)
	for i: int in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	print("screenshot %s: %s" % [OUTPUT_PATH, error_string(err)])
	quit(0 if err == OK else 1)
