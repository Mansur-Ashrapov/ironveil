extends CharacterBody2D

const SPEED = 60
const MAX_DISTANCE = 500

var player_node: Node2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Находим игрока в сцене
	find_player()

func find_player():
	# Ищем игрока по группе или по имени класса
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		player_node = players[0]
	else:
		# Альтернативный способ: ищем по классу
		for node in get_tree().get_nodes_in_group("network_players"):
			if node is PlayerBase:
				player_node = node
				break
	
func _physics_process(delta: float) -> void:
	if player_node == null:
		find_player()
		if player_node == null:
			return
	
	var distance_to_player = global_position.distance_to(player_node.global_position)
	
	# Если игрок слишком далеко, не преследовать
	if distance_to_player > 500:
		velocity = Vector2.ZERO
		return
	
	# Вычисляем направление к игроку
	var direction_to_player = (player_node.global_position - global_position).normalized()
	
	# Устанавливаем скорость
	velocity = direction_to_player * SPEED
	
	# Поворачиваем спрайт в сторону игрока
	if direction_to_player.x > 0:
		animated_sprite.flip_h = false
	elif direction_to_player.x < 0:
		animated_sprite.flip_h = true
		
	# Анимация
	if velocity.length() > 0:
		animated_sprite.flip_h = velocity.x < 0
		animated_sprite.play("walk")
	else:
		animated_sprite.play("idle")
	
	# Двигаем моба
	move_and_slide()
