extends Node2D
# A single draggable token on the 2D board. Position changes are sent to
# GameState so every connected player sees the move.
#
# NOTE for a future 3D board: this script only touches Vector2 positions and
# the GameState API -- a Node3D token script would look almost identical,
# just driving `position` on a 3D node and sending (x, z) instead of (x, y).

@export var texture_path: String = ""
@export var token_id: String = ""
@export var token_name: String = ""

var dragging := false
var drag_offset := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel

func _ready() -> void:
	name_label.text = token_name
	_apply_texture()

func setup(id: String, t_name: String, t_texture: String, pos: Vector2) -> void:
	token_id = id
	token_name = t_name
	texture_path = t_texture
	position = pos
	if is_inside_tree():
		name_label.text = t_name
		_apply_texture()

func _apply_texture() -> void:
	var tex := _load_texture(texture_path)
	sprite.texture = tex if tex != null else _make_placeholder_texture()

# Textures picked via a FileDialog (ACCESS_FILESYSTEM) are arbitrary OS
# paths, not project resources -- `load()` only works for res://user://
# paths, so external images must go through Image.load_from_file() instead.
static func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if path.begins_with("res://") or path.begins_with("user://"):
		if ResourceLoader.exists(path):
			return load(path)
		return null
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null

func _make_placeholder_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.2, 0.2, 1.0))
	return ImageTexture.create_from_image(img)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_mouse: Vector2 = get_global_mouse_position()
			if sprite.get_rect().has_point(to_local(local_mouse)):
				dragging = true
				drag_offset = position - local_mouse
				get_viewport().set_input_as_handled()
		else:
			if dragging:
				dragging = false
				GameState.request_move_token(token_id, position.x, position.y)

	elif event is InputEventMouseMotion and dragging:
		position = get_global_mouse_position() + drag_offset
		# Send frequent (unreliable) updates while dragging so other players
		# see smooth movement, not just the final drop position.
		GameState.request_move_token(token_id, position.x, position.y)

func remote_set_position(x: float, y: float) -> void:
	# Called when another player moves this token; don't re-broadcast.
	if not dragging:
		position = Vector2(x, y)
