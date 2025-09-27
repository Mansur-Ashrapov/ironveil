extends CharacterBody2D

const SPEED = 60
const MAX_DISTANCE = 500  # Максимальная дистанция преследования

var target_player: Node2D  # Текущая цель
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	find_nearest_player()

func find_nearest_player() -> bool:
	var players = get_all_players()
	
	if players.size() == 0:
		target_player = null
		return false
	
	# Находим ближайшего игрока
	var nearest_player = null
	var min_distance = INF
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance and distance <= MAX_DISTANCE:
			min_distance = distance
			nearest_player = player
	
	target_player = nearest_player
	return target_player != null

func get_all_players() -> Array:
	var players = []
	
	# Ищем игроков в разных группах
	players.append_array(get_tree().get_nodes_in_group("players"))
	players.append_array(get_tree().get_nodes_in_group("network_players"))
	
	# Дополнительно ищем по классу PlayerBase
	for node in get_tree().get_nodes_in_group("network_players"):
		if node is PlayerBase and not players.has(node):
			players.append(node)
	
	# Фильтруем только живых игроков (если есть система здоровья)
	var alive_players = []
	for player in players:
		if player.has_method("is_alive"):
			if player.is_alive():
				alive_players.append(player)
		else:
			alive_players.append(player)
	
	return alive_players

func _physics_process(delta: float) -> void:
	# Обновляем цель каждые N кадров для оптимизации
	if Engine.get_frames_drawn() % 30 == 0:  # Каждые 30 кадров
		find_nearest_player()
	
	if target_player == null:
		if not find_nearest_player():
			# Если игроков нет, стоим на месте
			velocity = Vector2.ZERO
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
			return
	
	# Проверяем, жив ли еще целевой игрок и не слишком ли далеко
	var distance_to_target = global_position.distance_to(target_player.global_position)
	if distance_to_target > MAX_DISTANCE:
		# Ищем нового игрока, если текущий слишком далеко
		find_nearest_player()
		if target_player == null:
			velocity = Vector2.ZERO
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
			return
	
	# Вычисляем направление к цели
	var direction_to_target = (target_player.global_position - global_position).normalized()
	
	# Устанавливаем скорость
	velocity = direction_to_target * SPEED
	
	# Поворачиваем спрайт в сторону цели
	if direction_to_target.x > 0:
		animated_sprite.flip_h = false
	elif direction_to_target.x < 0:
		animated_sprite.flip_h = true
	
	# Анимация
	if velocity.length() > 0:
		animated_sprite.play("walk")
	else:
		animated_sprite.play("idle")
	
	# Двигаем моба
	move_and_slide()
