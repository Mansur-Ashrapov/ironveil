extends Node
class_name SoundManagerClass

## Менеджер звуков - синглтон для проигрывания звуков в игре.
## Использует заглушки, пока реальные звуки не добавлены.
## 
## Использование:
##   SoundManager.play_sound("sword_attack")
##   SoundManager.play_sound("player_hurt", global_position)

# Словарь звуков: ключ -> путь к аудиофайлу
var sounds: Dictionary = {
	# Звуки игрока
	"player_hurt": "res://sounds/player_hurt.wav",          # Игрок получает урон
	"player_death": "res://sounds/player_death.wav",         # Смерть игрока
	"player_level_up": "res://sounds/player_level_up.wav",      # Повышение уровня
	"player_footstep": "",      # Шаги
	
	# Звуки способностей
	"ability_sword": "",        # Удар мечом
	"ability_beam": "res://sounds/abbility_beam.wav",         # Луч
	"ability_fireball": "res://sounds/ability_fireball.wav",     # Огненный шар
	"ability_taunt": "res://sounds/ability_taunt.wav",        # Провокация
	
	# Звуки мобов
	"mob_hurt": "res://sounds/mob_hurt.wav",             # Моб получает урон
	"mob_death": "res://sounds/mob_death.wav",            # Смерть моба
	"mob_attack": "",           # Атака моба
	
	# UI звуки
	"ui_click": "res://sounds/ui_click.wav",             # Клик по UI
	"ui_upgrade": "res://sounds/ui_upgrade.wav",           # Улучшение навыка
}

# Количество одновременных AudioStreamPlayer для полифонии
const MAX_POLYPHONY: int = 16
var audio_players_2d: Array[AudioStreamPlayer2D] = []
var audio_players: Array[AudioStreamPlayer] = []
var current_player_index_2d: int = 0
var current_player_index: int = 0

# Громкости по категориям (можно настроить в меню)
var master_volume: float = 0.01
var sfx_volume: float = 1.0
var music_volume: float = 1.0

# Кэш загруженных аудиопотоков
var _audio_cache: Dictionary = {}


func _ready() -> void:
	# Создаём пул AudioStreamPlayer для 2D звуков
	for i in range(MAX_POLYPHONY):
		var player_2d = AudioStreamPlayer2D.new()
		player_2d.bus = "Master"  # Можно настроить на SFX шину
		add_child(player_2d)
		audio_players_2d.append(player_2d)
		
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		audio_players.append(player)


## Проигрывает звук по ключу.
## sound_key - ключ из словаря sounds
## position - опционально, позиция для 2D звука. Если null - играет глобально.
## volume_db - громкость в децибелах (по умолчанию 0)
## pitch_scale - изменение высоты тона (по умолчанию 1.0)
func play_sound(sound_key: String, position: Variant = null, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sounds.has(sound_key):
		push_warning("SoundManager: Unknown sound key '%s'" % sound_key)
		return
	
	var sound_path: String = sounds[sound_key]
	
	# Если путь пустой - это заглушка, просто логируем
	if sound_path.is_empty():
		_play_placeholder(sound_key, position)
		return
	
	# Загружаем аудиопоток
	var stream = _get_or_load_stream(sound_path)
	if stream == null:
		push_warning("SoundManager: Failed to load sound '%s'" % sound_path)
		return
	
	# Играем звук
	if position != null and position is Vector2:
		_play_2d_sound(stream, position, volume_db, pitch_scale)
	else:
		_play_global_sound(stream, volume_db, pitch_scale)


## Проигрывает случайный звук из списка
func play_random_sound(sound_keys: Array[String], position: Variant = null, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if sound_keys.is_empty():
		return
	var random_key = sound_keys[randi() % sound_keys.size()]
	play_sound(random_key, position, volume_db, pitch_scale)


## Регистрирует новый звук в словаре
func register_sound(key: String, path: String) -> void:
	sounds[key] = path


## Устанавливает путь к звуку (для замены заглушки на реальный звук)
func set_sound_path(key: String, path: String) -> void:
	if sounds.has(key):
		sounds[key] = path
		# Очищаем кэш для этого звука
		if _audio_cache.has(path):
			_audio_cache.erase(path)


## Проверяет, является ли звук заглушкой
func is_placeholder(sound_key: String) -> bool:
	return sounds.has(sound_key) and sounds[sound_key].is_empty()


# Воспроизводит заглушку (просто print для отладки)
func _play_placeholder(sound_key: String, position: Variant) -> void:
	if position != null:
		print("[SFX PLACEHOLDER] '%s' at %s" % [sound_key, position])
	else:
		print("[SFX PLACEHOLDER] '%s' (global)" % sound_key)


# Получает или загружает аудиопоток из кэша
func _get_or_load_stream(path: String) -> AudioStream:
	if _audio_cache.has(path):
		return _audio_cache[path]
	
	if not ResourceLoader.exists(path):
		return null
	
	var stream = load(path) as AudioStream
	if stream:
		_audio_cache[path] = stream
	return stream


# Играет 2D звук в определенной позиции
func _play_2d_sound(stream: AudioStream, pos: Vector2, volume_db: float, pitch_scale: float) -> void:
	var player = audio_players_2d[current_player_index_2d]
	current_player_index_2d = (current_player_index_2d + 1) % MAX_POLYPHONY
	
	player.stream = stream
	player.volume_db = volume_db + linear_to_db(master_volume * sfx_volume)
	player.pitch_scale = pitch_scale
	player.global_position = pos
	player.play()


# Играет глобальный звук (без позиции)
func _play_global_sound(stream: AudioStream, volume_db: float, pitch_scale: float) -> void:
	var player = audio_players[current_player_index]
	current_player_index = (current_player_index + 1) % MAX_POLYPHONY
	
	player.stream = stream
	player.volume_db = volume_db + linear_to_db(master_volume * sfx_volume)
	player.pitch_scale = pitch_scale
	player.play()

