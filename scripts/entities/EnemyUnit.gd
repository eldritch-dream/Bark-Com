extends Unit
class_name EnemyUnit

signal action_complete

const EnemyDataScript = preload("res://scripts/resources/EnemyData.gd")

enum State { IDLE, CHASE, ATTACK }

const DEBUG_AI = false

var state = State.IDLE
var target_unit = null
var victim_log: Array[String] = []

# Data & config
var enemy_data: EnemyData
var attack_range: int = 4


func _ready():
	super._ready()
	faction = "Enemy"
	name = "Eldritch Beast"

	# Visuals: Red Cube
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mesh.material_override = mat
	mesh.name = "Mesh"  # Renamed from "MeshInstance3D" for Unit.gd animation compatibility
	# Adjust position (Box origin is center)
	mesh.position.y = 0.5
	add_child(mesh)

	# Debug Label
	var label = Label3D.new()
	label.name = "Label3D"
	label.text = "BEAST"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.8
	label.font_size = 32
	add_child(label)

	# Collider (For Mouse Interaction)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	col.shape = shape
	col.position.y = 0.5
	add_child(col)


func initialize_from_data(data: EnemyData):
	enemy_data = data
	name = data.display_name

	# Apply Stats
	max_hp = data.max_hp
	current_hp = data.max_hp
	mobility = data.mobility

	if data.primary_weapon:
		primary_weapon = data.primary_weapon
		attack_range = primary_weapon.weapon_range
	else:
		attack_range = 4  # Default

	# Apply Visuals
	var mesh = get_node_or_null("Mesh")
	if mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = data.visual_color
		mesh.material_override = mat

	var label = get_node_or_null("Label3D")
	if label:
		label.text = data.display_name.to_upper()
		label.modulate = data.visual_color

	# Apply Abilities
	for script_res in data.abilities:
		if script_res:
			abilities.append(script_res.new())

	if DEBUG_AI:
		print("Initialized ", name, " with behavior ", data.ai_behavior)


func _end_action():
	print(name, " [AI] Emitting action_complete signal.")
	action_complete.emit()


# AI Logic
func decide_action(_all_units: Array, grid_manager: GridManager):
	# ASYNC GUARD: Ensure we yield so TurnManager can set up listeners
	await get_tree().process_frame

	# DEBUG: Verify Turn State
	var tm = get_tree().get_first_node_in_group("TurnManager")
	var turn_state_str = "UNKNOWN"
	if tm:
		turn_state_str = str(tm.current_turn)
	print("ENEMY AI: ", name, " deciding acton. TM State: ", turn_state_str, " (Should be 1/ENEMY)")

	if DEBUG_AI:
		print(name, " is deciding action...")
	
	# Refresh Pathfinding logic to include units as obstacles
	grid_manager.refresh_pathfinding(_all_units, self)

	# Clear previous debug
	var gv = get_node("../GridVisualizer")
	if gv:
		gv.clear_debug_scores()

	# 1. Acquire Target
	target_unit = null
	var best_target_score = -9999.0
	var candidates = []  # List of {unit, score}

	# Pass 1: Score all valid targets
	for unit in _all_units:
		if (
			is_instance_valid(unit)
			and "faction" in unit
			and unit.faction == "Player"
			and unit.current_hp > 0
			and not unit.is_dead
		):
			# Ignore Neutrals (e.g. Objectives) unless specifically aggressive?
			# User Request: "The ai should not target the treat bag or the human"
			if (
				unit.has_method("get_type")
				and (unit.name == "Treat Bag" or unit.name == "Lost Human")
			):
				continue

			var score = _evaluate_target_priority(unit, grid_manager)
			candidates.append({"unit": unit, "score": score})
			if score > best_target_score:
				best_target_score = score

	# Pass 1b: Score Objectives (Golden Hydrant) -> DISABLED FOR NOW per User Request
	# var objectives = get_tree().get_nodes_in_group("Objectives")
	# ...

	# Pass 1b: Score Objectives (Golden Hydrant)
	var objectives = get_tree().get_nodes_in_group("Objectives")
	for obj in objectives:
		if is_instance_valid(obj) and obj.current_hp > 0:
			# Respect can_be_targeted flag if present (e.g. Treat Bag)
			if "can_be_targeted" in obj and not obj.can_be_targeted:
				continue

			var score = _evaluate_target_priority(obj, grid_manager)
			candidates.append({"unit": obj, "score": score})
			if score > best_target_score:
				best_target_score = score

	# Pass 2: Collect best candidates (within small epsilon for float precision, or exact)
	var best_candidates = []
	for c in candidates:
		if c["score"] >= (best_target_score - 0.1):
			best_candidates.append(c["unit"])

	if best_candidates.size() > 0:
		target_unit = best_candidates.pick_random()

	if not target_unit:
		state = State.IDLE
		if DEBUG_AI:
			print(" - No valid targets. Returning to IDLE.")
		_end_action()
		return

	if DEBUG_AI:
		print(
			" - Target acquired: ",
			target_unit.name,
			" (Score: ",
			best_target_score,
			" | Candidates: ",
			best_candidates.size(),
			")"
		)

	# 2. Tactical Movement (Utility AI)
	var tiles = get_reachable_tiles(grid_manager)
	if DEBUG_AI:
		print(" - Analyzing ", tiles.size(), " reachable tiles.")

	var best_tile = grid_pos
	var best_score = -9999.0

	for tile in tiles:
		# SKIP OCCUPIED TILES (Exclude self)
		if tile != grid_pos and is_tile_occupied(tile, _all_units):
			continue

		var score = evaluate_tile(tile, target_unit, grid_manager)
		if gv:
			gv.show_debug_score(tile, score)  # Debug Visuals

		if score > best_score:
			best_score = score
			best_tile = tile

	if DEBUG_AI:
		print(" - Best Tile: ", best_tile, " Score: ", best_score)

	# Fallback Logic: If stuck locally and out of range, try long-distance path
	if best_tile == grid_pos and grid_pos.distance_to(target_unit.grid_pos) > float(attack_range):
		if DEBUG_AI:
			print(" - Stuck locally. Attempting long-distance pathfinding...")
		var long_move = get_long_distance_move(target_unit, grid_manager)
		if long_move != grid_pos:
			best_tile = long_move
			if DEBUG_AI:
				print(" - Long Distance Move Found: ", best_tile)

	# Debug Visual
	if gv:
		var target_loc = grid_manager.get_world_position(best_tile)
		gv.draw_ai_intent(position, target_loc, Color.RED)

	# Move to best tile if different
	if best_tile != grid_pos:
		# Use AStar Pathfinding to get there!
		# 1. Get Path
		var path = grid_manager.get_move_path(grid_pos, best_tile)

		if path.size() > 0:
			# 2. Convert to World Points
			var world_path: Array[Vector3] = []
			var grid_subset: Array[Vector2] = []
			# Skip current pos index 0
			for i in range(1, path.size()):
				world_path.append(grid_manager.get_world_position(path[i]))
				grid_subset.append(path[i])

			# 3. Execute
			# grid_pos = best_tile # Removed immediate assignment
			print(name, " [AI] Moving along path... (Length: ", world_path.size(), ")")
			move_along_path(world_path, grid_subset)

			# WAIT FOR MOVEMENT
			print(name, " [AI] Awaiting movement_finished...")
			await movement_finished
			print(name, " [AI] Movement finished!")

			# check death (e.g. Overwatch kill)
			if current_hp <= 0:
				print(name, " [AI] Died during movement.")
				_end_action()
				return  # Stop AI if we died moving

		# Update Vision immediately so player sees them enter LOS
		var vm = get_node("../VisionManager")
		if vm:
			vm.update_vision(_all_units)

	# 3. Attack if possible
	if is_instance_valid(target_unit):
		var dist = grid_pos.distance_to(target_unit.grid_pos)
		if dist <= float(attack_range):  # Use dynamic variable
			if DEBUG_AI:
				print(" - Attacking from position.")
			attack_target(grid_manager)

			# WAIT FOR ATTACK ANIMATION/SPLA T
			print(name, " [AI] Attacking/Waiting...")
			await get_tree().create_timer(1.0).timeout
			print(name, " [AI] Attack sequence done.")
		else:
			if DEBUG_AI:
				print(" - Target out of range.")
	else:
		state = State.IDLE
		if DEBUG_AI:
			print(" - No Target to attack. Ending turn.")
	
	print(name, " [AI] decide_action COMPLETE.")
	_end_action()


func get_reachable_tiles(gm: GridManager) -> Array:
	var reachable = []
	var queue = []
	var visited = {}

	queue.append({"pos": grid_pos, "dist": 0})
	visited[grid_pos] = true
	reachable.append(grid_pos)  # Can stay put

	while queue.size() > 0:
		var current = queue.pop_front()
		var c_pos = current["pos"]
		var c_dist = current["dist"]

		if c_dist >= mobility:
			continue

		# Neighbors (4-way)
		var neighbors = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
		for n in neighbors:
			var next_pos = c_pos + n
			# Use AStar solid check (dynamic) instead of is_walkable (static)
			if not visited.has(next_pos) and gm.grid_data.has(next_pos):  # Basic bounds check
				if not gm.is_tile_blocked(next_pos):
					visited[next_pos] = true
					reachable.append(next_pos)
					queue.append({"pos": next_pos, "dist": c_dist + 1})

	return reachable


func _evaluate_target_priority(target, gm: GridManager) -> float:
	var score = 0.0

	# 1. Distance (Closer is better usually, saves Action Points)
	# Penalize distance heavily to prevent running across map for slightly better hit
	var dist = grid_pos.distance_to(target.grid_pos)
	score -= (dist * 2.0)

	# 2. Hit Chance (Can I hit them?)
	# We simulate the hit chance from CURRENT position
	var combat_data = CombatResolver.calculate_hit_chance(self, target, gm, grid_pos)
	var hit_chance = combat_data["hit_chance"]
	score += hit_chance  # Directly add hit chance (0-100)

	# 3. Flanking Bonus
	if hit_chance > 80:
		score += 20
	if combat_data.get("flanked", false):
		score += 30

	# 4. Lethality (Can I kill/panic them?)
	if target.current_hp <= 4:
		score += 50  # Execution bonus

	# 5. Fear/Threat (Original logic, simplified) - Only for Units
	if target.has_method("get_fear_level"):
		var fear = target.get_fear_level()
		score += (fear * 0.5)

	# 6. Objective Priority
	if target.is_in_group("Objectives"):
		score += 30.0  # Prioritize, but distraction/survival still matters

	# 6. Randomness (REMOVED - Handled by Candidate Selection)
	# score += randf_range(0, 5.0)

	return score


func evaluate_tile(tile: Vector2, target, gm: GridManager) -> float:
	var base_score = 0.0

	if not enemy_data:
		base_score = _evaluate_generic(tile, target, gm)
	else:
		match enemy_data.ai_behavior:
			EnemyDataScript.AIBehavior.RUSHER:
				base_score = _evaluate_rusher(tile, target, gm)
			EnemyDataScript.AIBehavior.SNIPER:
				base_score = _evaluate_sniper(tile, target, gm)
			_:
				base_score = _evaluate_generic(tile, target, gm)

	# HAZARD CHECK
	base_score += _get_hazard_penalty(tile, gm)

	return base_score


func _get_hazard_penalty(tile: Vector2, gm: GridManager) -> float:
	var penalty = 0.0
	var props = get_tree().get_nodes_in_group("Destructible")
	for p in props:
		if is_instance_valid(p) and p.get("is_burning"):
			var dist = tile.distance_to(p.grid_pos)
			if dist <= 3.5:  # Inside Blast Radius (approx 3)
				penalty -= 500.0  # RUN AWAY!
	return penalty


func _get_self_preservation_score(tile: Vector2, target, gm: GridManager) -> float:
	# Bonus for Safety if Low HP
	if current_hp > (max_hp * 0.3):
		return 0.0  # Brave enough

	var score = 0.0
	var dist = tile.distance_to(target.grid_pos)

	# 1. Run Away
	score += (dist * 10.0)

	# 2. Break Line of Sight (Hide)
	if not _check_los(tile, target, gm):
		score += 500.0  # Massive bonus to hide

	# 3. Seek Cover (if can't hide)
	var cover = CombatResolver.get_cover_height_at_pos(tile, target.grid_pos, gm)
	score += (cover * 50.0)

	return score


func _evaluate_generic(tile: Vector2, target, gm: GridManager) -> float:
	var score = 0.0

	# Self Preservation Mod
	score += _get_self_preservation_score(tile, target, gm)

	# A. Distance logic
	var ideal = 4
	var dist = tile.distance_to(target.grid_pos)
	var deviation = abs(dist - ideal)
	score -= (deviation * 5.0)

	# B. Defensive Cover
	var cover_h = CombatResolver.get_cover_height_at_pos(tile, target.grid_pos, gm)
	if cover_h >= 2.0:
		score += 30.0
	elif cover_h >= 1.0:
		score += 15.0

	# C. Flanking
	var target_cover_h = CombatResolver.get_cover_height_at_pos(target.grid_pos, tile, gm)
	if target_cover_h <= 0.0:
		score += 30.0
		# If flanking but no LOS, penalty
		if not _check_los(tile, target, gm):
			score -= 20.0
	else:
		# If no flank and no LOS, penalty depends on distance
		if not _check_los(tile, target, gm):
			if dist < 4:
				score -= 100.0  # Must see target at close range
			else:
				score -= 20.0  # Okay to lose sight while maneuvering far away

	# D. Hit Chance
	var combat_data = CombatResolver.calculate_hit_chance(self, target, gm, tile)
	var hit_chance = combat_data["hit_chance"]
	if hit_chance >= 50:
		score += (hit_chance * 0.5)
	elif hit_chance < 30:
		score -= 20.0

	return score


func _evaluate_rusher(tile: Vector2, target, gm: GridManager) -> float:
	var score = 0.0

	# Panic Check (Even rushers fear death)
	var preservation = _get_self_preservation_score(tile, target, gm)
	if preservation > 0:
		# Rushers are brave, but not stupid. Half panic score.
		score += (preservation * 0.5)

	# A. Aggression (Adjacency)
	var dist = tile.distance_to(target.grid_pos)

	# Goal: Dist 1.0
	# Penalty for distance
	score -= (dist * 10.0)

	if dist < 1.5:
		score += 200.0  # Massive bonus for biting range

	# Fallback: If we are stuck (Best tile is current tile, but we aren't in range)
	# We should penalize staying put if we aren't in range!
	if dist > 1.5 and tile == grid_pos:
		score -= 50.0  # Discourage standing still if not in range

	# B. Ignore Cover for Self (Beserker)
	# But Value Flanking! (Target has NO cover from me)
	var target_cover_h = CombatResolver.get_cover_height_at_pos(target.grid_pos, tile, gm)
	if target_cover_h <= 0.0:
		score += 30.0

	# C. LOS Check (Rushers smell their prey, LOS is less important than distance)
	if not _check_los(tile, target, gm):
		score -= 5.0  # Reduced from 50.0 to prevent getting stuck at corners

	return score


func get_long_distance_move(target, gm: GridManager) -> Vector2:
	# Path to target ignoring mobility limit
	var path = gm.get_move_path(grid_pos, target.grid_pos)
	if path.size() > 1:
		# Extract point efficiently
		var limit = min(path.size() - 1, mobility)
		# However, get_move_path returns World Positions or Grid Coords?
		# GridManager typically returns Grid Coords in AStar path.
		# Let's verify GridManager's get_move_path return type.
		# Assuming it returns Array[Vector2] (Grid Coords).

		# If path includes target (last point), we stop before target?
		# path[0] is start. path[limit] is destination for this turn.
		var dest = path[limit]

		# 3. Check for valid destination
		# Backtrack until we find a clear tile
		while limit > 0:
			var candidate = path[limit]
			# Check dynamic occupancy AND static blockage
			if not gm.is_tile_blocked(candidate):
				# Double check unit list just in case (GridManager might not update instantly?)
				if not _is_tile_occupied(candidate, gm):
					return candidate
			limit -= 1

	return grid_pos  # Stay put if failed


func _is_tile_occupied(tile: Vector2, gm: GridManager) -> bool:
	# Simple check against unit positions
	# ( Ideally GridManager has this, but helper here works)
	var units = get_tree().get_nodes_in_group("Units")
	for u in units:
		if u.grid_pos == tile and u != self and u.current_hp > 0:
			return true
	return false


func _evaluate_sniper(tile: Vector2, target, gm: GridManager) -> float:
	var score = 0.0

	# Extreme Self Preservation
	var preservation = _get_self_preservation_score(tile, target, gm)
	if preservation > 0:
		score += (preservation * 2.0)  # Cowardly

	# A. Range Goldilocks Zone (8-12)
	var dist = tile.distance_to(target.grid_pos)
	if dist >= 8 and dist <= 12:
		score += 50.0
	elif dist < 6:
		score -= (6.0 - dist) * 10.0  # Get away!

	# B. Seek High Cover ALWAYS
	var my_cover = CombatResolver.get_cover_height_at_pos(tile, target.grid_pos, gm)
	if my_cover >= 2.0:
		score += 100.0
	elif my_cover >= 1.0:
		score += 40.0
	else:
		score -= 50.0  # Hate open ground

	# C. Must have LOS to shoot
	if not _check_los(tile, target, gm):
		# Unless we are retreating (Preservation > 0)
		if preservation == 0:
			score -= 200.0  # Useless if can't see

	# D. Flanking Bonus
	var target_cover = CombatResolver.get_cover_height_at_pos(target.grid_pos, tile, gm)
	if target_cover <= 0.0:
		score += 40.0

	return score


func _check_los(tile: Vector2, target, gm: GridManager) -> bool:
	var my_eye = gm.get_world_position(tile) + Vector3(0, 1.5, 0)
	var target_center = target.position + Vector3(0, 1.0, 0)
	var space = get_viewport().world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(my_eye, target_center)
	var result = space.intersect_ray(query)
	if result:
		return false  # Blocked
	return true


func attack_target(grid_manager: GridManager):
	if target_unit:
		# Use CombatResolver
		var result = CombatResolver.execute_attack(self, target_unit, grid_manager)
		if DEBUG_AI:
			print(" - Attack Result: ", result)


func get_ideal_distance() -> int:
	return 4  # Default for base class


func is_tile_occupied(tile: Vector2, _all_units: Array) -> bool:
	for unit in _all_units:
		if is_instance_valid(unit) and unit.current_hp > 0:
			if unit.grid_pos == tile:
				return true
	return false
