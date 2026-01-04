extends Node3D

# Config
var duration: int = 3
var grid_pos: Vector2
var damage: int = 2
var effect_type: String = "Poison"

# References
var grid_manager


func initialize(pos: Vector2, gm):
	grid_pos = pos
	grid_manager = gm
	add_to_group("Hazards")

	# Snap to World
	position = gm.get_world_position(grid_pos)

	# Connect to SignalBus
	SignalBus.on_turn_changed.connect(_on_turn_changed)
	SignalBus.on_unit_move_step.connect(_on_unit_move_step)

	_setup_visuals()


# ... (Skipping _setup_visuals)


func _on_unit_move_step(unit, pos):
	if pos == grid_pos and not unit.is_dead:
		_apply_effect(unit)


func _on_turn_changed(phase, _turn_num):
	# Apply at start of Environment Phase? Or Start of Unit Turn?
	# Typically Environment Phase checks all hazards.
	if phase == "ENVIRONMENT PHASE":
		_apply_hazard_to_occupants()
		
		duration -= 1
		if duration <= 0:
			queue_free()


func _apply_hazard_to_occupants():
	# 1. Check Units
	var units = get_tree().get_nodes_in_group("Units")
	for unit in units:
		if unit.grid_pos == grid_pos and not unit.is_dead:
			_apply_effect(unit)
			
	# 2. Check Destructibles (Barrels/Crates)
	var props = get_tree().get_nodes_in_group("Destructible")
	for p in props:
		# Resolve actual script object if attached to node
		var prop = p
		# DestructibleCover often puts script on the root Node3D, but adds collision child to group?
		# The grep showed "sb.add_to_group" AND "add_to_group".
		# DestructibleCover.gd:13 -> add_to_group("Destructible") (Self)
		# DestructibleCover.gd:40 -> sb.add_to_group("Destructible") (Child StaticBody)
		# If 'p' is StaticBody, we want p.get_meta("owner_node") or get_parent().
		
		# Safer resolution:
		if p is StaticBody3D:
			prop = p.get_parent()
			
		if is_instance_valid(prop) and "grid_pos" in prop:
			if prop.grid_pos == grid_pos:
				# Apply Damage
				if prop.has_method("take_damage_custom"):
					prop.take_damage_custom(damage, "Acid")
				elif prop.has_method("take_damage"):
					prop.take_damage(damage)


func _setup_visuals():
	var mesh_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.8
	cyl.height = 0.1
	mesh_inst.mesh = cyl

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.WEB_GREEN
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	mat.emission_enabled = true
	mat.emission = Color.GREEN
	mat.emission_energy_multiplier = 1.0
	mesh_inst.material_override = mat

	add_child(mesh_inst)



func _apply_effect(unit):
	# Apply Damage to ANYTHING with health (Unit or Prop)
	if unit.has_method("take_damage"):
		unit.take_damage(damage)
	
	# Apply Poison Effect (Only for Units)
	if unit.has_method("apply_effect"):
		var poison = load("res://scripts/resources/effects/PoisonEffect.gd").new()
		unit.apply_effect(poison)
