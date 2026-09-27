extends SceneTree
## Renders every icon in assets/icons/ onto one contact sheet for review:
##   godot --headless --path <project> -s res://tools/icon_sheet.gd
## Saves tests/shots/icon_sheet.png.

const DIR: String = "res://assets/icons/"
const CELL: int = 136
const COLUMNS: int = 10


func _initialize() -> void:
	var files: Array[String] = []
	for f: String in DirAccess.get_files_at(DIR):
		if f.ends_with(".svg"):
			files.append(f)
	files.sort()
	var rows: int = ceili(float(files.size()) / COLUMNS)
	var sheet: Image = Image.create(COLUMNS * CELL, rows * CELL * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.06, 0.055, 0.05))
	for i: int in files.size():
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(DIR + files[i]), 1.0)
		var scale: float = minf(float(CELL - 8) / img.get_width(), float(CELL * 2 - 8) / img.get_height())
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale))
		var at := Vector2i((i % COLUMNS) * CELL + (CELL - img.get_width()) / 2, (i / COLUMNS) * CELL * 2 + 4)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	var out: String = "res://tests/shots/icon_sheet.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	sheet.save_png(ProjectSettings.globalize_path(out))
	print("icon sheet: %d icons -> %s" % [files.size(), out])
	for i: int in files.size():
		if i % COLUMNS == 0:
			print("row %d: %s" % [i / COLUMNS, ", ".join(files.slice(i, i + COLUMNS))])
	quit(0)
