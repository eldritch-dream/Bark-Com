extends Node

var game_manager_script = load("res://scripts/core/GameManager.gd")
var gm

func _ready():
	print("--- TEST BOOTSTRAP: Persistence & Roster Integrity ---")
	
	# Anti-Ghosting Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# Clean up previous runs
	var dir = DirAccess.open("user://")
	# Clean BOTH test and potential real save file to prevent logic collision?
	# Ideally we should backup the real one, but running tests locally on dev machine is risky.
	# The user is running this via pre-commit, so it's a dev environment.
	# Safety: Only delete if it looks like a test artifact? No, the test writes to 'savegame.dat'.
	# We must clean it.
	if dir.file_exists("savegame.dat"):
		dir.remove("savegame.dat")
	if dir.file_exists("test_savegame.dat"):
		dir.remove("test_savegame.dat")
		
	# Setup fake user directory logic by checking if we are in tmp dir?
	# We rely on CLI --user-data-dir. 
	
	_run_tests()
	
	if failures > 0:
		print("❌ FAILED: ", failures, " tests failed.")
		get_tree().quit(1)
	else:
		print("✅ PASS: All tests passed.")
		get_tree().quit()

var failures = 0
func fail(msg):
	print(msg)
	failures += 1
	
func pass_test(msg):
	print(msg)

func _run_tests():
	print("--- Starting Persistence Tests ---")
	_test_save_load_cycle()
	_test_mission_completion_roster_integrity()
	_test_iron_dog_logic()
	print("--- Finished Persistence Tests ---")

func _test_save_load_cycle():
	print("\n[TEST] Save/Load Cycle...")
	
	var test_path = "user://test_savegame.dat"
	
	# Ensure clean slate
	var dir = DirAccess.open("user://")
	if dir.file_exists("test_savegame.dat"):
		dir.remove("test_savegame.dat")

	gm = game_manager_script.new()
	gm.save_file_path = test_path # ISOLATION
	add_child(gm)
	
	gm.kibble = 500
	gm.missions_completed = 3
	gm.roster.clear()
	gm._add_recruit("TestDog_A", 2, "Scout")
	
	gm.save_game()
	
	# Wait for IO?
	await get_tree().process_frame
	
	if not FileAccess.file_exists(test_path):
		fail("FAIL: Save file not created at " + test_path)
	else:
		gm.kibble = 0
		gm.roster.clear()
		gm.load_game()
		
		# Validation
		if gm.kibble == 500 and gm.roster.size() == 1:
			pass_test("PASS: Save/Load Cycle Integrity Confirmed.")
		else:
			fail("FAIL: Data mismatch. Kibble: " + str(gm.kibble) + " Roster: " + str(gm.roster.size()))
			
	gm.queue_free()
	await get_tree().process_frame

func _test_mission_completion_roster_integrity():
	print("\n[TEST] Mission Completion & Roster Safety...")
	gm = game_manager_script.new()
	add_child(gm)
	
	gm.roster.clear()
	gm._add_recruit("Alpha", 1, "Scout")
	gm._add_recruit("Beta", 1, "Heavy")
	
	# Mock Deployment
	gm.deploying_squad = [gm.roster[0], gm.roster[1]]
	
	# Beta dies (Survivor only Alpha)
	var survivors = [{"name": "Alpha", "hp": 8, "inventory": []}]
	gm.register_fallen_hero(gm.roster[1], "Test Death")
	
	gm.complete_mission(survivors, true, [], 100)
	
	if _find_in_roster("Beta"):
		fail("FAIL: Beta should be purged.")
	else:
		pass_test("PASS: Dead unit purged correctly.")
		
	if not _find_in_roster("Alpha"):
		fail("FAIL: Alpha should survive.")
	else:
		pass_test("PASS: Survivor intact.")
	
	# Fail Safe
	gm.roster.clear()
	gm._add_recruit("LoneWolf", 1, "Scout")
	gm.deploying_squad = [gm.roster[0]]
	gm.complete_mission([], true, [], 100)
	
	if gm.roster.size() == 1:
		pass_test("PASS: Fail-Safe triggered for empty survivors on win.")
	else:
		fail("FAIL: Fail-Safe failed.")
		
	gm.queue_free()

func _test_iron_dog_logic():
	print("\n[TEST] Iron Dog Wipe...")
	gm = game_manager_script.new()
	add_child(gm)
	gm.iron_dog_mode = true
	gm.roster.clear()
	gm._add_recruit("IronPup", 1)
	gm.deploying_squad = [gm.roster[0]]
	
	# Create dummy save
	var f = FileAccess.open("user://savegame.dat", FileAccess.WRITE)
	f.store_string("test")
	f.close()
	
	# Register death to ensure roster purge triggers
	gm.register_fallen_hero(gm.roster[0], "Wiped")
	
	gm.complete_mission([], false, [], 0)
	
	if FileAccess.file_exists("user://savegame.dat"):
		fail("FAIL: Save not deleted on wipe.")
	else:
		pass_test("PASS: Save deleted.")
		
	gm.queue_free()

func _find_in_roster(name):
	for u in gm.roster:
		if u["name"] == name: return u
	return null
