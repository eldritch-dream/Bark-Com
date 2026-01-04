extends Node

# Signals
signal on_tile_clicked(grid_pos: Vector2, button_index: int)  # 1=Left, 2=Right
signal on_mouse_hover(grid_pos: Vector2) # For Safe Move Preview
signal on_camera_pan(direction: Vector2)
signal on_camera_zoom(amount: float)
signal on_rotation_request(direction: int)  # -1 Left, 1 Right
signal on_cancel_command
signal on_intro_skipped
signal on_debug_action(action: String)

# Configuration
const RAY_LENGTH = 1000.0


var is_input_blocked: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("InputManager: Initialized.")
	SignalBus.on_cinematic_mode_changed.connect(_on_cinematic_mode_changed)


func _on_cinematic_mode_changed(active: bool):
	is_input_blocked = active
	if active:
		# Cancel any pending actions/drags
		on_cancel_command.emit()


func _unhandled_input(event):
	# 1. State Check
	if not GameManager:
		return

	# If in MENU or PAUSED, ignore world inputs
	# BASE might have some inputs? For now assume MISSION is the main consumer of 3D clicks.
	# Base uses UI mainly, but maybe some 3D interaction later.
	# Let's restrict raycasting to MISSION or BASE.
	var state = GameManager.current_state
	var allow_3d_input = (
		state == GameManager.GameState.MISSION or state == GameManager.GameState.BASE
	)

	if not allow_3d_input or is_input_blocked:
		return

	# 2. Camera Controls (WASD / Zoom)
	_handle_camera_controls(event)

	# 3. Mouse Interaction (Raycasts)
	if event is InputEventMouseButton and event.pressed:
		_handle_mouse_click(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_hover(event)

	if event.is_action_pressed("ui_cancel"):  # Escape / Right click sometimes maps here
		on_cancel_command.emit()

	# 5. Debug Keys (Global)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F10:
			on_debug_action.emit("ForceWin")
		elif event.keycode == KEY_F11:
			on_debug_action.emit("ForceFail")


func _handle_camera_controls(event):
	# Pan
	var pan_dir = Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		pan_dir.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		pan_dir.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		pan_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		pan_dir.x += 1

	if pan_dir != Vector2.ZERO:
		# We emit this continuously? No, unhandled_input only fires on change.
		# CameraController needs to poll for continuous movement usually.
		# But this is "InputManager".
		# If we want continuous movement, we might need _process here or let CameraController verify Input.
		# REF: Prompt says "Refactor CameraController ... Connect to InputManager signals".
		# Better Pattern for WASD: InputManager emits "on_camera_pan" state?
		# Or CameraController polls Input directly for Axes?
		# "InputManager should be the only script that listens for _unhandled_input".
		# WASD is continuous. `unhandled_input` is discrete events.
		# Let's keep WASD polling in CameraController OR put `_process` in InputManager to emit pan.
		# Let's put `_process` in InputManager to emit pan signals every frame if pressed.
		pass

	# Zoom (Discrete)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			on_camera_zoom.emit(-1.0)  # Zoom In
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			on_camera_zoom.emit(1.0)  # Zoom Out

	# Rotate (Discrete)
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		# Holding right click for drag? Or click to cancel?
		# Current design: Right Click Drag Rotate.
		# Let's handle generic Right Click as "Cancel" if short?
		# Or emit "on_cancel" on Release if no drag?
		# Simpler: Main.gd logic used Right Click for Cancel.
		pass


func _process(_delta):
	if not GameManager:
		return
	var state = GameManager.current_state
	if state != GameManager.GameState.MISSION and state != GameManager.GameState.BASE:
		return
	if is_input_blocked:
		return

	# Continuous Pan polling
	var pan = Vector2.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		pan.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		pan.y += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		pan.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		pan.x += 1

	if pan != Vector2.ZERO:
		on_camera_pan.emit(pan)

	# Rotation inputs (Q/E)
	if Input.is_key_pressed(KEY_Q):
		on_rotation_request.emit(-1)
	if Input.is_key_pressed(KEY_E):
		on_rotation_request.emit(1)


func _handle_mouse_click(event: InputEventMouseButton):
	# Get Camera
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	# Ignore scroll wheel here (handled in _unhandled_input)
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		return

	# Raycast
	var from = camera.project_ray_origin(event.position)
	var dir = camera.project_ray_normal(event.position)

	# Create Query
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * RAY_LENGTH)
	# Default mask (1) is fine for Ground/Units

	var space = camera.get_world_3d().direct_space_state
	var result = space.intersect_ray(query)

	# 5. Debug Keys (Moved to unhandled_input)

	if result:
		var grid_pos = _result_to_grid(result.position)
		on_tile_clicked.emit(grid_pos, event.button_index)

		# Also emit Cancel for Right Click?
		if event.button_index == MOUSE_BUTTON_RIGHT:
			on_cancel_command.emit()


func _handle_mouse_hover(event: InputEventMouseMotion):
	var result = _raycast_from_mouse(event.position)
	if result:
		var grid_pos = _result_to_grid(result.position)
		on_mouse_hover.emit(grid_pos)


func _raycast_from_mouse(screen_pos: Vector2):
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return null
		
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	
	var query = PhysicsRayQueryParameters3D.create(from, from + dir * RAY_LENGTH)
	# query.collision_mask = 1 # Default (Visible) - Hidden props (Layer 2) are ignored!
	
	var space = camera.get_world_3d().direct_space_state
	return space.intersect_ray(query)


func _result_to_grid(hit_pos: Vector3) -> Vector2:
	var tile_size = 2.0
	var grid_x = round(hit_pos.x / tile_size)
	var grid_z = round(hit_pos.z / tile_size)
	return Vector2(grid_x, grid_z)

