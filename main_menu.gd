extends Control
# Main menu: pick a name, then either host a new game (choose a password)
# or join one (enter host IP + password).

@onready var name_input: LineEdit = $Center/VBox/NameInput
@onready var password_input: LineEdit = $Center/VBox/PasswordInput
@onready var ip_input: LineEdit = $Center/VBox/IPInput
@onready var port_input: LineEdit = $Center/VBox/PortInput
@onready var host_button: Button = $Center/VBox/HostButton
@onready var join_button: Button = $Center/VBox/JoinButton
@onready var status_label: Label = $Center/VBox/StatusLabel

func _ready() -> void:
	ip_input.text = "127.0.0.1"
	port_input.text = str(NetworkManager.DEFAULT_PORT)
	password_input.placeholder_text = "Room password"
	name_input.placeholder_text = "Your display name"

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	NetworkManager.auth_success.connect(_on_auth_success)
	NetworkManager.auth_failed.connect(_on_auth_failed)

func _player_name() -> String:
	var n := name_input.text.strip_edges()
	return n if n != "" else "Player"

func _on_host_pressed() -> void:
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	var err := NetworkManager.host_game(password_input.text, _player_name(), port)
	if err == OK:
		status_label.text = "Hosting on port %d. Share your IP + password with friends." % port
		get_tree().change_scene_to_file("res://scenes/tabletop.tscn")
	else:
		status_label.text = "Failed to host (error %d)." % err

func _on_join_pressed() -> void:
	var port := int(port_input.text) if port_input.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	var err := NetworkManager.join_game(ip_input.text.strip_edges(), password_input.text, _player_name(), port)
	if err != OK:
		status_label.text = "Failed to connect (error %d)." % err
	else:
		status_label.text = "Connecting..."

func _on_auth_success() -> void:
	get_tree().change_scene_to_file("res://scenes/tabletop.tscn")

func _on_auth_failed() -> void:
	status_label.text = "Connection failed or wrong password."
	NetworkManager.disconnect_game()
