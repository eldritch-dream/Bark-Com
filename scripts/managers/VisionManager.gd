extends Node3D
class_name VisionManager

# References
var grid_manager: GridManager
var grid_visualizer: Node  # Type checking loose to avoid cyclic dep if not careful, but generally GridVisualizer class
var units: Array = []

# State
var visible_tiles: Dictionary = {}  # coord: Vector2 -> bool
var explored_tiles: Dictionary = {}  # coord: Vector2 -> bool (Persistent)
var known_enemies: Dictionary = {}  # unit: EnemyUnit -> bool (true if currently seen)


func initialize(gm: GridManager, gv: Node):
	grid_manager = gm
	grid_visualizer = gv


func update_vision(all_units: Array):
	units = all_units
	visible_tiles.clear()
	known_enemies.clear()

	# Reset Visualizer (Hide everything, or set to Fogged)
	# For prototype: Hide everything first, then reveal.
	# But we want "explored" vs "active".
	# Let's simplify:
	# 1. Reset Visualizer (Hide everything by default, we will reveal incrementally)
	grid_visualizer.reset_vision()

	# 2. Reset all Enemies to invisible.
	for unit in units:
		if is_instance_valid(unit) and "faction" in unit and unit.faction == "Enemy":
			unit.visible = false

	# 3. Calculate Player Vision (Current)
	var player_units = units.filter(
		func(u): return is_instance_valid(u) and "faction" in u and u.faction == "Player"
	)

	for unit in player_units:
		_process_unit_vision(unit)

	# 3b. Mark current visible as explored
	for coord in visible_tiles:
		explored_tiles[coord] = true

	# 4. Render Tiles
	# First, render all confirmed explored tiles as Fogged
	for coord in explored_tiles:
		grid_visualizer.reveal_fogged(coord)

	# Then, render currently visible tiles as Bright (Overwrites Fogged)
	for coord in visible_tiles:
		grid_visualizer.reveal_visible(coord)

	# 5. Check Enemy Visibility
	_check_enemy_visibility(player_units)

	# 6. Check Prop Visibility (Barrels, etc)
	# Hide destructibles if not clearly visible (No "Ghost" mode for barrels yet)
	var props = get_tree().get_nodes_in_group("Destructible")
	# print("VisionManager: Found ", props.size(), " destructibles.")
	for p in props:
		var prop = p
		if p is StaticBody3D:
			prop = p.get_parent()
		
		if is_instance_valid(prop) and "grid_pos" in prop:
			# STRICT VISION: Only show if currently in visible_tiles OR explored
			# User request: "remain visible (but with fog vfx applied) after being seen"
			# STRICT VISION: Only show if currently in visible_tiles OR explored
			# FIX: Also toggle collision so hidden props don't block clicks
			var collider = p if p is CollisionObject3D else null
			
			if visible_tiles.has(prop.grid_pos) or explored_tiles.has(prop.grid_pos):
				prop.visible = true
				if collider: collider.collision_layer = 1
			else:
				prop.visible = false
				if collider: collider.collision_layer = 2 # Move to Layer 2 (Hidden)



func _process_unit_vision(unit):
	var start_pos = unit.position + Vector3(0, 0.5, 0)  # Eye level

	# Iterate tiles in bounding box of range
	var center = unit.grid_pos
	var r = unit.vision_range

	for x in range(center.x - r, center.x + r + 1):
		for y in range(center.y - r, center.y + r + 1):
			var coord = Vector2(x, y)
			if not grid_manager.grid_data.has(coord):
				continue

			if visible_tiles.has(coord):
				continue  # Already seen by another unit

			# Check Distance
			var dist = center.distance_to(coord)
			if dist > r:
				continue

			# Logic: Always see neighbors (Radius 1.5 covers diagonals 1.414)
			if dist <= 1.5:
				visible_tiles[coord] = true
				continue

			# Check LOS for further tiles
			var tile_pos = grid_manager.get_world_position(coord) + Vector3(0, 1.0, 0)  # Lower target to 1.0
			if _has_line_of_sight(start_pos, tile_pos, [unit]):
				visible_tiles[coord] = true


func _check_enemy_visibility(player_units: Array):
	var enemies = units.filter(
		func(u): return is_instance_valid(u) and "faction" in u and u.faction == "Enemy"
	)

	for enemy in enemies:
		var is_seen = false
		var is_smelled = false

		var enemy_center = enemy.position + Vector3(0, 0.5, 0)

		for player in player_units:
			# Check Visual Range
			var dist = player.grid_pos.distance_to(enemy.grid_pos)

			if dist <= player.vision_range:
				# Check Raycast
				var player_eye = player.position + Vector3(0, 1.5, 0)
				if _has_line_of_sight(
					player_eye, enemy_center + Vector3(0, 1.0, 0), [player, enemy]
				):
					is_seen = true
					break  # Seen by at least one

			# Check Smell Range
			if not is_seen and dist <= player.smell_range:
				is_smelled = true

		# print("DEBUG VISION RESULT: Seen=", is_seen, " Smelled=", is_smelled)

		if is_seen:
			enemy.visible = true
			enemy.set_visual_mode("NORMAL")
			known_enemies[enemy] = true

			# Sanity Stressor: Seeing an Enemy
			# Check if we should trigger horror
			for player in player_units:
				if player.has_method("on_seen_enemy"):
					# Player sees enemy this turn?
					# Double check LOS for THIS player to THIS enemy
					# We already checked dist and LOS in the inner loop (lines 92-100)
					# But wait, lines 92-100 check if ANY player sees the enemy.
					# We want specific players who see the enemy to take stress.
					# We need to do this check INSIDE the loop or re-check.

					# Re-check specific visibility
					var dist = player.grid_pos.distance_to(enemy.grid_pos)
					if dist <= player.vision_range:
						var player_eye = player.position + Vector3(0, 1.5, 0)
						if _has_line_of_sight(
							player_eye, enemy_center + Vector3(0, 1.0, 0), [player, enemy]
						):
							player.on_seen_enemy(enemy)

		elif is_smelled:
			# Show as Ghost/Blip
			enemy.visible = true
			enemy.set_visual_mode("GHOST")
			print("Smelled enemy at ", enemy.grid_pos)

		else:
			enemy.visible = false


func _has_line_of_sight(from: Vector3, to: Vector3, exclude: Array) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]  # Exclude self just in case

	var exclude_rids = []
	for ex in exclude:
		if ex is CollisionObject3D:
			exclude_rids.append(ex.get_rid())
	query.exclude = exclude_rids

	var result = space_state.intersect_ray(query)

	if result:
		# We hit something. Checking if it's the target or an obstruction.
		# Since we are casting to the center of a tile, and walls are ON the tile,
		# hitting the wall means we see it.

		# Check distance from hit point to target point.
		# Tile size is ~2.0. Center to face is ~1.0. Diagonal ~1.5.
		var dist_to_target = result.position.distance_to(to)

		if dist_to_target < 1.5:
			# We hit the target (or something very close to its center)
			return true
		else:
			# We hit something far away from the target -> Obstruction.
			# print("LOS Blocked by ", result.collider.name, " at ", result.position)
			return false

	return true
