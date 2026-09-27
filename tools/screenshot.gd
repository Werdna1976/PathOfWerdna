extends SceneTree
## Windowed screenshot tool for checking how scenes look. Needs a window and
## GPU, so run it without --headless:
##   godot --path <project> -s res://tools/screenshot.gd -- --scene=res://scenes/kit/kit_showcase.tscn --at=0,0,0 --out=res://tests/shots/kit.png
## Options (all optional):
##   --scene=<path>     scene to load (default: the game, scenes/main.tscn)
##   --at=x,y,z         point to look at; in the game the player is moved there
##   --distance=<m>     camera distance (default 22, the gameplay camera)
##   --pitch=<deg> --yaw=<deg>   camera angles (default 55 and 45, the gameplay camera)
##   --out=<path>       where to save the PNG (default res://tests/shots/shot.png)
##   --size=WxH         window size (default 1600x900)
##   --frames=<n>       frames to wait before capturing (default 150)

var _args: Dictionary = {}


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_run.call_deferred()


func _run() -> void:
	var size_parts: PackedStringArray = str(_args.get("size", "1600x900")).split("x")
	root.size = Vector2i(int(size_parts[0]), int(size_parts[1]))
	var path: String = _args.get("scene", "res://scenes/main.tscn")
	var at: Vector3 = _vec(_args.get("at", "0,0,0"))
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	if scene is Game:
		var game: Game = scene as Game
		var zone_path: String = _args.get("zone", "")
		if zone_path != "":
			await process_frame
			game.change_zone(zone_path, StringName(_args.get("entry", "start")))
		for i: int in 30:
			await physics_frame
		game.player.global_position = at
		game.player.reset_physics_interpolation()
		game.camera.snap_to_target()
		if _args.has("hide_hud"):
			game.hud.visible = false
		# --drops=N scatters N random items (and some orbs) around the player.
		var gen := ItemGenerator.new(7)
		for i: int in int(_args.get("drops", "0")):
			var angle: float = TAU * i / maxf(float(_args.get("drops", "1")), 1.0)
			var base: ItemBase = gen.random_base(40, i % 4 == 0)
			var item: Item = gen.generate(base, 40, -1, 150.0)
			GroundItem.spawn(item, game.current_zone, at + Vector3(cos(angle), 0, sin(angle)) * 2.2)
		# --inventory fills the bag with random items and opens the inventory.
		if _args.has("inventory"):
			var inventory: Inventory = game.player.get_node("Inventory") as Inventory
			for i: int in 14:
				inventory.try_add(gen.generate(gen.random_base(40, i % 5 == 0), 40, -1, 150.0))
			game.hud.inventory_screen.toggle()
	else:
		var cam := Camera3D.new()
		cam.fov = 35.0
		cam.far = 300.0
		cam.rotation = Vector3(deg_to_rad(-float(_args.get("pitch", "55"))), deg_to_rad(float(_args.get("yaw", "45"))), 0.0)
		root.add_child(cam)
		cam.global_position = at + cam.basis.z * float(_args.get("distance", "22"))
		cam.current = true
	for i: int in int(_args.get("frames", "150")):
		await process_frame
	await RenderingServer.frame_post_draw
	var out: String = _args.get("out", "res://tests/shots/shot.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(ProjectSettings.globalize_path(out))
	print("screenshot %s: %s" % [out, error_string(err)])
	quit(0 if err == OK else 1)


func _vec(text: String) -> Vector3:
	var p: PackedStringArray = text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
