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
	%GameManager.victory.connect(_on_victory)
	
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
	
	# Хост может сразу выбирать персонажа
	_set_character_buttons_enabled(true)
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/Title.text = "Select Character"
	
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
	
	# Отключаем кнопки пока соединение устанавливается
	_set_character_buttons_enabled(false)
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/Title.text = "Connecting..."
	
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
		# Сигналы для клиента
		if network.has_signal("client_connected_to_server") and not network.client_connected_to_server.is_connected(_on_client_connected):
			network.client_connected_to_server.connect(_on_client_connected)
		if network.has_signal("connection_failed") and not network.connection_failed.is_connected(_on_connection_failed):
			network.connection_failed.connect(_on_connection_failed)

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
		if _is_peer_connected():
			network.register_character_choice.rpc_id(1, "swordsman")
		else:
			# Direct call for host or when not yet connected
			network.register_character_choice("swordsman")

func select_magician():
	SoundManager.play_sound("ui_click")
	selected_character = "magician"
	_update_selected_label()
	_enable_ready_button()
	
	# Send choice to server
	var network = %NetworkManager.active_network
	if network:
		if _is_peer_connected():
			network.register_character_choice.rpc_id(1, "magician")
		else:
			# Direct call for host or when not yet connected
			network.register_character_choice("magician")

func on_ready_pressed():
	SoundManager.play_sound("ui_click")
	if selected_character == "":
		return
	
	# Send ready status to server
	var network = %NetworkManager.active_network
	if network:
		if _is_peer_connected():
			network.set_player_ready.rpc_id(1, true)
		else:
			# Direct call for host or when not yet connected
			network.set_player_ready(true)
	
	# Disable button after pressing
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/ReadyBtn.disabled = true
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/ReadyBtn.text = "Waiting..."
	
	# Disable character buttons
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/CharacterButtons/SwordsmanBtn.disabled = true
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/CharacterButtons/MagicianBtn.disabled = true

func _is_peer_connected() -> bool:
	var peer = multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

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
	
	# Check if using Steam network (has get_lobby_members method)
	var is_steam = network.has_method("get_lobby_members")
	
	if is_steam:
		# Use Steam lobby members for display
		var lobby_members = network.get_lobby_members()
		var owner_steam_id = network.get_lobby_owner_steam_id()
		
		for steam_id in lobby_members:
			var player_label = Label.new()
			var player_name = lobby_members[steam_id]
			var is_host = steam_id == owner_steam_id
			var char_type = network.get_player_character_by_steam(steam_id)
			var is_ready = network.get_player_ready_by_steam(steam_id)
			
			var char_name = char_type if char_type != "" else "..."
			var ready_text = " [Ready]" if is_ready else ""
			var host_text = " (Host)" if is_host else ""
			
			player_label.text = "%s%s: %s%s" % [player_name, host_text, char_name, ready_text]
			player_label.add_theme_font_size_override("font_size", 7)
			players_container.add_child(player_label)
	else:
		# Fallback to peer_id based display (for ENet)
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

func _on_client_connected():
	print("Client connected to server!")
	# Включаем кнопки выбора персонажа
	_set_character_buttons_enabled(true)
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/Title.text = "Select Character"

func _on_connection_failed(reason: String):
	print("Connection failed: %s" % reason)
	# Показываем ошибку и возвращаемся в меню
	push_warning("Connection failed: %s" % reason)
	_return_to_main_menu()

func _set_character_buttons_enabled(enabled: bool):
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/CharacterButtons/SwordsmanBtn.disabled = not enabled
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/CharacterButtons/MagicianBtn.disabled = not enabled


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
	
	# Отключаем кнопки пока соединение устанавливается
	_set_character_buttons_enabled(false)
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/Title.text = "Connecting..."
	
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
	
	# Проверяем началась ли уже игра
	var game_started = %GameManager.is_game_started
	
	# Корректно покидаем лобби через NetworkManager
	%NetworkManager.leave_lobby()
	
	# Сбрасываем состояние HUD
	_reset_hud_state()
	
	if game_started:
		# Игра уже началась - нужна полная перезагрузка сцены
		get_tree().reload_current_scene()
	else:
		# Игра ещё не началась - просто возвращаемся в главное меню
		_return_to_main_menu()

## Возвращает UI в главное меню без перезагрузки сцены
func _return_to_main_menu():
	# Скрываем все панели
	%CharacterSelectHUD.hide()
	%SteamHUD.hide()
	$CanvasLayer/waiting_for_players.hide()
	$CanvasLayer/restart.hide()
	$CanvasLayer/Label.show()
	
	# Показываем главное меню
	%MultiplayerHUD.show()
	
	# Сбрасываем UI выбора персонажа
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/Title.text = "Select Character"
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/SelectedLabel.text = "Selected: None"
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/ReadyBtn.disabled = true
	$CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/ReadyBtn.text = "Ready"
	_set_character_buttons_enabled(true)
	
	# Очищаем список игроков
	var players_container = $CanvasLayer/CharacterSelectHUD/Panel/VBoxContainer/PlayersList
	for child in players_container.get_children():
		child.queue_free()

func _reset_hud_state():
	selected_character = ""
	is_host_mode = false
	is_solo_mode = false
	pending_lobby_id = 0
	_spawned_players_count = 0
	_expected_players_count = 0
	_waiting_for_spawn = false

func _on_victory():
	print("Victory UI shown!")
	$CanvasLayer/VictoryHUD.show()

func _on_return_to_menu_pressed():
	SoundManager.play_sound("ui_click")
	$CanvasLayer/VictoryHUD.hide()
	
	# Корректно покидаем лобби через NetworkManager
	%NetworkManager.leave_lobby()
	
	# Сбрасываем состояние HUD
	_reset_hud_state()
	
	# Перезагружаем сцену
	get_tree().reload_current_scene()
