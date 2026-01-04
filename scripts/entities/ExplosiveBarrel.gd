extends "res://scripts/entities/VolatileCover.gd"
class_name ExplosiveBarrel

# Explosive Barrel
# Low HP, Instant/Short Fuse, Small Radius


func _ready():
	# Specs
	max_hp = 12
	current_hp = 12
	fuse_turns = 1  # 1 Turn fuse allows for "Warning" phase and reaction shots

	explosion_range = 2
	explosion_damage = 8

	super._ready()  # Registers signals


func _setup_visuals():
	mesh = MeshInstance3D.new()
	var pyl = CylinderMesh.new()
	pyl.top_radius = 0.3
	pyl.bottom_radius = 0.3
	pyl.height = 1.2
	mesh.mesh = pyl

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mesh.material_override = mat
	mesh.position.y = 0.6
	add_child(mesh)
