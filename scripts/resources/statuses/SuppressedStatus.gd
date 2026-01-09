extends StatusEffect

func _init():
	display_name = "Suppressed"
	description = "Mobility -4, Accuracy -20."
	duration = 1
	type = EffectType.DEBUFF
	icon = preload("res://assets/icons/status/suppressed.svg")

func on_apply(unit):
	# Apply Stat penalties
	# Handled via Unit.gd stat getters check for modifiers
	if not unit.modifiers.has("mobility"): unit.modifiers["mobility"] = 0
	unit.modifiers["mobility"] -= 4 # Significant slow
	
	if not unit.modifiers.has("accuracy"): unit.modifiers["accuracy"] = 0
	unit.modifiers["accuracy"] -= 20 # Aim penalty
	
	print(unit.name, " is SUPPRESSED! (-4 Mob, -20 Aim)")

func on_remove(unit):
	if unit.modifiers.has("mobility"):
		unit.modifiers["mobility"] += 4
	if unit.modifiers.has("accuracy"):
		unit.modifiers["accuracy"] += 20
	print(unit.name, " is no longer suppressed.")
