extends Node2D
class_name BossKillzone

# Killzone для босса
# Управляет нанесением урона при ближних и специальных атаках

@export var melee_damage: float = 25.0
@export var special_damage: float = 60.0
@export var melee_range: float = 120.0

var boss: Boss


func _ready() -> void:
	boss = get_parent() as Boss
	
	if boss:
		melee_damage = boss.melee_damage
		special_damage = boss.special_damage
		melee_range = boss.melee_range


func deal_melee_damage(target: PlayerBase) -> void:
	if not multiplayer.is_server():
		return
	
	if target == null or not is_instance_valid(target):
		return
	
	var distance = global_position.distance_to(target.global_position)
	if distance <= melee_range:
		target.take_damage(melee_damage)
		_sync_sound.rpc("mob_attack")
		print("[BOSS KILLZONE] Melee damage dealt to: ", target.name, " | Damage: ", melee_damage)


func deal_special_damage(target: PlayerBase) -> void:
	if not multiplayer.is_server():
		return
	
	if target == null or not is_instance_valid(target):
		return
	
	# Специальная атака всегда попадает (телепорт к цели)
	target.take_damage(special_damage)
	_sync_sound.rpc("mob_attack")
	print("[BOSS KILLZONE] Special damage dealt to: ", target.name, " | Damage: ", special_damage)


func deal_area_damage(center: Vector2, radius: float, damage: float) -> void:
	if not multiplayer.is_server():
		return
	
	var players = get_tree().get_nodes_in_group("players")
	
	for player in players:
		if player is PlayerBase:
			var distance = center.distance_to(player.global_position)
			if distance <= radius:
				player.take_damage(damage)
				print("[BOSS KILLZONE] Area damage dealt to: ", player.name, " | Damage: ", damage)
	
	if players.size() > 0:
		_sync_sound.rpc("mob_attack")


# Синхронизация звуков на всех клиентах
@rpc("any_peer", "reliable", "call_local")
func _sync_sound(sound_key: String) -> void:
	SoundManager.play_sound(sound_key, global_position)

