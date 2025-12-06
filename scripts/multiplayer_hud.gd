extends Node

var score = 0
var selected_character: String = ""
var is_host_mode: bool = false
var is_solo_mode: bool = false
var pending_lobby_id = 0
var _spawned_players_count: int = 0
var _expected_players_count: int = 0
var _waiting_for_spawn: bool = false

func _ready():
	if OS.has_feature("dedicated_server"):
		print("Starting dedicated server...")
		%NetworkManager.become_host(true)
	%GameManager.game_started.connect(_hide_waiting_on_game_started)
	
	# Подключаем сигнал spawned от MultiplayerSpawner
	var spawner = get_node_or_null("../MultiplayerSpawner")
	if spawner:
		spawner.spawned.connect(_on_player_spawned)
	
func _show_restart_button(text):
	$CanvasLayer/restart.text = text
	$CanvasLayer/restart.show()

func show_character_select_host():
	SoundManager.play_sound("ui_click")
	print("Show character select for host")
	is_host_mode = true
	%MultiplayerHUD.hide()
	%SteamHUD.hide()
	%CharacterSelectHUD.show()
	
	# Create network and host
	%NetworkManager.become_host()
	_connect_network_signals()
	_show_restart_button("CLOSE SERVER")

func show_character_select_client():
	SoundManager.play_sound("ui_click")
	print("Show character select for client")
	is_host_mode = false
	pending_lobby_id = 0
	%MultiplayerHUD.hide()
	%SteamHUD.hide()
	%CharacterSelectHUD.show()
	
	# Join as client
	%NetworkManager.join_as_client(pending_lobby_id)
	_connect_network_signals()
	_show_restart_button("DISCONNECT")

func _connect_network_signals():
	var network = %NetworkManager.active_network
	if network:
		if not network.character_selected.is_connected(_on_character_selected):
			network.character_selected.connect(_on_character_selected)
		if not network.player_ready_changed.is_connected(_on_player_ready_changed):
			network.player_ready_changed.connect(_on_player_ready_changed)
		if not network.all_players_ready.is_connected(_on_all_players_ready):
			network.all_players_ready.connect(_on_all_players_ready)
		if not network.player_joined_lobby.is_connected(_on_player_joined_lobby):
			network.player_joined_lobby.connect(_on_player_joined_lobby)
		if not network.player_left_lobby.is_connected(_on_player_left_lobby):
			network.player_left_lobby.connect(_on_player_left_lobby)

func become_host():
	show_character_select_host()

func join_as_client():
	SoundManager.play_sound("ui_click")
	print("Join as player 2")
	show_character_select_client()


func play_solo():
	SoundManager.play_sound("ui_click")
	print("play_solo pressed")
	is_solo_mode = true
	is_host_mode = true
	%MultiplayerHUD.hide()
	%SteamHUD.hide()
	%CharacterSelectHUD.show()
	
	# Create network and host in solo mode
	%NetworkManager.become_host(false, true)
	_connect_network_signals()
	_show_restart_button("MENU")

# Character selection functions
func select_swordsman():
	SoundManager.play_sound("ui_click")
	selected_character = "swordsman"
	_update_selected_label()
	_enable_ready_button()
	
	# Send choice to server
	var network = %NetworkManager.active_network
	if network:
		network.register_character_choice.rpc_id(1, "swordsman")

func select_magician():
	SoundManager.play_sound("ui_click")
	selected_character = "magician"
	_update_selected_label()
	_enable_ready_button()
	
	# Send choice to server
	var network = %NetworkManager.active_network
	if network:
		network.register_character_choice.rpc_id(1, "magician")

func on_ready_pressed():
	SoundManager.play_sound("ui_click")
	if selected_character == "":
		return
	
	# Send ready status to server
	var network = %NetworkManager.active_network
	if network:
		network.set_player_ready.rpc_id(1, true)
	
	# Disable button after pressing
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/ReadyBtn.disabled = true
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/ReadyBtn.text = "Waiting..."
	
	# Disable character buttons
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/CharacterButtons/SwordsmanBtn.disabled = true
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/CharacterButtons/MagicianBtn.disabled = true

func _update_selected_label():
	var label = $CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/SelectedLabel
	match selected_character:
		"swordsman":
			label.text = "Selected: Swordsman"
		"magician":
			label.text = "Selected: Magician"
		_:
			label.text = "Selected: None"

func _enable_ready_button():
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/ReadyBtn.disabled = false

func _update_players_list():
	var players_container = $CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/PlayersList
	
	# Clear existing labels
	for child in players_container.get_children():
		child.queue_free()
	
	var network = %NetworkManager.active_network
	if not network:
		return
	
	for peer_id in network.get_connected_peers():
		var player_label = Label.new()
		var char_type = network.get_player_character(peer_id)
		var is_ready = network.get_player_ready(peer_id)
		
		var peer_name = "Host" if peer_id == 1 else "Player %s" % peer_id
		var char_name = char_type if char_type != "" else "..."
		var ready_text = " [Ready]" if is_ready else ""
		
		player_label.text = "%s: %s%s" % [peer_name, char_name, ready_text]
		player_label.add_theme_font_size_override("font_size", 7)
		players_container.add_child(player_label)

# Network signal handlers
func _on_character_selected(_peer_id: int, _character: String):
	_update_players_list()

func _on_player_ready_changed(_peer_id: int, _is_ready: bool):
	_update_players_list()

func _on_all_players_ready():
	print("All players ready! Waiting for spawn...")
	%CharacterSelectHUD.hide()
	$CanvasLayer/Label.hide()
	
	# В соло-режиме ожидаем только 1 игрока
	if is_solo_mode:
		_expected_players_count = 1
	else:
		_expected_players_count = %NetworkManager.max_players
	_spawned_players_count = 0
	_waiting_for_spawn = true
	
	# Проверяем, может игроки уже заспавнены
	_check_all_spawned()

func _on_player_spawned(_node: Node):
	if not _waiting_for_spawn:
		return
	
	_spawned_players_count += 1
	print("Player spawned: %d/%d" % [_spawned_players_count, _expected_players_count])
	_check_all_spawned()

func _check_all_spawned():
	if not _waiting_for_spawn:
		return
	
	# Также проверяем по группе players
	var players_in_group = get_tree().get_nodes_in_group("players").size()
	
	if players_in_group >= _expected_players_count:
		print("All players spawned! Starting game...")
		_waiting_for_spawn = false
		%GameManager.start_game()

func _on_player_joined_lobby(_peer_id: int):
	_update_players_list()

func _on_player_left_lobby(_peer_id: int):
	_update_players_list()


var _lobby_match_list_connected: bool = false

func use_steam():
	SoundManager.play_sound("ui_click")
	print("Using Steam!")
	%MultiplayerHUD.hide()
	%SteamHUD.show()
	SteamManager.initialize_steam()
	if not _lobby_match_list_connected:
		Steam.lobby_match_list.connect(_on_lobby_match_list)
		_lobby_match_list_connected = true
	%NetworkManager.active_network_type = %NetworkManager.MULTIPLAYER_NETWORK_TYPE.STEAM

func list_steam_lobbies():
	SoundManager.play_sound("ui_click")
	print("List Steam lobbies")
	%NetworkManager.list_lobbies()

func join_lobby(lobby_id = 0):
	SoundManager.play_sound("ui_click")
	print("Joining lobby %s" % lobby_id)
	is_host_mode = false
	pending_lobby_id = lobby_id
	%MultiplayerHUD.hide()
	%SteamHUD.hide()
	%CharacterSelectHUD.show()
	
	# Join as client with lobby id
	%NetworkManager.join_as_client(lobby_id)
	_connect_network_signals()
	_show_restart_button("DISCONNECT")

func _show_waiting_players():
	$CanvasLayer/waiting_for_players.show()

func _hide_waiting_on_game_started():
	$CanvasLayer/Label.hide()
	$CanvasLayer/waiting_for_players.hide()

func _on_lobby_match_list(lobbies: Array):
	print("On lobby match list")
	
	for lobby_child in $"CanvasLayer/SteamHUD/Panel/Lobbies/VBoxContainer".get_children():
		lobby_child.queue_free()
		
	for lobby in lobbies:
		var lobby_name: String = Steam.getLobbyData(lobby, "name")
		
		if lobby_name != "":
			var lobby_mode: String = Steam.getLobbyData(lobby, "mode")
			
			var lobby_button: Button = Button.new()
			lobby_button.set_text(lobby_name + " | " + lobby_mode)
			lobby_button.set_size(Vector2(100, 30))
			lobby_button.add_theme_font_size_override("font_size", 8)
			
			lobby_button.set_name("lobby_%s" % lobby)
			lobby_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			lobby_button.connect("pressed", Callable(self, "join_lobby").bind(lobby))
			
			$"CanvasLayer/SteamHUD/Panel/Lobbies/VBoxContainer".add_child(lobby_button)


func _on_restart_pressed() -> void:
	SoundManager.play_sound("ui_click")
	var need_to_reload = multiplayer.is_server() or \
		multiplayer.multiplayer_peer.get_connection_status() == multiplayer.multiplayer_peer.CONNECTION_CONNECTING or \
		multiplayer.multiplayer_peer.get_connection_status() == multiplayer.multiplayer_peer.CONNECTION_CONNECTING
	multiplayer.multiplayer_peer.close()

	if need_to_reload:
		get_tree().reload_current_scene()
