extends Ability
class_name PreventativeCareAbility


func _init():
	display_name = "Preventative Care"
	ap_cost = 1
	ability_range = 1.5  # Adjacent
	cooldown_turns = 3


func get_valid_tiles(grid_manager: GridManager, user) -> Array[Vector2]:
	var valid: Array[Vector2] = []
	for tile in grid_manager.grid_data.keys():
		if tile.distance_to(user.grid_pos) <= ability_range:
			valid.append(tile)
	return valid


func execute(user, target_unit, target_tile: Vector2, grid_manager: GridManager) -> String:
	if not user.spend_ap(ap_cost):
		return "Not enough AP!"

	if not target_unit:
		return "Must target a unit!"

	if target_unit.faction != user.faction:
		return "Can only buff allies!"

	SignalBus.on_combat_action_started.emit(user, target_unit, "Preventative Care", target_unit.position)

	print(user.name, " applies Preventative Care on ", target_unit.name)
	
	# Apply Status Effect (Armor Buff)
	# We need a status effect script for this or use a generic one if available.
	# Since we don't have a generic "BuffEffect", let's create one or look for one.
	# For now, I'll inline a new effect creation if possible, or assume a class exists.
	# Checking codebase, we have StunEffect. Let's create ArmorBuffEffect later or use a dictionary approach if Unit supports it?
	# Unit.gd `apply_effect` takes a StatusEffect.
	# I will create a simple internal class or a new file for the effect. 
	# Creating a new file is cleaner: scripts/resources/effects/ArmorBuffEffect.gd
	
	# For this step, I'll assume ArmorBuffEffect exists or I will create it. 
	# Let's create `res://scripts/resources/effects/ArmorBuffEffect.gd` separately.
	var effect_script = load("res://scripts/resources/effects/ArmorBuffEffect.gd")
	if effect_script:
		var effect = effect_script.new()
		effect.duration = 2
		effect.armor_bonus = 2
		target_unit.apply_effect(effect)
	else:
		print("ArmorBuffEffect script missing!")

	# Bond Growth
	if user.has_method("trigger_bond_growth") and target_unit != user:
		user.trigger_bond_growth(target_unit, 2)

	if GameManager and GameManager.audio_manager:
		GameManager.audio_manager.play_sfx("SFX_Buff") # Placeholder

	start_cooldown()
	SignalBus.on_combat_action_finished.emit(user)
	return "Buff Applied!"
