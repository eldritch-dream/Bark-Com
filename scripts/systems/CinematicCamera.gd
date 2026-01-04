extends Node
class_name CinematicCamera

# Controls the Camera3D for cinematic shots (Action Cam, Death Cam)

var camera: Camera3D
var default_position: Vector3
var default_rotation: Vector3
var return_pos: Vector3  # Dynamic return position
var return_size: float = 18.0  # Dynamic return zoom
var current_attacker: Node  # Track who started the action
var is_active: bool = false
var tween: Tween


func _init(cam: Camera3D):
	camera = cam
	default_position = cam.position
	default_rotation = cam.rotation_degrees
	return_pos = cam.position  # Initialize fallback


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	SignalBus.on_combat_action_started.connect(_on_action_started)
	SignalBus.on_unit_died.connect(_on_unit_died)
	SignalBus.on_request_camera_zoom.connect(_on_request_camera_zoom)


func _on_request_camera_zoom(target_pos: Vector3, zoom_level: float, duration: float):
	print("CinematicCamera: Request Zoom -> Target: ", target_pos, " Zoom: ", zoom_level, " Dur: ", duration)
	
	# Only save state if we aren't already in a cinematic
	if not is_active:
		return_pos = camera.position
		return_size = camera.size
	
	is_active = true
	_kill_tween()
	SignalBus.on_cinematic_mode_changed.emit(true)
	
	# Calculate Target Position (Maintain isometric angle)
	# Project backwards from target
	var cam_backward = camera.global_transform.basis.z.normalized() # Ensure normalized
	# Maintain roughly same height/distance logic as standard
	var distance = 20.0
	var final_pos = target_pos + (cam_backward * distance)
	
	print("CinematicCamera: Final Cam Pos: ", final_pos)
	
	# PAUSE GAME SIMULATION (Time Stop)
	get_tree().paused = true
	
	tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(camera, "position", final_pos, 0.5)
	tween.tween_property(camera, "size", zoom_level, 0.5)
	
	# Wait for duration then reset
	tween.chain().tween_interval(duration)
	tween.chain().tween_callback(_reset_camera)


func _on_action_started(attacker, target, action_type: String, target_pos: Vector3):
	if is_active:
		return

	# Capture state before zoom
	return_pos = camera.position
	return_size = camera.size
	current_attacker = attacker

	# User Feedback: Remove Heal Zoom
	if action_type == "Heal" or action_type == "Sploot" or action_type == "Triage":
		return

	# User Feedback: Too much zooming.
	# Only zoom for "Special" actions (Grenade) or Kills (handled in _on_unit_died).
	# Disable for basic attacks.
	if action_type == "Attack":
		return

	# 2. Smooth "Action Zoom"
	var start_pos = attacker.position
	var end_pos = target_pos  # Use precise target point provided by signal

	# Instead of rotating, we maintain the isometric angle and Zoom In (Size).
	# And pan to the midpoint.

	var midpoint = start_pos
	if end_pos:
		midpoint = (start_pos + end_pos) / 2.0

	# Offset Calculation:
	# To look at 'midpoint' from the current rotation, we need to find the position
	# along the camera's backward vector (Z) that maintains distance.
	# Actually for Ortho camera, distance doesn't affect scale, but we want to avoid clipping.
	# Let's keep the CURRENT distance from the ground plane or similar reference?

	# Better: Use the camera's existing Z basis vector.
	var cam_backward = camera.global_transform.basis.z  # Vector pointing OUT of camera eye
	var distance = 20.0  # Standard standoff distance to avoid near-clip

	var target_cam_pos = midpoint + (cam_backward * distance)

	tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(camera, "position", target_cam_pos, 0.5)

	# Zoom In (Size)
	tween.tween_property(camera, "size", 8.0, 0.5)  # Zoom to 8

	# Hold then reset
	tween.chain().tween_interval(1.5)
	tween.chain().tween_callback(_reset_camera)


func _on_unit_died(unit):
	# Impact Zoom
	is_active = true
	_kill_tween()
	SignalBus.on_cinematic_mode_changed.emit(true)

	var cam_backward = camera.global_transform.basis.z
	var target_pos = unit.position + (cam_backward * 20.0)

	tween = create_tween()
	tween.tween_property(camera, "position", target_pos, 0.3)
	tween.tween_property(camera, "size", 6.0, 0.3)  # Zoom to 6!

	# User Request: Return to Shooter after Kill
	if is_instance_valid(current_attacker):
		# Calculate return pos centered on attacker
		# Maintain the same "height/angle" as the return_pos we saved, but shifted x/z
		# Simplest approach: Use offset from previous frame?
		# Or just project using camera basis vectors.
		var back = camera.global_transform.basis.z
		# Assuming standard distance roughly 20 (based on _init default usually).
		# We can calculate distance from return_pos to ground if needed, but hardcoded 20 is safe for ortho.
		return_pos = current_attacker.position + (back * 20.0)

	tween.chain().tween_interval(2.0)
	tween.chain().tween_callback(_reset_camera)


func _reset_camera():
	tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(camera, "position", return_pos, 0.8)  # Reset to saved/updated position
	tween.tween_property(camera, "size", return_size, 0.8)  # Reset to MEMORIZED size (don't force 18.0)
	# No rotation change needed if we didn't touch it
	tween.tween_property(camera, "rotation_degrees", default_rotation, 0.8)
	tween.chain().tween_callback(
		func():
			is_active = false
			get_tree().paused = false
			SignalBus.on_cinematic_mode_changed.emit(false)
	)


func _kill_tween():
	if tween:
		tween.kill()
