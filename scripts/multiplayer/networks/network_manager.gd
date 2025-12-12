extends Node

enum MULTIPLAYER_NETWORK_TYPE { ENET, STEAM }

@export var players_spawn_node: Node2D

var active_network_type: MULTIPLAYER_NETWORK_TYPE = MULTIPLAYER_NETWORK_TYPE.ENET
var enet_network_scene := preload("res://scenes/multiplayer/networks/enet_network.tscn")
var steam_network_scene := preload("res://scenes/multiplayer/networks/steam_network.tscn")
var active_network
var max_players: int = 2

func _build_multiplayer_network():
	if not active_network:
		print("Setting active_network")
		
		MultiplayerManager.multiplayer_mode_enabled = true
		
		match active_network_type:
			MULTIPLAYER_NETWORK_TYPE.ENET:
				print("Setting network type to ENet")
				_set_active_network(enet_network_scene)
				max_players -= 1
			MULTIPLAYER_NETWORK_TYPE.STEAM:
				print("Setting network type to Steam")
				_set_active_network(steam_network_scene)
			_:
				print("No match for network type!")

func _set_active_network(active_network_scene):
	var network_scene_initialized = active_network_scene.instantiate()
	active_network = network_scene_initialized
	active_network._players_spawn_node = players_spawn_node
	add_child(active_network)

func become_host(is_dedicated_server = false, is_solo = false):
	_build_multiplayer_network()
	MultiplayerManager.host_mode_enabled = true if is_dedicated_server == false else false
	active_network.become_host(max_players, is_solo)
	multiplayer.peer_disconnected.connect(reload_scene_on_disconnect)

func join_as_client(lobby_id = 0):
	_build_multiplayer_network()
	active_network.join_as_client(lobby_id)
	multiplayer.server_disconnected.connect(reload_scene_on_disconnect.bind(1))

func list_lobbies():
	_build_multiplayer_network()
	active_network.list_lobbies()

func reload_scene_on_disconnect(_id):
	leave_lobby()
	get_tree().reload_current_scene()

## Покидает текущее лобби и очищает состояние
func leave_lobby():
	if active_network and active_network.has_method("leave_lobby"):
		active_network.leave_lobby()
	elif multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	
	# Отключаем сигналы
	if multiplayer.peer_disconnected.is_connected(reload_scene_on_disconnect):
		multiplayer.peer_disconnected.disconnect(reload_scene_on_disconnect)
	if multiplayer.server_disconnected.is_connected(reload_scene_on_disconnect):
		multiplayer.server_disconnected.disconnect(reload_scene_on_disconnect)
	
	# Очищаем сеть
	if active_network:
		active_network.queue_free()
		active_network = null
	
	MultiplayerManager.host_mode_enabled = false
	MultiplayerManager.multiplayer_mode_enabled = false
