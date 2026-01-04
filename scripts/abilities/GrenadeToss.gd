extends Ability
class_name GrenadeToss


func _init():
	display_name = "Grenade"
	ap_cost = 2
	ability_range = 5
	cooldown_turns = 3


func get_valid_tiles(grid_manager: GridManager, user) -> Array[Vector2]:
	var valid: Array[Vector2] = []
	# Simple distance check
	for tile in grid_manager.grid_data.keys():
		if tile.distance_to(user.grid_pos) <= ability_range:
			valid.append(tile)
	return valid


func execute(user, _target_unit, target_tile: Vector2, grid_manager: GridManager) -> String:
	# Accuracy / Scatter Check
	var hit_chance = 80  # Base 80% chance
	var roll = randi() % 100
	var final_target_tile = target_tile

	if not user.spend_ap(ap_cost):
		return "Not enough AP!"

	if roll >= hit_chance:
		print("Grenade Missed! Scattering...")
		SignalBus.on_combat_log_event.emit("Grenade SCATTERED!", Color.ORANGE)

		# Pick random adjacent tile
		var neighbors = [
			target_tile + Vector2(0, 1),
			target_tile + Vector2(0, -1),
			target_tile + Vector2(1, 0),
			target_tile + Vector2(-1, 0),
			target_tile + Vector2(1, 1),
			target_tile + Vector2(1, -1),
			target_tile + Vector2(-1, 1),
			target_tile + Vector2(-1, -1)
		]
		var valid_scatter = []
		for n in neighbors:
			if grid_manager.grid_data.has(n):  # Ensure it's on grid (fixed method call)
				valid_scatter.append(n)

		if valid_scatter.size() > 0:
			final_target_tile = valid_scatter.pick_random()
			print("Grenade scattered to ", final_target_tile)

	var target_pos = grid_manager.get_world_position(final_target_tile)
	SignalBus.on_combat_action_started.emit(user, null, "Grenade", target_pos)

	# Define Hit Area based on FINAL tile
	var tiles_to_hit = [final_target_tile]
	tiles_to_hit.append(final_target_tile + Vector2(0, 1))
	tiles_to_hit.append(final_target_tile + Vector2(0, -1))
	tiles_to_hit.append(final_target_tile + Vector2(1, 0))
	tiles_to_hit.append(final_target_tile + Vector2(-1, 0))

	print(user.name, " tosses a grenade at ", final_target_tile)

	# Define Damage Logic (Lambda)
	var on_impact = func():
		print("Grenade Impact at ", final_target_tile)

		# PIT CHECK: If tile doesn't exist or is not walkable ground (and not occupied by unit/prop which implies ground)
		# Actually, just check if it exists in grid data.
		if not grid_manager.grid_data.has(final_target_tile):
			print("Grenade fell into the ABYSS!")
			SignalBus.on_combat_log_event.emit("Grenade fell into a pit!", Color.CYAN)

			if GameManager and GameManager.audio_manager:
				# Play falling sound if available, or just a generic "plop"
				GameManager.audio_manager.play_sfx("SFX_Miss")
			SignalBus.on_combat_action_finished.emit(user)
			return  # No Exploision

		# Play BOOM sound on impact
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Grenade")

		for tile in tiles_to_hit:
			var units = user.get_tree().get_nodes_in_group("Units")
			for u in units:
				if u.grid_pos == tile and u.current_hp > 0:
					u.take_damage(5)
					print("BOOM! ", u.name, " took 5 damage.")

					# Check Kill
					if u.current_hp <= 0:
						if user.has_method("gain_xp"):
							user.gain_xp(50)  # Standard Reward
							print(user.name, " killed ", u.name, " with Grenade!")

			# Destructible Damage (Barrels/Cover)
			var props = user.get_tree().get_nodes_in_group("Destructible")
			for p in props:
				# Prop logic: p might be StaticBody (Collider) or Node3D (Script).
				# We generally want the Node3D script.
				# Group "Destructible" is added to both now?
				# DestructibleCover.gd adds to group "Destructible" in _ready (Node3D).
				# AND we added it to `sb` (StaticBody).
				# So we might get duplicates if we iterate the group?
				# Let's check `p` type.
				var prop_script_obj = p
				if p is StaticBody3D:
					prop_script_obj = p.get_parent()

				if is_instance_valid(prop_script_obj) and "grid_pos" in prop_script_obj:
					if prop_script_obj.grid_pos == tile:
						if prop_script_obj.has_method("take_damage_custom"):
							prop_script_obj.take_damage_custom(999, "Explosion")
						elif prop_script_obj.has_method("take_damage"):
							prop_script_obj.take_damage(999)
		
		# Notify TurnManager that action is done
		SignalBus.on_combat_action_finished.emit(user)

	# Calculate Trajectory
	var start_pos = user.position + Vector3(0, 1.5, 0)  # Throw from hand height
	var end_pos = target_pos

	# Spawn Projectile
	if VFXManager.instance:
		VFXManager.instance.spawn_projectile(start_pos, end_pos, "Grenade", on_impact)
	else:
		on_impact.call()  # Fallback if no VFXManager

	start_cooldown()
	return "Grenade Tossed!"
