extends "res://scripts/entities/EnemyUnit.gd"
class_name WhispererUnit

# Passive: Dread Aura
# Range: 3 tiles
# Effect: -5 Sanity on Turn End


func _ready():
	super._ready()
	name = "The Whisperer"
	unit_name = "The Whisperer"
	max_hp = 40  # Low HP
	current_hp = 40
	mobility = 6  # Mobile

	# Visuals: Purple
	var mesh = get_node_or_null("Mesh")
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = Color(0.5, 0.0, 0.8)  # Purple

	# Update Label
	var label = get_node_or_null("Label3D")
	if label:
		label.text = "WHISPERER"

	# Add Abilities
	var mf_script = load("res://scripts/abilities/MindFractureAbility.gd")
	if mf_script:
		var mf = mf_script.new()
		abilities.append(mf)


func attack_target(gm):
	var target = target_unit  # Use base class member
	if not target:
		# Fallback to nearest
		target = _find_nearest_target()

	if not target:
		return

	# Try Mind Fracture first
	var mf = null
	for a in abilities:
		if a.display_name == "Mind Fracture":
			mf = a
			break

	if mf and current_ap >= mf.ap_cost:
		print("The Whisperer casting Mind Fracture on ", target.name)
		# execute(user, target_unit, target_tile, grid_manager)
		mf.execute(self, target, target.grid_pos, gm)
		spend_ap(mf.ap_cost)
	else:
		# Basic Attack
		super.attack_target(gm)


func _find_nearest_target():
	var min_d = 999
	var t = null
	for u in get_tree().get_nodes_in_group("Units"):
		if is_instance_valid(u) and "faction" in u and u.faction == "Player" and u.current_hp > 0:
			var d = grid_pos.distance_to(u.grid_pos)
			if d < min_d:
				min_d = d
				t = u
	return t


# Hook: Called by TurnManager when this unit's turn ends (via process_turn_end_effects)
func process_turn_end_effects():
	super.process_turn_end_effects()  # Standard resets
	_apply_dread_aura()


func _apply_dread_aura():
	# Find units in range 3
	# We need access to all units.
	# Option 1: Main/GameManager global list.
	# Option 2: Pass units to this function (requires changing signature).
	# Option 3: Access via parent/group.

	# Assuming Main.gd puts units in a group "units"? Or accessing Main via owner.
	# Let's iterate scene root children for now if "Main" is root.

	# Better: Use GridManager to query? No, GridManager stores Occupant.
	# Iterate tiles in range 3.

	print("The Whisperer emits a wave of Dread...")
	# VFX here?

	var main_scene = get_tree().current_scene
	if not main_scene:
		return

	# Assuming Main has a way to get units.
	# Or we just find nodes in group "player_units" if we added that.
	# We haven't formalized groups yet.
	# Let's assume Main.gd has 'spawned_units'.

	# HACK for MVP: Iterate all siblings if they are Unit
	for sibling in get_parent().get_children():
		if sibling is Unit and sibling != self and "faction" in sibling and sibling.faction == "Player":
			if sibling.current_hp > 0:
				var dist = grid_pos.distance_to(sibling.grid_pos)
				if dist <= 3.0:
					sibling.take_sanity_damage(5)  # Removed invalid source string arg
					print(sibling.name, " suffers 5 Dread damage!")
