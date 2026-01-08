extends Node

var is_owned: bool = false
var steam_app_id: int = 480 # Test game app id
var steam_id: int = 0
var steam_username: String = ""
var is_steam_initialized: bool = false

var lobby_id = 0
var lobby_max_members = 2

func _init():
	print("Init Steam")
	OS.set_environment("SteamAppId", str(steam_app_id))
	OS.set_environment("SteamGameId", str(steam_app_id))

func _ready():
	# Пробуем инициализировать Steam при запуске
	_try_init_steam()

func _process(_delta):
	# Вызываем callbacks только если Steam инициализирован
	if is_steam_initialized:
		Steam.run_callbacks()

## Пробует инициализировать Steam. Возвращает true если успешно.
func _try_init_steam() -> bool:
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("Steam init attempt: %s" % initialize_response)
	
	if initialize_response['status'] == 0:
		is_steam_initialized = true
		is_owned = Steam.isSubscribed()
		steam_id = Steam.getSteamID()
		steam_username = Steam.getPersonaName()
		print("Steam initialized! steam_id: %s, username: %s" % [steam_id, steam_username])
		return true
	else:
		print("Steam not available: %s" % initialize_response)
		is_steam_initialized = false
		return false

## Для обратной совместимости - вызывается из multiplayer_hud при нажатии Use Steam
func initialize_steam():
	if is_steam_initialized:
		return  # Уже инициализирован
	
	var success = _try_init_steam()
	if not success:
		print("Failed to init Steam!")
		# Не закрываем игру, позволяем пользователю выбрать действие
		return
	
	if is_owned == false:
		print("User does not own game!")
		# Не закрываем игру автоматически
