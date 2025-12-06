extends Resource
class_name Ability

@export var ability_name: String = "Ability"
@export var cooldown: float = 0.7
@export var stamina_cost: float = 5.0
@export var mana_cost: float = 5.0

# Ключ звука для этой способности (должен быть зарегистрирован в SoundManager)
# Переопределите в наследниках или оставьте пустым для автоматического ключа
@export var sound_key: String = ""

# Система прокачки навыков
var ability_level: int = 0
const MAX_LEVEL: int = 5
const COOLDOWN_REDUCTION_PER_LEVEL: float = 0.1  # 10% уменьшение за уровень
const COST_REDUCTION_PER_LEVEL: float = 0.08     # 8% уменьшение за уровень

var last_used_time: float = -999.0

# Получить текущий cooldown с учётом уровня
func get_effective_cooldown() -> float:
	var reduction = 1.0 - (ability_level * COOLDOWN_REDUCTION_PER_LEVEL)
	return cooldown * max(reduction, 0.3)  # Минимум 30% от базового

# Получить текущую стоимость маны с учётом уровня
func get_effective_mana_cost() -> float:
	var reduction = 1.0 - (ability_level * COST_REDUCTION_PER_LEVEL)
	return mana_cost * max(reduction, 0.4)  # Минимум 40% от базовой

# Получить текущую стоимость стамины с учётом уровня
func get_effective_stamina_cost() -> float:
	var reduction = 1.0 - (ability_level * COST_REDUCTION_PER_LEVEL)
	return stamina_cost * max(reduction, 0.4)  # Минимум 40% от базовой

func can_upgrade() -> bool:
	return ability_level < MAX_LEVEL

func upgrade() -> bool:
	if can_upgrade():
		ability_level += 1
		return true
	return false

func can_use(mana: float, stamina: float) -> bool:
	var stamina_remains = stamina - get_effective_stamina_cost()
	var mana_remains = mana - get_effective_mana_cost()
	return Time.get_ticks_msec() / 1000.0 - last_used_time >= get_effective_cooldown() and stamina_remains >= 0 and mana_remains >= 0

func use(user: PlayerBase):
	last_used_time = Time.get_ticks_msec() / 1000.0
	_play_ability_sound(user)
	_on_use(user)

func _on_use(_user: PlayerBase):
	# Переопределяется в наследниках
	pass

# Проигрывает звук способности
func _play_ability_sound(user: PlayerBase) -> void:
	var key = _get_sound_key()
	if key.is_empty():
		return
	SoundManager.play_sound(key, user.global_position)

# Возвращает ключ звука для этой способности
func _get_sound_key() -> String:
	if not sound_key.is_empty():
		return sound_key
	# Автоматически генерируем ключ на основе имени способности
	return "ability_" + ability_name.to_lower().replace(" ", "_")
