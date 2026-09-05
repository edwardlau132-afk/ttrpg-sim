extends Control
# Fillable Document System
#
# Allows creation and editing of fillable form documents with text fields,
# checkboxes, and multi-line text areas. Documents are saved/loaded as JSON.

class_name FillableDocument

const DOCUMENTS_DIR := "user://documents/"
const TEMPLATE_DIR := "res://data/document_templates/"

signal document_saved(path: String)
signal document_loaded(path: String)

var document_data: Dictionary = {}
var document_name: String = ""
var field_controls: Dictionary = {}
var template_path: String = ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DOCUMENTS_DIR)
	DirAccess.make_dir_recursive_absolute(TEMPLATE_DIR)

func load_template(template_name: String) -> bool:
	template_path = TEMPLATE_DIR + template_name + ".json"
	if not FileAccess.file_exists(template_path):
		push_error("Template not found: %s" % template_path)
		return false

	var f := FileAccess.open(template_path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_error("Failed to parse template JSON")
		return false

	var template: Dictionary = json.data
	document_data = template.get("fields", {})
	builder_from_template(template)
	return true

func builder_from_template(template: Dictionary) -> void:
	clear_controls()

	var title_label := Label.new()
	title_label.text = template.get("title", "Fillable Document")
	title_label.add_theme_font_size_override("font_size", 20)
	add_child(title_label)

	var fields = template.get("sections", [])
	for section in fields:
		var section_label := Label.new()
		section_label.text = section.get("title", "")
		section_label.add_theme_font_size_override("font_size", 16)
		add_child(section_label)

		for field in section.get("fields", []):
			_create_field(field)

func _create_field(field: Dictionary) -> void:
	var key: String = field.get("key", "")
	var label_text: String = field.get("label", key)
	var field_type: String = field.get("type", "text")

	var container := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200, 0)
	container.add_child(label)

	var control: Control

	match field_type:
		"text":
			var line_edit := LineEdit.new()
			line_edit.text = str(document_data.get(key, ""))
			line_edit.custom_minimum_size = Vector2(300, 0)
			line_edit.text_changed.connect(func(t): document_data[key] = t)
			control = line_edit

		"multiline":
			var text_edit := TextEdit.new()
			text_edit.text = str(document_data.get(key, ""))
			text_edit.custom_minimum_size = Vector2(300, 100)
			text_edit.text_changed.connect(func(): document_data[key] = text_edit.text)
			control = text_edit

		"checkbox":
			var check_box := CheckBox.new()
			check_box.button_pressed = document_data.get(key, false)
			check_box.toggled.connect(func(pressed): document_data[key] = pressed)
			control = check_box

		"number":
			var spin_box := SpinBox.new()
			spin_box.min_value = field.get("min", -999999)
			spin_box.max_value = field.get("max", 999999)
			spin_box.value = float(document_data.get(key, 0))
			spin_box.value_changed.connect(func(v): document_data[key] = v)
			control = spin_box

		_:
			var line_edit := LineEdit.new()
			line_edit.text = str(document_data.get(key, ""))
			line_edit.text_changed.connect(func(t): document_data[key] = t)
			control = line_edit

	container.add_child(control)
	add_child(container)
	field_controls[key] = control

func clear_controls() -> void:
	for child in get_children():
		child.queue_free()
	field_controls.clear()

func save_document(file_name: String) -> bool:
	document_name = file_name
	var path := DOCUMENTS_DIR + file_name + ".json"

	var save_data := {
		"name": document_name,
		"template": template_path,
		"fields": document_data,
		"saved_at": Time.get_ticks_msec()
	}

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to save document")
		return false

	f.store_string(JSON.stringify(save_data, "\t"))
	document_saved.emit(path)
	return true

func load_document(file_name: String) -> bool:
	document_name = file_name
	var path := DOCUMENTS_DIR + file_name + ".json"

	if not FileAccess.file_exists(path):
		push_error("Document not found: %s" % path)
		return false

	var f := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_error("Failed to parse document JSON")
		return false

	var loaded_data: Dictionary = json.data
	document_data = loaded_data.get("fields", {})
	template_path = loaded_data.get("template", "")

	if FileAccess.file_exists(template_path):
		var f2 := FileAccess.open(template_path, FileAccess.READ)
		var json2 := JSON.new()
		if json2.parse(f2.get_as_text()) == OK:
			builder_from_template(json2.data)
			_populate_fields()

	document_loaded.emit(path)
	return true

func _populate_fields() -> void:
	for key in document_data.keys():
		if field_controls.has(key):
			var control = field_controls[key]
			var value = document_data[key]

			if control is LineEdit:
				control.text = str(value)
			elif control is TextEdit:
				control.text = str(value)
			elif control is CheckBox:
				control.button_pressed = bool(value)
			elif control is SpinBox:
				control.value = float(value)

func get_document_data() -> Dictionary:
	return document_data.duplicate()
