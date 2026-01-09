extends Ability

var description: String
var icon: Texture2D

# SCOUT: Go For Ankles
# Active Ability: Melee Attack with strong debuff.
# Cost: 2 AP
# Cooldown: 3 Turns

func _init():
	display_name = "Go For Ankles"
	description = "[color=gold]Active Ability[/color]: Powerful melee attack (2 AP). Deals damage and applies [color=red]Slowed[/color] (-4 Mobility) and [color=red]Vulnerable[/color] (+15% Damage Taken)."
	ap_cost = 2
	cooldown_turns = 3
	icon = null
	# is_active = true

func execute(user, target, target_grid, grid_manager):
	# Distance Check (1.5)
	var dist = user.grid_pos.distance_to(target.grid_pos)
	if dist > 1.5:
		return "Target too far!"

	# Execute Attack (Hit Chance?)
	# Usually abilities hit automatically or have high hit chance. 
	# Let's use CombatResolver but force it or use custom logic?
	# Standard Ability logic:
	
	print(user.name, " uses Go For Ankles on ", target.name)
	
	# Apply Damage (Base Melee or Weapon?)
	var dmg = 3
	if user.primary_weapon:
		dmg = user.primary_weapon.damage 
	
	# Deal Damage
	if target.has_method("take_damage"):
		target.take_damage(dmg)
		
		# Apply Effects
		if target.has_method("apply_effect"):
			var slow = load("res://scripts/resources/statuses/SlowedStatus.gd").new()
			target.apply_effect(slow)
			var vuln = load("res://scripts/resources/statuses/VulnerableStatus.gd").new()
			target.apply_effect(vuln)
			
		if SignalBus:
			SignalBus.on_request_floating_text.emit(target.position, "ANKLES BITTEN!", Color.RED)
		
		# Start Cooldown
		start_cooldown()
		return "Used Go For Ankles"
	
	return "Invalid Target"

func get_valid_tiles(grid_manager, user) -> Array[Vector2]:
	var valid: Array[Vector2] = []
	# Adjacent enemies (1.5 tiles ~ Diagonals)
	if not grid_manager:
		return []

	var tree = grid_manager.get_tree()
	if not tree:
		return []

	for unit in tree.get_nodes_in_group("Units"):
		if is_instance_valid(unit) and unit != user and unit.get("faction") != user.get("faction") and unit.current_hp > 0:
			if unit.grid_pos.distance_to(user.grid_pos) <= 1.6: 
				valid.append(unit.grid_pos)
	return valid
