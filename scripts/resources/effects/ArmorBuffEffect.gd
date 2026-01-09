extends StatusEffect
class_name ArmorBuffEffect


var armor_bonus: int = 2

func _init():
	display_name = "Armored"
	description = "+2 Armor."
	type = EffectType.BUFF
	duration = 2
	icon = preload("res://assets/icons/status/armor_buff.svg")


func on_apply(unit: Node):
	print("StatusEffect: ", unit.name, " gains +", armor_bonus, " Armor.")
	SignalBus.on_request_floating_text.emit(
		unit.position + Vector3(0, 2.5, 0), "+ARMOR", Color.CYAN
	)
	if unit.get("modifiers") != null:
		if not unit.modifiers.has("armor_change"):
			unit.modifiers["armor_change"] = 0
		unit.modifiers["armor_change"] += armor_bonus
		SignalBus.on_unit_stats_changed.emit(unit)


func on_remove(unit: Node):
	print("StatusEffect: ", unit.name, " loses Armor buff.")
	if unit.get("modifiers") != null and unit.modifiers.has("armor_change"):
		unit.modifiers["armor_change"] -= armor_bonus
		SignalBus.on_unit_stats_changed.emit(unit)
