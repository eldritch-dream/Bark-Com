extends StatusEffect
class_name SlowedStatus

func _init():
	display_name = "Slowed"
	duration = 1
	type = EffectType.DEBUFF
	description = "Mobility -4."
	icon = preload("res://assets/icons/status/slowed.svg")

func on_apply(unit):
	if "modifiers" in unit:
		if not unit.modifiers.has("mobility"):
			unit.modifiers["mobility"] = 0
		unit.modifiers["mobility"] -= 4

	if SignalBus:
		SignalBus.on_request_floating_text.emit(unit.position + Vector3(0, 2, 0), "SLOWED", Color.ORANGE)

func on_remove(unit):
	if "modifiers" in unit and unit.modifiers.has("mobility"):
		unit.modifiers["mobility"] += 4

	if SignalBus:
		SignalBus.on_request_floating_text.emit(unit.position + Vector3(0, 2, 0), "Slowed Ended", Color.WHITE)
