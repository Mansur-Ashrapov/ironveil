extends Node2D

@export var hit_timer_cooldown: float =  1.5
@export var damage: float = 15.0
@export var damage_range: float = 80

var players_to_hit: Array[PlayerBase]


func _ready() -> void:
	var hit_timer = Timer.new()
	hit_timer.wait_time = hit_timer_cooldown
	hit_timer.autostart = true
	hit_timer.one_shot = false
	add_child(hit_timer)
	hit_timer.timeout.connect(_on_hit_timer)

func get_all_players() -> Array:
	return get_tree().get_nodes_in_group("players")

func _on_hit_timer():
	if not multiplayer.is_server(): return
	
	for player in get_all_players():
		print(player, global_position.distance_to(player.global_position))
		if global_position.distance_to(player.global_position) <= damage_range:
			player.take_damage(damage)
