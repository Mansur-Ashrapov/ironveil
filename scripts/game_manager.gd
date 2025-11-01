extends Node

var is_game_started = false

signal game_started()

func get_all_players() -> Array[PlayerBase]:
	var players: Array[PlayerBase] = []
	players.append_array(get_tree().get_nodes_in_group("players"))
	return players

func get_all_mobs() -> Array[MobBase]:
	var mobs: Array[MobBase] = []
	mobs.append_array(get_tree().get_nodes_in_group("mob"))
	return mobs

func start_game():
	if len(get_all_players()) < %NetworkManager.max_players:
		return

	print(get_all_players())
	for player in get_all_players():
		print(player.name)
		player.start_game()
	for mob in get_all_mobs():
		mob.game_started = true
	emit_game_started.rpc()

@rpc("any_peer", "call_local", "reliable")
func emit_game_started():
	is_game_started = true
	print("GAME_STARTED ", is_game_started)
	game_started.emit()
