extends Node

# --- TEST: Turn Manager Logic ---
# Verifies: Turn Cycling, AP Reset, Auto-End Turn
# Dependencies: TurnManager.gd

var tm
var mock_units = []

class MockUnit extends Node3D:
	var faction = "Player"
	var current_ap = 2
	var max_ap = 2
	var current_hp = 10
	func _ready():
		add_to_group("Units")
	
	func refresh_ap():
		print("MockUnit: refresh_ap called for ", name)
		current_ap = max_ap
		
	func on_turn_start(units, gm): pass
	func process_turn_end_effects(): pass
	func process_turn_start_effects(): pass
	func apply_panic_effect(units, gm): pass
	func decide_action(units, gm): 
		# Simulate instant action (deferred to allow await)
		# emit_signal("action_complete") # OLD
		call_deferred("emit_signal", "action_complete")
		
	signal action_complete

func _ready():
	print("--- TEST START: TurnManager ---")
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	setup_env()
	run_tests()

func setup_env():
	# Clean existing TurnHandlers if any (Singleton check)
	# But we are in a runner, so likely clean.
	tm = load("res://scripts/managers/TurnManager.gd").new()
	tm.name = "TurnManager"
	add_child(tm)
	
	var gm = Node.new()
	gm.name = "GridManager"
	# Add dynamic script to handle method calls
	var gm_script = GDScript.new()
	gm_script.source_code = "extends Node\nfunc refresh_pathfinding(a, b=null): pass\nfunc get_world_position(v): return Vector3.ZERO"
	gm_script.reload()
	gm.set_script(gm_script)
	add_child(gm)

func run_tests():
	await test_initialization()
	await test_turn_cycling()
	
	print("--- ALL TURN MANAGER TESTS PASSED ---")
	get_tree().quit()

func test_initialization():
	print("\nTest: Initialization...")
	
	var u1 = MockUnit.new()
	u1.name = "P1"
	add_child(u1)
	
	tm.start_game([u1])
	
	await get_tree().process_frame
	
	if tm.current_turn == 0: # PLAYER_TURN
		print("PASS: Started in Player Turn.")
	else:
		print("FAIL: Wrong start state: ", tm.current_turn)
		get_tree().quit(1)
		
	if tm.turn_count == 1:
		print("PASS: Turn Count is 1.")
	else:
		print("FAIL: Turn Count mismatch: ", tm.turn_count)
		get_tree().quit(1)
		
	u1.queue_free()

func test_turn_cycling():
	print("\nTest: Turn Cycling (Player -> Enemy -> Env -> Player)...")
	
	var p1 = MockUnit.new()
	p1.name = "Hero"
	p1.faction = "Player"
	add_child(p1)
	
	var e1 = MockUnit.new()
	e1.name = "Villain"
	e1.faction = "Enemy"
	e1.current_ap = 2
	add_child(e1)
	
	tm.start_game([p1, e1])
	await get_tree().process_frame
	
	# 1. Exhaust Player AP
	p1.current_ap = 0
	print("Exhausted Player AP. Checking auto-end...")
	
	tm.check_auto_end_turn()
	
	# Transition is deferred and awaited
	await get_tree().create_timer(1.0).timeout
	
	# Should be Enemy Turn
	if tm.current_turn == 1: # ENEMY_TURN
		print("PASS: Cycled to Enemy Turn.")
	else:
		print("FAIL: Did not cycle to Enemy Turn. State: ", tm.current_turn)
		get_tree().quit(1)
		
	# Enemy Logic runs automatically in start_enemy_turn -> execute actions
	# verify e1.decide_action was called? e1 emits signal immediately.
	# Then it goes to Environment -> Player.
	
	await get_tree().create_timer(3.0).timeout # Allow Enemy + Env phases
	
	if tm.current_turn == 0 and tm.turn_count == 2:
		print("PASS: Cycled back to Player Turn (Turn 2).")
	else:
		print("FAIL: Did not cycle back to Player. State: ", tm.current_turn, " Turn: ", tm.turn_count)
		get_tree().quit(1)
	
	# Verify AP Reset
	if p1.current_ap == p1.max_ap:
		print("PASS: Player AP refreshed.")
	else:
		print("FAIL: Player AP not refreshed.")
		get_tree().quit(1)

	p1.queue_free()
	e1.queue_free()
