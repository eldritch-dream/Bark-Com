extends Node3D

var main_camera: Camera3D

# Managers
var turn_manager
var fog_manager

# State
var selected_unit
var game_ui
var vision_manager
var spawned_units = []
var deployed_names = [] # Track names for roster sync (Death tracking)
# var is_base_defense: bool = false # Moved to MissionConfig
# var wave_count: int = 0         # Moved to MissionManager
# var max_waves: int = 10         # Moved to MissionManager
var active_mission_data: Resource = null  # Supports MissionData (Legacy) or MissionConfig (New)

# Systems
var mission_manager: MissionManager

var grid_manager


func _ready():
	# Setup Initialization
	var gm = GridManager.new()
	gm.name = "GridManager"
	grid_manager = gm

	var gv = load("res://scripts/ui/GridVisualizer.gd").new()
	gv.name = "GridVisualizer"
	gv.grid_manager = gm

	add_child(gv)
	add_child(gm)

	# Mission Manager
	mission_manager = MissionManager.new()
	mission_manager.name = "MissionManager"
	add_child(mission_manager)

	# Connect Mission Signals
	mission_manager.wave_started.connect(
		func(idx, total): _log("Wave " + str(idx) + "/" + str(total) + " Started!")
	)
	mission_manager.mission_completed.connect(func(_data): _on_mission_completed())

	# Setup UI/Feedback Managers
	var ftm = load("res://scripts/managers/FloatingTextManager.gd").new()
	add_child(ftm)

	var vfxm = load("res://scripts/managers/VFXManager.gd").new()
	add_child(vfxm)

	# Also add a Camera so the user can see
	main_camera = Camera3D.new()
	main_camera.set_script(load("res://scripts/core/CameraController.gd"))
	main_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	main_camera.size = 18  # Revert Zoom (User Request)
	main_camera.current = true

	# User-Defined Initial Position (Refined for Tactical View)
	# Centered better on 0-10 grid
	main_camera.position = Vector3(5.0, 10.0, 10.0)
	main_camera.rotation_degrees = Vector3(-45, -45, 0)  # Classic Iso Angle

	add_child(main_camera)

	# Cinematic Director
	var camera_script = load("res://scripts/systems/CinematicCamera.gd")
	if camera_script:
		var cam_controller = camera_script.new(main_camera)
		add_child(cam_controller)

	var light = DirectionalLight3D.new()
	add_child(light)
	light.position = Vector3(10, 20, 15)
	light.look_at(Vector3(10, 0, 10))
	light.shadow_enabled = true  # Enable shadows for depth

	# Mission Setup
	# Mission Setup
	# Logic:
	# 1. Check if GameManager has a mission pending.
	# 2. If not, default to Tutorial (Phase 79 verification).

	var mission_config = null

	# Fetch from GameManager if local property is empty (Standard Flow)
	if active_mission_data == null and GameManager and GameManager.active_mission:
		active_mission_data = GameManager.active_mission
		print("Main: Retrieved Active Mission from GameManager.")

	if active_mission_data:
		if active_mission_data is MissionConfig:
			mission_config = active_mission_data
			print("Main: Loaded Native MissionConfig -> ", mission_config.mission_name)
		elif (
			active_mission_data.get_class() == "MissionData"
			or "objective_type" in active_mission_data
		):
			# AUTO-ADAPTER: Convert Legacy Data to Config
			print("Main: Adapting Legacy MissionData -> MissionConfig")
			mission_config = MissionConfig.new()
			mission_config.mission_name = active_mission_data.mission_name
			mission_config.description = active_mission_data.description
			mission_config.mission_name = active_mission_data.mission_name
			mission_config.description = active_mission_data.description
			mission_config.is_final_defense = (active_mission_data.mission_name == "BASE DEFENSE")
			mission_config.objective_type = active_mission_data.objective_type
			mission_config.reward_kibble = active_mission_data.reward_kibble
			
			if "objective_target_count" in active_mission_data:
				mission_config.objective_target_count = active_mission_data.objective_target_count

			if mission_config.is_final_defense:
				# BASE DEFENSE: 10 Waves, Point Buy (5 + Level)
				for i in range(10):
					var w = WaveDefinition.new()
					w.budget_points = 5 + i
					# Progressive Difficulty: Add Whisperers later
					if i >= 5:
						w.allowed_archetypes.assign(["Rusher", "Sniper", "Spitter", "Whisperer"])
					else:
						w.allowed_archetypes.assign(["Rusher", "Sniper", "Spitter"])
					w.wave_message = "INVASION WAVE " + str(i + 1) + " (Threat: " + str(w.budget_points) + ")"
					mission_config.waves.append(w)
			else:
				# Legacy / Generated Mission Waves
				var w = WaveDefinition.new()
				var diff = active_mission_data.difficulty_rating
				
				if diff <= 1:
					w.budget_points = 5
					w.allowed_archetypes.assign(["Rusher", "Sniper"])
				elif diff == 2:
					w.budget_points = 8
					w.allowed_archetypes.assign(["Rusher", "Sniper", "Spitter"])
					w.guaranteed_spawns["Spitter"] = 1 # Match new Level 2 logic
				else:
					w.budget_points = 10 + (2 * diff)
					# Empty allowed = All Types
					
				w.wave_message = "Hostiles Detected!"
				mission_config.waves.append(w)
	else:
		# print("Main: No active mission found. Defaulting to Tutorial.")
		# mission_config = load("res://scripts/resources/missions/TutorialMission.gd").new()
		
		# DYNAMIC SCALING MISSION
		var level = 1
		if GameManager:
			level = GameManager.mission_level
		print("Main: No active mission found. Generating Level ", level, " Mission.")
		mission_config = mission_manager.generate_mission_config(level)

	# Perform Game Logic Setup (UI, TurnManager, Players)
	# Logic:
	# 1. We have 'mission_config' potentially from Adapter or Generation.
	# 2. We pass this to spawn_test_scenario to RUN the mission.
	spawn_test_scenario(gm, mission_config)

	# Audio: Mission Theme
	if GameManager and GameManager.audio_manager:
		GameManager.audio_manager.play_music("Theme_Mission")

	# Connect System Signals (to exit scene on done)
	if not SignalBus.on_mission_ended.is_connected(_on_mission_ended_handler):
		SignalBus.on_mission_ended.connect(_on_mission_ended_handler)
	if not SignalBus.on_turn_changed.is_connected(_on_turn_changed):
		SignalBus.on_turn_changed.connect(_on_turn_changed)
	if not SignalBus.on_unit_step_completed.is_connected(_on_unit_step_completed):
		SignalBus.on_unit_step_completed.connect(_on_unit_step_completed)
	if not SignalBus.on_request_camera_focus.is_connected(_on_camera_focus_requested):
		SignalBus.on_request_camera_focus.connect(_on_camera_focus_requested)

	# Phase 75: Input Manager Integration
	if GameManager:
		GameManager.current_state = GameManager.GameState.MISSION
	
	# Signal connections handled at the end of _ready with safety checks.


func _on_unit_step_completed(_unit):
	if vision_manager:
		vision_manager.update_vision(spawned_units)
	# fog_manager update delayed to Turn Start for Sanity Decay visuals


func _on_camera_focus_requested(target_pos: Vector3):
	if main_camera:
		# Calculate dynamic offset based on where the camera is currently looking
		var viewport_center = get_viewport().get_visible_rect().size / 2.0
		var from = main_camera.project_ray_origin(viewport_center)
		var dir = main_camera.project_ray_normal(viewport_center)

		# Intersect with Ground Plane (Y=0)
		# Ray: P = Origin + Dir * t
		# We want P.y = 0 (or target height?)
		# 0 = Origin.y + Dir.y * t  =>  t = -Origin.y / Dir.y

		var offset = Vector3(5, 10, 10)  # Fallback

		if abs(dir.y) > 0.001:
			var t = -from.y / dir.y
			var center_point = from + dir * t
			offset = main_camera.global_position - center_point

		var cam_target = target_pos + offset

		var tween = create_tween()
		(
			tween
			. tween_property(main_camera, "global_position", cam_target, 0.8)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)


func _on_turn_changed(phase_name, _turn_num):
	if phase_name == "PLAYER PHASE":
		if fog_manager and turn_manager:
			# 2. Update Mask (Reveals logic + visuals)
			fog_manager.update_mask(turn_manager.units)

	# BASE DEFENSE WAVE LOGIC
	# Now handled by MissionManager via turn signals?
	# MissionManager listens to turn/kill signals. Main doesn't need to drive this.
	pass

func _on_mission_completed():
	print("Main: _on_mission_completed triggered. Syncing Roster...")
	
	if not GameManager:
		return

	# Gather Survivors Data
	var survivors_data = []
	var deployed_data = [] # We need to reconstruct this or track it
	
	# 1. Build Survivors List
	for unit in spawned_units:
		if (
			is_instance_valid(unit) 
			and not unit.is_queued_for_deletion() 
			and unit.current_hp > 0
			and "faction" in unit 
			and unit.faction == "Player"
		):
			var data = {
				"name": unit.character_name if "character_name" in unit and unit.character_name != "" else unit.name,
				"hp": unit.current_hp,
				"sanity": unit.current_sanity,
				"xp": unit.current_xp, # Was unit.xp, verify check
				"level": unit.rank_level # Was unit.level, verify check
			}
			# Sync Inventory (Loot Persistence)
			# Sync Inventory (Loot Persistence)
			print("DEBUG_MAIN: Processing Unit: ", unit.name, " (Type: ", unit.get_class(), ")")
			
			var u_cast = unit as Unit
			if u_cast:
				data["inventory"] = u_cast.inventory
				print("DEBUG_MAIN: Inventory Found (Cast): ", data["inventory"])
			else:
				# Fallback or Debug
				var dyn_inv = unit.get("inventory")
				if dyn_inv != null:
					data["inventory"] = dyn_inv
					print("DEBUG_MAIN: Inventory Found (Dynamic): ", dyn_inv)
				else:
					print("DEBUG_MAIN: CRITICAL - No inventory access on unit!")

			survivors_data.append(data)
	
	print("Main: Syncing Roster. Survivors: ", survivors_data.size())
	
	# 3. Call GameManager
	# Use correct function name 'complete_mission'. Roster purging uses internal 'deploying_squad'.
	var reward = 0
	if mission_manager and mission_manager.active_mission_config:
		reward = mission_manager.active_mission_config.reward_kibble
		
	GameManager.complete_mission(survivors_data, true, [], reward)

	
	# 4. End Mission (UI / Signal)
	# Logic merged from deleted duplicate:
	print("Mission Completed via MissionManager!")
	if (
		mission_manager.active_mission_config
		and mission_manager.active_mission_config.is_final_defense
	):
		_trigger_victory_scene()
	else:
		_end_mission(true)
var _mission_end_processed = false

func _on_mission_ended_handler(victory: bool, _rewards: int):
	if _mission_end_processed:
		return
	_mission_end_processed = true

	print("Main: Mission Ended Signal Received. Victory: ", victory)
	
	# Stop Turn Processing
	if turn_manager:
		turn_manager.process_mode = Node.PROCESS_MODE_DISABLED

	if GameManager:
		if victory:
			GameManager.advance_doomsday_clock(1)
			if (
				mission_manager.active_mission_config
				and mission_manager.active_mission_config.is_final_defense
			):
				GameManager.invasion_progress = 0
				print("BASE DEFENSE SUCCESSFUL! DOOMSDAY AVERTED... FOR NOW.")
				# Trigger Victory Scene
				await get_tree().create_timer(3.0).timeout
				get_tree().change_scene_to_file("res://scenes/ui/VictoryScene.tscn")
				return  # Prevent standard clean-up

		else:
			GameManager.advance_doomsday_clock(5)

	# GameUI handles panel. Input handles exit.
	pass


func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):  # Spacebar / Enter
		var ui = get_node_or_null("GameUI")
		if ui and ui.mission_end_panel.visible:
			print("Returning to Base Scene...")
			queue_free()
			return

	# Hover Logic for Hit Chance
	if current_input_state == InputState.TARGETING:
		_handle_hover(get_viewport().get_mouse_position())
	else:
		SignalBus.on_hide_hit_chance.emit()

	# Debug Keys (moved to _unhandled_input)


func _apply_debug_effect(type: String):
	if not selected_unit:
		print("DEBUG: No unit selected for effect.")
		return

	var effect = null
	match type:
		"Poison":
			effect = load("res://scripts/resources/effects/PoisonEffect.gd").new()
		"Stun":
			effect = load("res://scripts/resources/effects/StunEffect.gd").new()
			effect.duration = 2  # Set to 2 so it survives the end of THIS turn to affect NEXT turn
		"GoodBoy":
			effect = load("res://scripts/resources/effects/GoodBoyBuff.gd").new()
		"Madness":
			if selected_unit.has_method("take_sanity_damage"):
				selected_unit.take_sanity_damage(30)
				print("DEBUG: Inflicted 30 Sanity Damage to ", selected_unit.name)
				return

	if effect:
		selected_unit.apply_effect(effect)
		SignalBus.on_request_floating_text.emit(
			selected_unit.position + Vector3(0, 2, 0), "+DEBUG " + type, Color.MAGENTA
		)


func _handle_hover(screen_pos):
	var from = main_camera.project_ray_origin(screen_pos)
	var to = from + main_camera.project_ray_normal(screen_pos) * 1000
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)

	var result = space.intersect_ray(query)
	var hovered_unit = null

	if result:
		if result.collider.is_in_group("Units"):
			hovered_unit = result.collider
		else:
			# Check grid
			var gm = get_node("GridManager")
			var grid_pos = gm.get_grid_coord(result.position)
			hovered_unit = _get_unit_at_grid(grid_pos)

	# Safe faction check for hover target and selected unit
	var target_faction = "Neutral"
	if is_instance_valid(hovered_unit) and "faction" in hovered_unit:
		target_faction = hovered_unit.faction

	var self_faction = "Neutral"
	if is_instance_valid(selected_unit) and "faction" in selected_unit:
		self_faction = selected_unit.faction

	if (
		is_instance_valid(hovered_unit)
		and hovered_unit != selected_unit
		and target_faction != self_faction
	):
		# Calculate Chance
		var gm = get_node("GridManager")
		var calc = CombatResolver.calculate_hit_chance(selected_unit, hovered_unit, gm)
		SignalBus.on_show_hit_chance.emit(calc["hit_chance"], calc["breakdown"])
	else:
		SignalBus.on_hide_hit_chance.emit()


func spawn_test_scenario(grid_manager: GridManager, mission: Resource = null):  # Updated Signature
	active_mission_data = mission
	print("--- TEST SCENARIO START ---")

	if mission and mission.mission_name == "BASE DEFENSE":
		print("--- BASE DEFENSE MISSION ---")

	# Initialize list before spawning anything
	spawned_units = []

	# Spawn Explosive Barrels
	# Spawn Explosive Barrels (Randomized 1-20)
	var num_barrels = randi_range(1, 20)
	print("Spawning ", num_barrels, " random Explosive Barrels.")
	
	for _i in range(num_barrels):
		var pos = grid_manager.get_random_valid_position()
		
		# Ensure not overlapping Player Start area (1,1)
		if pos != Vector2(-1, -1) and pos.distance_to(Vector2(1,1)) > 2:
			var barrel = load("res://scripts/entities/ExplosiveBarrel.gd").new()
			add_child(barrel)
			barrel.initialize(pos, grid_manager)
			spawned_units.append(barrel) # Treat as Unit for Targeting
			print("Spawned Explosive Barrel at ", pos)

	# 1. Spawn Corgi(s)
	# Check for GameManager

	# --- LOOTAPALOOZA: Spawn Loot Crates ---
	if GameManager and GameManager.debug_scenario == "lootapalooza":
		var num_crates = 15
		print("LOOTAPALOOZA: Spawning ", num_crates, " Loot Crates!")
		for _i in range(num_crates):
			var pos = grid_manager.get_random_valid_position()
			if pos != Vector2(-1, -1):
				var crate = load("res://scripts/entities/LootCrate.gd").new()
				add_child(crate)
				crate.initialize(pos, grid_manager)
				# FIX: Set World Position explicitly!
				crate.position = grid_manager.get_world_position(pos)
				
				spawned_units.append(crate) 
				# Ensure it has loot
				crate.loot_table.append(load("res://scripts/resources/items/Medkit.gd").new()) # Guaranteed Medkit for testing
				
				# Occupancy now handled by crate.initialize() + GridManager check.
				# Do NOT manually block AStar, as it breaks interaction (movement).

	# 1. Spawn Squad Loop
	# 1. Spawn Squad Loop
	var ready_units = []
	if GameManager:
		ready_units = GameManager.deploying_squad
		# Fallback if empty (e.g. testing Main directly)
		if ready_units.is_empty():
			ready_units = GameManager.get_ready_corgis()

	# Double Fallback: If still empty (Fresh save?), spawn Test Recruit.
	if ready_units.is_empty():
		ready_units = [{"name": "TestCorgi", "class": "Recruit"}]

	# spawned_units already cleared above
	deployed_names.clear()
	var start_tile = Vector2(1, 1)
	var spawn_offset = 0

	for data in ready_units:
		if spawn_offset >= 4:
			break  # Max 4 limit
		
		deployed_names.append(data["name"])

		# Instance
		var unit = load("res://scripts/entities/CorgiUnit.gd").new()
		unit.on_death.connect(_on_unit_death)
		add_child(unit)

		# Validate Walkable AND Occupied
		var target_tile = start_tile
		var found_spot = false

		# Linear search for open spot line (1...5)
		for i in range(10):  # Search tolerance
			var candidate = start_tile + Vector2(0, spawn_offset + i)
			var walkable_candidate = grid_manager.get_nearest_walkable_tile(candidate)

			# Check Occupancy against ALREADY spawned units
			var occupied = false
			for u in spawned_units:
				if u.grid_pos == walkable_candidate:
					occupied = true
					break

			if not occupied:
				target_tile = walkable_candidate
				found_spot = true
				break

		if not found_spot:
			print("CRITICAL: No spawn spot found for ", data["name"])
			continue  # Skip spawn

		unit.initialize(target_tile)
		unit.position = grid_manager.get_world_position(target_tile)
		print("Spawned ", data["name"], " at ", target_tile)

		# Apply Data
		unit.name = data["name"]
		unit.character_name = data["name"]  # Store displayed name (persisted)
		var cls = data.get("class", "Recruit")
		unit.apply_class_stats(cls)

		# Apply Persistence (XP/Level)
		# Apply Persistence (XP/Level)
		if data.has("xp"):
			unit.current_xp = data["xp"]
		if data.has("level"):
			unit.rank_level = data["level"]
		if data.has("sanity"):
			unit.current_sanity = data["sanity"]

		# Restore Talents
		if data.has("unlocked_talents"):
			for t_path in data["unlocked_talents"]:
				if ResourceLoader.exists(t_path):
					var talent = load(t_path)
					unit.learn_talent(talent)

		# Apply Level-Up Bonuses (e.g. +HP)
		unit.recalculate_stats()

		if data.get("primary_weapon") != null:
			unit.primary_weapon = data["primary_weapon"]

		# Cosmetic Persistence
		if data.has("cosmetics"):
			unit.restore_from_snapshot(data)

		spawned_units.append(unit)
		spawn_offset += 1
		
		# Phase 80: Restore Inventory
		if "inventory" in data:
			for item_entry in data["inventory"]:
				var item_res = null
				
				if item_entry is Resource:
					item_res = item_entry
				elif item_entry is String and GameManager:
					item_res = GameManager._find_item_by_name(item_entry)
				
				if item_res:
					if unit.has_method("add_item"):
						unit.add_item(item_res)
					else:
						# Direct array access fallback
						unit.inventory.append(item_res)

	# Select First Unit
	# 1c. Select First Unit
	# Postpone selection until GameUI is ready (end of function)
	pass

	# Spawn Enemies (Point Buy System)
	# Spawn Enemies (Point Buy System)
	# REMOVED: Managed by MissionManager (Phase 79)
	# _spawn_enemies_point_buy(grid_manager, mission)

	# Mission Setup (Terminals)
	# Legacy spawning removed. Now we wire up terminals spawned by MissionManager.
	if mission and mission.objective_type == ObjectiveManager.MissionType.HACKER:
		# Wait for MissionManager to finish spawning (it happens in start_mission?)
		# Actually, MissionManager.start_mission is called... where?
		# It seems Main.gd assumes MissionManager has populated the grid.
		pass
		



	# Turn Manager Setup
	turn_manager = TurnManager.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)

	# 4. Setup VisionManager
	vision_manager = load("res://scripts/managers/VisionManager.gd").new()
	vision_manager.name = "VisionManager"
	add_child(vision_manager)
	vision_manager.initialize(grid_manager, get_node("GridVisualizer"))

	# Force Visualizer to see Grid (Fix for 0 tiles hidden issue)
	var gv_node = get_node("GridVisualizer")
	if gv_node.tile_meshes.size() == 0:
		gv_node.visualize_grid()

	# 5. Setup GameUI
	game_ui = load("res://scripts/ui/GameUI.gd").new()  # Removed 'var'
	game_ui.name = "GameUI"
	add_child(game_ui)
	game_ui.initialize(turn_manager, grid_manager)

	fog_manager = load("res://scripts/managers/FogManager.gd").new()
	fog_manager.name = "FogManager"
	add_child(fog_manager)

	game_ui.connect("action_requested", _on_ui_action)
	game_ui.connect("ability_requested", _on_ability_requested)
	game_ui.connect("item_requested", _on_item_requested)
	game_ui.connect("end_turn_requested", _end_player_turn)
	game_ui.unit_selection_changed.connect(_handle_unit_selection_from_ui)

	SignalBus.on_turn_changed.connect(_on_turn_changed)

	# Connect InputManager
	var input_mgr = get_node_or_null("/root/InputManager")
	if input_mgr:
		if not input_mgr.on_tile_clicked.is_connected(_on_tile_clicked):
			input_mgr.on_tile_clicked.connect(_on_tile_clicked)
		
		# Ensure signal exists before connecting (it might not if InputManager is old version)
		if input_mgr.has_signal("on_cancel_command"):
			if not input_mgr.on_cancel_command.is_connected(_clear_targeting):
				input_mgr.on_cancel_command.connect(_clear_targeting)

	# 6. Setup Objectives
	var objective_manager = load("res://scripts/managers/ObjectiveManager.gd").new()
	objective_manager.name = "ObjectiveManager"
	add_child(objective_manager)

	# Random Mission Type (0=Deathmatch, 1=Rescue, 2=Retrieve, 3=Hacker)
	var mission_type = 0
	var obj_count = 0
	if mission:
		mission_type = mission.objective_type
		obj_count = mission.objective_target_count
	else:
		mission_type = randi() % 3
	objective_manager.initialize(mission_type, turn_manager, obj_count)

	# Spawn Objective Targets if needed (ONLY IF NOT BASE DEFENSE)
	var all_units = spawned_units.duplicate()
	var is_final = false
	if mission_manager.active_mission_config:
		is_final = mission_manager.active_mission_config.is_final_defense

	# Disable Objectives if Tutorial Mission (or unspecified)
	if (
		mission_manager.active_mission_config
		and mission_manager.active_mission_config.mission_name == "Training Day"
	):
		mission_type = 0  # DEATHMATCH (No objectives)
		is_final = true  # Hack: Block objective spawning logic below (since it checks !is_final)

	if not is_final and false: # Legacy spawning disabled (Managed by MissionManager)
		if mission_type == objective_manager.MissionType.RETRIEVE:
			var loot = load("res://scripts/entities/ObjectiveUnit.gd").new()
			loot.name = "Treat Bag"
			loot.faction = "Neutral"
			loot.can_be_targeted = false
			add_child(loot)

			# Safe Spawn
			var loot_grid = grid_manager.get_nearest_walkable_tile(Vector2(9, 1))
			loot.initialize(loot_grid)
			loot.position = grid_manager.get_world_position(loot_grid)
			objective_manager.loot_target = loot
			all_units.append(loot)
			print("Spawned Treat Bag at ", loot_grid)

		elif mission_type == objective_manager.MissionType.RESCUE:
			var human = load("res://scripts/entities/ObjectiveUnit.gd").new()
			human.name = "Lost Human"
			human.faction = "Neutral"
			add_child(human)

			# Safe Spawn
			var human_grid = grid_manager.get_nearest_walkable_tile(Vector2(9, 5))
			human.initialize(human_grid)
			human.position = grid_manager.get_world_position(human_grid)
			objective_manager.rescue_target = human
			all_units.append(human)
			print("Spawned Lost Human at ", human_grid)

	# Spawn Interactive Props
	if is_final:
		_spawn_golden_hydrant(grid_manager)
	else:
		spawn_interactive_test(grid_manager)

	# INITIALIZE SQUAD UI
	print("Main: Initializing Squad List with ", spawned_units.size(), " units.")
	game_ui.initialize_squad_list(spawned_units)

	# Initial Vision Update
	vision_manager.update_vision(all_units)

	# Select First Corgi by Default
	# Select First Player Corgi by Default
	var first_player = null
	for u in spawned_units:
		if is_instance_valid(u) and "faction" in u and u.faction == "Player":
			first_player = u
			break

	if first_player:
		game_ui.select_unit(first_player)
		selected_unit = first_player

	# Collect Enemies for TurnManager
	if mission_manager:
		# Always regenerate config from GameManager data to ensure latest mission is used
		# (Fixes issue where persistent MissionManager ignored new missions)
		# Always regenerate config from GameManager data to ensure latest mission is used
		# (Fixes issue where persistent MissionManager ignored new missions)
		
		var config = null
		
		# 1. Start with Provided Config
		if mission and mission is MissionConfig:
			print("Main: Using provided MissionConfig directly.")
			config = mission
		else:
			# 2. Legacy / Generation Logic
			var level = 1
			if mission and "difficulty_rating" in mission:
				level = mission.difficulty_rating
			
			config = mission_manager.generate_mission_config(level)
			
			# Sync Objective Type from Legacy Mission Data if present
			if mission:
				print("Main: Syncing from MissionData (Legacy) - Type: ", mission.objective_type)
				config.objective_type = mission.objective_type
				if "objective_target_count" in mission:
					config.objective_target_count = mission.objective_target_count
				# Also sync name if valid
				if mission.mission_name != "":
					config.mission_name = mission.mission_name
		
		# Show Mission Briefing
		_show_mission_briefing(config)
		
		# Override for Lootapalooza
		if GameManager and GameManager.debug_scenario == "lootapalooza":
			print("LOOTAPALOOZA: Setting up minimal resistance (1 Rusher).")
			config.waves.clear()
			var dummy_wave = WaveDefinition.new()
			dummy_wave.budget_points = 1 # 1 Rusher
			dummy_wave.allowed_archetypes.assign(["Rusher"])
			dummy_wave.wave_message = "Lootapalooza: 1 Guard Dog Detected!"
			config.waves.append(dummy_wave)
		
		# 3. Refresh Grid with Player Positions so Enemies don't spawn on top of them!
		grid_manager.refresh_pathfinding(spawned_units)

		print("Main: Starting MissionManager with Config -> Type: ", config.objective_type, " Count: ", config.objective_target_count)
		mission_manager.start_mission(config, grid_manager)

		mission_manager.register_player_units(spawned_units) # Essential for Signal connections!
			
		all_units.append_array(mission_manager.spawned_units)  # Enemies

		# WIRE UP TERMINALS (Moved here to ensure they exist!)
		if config.objective_type == ObjectiveManager.MissionType.HACKER:
			# Yield a frame to wait for spawn completion? MissionManager is sync usually.
			var terminals = get_tree().get_nodes_in_group("Terminals")
			print("Main: Wiring up ", terminals.size(), " Terminals (Post-Spawn).")
			for term in terminals:
				if not term.hack_complete.is_connected(_on_terminal_hack_complete):
					term.connect("hack_complete", func(s): _on_terminal_hack_complete(s, term.grid_pos))

	# Interactive props were already added to all_units in spawning block above (lines 418/432)

	turn_manager.start_game(all_units)
	
	# Force initial vision update to detect enemies (Smell Check)
	if vision_manager:
		vision_manager.update_vision(all_units)


func _spawn_enemies_point_buy(grid_manager: GridManager, mission: MissionData):
	var budget = 5  # Default
	if mission:
		budget = mission.difficulty_rating
		# Ensure minimum budget if rating is low?
		# User defined logic: Diff 1 = 1 Rusher (Cost 1). So Budget 1 is fine.
		# Whisperer (5) needs Budget 5.

	print("Main: Spawning Enemies with Budget: ", budget)

	# Candidates and Costs
	var candidates = [
		{"type": "Rusher", "cost": 1, "script": "res://scripts/entities/EnemyUnit.gd"},
		{"type": "Sniper", "cost": 1, "script": "res://scripts/entities/EnemyUnit.gd"},  # Need specialized setup
		{"type": "Spitter", "cost": 4, "script": "res://scripts/entities/SpitterUnit.gd"},
		{"type": "Whisperer", "cost": 5, "script": "res://scripts/entities/WhispererUnit.gd"}
	]

	# Loop until budget exhausted or no valid options
	var spawn_index = 0

	while budget > 0:
		# Filter affordable
		var affordable = candidates.filter(func(c): return c.cost <= budget)
		if affordable.is_empty():
			break

		# Pick Random
		var choice = affordable.pick_random()

		# Spend
		budget -= choice.cost

		# Logic to Instantiate
		_spawn_enemy_unit(choice, grid_manager, spawn_index)
		spawn_index += 1


func _spawn_enemy_unit(type_data: Dictionary, grid_manager: GridManager, index: int):
	# Handle Nemesis check globally first? Or per spawn?
	# Assuming Nemesis cost is 2 (User spec).
	# Let's verify if we have a Nemesis queued.
	# The plan said Nemesis is cost 2.
	# If we pick a "Nemesis" candidate, we spawn it.
	# For now, let's inject Nemesis into the candidates list if available?
	# Or simple logic: Just spawn generic for now, refine Nemesis later if needed for Point Buy integration.
	# Retaining generic logic:

	var unit_script = load(type_data.script)
	var enemy = unit_script.new()
	add_child(enemy)

	# Setup Data
	var data = load("res://scripts/resources/EnemyData.gd").new()

	# Specific Configs
	if type_data.type == "Rusher":
		var theme = ["Fleshy", "Suburbia"].pick_random()
		data.display_name = GameManager.get_enemy_name(theme)
		data.ai_behavior = data.AIBehavior.RUSHER
		data.max_hp = 8
		data.mobility = 6
		data.visual_color = Color.ORANGE
		var bite = WeaponData.new()
		bite.display_name = "Feral Bite"
		bite.damage = 3
		bite.weapon_range = 1
		data.primary_weapon = bite
		enemy.initialize_from_data(data)

	elif type_data.type == "Sniper":
		var theme = ["Abstract", "Aquatic"].pick_random()
		data.display_name = GameManager.get_enemy_name(theme)
		data.ai_behavior = data.AIBehavior.SNIPER
		data.max_hp = 6
		data.mobility = 3
		data.visual_color = Color.CYAN
		var rifle = WeaponData.new()
		rifle.display_name = "Eldritch Eye"
		rifle.damage = 4
		rifle.weapon_range = 10
		data.primary_weapon = rifle
		enemy.initialize_from_data(data)

	elif type_data.type == "Spitter":
		# Spitter script handles its own ready init usually, but data override helps
		data.display_name = "Acid Spitter"
		# SpitterUnit applies stats in _ready, but we can override
		enemy.initialize_from_data(data)  # Spitter logic

	elif type_data.type == "Whisperer":
		var w_path = "res://assets/data/enemies/WhispererData.tres"
		if ResourceLoader.exists(w_path):
			var w_data = load(w_path)
			enemy.initialize_from_data(w_data)

	spawned_units.append(enemy)

	# Find Valid Position (Not taken by any unit)
	var pos = Vector2(-1, -1)
	var attempts = 0

	while attempts < 50:
		attempts += 1
		# Random attempt
		var candidate = Vector2(randi() % 20, randi() % 20)
		var valid_tile = grid_manager.get_nearest_walkable_tile(candidate)

		# Check Occupancy
		var occupied = false

		# check against existing units in turn_manager (if started)
		# But here we are IN init phase often. So check 'all_units' or 'spawned_units'
		# AND 'turn_manager.units' if referencing active game state.
		# Best source of truth: GridManager? No, unit positions aren't stored there usually.
		# Let's check get_tree().get_nodes_in_group("Units")

		# check against existing units in turn_manager (if started)
		for u in get_tree().get_nodes_in_group("Units"):
			if not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			# If unit is actually placed (has valid grid_pos)
			if u.grid_pos == valid_tile:
				occupied = true
				break

		# Also check against other just-spawned units (in this batch)
		for u in spawned_units:
			if is_instance_valid(u) and u != enemy and u.grid_pos == valid_tile:
				occupied = true
				break

		# Distance Check (Avoid Player Start)
		if not occupied:
			# If valid, also check distance
			if valid_tile.distance_to(Vector2(2, 18)) > 8:
				pos = valid_tile
				break

	if pos == Vector2(-1, -1):
		print("Spawn Failed: Could not find empty tile after 50 attempts.")
		pos = grid_manager.get_nearest_walkable_tile(Vector2(0, 0))  # Fallback

	enemy.initialize(pos)
	enemy.position = grid_manager.get_world_position(pos)
	print("PointBuy: Spawned ", type_data.type, " at ", pos)


func _spawn_terminals(gm: GridManager):
	var term_script = load("res://scripts/entities/Terminal.gd")
	var positions = []
	for i in range(3):
		var rp = Vector2(randi_range(2, 17), randi_range(2, 17))
		positions.append(gm.get_nearest_walkable_tile(rp))

	for pos in positions:
		var term = term_script.new()
		add_child(term)
		term.initialize(pos, gm)
		term.connect("hack_complete", func(s): _on_terminal_hack_complete(s, pos))
		print("Spawned Terminal at ", pos)


func _spawn_golden_hydrant(gm: GridManager):
	var hydrant_script = load("res://scripts/entities/GoldenHydrant.gd")
	var center = Vector2(10, 10)
	var pos = gm.get_nearest_walkable_tile(center)

	var hydrant = hydrant_script.new()
	add_child(hydrant)
	hydrant.initialize(pos, gm)
	print("Spawned GOLDEN HYDRANT at ", pos)


# Legacy wave spawn moved to MissionManager
func _spawn_wave_reinforcement():
	print("Legacy Wave Spawn Blocked (Use MissionManager)")
	pass


func _on_terminal_hack_complete(success: bool, pos: Vector2):
	var om = get_node_or_null("ObjectiveManager")
	if om:
		om.register_hack(success)

	if success:
		print("Main: Terminal Hacked at ", pos)
		# Spawn 2 "Security Drone" Reinforcements
		var rusher_data = load("res://scripts/resources/EnemyData.gd").new()
		rusher_data.display_name = "Security Drone"
		rusher_data.ai_behavior = rusher_data.AIBehavior.RUSHER
		rusher_data.max_hp = 4
		rusher_data.mobility = 4
		rusher_data.visual_color = Color.ORANGE

		for i in range(2): 
			var spawn_pos = Vector2(-1, -1)
			# Spiral search around terminal
			for attempts in range(30):
				var offset = Vector2(randi_range(-3, 3), randi_range(-3, 3))
				var candidate = pos + offset
				if offset == Vector2.ZERO: continue # Don't spawn on terminal

				if grid_manager.is_walkable(candidate):

					# Check dynamic occupancy
					var occupied = false
					for u in spawned_units:
						if is_instance_valid(u) and u.grid_pos == candidate and u.current_hp > 0:
							occupied = true
							break
					if not occupied:
						spawn_pos = candidate
						break
			
			if spawn_pos != Vector2(-1, -1):
				var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
				add_child(enemy)
				enemy.initialize_from_data(rusher_data)
				enemy.initialize(spawn_pos)
				enemy.position = grid_manager.get_world_position(spawn_pos)
				spawned_units.append(enemy)
				
				# Ensure TurnManager knows about it
				if turn_manager and not turn_manager.units.has(enemy):
					turn_manager.units.append(enemy)
				
				print("Main: Security Drone dispatched to ", spawn_pos)
				SignalBus.on_request_floating_text.emit(enemy.position, "ALERT!", Color.RED)

	else:
		print("Main: Terminal Hack Failed at ", pos)
		# Punishment? Logic says 1 Rusher? 
		# If user didn't ask for punishment fix, I'll leave it empty or add simple punishment.
		spawn_reinforcement("Rusher", pos + Vector2(0, 3)) # Keeping legacy fallback for fail case



func spawn_reinforcement(type: String, near_grid_pos: Vector2):
	var gm = get_node("GridManager")
	# Find valid position near target that is NOT occupied
	var valid_pos = _find_empty_tile_near(gm, near_grid_pos)
	if valid_pos == Vector2(-999, -999):
		print("Reinforcement Failed: No space near ", near_grid_pos)
		return

	print("Reinforcement Incoming: ", type)
	SignalBus.on_request_floating_text.emit(gm.get_world_position(valid_pos), "WARNING!", Color.RED)

	var data = {"type": type, "cost": 1, "script": "res://scripts/entities/EnemyUnit.gd"}
	_spawn_enemy_unit(data, gm, randi())

	# Fix Position (Update spawned unit to valid_pos instead of random)
	var new_unit = spawned_units.back()
	new_unit.initialize(valid_pos)  # Reset to valid pos
	new_unit.position = gm.get_world_position(valid_pos)

	if turn_manager:
		turn_manager.units.append(new_unit)
		vision_manager.update_vision(turn_manager.units)


func _find_empty_tile_near(gm: GridManager, start_pos: Vector2) -> Vector2:
	# Local BFS to find empty spot
	var queue = [start_pos]
	var visited = {start_pos: true}
	var occupied_positions = {}

	if turn_manager:
		for u in turn_manager.units:
			if is_instance_valid(u):
				occupied_positions[u.grid_pos] = true

	while not queue.is_empty():
		var current = queue.pop_front()

		# Check if valid
		if gm.is_walkable(current) and not occupied_positions.has(current):
			return current

		# Add neighbors
		var neighbors = [
			current + Vector2(1, 0),
			current + Vector2(-1, 0),
			current + Vector2(0, 1),
			current + Vector2(0, -1),
			current + Vector2(1, 1),
			current + Vector2(-1, -1),
			current + Vector2(1, -1),
			current + Vector2(-1, 1)
		]

		for n in neighbors:
			if not visited.has(n):
				visited[n] = true
				if gm.grid_data.has(n):
					queue.append(n)

		if visited.size() > 50:  # Safety break
			break

	return Vector2(-999, -999)


# Interaction State
enum InputState {
	SELECTING, MOVING, TARGETING, INTERACTING, ABILITY_TARGETING, CINEMATIC, ITEM_TARGETING
}
var current_input_state = InputState.SELECTING
# var selected_unit # Moved to member variable
var selected_ability  # Track which ability is pending
var pending_item_action = null  # Track pending item
var pending_item_slot = -1


func _on_movement_complete():
	var vm = get_node("VisionManager")
	var tm = get_node("TurnManager")
	if vm and tm:
		vm.update_vision(tm.units)

	# REFRESH UI (Buttons dependent on position need update)
	if game_ui and selected_unit:
		game_ui.update_unit_info(selected_unit)

	# Fog is now Delayed Reveal at start of next turn.


func _on_ui_action(action):
	# Always clear previous targeting state/visuals first
	_clear_targeting()

	if action == "Move":
		current_input_state = InputState.MOVING
		print("Select a tile to Move...")
		
		# VISUALIZE MOVEMENT
		if selected_unit and grid_manager and turn_manager:
			# Ensure pathfinding knows about other units
			grid_manager.refresh_pathfinding(turn_manager.units, selected_unit)
			
			var move_range = selected_unit.mobility
			var reachable = grid_manager.get_reachable_tiles(selected_unit.grid_pos, move_range)
			
			var gv = get_node("GridVisualizer")
			if gv:
				gv.show_highlights(reachable, Color.CYAN)
	elif action == "Attack":
		current_input_state = InputState.TARGETING
		print("Select a target to Attack...")
	elif action == "Interact":
		_try_interact()
	elif action == "EndTurn":
		_end_player_turn()
	elif action == "Abort":
		print("Main: Abort Requested!")
		if turn_manager:
			turn_manager.force_retreat()


func _end_player_turn():
	print("Main: Player ended turn. Applying Fog Penalties...")

	if fog_manager:
		fog_manager.apply_sanity_penalties(turn_manager.units)

	if turn_manager:
		turn_manager.end_player_turn()




func _on_ability_requested(ability):
	selected_ability = ability
	print("Ability Selected: ", ability.display_name)

	# If ability is self-target only or range 0, maybe execute immediately?
	# Or let user click self?
	# Let's support user clicking for consistency, unless it's strictly self.
	# SplootHeal has range 0.

	current_input_state = InputState.ABILITY_TARGETING
	print("Select a target tile for ", ability.display_name)

	current_input_state = InputState.ABILITY_TARGETING
	print("Select a target tile for ", ability.display_name)

	# Highlights
	var valid = ability.get_valid_tiles(grid_manager, selected_unit)
	var gv = get_node("GridVisualizer")
	if gv:
		gv.show_highlights(valid, Color.YELLOW)


func _on_item_requested(item, slot_index):
	print("Main: Item requested: ", item.display_name)

	current_input_state = InputState.ITEM_TARGETING
	selected_ability = null
	pending_item_action = item
	pending_item_slot = slot_index

	# Visuals
	var valid_tiles = []
	if item.ability_ref:
		var ability = item.ability_ref.new()
		valid_tiles = ability.get_valid_tiles(grid_manager, selected_unit)
	else:
		# Simple Range Check (BFS not needed if just radius, but line of sight might be?)
		# For items we'll assume throw/use radius.
		var range_val = item.range_tiles
		for tile in grid_manager.grid_data:
			if tile.distance_to(selected_unit.grid_pos) <= range_val:
				valid_tiles.append(tile)

	var gv = get_node("GridVisualizer")
	if gv:
		gv.show_highlights(valid_tiles, Color.CYAN)

	game_ui.log_message("Select Target for " + item.display_name)


func _on_tile_clicked(grid_pos: Vector2, button_index: int):
	# 1. Cancel / Right Click
	if button_index == MOUSE_BUTTON_RIGHT:
		_clear_targeting()
		return

	# 2. Blockers
	if current_input_state == InputState.CINEMATIC:
		return
	if selected_unit and selected_unit.get("is_moving"):
		print("Unit is moving, input ignored.")
		return

	# 3. State Handling
	if current_input_state == InputState.ITEM_TARGETING:
		if pending_item_action and selected_unit:
			var world_pos = grid_manager.get_world_position(grid_pos)
			selected_unit.use_item(pending_item_slot, world_pos, grid_manager)
			_clear_targeting()

	elif current_input_state == InputState.ABILITY_TARGETING:
		if selected_ability and selected_unit:
			var world_pos = grid_manager.get_world_position(grid_pos)
			var target_unit = _get_unit_at_grid(grid_pos)
			var result = selected_ability.execute(
				selected_unit, target_unit, grid_pos, grid_manager
			)
			print("Ability Result: ", result)
			game_ui.log_message(result)
			_clear_targeting()

	elif current_input_state == InputState.TARGETING:  # Attack
		var target_obj = _get_unit_at_grid(grid_pos)
		
		# If no unit, check for destructibles
		if not target_obj:
			var props = get_tree().get_nodes_in_group("Destructible")
			for p in props:
				var prop = p
				if p is StaticBody3D:
					prop = p.get_parent()
				if is_instance_valid(prop) and "grid_pos" in prop and prop.grid_pos == grid_pos:
					target_obj = prop
					break
		
		if target_obj and target_obj != selected_unit:
			_process_combat(target_obj)
			_clear_targeting()

	elif current_input_state == InputState.MOVING:
		if selected_unit:
			_process_move_or_interact(grid_pos)
			_clear_targeting()

	elif current_input_state == InputState.SELECTING:
		var target_unit = _get_unit_at_grid(grid_pos)

		# Friendly Switching
		# Ensure target has 'faction' property before checking
		if target_unit and "faction" in target_unit and target_unit.faction == "Player" and target_unit != selected_unit:
			_handle_unit_selection_from_ui(target_unit)
			return

		# Select Unit (Only Player or Enemy, ignore Props/Crates)
		if target_unit and "faction" in target_unit and target_unit.faction != "Neutral":
			SignalBus.on_ui_select_unit.emit(target_unit)
			selected_unit = target_unit
		# Context Move
		elif selected_unit and is_instance_valid(selected_unit):
			# Allow click-to-move in Selection state (RTS style)
			_process_move_or_interact(grid_pos)


func _clear_targeting():
	current_input_state = InputState.SELECTING
	selected_ability = null
	pending_item_action = null
	pending_item_slot = -1
	var gv = get_node("GridVisualizer")
	if gv:
		gv.clear_highlights()
	game_ui.log_message("Command Cancelled.")


func _try_interact():
	# Check adjacent units for objectives
	if not selected_unit:
		return

	var om = get_node("ObjectiveManager")
	var tm = get_node("TurnManager")

	# Find adjacent objective units
	# Find adjacent objective units
	var potential_targets = tm.units.duplicate()
	potential_targets.append_array(get_tree().get_nodes_in_group("Objectives"))
	
	for unit in potential_targets:
		if not is_instance_valid(unit):
			continue
		if unit == selected_unit:
			continue
		
		# Distance Check (0 = On Top, 1 or 1.414 = Adjacent)
		# NOTE: Ladders are 'Connectors', Corgi stands on same tile.
		if is_instance_valid(unit) and "grid_pos" in unit:
			if unit.grid_pos.distance_to(selected_unit.grid_pos) <= 1.5:
				om.handle_interaction(selected_unit, unit)
				selected_unit.spend_ap(1)
				return

	print("Nothing in range to interact with!")


func _on_debug_action(action: String):
	print("DEBUG ACTION: ", action)
	if action == "ForceWin":
		print("DEBUG: Force WIN")
		SignalBus.on_mission_ended.emit(true, 500)
	elif action == "ForceFail":
		print("DEBUG: Force FAIL Defense")
		var hydrant = get_tree().get_first_node_in_group("Objectives")
		if hydrant and is_instance_valid(hydrant) and hydrant.has_method("take_damage"):
			hydrant.take_damage(9999)
		else:
			SignalBus.on_mission_ended.emit(false, 0)


func _process_combat(target_obj):
	# Logic refactored from old _handle_click
	# Check healing override
	var can_target_friendly = false
	if selected_unit.primary_weapon and selected_unit.primary_weapon.display_name == "Syringe Gun":
		can_target_friendly = true

	var t_faction = target_obj.get("faction") if "faction" in target_obj else "Neutral"
	var s_faction = selected_unit.faction

	var valid_target = false
	if t_faction != s_faction:
		valid_target = true
	elif can_target_friendly and t_faction == s_faction:
		valid_target = true

	if valid_target:
		if selected_unit.current_ap >= 1:
			var gm = get_node("GridManager")
			
			# Range Check Debug
			var dist = selected_unit.grid_pos.distance_to(target_obj.grid_pos)
			# Assuming Weapon Range is checked in CombatResolver, but verify here?
			# print("DEBUG: Attempting Attack. Dist: ", dist, " Unit AP: ", selected_unit.current_ap)
			
			CombatResolver.execute_attack(selected_unit, target_obj, gm)
			selected_unit.spend_ap(1)
			current_input_state = InputState.SELECTING
		else:
			print("DEBUG: Attack Failed - Not enough AP! Current: ", selected_unit.current_ap)
	else:
		print("DEBUG: Attack Failed - Invalid Faction Target. Self: ", s_faction, " Target: ", t_faction)


func _get_unit_at_grid(coord: Vector2):
	if not turn_manager:
		# Fallback just in case
		turn_manager = get_node_or_null("TurnManager")

	if not turn_manager:
		return null

	for unit in turn_manager.units:
		if is_instance_valid(unit) and unit.grid_pos == coord and unit.current_hp > 0:
			return unit
	return null


func _is_valid_move(unit, grid_pos: Vector2) -> bool:
	var gm = get_node("GridManager")
	if not gm.grid_data.has(grid_pos):
		return false
	if not gm.grid_data[grid_pos]["is_walkable"]:
		return false

	# Check Occupancy
	if _get_unit_at_grid(grid_pos) != null:
		print("Tile occupied!")
		return false

	# Check distance (Mobility)
	# 1. Check if Tile is Valid Destination (e.g. not a ladder)
	if not gm.is_valid_destination(grid_pos):
		print("Invalid destination (e.g. Ladder/Obstacle)")
		return false

	# 2. Calculate Actual Path Cost
	var path = gm.get_move_path(unit.grid_pos, grid_pos)
	if path.is_empty():
		return false  # Unreachable

	var cost = gm.calculate_path_cost(path)

	if cost > unit.current_ap * 5:  # Assuming 5 tiles per AP?
		# Wait, Mobility is usually total tiles allowed per turn?
		# Or is Mobility per Action Point?
		# Original check: distance > unit.mobility
		# Unit.mobility is e.g. 6 or 8.
		# But Unit HAS current_ap.
		# If we assume 1 AP = 1 Move Action of "Mobility" distance.
		# Then path cost must be <= unit.mobility.
		if cost > unit.mobility:
			print("Too far! Cost: ", cost, " vs Mobility: ", unit.mobility)
			return false

	# Check AP
	if unit.current_ap < 1:
		print("No AP!")
		return false

	return true


func spawn_interactive_test(gm: GridManager):
	return  # Disabled for now (Refactoring Props)
	# Door - Try center-ish
	# var door_pos = gm.get_nearest_walkable_tile(Vector2(4, 4))
	# ...


func _process_move_or_interact(target_grid_pos: Vector2):
	var gm = get_node("GridManager")
	# Grid coord passed directly from InputManager refactor

	if not (
		selected_unit and is_instance_valid(selected_unit) and selected_unit.get("faction") == "Player"
	):
		return

	# INTERACTION CHECK (Before Movement)
	var interactive_obj = null
	var objects = get_tree().get_nodes_in_group("Interactive")

	# Debug
	print(
		"DEBUG: Interaction check at ",
		target_grid_pos,
		". Found ",
		objects.size(),
		" interactive objects."
	)

	for obj in objects:
		if obj.grid_pos == target_grid_pos:
			interactive_obj = obj
			print("DEBUG: Found object at target: ", obj)
			break

	if interactive_obj:
		var dist = selected_unit.grid_pos.distance_to(target_grid_pos)
		print("DEBUG: Object found. Distance: ", dist)

		# Attempt Interaction
		if dist <= 1.5:
			# interactive_obj.interact(selected_unit) # OLD DIRECT CALL
			var om = get_node("ObjectiveManager")
			if om:
				om.handle_interaction(selected_unit, interactive_obj)
			else:
				print("Main: Critical - OM not found for context interaction!")
				interactive_obj.interact(selected_unit) # Fallback
			return
		else:
			print("Too far to interact! (Dist: " + str(dist) + ")")

	# MOVEMENT
	# Refresh Pathfinding to respect units
	var tm = get_node("TurnManager")
	gm.refresh_pathfinding(tm.units, selected_unit)

	var path = gm.get_move_path(selected_unit.grid_pos, target_grid_pos)

	if path.size() == 0:
		print("Unreachable!")
	elif path.size() - 1 > selected_unit.mobility:
		print("Too far! Path length: ", path.size() - 1)
	elif _get_unit_at_grid(target_grid_pos) != null:
		print("Cannot Move: Tile Occupied by Unit (Select 'Attack' to fight).")
	elif selected_unit.current_ap < 1:
		print("No AP!")
	else:
		var world_path: Array[Vector3] = []
		var grid_subset: Array[Vector2] = []
		for i in range(1, path.size()):
			world_path.append(gm.get_world_position(path[i]))
			grid_subset.append(path[i])  # Sync grid Path

		# Lock Input
		current_input_state = InputState.MOVING
		selected_unit.move_along_path(world_path, grid_subset)
		selected_unit.spend_ap(1)

		if not selected_unit.movement_finished.is_connected(_on_movement_complete):
			selected_unit.movement_finished.connect(_on_movement_complete, CONNECT_ONE_SHOT)

		current_input_state = InputState.SELECTING


func play_intro_sequence(target_unit):
	print("Main: Starting Cinematic Intro for " + target_unit.name)
	current_input_state = InputState.CINEMATIC

	# Hide UI (Optional)
	SignalBus.on_cinematic_mode_changed.emit(true)

	# 1. Store Original Cam Transform
	var start_pos = main_camera.position
	var start_size = main_camera.size

	# 2. Tween to Target
	var tween = create_tween()
	var target_pos = target_unit.position + Vector3(0, 5, 5)  # Offset zoom

	(
		tween
		. parallel()
		. tween_property(main_camera, "position", target_pos, 1.5)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)
	tween.parallel().tween_property(main_camera, "size", 8, 1.5)  # Zoom In (Smaller Size = Zoom in Ortho)

	await tween.finished

	# 3. Dramatic Pause / Title Card
	SignalBus.on_request_floating_text.emit(
		target_unit.position + Vector3(0, 3, 0), "NEMESIS DETECTED!", Color.RED
	)
	await get_tree().create_timer(1.0).timeout
	var title_part = "The Nemesis"
	if "," in target_unit.name:
		title_part = target_unit.name.split(",")[1].strip_edges()
	SignalBus.on_request_floating_text.emit(
		target_unit.position + Vector3(0, 2.5, 0), title_part, Color.ORANGE
	)

	# Restore UI after intro (Safety)
	SignalBus.on_cinematic_mode_changed.emit(false)

	# Taunt Animation Placeholder
	print("Main: [Nemesis Taunt Animation]")
	# target_unit.play_anim("Taunt")


func _handle_unit_selection_from_ui(unit):
	if not is_instance_valid(unit):
		return
	if selected_unit == unit:
		return

	print("Main: UI Selected Unit -> ", unit.name)
	selected_unit = unit
	# Reset state
	current_input_state = InputState.SELECTING

	# Focus Camera
	if main_camera and is_instance_valid(unit):
		# Standard Isometric Centering
		# Use the camera's own Forward vector (Basis Z) to back up.
		# This ensures the unit is centered in the view regardless of rotation.
		var distance = 14.0  # Distance to maintain
		var current_basis = main_camera.global_transform.basis
		var offset = current_basis.z * distance

		# Target is Unit Position, adjusted so Camera looks AT it.
		var target = unit.position + offset

		# Maintain specific height? Ortho size handles zoom, Position handles center.
		# If Orthogonal, moving along Z axis just changes near/far clips plane rel, doesn't shift view?
		# No, moving along Basis Z changes the "Center" of the volume?
		# Wait, for Ortho, moving along View Axis (Z) does NOT change the image centering.
		# Moving along X/Y (View Right/Up) changes centering.
		# If we want to center the unit, we must position the camera such that the Unit is at (0,0) in View Space.
		# View Space = Inverse Camera Transform * World Pos.
		# We want (CamPos) such that it looks at Unit.

		# Easiest way:
		# CamPos = UnitPos + Offset
		# Where Offset has the same orientation as the camera.

		target = unit.position + (Vector3(1, 1, 1).normalized() * 15.0)  # Standard Iso Back-Right-Up
		# But we need to match the actual rotation.
		# Let's revert to a simpler verified offset or trust the basis.

		# If I assume rotation is (-45, -45, 0):
		# Basis.Z points Back-Right-Up.
		target = unit.position + (current_basis.z * 20.0)

		var tween = create_tween()
		tween.tween_property(main_camera, "position", target, 0.5).set_trans(Tween.TRANS_CUBIC)

	# SignalBus.on_cinematic_mode_changed.emit(false)
	# current_input_state = InputState.SELECTING
	# print("Main: Cinematic Ended.")


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_K:
			if (
				selected_unit
				and is_instance_valid(selected_unit)
				and selected_unit.faction == "Player"
			):
				print("DEBUG: Inflicting Sanity Damage on ", selected_unit.name)
				selected_unit.take_sanity_damage(100)  # Instant Panic
		if event.pressed and event.keycode == KEY_L:
			if selected_unit and is_instance_valid(selected_unit):
				print("DEBUG: Killing Unit ", selected_unit.name)
				selected_unit.take_damage(999)  # Instant Kill


# --- HELPERS ---
func _log(msg: String):
	print("[Main] ", msg)





func _trigger_victory_scene():
	if GameManager:
		GameManager.invasion_progress = 0
		print("BASE DEFENSE SUCCESSFUL!")
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://scenes/ui/VictoryScene.tscn")


func _end_mission(victory: bool):
	var reward = 0
	if mission_manager.active_mission_config:
		reward = mission_manager.active_mission_config.reward_kibble
	SignalBus.on_mission_ended.emit(victory, reward)


func _show_mission_briefing(config: MissionConfig):
	current_input_state = InputState.CINEMATIC # Block Input
	
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	canvas.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 300)
	panel.add_child(vbox)
	
	# Header
	var lbl = Label.new()
	lbl.text = "MISSION BRIEFING"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(lbl)
	vbox.add_child(HSeparator.new())
	
	# Mission Name
	var name_l = Label.new()
	name_l.text = config.mission_name
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_l)
	
	# Description
	var desc = Label.new()
	desc.text = config.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.y = 100
	vbox.add_child(desc)
	
	vbox.add_child(HSeparator.new())
	
	# Tips
	var tip = Label.new()
	tip.text = "Tactical Tip: End your turn behind obstacles to gain Cover defense bonuses."
	tip.modulate = Color(0.8, 0.8, 0.8)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(tip)
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Start Button
	var btn = Button.new()
	btn.text = "INITIATE OPERATION"
	btn.custom_minimum_size.y = 50
	btn.pressed.connect(func():
		canvas.queue_free()
		current_input_state = InputState.SELECTING
		# Intro Cinematics?
	)
	vbox.add_child(btn)

func _on_unit_death(unit):
	if not "faction" in unit:
		return # Ignore Props/Barrels

	print("Main: _on_unit_death called for ", unit.name)

	# 1. Register Death in GameManager (Persistence)
	if GameManager and unit.faction == "Player":
		var cause = "Killed in Action"
		if unit.has_method("get_data_snapshot"):
			GameManager.register_fallen_hero(unit.get_data_snapshot(), cause)

	# 2. Check for Wipe Condition (Iron Dog)
	# If this was the last player unit...
	# We rely on TurnManager or check directly
	var players_alive = 0
	if turn_manager:
		for u in turn_manager.units:
			# Fix Crash: Ensure u has faction before checking it
			if is_instance_valid(u) and u.current_hp > 0 and "faction" in u and u.faction == "Player":
				players_alive += 1

	# Note: The unit who just died might still be in the list until next frame, so we check carefully.
	# If current_hp <= 0, they are technically dead.

	if players_alive == 0:
		print("Main: LAST SQUAD MEMBER FALLEN!")
		# Iron Dog check happens in GameManager on mission complete, but we need to trigger mission end.
		# If objective was "Survive", we failed.
		# The standard check handles empty squad return.
