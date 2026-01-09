extends StatusEffect
class_name SitStayStatus

func _init():
	display_name = "Sit & Stay"
	duration = 1
	type = EffectType.BUFF
	description = "Defense +20."
	icon = preload("res://assets/icons/status/sit_stay.svg")

func on_apply(unit):
	# Apply Defense Bonus
	if "defense" in unit:
		unit.defense += 20
		
	# Visual feedback
	if SignalBus:
		SignalBus.on_request_floating_text.emit(unit.position + Vector3(0, 2, 0), "SIT & STAY", Color.CYAN)

func on_remove(unit):
	# Revert Defense Bonus
	if "defense" in unit:
		unit.defense -= 20

	if SignalBus:
		SignalBus.on_request_floating_text.emit(unit.position + Vector3(0, 2, 0), "Sit & Stay Ended", Color.WHITE)
