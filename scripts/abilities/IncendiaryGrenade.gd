extends Ability
class_name IncendiaryGrenade

var max_charges: int = 1
var charges: int = 1
var initialized: bool = false

var base_aoe_radius: float = 2.0
var aoe_radius: float = 2.0

func _init():
	display_name = "Incendiary Grenade"
	ap_cost = 2
	ability_range = 5
	cooldown_turns = 4 

func on_turn_start(user):
	super.on_turn_start(user)
	update_stats(user)

func update_stats(user):
	# Check for Bombardier (Passive Range)
	if user.has_method("has_perk") and user.has_perk("grenadier_bombardier"):
		ability_range = 8
	else:
		ability_range = 5
		
	# Check for Big Bada Boom
	aoe_radius = base_aoe_radius
	if user.has_method("has_perk") and user.has_perk("grenadier_big_bada_boom"):
		aoe_radius += 1.0

func get_valid_tiles(grid_manager: GridManager, user) -> Array[Vector2]:
	return grid_manager.get_tiles_in_radius(user.grid_pos, ability_range)


func get_hit_chance_breakdown(_grid_manager, _user, _target) -> Dictionary:
	var base = 80
	var breakdown = {"Base Accuracy": base}
	return {
		"hit_chance": base, # 80% accuracy for all grenades
		"breakdown": breakdown
	}

func execute(user, _target_unit, target_tile: Vector2, grid_manager: GridManager) -> String:
	if not user.spend_ap(ap_cost):
		return "Not enough AP!"

	# Scatter Check
	var hit_chance = 80
	var roll = randi() % 100
	var final_target_tile = target_tile
	
	if roll >= hit_chance:
		print("Incendiary Missed! Scattering...")
		SignalBus.on_combat_log_event.emit("Incendiary SCATTERED!", Color.ORANGE)
		
		var neighbors = [
			target_tile + Vector2(0, 1), target_tile + Vector2(0, -1),
			target_tile + Vector2(1, 0), target_tile + Vector2(-1, 0),
			target_tile + Vector2(1, 1), target_tile + Vector2(1, -1),
			target_tile + Vector2(-1, 1), target_tile + Vector2(-1, -1)
		]
		var valid_scatter = []
		for n in neighbors:
			if grid_manager.grid_data.has(n):
				valid_scatter.append(n)
		
		if valid_scatter.size() > 0:
			final_target_tile = valid_scatter.pick_random()
			print("Scattered to ", final_target_tile)

	var target_pos = grid_manager.get_world_position(final_target_tile)
	SignalBus.on_combat_action_started.emit(user, null, "Incendiary", target_pos)
	
	# Radius Use Property
	var tiles_to_hit = grid_manager.get_tiles_in_radius(final_target_tile, aoe_radius)

	print(user.name, " throws INCENDIARY at ", target_tile)

	var on_impact = func():
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Grenade") 

		for tile in tiles_to_hit:
			var units = user.get_tree().get_nodes_in_group("Units")
			for u in units:
				if u.grid_pos == tile and u.current_hp > 0:
					u.take_damage(3) # Moderate initial damage
					
					# Apply Burning
					var burn_res = load("res://scripts/resources/statuses/BurningEffect.gd")
					if burn_res:
						var burn = burn_res.new()
						u.apply_effect(burn)
					else:
						print("BurningEffect script not found!")

		SignalBus.on_combat_action_finished.emit(user)

	# VFX
	var start_pos = user.position + Vector3(0, 1.5, 0)
	var end_pos = target_pos
	
	if VFXManager.instance:
		VFXManager.instance.spawn_projectile(start_pos, end_pos, "Grenade", on_impact)
	else:
		on_impact.call()

	start_cooldown()
	return "Fire in the hole!"
