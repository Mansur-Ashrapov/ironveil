extends Area2D

@export var hit_timer_cooldown: float =  1.5
@export var damage: float = 15.0

var players_to_hit: Array[PlayerBase]


func _ready() -> void:
	var hit_timer = Timer.new()
	hit_timer.wait_time = hit_timer_cooldown
	hit_timer.autostart = true
	hit_timer.one_shot = false
	add_child(hit_timer)
	hit_timer.timeout.connect(_on_hit_timer)

func _on_hit_timer():
	for player in players_to_hit:
		player.take_damage(damage)

func _on_body_entered(body: Node2D) -> void:
	if multiplayer.is_server() and body is PlayerBase:
		players_to_hit.append((body as PlayerBase))

func _on_body_exited(body: Node2D) -> void:
	if multiplayer.is_server() and body is PlayerBase:
		players_to_hit = players_to_hit.filter(func(player: PlayerBase): return player.name != body.name)
