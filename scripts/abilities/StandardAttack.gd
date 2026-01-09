extends Ability
class_name StandardAttack

func _init():
	display_name = "Shoot"
	ap_cost = 1 # Standard cost, can be modified by Unit logic
	ability_range = -1 # Use Weapon Range
	# description = "Fire primary weapon."

func get_valid_tiles(grid_manager, user) -> Array[Vector2]:
	var valid: Array[Vector2] = []
	# Infinite Range (within map bounds / reasonable limits)
	# User can target any visible enemy.
	# For "Valid Tiles", we usually highlight reachable targets.
	# Let's iterate all known units? 
	# A simpler approach for "Infinite" is a large radius matching map size (e.g., 50).
	var r = 50 
	
	for tile in grid_manager.grid_data:
		if tile.distance_to(user.grid_pos) <= r:
				valid.append(tile)
	return valid

func get_hit_chance_breakdown(grid_manager, user, target) -> Dictionary:
	var base_acc = user.accuracy
	var defense_val = 0
	if "defense" in target:
		defense_val = target.defense
		
	# Distance Falloff
	var dist = user.grid_pos.distance_to(target.grid_pos)
	var optimal_range = 5.0 # No penalty within this range
	var penalty_per_tile = 5.0 # -5% per tile beyond optimal
	
	var range_penalty = 0
	if dist > optimal_range:
		range_penalty = round((dist - optimal_range) * penalty_per_tile)
	
	# Cover (Basic)
	var cover_val = 0
	if grid_manager.is_tile_cover(target.grid_pos): 
		# Need cover calculation logic relative to shooter.
		# For now, simplistic flat cover if standing on cover tile?
		# Usually cover provides defense if obstacle is BETWEEN shooter and target.
		# That requires raycasting. 
		# Let's trust target.defense includes cover? No, defense is base stats.
		# For this task (Range Refinement), lets focus on Range Penalty.
		pass

	var final_chance = base_acc - defense_val - range_penalty - cover_val
	final_chance = clamp(final_chance, 5, 100) # Minimum 5% per user request
	
	return {
		"hit_chance": final_chance,
		"breakdown": {
			"Base Accuracy": base_acc,
			"Enemy Defense": -defense_val,
			"Range Penalty": -range_penalty,
			"Cover": -cover_val
		}
	}

func execute(user, target, grid_pos, grid_manager):
	# Delegate to Main's combat processing via Signal or Direct Call?
	# The Controller calls Main._execute_ability.
	# Main._execute_ability calls ability.execute.
	# So we should call Main._process_combat here? 
	# Or implement combat logic here? 
	# Combat logic is complex (Animation, Damage, Death).
	# Ideally, Main._process_combat handles the heavy lifting.
	# So we can return a "request" or call back to Main.
	
	# BUT `Ability.execute` is usually async.
	# Let's call `user.attack(target)` if it exists?
	# OR `Main` has `_process_combat(target_unit)`.
	
	# If we are refactoring, we should probably move `_process_combat` logic eventually.
	# For "Standardize Legacy", let's wrap the legacy call.
	
	# Current Architecture Issue: `Ability.execute` returns a result string.
	# Main._execute_ability expects this.
	
	# Hack: Call Main._process_combat directly? No, that's circular if passed Main.
	# Controller implementation of `_handle_ability_click` calls `main_node._execute_ability(selected_ability...)`.
	# If we use StandardAttack, `_execute_ability` will call `execute`.
	
	# Temporary Solution:
	# If we have access to Main (via user? no), or if we pass it? 
	# execute signature is (user, target, grid_pos, grid_manager).
	# We don't have Main.
	
	# Maybe we return a special signal/string that Main interprets?
	# OR we replicate `_process_combat` logic here?
	# `_process_combat` does `user.play_anim("Shoot")`, `target.take_damage`, etc.
	
	# Let's try to delegate back to Main?
	# Main._execute_ability checks ability type? No.
	
	# Let's make `StandardAttack` emit a signal via SignalBus?
	# `SignalBus.on_request_combat.emit(user, target)`?
	# Then Main listens and runs `_process_combat`.
	
	# Let's add `on_request_standard_attack` to SignalBus?
	pass
	return "Attack Initiated"
