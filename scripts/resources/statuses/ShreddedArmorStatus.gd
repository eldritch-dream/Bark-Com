extends StatusEffect

func _init():
	display_name = "Shredded Armor"
	description = "Armor reduced by 2."
	duration = 99
	type = EffectType.DEBUFF
	icon = preload("res://assets/icons/status/shredded_armor.svg")

func on_apply(unit):
	if not unit.modifiers.has("armor_change"): unit.modifiers["armor_change"] = 0
	unit.modifiers["armor_change"] -= 2
	print(unit.name, " armor SHREDDED! (-2 Armor)")

func on_remove(unit):
	# If it's permanent, we don't restore it. But status usually cleans up.
	# If we want it permanent, we should probably change the base 'armor' stat directly in RocketLauncher
	# instead of using a status.
	# However, user asked for "debuff".
	# If healed, maybe we restore?
	# For now, let's revert it on remove so it behaves like a status.
	if unit.modifiers.has("armor_change"):
		unit.modifiers["armor_change"] += 2
	print(unit.name, " armor restored.")
