extends "res://scripts/fsm/State.gd"


func enter(msg: Dictionary = {}):
	var type = msg.get("type", "FREEZE")
	var unit = context as Unit

	print(unit.name, " entered PANIC state: ", type)

	match type:
		"FREEZE":
			unit.current_ap = 0
			SignalBus.on_unit_stats_changed.emit(unit)
			# Freeze just sits there.
			await unit.get_tree().create_timer(1.0).timeout
			state_machine.transition_to("Idle")

		"RUN":
			_panic_run(unit)

		"BERSERK":
			_panic_berserk(unit)


func _panic_run(unit: Unit):
	var gm = unit.get_node_or_null("../GridManager")
	if not gm:
		state_machine.transition_to("Idle")
		return

	# Find Nearest Enemy
	var all_units = unit.get_tree().get_nodes_in_group("Units")
	var nearest_enemy = null
	var min_dist = 999.0

	for u in all_units:
		if is_instance_valid(u) and u != unit and u.faction == "Enemy":
			var d = unit.grid_pos.distance_to(u.grid_pos)
			if d < min_dist:
				min_dist = d
				nearest_enemy = u

	if not nearest_enemy:
		state_machine.transition_to("Idle")
		return

	# Calculate Run Target
	var dir_away = (Vector2(unit.grid_pos) - Vector2(nearest_enemy.grid_pos)).normalized()
	var target_pos = (unit.grid_pos + (dir_away * unit.mobility)).round()

	var world_path = []
	var grid_path = []

	# Simple Validation
	if gm.is_walkable(target_pos):
		# Create Move Command
		state_machine.transition_to(
			"Moving", {"world_path": [gm.get_world_position(target_pos)], "grid_path": [target_pos]}  # Simple straight line visual for panic? Or pathfind?
		)
		# NOTE: transitioning to Moving will override current state.
		# Panic is technically a "Command" state that delegates to Moving.
	else:
		# Try shorter
		target_pos = unit.grid_pos + dir_away.round()
		if gm.is_walkable(target_pos):
			state_machine.transition_to(
				"Moving",
				{"world_path": [gm.get_world_position(target_pos)], "grid_path": [target_pos]}
			)
		else:
			print("Cornered! Nowhere to run!")
			state_machine.transition_to("Idle")

	unit.current_ap = 0
	SignalBus.on_unit_stats_changed.emit(unit)


func _panic_berserk(unit: Unit):
	var gm = unit.get_node_or_null("../GridManager")
	var all_units = unit.get_tree().get_nodes_in_group("Units")

	var nearest = null
	var min_dist = 999.0
	for u in all_units:
		if is_instance_valid(u) and u != unit and u.current_hp > 0:
			var d = unit.grid_pos.distance_to(u.grid_pos)
			if d < min_dist:
				min_dist = d
				nearest = u

	if not nearest:
		state_machine.transition_to("Idle")
		return

	print(unit.name, " targets ", nearest.name, " in a blind rage!")

	# Attack or Move?
	var dist = unit.grid_pos.distance_to(nearest.grid_pos)
	var attack_range = 4

	if dist > attack_range:
		# Move Closer first
		# We can't chain states easily without a queue.
		# For now, just Attack if in range, otherwise skip move to suppress complexity
		# Or assume Beserk = Attack closest.
		pass

	CombatResolver.execute_attack(unit, nearest, gm)
	unit.current_ap = 0
	SignalBus.on_unit_stats_changed.emit(unit)

	await unit.get_tree().create_timer(1.0).timeout
	state_machine.transition_to("Idle")
