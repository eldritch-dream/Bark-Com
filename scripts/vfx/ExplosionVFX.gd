extends Node3D


func _ready():
	var particles = GPUParticles3D.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 0.5, 0.0)  # Orange
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES

	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.5, 0.5)
	mesh.material = mat
	particles.draw_pass_1 = mesh

	var process_mat = ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = 0.5
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 180.0
	process_mat.gravity = Vector3(0, 0, 0)
	process_mat.initial_velocity_min = 2.0
	process_mat.initial_velocity_max = 5.0
	process_mat.scale_min = 1.0
	process_mat.scale_max = 3.0
	process_mat.color = Color(1, 0.5, 0, 1)

	particles.process_material = process_mat
	particles.amount = 32
	particles.lifetime = 1.0
	particles.explosiveness = 1.0
	particles.one_shot = true

	add_child(particles)
	particles.emitting = true

	# Auto cleanup
	await get_tree().create_timer(1.5).timeout
	queue_free()
