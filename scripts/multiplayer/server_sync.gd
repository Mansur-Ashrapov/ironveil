extends Node2D
class_name ServerSync
# Класс в котором создается тикер, каждый тик происходит синхронизация позиций персонажей и мобов

var tick_timer: Timer

func _ready():
	if multiplayer.is_server():
		tick_timer = Timer.new()
		tick_timer.wait_time = 1.0 / HighLevelMultiplayerHandler.TICKRATE
		tick_timer.autostart = true
		tick_timer.one_shot = false
		add_child(tick_timer)
