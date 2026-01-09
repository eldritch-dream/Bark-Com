extends Ability
class_name DisablingShotAbility

func _init():
	display_name = "Disabling Shot"
	ap_cost = 1 # Usually cheap or expensive? Stun is powerful. 
	# User didn't specify AP cost. 2 AP is standard for attacks.
	ap_cost = 2
	ability_range = 12
	cooldown_turns = 3

func get_valid_tiles(grid_manager: GridManager, user) -> Array[Vector2]:
	# Dynamic Range check based on Weapon if possible?
	var r = ability_range
	if user.get("primary_weapon"):
		r = max(r, user.primary_weapon.weapon_range)
		
	var valid: Array[Vector2] = []
	for tile in grid_manager.grid_data.keys():
		if tile.distance_to(user.grid_pos) <= r:
			valid.append(tile)
	return valid

func get_hit_chance_breakdown(grid_manager, user, target) -> Dictionary:
	# Use CombatResolver for base calculation (Standard Attack Logic)
	var CombatResolver = load("res://scripts/managers/CombatResolver.gd")
	var result = CombatResolver.calculate_hit_chance(user, target, grid_manager)
	return result

func execute(user, target_unit, target_tile: Vector2, grid_manager: GridManager) -> String:
	if not user.spend_ap(ap_cost):
		return "Not enough AP!"
		
	if not target_unit:
		return "Must target a unit!"

	SignalBus.on_combat_action_started.emit(user, target_unit, "Disabling Shot", target_unit.position)
	print(user.name, " fires Disabling Shot at ", target_unit.name)
	
	# Normal Hit mechanics? Or guaranteed for utility?
	# Standard XCOM: Has aim check but usually with small penalty or bonus.
	# Let's standard aim check.
	# Use CombatResolver for consistenct rules (Cover, Range, etc)
	var CombatResolver = load("res://scripts/managers/CombatResolver.gd")
	var hit_info = CombatResolver.calculate_hit_chance(user, target_unit, grid_manager)
	var hit_chance = hit_info["hit_chance"]
	
	var roll = randi() % 100 + 1
	
	print("Disabling Shot Roll: ", roll, " vs Chance: ", hit_chance)
	
	if roll <= hit_chance:
		# Visuals: Muzzle Flash (Match Standard Attack)
		SignalBus.on_request_vfx.emit(
			"MuzzleFlash",
			user.position + Vector3(0, 1, 0),
			Vector3.ZERO,
			user,
			target_unit.position
		)

		# Wait for "bullet travel" (Visual feel)
		await user.get_tree().create_timer(0.2).timeout

		# Hit. Deal Weapon Damage + Stun.
		var dmg = user.primary_weapon.damage
		if user.has_method("get_weapon_damage"):
			dmg = user.get_weapon_damage()
		target_unit.take_damage(dmg) # Base damage
		
		# VFX: Blood Splatter (Impact)
		SignalBus.on_request_vfx.emit(
			"BloodSplatter", target_unit.position + Vector3(0, 1, 0), Vector3.ZERO, target_unit, null
		)
		
		# Apply Stun
		var stun_res = load("res://scripts/resources/effects/StunEffect.gd")
		if stun_res:
			var stun = stun_res.new()
			target_unit.apply_effect(stun)
			print("Target STUNNED.")
			
	else:
		# MISS
		print("Disabling Shot MISSED!")
		SignalBus.on_request_floating_text.emit(target_unit.position, "MISS", Color.GRAY)
		
		# Audio: Miss
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Miss")

	start_cooldown()
	SignalBus.on_combat_action_finished.emit(user)
	return "Shot Fired"
