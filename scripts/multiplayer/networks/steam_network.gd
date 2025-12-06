extends Node

var multiplayer_scene = preload("res://scenes/network_player.tscn")
var multiplayer_peer: SteamMultiplayerPeer
var _players_spawn_node
var _hosted_lobby_id = 0

const LOBBY_NAME = "IRONVEIL"
const LOBBY_MODE = "CoOP"

signal player_created()

func  _ready():
	Steam.lobby_created.connect(_on_lobby_created.bind())

func become_host(max_players: int):
	print("Starting host!")
	
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_del_player)
	
	Steam.lobby_joined.connect(_on_lobby_joined.bind())
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, max_players)
	
func join_as_client(lobby_id):
	print("Joining lobby %s" % lobby_id)
	Steam.lobby_joined.connect(_on_lobby_joined.bind())
	Steam.joinLobby(int(lobby_id))
 
func _on_lobby_created(_connect: int, lobby_id):
	print("On lobby created")
	if _connect == 1:
		_hosted_lobby_id = lobby_id
		print("Created lobby: %s" % _hosted_lobby_id)
		
		Steam.setLobbyJoinable(_hosted_lobby_id, true)
		
		Steam.setLobbyData(_hosted_lobby_id, "name", LOBBY_NAME)
		Steam.setLobbyData(_hosted_lobby_id, "mode", LOBBY_MODE)
		
		_create_host()

func _create_host():
	print("Create Host")
	multiplayer_peer = SteamMultiplayerPeer.new()
	var error = multiplayer_peer.create_host(0)
	
	if error == OK:
		multiplayer.multiplayer_peer = multiplayer_peer
		if not OS.has_feature("dedicated_server"):
			_add_player_to_game(1)
	else:
		push_error("Failed to create Steam host: %s" % _get_error_string(error))
		# Можно добавить сигнал для уведомления UI об ошибке

func _on_lobby_joined(lobby: int, _permissions: int, _locked: bool, response: int):
	print("On lobby joined: %s" % response)
	
	if response == 1:
		var id = Steam.getLobbyOwner(lobby)
		if id != Steam.getSteamID():
			print("Connecting client to socket...")
			connect_socket(id)
	else:
		var fail_reason = _get_lobby_join_failure_reason(response)
		push_error("Failed to join lobby: %s" % fail_reason)
		# Можно добавить сигнал для уведомления UI об ошибке

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
	
func connect_socket(steam_id: int):
	multiplayer_peer = SteamMultiplayerPeer.new()
	var error = multiplayer_peer.create_client(steam_id, 0)
	if error == OK:
		print("Connecting peer to host...")
		multiplayer.multiplayer_peer = multiplayer_peer
	else:
		push_error("Failed to create Steam client: %s" % _get_error_string(error))
		# Можно добавить сигнал для уведомления UI об ошибке

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
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	# NOTE: If you are using the test app id, you will need to apply a filter on your game name
	# Otherwise, it may not show up in the lobby list of your clients
	Steam.addRequestLobbyListStringFilter("name", LOBBY_NAME, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _add_player_to_game(id: int):
	print("Player %s joined the game!" % id)
	
	var player_to_add = multiplayer_scene.instantiate()
	player_to_add.name = str(id)
	
	_players_spawn_node.add_child(player_to_add, true)
	player_created.emit()
	
func _del_player(id: int):
	print("Player %s left the game!" % id)
	if not _players_spawn_node.has_node(str(id)):
		return
	_players_spawn_node.get_node(str(id)).queue_free()
