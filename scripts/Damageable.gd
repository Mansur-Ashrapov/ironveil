extends CharacterBody2D

@export var health: int = 100
var last_spike_hit_time := 0.0

# RPC урон — вызывают только клиенты, обрабатывает хост
@rpc("authority")
func rpc_take_damage(amount: int, knockback: Vector2):
	if health <= 0:
		return
	health -= amount
	velocity += knockback

	if health <= 0:
		_die()

func _die():
	print("Unit died:", self)
	queue_free()
