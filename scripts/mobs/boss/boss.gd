extends MobBase
class_name Boss

# Состояния босса
enum BossState {
	IDLE,
	TELEPORT_IN,
	MELEE_ATTACK,
	RETREAT,
	SPECIAL_MARK,
	SPECIAL_STRIKE
}

# Фазы боя
enum BossPhase {
	PHASE_1,  # >50% HP
	PHASE_2   # <=50% HP
}

# Настройки босса
@export var max_boss_health: float = 500.0
@export var melee_damage: float = 25.0
@export var special_damage: float = 60.0
@export var melee_range: float = 120.0
@export var retreat_distance: float = 250.0
@export var teleport_range: float = 600.0

# Дистанция потери цели
const LOSE_TARGET_DISTANCE: float = 600.0

# Кулдауны для фаз (в секундах)
const PHASE_1_ATTACK_COOLDOWN: float = 3.0
const PHASE_2_ATTACK_COOLDOWN: float = 2.0
const PHASE_1_SPECIAL_COOLDOWN: float = 12.0
const PHASE_2_SPECIAL_COOLDOWN: float = 8.0
const MARK_DURATION: float = 1.0  # Время метки перед ударом
const RETREAT_SPEED: float = 150.0

# Текущее состояние
var current_state: BossState = BossState.IDLE
var current_phase: BossPhase = BossPhase.PHASE_1

# Таймеры и кулдауны
var attack_cooldown_timer: float = 0.0
var special_cooldown_timer: float = 0.0
var state_timer: float = 0.0
var mark_timer: float = 0.0

# Цели
var marked_player: PlayerBase = null
var retreat_direction: Vector2 = Vector2.ZERO
var teleport_target_position: Vector2 = Vector2.ZERO

# Ссылки на ноды (animation_controller наследуется от MobBase как $AnimationPlayer)
@onready var boss_animation_controller: BossAnimationController = $AnimationPlayer
@onready var killzone: BossKillzone = $Killzone

# Сцена эффекта метки
var mark_effect_scene: PackedScene = preload("res://scenes/boss_mark_effect.tscn")
var current_mark_effect: Node2D = null

# Сигналы
signal state_changed(new_state: BossState)
signal phase_changed(new_phase: BossPhase)
signal mark_placed(player: PlayerBase)
signal special_attack_started()
signal boss_defeated()


func _ready() -> void:
	super._ready()
	health = max_boss_health
	add_to_group("boss")
	
	# Подключаем сигналы анимации
	if boss_animation_controller:
		boss_animation_controller.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if not game_started:
		return
	
	if multiplayer.is_server():
		_update_phase()
		_update_cooldowns(delta)
		_process_state(delta)


func _update_phase() -> void:
	var health_percent = health / max_boss_health
	var new_phase = BossPhase.PHASE_1 if health_percent > 0.5 else BossPhase.PHASE_2
	
	if new_phase != current_phase:
		current_phase = new_phase
		phase_changed.emit(new_phase)
		print("[BOSS] Phase changed to: ", "PHASE_2" if new_phase == BossPhase.PHASE_2 else "PHASE_1")


func _update_cooldowns(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if special_cooldown_timer > 0:
		special_cooldown_timer -= delta


func _get_attack_cooldown() -> float:
	return PHASE_2_ATTACK_COOLDOWN if current_phase == BossPhase.PHASE_2 else PHASE_1_ATTACK_COOLDOWN


func _get_special_cooldown() -> float:
	return PHASE_2_SPECIAL_COOLDOWN if current_phase == BossPhase.PHASE_2 else PHASE_1_SPECIAL_COOLDOWN


func _process_state(delta: float) -> void:
	match current_state:
		BossState.IDLE:
			_process_idle_state(delta)
		BossState.TELEPORT_IN:
			_process_teleport_in_state(delta)
		BossState.MELEE_ATTACK:
			_process_melee_attack_state(delta)
		BossState.RETREAT:
			_process_retreat_state(delta)
		BossState.SPECIAL_MARK:
			_process_special_mark_state(delta)
		BossState.SPECIAL_STRIKE:
			_process_special_strike_state(delta)


func _process_idle_state(_delta: float) -> void:
	# Проверяем дистанцию до цели - теряем её если слишком далеко
	if _has_valid_target():
		var distance_to_target = global_position.distance_to(target_player.global_position)
		if distance_to_target > LOSE_TARGET_DISTANCE:
			print("[BOSS] Lost target - player too far: ", distance_to_target)
			target_player = null
			return
	
	# Проверяем, можем ли использовать специальную атаку
	if special_cooldown_timer <= 0 and _has_valid_target():
		_start_special_attack()
		return
	
	# Проверяем, можем ли атаковать в ближнем бою
	if attack_cooldown_timer <= 0 and _has_valid_target():
		var distance = global_position.distance_to(target_player.global_position)
		
		if distance <= melee_range:
			# Цель в радиусе ближней атаки
			_change_state(BossState.MELEE_ATTACK)
		else:
			# Телепортируемся к цели (без ограничения дистанции)
			_start_teleport_to_target()
	
	# Обновляем цель если нужно
	if not _has_valid_target():
		find_nearest_player()


func _process_teleport_in_state(delta: float) -> void:
	state_timer -= delta
	
	if state_timer <= 0:
		# Телепортируемся к цели
		global_position = teleport_target_position
		_sync_teleport.rpc(teleport_target_position)
		_change_state(BossState.MELEE_ATTACK)


func _process_melee_attack_state(_delta: float) -> void:
	# Состояние управляется анимацией, ждем сигнал animation_finished
	pass


func _process_retreat_state(delta: float) -> void:
	state_timer -= delta
	
	# Движемся в направлении отступления
	velocity = retreat_direction * RETREAT_SPEED
	move_and_slide()
	
	if state_timer <= 0:
		velocity = Vector2.ZERO
		attack_cooldown_timer = _get_attack_cooldown()
		_change_state(BossState.IDLE)


func _process_special_mark_state(delta: float) -> void:
	mark_timer -= delta
	
	# Проверяем, не перехватил ли кто-то метку через taunt
	if forced_target_player != null and forced_target_player != marked_player:
		_transfer_mark_to(forced_target_player)
	
	# Обновляем позицию метки
	if current_mark_effect and is_instance_valid(marked_player):
		current_mark_effect.global_position = marked_player.global_position + Vector2(0, -80)
	
	if mark_timer <= 0:
		_execute_special_strike()


func _process_special_strike_state(_delta: float) -> void:
	# Состояние управляется анимацией
	pass


func _start_teleport_to_target() -> void:
	if not _has_valid_target():
		return
	
	# Вычисляем позицию телепорта рядом с целью
	var direction_to_target = (target_player.global_position - global_position).normalized()
	teleport_target_position = target_player.global_position - direction_to_target * (melee_range * 0.7)
	
	_change_state(BossState.TELEPORT_IN)
	state_timer = 0.3  # Время на анимацию телепорта
	
	# Поворачиваем спрайт в сторону цели
	_update_sprite_direction(direction_to_target)


func _start_special_attack() -> void:
	# Выбираем жертву: приоритет у того, кто использовал taunt
	if forced_target_player != null and is_instance_valid(forced_target_player):
		marked_player = forced_target_player
	elif target_player != null and is_instance_valid(target_player):
		marked_player = target_player
	else:
		# Выбираем случайного игрока
		var players = get_all_players()
		if players.size() > 0:
			marked_player = players[randi() % players.size()]
	
	if marked_player == null:
		return
	
	_change_state(BossState.SPECIAL_MARK)
	mark_timer = MARK_DURATION
	special_attack_started.emit()
	
	# Создаем визуальный эффект метки
	_spawn_mark_effect.rpc(marked_player.get_path())
	mark_placed.emit(marked_player)
	
	print("[BOSS] Marked player: ", marked_player.name)


func _transfer_mark_to(new_target: PlayerBase) -> void:
	if current_mark_effect:
		current_mark_effect.queue_free()
	
	marked_player = new_target
	_spawn_mark_effect.rpc(marked_player.get_path())
	
	print("[BOSS] Mark transferred to: ", marked_player.name)


func _execute_special_strike() -> void:
	if not is_instance_valid(marked_player):
		_cleanup_special_attack()
		_change_state(BossState.IDLE)
		return
	
	# Телепортируемся к отмеченному игроку
	var direction_to_target = (marked_player.global_position - global_position).normalized()
	var strike_position = marked_player.global_position - direction_to_target * (melee_range * 0.5)
	
	global_position = strike_position
	_sync_teleport.rpc(strike_position)
	_update_sprite_direction(direction_to_target)
	
	_change_state(BossState.SPECIAL_STRIKE)
	
	# Наносим урон
	if killzone:
		killzone.deal_special_damage(marked_player)


func _cleanup_special_attack() -> void:
	if current_mark_effect and is_instance_valid(current_mark_effect):
		current_mark_effect.queue_free()
	current_mark_effect = null
	marked_player = null
	special_cooldown_timer = _get_special_cooldown()


func _change_state(new_state: BossState) -> void:
	current_state = new_state
	state_changed.emit(new_state)
	_sync_state.rpc(new_state)
	
	# Запускаем соответствующую анимацию
	match new_state:
		BossState.IDLE:
			if boss_animation_controller:
				boss_animation_controller.play_idle()
		BossState.TELEPORT_IN:
			if boss_animation_controller:
				boss_animation_controller.play_skill()
		BossState.MELEE_ATTACK:
			if boss_animation_controller:
				boss_animation_controller.play_attack()
		BossState.RETREAT:
			if boss_animation_controller:
				boss_animation_controller.play_idle()
		BossState.SPECIAL_MARK:
			if boss_animation_controller:
				boss_animation_controller.play_skill()
		BossState.SPECIAL_STRIKE:
			if boss_animation_controller:
				boss_animation_controller.play_attack1()


func _on_animation_finished(anim_name: String) -> void:
	if not multiplayer.is_server():
		return
	
	match current_state:
		BossState.MELEE_ATTACK:
			if anim_name == "attack" or anim_name == "attack1":
				# Наносим урон
				if killzone and _has_valid_target():
					var distance = global_position.distance_to(target_player.global_position)
					if distance <= melee_range:
						killzone.deal_melee_damage(target_player)
				
				# Переключаемся на другого игрока после атаки
				_switch_to_different_target()
				
				# Начинаем отступление
				_start_retreat()
		
		BossState.SPECIAL_STRIKE:
			if anim_name == "attack1":
				_cleanup_special_attack()
				
				# Переключаемся на другого игрока после спец. атаки
				_switch_to_different_target()
				
				_start_retreat()


func _start_retreat() -> void:
	if _has_valid_target():
		retreat_direction = (global_position - target_player.global_position).normalized()
	else:
		retreat_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	state_timer = retreat_distance / RETREAT_SPEED
	_change_state(BossState.RETREAT)


func _has_valid_target() -> bool:
	return target_player != null and is_instance_valid(target_player) and not target_player.is_queued_for_deletion()


# Переключает цель на другого игрока (если есть)
func _switch_to_different_target() -> void:
	var players = get_all_players()
	if players.size() <= 1:
		return  # Нет других игроков для переключения
	
	var current_target = target_player
	var available_players = players.filter(func(p): return p != current_target and is_instance_valid(p))
	
	if available_players.size() > 0:
		target_player = available_players[randi() % available_players.size()]
		print("[BOSS] Switched target to: ", target_player.name)


func _update_sprite_direction(direction: Vector2) -> void:
	if abs(direction.x) > 0.1:
		sprite.flip_h = direction.x < 0


# Переопределяем force_aggro для перехвата метки
func force_aggro(player: PlayerBase, duration: float = -1.0) -> void:
	super.force_aggro(player, duration)
	
	# Если босс в состоянии метки, переносим её на нового таргета
	if current_state == BossState.SPECIAL_MARK and marked_player != player:
		_transfer_mark_to(player)


# RPC функции для синхронизации
@rpc("authority", "call_local", "reliable")
func _sync_state(new_state: int) -> void:
	current_state = new_state as BossState


@rpc("authority", "call_local", "reliable")
func _sync_teleport(new_position: Vector2) -> void:
	global_position = new_position


@rpc("authority", "call_local", "reliable")
func _spawn_mark_effect(player_path: NodePath) -> void:
	var player = get_node_or_null(player_path)
	if player == null:
		return
	
	if current_mark_effect and is_instance_valid(current_mark_effect):
		current_mark_effect.queue_free()
	
	current_mark_effect = mark_effect_scene.instantiate()
	get_tree().get_first_node_in_group("trash").add_child(current_mark_effect)
	current_mark_effect.global_position = player.global_position + Vector2(0, -80)
	current_mark_effect.setup(MARK_DURATION)


# Переопределяем take_damage для отслеживания фаз
func take_damage(amount: float, damage_source_position: Vector2 = Vector2.ZERO) -> void:
	super.take_damage(amount, damage_source_position)
	_update_phase()

# Переопределяем смерть для сигнала победы
@rpc("any_peer", "call_local", "reliable")
func death():
	boss_defeated.emit()
	_notify_victory.rpc()
	queue_free()

@rpc("authority", "call_local", "reliable")
func _notify_victory() -> void:
	# Уведомляем GameManager о победе
	var game_manager = get_tree().get_first_node_in_group("root")
	if game_manager:
		var gm = game_manager.get_node_or_null("%GameManager")
		if gm and gm.has_method("on_boss_defeated"):
			gm.on_boss_defeated()

