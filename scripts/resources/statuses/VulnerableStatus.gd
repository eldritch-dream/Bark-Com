extends StatusEffect
class_name VulnerableStatus

func _init():
	display_name = "Vulnerable"
	duration = 1
	type = EffectType.DEBUFF
	description = "Take +15% Damage."
	icon = preload("res://assets/icons/status/vulnerable.svg")

func on_apply(unit):
	if "modifiers" in unit:
		if not unit.modifiers.has("damage_taken_mult"):
			unit.modifiers["damage_taken_mult"] = 0.0
		unit.modifiers["damage_taken_mult"] += 0.15

	if SignalBus:
		SignalBus.on_request_floating_text.emit(unit.position + Vector3(0, 2, 0), "VULNERABLE", Color.MAGENTA)

func on_remove(unit):
	if "modifiers" in unit and unit.modifiers.has("damage_taken_mult"):
		unit.modifiers["damage_taken_mult"] -= 0.15

	if SignalBus:
		SignalBus.on_request_floating_text.emit(unit.position + Vector3(0, 2, 0), "Vulnerable Ended", Color.WHITE)
