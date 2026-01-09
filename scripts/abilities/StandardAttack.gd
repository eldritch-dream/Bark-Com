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
	# Delegate to CombatResolver for centralized rules (Infinite Range, Falloff, etc)
	# CombatResolver.calculate_hit_chance handles all modifiers.
	return CombatResolver.calculate_hit_chance(user, target, grid_manager)


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
	# Placeholder execution if this is ever called directly
	print("StandardAttack Executed.")
	if user.has_method("spend_ap"):
		user.spend_ap(ap_cost)
	
	SignalBus.on_combat_action_finished.emit(user)
	return "Attack Initiated"
