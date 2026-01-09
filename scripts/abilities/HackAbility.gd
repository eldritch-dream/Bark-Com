extends Ability
class_name HackAbility


func _init():
	display_name = "Hack"
	ap_cost = 1
	ability_range = 1  # Base
	cooldown_turns = 1  # Prevent spam? Or unlimited if AP allows? 1 turn cooldown seems fair.


func get_valid_tiles(grid_manager: GridManager, user) -> Array[Vector2]:
	var valid: Array[Vector2] = []

	# Determine Range based on Tech Score
	# Scouts (Tech > 0) get range 5. Others get 1.
	var effective_range = ability_range
	if "tech_score" in user and user.tech_score > 0:
		effective_range = 5

	# Find Terminals
	var terminals = user.get_tree().get_nodes_in_group("Terminals")
	for t in terminals:
		if is_instance_valid(t) and not t.is_hacked:
			if t.grid_pos.distance_to(user.grid_pos) <= effective_range:
				valid.append(t.grid_pos)

	return valid



func get_hit_chance_breakdown(_grid_manager, user, _target) -> Dictionary:
	var tech = user.tech_score if "tech_score" in user else 0
	var base = 70
	var chance = clamp(base + tech, 0, 100)
	
	var breakdown = {
		"Base Tech Chance": base,
		"Tech Bonus": tech
	}
	
	return {
		"hit_chance": chance,
		"breakdown": breakdown
	}


func execute(user, target_unit, target_tile: Vector2, grid_manager: GridManager) -> String:
	# Resolve Target
	var terminal = null

	# Target might be passed as target_unit if it was clicked directly and processed by Main
	if target_unit and target_unit.is_in_group("Terminals"):
		terminal = target_unit
	else:
		# Find terminal at grid pos
		var terminals = user.get_tree().get_nodes_in_group("Terminals")
		for t in terminals:
			if t.grid_pos == target_tile:
				terminal = t
				break

	if not terminal:
		return "No Terminal found!"
	if terminal.is_hacked:
		return "Already Hacked!"

	if not user.spend_ap(ap_cost):
		return "Not enough AP!"

	# Calculate Chance
	var tech = user.tech_score if "tech_score" in user else 0
	var chance = 70 + tech
	chance = clamp(chance, 0, 100)

	print(user.name, " attempting HACK. Chance: ", chance, "% (Base 70 + Tech ", tech, ")")

	# VFX: Datapad Beam?
	SignalBus.on_combat_action_started.emit(user, terminal, "Hack", terminal.position)

	# Roll
	var roll = randi() % 100 + 1
	var success = roll <= chance

	if success:
		print("HACK SUCCESS!")
		terminal.on_hack_result(true)
		SignalBus.on_combat_action_finished.emit(user)
		return "Hack Successful!"
	else:
		print("HACK FAILED!")
		terminal.on_hack_result(false)
		SignalBus.on_combat_action_finished.emit(user)
		return "Hack Failed!"
