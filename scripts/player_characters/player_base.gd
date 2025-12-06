extends CharacterBody2D
class_name PlayerBase

const SPEED = 240.0
const LERP_SPEED = 20.0
const REGEN_TICK_INTERVAL = 1.0

@export var player_ui: CanvasLayer
@export var animation_controller: PlayerAnimationController
@export var sprite: Sprite2D
var player_camera: Camera2D

# Ключ абилки, ключ для клавиши и ключ анимации должны совпадать, чтобы все работало
@export var abilities: Array
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var max_mana: float = 100.0
@export var base_damage: float = 10.0
@export var experience: float = 0
@export var level: int = 0
@export var direction: Vector2 = Vector2(1, 0) # направление движения
@export var game_started: bool = false

@export var health_regen: float = 0.25
@export var mana_regen: float = 2
@export var stamina_regen: float = 1.5

@export var health_per_level: float = 20.0
@export var stamina_per_level: float = 20.0
@export var mana_per_level: float = 20.0
@export var damage_per_level: float = 5.0

var experience_to_level_up: int = 35
var abilities_instances: Array

var health := max_health
var stamina := max_stamina
var mana := max_mana

# Счетчик непотраченных уровней (для очереди прокачки)
var pending_upgrades: int = 0

var last_direction: Vector2 = Vector2(1, 0) # нужен чтобы не отправлять Vector2.ZERO при отсутсвии инпута и наоборот, если инпут не меняется, сохранять прошлый
var can_move: bool = true # когда персонаж использует абилку, не может двигаться

# RESPAWN SYSTEM
var spawn_position: Vector2 = Vector2.ZERO
var is_dead: bool = false
var respawn_timer: Timer
const RESPAWN_TIME: float = 5.0

# SIGNALS
signal parameters_changed(new_health: int, new_mana: int, new_stamina: int, new_experience: int, new_lvl)
signal get_hit()
signal used_ability(ability_name: String)
signal changed_direction(new_diretion: Vector2)
signal show_ability_upgrade_ui(abilities: Array)  # Показать UI выбора навыка для прокачки
signal ability_upgraded(ability_idx: int, new_level: int)  # Навык улучшен
signal respawn_timer_started()  # Таймер респавна начался
signal respawn_timer_updated(time_remaining: float)  # Обновление таймера респавна
signal respawn_timer_finished()  # Таймер респавна завершен

# POSITION INTERPOLATION
var state_buffer := [] # Буффер передвижений игрока


func _ready() -> void:
	# Добавляем игрока в группу для легкого поиска
	add_to_group("players")
	
	get_hit.connect(animation_controller.on_get_hit)
	used_ability.connect(animation_controller.on_ability_used)
	changed_direction.connect(animation_controller.on_direction_changed)
	
	for ability in abilities:
		abilities_instances.append(ability.new())
	
	var regen_timer = Timer.new()
	regen_timer.wait_time = REGEN_TICK_INTERVAL
	regen_timer.autostart = true
	regen_timer.one_shot = false
	add_child(regen_timer)
	regen_timer.timeout.connect(_on_regen_tick)
	
	# Создаем таймер респавна
	respawn_timer = Timer.new()
	respawn_timer.wait_time = 0.1  # Обновляем каждые 0.1 секунды для плавного отображения
	respawn_timer.autostart = false
	respawn_timer.one_shot = false
	add_child(respawn_timer)
	respawn_timer.timeout.connect(_on_respawn_timer_tick)

func _on_regen_tick() -> void:
	if not game_started:
		return
	
	if not multiplayer.is_server():
		return
	
	# Не восстанавливаем ресурсы если игрок мертв
	if is_dead:
		return

	# Применяем восстановление
	health = clamp(health + health_regen, 0, max_health)
	mana = clamp(mana + mana_regen, 0, max_mana)
	stamina = clamp(stamina + stamina_regen, 0, max_stamina)

	# Обновляем параметры на всех клиентах
	sync_parameters.rpc(health, mana, stamina, experience, level)

func _enter_tree() -> void:
	# назначаем игрока владельцем
	set_multiplayer_authority(name.to_int())
	
	# Сохраняем начальную позицию спавна
	spawn_position = global_position

	if is_multiplayer_authority():
		player_camera = Camera2D.new()
		self.add_child(player_camera)
		parameters_changed.connect(player_ui.new_parameters)
		player_ui.setup(self)  # Настройка UI с ссылкой на игрока
		# Начальное обновление UI (данные синхронизируются через MultiplayerSynchronizer)
		parameters_changed.emit(health, mana, stamina, experience, level)
	else:
		player_ui.queue_free()

func _process(_delta: float) -> void:
	if not game_started:
		return
	# Если игрок мертв, не обрабатываем ввод (на всех клиентах)
	if is_dead:
		velocity = Vector2.ZERO
		direction = Vector2.ZERO
		move_and_slide()
		return
	# обработка нажатий игрока и отправка их серверу
	if is_multiplayer_authority():
		_handle_move_input()
		_handle_abilities_input()
		velocity = direction * SPEED
		_flip_sprite()
	
	move_and_slide()

func _flip_sprite():
	if direction.x > 0:
		sprite.flip_h = false
	elif direction.x < 0:
		sprite.flip_h = true

# Вспомогательный метод для расчета направления и позиции способностей
# Возвращает словарь с direction и position
func get_ability_direction_and_position(offset_distance: float = 50.0) -> Dictionary:
	var ability_direction: Vector2
	var ability_position: Vector2
	
	if direction != Vector2.ZERO:
		ability_direction = direction
		ability_position = global_position + direction * offset_distance
	else:
		# Если нет направления движения, используем направление спрайта
		if sprite.flip_h:
			ability_direction = Vector2.LEFT
			ability_position = global_position + Vector2.LEFT * offset_distance
		else:
			ability_direction = Vector2.RIGHT
			ability_position = global_position + Vector2.RIGHT * offset_distance
	
	return {"direction": ability_direction, "position": ability_position}

# Получает ввод игрока и отправляет вектор направления передвижения
func _handle_move_input() -> void:
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if last_direction == Vector2.ZERO and direction == Vector2.ZERO or last_direction == direction: return
	elif not can_move: 
		last_direction = direction
	changed_direction.emit(direction)
	last_direction = direction

# Обрабатывает использование абилок
func _handle_abilities_input() -> void:
	if is_dead:
		return  # Нельзя использовать способности когда мертв
	for idx in range(0, abilities_instances.size()):
		if Input.is_action_just_pressed("ability" + str(idx)):
			if abilities_instances[idx].can_use(mana, stamina):
				server_use_ability.rpc_id(1, idx)

func take_damage(amount: float):
	if is_dead:
		return  # Игрок уже мертв, не обрабатываем урон
	
	health -= amount
	get_hit.emit()
	
	# Синхронизируем звук получения урона на всех клиентах
	_sync_sound.rpc("player_hurt")

	if health <= 0:
		health = 0
		_on_death()

	sync_parameters.rpc(health, mana, stamina, experience, level)

func get_experience(amount: int):
	experience += amount
	
	while experience >= experience_to_level_up:
		level += 1
		experience -= experience_to_level_up
		level_up()

	sync_maxs_parameters.rpc(max_health, max_stamina, max_mana, base_damage)
	sync_parameters.rpc(health, mana, stamina, experience, level)

func level_up():
	max_stamina += stamina_per_level
	max_mana += mana_per_level
	max_health += health_per_level
	base_damage += damage_per_level
	
	# Если мы являемся владельцем игрока, увеличиваем счетчик и показываем UI напрямую
	if is_multiplayer_authority():
		pending_upgrades += 1
		_show_upgrade_ui_local()
	# Если мы на сервере, но не являемся владельцем, отправляем RPC клиенту-владельцу
	elif multiplayer.is_server():
		var player_peer_id = get_multiplayer_authority()
		if player_peer_id != 0:
			client_show_upgrade_ui.rpc_id(player_peer_id)

func _show_upgrade_ui_local():
	# Показываем UI только если он еще не открыт
	if player_ui and player_ui.ability_upgrade_ui:
		if not player_ui.ability_upgrade_ui.visible:
			# Проигрываем звук только при первом показе (когда UI был закрыт)
			SoundManager.play_sound("player_level_up", global_position)
			show_ability_upgrade_ui.emit(abilities_instances)

@rpc("any_peer", "reliable", "call_local")
func client_show_upgrade_ui():
	# Этот метод вызывается на клиенте-владельце игрока
	if is_multiplayer_authority():
		# Увеличиваем счетчик непотраченных уровней на клиенте
		pending_upgrades += 1
		_show_upgrade_ui_local()

# Улучшить навык по индексу (вызывается из UI)
func request_upgrade_ability(ability_idx: int):
	if is_multiplayer_authority():
		server_upgrade_ability.rpc_id(1, ability_idx)

@rpc("any_peer", "reliable", "call_local")
func server_upgrade_ability(ability_idx: int):
	if not multiplayer.is_server(): return
	
	if ability_idx >= 0 and ability_idx < abilities_instances.size():
		var ability = abilities_instances[ability_idx] as Ability
		if ability.can_upgrade():
			ability.upgrade()
			# Синхронизируем уровень навыка со всеми клиентами
			sync_ability_level.rpc(ability_idx, ability.ability_level)

@rpc("any_peer", "reliable", "call_local")
func sync_ability_level(ability_idx: int, new_level: int):
	if ability_idx >= 0 and ability_idx < abilities_instances.size():
		(abilities_instances[ability_idx] as Ability).ability_level = new_level
		ability_upgraded.emit(ability_idx, new_level)
		
		# Уменьшаем счетчик непотраченных уровней и показываем следующее окно, если есть
		if is_multiplayer_authority():
			pending_upgrades = max(0, pending_upgrades - 1)
			if pending_upgrades > 0:
				# Показываем следующее окно выбора улучшения с небольшой задержкой
				# чтобы текущее окно успело закрыться
				await get_tree().process_frame
				_show_upgrade_ui_local()

func start_game():
	_start_game.rpc()

@rpc("any_peer", "reliable", "call_local")
func sync_maxs_parameters(max_h, max_s, max_m, base_d):
	max_health = max_h
	max_stamina = max_s
	max_mana = max_m
	base_damage = base_d

@rpc("any_peer", "reliable", "call_local")
func _start_game():
	game_started = true

# Сервер обрабатывает использование абилки
@rpc("any_peer", "reliable", "call_local")
func server_use_ability(ability_idx: int):
	if not multiplayer.is_server(): return
	if abilities_instances.size() > ability_idx and abilities_instances[ability_idx].can_use(mana, stamina):
		abilities_instances[ability_idx].use(self)
		var ability = abilities_instances[ability_idx] as Ability
		mana -= ability.get_effective_mana_cost()
		stamina -= ability.get_effective_stamina_cost()
		sync_parameters.rpc(health, mana, stamina, experience, level)
		sync_ability.rpc(ability_idx)

# Ключ абилки, ключ для клавиши и ключ анимации должны совпадать, чтобы все работало
@rpc("any_peer", "reliable", "call_local")
func sync_ability(ability_idx: int):
	if multiplayer.is_server(): return
	used_ability.emit("ability" + str(ability_idx))
	abilities_instances[ability_idx].use(self)

@rpc("any_peer", "unreliable", "call_local")
func sync_parameters(new_health: float, new_mana: float, new_stamina: float, new_experience: float, new_lvl: int) -> void:
	health = new_health
	mana = new_mana
	stamina = new_stamina
	experience = new_experience
	level = new_lvl
	parameters_changed.emit(new_health, new_mana, new_stamina, new_experience, new_lvl)

# Синхронизация звуков на всех клиентах
@rpc("any_peer", "reliable", "call_local")
func _sync_sound(sound_key: String) -> void:
	SoundManager.play_sound(sound_key, global_position)

# Обработка смерти игрока
func _on_death():
	if is_dead:
		return  # Уже обрабатываем смерть
	
	print("spookie spokie skeleton")
	
	# Синхронизируем состояние смерти на всех клиентах и запускаем таймер
	if multiplayer.is_server():
		# На сервере устанавливаем состояние и запускаем таймер
		set_dead_state.rpc(true)
		start_respawn_timer.rpc()
	else:
		# На клиенте просто устанавливаем состояние (таймер запустится через RPC)
		set_dead_state.rpc(true)
	
	# Звук смерти только для владельца
	if is_multiplayer_authority():
		SoundManager.play_sound("player_death", global_position)

# Синхронизация состояния смерти
@rpc("any_peer", "reliable", "call_local")
func set_dead_state(dead: bool):
	is_dead = dead
	if dead:
		# Скрываем спрайт игрока
		if sprite:
			sprite.visible = false
		# Блокируем движение немедленно
		velocity = Vector2.ZERO
		direction = Vector2.ZERO
	else:
		# Показываем спрайт игрока
		if sprite:
			sprite.visible = true

# Запуск таймера респавна
@rpc("any_peer", "reliable", "call_local")
func start_respawn_timer():
	if not respawn_timer:
		return
	
	# Убеждаемся, что is_dead установлен (на случай если RPC пришел раньше)
	if not is_dead:
		is_dead = true
	
	# Сбрасываем таймер
	respawn_time_remaining = RESPAWN_TIME
	
	# Показываем таймер только владельцу игрока
	if is_multiplayer_authority():
		respawn_timer_started.emit()
	
	# Останавливаем таймер если он уже запущен
	if respawn_timer.is_stopped() == false:
		respawn_timer.stop()
	
	respawn_timer.start()
	_on_respawn_timer_tick()  # Сразу обновляем таймер

# Обновление таймера респавна
var respawn_time_remaining: float = RESPAWN_TIME

func _on_respawn_timer_tick():
	# Если таймер запущен, он должен работать до истечения времени
	# (независимо от is_dead, так как RPC могут прийти в разном порядке)
	
	respawn_time_remaining -= respawn_timer.wait_time
	
	# Обновляем UI только для владельца (если is_dead установлен)
	if is_multiplayer_authority() and is_dead:
		respawn_timer_updated.emit(respawn_time_remaining)
	
	# Когда таймер истек, респавним игрока (только на сервере)
	if respawn_time_remaining <= 0:
		respawn_timer.stop()
		respawn_time_remaining = RESPAWN_TIME
		
		if multiplayer.is_server():
			# Убеждаемся, что is_dead установлен перед респавном
			if not is_dead:
				is_dead = true
			respawn_player.rpc()

# Респавн игрока
@rpc("any_peer", "reliable", "call_local")
func respawn_player():
	# Синхронизируем состояние смерти на всех клиентах
	set_dead_state.rpc(false)
	
	# Восстанавливаем здоровье, ману и выносливость (только на сервере)
	if multiplayer.is_server():
		health = max_health
		mana = max_mana
		stamina = max_stamina
		
		# Перемещаем игрока на начальную точку спавна
		global_position = spawn_position
		
		# Синхронизируем позицию на всех клиентах
		sync_respawn_position.rpc(spawn_position)
		
		# Синхронизируем параметры
		sync_parameters.rpc(health, mana, stamina, experience, level)
	
	# Скрываем таймер для владельца (на всех клиентах)
	if is_multiplayer_authority():
		respawn_timer_finished.emit()

# Синхронизация позиции респавна
@rpc("any_peer", "reliable", "call_local")
func sync_respawn_position(new_position: Vector2):
	global_position = new_position

