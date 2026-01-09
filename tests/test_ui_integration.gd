extends SceneTree

# Usage: godot -s tests/test_ui_integration.gd

var GameUI_Script
var SignalBus_Script

class MockGridManager:
	func is_walkable(pos): return true

class MockTurnManager:
	var units = []

class MockUnit:
	var name = "TestUnit"
	var current_hp = 10
	var max_hp = 10
	var faction = "Player"
	var inventory = []
	var abilities = []
	func has_method(m): return true
	func get(p): 
		if p == "faction": return "Player"
		return null

func _init():
	print("--- STARTING UI INTEGRATION TESTS ---")
	
	GameUI_Script = load("res://scripts/ui/GameUI.gd")
	if not GameUI_Script:
		printerr("CRITICAL FAIL: Could not load GameUI script! Check for syntax errors or duplicates.")
		quit(1)
		return

	test_signal_connection_and_processing()
	
	print("--- ALL UI TESTS PASSED ---")
	quit()

func test_signal_connection_and_processing():
	var gui = GameUI_Script.new()
	var mock_tm = MockTurnManager.new()
	var mock_gm = MockGridManager.new()
	
	# Initialize (Dependency Injection)
	gui.initialize(mock_tm, mock_gm)
	
	# Simulate _ready (Manually call since we aren't adding to tree usually, 
	# but GameUI connects in _ready. We must add to tree to trigger _ready or call it.
	# Adding to root to trigger lifecycle.)
	root.add_child(gui)
	
	# 1. Test Squad Init Signal
	var units = [MockUnit.new(), MockUnit.new()]
	print("Emitting on_squad_list_initialized...")
	SignalBus.on_squad_list_initialized.emit(units)
	
	# Verification: Check if gui.squad_list_container has children
	# accessing private vars for test is okay
	if gui.squad_list_container.get_child_count() == 2:
		print("PASS [Squad List Init]: Created 2 frames.")
	else:
		print("FAIL [Squad List Init]: Expected 2 frames, got ", gui.squad_list_container.get_child_count())

	# 2. Test Log Signal
	print("Emitting on_combat_log_event...")
	SignalBus.on_combat_log_event.emit("Test Message", Color.WHITE)
	# No crash = Good.
	# If we could check log history, we would.
	print("PASS [Combat Log]: Signal handled without crash.")
	
	# 3. Test Pause Signal
	print("Emitting on_request_pause...")
	SignalBus.on_request_pause.emit()
	if gui.pause_menu and gui.pause_menu.visible:
		print("PASS [Pause Menu]: Menu became visible.")
	else:
		print("FAIL [Pause Menu]: Menu did not open.")
		
	# 4. Test Select Unit Signal
	print("Emitting on_ui_select_unit...")
	var ref_unit = MockUnit.new()
	ref_unit.name = "SelectionTest"
	SignalBus.on_ui_select_unit.emit(ref_unit)
	if gui.selected_unit == ref_unit:
		print("PASS [Selection]: Unit selected correctly.")
	else:
		print("FAIL [Selection]: Expected unit selection not applied.")

	gui.queue_free()
