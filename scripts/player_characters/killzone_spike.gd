extends Node

func _physics_process(_delta):
	if not multiplayer.is_server():
		return

	var players = get_tree().get_nodes_in_group("players")
	var spike_layers = get_tree().get_nodes_in_group("spike_maps")

	for player in players:
		for layer in spike_layers:
			if not layer is TileMapLayer:
				continue

			var cell = layer.local_to_map(player.global_position)
			var tile_data = layer.get_cell_tile_data(cell)

			if tile_data == null:
				continue

			var is_spike = tile_data.get_custom_data("is_spike")
			if is_spike != true:
				continue

			print("SPIKE HIT:", player.name)
			player.take_damage(tile_data.get_custom_data("damage"))
			print("Cell:", cell)
			print("Custom:", tile_data.get_custom_data())



#extends Node
#
#func _physics_process(_delta):
	#
	#if not multiplayer.is_server():
		#return
#
	#var players = get_tree().get_nodes_in_group("players")
	#var spike_layers = get_tree().get_nodes_in_group("spike_maps")
#
	#for player in players:
		#for layer in spike_layers:
			#if not layer is TileMapLayer:
				#continue
#
			#var cell = layer.local_to_map(player.global_position)
			#var tile_data = layer.get_cell_tile_data(cell)
			#print("hhelo")
			#print(tile_data.get_custom_data())
			#if tile_data == null:
				#continue
#
			#if tile_data.get_custom_data("is_spike"):
				#print("SPIKE HIT:", player.name)
				#player.take_damage(10)
#
#
#
##extends Node
##class_name KillZone
##
##@export var check_interval := 0.1
##
##var _timer := 0.0
##
##func _physics_process(delta: float) -> void:
	##if not multiplayer.is_server():
		##return
##
	##_timer -= delta
	##if _timer > 0.0:
		##return
##
	##_timer = check_interval
	##_check_players_on_spikes()
	##
##func _check_players_on_spikes() -> void:
	##var players := get_tree().get_nodes_in_group("players")
	##var spike_maps := get_tree().get_nodes_in_group("spike_maps")
##
	##if spike_maps.is_empty():
		##return
##
	##for player in players:
		##if not player is CharacterBody2D:
			##continue
##
		##for tilemap in spike_maps:
			##if not tilemap is TileMap:
				##continue
##
			##var map_pos = tilemap.local_to_map(player.global_position)
			##var tile_data = tilemap.get_cell_tile_data(map_pos)
##
			##if tile_data == null:
				##continue
##
			##if not tile_data.get_custom_data("is_spike"):
				##continue
##
			##_apply_spike_damage(player, tilemap, map_pos, tile_data)
			##break
##
##
##func _apply_spike_damage(
	##player: CharacterBody2D,
	##tilemap: TileMap,
	##map_pos: Vector2i,
	##tile_data: TileData
##) -> void:
##
	##print("SPIKE HIT:", player.name)
##
	##if not player.has_method("take_damage"):
		##return
##
	##var damage := float(tile_data.get_custom_data("damage"))
	##var knockback := float(tile_data.get_custom_data("knockback"))
##
	##var tile_center := tilemap.map_to_local(map_pos) + tilemap.tile_set.tile_size * 0.5
##
	##var dir := (player.global_position - tile_center).normalized()
##
	##player.velocity += dir * knockback
	##player.take_damage(damage)
	##print("SPIKE HIT:", player.name)
