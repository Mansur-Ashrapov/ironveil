extends CharacterBody2D
class_name MobBase

@export var expirience_cost: int = 15
@export var health: float = 30
@onready var animation_cotroller: MobBaseAnimationController = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@export var game_started = false

const SPEED = 90
const MAX_DISTANCE = 800
# Кадры между обновлением цели
const TARGET_UPDATE_INTERVAL = 30
# Радиус агрессии
const AGRO_RADIUS = 300
# Сила отбрасывания при получении урона
const KNOCKBACK_FORCE = 200
# Длительность отбрасывания в секундах
const KNOCKBACK_DURATION = 0.2

var target_player: Node2D
var last_target_update = 0
var is_knockback_active: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

signal get_hit()
signal moving_to_player()
signal stop_moving()

func _ready() -> void:
	get_hit.connect(animation_cotroller.on_get_hit)
	moving_to_player.connect(animation_cotroller.moving_to_player)
	stop_moving.connect(animation_cotroller.stop_moving)

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

func get_damage(amount: float, damage_source_position: Vector2 = Vector2.ZERO):
	health -= amount
	
	get_hit.emit()
	
	# Применяем импульс/отбрасывание
	if damage_source_position != Vector2.ZERO:
		apply_knockback(damage_source_position)
	
	if health <= 0 and multiplayer.is_server():
		for player in get_all_players():
			if player is PlayerBase:
				player.get_expirience(expirience_cost)
		await get_tree().create_timer(0.25).timeout
		death.rpc()
		

func apply_knockback(damage_source_position: Vector2):
	# Вычисляем направление от источника урона
	var knockback_direction = (global_position - damage_source_position).normalized()
	knockback_velocity = knockback_direction * KNOCKBACK_FORCE
	is_knockback_active = true
	knockback_timer = KNOCKBACK_DURATION

@rpc("any_peer", "call_local", "reliable")
func death():
	queue_free()

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
	if not game_started:
		return
	
	if multiplayer.is_server():
		mob_movement(delta)

func mob_movement(delta: float):
	# Обрабатываем отбрасывание
	if is_knockback_active:
		knockback_timer -= delta
		velocity = knockback_velocity
		
		# Затухание отбрасывания (опционально)
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 1.0 - (knockback_timer / KNOCKBACK_DURATION))
		
		if knockback_timer <= 0:
			is_knockback_active = false
			knockback_velocity = Vector2.ZERO
		
		move_and_slide()
		return
	
	# Обновляем цель с интервалом
	last_target_update += 1
	if last_target_update >= TARGET_UPDATE_INTERVAL:
		find_nearest_player()
		last_target_update = 0
	
	if target_player == null:
		if not find_nearest_player():
			velocity = Vector2.ZERO
			stop_moving.emit()
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
			stop_moving.emit()
			return

	# Вычисляем направление к игроку
	var direction_to_target = (target_player.global_position - global_position).normalized()

	# Устанавливаем скорость
	velocity = direction_to_target * SPEED

	# Поворачиваем спрайт в сторону игрока
	if abs(direction_to_target.x) > 0.1:
		sprite.flip_h = direction_to_target.x < 0

	# Двигаем моба
	move_and_slide()
