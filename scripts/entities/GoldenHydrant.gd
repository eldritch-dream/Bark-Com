extends DestructibleCover
class_name GoldenHydrant

# The Sacred Artifact.
# If destroyed, the Base Defense fails (Game Over).


func _ready():
	super._ready()
	add_to_group("Objectives")

	# Override Stats
	max_hp = 100  # Buffed for durability
	current_hp = 100

	# Override Visuals (Gold Tint)
	var mesh = $MeshInstance3D if has_node("MeshInstance3D") else null
	if not mesh:
		# Fallback: Create Procedural Mesh
		mesh = MeshInstance3D.new()
		mesh.name = "MeshInstance3D"
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.4
		cyl.height = 1.0
		mesh.mesh = cyl
		mesh.position.y = 0.5
		add_child(mesh)
		
		# Ensure Collision too
		if not has_node("CollisionShape3D"):
			var col = CollisionShape3D.new()
			col.name = "CollisionShape3D"
			var shape = CylinderShape3D.new()
			shape.height = 1.0
			shape.radius = 0.4
			col.shape = shape
			col.position.y = 0.5
			add_child(col)

	if mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.84, 0.0)  # Gold
		mat.metallic = 1.0
		mat.roughness = 0.2
		mesh.material_override = mat

	# Floating Text
	var label = Label3D.new()
	label.text = "THE HYDRANT"
	label.modulate = Color.GOLD
	label.position = Vector3(0, 2.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func take_damage(amount, source_unit = null):
	super.take_damage(amount)
	if current_hp <= 0:
		_on_destroyed()


func _on_destroyed():
	print("GoldenHydrant: DESTROYED! THE BASE IS LOST!")
	SignalBus.on_mission_ended.emit(false, 0)  # Instant Defeat
