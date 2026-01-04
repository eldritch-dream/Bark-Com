extends StatusEffect


func _init():
	display_name = "Confused"
	description = "Unit is controlled by AI and may attack allies."
	duration = 1
	type = EffectType.DEBUFF


func on_turn_start(unit: Node):
	# Fallback if no grid manager
	if "current_ap" in unit:
		unit.current_ap = 0
	print(unit.name, " is CONFUSED! (No Grid Context)")


func on_turn_start_with_grid(unit: Node, grid_manager: Node):
	print(unit.name, " is CONFUSED! Executing Friendly Fire logic.")

	# Wait for Player Turn Banner
	await SignalBus.on_turn_banner_finished

	# Consume AP for "AI Actions"
	# We simulate the turn here instantaneously

	var ap = 0
	if "current_ap" in unit:
		ap = unit.current_ap

	while ap > 0:
		# 1. Find Nearest Ally (Target)
		var target = _find_nearest_ally(unit, grid_manager)

		if not target:
			print("Confused Unit: No allies found to betray.")
			break

		# 2. Check Range
		var dist = unit.grid_pos.distance_to(target.grid_pos)
		var weapon_range = 1
		if unit.get("primary_weapon"):
			weapon_range = unit.primary_weapon.weapon_range

		if dist <= weapon_range:
			# ATTACK
			print("Confused Unit: Attacking ", target.name)
			_perform_betrayal_attack(unit, target)
			ap -= 1
			await unit.get_tree().create_timer(1.0).timeout  # Pause for effect
		else:
			# MOVE
			if ap >= 1:  # Move costs 1?
				print("Confused Unit: Moving towards ", target.name)
				# Simple move 1 tile closer
				var path = grid_manager.get_move_path(unit.grid_pos, target.grid_pos)
				if path.size() > 1:
					var next_tile = path[1]
					unit.move_to(next_tile, grid_manager.get_world_position(next_tile))
					# We need to wait for move?
					# Unit.move_to is async (tween).
					# Let's wait a bit to simulate travel time
					await unit.get_tree().create_timer(0.8).timeout
					ap -= 1  # Waste AP stumbling
				else:
					ap -= 1
			else:
				break

	# Ensure AP is gone
	if "current_ap" in unit:
		unit.current_ap = 0


func _find_nearest_ally(unit, gm):
	var nearest = null
	var min_dist = 999.0
	var units = unit.get_tree().get_nodes_in_group("Units")
	for u in units:
		# Ally = Same faction (Player) AND Not Self AND Alive
		# Verify it's a unit (has 'faction')
		if "faction" in u and u != unit and u.faction == unit.faction and u.current_hp > 0:
			var d = unit.grid_pos.distance_to(u.grid_pos)
			if d < min_dist:
				min_dist = d
				nearest = u
	return nearest


func _perform_betrayal_attack(attacker, victim):
	# Simple Hit calc
	var hit_chance = 60
	if attacker.get("accuracy"):
		hit_chance = attacker.accuracy

	var roll = randi() % 100
	if roll < hit_chance:
		# Damage
		var dmg = 3
		if attacker.get("primary_weapon"):
			dmg = attacker.primary_weapon.damage

		print("BETRAYAL! ", attacker.name, " hits ", victim.name, " for ", dmg, " damage!")
		if victim.has_method("take_damage"):
			victim.take_damage(dmg)

		# VFX
		if attacker.get_node_or_null("VFXManager"):  # Global?
			pass  # Creating vfx is tricky without scene context
	else:
		print("BETRAYAL! ", attacker.name, " missed ", victim.name)
