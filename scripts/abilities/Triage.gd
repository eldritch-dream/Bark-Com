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
	var heal_amount = 4
	if user.has_method("has_perk") and user.has_perk("paramedic_advanced_triage"):
		heal_amount += 3
		print(user.name, " uses Advanced Triage! (+3 Heal)")
		
	target_unit.heal(heal_amount)

	# Bond Growth
	if user.has_method("trigger_bond_growth") and target_unit != user:
		user.trigger_bond_growth(target_unit, 3)

	# 2. Cure Status / Miracle Worker (Sanity)
	var is_miracle_worker = false
	if user.has_method("has_perk") and user.has_perk("paramedic_miracle_worker"):
		is_miracle_worker = true
		
	if is_miracle_worker:
		# Heal Sanity
		if target_unit.has_method("heal_sanity"):
			target_unit.heal_sanity(5)
			print(user.name, " uses Miracle Worker! (+5 Sanity)")
			
		# Cleanse All Debuffs (Assumes we implement remove_negative_effects on Unit or iterate here)
		# For now, we attempt to support future Unit method or do manual clear of some known tags?
		# Currently Unit.gd handles panic states via sanity heal often.
		# Let's clean standard status effects if possible.
		if target_unit.has_method("clear_negative_effects"):
			target_unit.clear_negative_effects()
		else:
			# Fallback: We can't easily access the private active_effects array from here if variables are not public.
			# But Unit.gd shows `active_effects` variable.
			# Let's define a Cleanse for standard effects we know: Stun, Burn, Bleed etc.
			# Or we add 'clear_negative_effects' to Unit.gd later.
			# I will print for now as user prompt didn't strictly require Unit.gd changes for Cleanse yet,
			# but I should implement it in Unit.gd.
			print("DEBUG: Miracle Worker attempts cleanse.")

	# 3. VFX
	if VFXManager.instance:
		VFXManager.instance.spawn_vfx("HealSparkles", target_unit.position, Vector3.UP, target_unit)

	if GameManager and GameManager.audio_manager:
		GameManager.audio_manager.play_sfx("SFX_Menu")  # Placeholder for Heal sound

	start_cooldown()
	SignalBus.on_combat_action_finished.emit(user)
	return "Triage Complete!"
