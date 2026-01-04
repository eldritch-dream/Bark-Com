extends Node3D


func _ready():
	# Procedural Fire using CPU Particles
	var particles = CPUParticles3D.new()
	particles.amount = 32
	particles.lifetime = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.4, 0.1, 0.4)
	particles.direction = Vector3.UP
	particles.gravity = Vector3(0, 4.0, 0)
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.0
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.3

	# Voxel style cubes -> Just use small box meshes or billboards
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.1)
	particles.mesh = mesh

	# Color Over Lifetime
	var grad = Gradient.new()
	grad.set_color(0, Color.YELLOW)
	grad.set_color(1, Color(1, 0, 0, 0))  # Red Fade
	particles.color_ramp = grad

	add_child(particles)
	particles.emitting = true
