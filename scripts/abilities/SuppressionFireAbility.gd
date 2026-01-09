extends "res://scripts/resources/Ability.gd"

var aoe_radius: float = 3.5

func _init():
	display_name = "Suppression Fire"
	ap_cost = 2
	ability_range = 10 
	cooldown_turns = 3
	
func execute(user, _target_unit, target_pos: Vector2, grid_manager) -> String:
	# AoE Suppression
	var world_pos = grid_manager.get_world_position(target_pos)
	# Convert Tile Radius to World Radius
	var world_radius = 3.5 * grid_manager.TILE_SIZE
	var units = grid_manager.get_units_in_radius_world(world_pos, world_radius) # Wide area
	
	if units.size() == 0:
		print("Suppression Fire hit nothing.") 
		# Still spends ammo/AP? Usually yes.
	
	for unit in units:
		if unit == user: continue # Don't suppress self
		
		# Apply Status
		var status = load("res://scripts/resources/statuses/SuppressedStatus.gd").new()
		unit.apply_effect(status)
		
		# Deal Chip Damage
		unit.take_damage(1) 
		SignalBus.on_request_floating_text.emit(unit.global_position + Vector3(0,2,0), "SUPPRESSED!", Color.ORANGE)
		print(user.name, " suppressed ", unit.name)
	
	user.spend_ap(ap_cost)
	start_cooldown()
	SignalBus.on_combat_action_finished.emit(user)
	return "SUPPRESSION"

func get_valid_tiles(grid_manager: GridManager, user) -> Array[Vector2]:
	# Return all tiles in range (Ground Target)
	var valid: Array[Vector2] = []
	var center = user.grid_pos
	var r = ability_range
	
	# Iterate Bounding Box for efficiency? Or iterate all grid?
	# Grid is 20x20 usually, so iteration is fast.
	# But better: -r to +r
	for x in range(center.x - r, center.x + r + 1):
		for y in range(center.y - r, center.y + r + 1):
			var tile = Vector2(x, y)
			if grid_manager.is_walkable(tile):
				# Euclidean or Manhattan? Usually Euclidean for shooting.
				if center.distance_to(tile) <= r:
					valid.append(tile)
	return valid
