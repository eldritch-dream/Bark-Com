extends Node

# --- TEST: Enemy AI Logic ---
# Verifies: Target Selection, Movement Scoring, Attack Logic
# Dependencies: EnemyUnit.gd, GridManager.gd, CombatResolver.gd

var grid_manager
var enemy_unit
var player_unit
var mock_tm

class MockTurnManager extends Node:
	var current_turn = 1 
	var units = []
	func check_auto_end_turn(): pass
	func handle_reaction_fire(unit, from_pos): pass

class MockGridVisualizer extends Node:
	func clear_debug_scores(): pass
	func debug_score_tiles(u, tiles): pass
	func show_debug_score(pos, score): pass
	func draw_ai_intent(start, end, color): pass
	func visualize_path(path): pass

class MockVisionManager extends Node:
	func check_visibility(a, b): return true
	func update_vision(units=[]): pass

class MockPlayerUnit extends Node3D:
	var grid_pos = Vector2(0,0)
	var faction = "Player"
	var current_hp = 10
	var max_hp = 10
	# var position is inherited from Node3D
	var is_dead = false
	var modifiers = {}
	var accuracy = 65
	var defense = 10
	var armor = 0
	
	func get_type(): return "Unit"
	
	func take_damage(amount):
		current_hp -= amount
		
	func has_perk(p): return false
	
func _ready():
	print("--- TEST START: Enemy AI ---")
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	setup_env()
	
	# Async Execution
	run_tests()

func setup_env():
	# 1. Grid Manager
	grid_manager = load("res://scripts/managers/GridManager.gd").new()
	add_child(grid_manager)
	
	# Setup simple 10x10 open grid
	for x in range(10):
		for y in range(10):
			var tile = Vector2(x,y)
			grid_manager.grid_data[tile] = {
				"type": 0, "is_walkable": true, "world_pos": Vector3(x, 0, y)
			}

	# 2. TurnManager (Group)
	mock_tm = MockTurnManager.new()
	mock_tm.add_to_group("TurnManager")
	mock_tm.add_to_group("TurnManager")
	add_child(mock_tm)
	
	# 3. Visualizer (Mock)
	var gv = MockGridVisualizer.new()
	gv.name = "GridVisualizer"
	add_child(gv)
	
	# 4. VisionManager (Mock)
	var vm = MockVisionManager.new()
	vm.name = "VisionManager"
	add_child(vm)
	
	# Setup AStar (Critical!)
	grid_manager._setup_astar()

func run_tests():
	await test_movement_towards_enemy()
	await test_attack_in_range()
	# await test_cover_preference() # Complex to setup cover data in mock grid, maybe later
	
	
	if failures > 0:
		print("❌ FAILED: ", failures, " tests failed.")
		get_tree().quit(1)
	else:
		print("✅ ALL AI TESTS PASSED")
		get_tree().quit()

var failures = 0
func fail(msg):
	print(msg)
	failures += 1
	
func pass_test(msg):
	print(msg)

func test_movement_towards_enemy():
	print("\nTest: Movement Towards Enemy...")
	
	# Setup
	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.name = "AI_Rusher"
	add_child(enemy)
	enemy.initialize(Vector2(0,0))
	enemy.mobility = 4
	enemy.attack_range = 1 # Melee
	
	mock_tm.units.append(enemy)
	
	var target = MockPlayerUnit.new()
	target.grid_pos = Vector2(8,0) # Far away
	target.position = Vector3(8,0,0)
	target.name = "TargetDummy"
	add_child(target)
	mock_tm.units.append(target)
	
	# Execute
	# We want to spy on movement. EnemyUnit calls move_along_path -> state_machine.transition
	# But EnemyUnit.move_along_path prints and updates grid_pos eventually?
	# Actual movement is async and visual.
	# For logic test, we care about the DECISION.
	# But decide_action does everything.
	
	# Verify Start
	if enemy.grid_pos != Vector2(0,0):
		fail("FAIL: Enemy not at start.")
		return
	
	# We expect AI to move CLOSER to (8,0). 
	# Max move 4. Should end at (4,0).
	
	print("Running decide_action...")
	await enemy.decide_action([target, enemy], grid_manager)
	
	# Check Result
	print("Enemy End Pos: ", enemy.grid_pos)
	
	if enemy.grid_pos.x > 0:
		pass_test("PASS: Enemy moved towards target.")
	else:
		fail("FAIL: Enemy did not move. Pos: " + str(enemy.grid_pos))
		
	enemy.queue_free()
	target.queue_free()

func test_attack_in_range():
	print("\nTest: Attack In Range...")
	
	var enemy = load("res://scripts/entities/EnemyUnit.gd").new()
	enemy.name = "AI_Shooter"
	add_child(enemy)
	enemy.initialize(Vector2(5,5))
	enemy.accuracy = 200 # Force 100% hit chance for test stability
	enemy.attack_range = 4
	enemy.current_ap = 10 # Ensure AP for move + shoot
	mock_tm.units.append(enemy)
	
	var target = MockPlayerUnit.new()
	target.grid_pos = Vector2(5,9) # Distance 4 (Ideal)
	target.position = Vector3(5,0,9)
	target.name = "Victim"
	add_child(target)
	mock_tm.units.append(target)
	
	# Spy on Combat?
	# CombatResolver.execute_attack -> writes to target.current_hp
	var start_hp = target.current_hp
	
	await enemy.decide_action([target, enemy], grid_manager)
	
	if target.current_hp < start_hp:
		pass_test("PASS: Enemy attacked target (HP Dropped: " + str(start_hp) + " -> " + str(target.current_hp) + ")")
	else:
		fail("FAIL: Enemy did not damage target.")

	enemy.queue_free()
	target.queue_free()
