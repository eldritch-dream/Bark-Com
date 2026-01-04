extends Node
class_name ObjectiveManager

enum MissionType { DEATHMATCH, RESCUE, RETRIEVE, HACKER, DEFENSE }

var current_mission_type = MissionType.DEATHMATCH
var turn_limit = -1  # -1 means no limit
var current_turn = 0
var is_objective_complete = false
const HACKS_REQUIRED = 3
var current_hacks = 0
var target_count = 0
var current_retrievals = 0

# Retrieve Specifics
var loot_target = null

# Rescue Specifics
var rescue_target = null
var rescue_secured: bool = false
var rescue_win_turn: int = -1


func _ready():
	add_to_group("ObjectiveManager")


func initialize(mission_type, _turn_manager: TurnManager, count_override: int = 0):
	current_mission_type = mission_type
	is_objective_complete = false
	current_turn = 0
	current_hacks = 0
	current_retrievals = 0
	target_count = count_override

	print("\n=== MISSION OBJECTIVE: ", MissionType.keys()[mission_type], " ===")

	match current_mission_type:
		MissionType.DEATHMATCH:
			print(" - Eliminate all enemies!")
		MissionType.HACKER:
			if target_count == 0: target_count = HACKS_REQUIRED
			print(" - Hack ", target_count, " Terminals provided by the Network!")
		MissionType.RETRIEVE:
			if target_count == 0: target_count = 1 # Fallback
			print(" - Secure ", target_count, " Treat Bags!")
		MissionType.DEFENSE:
			turn_limit = 30  # Estimated 10 waves * 2 + buffer
			print(" - SURVIVE until Turn ", turn_limit, "!")


func check_status(units: Array, turn_count: int) -> String:
	current_turn = turn_count

	# Check Loss Conditions first
	# Crash Fix: Ensure unit is valid before checking faction
	var players_alive = (
		units
		. filter(
			func(u): return is_instance_valid(u) and "faction" in u and u.faction == "Player" and u.current_hp > 0
		)
		. size()
	)
	if players_alive == 0:
		return "LOSS"

	match current_mission_type:
		MissionType.DEATHMATCH:
			var enemies_alive = 0
			for u in units:
				if is_instance_valid(u) and "faction" in u and u.faction == "Enemy" and u.current_hp > 0:
					enemies_alive += 1
			if enemies_alive == 0:
				# Prevent instant win if game just started (Turn 0 or 1 with no spawns yet)
				if current_turn <= 1 and units.size() < 4: # Arbitrary small number, assuming squad is ~4
					return "CONTINUE"
				return "WIN"

		MissionType.RETRIEVE:
			if current_retrievals >= target_count:
				return "WIN"
			if turn_limit > 0 and current_turn > turn_limit:
				print("Time expired! Keeping failed.")
				return "LOSS"

		MissionType.RESCUE:
			# Dynamic Target Finder (if reference lost or not set by bad init)
			var target_node = rescue_target
			if not is_instance_valid(target_node):
				target_node = get_tree().get_first_node_in_group("RescueTargets")
				
			if not is_instance_valid(target_node) or target_node.current_hp <= 0:
				return "LOSS"
				
			if rescue_secured:
				if current_turn >= rescue_win_turn:
					return "WIN"
			
			return "CONTINUE"

		MissionType.HACKER:
			if current_hacks >= target_count:
				return "WIN"

		MissionType.DEFENSE:
			# Loss via Hydrant Death handled by Main/Signal
			# Win via Survival
			if current_turn >= turn_limit:
				print("Base Defense Successful! Wave Limit Reached.")
				return "WIN"

	return "CONTINUE"


func register_hack(success: bool):
	if current_mission_type != MissionType.HACKER:
		return

	if success:
		current_hacks += 1
		print_objective_status()
	else:
		print("ObjectiveManager: Hack Failed! Reinforcements incoming!")


func print_objective_status():
	if current_mission_type == MissionType.HACKER:
		print("Hacking Progress: ", current_hacks, "/", target_count)
		SignalBus.on_request_floating_text.emit(
			Vector3(5, 5, 5),
			str(current_hacks) + "/" + str(target_count) + " HACKED",
			Color.GREEN
		)


func handle_interaction(interactor, target):
	print("ObjectiveManager: Handling Interaction. Type: ", current_mission_type, " Target: ", target.name)
	
	# Generic Interaction (Loot Crates, Switches, etc)
	if target.has_method("interact"):
		target.interact(interactor)
		# Do not return, check if this interaction fulfilled an objective
	
	if not is_instance_valid(target):
		print("ObjectiveManager: Target became invalid after interaction. Continuing check anyway (using cached groups if possible).")
		# We can't use target.is_in_group if it's freed?
		# Actually, is_instance_valid(freed_object) is false.
		# But we need to know if it WAS a objective.
		# If LootCrate deleted itself, we are in trouble.
		# But we know LootCrate doesn't delete itself (except fallback).
		
		# If it's invalid, we assume it's gone and return, BUT we want to know why.
		return

	# print("ObjectiveManager: Handling Interaction... (Moved to top)")
	if current_mission_type == MissionType.RETRIEVE:
		if target.is_in_group("TreatBags") or target is LootCrate:
			current_retrievals += 1
			print(interactor.name, " secured a Treat Bag! Progress: ", current_retrievals, "/", target_count)
			SignalBus.on_request_floating_text.emit(target.position + Vector3(0,2,0), "SECURED " + str(current_retrievals) + "/" + str(target_count), Color.CYAN)
			
			# Clean up object
			if is_instance_valid(target):
				target.queue_free()
			
			if current_retrievals >= target_count:
				is_objective_complete = true
			
			print("ObjectiveManager: Secured! Count: ", current_retrievals, "/", target_count, " Complete? ", is_objective_complete)
			
			# Notify System to check win condition immediately
			print("ObjectiveManager: Emitting INTERRUPT signal to force check.")
			# SignalBus.on_turn_changed.emit("INTERRUPT", current_turn) # Hacky force check REMOVED to avoid banner logic
			
			# If we want instant win check, we can call MissionManager if we have reference, or just wait for next check.
			# For now, silent is better than annoying.
			
			# target.queue_free() # Handled above

	elif current_mission_type == MissionType.RESCUE:
		if target.is_in_group("RescueTargets") or target == rescue_target:
			if not rescue_secured:
				rescue_secured = true
				rescue_win_turn = current_turn + 1
				print(interactor.name, " secured the human! Hold until Turn ", rescue_win_turn)
				SignalBus.on_request_floating_text.emit(target.position + Vector3(0,2,0), "SECURED! DEFEND!", Color.GREEN)
			else:
				print("Already secured target.")
			# Do NOT queue_free. Must survive.


func mission_failed(reason: String):
	print("ObjectiveManager: Mission Failed - ", reason)
	# Notify Game Manager or Main to trigger defeat
	# Since Main calls check_status, we can force a fail state or emit signal
	# But Main typically polls check_status.
	# To allow instant failure from event (like unit death), we need a signal.

	# Or, we update a flag that check_status reads.
	# But check_status reads "LOSS" if players dead.
	# Let's emit a specific signal that Main listens to, or force Main to end.

	if GameManager:
		GameManager.call_deferred("fail_mission_generic", reason)
	else:
		# Fallback for testing without GameManager
		SignalBus.on_mission_ended.emit(false, 0)
