extends Node

var swordsman_scene = preload("res://scenes/swords_man.tscn")
var magician_scene = preload("res://scenes/magician.tscn")
var multiplayer_peer: SteamMultiplayerPeer = SteamMultiplayerPeer.new()
var _players_spawn_node
var _hosted_lobby_id = 0

const LOBBY_NAME = "IRONVEIL"
const LOBBY_MODE = "CoOP"

# Character selection tracking
var player_characters: Dictionary = {}  # {peer_id: character_type}
var player_ready_status: Dictionary = {}  # {peer_id: bool}
var connected_peers: Array = []  # List of connected peer IDs
var is_solo_mode: bool = false

signal player_created()
signal character_selected(peer_id: int, character: String)
signal player_ready_changed(peer_id: int, is_ready: bool)
signal all_players_ready()
signal player_joined_lobby(peer_id: int)
signal player_left_lobby(peer_id: int)
signal client_connected_to_server()
signal connection_failed(reason: String)


func  _ready():
	Steam.connect("lobby_created", _on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)

func become_host(max_players: int, solo_mode: bool = false):
	print("Starting host!")
	is_solo_mode = solo_mode
	
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, max_players)
	
func join_as_client(lobby_id):
	print("Joining lobby %s" % lobby_id)
	Steam.joinLobby(int(lobby_id))
 
func _on_lobby_created(_connect: int, lobby_id):
	print("On lobby created: connect=%s, lobby_id=%s" % [_connect, lobby_id])
	if _connect == Steam.RESULT_OK:
		_hosted_lobby_id = lobby_id
		print("Created lobby: %s" % _hosted_lobby_id)
		
		multiplayer_peer.host_with_lobby(lobby_id)
		multiplayer.multiplayer_peer = multiplayer_peer
		Steam.setLobbyJoinable(_hosted_lobby_id, true)
		
		Steam.setLobbyData(_hosted_lobby_id, "name", LOBBY_NAME)
		Steam.setLobbyData(_hosted_lobby_id, "mode", LOBBY_MODE)
		
		# Register host as connected peer
		_on_peer_connected(1)
	else:
		var error_msg = "Failed to create lobby (error code: %d)" % _connect
		push_error(error_msg)
		print(error_msg)


func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int):
	print("On lobby joined: lobby=%s, response=%s" % [lobby, response])
	
	if response == 1:
		var lobby_owner_id = Steam.getLobbyOwner(lobby)
		var my_steam_id = Steam.getSteamID()
		
		if lobby_owner_id == my_steam_id:
			# We are the host - lobby was created, host is already set up in _create_host()
			print("Joined own lobby as host")
			# Host is already connected as peer 1 in _create_host()
		else:
			# Connect signal for client to know when connected to server
			if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
				multiplayer.connected_to_server.connect(_on_connected_to_server)
			multiplayer_peer.connect_to_lobby(lobby)
			multiplayer.multiplayer_peer = multiplayer_peer
	else:
		var fail_reason = _get_lobby_join_failure_reason(response)
		push_error("Failed to join lobby: %s" % fail_reason)
		connection_failed.emit(fail_reason)

func _get_lobby_join_failure_reason(response: int) -> String:
	match response:
		2:  return "This lobby no longer exists."
		3:  return "You don't have permission to join this lobby."
		4:  return "The lobby is now full."
		5:  return "Something unexpected happened!"
		6:  return "You are banned from this lobby."
		7:  return "You cannot join due to having a limited account."
		8:  return "This lobby is locked or disabled."
		9:  return "This lobby is community locked."
		10: return "A user in the lobby has blocked you from joining."
		11: return "A user you have blocked is in the lobby."
		_:  return "Unknown error (code: %d)" % response


func _on_connected_to_server():
	var my_id = multiplayer.get_unique_id()
	print("Connected to server as peer %s" % my_id)
	connected_peers.append(my_id)
	player_ready_status[my_id] = false
	player_joined_lobby.emit(my_id)
	client_connected_to_server.emit()

func _get_error_string(error_code: int) -> String:
	match error_code:
		ERR_UNAVAILABLE:
			return "Service unavailable"
		ERR_UNCONFIGURED:
			return "Unconfigured"
		ERR_UNAUTHORIZED:
			return "Unauthorized"
		ERR_PARAMETER_RANGE_ERROR:
			return "Parameter range error"
		_:
			return "Unknown error (code: %d)" % error_code

func list_lobbies():
	Steam.addRequestLobbyListStringFilter("name", LOBBY_NAME, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _on_peer_connected(id: int):
	print("Peer %s connected to lobby!" % id)
	connected_peers.append(id)
	player_ready_status[id] = false
	player_joined_lobby.emit(id)
	
	# Sync existing players to the new peer
	if multiplayer.is_server() and id != 1:
		for peer_id in connected_peers:
			if peer_id != id:
				_sync_player_to_peer.rpc_id(id, peer_id, player_characters.get(peer_id, ""), player_ready_status.get(peer_id, false))

func _on_peer_disconnected(id: int):
	print("Peer %s disconnected from lobby!" % id)
	connected_peers.erase(id)
	player_characters.erase(id)
	player_ready_status.erase(id)
	player_left_lobby.emit(id)
	_del_player(id)

@rpc("any_peer", "reliable", "call_local")
func _sync_player_to_peer(peer_id: int, character: String, is_ready: bool):
	if peer_id not in connected_peers:
		connected_peers.append(peer_id)
	if character != "":
		player_characters[peer_id] = character
	player_ready_status[peer_id] = is_ready
	player_joined_lobby.emit(peer_id)
	if character != "":
		character_selected.emit(peer_id, character)
	player_ready_changed.emit(peer_id, is_ready)

@rpc("any_peer", "reliable", "call_local")
func register_character_choice(character: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1  # host
	player_characters[sender_id] = character
	character_selected.emit(sender_id, character)
	
	# Broadcast to all clients
	if multiplayer.is_server():
		_broadcast_character_choice.rpc(sender_id, character)

@rpc("authority", "reliable", "call_local")
func _broadcast_character_choice(peer_id: int, character: String):
	player_characters[peer_id] = character
	character_selected.emit(peer_id, character)

@rpc("any_peer", "reliable", "call_local")
func set_player_ready(is_ready: bool):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1  # host
	player_ready_status[sender_id] = is_ready
	player_ready_changed.emit(sender_id, is_ready)
	
	# Broadcast to all clients
	if multiplayer.is_server():
		_broadcast_player_ready.rpc(sender_id, is_ready)
		_check_all_ready()

@rpc("authority", "reliable", "call_local")
func _broadcast_player_ready(peer_id: int, is_ready: bool):
	player_ready_status[peer_id] = is_ready
	player_ready_changed.emit(peer_id, is_ready)

func _check_all_ready():
	# В соло-режиме достаточно 1 игрока, в мультиплеере нужно минимум 2
	var min_players = 1 if is_solo_mode else 2
	if connected_peers.size() < min_players:
		return
	
	for peer_id in connected_peers:
		if not player_ready_status.get(peer_id, false):
			return
		if not player_characters.has(peer_id):
			return
	
	# All players are ready and have selected characters
	_spawn_all_players()
	# Notify all clients that game is starting
	_notify_all_players_ready.rpc()

@rpc("authority", "reliable", "call_local")
func _notify_all_players_ready():
	all_players_ready.emit()

func _spawn_all_players():
	for peer_id in connected_peers:
		_add_player_to_game(peer_id)

func _add_player_to_game(id: int):
	print("Player %s joined the game!" % id)
	
	# Проверяем, что выбор персонажа зарегистрирован
	if not player_characters.has(id):
		push_error("Player %s character choice not registered! Cannot spawn player." % id)
		return
	
	var char_type = player_characters.get(id, "swordsman")
	var scene = swordsman_scene if char_type == "swordsman" else magician_scene
	var player_to_add = scene.instantiate()
	player_to_add.name = str(id)
	
	_players_spawn_node.add_child(player_to_add, true)
	player_created.emit()
	
func _del_player(id: int):
	print("Player %s left the game!" % id)
	if not _players_spawn_node.has_node(str(id)):
		return
	_players_spawn_node.get_node(str(id)).queue_free()

func get_connected_peers() -> Array:
	return connected_peers

func get_player_character(peer_id: int) -> String:
	return player_characters.get(peer_id, "")

func get_player_ready(peer_id: int) -> bool:
	return player_ready_status.get(peer_id, false)
