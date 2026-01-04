extends InteractiveObject
class_name Door

var is_open: bool = false
var mesh: MeshInstance3D


func _ready():
	_setup_visuals()


func _setup_visuals():
	mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.8, 2.5, 0.2)  # Door shape
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.4, 0.2)  # Wood brown
	mesh.material_override = mat
	# Pivot hack: We want it to hinge.
	# Simplest is just rotate center for now or offset mesh
	mesh.position.y = 1.25
	add_child(mesh)


func initialize(pos: Vector2, gm: GridManager):
	super.initialize(pos, gm)
	# Set Grid State: BLOCKED (Wall)
	gm.update_tile_state(pos, false, 2.0, GridManager.TileType.OBSTACLE)


func interact(_unit):
	if is_open:
		print("Door is already open.")
		return

	print("Opening Door at ", grid_pos)
	is_open = true

	# Update Grid: WALKABLE + NO COVER
	# Actually, does an open door provide cover? Maybe Low Cover?
	# Let's say No Cover for simplicity (Door swings wide open)
	grid_manager.update_tile_state(grid_pos, true, 0.0, GridManager.TileType.GROUND)

	# Visuals
	var tween = create_tween()
	# Rotate 90 degrees
	(
		tween
		. tween_property(mesh, "rotation_degrees:y", 90.0, 0.5)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)

	# Optional: Sound
	# if AudioManager.instance: AudioManager.instance.play_sfx(...)
