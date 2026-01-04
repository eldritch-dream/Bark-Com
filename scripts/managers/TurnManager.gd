extends Node
class_name TurnManager

signal turn_changed(new_turn_state)

enum TurnState { PLAYER_TURN, ENEMY_TURN, ENVIRONMENT_TURN }

var current_turn = TurnState.PLAYER_TURN
var turn_count: int = 1
var units: Array = []
var game_over: bool = false
var is_cinematic_active: bool = false # Track state locally
var is_handling_action: bool = false # Track if an async action (grenade etc) is running


func _ready():
	print("TurnManager initialized! Instance ID: ", get_instance_id())
	
	# Singleton Enforcement: Prevent duplicate Managers
	if get_tree().get_nodes_in_group("TurnManager").size() > 0:
		print("TurnManager: Duplicate detected! Destroying self (Instance ", get_instance_id(), ")")
		queue_free()
		return

	add_to_group("TurnManager")

	SignalBus.on_cinematic_mode_changed.connect(_on_cinematic_mode_changed)
	SignalBus.on_combat_action_started.connect(_on_combat_action_started)
	SignalBus.on_combat_action_finished.connect(_on_combat_action_finished)
	SignalBus.on_mission_ended.connect(_on_mission_ended)
	pass


func _on_cinematic_mode_changed(active: bool):
	is_cinematic_active = active
	if not active:
		# Check if we should end turn now that cinematic is done
		check_auto_end_turn()


func register_unit(unit):
	if not units.has(unit):
		units.append(unit)
		print("TurnManager: Registered new unit ", unit.name)


func _on_combat_action_started(_attacker, _target, _action, _pos):
	if current_turn == TurnState.PLAYER_TURN:
		# print("TM: Combat Action Started (Async). Locking Turn.")
		is_handling_action = true


func _on_combat_action_finished(_attacker):
	if is_handling_action:
		# print("TM: Combat Action Finished. Improving Turn.")
		is_handling_action = false
		# Now we can check if turn should end
		# Wait a frame to allow stats to update?
		await get_tree().process_frame
		check_auto_end_turn()


func _on_mission_ended(_victory, _rewards):
	print("TurnManager: Mission Ended. Stopping.")
	game_over = true
	# Force stop any looping logic if possible, 
	# but the flag checks in loops are primary defense.


func start_game(all_units: Array):
	units = all_units
	turn_count = 0
	game_over = false
	print("\n=== GAME START ===")
	start_player_turn()


func start_player_turn():
	current_turn = TurnState.PLAYER_TURN
	turn_count += 1  # INCREMENT TURN

	# REFRESH GRID: Ensure unit positions are blocked
	var gm = get_node_or_null("../GridManager")
	if gm:
		gm.refresh_pathfinding(units)

	print("\n--- TURN ", turn_count, ": PLAYER PHASE ---")
	SignalBus.on_turn_changed.emit("PLAYER PHASE", turn_count)

	for unit in units:
		if (
			is_instance_valid(unit)
			and "faction" in unit
			and unit.faction == "Player"
			and unit.current_hp > 0
		):
			unit.refresh_ap()
			# Need GridManager. Find it from unit context or search?
			# Main.gd creates it as sibling of TurnManager usually.
			unit.apply_panic_effect(units, gm)
			unit.process_turn_start_effects(gm)

	# Camera Focus on Lead Corgi (Visuals)d
	# We focus on the first unit in the list (usually the one spawned first/Lead)
	for unit in units:
		if (
			is_instance_valid(unit)
			and "faction" in unit
			and unit.faction == "Player"
			and unit.current_hp > 0
		):
			SignalBus.on_request_camera_focus.emit(unit.position)
			break


func check_auto_end_turn():
	# DEBUG: Trace Turn End Logic
	print("TM: check_auto_end_turn() called. CurrentTurn: ", current_turn, " (0=Player, 1=Enemy). Cinematic: ", is_cinematic_active)

	# If ALL player units have AP <= 0, end turn automatically
	if current_turn != TurnState.PLAYER_TURN:
		print("TM: Aborting check (Not Player Turn).")
		return

	if is_cinematic_active:
		print("TM: Cinematic active, deferring end turn.")
		return

	if is_handling_action:
		print("TM: Action in progress, deferring end turn.")
		return

	var any_can_act = false
	var active_unit_name = ""
	for u in units:
		if is_instance_valid(u) and "faction" in u and u.faction == "Player" and u.current_hp > 0:
			if u.current_ap > 0:
				any_can_act = true
				active_unit_name = u.name
				break

	if not any_can_act:
		print("TM: All units acted. Ending Player Turn...")
		call_deferred("end_player_turn")
	else:
		print("TM: Waiting for unit: ", active_unit_name)


func end_player_turn():
	# Process End Turn Effects for Player Units
	for unit in units:
		if (
			is_instance_valid(unit)
			and "faction" in unit
			and unit.faction == "Player"
			and unit.current_hp > 0
		):
			unit.process_turn_end_effects()

	print("Player ended turn.")
	# Small delay before Enemy Phase starts
	await get_tree().create_timer(0.5).timeout
	start_enemy_turn()


func start_enemy_turn():
	if game_over or current_turn == TurnState.ENEMY_TURN:
		print("TurnManager: start_enemy_turn blocked (Game Over or Already Active).")
		return

	current_turn = TurnState.ENEMY_TURN
	
	# Wait for any death cleanups (e.g. from Barrels) to resolve
	await get_tree().process_frame
	
	# Refresh units list to catch dynamically spawned enemies (Acidsplosion)
	var all_nodes = get_tree().get_nodes_in_group("Units")
	units = []
	for u in all_nodes:
		if is_instance_valid(u) and not u.is_queued_for_deletion() and u.current_hp > 0:
			units.append(u)
	
	print("\n--- TURN ", turn_count, ": ENEMY PHASE (Units: ", units.size(), ") ---")
	SignalBus.on_turn_changed.emit("ENEMY PHASE", turn_count)

	# Enemy Start Turn Effects
	for unit in units:
		if (
			is_instance_valid(unit)
			and "faction" in unit
			and unit.faction == "Enemy"
			and unit.current_hp > 0
		):
			unit.refresh_ap()  # Ensure AP ready
			unit.process_turn_start_effects()

	# Delay for visual emphasis
	await get_tree().create_timer(1.0).timeout

	# Execute Enemy Actions
	# In a real game, this might be async with yields/awaits for animations.
	for unit in units:
		if game_over:
			print("TurnManager: Game Over detected. Aborting Enemy Turn.")
			break

		if (
			is_instance_valid(unit)
			and "faction" in unit
			and unit.faction == "Enemy"
			and unit.current_hp > 0
		):
			if unit.has_method("decide_action"):
				# Find GridManager?
				# Ideally passed in start_game.
				# Workaround: find sibling
				var gm = unit.get_node("../GridManager")

				# Camera Focus (Phase 68)
				if unit.visible:
					SignalBus.on_request_camera_focus.emit(unit.position)
					# Wait for pan + moment of recognition
					await get_tree().create_timer(1.5).timeout

				print("TM [", get_instance_id(), "]: Awaiting action for ", unit.name, " (", unit.get_instance_id(), ")")


				unit.decide_action(units, gm)
				
				if unit.has_signal("action_complete"):
					await unit.action_complete
				else:
					await get_tree().create_timer(1.0).timeout

				# await unit.decide_action(units, gm) # Replaced with signal wait
				
				# SAFETY CHECK: If unit is still moving, force wait
				if unit.get("is_moving"):
					# print("TM: WARNING! Unit ", unit.name, " is still moving after decide_action! Forcing wait.")
					while unit.get("is_moving"):
						await get_tree().process_frame
					# print("TM: Unit ", unit.name, " finished forced move wait.")

	# Enemy End Turn Effects
	for unit in units:
		if (
			is_instance_valid(unit)
			and "faction" in unit
			and unit.faction == "Enemy"
			and unit.current_hp > 0
		):
			unit.process_turn_end_effects()

	start_environment_turn()


func start_environment_turn():
	current_turn = TurnState.ENVIRONMENT_TURN
	print("\n--- TURN ", turn_count, ": ENVIRONMENT PHASE ---")
	SignalBus.on_turn_changed.emit("ENVIRONMENT PHASE", turn_count)

	# Handle Environment effects (Sanity decay, etc.)
	# Placeholder
	print("Environment is calm...")

	# Check Objective Status (Timers, etc)
	var status = check_game_over()
	if status != "CONTINUE":
		return

	# End of full round
	start_player_turn()


func check_game_over() -> String:
	# Delegate to ObjectiveManager if it exists (Main creates it usually)
	# Or we can own it. Let's look for sibling for now as per architecture pattern
	var om = get_node_or_null("../ObjectiveManager")
	if not om:
		# Fallback to simple deathmatch if no manager
		return "CONTINUE"

	var status = om.check_status(units, turn_count)

	if status == "WIN":
		if game_over:
			return "WIN"  # Already triggered
		game_over = true
		print("\n*** VICTORY! ***")
		var reward = 50  # Default
		if GameManager and GameManager.active_mission:
			reward = GameManager.active_mission.reward_kibble

		SignalBus.on_mission_ended.emit(true, reward)

		# Notify GameManager -> Return to Base
		if GameManager:
			GameManager.add_kibble(reward)  # Reward

			# Collect Survivor Data & Award Mission XP
			var survivors = []
			for u in units:
				if is_instance_valid(u) and "faction" in u and u.faction == "Player":
					# Award Mission XP
					if u.current_hp > 0:
						u.gain_xp(20)

					# Note: Even dead units might need to be passed if we want to remove them from roster?
					# Currently complete_mission only updates specific names.
					# Let's pass everyone.
					# Let's pass everyone.
					survivors.append(_build_survivor_data(u))
			# Search for Nemesis Candidates
			var enemy_survivors = []
			for u in units:
				if (
					is_instance_valid(u)
					and "faction" in u
					and u.faction == "Enemy"
					and u.current_hp > 0
				):
					if "victim_log" in u and u.victim_log.size() > 0:
						enemy_survivors.append(
							{"name": u.name, "victim_log": u.victim_log, "base_type": "Rusher"}  # Placeholder, implies base stats
						)

			GameManager.complete_mission(survivors, true, enemy_survivors)
		return "WIN"
		return "WIN"
	elif status == "LOSS":
		if game_over:
			return "LOSS"
		game_over = true
		print("\n*** DEFEAT... ***")
		SignalBus.on_mission_ended.emit(false, 0)

		# Ensure dead are purged even on loss
		# Ensure dead are purged even on loss
		if GameManager:
			var survivors = []
			for u in units:
				if (
					is_instance_valid(u)
					and "faction" in u
					and u.faction == "Player"
					and u.current_hp > 0
				):
					survivors.append(_build_survivor_data(u))

			# Search for Nemesis Candidates (Even on Defeat!)
			var enemy_survivors = []
			for u in units:
				if (
					is_instance_valid(u)
					and "faction" in u
					and u.faction == "Enemy"
					and u.current_hp > 0
				):
					if "victim_log" in u and u.victim_log.size() > 0:
						enemy_survivors.append(
							{"name": u.name, "victim_log": u.victim_log, "base_type": "Rusher"}  # Placeholder
						)

			GameManager.complete_mission(survivors, false, enemy_survivors)
		# Duplicate logic removed.

		return "LOSS"

		return "LOSS"

	return "CONTINUE"


func handle_reaction_fire(mover, from_pos: Vector2 = Vector2(-999, -999)):
	# Fix default manual logic if not passed
	if from_pos == Vector2(-999, -999):
		from_pos = mover.grid_pos

	# Find GridManager
	var gm = get_node_or_null("../GridManager")
	if not gm:
		return

	# Check all units for Overwatch against the mover
	for unit in units:
		if not is_instance_valid(unit) or unit.current_hp <= 0:
			continue
		if unit == mover:
			continue

		# Safe Faction Check
		var u_fac = unit.faction if "faction" in unit else "Neutral"
		var m_fac = mover.faction if "faction" in mover else "Neutral"

		if u_fac == m_fac:
			continue  # No friendly fire reaction

		# Check Overwatch Status
		if unit.get("is_overwatch"):  # Use get to avoid crash if property missing on base class (though Unit has it)
			# Check Validation (Range & LOS)
			# We can use CombatResolver's hit chance. If > 0, we can shoot.
			# Note: We might want a dedicated LOS check, but calculate_hit_chance usually covers it.
			# However, calculate_hit_chance doesn't strictly return 0 if blocked, it penalizes.
			# Let's use VisionManager if possible, or just distance + raycast locally.

			# Use from_pos for distance checking
			var dist = unit.grid_pos.distance_to(from_pos)
			var range_limit = 4
			if unit.primary_weapon:
				range_limit = unit.primary_weapon.weapon_range
			elif "attack_range" in unit:
				range_limit = unit.attack_range

			if dist <= range_limit:
				# Check LOS simple raycast
				var space = get_viewport().world_3d.direct_space_state
				var query = PhysicsRayQueryParameters3D.create(
					unit.position + Vector3(0, 1, 0), mover.position + Vector3(0, 1, 0)
				)
				# exclude units?
				# Ideally we want to see if walls block it.
				# AStar solid check is better? No, raycast is best for visual LOS.
				# But to prevent self-hit, exclude self and target.
				query.exclude = [unit.get_rid(), mover.get_rid()]

				var result = space.intersect_ray(query)
				var blocked = false
				if result:
					# Hit something (Wall?)
					if result.collider.is_in_group("Units"):
						pass  # Ignored via exclude, but checking again
					else:
						# Blocked by scenery
						blocked = true

				if not blocked:
					# Check combat resolver hit chance using FROM position?
					# Actually, verify that calculate_hit_chance > 0
					var check = CombatResolver.calculate_hit_chance(unit, mover, gm, from_pos, true)

					if check["hit_chance"] <= 5:  # Assuming 5 is min
						continue

					# TRIGGER REACTION!
					# print("!!! OVERWATCH TRIGGERED: ", unit.name, " -> ", mover.name)
					SignalBus.on_reaction_fire_triggered.emit(unit, mover)

					# Consume Overwatch
					unit.is_overwatch = false
					SignalBus.on_request_floating_text.emit(
						unit.position, "REACTION!", Color.ORANGE
					)

					# Small delay for drama
					await get_tree().create_timer(0.5).timeout

					# Execute Shot
					# Execute Shot
					CombatResolver.execute_attack(unit, mover, gm, true)

					# Pause movement briefly
					await get_tree().create_timer(0.5).timeout

					# Stop if mover is dead/freed
					if not is_instance_valid(mover):
						break
					if mover.current_hp <= 0:
						break  # Mover died, stop checking others


func force_retreat():
	if game_over:
		return
	game_over = true
	print("\n*** RETREAT! ***")
	SignalBus.on_mission_ended.emit(false, 0)  # Loss with 0 reward? Or partial?

	if GameManager:
		# 1. Collect Survivors
		var survivors = []
		for u in units:
			if (
				is_instance_valid(u)
				and "faction" in u
				and u.faction == "Player"
				and u.current_hp > 0
			):
				survivors.append(_build_survivor_data(u))

		# 2. Collect Enemy Survivors (Nemesis Logic)
		var enemy_survivors = []
		for u in units:
			if (
				is_instance_valid(u)
				and "faction" in u
				and u.faction == "Enemy"
				and u.current_hp > 0
			):
				if "victim_log" in u and u.victim_log.size() > 0:
					enemy_survivors.append(
						{"name": u.name, "victim_log": u.victim_log, "base_type": "Rusher"}  # Placeholder
					)

		# 3. Complete Mission
		GameManager.complete_mission(survivors, false, enemy_survivors)

	print("TurnManager: Retreat Executed.")


func _build_survivor_data(u) -> Dictionary:
	var data = {
		"name": u.name,
		"hp": u.current_hp,
		"xp": u.current_xp,
		"level": u.rank_level,
		"sanity": u.current_sanity
	}
	# Sync Inventory (Persistence Fix)
	var inv = u.get("inventory")
	if inv != null:
		data["inventory"] = inv
	elif "inventory" in u:
		data["inventory"] = u.inventory
		
	return data
