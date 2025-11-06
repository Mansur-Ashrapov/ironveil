extends CharacterBody2D
class_name PlayerBase

const SPEED = 240.0
const LERP_SPEED = 20.0

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
@export var expirience: float = 0
@export var level: int = 0
@export var direction: Vector2 = Vector2(1, 0) # направление движения
@export var game_started: bool = false

@export var health_regen: float = 0.25
@export var mana_regen: float = 2
@export var stamina_regen: float = 1.5

var expirience_to_level_up: int = 35
var abilities_instances: Array

var health := max_health
var stamina := max_stamina
var mana := max_mana

var last_direction: Vector2 = Vector2(1, 0) # нужен чтобы не отправлять Vector2.ZERO при отсутсвии инпута и наоборот, если инпут не меняется, сохранять прошлый
var can_move: bool = true # когда персонаж использует абилку, не может двигаться

# SIGNALS
signal parametrs_changed(new_health: int, new_mana: int, new_stamina: int, new_experience: int, new_lvl)
signal get_hit()
signal used_ability(ability_name: String)
signal changed_direction(new_diretion: Vector2)

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
	regen_timer.wait_time = 1.0
	regen_timer.autostart = true
	regen_timer.one_shot = false
	add_child(regen_timer)
	regen_timer.timeout.connect(_on_regen_tick)

func _on_regen_tick() -> void:
	if not game_started and not multiplayer.is_server():
		return

	# Применяем восстановление
	health = clamp(health + health_regen, 0, max_health)
	mana = clamp(mana + mana_regen, 0, max_mana)
	stamina = clamp(stamina + stamina_regen, 0, max_stamina)

	# Обновляем параметры на всех клиентах
	sync_parametrs.rpc(health, mana, stamina, expirience, level)

func _enter_tree() -> void:
	# назначаем игрока владельцем
	set_multiplayer_authority(name.to_int())

	if is_multiplayer_authority():
		player_camera = Camera2D.new()
		self.add_child(player_camera)
		parametrs_changed.connect(player_ui.new_parametrs)
		sync_parametrs.rpc(health, mana, stamina, expirience, level)
	else:
		player_ui.queue_free()

func _process(_delta: float) -> void:
	if not game_started:
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
	for idx in range(0, abilities_instances.size()):
		if Input.is_action_just_pressed("ability" + str(idx)):
			if abilities_instances[idx].can_use(mana, stamina):
				server_use_ability.rpc_id(1, idx)

func take_damage(amount: float):
	health -= amount
	get_hit.emit()

	if health <= 0:
		print("spookie spokie skeleton")

	sync_parametrs.rpc(health, mana, stamina, expirience, level)

func get_expirience(amount: int):
	expirience += amount
	
	while expirience >= expirience_to_level_up:
		level += 1
		expirience -= expirience_to_level_up

	sync_parametrs.rpc(health, mana, stamina, expirience, level)

func start_game():
	_start_game.rpc()

@rpc("any_peer", "reliable", "call_local")
func _start_game():
	game_started = true

# Сервер обрабатывает использование абилки
@rpc("any_peer", "reliable", "call_local")
func server_use_ability(ability_idx: int):
	if not multiplayer.is_server(): return
	if abilities_instances.size() > ability_idx and abilities_instances[ability_idx].can_use(mana, stamina):
		abilities_instances[ability_idx].use(self)
		mana -= (abilities_instances[ability_idx] as Ability).mana_cost
		stamina -= (abilities_instances[ability_idx] as Ability).stamina_cost
		sync_parametrs.rpc(health, mana, stamina, expirience, level)
		sync_ability.rpc(ability_idx)

# Ключ абилки, ключ для клавиши и ключ анимации должны совпадать, чтобы все работало
@rpc("any_peer", "reliable", "call_local")
func sync_ability(ability_idx: int):
	if multiplayer.is_server(): return
	used_ability.emit("ability" + str(ability_idx))
	abilities_instances[ability_idx].use(self)

@rpc("any_peer", "unreliable", "call_local")
func sync_parametrs(new_health: float, new_mana: float, new_stamina: float, new_expirience: float, new_lvl: int) -> void:
	health = new_health
	mana = new_mana
	stamina = new_stamina
	expirience = new_expirience
	level = new_lvl
	parametrs_changed.emit(new_health, new_mana, new_stamina, new_expirience, new_lvl)
