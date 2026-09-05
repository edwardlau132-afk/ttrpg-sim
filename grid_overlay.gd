extends CanvasLayer
# Grid Overlay System
#
# Provides a customizable grid overlay for the tabletop board.
# Supports square and hexagonal grids with configurable spacing and appearance.
# Grid state is networked via GameState for multiplayer synchronization.

class_name GridOverlay

const GRID_SETTINGS_PATH := "res://data/grid_config.json"

enum GridType {
	SQUARE,
	HEXAGONAL
}

signal grid_toggled(enabled: bool)
signal grid_size_changed(size: int)
signal grid_type_changed(type: int)

@export var grid_type: GridType = GridType.SQUARE
@export var grid_size: int = 50
@export var line_color: Color = Color(0.5, 0.5, 0.5, 0.3)
@export var line_width: float = 1.0
@export var enabled: bool = false

var grid_config: Dictionary = {}
var _canvas: CanvasItem

func _ready() -> void:
	_load_grid_config()
	if enabled:
		queue_redraw()

func _load_grid_config() -> void:
	if FileAccess.file_exists(GRID_SETTINGS_PATH):
		var f := FileAccess.open(GRID_SETTINGS_PATH, FileAccess.READ)
		var json := JSON.new()
		if json.parse(f.get_as_text()) == OK:
			grid_config = json.data
			grid_type = grid_config.get("type", GridType.SQUARE)
			grid_size = grid_config.get("size", 50)
			line_color = Color.html(grid_config.get("color", "#808080"))
			line_width = grid_config.get("line_width", 1.0)

func toggle_grid() -> void:
	enabled = !enabled
	if enabled:
		queue_redraw()
	grid_toggled.emit(enabled)

func set_grid_size(size: int) -> void:
	grid_size = clamp(size, 10, 200)
	if enabled:
		queue_redraw()
	grid_size_changed.emit(grid_size)

func set_grid_type(type: GridType) -> void:
	grid_type = type
	if enabled:
		queue_redraw()
	grid_type_changed.emit(type)

func _draw() -> void:
	if not enabled:
		return

	match grid_type:
		GridType.SQUARE:
			_draw_square_grid()
		GridType.HEXAGONAL:
			_draw_hexagonal_grid()

func _draw_square_grid() -> void:
	var viewport_size := get_viewport_rect().size

	var x := 0.0
	while x < viewport_size.x:
		draw_line(Vector2(x, 0), Vector2(x, viewport_size.y), line_color, line_width)
		x += grid_size

	var y := 0.0
	while y < viewport_size.y:
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), line_color, line_width)
		y += grid_size

func _draw_hexagonal_grid() -> void:
	var viewport_size := get_viewport_rect().size
	var hex_size := float(grid_size) / 2.0
	var hex_height := hex_size * sqrt(3.0)

	var y := 0.0
	var row := 0
	while y < viewport_size.y:
		var x_offset := (row % 2) * hex_size
		var x := 0.0
		while x < viewport_size.x + hex_size:
			_draw_hexagon(Vector2(x + x_offset, y), hex_size)
			x += hex_size * 2.0
		y += hex_height
		row += 1

func _draw_hexagon(center: Vector2, radius: float) -> void:
	var points: PackedVector2Array = []
	for i in range(6):
		var angle := TAU / 6.0 * i
		var x := center.x + radius * cos(angle)
		var y := center.y + radius * sin(angle)
		points.append(Vector2(x, y))

	for i in range(6):
		var p1 := points[i]
		var p2 := points[(i + 1) % 6]
		draw_line(p1, p2, line_color, line_width)

func get_grid_position(world_pos: Vector2) -> Vector2:
	if grid_type == GridType.SQUARE:
		return (world_pos / grid_size).round() * grid_size
	else:
		return world_pos

func save_grid_config() -> void:
	var config := {
		"type": grid_type,
		"size": grid_size,
		"color": line_color.to_html(),
		"line_width": line_width
	}
	var dir := DirAccess.open("res://data")
	if dir == null:
		DirAccess.make_dir_absolute("res://data")
	var f := FileAccess.open(GRID_SETTINGS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(config, "\t"))
