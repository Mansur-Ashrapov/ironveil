extends CharacterBody2D
class_name MobBase

@export var experience_cost: int = 15
@export var health: float = 30
@onready var animation_controller: MobBaseAnimationController = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@export var game_started = false

const SPEED = 105
const MAX_DISTANCE = 800
# Кадры между обновлением цели
const TARGET_UPDATE_INTERVAL = 30
# Радиус агрессии
const AGRO_RADIUS = 300
# Сила отбрасывания при получении урона
const KNOCKBACK_FORCE = 200
# Длительность отбрасывания в секундах
const KNOCKBACK_DURATION = 0.35
const DEATH_DELAY = 0.25

var target_player: Node2D
var last_target_update = 0
var is_knockback_active: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

# Система принудительного агро
var forced_target_player: Node2D = null
var forced_aggro_timer: float = -1.0  # -1 означает отсутствие принудительного агро

signal get_hit()
signal moving_to_player()
signal stop_moving()

func _ready() -> void:
	add_to_group("damageables")
	
	get_hit.connect(animation_cotroller.on_get_hit)
	moving_to_player.connect(animation_cotroller.moving_to_player)
	stop_moving.connect(animation_cotroller.stop_moving)

func find_nearest_player() -> bool:
	# Если есть принудительное агро, используем его
	if forced_target_player != null and is_instance_valid(forced_target_player) and not forced_target_player.is_queued_for_deletion():
		target_player = forced_target_player
		return true
	
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

func take_damage(amount: float, damage_source_position: Vector2 = Vector2.ZERO):
	health -= amount
	
	get_hit.emit()
	
	# Синхронизируем звук получения урона на всех клиентах
	_sync_sound.rpc("mob_hurt")
	
	# Применяем импульс/отбрасывание
	if damage_source_position != Vector2.ZERO:
		apply_knockback(damage_source_position)
	
	if health <= 0 and multiplayer.is_server():
		# Синхронизируем звук смерти на всех клиентах
		_sync_sound.rpc("mob_death")
		for player in get_all_players():
			if player is PlayerBase:
				player.get_experience(experience_cost)
		await get_tree().create_timer(DEATH_DELAY).timeout
		death.rpc()
		

func take_damage(amount: float, damage_source_position: Vector2 = Vector2.ZERO):
	get_damage(amount, damage_source_position)

func apply_knockback(damage_source_position: Vector2):
	# Вычисляем направление от источника урона
	var knockback_direction = (global_position - damage_source_position).normalized()
	knockback_velocity = knockback_direction * KNOCKBACK_FORCE
	is_knockback_active = true
	knockback_timer = KNOCKBACK_DURATION

@rpc("any_peer", "call_local", "reliable")
func death():
	queue_free()

# Синхронизация звуков на всех клиентах
@rpc("any_peer", "reliable", "call_local")
func _sync_sound(sound_key: String) -> void:
	SoundManager.play_sound(sound_key, global_position)

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

# Принудительно переагрит моба на указанного игрока
# duration: длительность принудительного агро в секундах (-1 для постоянного)
func force_aggro(player: PlayerBase, duration: float = -1.0):
	print("[MOB ", name, "] force_aggro called | Player: ", player.name, " | Duration: ", duration)
	
	if not multiplayer.is_server():
		print("[MOB ", name, "] Not server, skipping")
		return
	
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		print("[MOB ", name, "] Player invalid or queued for deletion")
		return
	
	var old_target = str(target_player.name) if target_player else "none" 
	forced_target_player = player
	forced_aggro_timer = duration
	target_player = player  # Сразу устанавливаем цель
	print("[MOB ", name, "] Target changed: ", old_target, " -> ", player.name, " | Timer: ", forced_aggro_timer)

func _physics_process(delta: float) -> void:
	if not game_started:
		return
	
	if multiplayer.is_server():
		mob_movement(delta)

func mob_movement(delta: float):
	_update_forced_aggro_timer(delta)
	_validate_forced_target()
	
	if _handle_knockback(delta):
		return
	
	_update_target_if_needed()
	
	if not _ensure_valid_target():
		return
	
	if not _check_target_distance():
		return
	
	_move_towards_target()

func _update_forced_aggro_timer(delta: float) -> void:
	if forced_aggro_timer > 0:
		forced_aggro_timer -= delta
		if forced_aggro_timer <= 0:
			forced_target_player = null
			forced_aggro_timer = -1.0

func _validate_forced_target() -> void:
	if forced_target_player != null and (not is_instance_valid(forced_target_player) or forced_target_player.is_queued_for_deletion()):
		forced_target_player = null
		forced_aggro_timer = -1.0

func _handle_knockback(delta: float) -> bool:
	if not is_knockback_active:
		return false
	
	knockback_timer -= delta
	velocity = knockback_velocity
	
	# Затухание отбрасывания
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 1.0 - (knockback_timer / KNOCKBACK_DURATION))
	
	if knockback_timer <= 0:
		is_knockback_active = false
		knockback_velocity = Vector2.ZERO
	
	move_and_slide()
	return true

func _update_target_if_needed() -> void:
	if forced_target_player == null:
		last_target_update += 1
		if last_target_update >= TARGET_UPDATE_INTERVAL:
			find_nearest_player()
			last_target_update = 0

func _ensure_valid_target() -> bool:
	if target_player == null:
		if not find_nearest_player():
			_stop_movement()
			return false
	
	# Проверяем валидность текущей цели
	if not is_instance_valid(target_player) or target_player.is_queued_for_deletion():
		target_player = null
		if forced_target_player == null:
			return false
	
	return true

func _check_target_distance() -> bool:
	var distance_to_target = global_position.distance_to(target_player.global_position)
	
	# Если игрок слишком далеко и нет принудительного агро, не преследовать
	if distance_to_target > MAX_DISTANCE and forced_target_player == null:
		find_nearest_player()
		if target_player == null:
			_stop_movement()
			return false
	
	return true

func _move_towards_target() -> void:
	var direction_to_target = (target_player.global_position - global_position).normalized()
	velocity = direction_to_target * SPEED
	moving_to_player.emit()
	
	# Поворачиваем спрайт в сторону игрока
	if abs(direction_to_target.x) > 0.1:
		sprite.flip_h = direction_to_target.x < 0
	
	move_and_slide()

func _stop_movement() -> void:
	velocity = Vector2.ZERO
	stop_moving.emit()
