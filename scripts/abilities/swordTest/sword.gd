extends Sprite2D
class_name SwordTest

var damage: int = 0

@onready var col: Area2D = $Area2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	col.body_entered.connect(_on_body_entered)
	await get_tree().create_timer(0.3).timeout
	queue_free()

func get_ready(_damage: int):
	damage = _damage

func _on_body_entered(body: Node2D):
	if multiplayer.is_server() and body is MobBase:
		body.get_damage(damage)
