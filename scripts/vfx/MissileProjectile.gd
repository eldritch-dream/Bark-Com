extends Node3D
class_name MissileProjectile

signal impact

var target_pos: Vector3
var speed: float = 15.0 # Adjusted for 3D world scale
var arrived: bool = false

func _ready():
	# Visuals: Composition of Meshes
	
	# 1. Main Body (White Cylinder)
	var body_mesh = CylinderMesh.new()
	body_mesh.top_radius = 0.08
	body_mesh.bottom_radius = 0.08
	body_mesh.height = 0.6
	
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.9, 0.9, 0.9) # White
	body_mat.emission_enabled = true
	body_mat.emission = Color(0.1, 0.1, 0.1)
	body_mesh.material = body_mat
	
	var body = MeshInstance3D.new()
	body.mesh = body_mesh
	# Rotation: Cylinder is Y-up. Rotate X -90 to point -Z (Forward)
	body.rotation_degrees = Vector3(-90, 0, 0)
	add_child(body)
	
	# 2. Nose Cone (Red)
	var nose_mesh = CylinderMesh.new()
	nose_mesh.top_radius = 0.0 # Pointy
	nose_mesh.bottom_radius = 0.08
	nose_mesh.height = 0.25
	
	var nose_mat = StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.9, 0.1, 0.1) # Red
	nose_mat.emission_enabled = true
	nose_mat.emission = Color(0.3, 0.0, 0.0)
	nose_mesh.material = nose_mat
	
	var nose = MeshInstance3D.new()
	nose.mesh = nose_mesh
	# Offset: Half body height + half nose height = 0.3 + 0.125 = 0.425
	# Since body is rotated -90 X, 'Up' is -Z.
	nose.position = Vector3(0, 0, -0.425) 
	nose.rotation_degrees = Vector3(-90, 0, 0)
	add_child(nose)
	
	# 3. Fins (Grey)
	var fin_mesh = BoxMesh.new()
	fin_mesh.size = Vector3(0.02, 0.2, 0.2) # Thin, wide, longish
	
	var fin_mat = StandardMaterial3D.new()
	fin_mat.albedo_color = Color(0.3, 0.3, 0.3) # Dark Grey
	fin_mesh.material = fin_mat
	
	for i in range(4):
		var fin = MeshInstance3D.new()
		fin.mesh = fin_mesh
		# Position at back
		fin.position = Vector3(0, 0, 0.2)
		# Rotate around Z axis for the 4 fins
		# And rotate X to match body? Box is isotropic ish but let's see.
		# Base X rotation to lie flat?
		# Actually, let's just rotate the container node around Z.
		
		# Offset from center
		var angle = deg_to_rad(i * 90)
		var offset_dist = 0.08
		fin.position = Vector3(cos(angle) * offset_dist, sin(angle) * offset_dist, 0.2)
		
		# Rotate fin itself to radiate out
		fin.rotation = Vector3(0, 0, angle)
		add_child(fin)
	
	# Tail flame (Particles)
	var particles = CPUParticles3D.new()
	particles.amount = 30
	particles.direction = Vector3(0, 0, 1) # +Z is Back
	particles.spread = 5
	particles.gravity = Vector3(0, 0, 0)
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.scale_amount_min = 0.05
	particles.scale_amount_max = 0.15
	particles.color = Color(1, 0.6, 0.1) # Orange/Yellow
	
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(0.05, 0.05, 0.05)
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(1, 0.8, 0.2)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1, 0.6, 0.0)
	p_mesh.material = p_mat
	particles.mesh = p_mesh
	
	particles.position = Vector3(0, 0, 0.35) 
	add_child(particles)

func launch(start_pos: Vector3, end_pos: Vector3):
	global_position = start_pos
	target_pos = end_pos
	
	# Look at target
	look_at(end_pos, Vector3.UP)
	
	var dist = start_pos.distance_to(end_pos)
	var duration = dist / speed
	
	var tw = create_tween()
	tw.tween_property(self, "global_position", end_pos, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_arrival)

func _on_arrival():
	arrived = true
	impact.emit()
	queue_free()
