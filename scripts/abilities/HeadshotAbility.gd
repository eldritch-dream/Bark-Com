extends Ability
class_name HeadshotAbility

func _init():
	display_name = "Headshot"
	ap_cost = 2
	ability_range = 10 # Long Range (Sniper base usually implies weapon range, but ability range overrides?)
	# Usually Snipers rely on Weapon Range. Ability usually shouldn't hardcode range if we want it to match weapon?
	# "ability_range" in base class is used for `get_valid_tiles`.
	# If we want Weapon Range:
	# Unit has `primary_weapon.weapon_range`. But we don't have access to user in _init.
	# We can update range in `on_turn_start` or `get_valid_tiles` dynamically?
	# Let's start with a high default since Snipers have long range.
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
	# Use CombatResolver for base calculation
	var CombatResolver = load("res://scripts/managers/CombatResolver.gd")
	var result = CombatResolver.calculate_hit_chance(user, target, grid_manager)
	
	# Apply Headshot Penalty
	var penalty = 20
	result["hit_chance"] = clamp(result["hit_chance"] - penalty, 0, 100)
	result["breakdown"] += " | Headshot: -" + str(penalty)
	
	return result

func execute(user, target_unit, target_tile: Vector2, grid_manager: GridManager) -> String:
	if not user.spend_ap(ap_cost):
		return "Not enough AP!"
		
	if not target_unit:
		return "Must target a unit!"

	# Aim Penalty Check
	# We need a way to roll for hit with penalty.
	# Unit.gd doesn't seem to expose a "calculate_hit_chance(target, modifier)" public helper easily for abilities to use?
	# Usually abilities are guaranteed or handle their own logic.
	# User request: "-20 Aim penalty to hit."
	
	# Current combat logic is often in CombatResolver? Or simplistic in Ability?
	# `GrenadeToss` had manual `roll >= hit_chance`.
	# We should probably use `CombatResolver` if it exists.
	# `Unit.gd` calls `CombatResolver.execute_item_effect`.
	# Let's check `CombatResolver` capabilities or implement manual roll.
	
	# Manual Roll with -20 Penalty
	var final_acc = 0
	
	# Better: Use the shared logic so execute matches preview
	if has_method("get_hit_chance_breakdown"):
		var info = get_hit_chance_breakdown(grid_manager, user, target_unit)
		final_acc = info["hit_chance"]
	else:
		# Fallback if method missing (shouldn't happen)
		final_acc = user.accuracy - 20
	
	var roll = randi() % 100 + 1
	
	SignalBus.on_combat_action_started.emit(user, target_unit, "Headshot", target_unit.position)
	print(user.name, " attempts Headshot on ", target_unit.name, " (Acc: ", final_acc, "%)")
	
	if roll <= final_acc:
		# Hit! 2x Damage
		var dmg = 0
		if user.has_method("get_weapon_damage"):
			dmg = user.get_weapon_damage() * 2
		else:
			# Fallback if Unit.gd update failed or unit is basic
			dmg = user.primary_weapon.damage * 2
		
		# Crit? (Sniper usually crits)
		if randi() % 100 < user.crit_chance:
			dmg += 2 # or multiplier
			print("CRITICAL HIT!")
			SignalBus.on_combat_log_event.emit("CRITICAL!", Color.RED)
			
		target_unit.take_damage(dmg)
		print("Headshot LANDED for ", dmg, " damage.")
		
		if VFXManager.instance:
			VFXManager.instance.spawn_projectile(user.position + Vector3(0,1.5,0), target_unit.position, "Bullet", func(): pass)
			
	else:
		print("Headshot MISSED!")
		SignalBus.on_combat_log_event.emit("MISS", Color.GRAY)
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Miss")

	start_cooldown()
	SignalBus.on_combat_action_finished.emit(user)
	return "Headshot Executed"
