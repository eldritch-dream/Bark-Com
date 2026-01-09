extends StatusEffect
class_name DisorientedEffect

var aim_penalty: int = 20

func _init():
	display_name = "Disoriented"
	description = "-20 Aim."
	type = EffectType.DEBUFF
	duration = 1 # 1 Turn
	icon = preload("res://assets/icons/status/disoriented.svg")

func on_apply(unit: Node):
	print("StatusEffect: ", unit.name, " is Disoriented!")
	SignalBus.on_request_floating_text.emit(
		unit.position + Vector3(0, 2.5, 0), "DISORIENTED", Color.ORANGE
	)
	if unit.get("modifiers") != null:
		if not unit.modifiers.has("accuracy"):
			unit.modifiers["accuracy"] = 0
		unit.modifiers["accuracy"] -= aim_penalty
		SignalBus.on_unit_stats_changed.emit(unit)

func on_remove(unit: Node):
	print("StatusEffect: ", unit.name, " recovers from disorientation.")
	if unit.get("modifiers") != null and unit.modifiers.has("accuracy"):
		unit.modifiers["accuracy"] += aim_penalty
		SignalBus.on_unit_stats_changed.emit(unit)
