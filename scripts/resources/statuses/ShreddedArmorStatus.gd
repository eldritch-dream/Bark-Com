extends "res://scripts/resources/StatusEffect.gd"

func _init():
	display_name = "Shredded Armor"
	duration = 3 # Lasts for rest of mission usually, but let's give it a long duration or until healed? XCOM shred is permanent. 
	# User: "-2 flat armor min of 0"
	# If we want permanent, we might not use duration or set it high.
	# Let's start with 3 turns for now, or just implement on_apply with no revert in on_remove if it's permanent? 
	# StatusEffects generally imply temporary.
	# But "Shredded" implies physical damage. Let's make it last 99 turns.
	duration = 99
	type = EffectType.DEBUFF

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
