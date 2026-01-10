extends Node

# Usage: godot -s tests/test_mission_rewards.gd

func _ready():
	print("--- STARTING MISSION REWARDS TEST ---")
	add_child(load("res://tests/TestSafeGuard.gd").new())
	await get_tree().process_frame
	
	var GM_Script = load("res://scripts/core/GameManager.gd")
	var GM = GM_Script.new()
	# Mock UI manager requirement? GM uses SignalBus.
	
	# 1. Test Generation
	print("TEST 1: Mission Generation (Rescue Rewards)")
	GM._generate_daily_batch() # Populates available_missions
	
	var found_rescue = false
	for m in GM.available_missions:
		if m.objective_type == 1: # Rescue
			found_rescue = true
			if m.reward_recruit_data.size() > 0:
				print("PASS: Rescue Mission has reward data: ", m.reward_recruit_data)
				
				# Check Level Match
				if m.reward_recruit_data["level"] == m.difficulty_rating:
					print("PASS: Recruit Level matches Difficulty (", m.difficulty_rating, ")")
				else:
					printerr("FAIL: Recruit Level mismatch. Diff: ", m.difficulty_rating, " Recruit: ", m.reward_recruit_data["level"])
			else:
				printerr("FAIL: Rescue Mission missing reward data.")
	
	if not found_rescue:
		print("WARN: No Rescue mission generated in this batch. Forcing one.")
		var m = load("res://scripts/resources/MissionData.gd").new()
		m.objective_type = 1
		m.difficulty_rating = 2
		GM.available_missions.clear()
		GM.available_missions.append(m)
		# Trigger logic manually? _generate_daily_batch does it.
		# We need to spy on _generate logic or just trust standard gen eventually hits it.
		# Ideally we force the outcome.
		
	# 2. Test Completion
	print("TEST 2: Mission Completion Award")
	
	# SETUP: Populate Roster and Squad
	GM.roster.clear()
	var vet = {"name": "VeteranDog", "level": 5, "class": "Heavy", "hp": 20, "status": "Ready"}
	GM.roster.append(vet)
	GM.deploying_squad = [vet] # They are deployed
	
	# Setup specific mission
	var mission = load("res://scripts/resources/MissionData.gd").new()
	mission.objective_type = 1
	mission.reward_recruit_data = {"name": "RewardDog", "class": "Scout", "level": 3}
	GM.active_mission = mission
	
	var initial_size = GM.roster.size()
	print("DEBUG: Pre-Mission Roster Size: ", initial_size)
	
	# EXECUTE: Complete with EMPTY survivors (Simulate 'missing' units)
	# This triggers logic: deployed but not in survivors.
	# Should print "Unit missing but NOT in Memorial?". Should NOT remove.
	GM.complete_mission([], true, [], 0) 
	
	print("DEBUG: Post-Mission Roster Size: ", GM.roster.size())
	
	var found_vet = false
	var found_reward = false
	
	for u in GM.roster:
		if u["name"] == "VeteranDog": found_vet = true
		if u["name"] == "RewardDog": found_reward = true
		
	if found_vet:
		print("PASS: VeteranDog persisted (was missing but not fallen).")
	else:
		printerr("FAIL: VeteranDog was WIPED!")
		
	if found_reward:
		print("PASS: RewardDog added.")
	else:
		printerr("FAIL: RewardDog missing.")
		
	if GM.roster.size() == 2:
		print("PASS: Roster size correct.")
	else:
		printerr("FAIL: Roster size mismatch. Expected 2, Got: ", GM.roster.size())
		
	print("--- MISSION REWARDS TEST COMPLETE ---")
	GM.free()
	get_tree().quit()
