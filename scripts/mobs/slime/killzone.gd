extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if multiplayer.is_server() and body is PlayerBase:
		body.take_damage(10)
