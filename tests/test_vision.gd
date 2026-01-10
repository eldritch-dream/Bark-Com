extends Node3D

# --- TEST: Vision Manager Logic ---
# Verifies: Line of Sight (Raycasting), Obstacle Occlusion
# Dependencies: VisionManager.gd, Physics Server

var vm
var wall
var unit_a
var unit_b

func _ready():
	print("--- TEST START: VisionManager ---")
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	setup_env()
	run_tests()

func setup_env():
	# 1. Vision Manager
	vm = load("res://scripts/managers/VisionManager.gd").new()
	vm.name = "VisionManager"
	add_child(vm)
	
	# We don't need full GridManager for _has_line_of_sight if we call it directly, 
	# but vm.initialize() might be needed for other methods.
	# For strict unit testing of _has_line_of_sight, we can just use the method if it doesn't crash.
	# It uses get_world_3d().direct_space_state which is available on Node3D.
	
	setup_physics_world()

func setup_physics_world():
	# Create floor? Not needed if we raycast horizontally at height 1.5
	
	# Create Wall Obstacle at (2, 0, 0)
	wall = StaticBody3D.new()
	wall.name = "Wall"
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1, 2, 1) # Full height wall
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(5, 1, 5) # Mid path, raised to block Y=1.5
	add_child(wall)
	
	print("Physics World Setup. Wall at ", wall.position)

func run_tests():
	await get_tree().physics_frame
	await get_tree().physics_frame # Wait for physics to register
	
	await test_clear_los()
	await test_blocked_los()
	
	print("--- ALL VISION TESTS PASSED ---")
	get_tree().quit()

func test_clear_los():
	print("\nTest: Clear Line of Sight...")
	
	var from = Vector3(0, 1.5, 0)
	var to = Vector3(2, 1.0, 0) # Short distance, no wall
	
	var result = vm._has_line_of_sight(from, to, [])
	
	if result == true:
		print("PASS: LOS is clear.")
	else:
		print("FAIL: LOS reported blocked (Expected Clear).")
		get_tree().quit(1)

func test_blocked_los():
	print("\nTest: Blocked Line of Sight...")
	
	# Wall is at (5,0,5).
	# Cast from (4, 1.5, 5) to (6, 1.0, 5). Wall is in between.
	
	var from = Vector3(4, 1.5, 5)
	var to = Vector3(6, 1.0, 5)
	
	# Ensure wall is collision layer 1 (default) and query uses it.
	
	var result = vm._has_line_of_sight(from, to, [])
	
	if result == false:
		print("PASS: LOS is blocked.")
	else:
		print("FAIL: LOS reported clear (Expected Blocked).")
		get_tree().quit(1)
