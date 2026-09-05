extends Node
# Grid Manager Autoload
#
# Manages the grid overlay system for easy access throughout the game.

var grid_overlay: CanvasLayer
var is_grid_enabled: bool = false

func _ready() -> void:
	if grid_overlay == null:
		grid_overlay = GridOverlay.new()
		add_child(grid_overlay)

func toggle_grid() -> void:
	grid_overlay.toggle_grid()

func set_grid_size(size: int) -> void:
	grid_overlay.set_grid_size(size)

func set_grid_type(type: int) -> void:
	grid_overlay.set_grid_type(type)

func is_grid_visible() -> bool:
	return grid_overlay.enabled if grid_overlay else false
