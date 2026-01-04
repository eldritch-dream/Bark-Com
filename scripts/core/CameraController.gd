extends Camera3D

# Settings
var move_speed = 10.0
var zoom_speed = 2.0
var rotate_speed = 0.5
var min_zoom = 5.0
var max_zoom = 50.0

# State
var debug_label: Label
var is_rotating = false


func _ready():
	current = true

	# Create Debug UI
	var canvas = CanvasLayer.new()
	add_child(canvas)

	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.modulate = Color.YELLOW
	canvas.add_child(debug_label)

	print("Camera Controls:")
	print(" - WASD / Arrows: Pan")
	print(" - Scroll: Zoom")
	print(" - Right-Click + Drag: Rotate")
	print(" - Right-Click + Drag: Rotate")
	print(" - P: Print current settings to Console")

	# Connect InputManager
	InputManager.on_camera_pan.connect(_on_camera_pan)
	InputManager.on_camera_zoom.connect(_on_camera_zoom)
	InputManager.on_rotation_request.connect(_on_rotation_request)


func _on_camera_pan(input_dir: Vector2):
	# Move relative to camera orientation
	var forward = transform.basis.z
	var right = transform.basis.x

	forward.y = 0
	forward = forward.normalized()
	right.y = 0
	right = right.normalized()

	var delta = get_process_delta_time()
	global_position += (right * input_dir.x + forward * input_dir.y) * move_speed * delta


func _on_camera_zoom(amount: float):
	size = clamp(size + amount * zoom_speed, min_zoom, max_zoom)


func _on_rotation_request(direction: int):
	# Continuous rotation while key held (signal received every frame)
	var delta = get_process_delta_time()
	var speed = 2.0  # Rads/sec? Or factor.
	rotate_y(direction * speed * delta)


func _process(_delta):
	# Only update Debug UI
	debug_label.text = "Pos: %v\nRot (Deg): %v\nSize: %.1f" % [position, rotation_degrees, size]
