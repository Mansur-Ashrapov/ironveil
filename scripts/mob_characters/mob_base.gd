extends CharacterBody2D
class_name MobBase

const SPEED = 60
const MAX_DISTANCE = 500
# Кадры между обновлением цели
const TARGET_UPDATE_INTERVAL = 30
# Радиус агрессии
const AGRO_RADIUS = 300

# Буфер состояний для интерполяции на клиентах
var state_buffer := []
var last_target_update := 0
var target_player: Node2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Параметры (можно расширять)
@export var max_health := 50.0
var health := max_health

func _ready() -> void:
	# добавляем в группу для поиска
	add_to_group("mobs")
		# сразу ищем цель (сервер выполнит реальную логику, клиент просто проинициализируется)
	if multiplayer.is_server():
		find_nearest_player()

func _enter_tree() -> void:
	# Назначаем владельцем (сервер - peer_id 1)
	# У мобов обычно сервер - авторитет
	set_multiplayer_authority(1)

func find_nearest_player() -> bool:
	# Ищем игрока по группе или по имени класса
	var players = get_all_players()
	
	if players.size() == 0:
		target_player = null
		return false
		
	var nearest_player = null
	var min_distance = INF
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		# Определяем цель по дистанции
		if target_player == player and distance <= AGRO_RADIUS:
			nearest_player = player
			break
		elif distance < min_distance and distance <= MAX_DISTANCE:
			min_distance = distance
			nearest_player = player
			
	target_player = nearest_player
	return target_player != null
	
func get_all_players() -> Array:
	var players = []
	
	# Объединяем все возможные источники игроков
	var all_possible_players = []
	all_possible_players.append_array(get_tree().get_nodes_in_group("players"))
	
	# Убираем дубликаты
	for player in all_possible_players:
		if player is PlayerBase and not players.has(player):
			players.append(player)
	
	return players
	
func _physics_process(delta: float) -> void:
	# Обновляем цель с итервалом
	last_target_update += 1
	if last_target_update >= TARGET_UPDATE_INTERVAL:
		find_nearest_player()
		last_target_update = 0
	
	if target_player == null:
		if not find_nearest_player():
			# Нет игроков - idle
			velocity = Vector2.ZERO
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
			return
	
	# Проверяем валидность текущей цели
	if not is_instance_valid(target_player) or target_player.is_queued_for_deletion():
		target_player = null
		return
	
	var distance_to_target = global_position.distance_to(target_player.global_position)
	
	# Если игрок слишком далеко, не преследовать
	if distance_to_target > MAX_DISTANCE:
		find_nearest_player()
		if target_player == null:	
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
			return
	
	# Вычисляем направление к игроку
	var direction_to_target = (target_player.global_position - global_position).normalized()
	
	# Устанавливаем скорость
	velocity = direction_to_target * SPEED
	
	# Поворачиваем спрайт в сторону игрока
	if abs(direction_to_target.x) > 0.1:
		animated_sprite.flip_h = direction_to_target.x < 0
		
	# Анимация
	if velocity.length() > 10:
		animated_sprite.play("idle")
		
		#animated_sprite.flip_h = velocity.x < 0
		#animated_sprite.play("walk")
	#else:
		#animated_sprite.play("idle")
	
	# Двигаем моба
	move_and_slide()
