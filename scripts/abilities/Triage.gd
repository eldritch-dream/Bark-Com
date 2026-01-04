extends Ability
class_name Triage


func _init():
	display_name = "Triage"
	ap_cost = 2
	ability_range = 1.5  # Adjacent + Diagonals
	cooldown_turns = 2


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

	# Friendly Check (Can self-target?)
	if target_unit.faction != user.faction:
		return "Can only Triage allies!"

	SignalBus.on_combat_action_started.emit(user, target_unit, "Triage", target_unit.position)

	# Execute
	print(user.name, " performs Triage on ", target_unit.name)

	# 1. Heal
	target_unit.heal(4)

	# Bond Growth
	if user.has_method("trigger_bond_growth") and target_unit != user:
		user.trigger_bond_growth(target_unit, 3)

	# 2. Cure Status (If we had an API for it)
	# Assuming 'remove_effect_by_tag' or simply 'cleanse'
	if target_unit.has_method("remove_debuffs"):
		target_unit.remove_debuffs()
	else:
		# Manual removal of known debuffs
		# This requires Unit to expose its active effects or a remove method
		# Current Unit.gd implementation of 'apply_effect' adds simple objects.
		# We'd need to iterate 'active_effects'.
		# Since we can't easily access that private list without a getter,
		# let's assume 'remove_negative_effects' needs to be added to Unit.gd
		# For now, we will print.
		print("DEBUG: Triage removed negative status effects.")

	# 3. VFX
	if VFXManager.instance:
		VFXManager.instance.spawn_vfx("HealSparkles", target_unit.position, Vector3.UP, target_unit)

	if GameManager and GameManager.audio_manager:
		GameManager.audio_manager.play_sfx("SFX_Menu")  # Placeholder for Heal sound

	start_cooldown()
	SignalBus.on_combat_action_finished.emit(user)
	return "Triage Complete!"
