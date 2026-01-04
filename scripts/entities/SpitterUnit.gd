extends "res://scripts/entities/EnemyUnit.gd"

# Spitter Specs
# Medium HP, Medium Mobility, Low Aim
# Ability: Acid Loogie (Area Denial)

var acid_cooldown: int = 0
const MAX_ACID_COOLDOWN = 1


func _ready():
	super._ready()
	# Override Stats if not provided by data
	if not primary_weapon:
		# Fallback Weapon for basic attacks if Cooldown is active
		var spit = WeaponData.new()
		spit.display_name = "Weak Spit"
		spit.damage = 2
		spit.weapon_range = 6
		primary_weapon = spit

	if max_hp < 10:
		max_hp = 10
	current_hp = max_hp
	mobility = 5

	# Visual Override handled in _setup_spitter_visuals called by _ready or initialize
	_setup_spitter_visuals()


func _setup_spitter_visuals():
	var mesh = get_node_or_null("Mesh")
	if mesh:
		if not mesh.material_override:
			mesh.material_override = StandardMaterial3D.new()
		mesh.material_override.albedo_color = Color.WEB_GREEN


# --- AI LOGIC OVERRIDE ---
func decide_action(_all_units: Array, gm: GridManager):
	print(name, " (Spitter) deciding action. Cooldown: ", acid_cooldown)

	# Reduce Cooldown (Simulated Per Turn)
	if acid_cooldown > 0:
		acid_cooldown -= 1

	target_unit = null

	# 1. ACQUIRE TARGET
	var best_score = -9999.0
	for unit in _all_units:
		if is_instance_valid(unit) and "faction" in unit and unit.faction == "Player" and unit.current_hp > 0:
			var score = _evaluate_target_priority(unit, gm)
			if score > best_score:
				best_score = score
				target_unit = unit

	if not target_unit:
		state = State.IDLE
		print(" - Spitter has no target.")
		_end_action()
		return

	# 2. CHECK ABILITY (Acid Spit)
	var can_spit = false
	if acid_cooldown == 0:
		var dist = grid_pos.distance_to(target_unit.grid_pos)
		if dist <= 6:
			# CHECK FOR EXISTING HAZARD
			var already_acid = false
			var hazards = get_tree().get_nodes_in_group("Hazards")
			for h in hazards:
				if h.grid_pos == target_unit.grid_pos:
					already_acid = true
					break
			
			if not already_acid:
				can_spit = true
				
	if can_spit:
		# VISUAL: Projectile
		await _play_spit_animation(target_unit.grid_pos, gm)

		_perform_acid_attack(target_unit.grid_pos, gm)

		# Delay for impact
		await get_tree().create_timer(0.5).timeout
		_end_action()
		return
	else:
		# Move closer to use Ability
		# Simplify: Just fall back to standard behavior (Move + Shoot)
		pass

	# 3. FALLBACK: GENERIC BEHAVIOR
	super.decide_action(_all_units, gm)


func _play_spit_animation(target_pos_grid: Vector2, gm: GridManager):
	var start_pos = position + Vector3(0, 1.0, 0)
	var end_pos = gm.get_world_position(target_pos_grid)

	# Create Projectile
	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh_inst.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.WEB_GREEN
	mat.emission_enabled = true
	mat.emission = Color.LIME
	mesh_inst.material_override = mat
	get_parent().add_child(mesh_inst)  # Add to Scene
	mesh_inst.position = start_pos

	# Parabolic Tween
	var tween = create_tween()
	var duration = 0.6
	# Linear X/Z
	tween.tween_property(mesh_inst, "position:x", end_pos.x, duration)
	tween.parallel().tween_property(mesh_inst, "position:z", end_pos.z, duration)
	# Arc Y
	var peak_y = max(start_pos.y, end_pos.y) + 2.0
	(
		tween
		. parallel()
		. tween_property(mesh_inst, "position:y", peak_y, duration * 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. parallel()
		. tween_property(mesh_inst, "position:y", end_pos.y, duration * 0.5)
		. set_delay(duration * 0.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)

	await tween.finished
	mesh_inst.queue_free()

	# End of Animation Helper function logic
	pass


func _perform_acid_attack(target_pos: Vector2, gm: GridManager):
	print(name, " spits ACID at ", target_pos)

	# Spawn HazardZone (3x3 Grid)
	var center = target_pos
	var offsets = [
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(-1, 0),
		Vector2(0, 1),
		Vector2(0, -1),
		Vector2(1, 1),
		Vector2(1, -1),
		Vector2(-1, 1),
		Vector2(-1, -1)
	]

	# Use Scene Root to avoid parenting to Self (which moves)
	var scene_root = get_tree().current_scene

	for offset in offsets:
		var tile = center + offset
		if gm.grid_data.has(tile):
			var zone = load("res://scripts/entities/HazardZone.gd").new()
			scene_root.add_child(zone)
			zone.initialize(tile, gm)

	# Floating Text
	SignalBus.on_request_floating_text.emit(
		gm.get_world_position(target_pos) + Vector3(0, 2, 0), "ACID SPLASH!", Color.LIME
	)

	acid_cooldown = 2  # Reset Cooldown
