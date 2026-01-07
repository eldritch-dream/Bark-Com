extends "res://scripts/resources/Ability.gd"

var charges = 1
var aoe_radius = 2.5

func _init():
	display_name = "Rocket Launcher (1 Use)"
	ap_cost = 2
	ability_range = 12
	cooldown_turns = 1 # Cooldown even if charges limited?
	
func execute(user, _target_unit, target_pos: Vector2, grid_manager) -> String:
	if charges <= 0:
		print("No rockets left!")
		return "NO_AMMO"
		
	charges -= 1
	var world_pos = grid_manager.get_world_position(target_pos)
	print(user.name, " fires a ROCKET at ", world_pos)
	
	# --- MISSILE ANIMATION ---
	var missile_script = load("res://scripts/vfx/MissileProjectile.gd")
	if missile_script:
		var missile = missile_script.new()
		user.get_tree().root.add_child(missile)
		missile.launch(user.global_position + Vector3(0, 1.5, 0), world_pos)
		await missile.impact
	
	# AOE Logic
	var units = grid_manager.get_units_in_radius_world(world_pos, aoe_radius) 
	for unit in units:
		# Friendly Fire is ENABLED for Rockets
		unit.take_damage(6)
		
		# Shred Armor
		var shred = load("res://scripts/resources/statuses/ShreddedArmorStatus.gd").new()
		unit.apply_effect(shred)
		
	# Detonate Explosives (Barrels)
	# We need to find objects in 'Destructible' group. 
	# GridManager mostly tracks Units, but let's check if we can find barrels.
	# Or, since barrels are usually physics bodies, we might need an Area check or traverse SceneTree?
	# Better: GridManager tracks static obstacles. If they have 'take_damage', hit them.
	# Actually, get_units_in_radius_world returns 'units' from grid_data.
	# If Barrels are registered as 'unit' in grid_data (they block movement), they are in the list.
	# Otherwise, we might miss them.
	# Barrels usually handle their own physics or are props.
	# Let's try iterating the scene tree group "Destructible" since we don't have a spatial query handy in GridManager specifically for props.
	var destructibles = user.get_tree().get_nodes_in_group("Destructible")
	for obj in destructibles:
		# Check distance
		if obj.global_position.distance_to(world_pos) <= 2.5:
			if obj.has_method("take_damage"):
				obj.take_damage(999) # INSTANT DETONATION
				print("Rocket detonated ", obj.name)
		
	# Destroy Cover? (Requires GridManager logic for cover destruction)
	# grid_manager.destroy_cover_at_world(target_pos, 2.0)
	
	# VFX
	SignalBus.on_request_vfx.emit("Explosion", world_pos, Vector3.ZERO, null, null)
	
	user.spend_ap(ap_cost)
	start_cooldown()
	return "ROCKET"

func can_use() -> bool:
	return charges > 0 and super.can_use()
