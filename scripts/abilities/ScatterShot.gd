extends Ability
class_name ScatterShot


func _init():
	display_name = "Scatter Shot"
	ap_cost = 2
	ability_range = 3
	cooldown_turns = 2


# AOE Logic: 3x3 Blast centered on target
# Push Logic: Move unit away from center of blast


func get_valid_tiles(grid_manager: GridManager, user) -> Array[Vector2]:
	var valid: Array[Vector2] = []
	for tile in grid_manager.grid_data.keys():
		if tile.distance_to(user.grid_pos) <= ability_range:
			valid.append(tile)
	return valid


func execute(user, _target_unit, target_tile: Vector2, grid_manager: GridManager) -> String:
	if not user.spend_ap(ap_cost):
		return "Not enough AP!"

	SignalBus.on_combat_action_started.emit(
		user, null, "Scatter Shot", grid_manager.get_world_position(target_tile)
	)
	print(user.name, " fires Scatter Shot at ", target_tile)

	# Define Area
	var tiles_to_hit = [target_tile]
	var neighbors = [
		Vector2(0, 1),
		Vector2(0, -1),
		Vector2(1, 0),
		Vector2(-1, 0),
		Vector2(1, 1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(-1, -1)
	]
	for n in neighbors:
		tiles_to_hit.append(target_tile + n)

	# Damage & Push Logic is deferred to impact (mimic Grenade delay?)
	# For "Shotgun" feel, let's make it instant or fast.
	# We'll stick to instant for simplicity in this pass, unless VFX requires delay.
	# Grenade uses lambda for projectile. Let's assume instant for now.

	# SFX
	if GameManager and GameManager.audio_manager:
		GameManager.audio_manager.play_sfx("SFX_Grenade")  # Reuse boom or add shotgun sound

	var hits = 0
	for tile in tiles_to_hit:
		var unit = _get_unit_at(tile, user)
		if unit and unit.current_hp > 0:
			# Damage
			unit.take_damage(4)
			hits += 1
			print("Scatter hit ", unit.name)

			# Push
			if unit.current_hp > 0:
				_apply_push(unit, target_tile, grid_manager)

			# XP
			if unit.current_hp <= 0 and user.has_method("gain_xp"):
				user.gain_xp(30)

	start_cooldown()
	SignalBus.on_combat_action_finished.emit(user)
	return "Scatter Shot fired! Hit " + str(hits) + " targets."


func _get_unit_at(grid_pos: Vector2, user):
	var units = user.get_tree().get_nodes_in_group("Units")
	for u in units:
		if u.grid_pos == grid_pos and u != user:  # Don't hit self? Grenade hits self. Scatter probably shouldn't?
			return u
	return null


func _apply_push(unit, center: Vector2, grid_manager: GridManager):
	var dir = (unit.grid_pos - center).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(1, 0)  # Default push if direct hit

	# Snap to grid dir
	var push_dest = unit.grid_pos + Vector2(round(dir.x), round(dir.y))

	# Validate Dest
	if grid_manager.is_walkable(push_dest):
		# Create manual movement or teleport
		# Teleport is safer for instant ability
		unit.grid_pos = push_dest
		unit.position = grid_manager.get_world_position(push_dest)
		print(unit.name, " was pushed to ", push_dest)

		# Trigger Sanity Hit?
		unit.take_sanity_damage(2)  # Shake them up
	else:
		# Wall Slam! Extra damage?
		unit.take_damage(2)
		print(unit.name, " slammed into a wall!")
