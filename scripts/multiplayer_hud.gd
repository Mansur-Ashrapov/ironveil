extends Node

var score = 0

func _ready():
	if OS.has_feature("dedicated_server"):
		print("Starting dedicated server...")
		%NetworkManager.become_host(true)
	%GameManager.game_started.connect(_hide_waiting_on_game_started)
	
func _show_restart_button(text):
	$CanvasLayer/restart.text = text
	$CanvasLayer/restart.show()

func become_host():
	print("Become host pressed")
	%MultiplayerHUD.hide()
	%SteamHUD.hide()
	%NetworkManager.become_host()
	%NetworkManager.active_network.player_created.connect(%GameManager.start_game)
	_show_waiting_players()
	_show_restart_button("CLOSE SERVER")

func join_as_client():
	print("Join as player 2")
	join_lobby()
	_show_waiting_players()
	_show_restart_button("DISCONNECT")

func use_steam():
	print("Using Steam!")
	%MultiplayerHUD.hide()
	%SteamHUD.show()
	SteamManager.initialize_steam()
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	%NetworkManager.active_network_type = %NetworkManager.MULTIPLAYER_NETWORK_TYPE.STEAM

func list_steam_lobbies():
	print("List Steam lobbies")
	%NetworkManager.list_lobbies()

func join_lobby(lobby_id = 0):
	print("Joining lobby %s" % lobby_id)
	%MultiplayerHUD.hide()
	%SteamHUD.hide()
	%NetworkManager.join_as_client(lobby_id)
	_show_waiting_players()
	_show_restart_button("DISCONNECT")

func _show_waiting_players():
	$CanvasLayer/waiting_for_players.show()

func _hide_waiting_on_game_started():
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
	var need_to_reload = multiplayer.is_server() or \
		multiplayer.multiplayer_peer.get_connection_status() == multiplayer.multiplayer_peer.CONNECTION_CONNECTING or \
		multiplayer.multiplayer_peer.get_connection_status() == multiplayer.multiplayer_peer.CONNECTION_CONNECTING
	multiplayer.multiplayer_peer.close()

	if need_to_reload:
		get_tree().reload_current_scene()
