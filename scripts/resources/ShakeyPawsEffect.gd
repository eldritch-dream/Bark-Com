extends "res://scripts/resources/StatusEffect.gd"


func _init():
	display_name = "Shakey Paws"
	duration = 2


func on_apply(unit: Node):
	print(unit.name, " has Shakey Paws! Aim reduced by 20.")
	# Apply logic usually handled by stats check,
	# but we can modify the modifiers dictionary if Unit supports it.
	# Unit.gd has 'modifiers'.
	if "modifiers" in unit:
		if unit.modifiers.has("aim"):
			unit.modifiers["aim"] -= 20
		else:
			unit.modifiers["aim"] = -20

	SignalBus.on_request_floating_text.emit(
		unit.position + Vector3(0, 2, 0), "SHAKEY PAWS", Color.PURPLE
	)


func on_remove(unit: Node):
	print(unit.name, " recovered from Shakey Paws.")
	if "modifiers" in unit and unit.modifiers.has("aim"):
		unit.modifiers["aim"] += 20
