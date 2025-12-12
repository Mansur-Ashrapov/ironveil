extends MobBaseAnimationController
class_name BossAnimationController

# Анимации босса:
# - idle: бездействие/левитация
# - attack: первая ближняя атака
# - attack1: вторая ближняя атака (используется для специального удара)
# - skill: телепортация/подготовка к специальной атаке

var attack_index: int = 0  # Чередуем атаки для разнообразия


func play_idle() -> void:
	play_loop("idle")


func play_attack() -> void:
	# Чередуем между двумя атаками
	if attack_index == 0:
		play_once("attack")
	else:
		play_once("attack1")
	attack_index = (attack_index + 1) % 2


func play_attack1() -> void:
	# Специальная атака - всегда используем attack1
	play_once("attack1")


func play_skill() -> void:
	play_once("skill")


# Переопределяем для корректной работы с боссом
func change_to_idle(anim_name: String) -> void:
	# Не возвращаемся автоматически к idle после attack/attack1/skill
	# Это управляется логикой состояний босса
	if anim_name not in ["attack", "attack1", "skill"]:
		play_loop("idle")

