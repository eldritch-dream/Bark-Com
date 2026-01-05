extends Node
class_name MissionManager

# Signals
signal wave_started(wave_index, wave_count)
signal wave_cleared(wave_index)
signal mission_completed(mission_data)
signal mission_failed(reason)

# Config
var active_mission_config: MissionConfig
var current_wave_index: int = 0
var spawned_units: Array = []
var grid_manager = null  # Reference to GridManager
var _mission_ended_flag: bool = false


func _ready():
	SignalBus.on_unit_died.connect(_on_unit_died)





# Enemies (Hardcoded Archetypes for now, could be Resources too)
const ENEMY_SCRIPTS = {
	"Rusher": "res://scripts/entities/EnemyUnit.gd",
	"Sniper": "res://scripts/entities/EnemyUnit.gd", 
	"Spitter": "res://scripts/entities/SpitterUnit.gd",
	"Whisperer": "res://scripts/entities/WhispererUnit.gd",
	"Nemesis": "res://scripts/entities/EnemyUnit.gd" # Placeholder
}
func generate_mission_config(level: int) -> MissionConfig:
	var config = MissionConfig.new()
	config.mission_name = "Sector Sweep (Level " + str(level) + ")"
	config.description = "Clear all hostiles in the sector."
	config.reward_kibble = 50 * level
	
	if level == 1:
		# Level 1: 1 Wave, Max Threat 5, Only Snipers/Rushers
		var wave1 = _create_wave(5, ["Rusher", "Sniper"])
		wave1.wave_message = "Hostiles Detected!"
		config.waves.append(wave1)

	elif level == 2:
		# Level 2: 2 Waves, Spitter Limit 1 (per wave), Rushers/Snipers/Spitters
		
		# Wave 1: Intro (Lighter)
		var wave1 = _create_wave(6, ["Rusher", "Sniper"]) 
		wave1.wave_message = "First Wave Incoming!"
		config.waves.append(wave1)
		
		# Wave 2: Escalation (With Spitter)
		# Spitter Cost 3. Budget 8 allows 1 Spitter + 5 Rushers or 1 Spitter + 2 Snipers + 1 Rusher
		# We need to enforce max 1 Spitter. _create_wave logic needs to handle this or we constrain budget/rng.
		# For now, relying on luck + budget is risky.
		# Let's use guaranteed spawn for the Spitter to ensure it appears (and limit it to 1 via param if we add it).
		
		var wave2 = _create_wave(8, ["Rusher", "Sniper", "Spitter"])
		# Force 1 Spitter if random doesn't pick it? 
		# Or just allow random. The requirement is "Maximum 1 Spitter active".
		# Since we reset waves, max 1 spitter PER WAVE meets this if we only spawn 1.
		# Cost 3 means at budget 8, you could theoretically get 2 spitters (6) + 2 rushers (2).
		# We should manually enforce the limit in _create_wave or just use guaranteed.
		wave2.guaranteed_spawns["Spitter"] = 1
		# Reduce budget by Spitter cost (3) -> 5 remaining for randoms
		wave2.budget_points = 5 
		wave2.allowed_archetypes = ["Rusher", "Sniper"] # Don't allow more Random Spitters
		wave2.wave_message = "Reinforcements! Caution: Acid Detected!"
		config.waves.append(wave2)

	elif level >= 3:
		# Level 3+: 3 Waves, Any Enemies.
		var w1 = _create_wave(8, ["Rusher", "Sniper"])
		config.waves.append(w1)
		
		var w2 = _create_wave(10, ["Rusher", "Sniper", "Spitter"])
		config.waves.append(w2)
		
		var w3 = _create_wave(12 + (level * 2), ["Rusher", "Sniper", "Spitter", "Whisperer"])
		config.waves.append(w3)
	
	# Randomize Objective Type (Level 1 is always Deathmatch for simplicity)
	if level > 1:
		var types = [0, 2, 3] # Deathmatch, Retrieve, Hacker
		# Level 2 focuses on Retrieve logic, Level 3 introduces Hacker? 
		# Or generic randomization.
		# Let's weight it? No, flat is fine.
		config.objective_type = types.pick_random()
		
		# Debug override for testing
		# config.objective_type = 2 
		
		match config.objective_type:
			2: # Retrieve
				config.objective_target_count = randi_range(5, 7)
				config.mission_name = "Supply Run (Level " + str(level) + ")"
				config.description = "Retrieve " + str(config.objective_target_count) + " Treat Bags."
			3: # Hacker
				config.objective_target_count = randi_range(3, 4)
				config.mission_name = "Network Breach (Level " + str(level) + ")"
				config.description = "Hack " + str(config.objective_target_count) + " Terminals."
			_:
				config.objective_type = 0 # Default Deathmatch
				config.mission_name = "Sector Sweep (Level " + str(level) + ")"
				config.description = "Eliminate all hostiles."
	
	return config


func _create_wave(budget: int, allowed: Array) -> WaveDefinition:
	var w = WaveDefinition.new()
	w.budget_points = budget
	w.allowed_archetypes.assign(allowed) # Godot Array copy
	return w


func start_mission(config: MissionConfig, grid: GridManager):
	active_mission_config = config
	grid_manager = grid
	current_wave_index = 0
	spawned_units.clear()

	print("--- MISSION STARTED: ", config.mission_name, " ---")

	# Spawn Loot (10% Chance if Deathmatch, or Default for other?)
	# Use standard Logic
	print("MissionManager: Objective Type is ", active_mission_config.objective_type)
	if active_mission_config.objective_type != 0:
		_spawn_objectives(active_mission_config.objective_type, active_mission_config.objective_target_count)
	else:
		if randf() <= 0.1:
			_spawn_loot()

	# Start First Wave
	start_next_wave()


func _spawn_objectives(type: int, count: int):
	print("MissionManager: Spawning ", count, " Objectives (Type ", type, ")...")
	
	var successful_spawns = 0
	for i in range(count):
		var pos = _find_valid_loot_pos()
		if pos == Vector2(-1, -1):
			print("MissionManager: Could not find spot for objective ", i)
			continue
			
		var obj_node = null
		
		# Define Objective based on Type
		if type == 3: # HACKER
			var t_script = load("res://scripts/entities/Terminal.gd")
			if t_script:
				obj_node = t_script.new()
				obj_node.add_to_group("Terminals")
				
		elif type == 2: # RETRIEVE
			var l_script = load("res://scripts/entities/LootCrate.gd")
			if l_script:
				obj_node = l_script.new()
				obj_node.add_to_group("TreatBags")
				# Add Reward (10% Chance)
				if randf() <= 0.1:
					var pool = [
						"res://scripts/resources/items/SanityTreat.gd",
						"res://scripts/resources/items/Medkit.gd",
						"res://scripts/resources/items/GrenadeItem.gd"
					]
					var picked = pool.pick_random()
					var script = load(picked)
					if script:
						obj_node.loot_table.append(script.new())
						print("MissionManager: Crate at ", pos, " contains loot: ", picked)
				
		elif type == 1: # RESCUE
			var h_script = load("res://scripts/entities/ObjectiveUnit.gd")
			if h_script:
				obj_node = h_script.new()
				obj_node.name = "Lost Human"
				obj_node.add_to_group("RescueTargets")
		
		elif type == 4: # DEFENSE (Golden Hydrant)
			var gh_script = load("res://scripts/entities/GoldenHydrant.gd")
			if gh_script:
				obj_node = gh_script.new()
				obj_node.name = "GoldenHydrant"
				# Center of map (Assuming 20x20)
				# Override position logic to force center
				# SPIRAL SEARCH FOR VALID & REACHABLE TILE
				# Center (10,10) might be unreachable. Check reachability from Player Start (Approx 1,1)
				var center = Vector2(10, 10)
				var best_pos = Vector2(-1, -1)
				var player_start_approx = Vector2(1, 1)

				# Check Center First
				var path = grid_manager.get_move_path(player_start_approx, center)
				if not path.is_empty():
					best_pos = center
				else:
					print("MissionManager: Center (10,10) unreachable. Spiraling search...")
					var found = false
					for r in range(1, 10): # Radius 1 to 9
						for x in range(center.x - r, center.x + r + 1):
							for y in range(center.y - r, center.y + r + 1):
								var p = Vector2(x, y)
								if not grid_manager.grid_data.has(p):
									continue

								
								# Distance heuristic (Manhattan from center) = max(abs(dx), abs(dy))
								# But just check walkability + reachability
								if grid_manager.is_walkable(p):
									var p_path = grid_manager.get_move_path(player_start_approx, p)
									if not p_path.is_empty():
										best_pos = p
										found = true
										print("MissionManager: Found suitable Hydrant spot at ", p)
										break
							if found: break
						if found: break
				
				if best_pos != Vector2(-1, -1):
					pos = best_pos
				else:
					# Fallback to center and hope clearing works
					pos = center
					print("MissionManager: Could not find reachable spot? Forcing Center.")

				
				# CRITICAL: Force clear the tile so it doesn't spawn in a wall
				if grid_manager.grid_data.has(pos):
					grid_manager.grid_data[pos]["walkable"] = true
					grid_manager.grid_data[pos]["cover"] = 0.0
					grid_manager.grid_data[pos]["unit"] = null # Clear any existing unit placeholder
					print("MissionManager: Force-cleared tile for Hydrant at ", pos)
					
					# PHYSICS CLEANUP: Destroy any visual/collision walls here
					var world_pos = grid_manager.get_world_position(pos)
					# GridManager is Node, not Node3D. Use Viewport to get World3D.
					var space_state = grid_manager.get_viewport().world_3d.direct_space_state
					
					# Check for obstacles (Walls are usually StaticBody3D on Layer 1)
					var query = PhysicsPointQueryParameters3D.new()
					query.position = world_pos + Vector3(0, 0.5, 0) # Raise slightly
					query.collision_mask = 1 # Layer 1 (World/Walls)
					query.collide_with_bodies = true
					
					var results = space_state.intersect_point(query)
					for res in results:
						if res.collider and res.collider.is_class("StaticBody3D"):
							print("MissionManager: Destroying Wall at Hydrant Point! ", res.collider)
							res.collider.queue_free()



		
		if obj_node:
			# Setup
			grid_manager.get_parent().add_child(obj_node)
			obj_node.position = grid_manager.get_world_position(pos)
			obj_node.grid_pos = pos
			
			if obj_node.has_method("initialize"):
				# Type 3 (Terminal) and Type 4 (Hydrant/Destructible) expect (pos, gm)
				if type == 3 or type == 4:
					obj_node.initialize(pos, grid_manager)
				else:
					# Type 1 & 2 (Unit/Loot) -> initialize(pos)
					obj_node.initialize(pos)
			
			obj_node.add_to_group("Objectives")
			print("MissionManager: Spawned Objective (Type ", type, ") at ", pos)
			successful_spawns += 1
		else:
			print("MissionManager: Failed to create objective node for type ", type)

	# Desperation Spawn (Ensure at least 1)
	if successful_spawns == 0 and count > 0:
		print("MissionManager: CRITICAL! No valid spots found. Attempting ROBUST Desperation Spawn.")
		# Search area around player start for ANY valid tile
		var spawned_desperation = false
		for x in range(1, 6):
			for y in range(1, 6):
				var fallback_pos = Vector2(x, y)
				if grid_manager.is_walkable(fallback_pos):
					var obj_node = null
					if type == 2:
						var l_script = load("res://scripts/entities/LootCrate.gd")
						obj_node = l_script.new()
						obj_node.add_to_group("TreatBags")
					# Handle other types if needed, but currently mostly Retrieve fails
					
					if obj_node:
						grid_manager.get_parent().add_child(obj_node)
						obj_node.position = grid_manager.get_world_position(fallback_pos)
						obj_node.grid_pos = fallback_pos
						if obj_node.has_method("initialize"):
							obj_node.initialize(fallback_pos)
						obj_node.add_to_group("Objectives")
						successful_spawns += 1
						spawned_desperation = true
						print("MissionManager: Desperation Spawn Successful at ", fallback_pos)
						break
			if spawned_desperation:
				break
				
	if successful_spawns < count:
		print("MissionManager: WARN - Only spawned ", successful_spawns, "/", count, " objectives.")
		
		# Prevent Instant Win by ensuring target is at least 1 (unless count was 0)
		var final_target = successful_spawns
		if final_target == 0 and count > 0:
			print("MissionManager: ERROR! Failed to spawn ANY objectives even with desperation. Forcing target to 1 to prevent instant win.")
			final_target = 1
		
		active_mission_config.objective_target_count = final_target
		
		var om = grid_manager.get_node_or_null("../ObjectiveManager")
		if om:
			print("MissionManager: Syncing ObjectiveManager to new count: ", final_target)
			om.target_count = final_target
		else:
			print("MissionManager: CRITICAL! Could not find ObjectiveManager to sync count! Main scene structure mismatch?")
	else:
		print("MissionManager: All ", count, " objectives spawned successfully.")


func _spawn_loot():
	if not grid_manager:
		return
	print("MissionManager: Spawning Loot Crate...")

	valid_loot_pos = _find_valid_loot_pos()
	if valid_loot_pos == Vector2(-1, -1):
		return

	var crate_script = load("res://scripts/entities/LootCrate.gd")
	var crate = crate_script.new()

	# Add Medkit to Loot Table directly
	var medkit_script = load("res://scripts/resources/items/Medkit.gd")
	if medkit_script:
		crate.loot_table.append(medkit_script.new())

	# 2. Spawn Explosive Barrels
	var barrel_positions = [
		Vector2(2, 5), Vector2(4, 5), Vector2(6, 5), Vector2(8, 5),
		Vector2(3, 7), Vector2(5, 7), Vector2(7, 7),
		Vector2(5, 5) # Central one
	]
	
	for pos in barrel_positions:
		var barrel = load("res://scripts/entities/ExplosiveBarrel.gd").new()
		# Initialize barrel if needed (assuming _ready handles it, just set pos)
		barrel.position = grid_manager.get_world_position(pos)
		barrel.grid_pos = pos
		grid_manager.get_parent().add_child(barrel) # Changed unit_container to grid_manager.get_parent()
		
		# Register prop in grid?
		# Static props might not need move registration, but Blocking check needs it.
		# Better to register if it blocks tiles.
		if barrel.has_method("initialize"):
			barrel.initialize(pos, grid_manager)
		else:
			# Manual registration fallback
			if grid_manager.grid_data.has(pos):
				grid_manager.grid_data[pos]["unit"] = barrel

		# Register with TurnManager (Ensure it's tracked as a unit/active prop)
		var tm = grid_manager.get_node_or_null("../TurnManager")
		if tm:
			tm.register_unit(barrel)

	# The original instruction had a print statement here that referenced `spitter_positions.size()`,
	# which is not defined in this function. Removing it to avoid errors.
	# print("MissionManager: Acidsplosion setup complete with ", spitter_positions.size(), " spitters and ", barrel_positions.size(), " barrels.")

	# Setup Position
	crate.grid_pos = valid_loot_pos
	crate.position = grid_manager.get_world_position(valid_loot_pos)

	# Add to Scene (Same parent as units)
	grid_manager.get_parent().add_child(crate)

	# Ensure it is in 'Objectives' group for interaction check if needed?
	# Main._try_interact checks "Objectives" group?
	# LootCrate should probably be in "Objectives" or "Interactables"
	crate.add_to_group("Objectives")  # _try_interact scans this group

	print("Spawned Loot Crate at ", valid_loot_pos)


var valid_loot_pos = Vector2(-1, -1)


func _find_valid_loot_pos() -> Vector2:
	var player_start = Vector2(1, 1) # Default
	# Search for actual valid start if 1,1 is blocked
	if not grid_manager.is_walkable(player_start):
		for x in range(1, 4):
			for y in range(1, 4):
				if grid_manager.is_walkable(Vector2(x, y)):
					player_start = Vector2(x, y)
					break
			if player_start != Vector2(1, 1): break

	# Try random positions (Strict)
	for i in range(30): # Increased attempts due to stricter filter
		var pos = grid_manager.get_random_valid_position()
		# Avoid start zone
		if pos.distance_to(player_start) > 5:
			# REACHABILITY CHECK
			var path = grid_manager.get_move_path(player_start, pos)
			if not path.is_empty():
				return pos
			
	# Fallback (Lenient)
	for i in range(20):
		var pos = grid_manager.get_random_valid_position()
		if pos != Vector2(0,0) and pos != player_start: 
			# Just ensure it's reachable, distance doesn't matter as much for fallback
			var path = grid_manager.get_move_path(player_start, pos)
			if not path.is_empty():
				print("MissionManager: Using fallback reachable spawn pos at ", pos)
				return pos
			
	return Vector2(-1, -1)


func register_player_units(_player_units: Array):
	# Initialize TurnManager tracking
	if not SignalBus.on_turn_changed.is_connected(_on_turn_changed):
		SignalBus.on_turn_changed.connect(_on_turn_changed)
	if not SignalBus.on_unit_died.is_connected(_on_unit_died):
		SignalBus.on_unit_died.connect(_on_unit_died)



# Handle Unit Death (Player Permadeath & Wave Logic)
func _on_unit_died(unit):
	if not unit:
		return
	
	# 1. Player Death (Permadeath)
	if "faction" in unit and unit.faction == "Player":
		print("MissionManager: Player Unit Died! Registering death...")
		if GameManager:
			var data = {
				"name": unit.name,
				"class": unit.unit_class if "unit_class" in unit else "Recruit",
				"level": unit.level if "level" in unit else 1,
				"unlocked_talents": unit.unlocked_talents if "unlocked_talents" in unit else []
			}
			GameManager.register_fallen_hero(data, "Killed in Action")

	# 2. Enemy/Wave Logic
	if unit in spawned_units:
		spawned_units.erase(unit)

		if spawned_units.is_empty():
			print("Wave Cleared!")
			wave_cleared.emit(current_wave_index)
			
			if current_wave_index < active_mission_config.waves.size():
				get_tree().create_timer(2.0).timeout.connect(start_next_wave)
			else:
				# Waves Exhausted. 
				# Only Trigger Victory if Deathmatch (0) or Defense (4).
				# For Hacker (3), Retrieve (2), Rescue (1), the player must complete the objective manually.
				if active_mission_config.objective_type == 0 or active_mission_config.objective_type == 4:
					_complete_mission()
				else:
					print("MissionManager: Waves Clear. Waiting for Objective Completion...")
	
	# 3. Generic Status Check
	_check_mission_status()


func _on_turn_changed(_phase, turn_num):
	_check_mission_status(turn_num)


func _check_mission_status(turn_num: int = -1):
	var om = grid_manager.get_node_or_null("../ObjectiveManager")
	var tm = grid_manager.get_node_or_null("../TurnManager")
	
	if not om or not tm:
		return
		
	# Pass current units list to status checker
	# print("MissionManager: Checking Status... Turn:", turn_num)
	var status = om.check_status(tm.units, turn_num if turn_num != -1 else om.current_turn)
	print("MissionManager: Status Result -> ", status)
	
	if status == "WIN":
		print("MissionManager: Victory Condition Met!")
		_complete_mission()
	elif status == "LOSS":
		print("MissionManager: Defeat Condition Met!")
		_handle_defeat(tm.units)
		SignalBus.on_mission_ended.emit(false, 0)



func start_next_wave():
	if current_wave_index >= active_mission_config.waves.size():
		_complete_mission()
		return

	var wave_def = active_mission_config.waves[current_wave_index]
	current_wave_index += 1
	wave_started.emit(current_wave_index, active_mission_config.waves.size())

	print(">>> WAVE ", current_wave_index, ": ", wave_def.wave_message)
	_spawn_wave(wave_def)


func _spawn_wave(wave_def: WaveDefinition):
	# 1. Guaranteed Spawns
	for type in wave_def.guaranteed_spawns:
		var count = wave_def.guaranteed_spawns[type]
		for _i in range(count):
			_spawn_enemy(type)

	# 2. Budget Spawns
	var budget = wave_def.budget_points
	var attempts = 0
	while budget > 0 and attempts < 100:
		var type = _pick_random_archetype(wave_def)
		if type == "":
			break  # No valid types

		var cost = _get_cost(type)

		if cost <= budget:
			_spawn_enemy(type)
			budget -= cost
		else:
			attempts += 1  # Try to find cheaper unit or exit


func _pick_random_archetype(wave_def: WaveDefinition) -> String:
	# Use Allowed List if present
	# Use Allowed List if present
	var pool = []
	if not wave_def.allowed_archetypes.is_empty():
		pool = wave_def.allowed_archetypes
		# print("Debug: using allowed archetypes: ", pool)
	else:
		print("Debug: allowed_archetypes EXPECTED but EMPTY! Falling back to defaults.")
		# Fallback: Random key from ENEMIES (excluding Nemesis/Whisperer usually unless specified?)
		pool = ["Rusher", "Sniper", "Spitter"]
	
	if pool.is_empty():
		return ""
	var choice = pool[randi() % pool.size()]
	# print("Debug: Picked archetype: ", choice)
	return choice


func _get_cost(type_name: String) -> int:
	match type_name:
		"Rusher":
			return 1
		"Sniper":
			return 2
		"Spitter":
			return 3
		"Whisperer":
			return 4
		"Nemesis":
			return 5
		_:
			return 1


func _spawn_enemy(type_name: String):
	if not grid_manager:
		return

	var script_path = ENEMY_SCRIPTS.get(type_name)
	if not script_path or not ResourceLoader.exists(script_path):
		print("Error: Unknown enemy script for ", type_name)
		return

	var script = load(script_path)
	var enemy = script.new()

	# Find Spawn Position
	var spawn_pos = Vector2(-1, -1)
	for i in range(20): # Try 20 times
		var candidate = grid_manager.get_random_valid_position()
		
		# Check Reachability from Player Start Zone (Approx 1,1)
		# AStar ensures valid path exists (ignores range)
		var path = grid_manager.get_move_path(Vector2(1, 1), candidate)
		if not path.is_empty():
			spawn_pos = candidate
			break
			
	if spawn_pos == Vector2(-1, -1):
		print("MissionManager: Could not find reachable spawn for ", type_name)
		spawn_pos = grid_manager.get_random_valid_position() # Fallback


	enemy.position = grid_manager.get_world_position(spawn_pos)
	enemy.grid_pos = spawn_pos
	
	# Register in Grid immediately to prevent stacking!
	if grid_manager.grid_data.has(spawn_pos):
		grid_manager.grid_data[spawn_pos]["unit"] = enemy


	# Default Visibility: Hidden (VisionManager will reveal if seen)
	enemy.visible = false

	grid_manager.get_parent().add_child(enemy)
	enemy.add_to_group("Units")
	enemy.add_to_group("Enemies")
	spawned_units.append(enemy)

	# Register with TurnManager (Critical for Targeting/Turn Logic)
	var tm = grid_manager.get_node_or_null("../TurnManager")
	if tm:
		tm.register_unit(enemy)

	# Factory Configuration (Applied AFTER add_child so _ready (visuals) exist)
	_configure_enemy(enemy, type_name)

	# Initialize if needed (some scripts use _ready, others initialize())
	if enemy.has_method("initialize"):
		enemy.initialize(spawn_pos)

	print("Spawned ", type_name, " at ", spawn_pos)


func _configure_enemy(enemy, type_name: String):
	# This requires GameManager to access EnemyData helper if needed.
	# Or we manually construct data here.

	var data_script = load("res://scripts/resources/EnemyData.gd")
	if not data_script:
		return
	var data = data_script.new()

	# Weapon Data Helper
	var weapon_script = load("res://scripts/resources/WeaponData.gd")

	# GameManager Access
	# GameManager is Autoload, so capable of direct access
	var gm_global = null
	if has_node("/root/GameManager"):
		gm_global = get_node("/root/GameManager")

	match type_name:
		"Rusher":
			var theme = ["Fleshy", "Suburbia"].pick_random()
			if gm_global:
				data.display_name = gm_global.get_enemy_name(theme)
			else:
				data.display_name = "Feral Rusher"

			data.ai_behavior = data.AIBehavior.RUSHER
			data.max_hp = 8
			data.mobility = 6
			data.visual_color = Color.ORANGE
			if weapon_script:
				var w = weapon_script.new()
				w.display_name = "Bite"
				w.damage = 3
				w.weapon_range = 1
				data.primary_weapon = w
			enemy.initialize_from_data(data)

		"Sniper":
			var theme = ["Abstract", "Aquatic"].pick_random()
			if gm_global:
				data.display_name = gm_global.get_enemy_name(theme)
			else:
				data.display_name = "Eldritch Sniper"

			data.ai_behavior = data.AIBehavior.SNIPER
			data.max_hp = 6
			data.mobility = 3
			data.visual_color = Color.CYAN
			if weapon_script:
				var w = weapon_script.new()
				w.display_name = "Eye Rifle"
				w.damage = 4
				w.weapon_range = 10
				data.primary_weapon = w
			enemy.initialize_from_data(data)

		"Spitter":
			var theme = ["Fleshy", "Abstract"].pick_random()
			if gm_global:
				data.display_name = gm_global.get_enemy_name(theme)
			else:
				data.display_name = "Acid Spitter"
			enemy.initialize_from_data(data)

		"Whisperer":
			var theme = ["Abstract"].pick_random()
			if gm_global:
				data.display_name = gm_global.get_enemy_name(theme)
			else:
				data.display_name = "Whisperer"

			# Needs resource data
			var w_path = "res://assets/data/enemies/WhispererData.tres"
			if ResourceLoader.exists(w_path):
				var w_data = load(w_path)
				enemy.initialize_from_data(w_data)


func _complete_mission():
	if _mission_ended_flag:
		return
	_mission_ended_flag = true

	print("MissionManager: Mission Complete! Emitting Victory Signal.")
	mission_completed.emit(active_mission_config)
	
	# Also notify global bus so Main.gd shows victory screen
	var rewards = 100
	if active_mission_config and "reward_kibble" in active_mission_config:
		rewards = active_mission_config.reward_kibble
		
	SignalBus.on_mission_ended.emit(true, rewards)


func _handle_defeat(units: Array):
	if _mission_ended_flag:
		return
	_mission_ended_flag = true

	print("MissionManager: Processing Defeat Persistence...")
	if not GameManager:
		return

	# Collect Survivors (Player)
	var survivors = []
	for u in units:
		if is_instance_valid(u) and "faction" in u and u.faction == "Player" and u.current_hp > 0:
			survivors.append({
				"name": u.name,
				"hp": u.current_hp,
				"xp": u.current_xp if "current_xp" in u else 0,
				"level": u.rank_level if "rank_level" in u else 1,
				"sanity": u.current_sanity if "current_sanity" in u else 0,
				"inventory": u.inventory if "inventory" in u else []
			})

	# Collect Enemy Survivors (Nemesis System)
	var enemy_survivors = []
	for u in units:
		if is_instance_valid(u) and "faction" in u and u.faction == "Enemy" and u.current_hp > 0:
			if "victim_log" in u and u.victim_log.size() > 0:
				enemy_survivors.append({
					"name": u.name,
					"victim_log": u.victim_log,
					"base_type": "Rusher" # Simplified
				})

	GameManager.complete_mission(survivors, false, enemy_survivors)


func setup_acidsplosion_scenario(grid_manager, unit_container):
	print("MissionManager: Setting up ACIDSPLOSION Scenario!")
	
	# 1. Spawn Spitters
	# Center the action around 10,10
	var spitter_positions = [
		Vector2(8, 8), Vector2(12, 8), Vector2(8, 12), Vector2(12, 12), Vector2(10, 6)
	]
	
	for pos in spitter_positions:
		# Ensure tile is valid (Force Clear)
		if grid_manager.grid_data.has(pos):
			grid_manager.grid_data[pos]["walkable"] = true
			grid_manager.grid_data[pos]["cover"] = 0.0
			# Remove any existing static body? 
			# GridManager usually manages data, LevelGenerator manages meshes.
			# We can't easily remove the mesh here without a reference map.
			# But we can update data so pathfinding works.
		
		var spitter = load("res://scripts/entities/SpitterUnit.gd").new()
		
		# Add to scene FIRST to trigger _ready() and setup nodes
		unit_container.add_child(spitter)
		spitter.position = grid_manager.get_world_position(pos)
		
		# Load minimal data manually
		var data = load("res://scripts/resources/EnemyData.gd").new()
		data.display_name = "Acid Spitter"
		data.max_hp = 10
		data.mobility = 5
		data.visual_color = Color.WEB_GREEN
		
		# Initialize Data (Updates Visuals & Stats)
		spitter.initialize_from_data(data)
		spitter.grid_pos = pos
		
		pass
		
	# 2. Spawn Explosive Barrels
	var barrel_positions = [
		Vector2(10, 10), # Center Bullseye
		Vector2(9, 9), Vector2(11, 9), Vector2(9, 11), Vector2(11, 11), # Inner Ring
		Vector2(10, 8), Vector2(10, 12), Vector2(8, 10), Vector2(12, 10) # Cross
	]
	
	for pos in barrel_positions:
		# Force Clear for Barrels too
		if grid_manager.grid_data.has(pos):
			grid_manager.grid_data[pos]["walkable"] = true
			grid_manager.grid_data[pos]["cover"] = 0.0

		var barrel_script = load("res://scripts/entities/ExplosiveBarrel.gd")
		if barrel_script:
			var barrel = barrel_script.new()
			# IMPORTANT: Add to scene FIRST if _ready depends on tree, otherwise set props.
			# But position needs to be set.
			if grid_manager and grid_manager.get_parent():
				grid_manager.get_parent().add_child(barrel)
			
			barrel.grid_pos = pos
			barrel.position = grid_manager.get_world_position(pos)
			
			if barrel.has_method("initialize"):
				barrel.initialize(pos, grid_manager)
			else:
				if grid_manager.grid_data.has(pos):
					grid_manager.grid_data[pos]["unit"] = barrel

	print("MissionManager: Acidsplosion setup complete.")
