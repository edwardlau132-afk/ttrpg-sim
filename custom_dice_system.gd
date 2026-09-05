extends Node
# Custom Dice System
#
# Extends the base DiceRoller with support for custom dice definitions,
# custom die sets, and advanced roll formulas. Configurations are JSON-based.

class_name CustomDiceSystem

const DICE_CONFIG_PATH := "res://data/dice_config.json"
const DICE_PRESETS_PATH := "res://data/dice_presets.json"

signal custom_roll_completed(formula: String, result: Dictionary)

var dice_config: Dictionary = {}
var dice_presets: Dictionary = {}

func _ready() -> void:
	_load_dice_config()
	_load_dice_presets()

func _load_dice_config() -> void:
	if FileAccess.file_exists(DICE_CONFIG_PATH):
		var f := FileAccess.open(DICE_CONFIG_PATH, FileAccess.READ)
		var json := JSON.new()
		if json.parse(f.get_as_text()) == OK:
			dice_config = json.data

func _load_dice_presets() -> void:
	if FileAccess.file_exists(DICE_PRESETS_PATH):
		var f := FileAccess.open(DICE_PRESETS_PATH, FileAccess.READ)
		var json := JSON.new()
		if json.parse(f.get_as_text()) == OK:
			dice_presets = json.data

func roll_custom_formula(formula: String) -> Dictionary:
	var expanded_formula := formula
	for preset_name in dice_presets.keys():
		if expanded_formula.contains(preset_name):
			var preset_formula = dice_presets[preset_name].get("formula", "")
			expanded_formula = expanded_formula.replace(preset_name, preset_formula)

	var result := DiceRoller.roll(expanded_formula)
	custom_roll_completed.emit(formula, result)
	return result

func create_dice_preset(name: String, formula: String, description: String = "") -> bool:
	if not dice_presets.has(name):
		dice_presets[name] = {
			"formula": formula,
			"description": description
		}
		return save_dice_presets()
	return false

func delete_dice_preset(name: String) -> bool:
	if dice_presets.has(name):
		dice_presets.erase(name)
		return save_dice_presets()
	return false

func get_all_presets() -> Dictionary:
	return dice_presets.duplicate()

func save_dice_presets() -> bool:
	var dir := DirAccess.open("res://data")
	if dir == null:
		DirAccess.make_dir_absolute("res://data")

	var f := FileAccess.open(DICE_PRESETS_PATH, FileAccess.WRITE)
	if f == null:
		return false

	f.store_string(JSON.stringify(dice_presets, "\t"))
	return true

func create_custom_die(name: String, sides: int) -> bool:
	if not dice_config.has(name):
		dice_config[name] = {
			"sides": sides,
			"created_at": Time.get_ticks_msec()
		}
		return save_dice_config()
	return false

func delete_custom_die(name: String) -> bool:
	if dice_config.has(name):
		dice_config.erase(name)
		return save_dice_config()
	return false

func get_all_custom_dice() -> Dictionary:
	return dice_config.duplicate()

func save_dice_config() -> bool:
	var dir := DirAccess.open("res://data")
	if dir == null:
		DirAccess.make_dir_absolute("res://data")

	var f := FileAccess.open(DICE_CONFIG_PATH, FileAccess.WRITE)
	if f == null:
		return false

	f.store_string(JSON.stringify(dice_config, "\t"))
	return true

func roll_preset(preset_name: String) -> Dictionary:
	if dice_presets.has(preset_name):
		var formula = dice_presets[preset_name].get("formula", "")
		return roll_custom_formula(formula)
	return {"total": 0, "rolls": [], "breakdown": "Preset not found: %s" % preset_name}

func roll_weighted_dice(sides: int, weights: Array) -> int:
	if weights.is_empty() or weights.size() != sides:
		return randi_range(1, sides)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var total := 0.0
	var roll := rng.randf() * 100.0

	for i in range(sides):
		total += float(weights[i])
		if roll <= total:
			return i + 1

	return sides
