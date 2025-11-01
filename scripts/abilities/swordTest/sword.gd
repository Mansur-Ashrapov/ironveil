extends Sprite2D
class_name SwordTest

var damage: float = 0
var impulse_direction: Vector2 = Vector2(1, 1)
var impulse_strength: float = 500

@onready var col: Area2D = $Area2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	col.body_entered.connect(_on_body_entered)
	await get_tree().create_timer(0.3).timeout
	queue_free()

func get_ready(_damage: float):
	damage = _damage

func _on_body_entered(body: Node2D):
	if body is MobBase and multiplayer.is_server():
		body.get_damage(damage, global_position)
