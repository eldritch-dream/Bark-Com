extends Node

var game_manager_script = load("res://scripts/core/GameManager.gd")
var gm

func _ready():
	print("--- TEST BOOTSTRAP: Persistence & Roster Integrity ---")
	
	# Anti-Ghosting Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# Clean up previous runs
	var dir = DirAccess.open("user://")
	if dir.file_exists("test_savegame.dat"):
		dir.remove("test_savegame.dat")
		
	# Setup fake user directory logic by checking if we are in tmp dir?
	# We rely on CLI --user-data-dir. 
	
	_run_tests()
	get_tree().quit()

func _run_tests():
	_test_save_load_cycle()
	_test_mission_completion_roster_integrity()
	_test_iron_dog_logic()

func _test_save_load_cycle():
	print("\n[TEST] Save/Load Cycle...")
	
	gm = game_manager_script.new()
	add_child(gm)
	
	gm.kibble = 500
	gm.missions_completed = 3
	gm.roster.clear()
	gm._add_recruit("TestDog_A", 2, "Scout")
	
	gm.save_game()
	
	if not FileAccess.file_exists("user://savegame.dat"):
		print("FAIL: Save file not created.")
	else:
		gm.kibble = 0
		gm.roster.clear()
		gm.load_game()
		
		if gm.kibble == 500 and gm.roster.size() == 1:
			print("PASS: Save/Load Cycle Integrity Confirmed.")
		else:
			print("FAIL: Data mismatch.")
			
	gm.queue_free()

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
		print("FAIL: Beta should be purged.")
	else:
		print("PASS: Dead unit purged correctly.")
		
	if not _find_in_roster("Alpha"):
		print("FAIL: Alpha should survive.")
	else:
		print("PASS: Survivor intact.")
	
	# Fail Safe
	gm.roster.clear()
	gm._add_recruit("LoneWolf", 1, "Scout")
	gm.deploying_squad = [gm.roster[0]]
	gm.complete_mission([], true, [], 100)
	
	if gm.roster.size() == 1:
		print("PASS: Fail-Safe triggered for empty survivors on win.")
	else:
		print("FAIL: Fail-Safe failed.")
		
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
	
	gm.complete_mission([], false, [], 0)
	
	if FileAccess.file_exists("user://savegame.dat"):
		print("FAIL: Save not deleted on wipe.")
	else:
		print("PASS: Save deleted.")
		
	gm.queue_free()

func _find_in_roster(name):
	for u in gm.roster:
		if u["name"] == name: return u
	return null
