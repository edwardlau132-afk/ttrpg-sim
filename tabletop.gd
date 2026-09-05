extends Control
# Main Tabletop screen.
#
# Layout:
#   BoardRoot (Node2D)      <- the 2D map + tokens. Swap this subtree for a
#                              Node3D + Camera3D setup to go 3D; nothing else
#                              in this script needs to change since it only
#                              talks to GameState, never to rendering details.
#   SidePanel (Control)     <- dice roller, chat, player list, character sheet button

const TOKEN_SCENE := preload("res://scenes/token.tscn")
const CHARACTER_SHEET_SCENE := preload("res://scenes/character_sheet.tscn")
const FILLABLE_DOCUMENT_SCENE := preload("res://scenes/fillable_document.tscn")

@onready var board_root: Node2D = $HSplit/BoardRoot
@onready var map_background: TextureRect = $HSplit/BoardRoot/MapBackground
@onready var token_layer: Node2D = $HSplit/BoardRoot/TokenLayer

@onready var dice_formula_input: LineEdit = $HSplit/SidePanel/VBox/DicePanel/FormulaRow/FormulaInput
@onready var roll_button: Button = $HSplit/SidePanel/VBox/DicePanel/FormulaRow/RollButton
@onready var quick_dice_row: HBoxContainer = $HSplit/SidePanel/VBox/DicePanel/QuickRow
@onready var log_display: RichTextLabel = $HSplit/SidePanel/VBox/LogPanel/LogDisplay

@onready var chat_input: LineEdit = $HSplit/SidePanel/VBox/ChatRow/ChatInput
@onready var chat_send: Button = $HSplit/SidePanel/VBox/ChatRow/ChatSend

@onready var player_list: ItemList = $HSplit/SidePanel/VBox/PlayerList
@onready var character_sheet_button: Button = $HSplit/SidePanel/VBox/ButtonsRow/CharacterSheetButton
@onready var add_token_button: Button = $HSplit/SidePanel/VBox/ButtonsRow/AddTokenButton
@onready var load_map_button: Button = $HSplit/SidePanel/VBox/ButtonsRow/LoadMapButton

var token_nodes: Dictionary = {}
var grid_overlay: CanvasLayer

func _ready() -> void:
	# Setup grid overlay
	grid_overlay = GridOverlay.new()
	add_child(grid_overlay)
	
	# Create grid toggle button
	var grid_toggle_button := Button.new()
	grid_toggle_button.text = "Toggle Grid"
	grid_toggle_button.pressed.connect(_on_grid_toggle_pressed)
	quick_dice_row.add_child(grid_toggle_button)
	
	# Create custom dice presets button
	var custom_dice_button := Button.new()
	custom_dice_button.text = "Dice Presets"
	custom_dice_button.pressed.connect(_on_dice_presets_pressed)
	quick_dice_row.add_child(custom_dice_button)
	
	# Create fillable document button
	var document_button := Button.new()
	document_button.text = "Forms"
	document_button.pressed.connect(_on_open_document)
	quick_dice_row.add_child(document_button)
	
	roll_button.pressed.connect(_on_roll_pressed)
	for die in [4, 6, 8, 10, 12, 20, 100]:
		var b := Button.new()
		b.text = "d%d" % die
		b.pressed.connect(func(): GameState.roll_and_broadcast("1d%d" % die))
		quick_dice_row.add_child(b)

	chat_send.pressed.connect(_on_chat_send)
	chat_input.text_submitted.connect(func(_t): _on_chat_send())

	character_sheet_button.pressed.connect(_on_open_character_sheet)
	add_token_button.pressed.connect(_on_add_token_pressed)
	load_map_button.pressed.connect(_on_load_map_pressed)

	GameState.dice_rolled.connect(_on_dice_rolled)
	GameState.chat_message_received.connect(_on_chat_received)
	GameState.player_list_changed.connect(_refresh_player_list)
	GameState.token_added.connect(_on_token_added)
	GameState.token_moved.connect(_on_token_moved)
	GameState.token_removed.connect(_on_token_removed)

	_refresh_player_list()
	for id in GameState.tokens.keys():
		_on_token_added(id, GameState.tokens[id])

func _on_grid_toggle_pressed() -> void:
	GridOverlay.toggle_grid()

func _on_dice_presets_pressed() -> void:
	var presets = CustomDiceSystem.get_all_presets()
	if presets.is_empty():
		log_display.append_text("[color=yellow]No dice presets available.[/color]\n")
		return
	
	var preset_menu = PopupMenu.new()
	var index = 0
	for preset_name in presets.keys():
		var desc = presets[preset_name].get("description", "")
		preset_menu.add_item("%s - %s" % [preset_name, desc], index)
		index += 1
	
	preset_menu.id_pressed.connect(func(id: int): _on_preset_selected(id, presets.keys()))
	add_child(preset_menu)
	preset_menu.popup_rect(Rect2(get_global_mouse_position(), Vector2(300, 200)))

func _on_preset_selected(index: int, preset_names: Array) -> void:
	if index >= 0 and index < preset_names.size():
		var preset_name = preset_names[index]
		var result = CustomDiceSystem.roll_preset(preset_name)
		GameState.roll_and_broadcast(result.get("breakdown", ""))

func _on_open_document() -> void:
	var doc = FILLABLE_DOCUMENT_SCENE.instantiate()
	add_child(doc)
	if doc.load_template("character_sheet_form"):
		log_display.append_text("[color=green]Loaded character sheet form.[/color]\n")
	else:
		log_display.append_text("[color=red]Failed to load form template.[/color]\n")

func _on_roll_pressed() -> void:
	var formula := dice_formula_input.text.strip_edges()
	if formula != "":
		GameState.roll_and_broadcast(formula)

func _on_dice_rolled(player_name: String, formula: String, total: int, breakdown: String) -> void:
	log_display.append_text("[b]%s[/b] rolled %s: %s = [b]%d[/b]\n" % [player_name, formula, breakdown, total])

func _on_chat_send() -> void:
	var text := chat_input.text.strip_edges()
	if text != "":
		GameState.send_chat(text)
		chat_input.text = ""

func _on_chat_received(player_name: String, text: String) -> void:
	log_display.append_text("[color=gray]%s: %s[/color]\n" % [player_name, text])

func _refresh_player_list() -> void:
	player_list.clear()
	for id in GameState.players.keys():
		player_list.add_item(GameState.players[id]["name"])

func _on_open_character_sheet() -> void:
	var sheet := CHARACTER_SHEET_SCENE.instantiate()
	add_child(sheet)

func _on_add_token_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg ; Images"])
	add_child(dialog)
	dialog.file_selected.connect(func(path):
		var id := GameState.generate_token_id()
		GameState.request_add_token(id, "New Token", path, 400.0, 300.0)
		dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(700, 500))

func _on_load_map_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg ; Map Images"])
	add_child(dialog)
	dialog.file_selected.connect(func(path):
		if ResourceLoader.exists(path):
			map_background.texture = load(path)
		else:
			var img := Image.load_from_file(path)
			if img:
				map_background.texture = ImageTexture.create_from_image(img)
		dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(700, 500))

func _on_token_added(token_id: String, data: Dictionary) -> void:
	if token_nodes.has(token_id):
		return
	var token := TOKEN_SCENE.instantiate()
	token_layer.add_child(token)
	token.setup(token_id, data.get("name", ""), data.get("texture", ""), Vector2(data.get("x", 0), data.get("y", 0)))
	token_nodes[token_id] = token

func _on_token_moved(token_id: String, x: float, y: float) -> void:
	if token_nodes.has(token_id):
		token_nodes[token_id].remote_set_position(x, y)

func _on_token_removed(token_id: String) -> void:
	if token_nodes.has(token_id):
		token_nodes[token_id].queue_free()
		token_nodes.erase(token_id)
