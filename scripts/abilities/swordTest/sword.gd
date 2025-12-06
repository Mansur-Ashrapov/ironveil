extends Sprite2D
class_name SwordTest

const LIFETIME: float = 0.3

var damage: float = 0
var impulse_direction: Vector2 = Vector2(1, 1)
var impulse_strength: float = 500

@onready var col: Area2D = $Area2D

func _ready() -> void:
	col.body_entered.connect(_on_body_entered)
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()

func get_ready(_damage: float):
	damage = _damage

func _on_body_entered(body: Node2D):
	if body is MobBase and multiplayer.is_server():
		body.take_damage(damage, global_position)
