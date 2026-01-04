extends Unit
class_name ObjectiveUnit


func _ready():
	super._ready()
	add_to_group("Objectives")
	# Visuals: Yellow Cylinder or Sphere
	var mesh = MeshInstance3D.new()
	var shape = CylinderMesh.new()
	shape.top_radius = 0.3
	shape.bottom_radius = 0.3
	shape.height = 1.0
	mesh.mesh = shape

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.YELLOW
	mat.emission_enabled = true
	mat.emission = Color.YELLOW
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat

	mesh.position.y = 0.5
	add_child(mesh)

	# BEACON (Tall thin pole to see over walls)
	var beacon = MeshInstance3D.new()
	var b_shape = CylinderMesh.new()
	b_shape.top_radius = 0.05
	b_shape.bottom_radius = 0.05
	b_shape.height = 10.0
	beacon.mesh = b_shape
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color.YELLOW
	b_mat.emission_enabled = true
	b_mat.emission = Color.YELLOW
	beacon.material_override = b_mat
	beacon.position.y = 5.0
	add_child(beacon)

	# OmniLight for attention
	var light = OmniLight3D.new()
	light.light_color = Color.YELLOW
	light.light_energy = 5.0
	light.omni_range = 5.0
	add_child(light)
	light.position.y = 2.0

	# Add Collision
	var area = StaticBody3D.new()
	area.name = "ObjectiveBody"
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	col.shape = box
	area.add_child(col)
	add_child(area)

	faction = "Neutral"


var can_be_targeted: bool = true


func initialize(pos: Vector2):
	super.initialize(pos)
	current_hp = 12  # Durability Buff (Was 1)
	max_hp = 12
	max_ap = 0
	current_ap = 0
	max_sanity = 0
	current_sanity = 0


func die():
	# If an objective dies, it's usually bad news
	print(name, " has been destroyed!")

	# Signal Mission Failure if it was the Retrieve Target
	var obj_man = get_tree().get_first_node_in_group("ObjectiveManager")  # Or parent path
	# Actually Main has ObjectiveManager as child usually, but units are siblings of it?
	# Better to use Group or direct reference.
	# ObjectiveManager usually listens to units? Or monitors them?

	# Simplest: SignalBus
	# But we don't have a specific MissionFailed signal payload for this yet.
	# Let's check ObjectiveManager singleton access or just use the generic die().

	super.die()  # Plays death logic

	# We need to ensure Mission Failure happens.
	# ObjectiveManager checks status. If target is null/freed, it might auto-fail?
	# Let's rely on ObjectiveManager to catch it, or emit a specific signal.
	if name == "Treat Bag":
		# Hacky check, but robust for now
		if GameManager:
			GameManager.call_deferred("fail_mission_generic", "Objective Destroyed!")
		elif get_node_or_null("/root/Main/ObjectiveManager"):
			get_node("/root/Main/ObjectiveManager").mission_failed("Objective Destroyed!")
