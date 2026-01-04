extends InteractiveObject
class_name DestructibleCover

@export var max_hp: int = 5
var current_hp: int = 5
var mesh: MeshInstance3D


func _ready():
	_setup_visuals()
	_setup_collision()
	current_hp = max_hp
	add_to_group("Destructible")


func _setup_visuals():
	mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)  # Crate size estimate
	mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.3, 0.1)  # Crate brown
	mesh.material_override = mat
	mesh.position.y = 0.5
	add_child(mesh)


func _setup_collision():
	# COLLISION SETUP (For Targeting)
	var sb = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)
	shape.shape = box_shape
	shape.position.y = 0.5
	sb.add_child(shape)
	add_child(sb)

	# Add SB to group so Raycast finds it and checks group
	sb.add_to_group("Destructible")
	# Also ensure 'self' is reachable from collider logic in Main.gd
	sb.set_meta("owner_node", self)


func initialize(pos: Vector2, gm: GridManager):
	super.initialize(pos, gm)
	# Set Grid State: BLOCKED/WALKABLE?
	# Typically crates are HIGH COVER (Block walk? or just Provide Cover?)
	# If player can hurdle, is_walkable=true. If chest-high wall, is_walkable=false (in this game mostly).
	# Let's say Blocked for movement, but destructible.
	gm.update_tile_state(pos, false, 1.0, GridManager.TileType.COVER_HALF)  # Half Cover Crate?


func take_damage(amount: int):
	current_hp -= amount
	print("Crate at ", grid_pos, " took ", amount, " damage. HP: ", current_hp)

	SignalBus.on_request_floating_text.emit(position, str(amount), Color.YELLOW)

	if current_hp <= 0:
		destroy()


func destroy():
	print("Crate destroyed!")
	# Update Grid: WALKABLE + NO COVER
	grid_manager.update_tile_state(grid_pos, true, 0.0, GridManager.TileType.GROUND)

	# Visuals
	mesh.visible = false
	# Spawn particles?
	# queue_free after delay
	queue_free()
