extends Node
# GameState (Autoload)
#
# Single source of truth for everything shared between players: who's
# connected, character data, token positions, dice history, chat. This node
# doesn't care whether the board is drawn in 2D or 3D -- scenes read/write
# this data and react to its signals.
#
# NETWORK PATTERN: every player-triggered action follows the same shape:
#   1. `request_X(...)`  - any peer may call this. Sent with rpc_id(1, ...),
#      so it always lands on the server (self-calls on the host execute
#      immediately, no network round-trip needed).
#   2. The server validates/processes it, then calls `_apply_X(...).rpc(...)`
#      which is "authority" + "call_local", so it fans out to every
#      connected peer (including the server itself).
# This avoids the common bug of a client's rpc() only reaching the host.

signal player_list_changed
signal character_updated(peer_id: int, character: Dictionary)
signal dice_rolled(player_name: String, formula: String, total: int, breakdown: String)
signal chat_message_received(player_name: String, text: String)
signal token_added(token_id: String, data: Dictionary)
signal token_moved(token_id: String, x: float, y: float)
signal token_removed(token_id: String)

var players: Dictionary = {}   # peer_id -> { "name": String, "character": Dictionary }
var tokens: Dictionary = {}    # token_id -> { "name": String, "texture": String, "x": float, "y": float, "owner_id": int }
var chat_log: Array = []

var _next_token_id := 0

func reset() -> void:
	players.clear()
	tokens.clear()
	chat_log.clear()
	_next_token_id = 0

# --- Players (registration is driven by NetworkManager, not RPC'd here) ---

func register_player(id: int, player_name: String) -> void:
	players[id] = {"name": player_name, "character": {}}
	player_list_changed.emit()

func unregister_player(id: int) -> void:
	players.erase(id)
	player_list_changed.emit()

func get_player_name(id: int) -> String:
	if players.has(id):
		return players[id]["name"]
	return "Unknown"

# --- Character sheets ---

func request_character_update(field: String, value) -> void:
	request_character_field.rpc_id(1, field, value)

@rpc("any_peer", "reliable")
func request_character_field(field: String, value) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1 # host calling on itself
	_apply_character_field.rpc(sender_id, field, value)

@rpc("authority", "call_local", "reliable")
func _apply_character_field(peer_id: int, field: String, value) -> void:
	if not players.has(peer_id):
		players[peer_id] = {"name": "Unknown", "character": {}}
	players[peer_id]["character"][field] = value
	character_updated.emit(peer_id, players[peer_id]["character"])

# --- Dice ---

func roll_and_broadcast(formula: String) -> void:
	request_dice_roll.rpc_id(1, formula)

@rpc("any_peer", "reliable")
func request_dice_roll(formula: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	var result := DiceRoller.roll(formula)
	_apply_dice_roll.rpc(get_player_name(sender_id), formula, result["total"], result["breakdown"])

@rpc("authority", "call_local", "reliable")
func _apply_dice_roll(player_name: String, formula: String, total: int, breakdown: String) -> void:
	dice_rolled.emit(player_name, formula, total, breakdown)

# --- Chat ---

func send_chat(text: String) -> void:
	request_chat.rpc_id(1, text)

@rpc("any_peer", "reliable")
func request_chat(text: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	_apply_chat.rpc(get_player_name(sender_id), text)

@rpc("authority", "call_local", "reliable")
func _apply_chat(player_name: String, text: String) -> void:
	chat_log.append({"name": player_name, "text": text})
	chat_message_received.emit(player_name, text)

# --- Tokens (map pieces) ---

func generate_token_id() -> String:
	_next_token_id += 1
	return "token_%d" % _next_token_id

func request_add_token(token_id: String, token_name: String, texture: String, x: float, y: float) -> void:
	_request_add_token.rpc_id(1, token_id, token_name, texture, x, y)

@rpc("any_peer", "reliable")
func _request_add_token(token_id: String, token_name: String, texture: String, x: float, y: float) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	_apply_add_token.rpc(token_id, token_name, texture, x, y, sender_id)

@rpc("authority", "call_local", "reliable")
func _apply_add_token(token_id: String, token_name: String, texture: String, x: float, y: float, owner_id: int) -> void:
	tokens[token_id] = {"name": token_name, "texture": texture, "x": x, "y": y, "owner_id": owner_id}
	token_added.emit(token_id, tokens[token_id])

func request_move_token(token_id: String, x: float, y: float) -> void:
	_request_move_token.rpc_id(1, token_id, x, y)

@rpc("any_peer", "unreliable_ordered")
func _request_move_token(token_id: String, x: float, y: float) -> void:
	if not multiplayer.is_server():
		return
	_apply_move_token.rpc(token_id, x, y)

@rpc("authority", "call_local", "unreliable_ordered")
func _apply_move_token(token_id: String, x: float, y: float) -> void:
	if tokens.has(token_id):
		tokens[token_id]["x"] = x
		tokens[token_id]["y"] = y
	token_moved.emit(token_id, x, y)

func request_remove_token(token_id: String) -> void:
	_request_remove_token.rpc_id(1, token_id)

@rpc("any_peer", "reliable")
func _request_remove_token(token_id: String) -> void:
	if not multiplayer.is_server():
		return
	_apply_remove_token.rpc(token_id)

@rpc("authority", "call_local", "reliable")
func _apply_remove_token(token_id: String) -> void:
	tokens.erase(token_id)
	token_removed.emit(token_id)
