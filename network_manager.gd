extends Node
# NetworkManager (Autoload)
#
# Handles hosting/joining a game over Godot's high-level multiplayer API
# (ENet), plus a simple password handshake since ENet has no built-in auth.
#
# Flow:
#   Host  -> create_server(), waits for peers to connect, then waits for
#            each peer to submit a password via RPC.
#   Client -> create_client(), once connected automatically submits the
#            password. If wrong, the server disconnects it.

signal auth_success
signal auth_failed
signal player_list_changed

const DEFAULT_PORT := 8910
const MAX_PLAYERS := 8

var password := ""
var is_host := false
var pending_player_name := "Player"

func host_game(pw: String, player_name: String, port: int = DEFAULT_PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = peer
	password = pw
	is_host = true

	# Host is always peer id 1 and is auto-authenticated.
	GameState.register_player(1, player_name)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return OK

func join_game(ip: String, pw: String, player_name: String, port: int = DEFAULT_PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err

	multiplayer.multiplayer_peer = peer
	password = pw
	is_host = false
	pending_player_name = player_name

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	return OK

func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	GameState.reset()

# --- Client side ---

func _on_connected_to_server() -> void:
	_submit_password.rpc_id(1, password, pending_player_name)

func _on_connection_failed() -> void:
	auth_failed.emit()

@rpc("authority", "reliable")
func _auth_result(success: bool) -> void:
	if success:
		auth_success.emit()
	else:
		auth_failed.emit()

# --- Server side ---

func _on_peer_connected(_id: int) -> void:
	pass # We wait for the peer to submit a password before trusting them.

func _on_peer_disconnected(id: int) -> void:
	GameState.unregister_player(id)
	player_list_changed.emit()

@rpc("any_peer", "reliable")
func _submit_password(pw: String, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if pw == password:
		GameState.register_player(sender, player_name)
		_auth_result.rpc_id(sender, true)
		player_list_changed.emit()
	else:
		_auth_result.rpc_id(sender, false)
		# Give the RPC a moment to actually send before dropping the peer.
		var timer := get_tree().create_timer(0.3)
		timer.timeout.connect(func():
			if multiplayer.multiplayer_peer:
				multiplayer.multiplayer_peer.disconnect_peer(sender)
		)
