extends Sprite2D
class_name Beam

const CHARGE_TIME: float = 0.8  # Время зарядки
const BEAM_LENGTH: float = 500.0  # Длина луча
const BEAM_DISPLAY_TIME: float = 0.15  # Время отображения луча после выстрела

enum State { CHARGING, FIRED }

var damage: float = 0
var direction: Vector2 = Vector2.RIGHT
var state: State = State.CHARGING
var user: PlayerBase = null
var charge_progress: float = 0.0

func _ready() -> void:
	# Начинаем зарядку
	_start_charging()

func _start_charging() -> void:
	state = State.CHARGING
	modulate.a = 0.3  # Полупрозрачный во время зарядки
	
	# Ждём окончания зарядки
	await get_tree().create_timer(CHARGE_TIME).timeout
	
	if not is_inside_tree():
		return
	
	# Фиксируем направление от пользователя в момент выстрела
	if user and is_instance_valid(user):
		var ability_data = user.get_ability_direction_and_position(0.0)
		direction = ability_data.direction
		global_position = user.global_position
	
	# Выстрел
	_fire()

func _fire() -> void:
	state = State.FIRED
	
	# Синхронизируем визуал на всех клиентах
	sync_fire.rpc(direction.angle())
	
	# Raycast урон (только на сервере)
	if multiplayer.is_server():
		_deal_raycast_damage()
	
	# Показываем луч и удаляем
	await get_tree().create_timer(BEAM_DISPLAY_TIME).timeout
	
	if is_inside_tree():
		queue_free()

@rpc("any_peer", "call_local", "reliable")
func sync_fire(rot: float):
	# Визуальный эффект - растягиваем спрайт на всю длину луча
	rotation = rot
	# Оставляем centered = true (по умолчанию), но смещаем offset по X чтобы луч начинался от игрока
	offset.x = 32  # Половина ширины текстуры (64/2), чтобы левый край был на позиции игрока
	scale = Vector2(BEAM_LENGTH / 64.0, 16)  # Растягиваем (64 - ширина текстуры), Y=16 для широкого луча
	modulate.a = 1.0
	_flash_effect()

func _flash_effect():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(3, 3, 3, 1), 0.02)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), BEAM_DISPLAY_TIME - 0.02)

func _deal_raycast_damage() -> void:
	# Получаем все мобы и проверяем пересечение с лучом
	var mobs = get_tree().get_nodes_in_group("mob")
	var beam_start = user.global_position if user else global_position
	var beam_end = beam_start + direction * BEAM_LENGTH
	
	# Радиус попадания = половина визуальной ширины луча (8 текстура * 16 scale / 2)
	var hit_radius = 80.0
	
	for mob in mobs:
		if not mob or not mob.is_inside_tree() or not mob is MobBase:
			continue
		
		# Проверяем расстояние от моба до линии луча
		var hit_distance = _point_to_line_distance(mob.global_position, beam_start, beam_end)
		
		if hit_distance <= hit_radius:
			# Проверяем что моб находится в направлении луча, а не позади
			var to_mob = mob.global_position - beam_start
			var dot = to_mob.dot(direction)
			if dot > 0 and dot < BEAM_LENGTH:
				(mob as MobBase).get_damage(damage, beam_start)

func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_len = line_vec.length()
	
	if line_len == 0:
		return point_vec.length()
	
	var line_unitvec = line_vec / line_len
	var proj_length = point_vec.dot(line_unitvec)
	proj_length = clamp(proj_length, 0, line_len)
	
	var nearest_point = line_start + line_unitvec * proj_length
	return point.distance_to(nearest_point)

func get_ready(_damage: float):
	damage = _damage

func _physics_process(delta: float) -> void:
	if state == State.CHARGING:
		_process_charging(delta)

func _process_charging(delta: float) -> void:
	charge_progress += delta / CHARGE_TIME
	charge_progress = clamp(charge_progress, 0.0, 1.0)
	
	# Следуем за пользователем во время зарядки
	if user and is_instance_valid(user):
		var ability_data = user.get_ability_direction_and_position(60.0)
		direction = ability_data.direction
		global_position = ability_data.position
		rotation = direction.angle()
	
	# Визуальный эффект зарядки
	modulate.a = 0.3 + charge_progress * 0.4
	
	# Пульсация во время зарядки (квадратная текстура)
	var pulse = sin(Time.get_ticks_msec() / 80.0) * 0.15 + 1.0
	scale = Vector2(pulse, pulse * 8)  # Y в 8 раз больше чтобы компенсировать пропорции текстуры 64x8
