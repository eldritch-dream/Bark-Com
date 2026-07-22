extends Node

const LOG_PREFIX = "VerifyBonds: "

func _ready():
	print(LOG_PREFIX, "Starting Bond Clearing Test...")
	
	# Watchdog
	var guard = load("res://tests/TestSafeGuard.gd").new()
	add_child(guard)
	
	await get_tree().process_frame
	
	# 1. Setup - Mocking New Game
	# Ensure GameManager is present (it should be if run as scene)
	if not GameManager:
		print(LOG_PREFIX, "FATAL: GameManager not found!")
		get_tree().quit(1)
		return

	# Force Test Mode
	GameManager.TEST_MOCK_ENABLED = true
	GameManager.save_file_path = "user://test_savegame.dat"
	
	# Start Fresh
	GameManager.new_game()
	
	# 2. Add Units
	# Unit A: Dead Dog
	# Unit B: Survivor (On Mission)
	# Unit C: Survivor (At Base)
	# Unit D: Survivor (On Mission)
	
	var unit_a = "UnitDead"
	var unit_b = "UnitLiveMission"
	var unit_c = "UnitLiveBase"
	var unit_d = "UnitLiveMissionPartner"
	
	GameManager._add_recruit(unit_a, 1, "Recruit")
	GameManager._add_recruit(unit_b, 1, "Recruit")
	GameManager._add_recruit(unit_c, 1, "Recruit")
	GameManager._add_recruit(unit_d, 1, "Recruit")
	
	# 3. Create Bonds
	# A <-> B (Should Clear)
	# A <-> C (Should Clear)
	# B <-> C (Should PERIST)
	# B <-> D starts at zero and should grow exactly once after they survive together.
	
	GameManager.modify_bond(unit_a, unit_b, 10)
	GameManager.modify_bond(unit_a, unit_c, 10)
	GameManager.modify_bond(unit_b, unit_c, 10)
	
	print(LOG_PREFIX, "Initial Bonds Set.")
	print(" - A-B: ", GameManager.get_bond_score(unit_a, unit_b))
	print(" - A-C: ", GameManager.get_bond_score(unit_a, unit_c))
	print(" - B-C: ", GameManager.get_bond_score(unit_b, unit_c))
	
	# Verify Setup
	if GameManager.get_bond_score(unit_a, unit_b) != 10:
		print(LOG_PREFIX, "Setup Failed: Bond A-B not set.")
		get_tree().quit(1)
		return
		
	# 4. Simulate Mission & Death
	print(LOG_PREFIX, "Simulating Mission where Unit A dies...")
	
	# Setup Squad (A, B, and D went on mission)
	var squad = []
	for u in GameManager.roster:
		if u.name == unit_a or u.name == unit_b or u.name == unit_d:
			squad.append(u)
	
	GameManager.deploying_squad = squad
	
	# Surviving Squad Data (B and D return)
	var survivors = []
	var b_data = {
		"name": unit_b,
		"hp": 10,
		"xp": 0,
		"inventory": []
	}
	survivors.append(b_data)
	var d_data = {
		"name": unit_d,
		"hp": 10,
		"xp": 0,
		"inventory": []
	}
	survivors.append(d_data)
	
	# Register Death explicitly usually happens via 'fallen_heroes' logic check or just missing from survivors.
	# GameManager.complete_mission checks against 'deploying_squad'.
	# Any deployed unit NOT in 'survivors' AND in 'fallen_heroes' is removed?
	# Wait, let's check GameManager.gd lines 597-608.
	# If not found in survivors: checks if in fallen_heroes.
	# IF in fallen_heroes -> Removed.
	# So we MUST register A as fallen hero first.
	
	var a_full_data = null
	for u in GameManager.roster:
		if u.name == unit_a:
			a_full_data = u
			break
			
	GameManager.register_fallen_hero(a_full_data, "Test Death")
	
	# 5. Complete Mission
	GameManager.complete_mission(survivors, true, [], 0)
	
	# 6. Verify Bonds
	print(LOG_PREFIX, "Verifying Bonds after Death...")
	
	var bond_ab = GameManager.get_bond_score(unit_a, unit_b)
	var bond_ac = GameManager.get_bond_score(unit_a, unit_c)
	var bond_bc = GameManager.get_bond_score(unit_b, unit_c)
	var bond_bd = GameManager.get_bond_score(unit_b, unit_d)
	
	print(" - A-B (Should be 0): ", bond_ab)
	print(" - A-C (Should be 0): ", bond_ac)
	print(" - B-C (Should be 10): ", bond_bc)
	print(" - B-D (Should be 1): ", bond_bd)
	
	var fail = false
	
	if bond_ab != 0:
		print(LOG_PREFIX, "FAIL: Bond A-B persisted!")
		fail = true
		
	if bond_ac != 0:
		print(LOG_PREFIX, "FAIL: Bond A-C persisted!")
		fail = true
		
	if bond_bc != 10:
		print(LOG_PREFIX, "FAIL: Bond B-C was incorrectly removed/modified! Val: ", bond_bc)
		fail = true

	if bond_bd != 1:
		print(LOG_PREFIX, "FAIL: Mission survivor bond should grow exactly once! Expected: 1, Actual: ", bond_bd)
		fail = true
		
	if fail:
		print(LOG_PREFIX, "Verification FAILED.")
		get_tree().quit(1)
	else:
		print(LOG_PREFIX, "SUCCESS: Bonds cleared correctly.")
		get_tree().quit(0)
