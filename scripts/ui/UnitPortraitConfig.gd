extends SubViewportContainer

var sub_viewport: SubViewport
var camera: Camera3D
var model_root: Node3D


func _ready():
	_setup_viewport()


func _setup_viewport():
	custom_minimum_size = Vector2(100, 100)  # Portrait Size
	stretch = true

	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2(100, 100)
	sub_viewport.own_world_3d = true  # Isolate
	sub_viewport.transparent_bg = true
	add_child(sub_viewport)

	# Light
	var light = DirectionalLight3D.new()
	light.position = Vector3(0, 5, 5)
	# light.look_at(Vector3.ZERO) # Error: Not in tree
	# Manually set rotation (approx 45 deg down)
	light.rotation_degrees = Vector3(-45, 0, 0)
	sub_viewport.add_child(light)

	# Camera
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.8, 2.0)  # Zoomed out (was 1.2)
	# camera.look_at(Vector3(0, 0.5, 0)) # Error: Not in tree
	# Manual rotation: Looking slightly down and center
	camera.rotation_degrees = Vector3(-15, 0, 0)
	sub_viewport.add_child(camera)

	# Model Root
	model_root = Node3D.new()
	sub_viewport.add_child(model_root)


func update_portrait(unit_data: Variant):
	# Clear previous
	for child in model_root.get_children():
		child.queue_free()

	# 1. Generate Corgi Model
	var visual_data = PlaceholderCorgiGenerator.generate_corgi(model_root)
	# Rotate 180 to face camera
	model_root.rotation.y = deg_to_rad(180)
	var sockets = visual_data.sockets
	var anim_player = visual_data.anim_player

	# Play Idle
	anim_player.play("Idle")

	# 2. Cosmetics
	var cosmetics = {}
	if unit_data is Dictionary:
		cosmetics = unit_data.get("cosmetics", {})
	elif unit_data is Object and "equipped_cosmetics" in unit_data:
		cosmetics = unit_data.equipped_cosmetics

	# HEAD
	if cosmetics.has("HEAD") and sockets.has("Head"):
		var item_id = cosmetics["HEAD"]
		_attach_item(item_id, sockets["Head"])

	# BACK
	if cosmetics.has("BACK") and sockets.has("Spine"):
		var item_id = cosmetics["BACK"]
		_attach_item(item_id, sockets["Spine"])


func _attach_item(item_id, parent):
	var mesh = CosmeticManager.get_mesh_for_item(item_id)
	var data = CosmeticManager.database.get(item_id)

	if mesh and data:
		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = data.color_override
		mi.material_override = mat
		parent.add_child(mi)


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_rotating = true
			else:
				is_rotating = false
	elif event is InputEventMouseMotion and is_rotating:
		if model_root:
			model_root.rotate_y(event.relative.x * 0.01)


var is_rotating = false
