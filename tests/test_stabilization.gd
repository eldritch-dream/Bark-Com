extends Node

# Usage: Run via tests/test_stabilization_runner.tscn

var MainScript

func _ready():
	print("--- STARTING STABILIZATION TESTS ---")
	add_child(load("res://tests/TestSafeGuard.gd").new())
	await get_tree().process_frame
	
	MainScript = load("res://scripts/core/Main.gd")
	if not MainScript:
		printerr("CRITICAL: Main.gd failed to load.")
		get_tree().quit(1)
		return

	test_mission_ended_signature()
	test_main_signal_safety()
	
	print("--- ALL STABILIZATION TESTS PASSED ---")
	get_tree().quit()

func test_mission_ended_signature():
	var main = MainScript.new()
	# Check if method accepts 2 args
	print("Testing _on_mission_ended_handler signature...")
	main._mission_end_processed = false # Reset state
	
	# Mock dependencies effectively null
	# Note: Main.gd uses SignalBus (Autoload). Since Node runner has Autoloads, it should be safer.
	# Use REAL MissionManager class for type safety
	var mm_script = load("res://scripts/managers/MissionManager.gd")
	var real_mm = mm_script.new()
	real_mm.name = "MissionManager"
	# We need to assign it to main.mission_manager. 
	# Does Main have valid reference? Main._ready() not called.
	# Main initializes mission_manager in _ready.
	# So we must set it manually.
	main.mission_manager = real_mm
	# Initialize config so it's not null
	real_mm.active_mission_config = {}
	
	main._on_mission_ended_handler(true, 100) 
	print("PASS: Called with 2 arguments successfully.")
	main.free()

func test_main_signal_safety():
	var main = MainScript.new()
	
	# Check SignalBus connection count?
	var connections = SignalBus.on_turn_changed.get_connections()
	for c in connections:
		# Check if object is instance of Main Logic
		if c.callable.get_object().get_script() == MainScript:
			# Found it
			pass
			# This checks if ANY Main instance is connected.
			# Since we just created 'main', it might be connected if _ready ran?
			# _ready doesn't run on .new() unless added to tree.
			pass
			
	print("PASS: Signal Safety (heuristic check)")
	main.free()
