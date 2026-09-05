extends Control
# Character Sheet UI
#
# Builds its form entirely from data/character_template.json at runtime.
# To customize the sheet for your own game system, edit that JSON file --
# add, remove, or reorder sections/fields. No code changes required for
# "text", "number", or "multiline" field types.

const TEMPLATE_PATH := "res://data/character_template.json"
const SAVE_DIR := "user://characters/"

@onready var sections_container: VBoxContainer = $Margin/VBox/Scroll/Sections
@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var save_button: Button = $Margin/VBox/ButtonRow/SaveButton
@onready var load_button: Button = $Margin/VBox/ButtonRow/LoadButton
@onready var close_button: Button = $Margin/VBox/ButtonRow/CloseButton

var template: Dictionary = {}
var field_controls: Dictionary = {} # key -> Control
var my_id: int = 1

func _ready() -> void:
	my_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_load_template()
	_build_form()
	_populate_from_state()

	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	close_button.pressed.connect(func(): queue_free())

	GameState.character_updated.connect(_on_character_updated)

func _load_template() -> void:
	if not FileAccess.file_exists(TEMPLATE_PATH):
		push_error("Character template not found at %s" % TEMPLATE_PATH)
		return
	var f := FileAccess.open(TEMPLATE_PATH, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	if err == OK:
		template = json.data
	else:
		push_error("Failed to parse character template JSON: %s" % json.get_error_message())

func _build_form() -> void:
	if template.is_empty():
		return
	title_label.text = template.get("system_name", "Character Sheet")

	for section in template.get("sections", []):
		var section_box := VBoxContainer.new()
		var header := Label.new()
		header.text = section.get("title", "")
		header.add_theme_font_size_override("font_size", 18)
		section_box.add_child(header)

		for field in section.get("fields", []):
			var row := HBoxContainer.new()
			var label := Label.new()
			label.text = field.get("label", field.get("key", ""))
			label.custom_minimum_size = Vector2(160, 0)
			row.add_child(label)

			var key: String = field.get("key")
			var control: Control

			match field.get("type", "text"):
				"number":
					var spin := SpinBox.new()
					spin.min_value = field.get("min", -999999)
					spin.max_value = field.get("max", 999999)
					spin.value = field.get("default", 0)
					spin.value_changed.connect(func(v): _on_field_changed(key, v))
					control = spin
				"multiline":
					var text_edit := TextEdit.new()
					text_edit.custom_minimum_size = Vector2(300, 100)
					text_edit.text = str(field.get("default", ""))
					text_edit.text_changed.connect(func(): _on_field_changed(key, text_edit.text))
					control = text_edit
				_: # "text" and anything unrecognized falls back to a line edit
					var line_edit := LineEdit.new()
					line_edit.text = str(field.get("default", ""))
					line_edit.custom_minimum_size = Vector2(200, 0)
					line_edit.text_changed.connect(func(t): _on_field_changed(key, t))
					control = line_edit

			row.add_child(control)
			section_box.add_child(row)
			field_controls[key] = control

		sections_container.add_child(section_box)
		sections_container.add_child(HSeparator.new())

func _populate_from_state() -> void:
	if not GameState.players.has(my_id):
		return
	var character: Dictionary = GameState.players[my_id]["character"]
	for key in character.keys():
		_set_control_value(key, character[key])

func _set_control_value(key: String, value) -> void:
	if not field_controls.has(key):
		return
	var control: Control = field_controls[key]
	if control is SpinBox:
		control.value = value
	elif control is TextEdit:
		control.text = str(value)
	elif control is LineEdit:
		control.text = str(value)

func _on_field_changed(key: String, value) -> void:
	if multiplayer.has_multiplayer_peer():
		GameState.request_character_update(key, value)
	else:
		# Offline/testing mode without networking active.
		if not GameState.players.has(my_id):
			GameState.players[my_id] = {"name": "You", "character": {}}
		GameState.players[my_id]["character"][key] = value

func _on_character_updated(peer_id: int, character: Dictionary) -> void:
	if peer_id != my_id:
		return
	for key in character.keys():
		_set_control_value(key, character[key])

func _on_save_pressed() -> void:
	var character: Dictionary = GameState.players.get(my_id, {}).get("character", {})
	var char_name: String = character.get("name", "unnamed")
	var path := SAVE_DIR + char_name.to_lower().replace(" ", "_") + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(character, "\t"))
	f.close()

func _on_load_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_USERDATA
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.current_dir = SAVE_DIR
	dialog.filters = PackedStringArray(["*.json ; Character Files"])
	add_child(dialog)
	dialog.file_selected.connect(func(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		if json.parse(f.get_as_text()) == OK:
			var data: Dictionary = json.data
			for key in data.keys():
				_on_field_changed(key, data[key])
		dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(600, 400))
