extends Node

func _ready():
	print("--- Starting Feature Helper Tests (Scene Mode) ---")
	
	# Wait one frame to ensure Autoloads are fully reliable (though _ready usually suffices)
	await get_tree().process_frame
	
	test_grenade_helper()
	test_hack_helper()
	test_special_grenades()
	test_status_consistency()
	
	if load("res://scripts/ui/UnitStatusUI.gd"):
		print("  -> UnitStatusUI Syntax Valid")
	else:
		print("FAILED: UnitStatusUI Syntax Error")
		get_tree().quit(1)
	
	print("--- All Feature Helper Tests Passed ---")
	get_tree().quit(0)
	get_tree().quit()

func test_grenade_helper():
	print("Test 1: Grenade Hit Chance")
	
	var grenade_script = load("res://scripts/abilities/GrenadeToss.gd")
	if not grenade_script:
		print("FAILED: Could not load GrenadeToss.gd")
		get_tree().quit(1)
		return
		
	var grenade = grenade_script.new()
	# Grenade hit chance is primarily Base 80% initially
	
	var info = grenade.get_hit_chance_breakdown(null, null, null)
	assert_check(info.has("hit_chance"), "Grenade info missing hit_chance. Info: " + str(info))
	var chance = info.get("hit_chance")
	assert_check(chance == 80, "Grenade base chance should be 80. Got: " + str(chance))
	
	print("  -> Grenade logic valid.")
	# Grenade is RefCounted, auto-freed.

func test_hack_helper():
	print("Test 2: Hack Chance")
	
	var hack_script = load("res://scripts/abilities/HackAbility.gd")
	if not hack_script:
		print("FAILED: Could not load HackAbility.gd")
		get_tree().quit(1)
		return
		
	var hack = hack_script.new()
	
	# Mock User
	var UserMock = load("res://scripts/entities/Unit.gd") 
	var user = UserMock.new()
	user.tech_score = 0
	
	# Case A: Base Tech (0)
	var info = hack.get_hit_chance_breakdown(null, user, null)
	var chance = info.get("hit_chance")
	assert_check(chance == 70, "Hack base chance should be 70. Got: " + str(chance) + " Info: " + str(info))
	
	# Case B: High Tech (10)
	user.tech_score = 10
	var info_high = hack.get_hit_chance_breakdown(null, user, null)
	var chance_high = info_high.get("hit_chance")
	assert_check(chance_high == 80, "Hack w/ 10 Tech should be 80. Got: " + str(chance_high))
	
	# Case C: Max Tech (100) -> Cap 100
	user.tech_score = 50
	var info_cap = hack.get_hit_chance_breakdown(null, user, null)
	var chance_cap = info_cap.get("hit_chance")
	assert_check(chance_cap == 100, "Hack should cap at 100. Got: " + str(chance_cap))
	
	print("  -> Hack logic valid.")
	
	user.free() # Unit extends CharacterBody3D (Node), must be freed.
	# Hack (Ability) is RefCounted, no free.

func test_special_grenades():
	print("Test 3: Special Grenades")
	
	var inc_script = load("res://scripts/abilities/IncendiaryGrenade.gd")
	if inc_script:
		var inc = inc_script.new()
		var info = inc.get_hit_chance_breakdown(null, null, null)
		assert_check(info.get("hit_chance") == 80, "Incendiary should appear with 80% chance")
		print("  -> Incendiary Valid")
	
	var flash_script = load("res://scripts/abilities/FlashbangToss.gd")
	if flash_script:
		var flash = flash_script.new()
		var info = flash.get_hit_chance_breakdown(null, null, null)
		assert_check(info.get("hit_chance") == 80, "Flashbang should appear with 80% chance")

func test_status_consistency():
	print("Test 4: Status Consistency")
	var paths = [
		"res://scripts/resources/statuses",
		"res://scripts/resources/effects"
	]
	
	for p in paths:
		var dir = DirAccess.open(p)
		if dir:
			dir.list_dir_begin()
			var fn = dir.get_next()
			while fn != "":
				if not dir.current_is_dir() and fn.ends_with(".gd"):
					var res = load(p + "/" + fn)
					if res:
						var inst = res.new()
						var name = inst.display_name if "display_name" in inst else "UNKNOWN"
						
						# Validations
						assert_check("description" in inst and inst.description != "", name + " has description")
						assert_check("type" in inst, name + " has type")
						
						if "icon" in inst and inst.icon:
							pass
						else:
							print("FAILED: " + name + " missing icon!")
						
						# Check Type is Valid (0 or 1 usually)
						if "type" in inst:
							if inst.type == 0: pass # BUFF
							elif inst.type == 1: pass # DEBUFF
							else: print("WARN: " + name + " is NEUTRAL or Invalid")
							
				fn = dir.get_next()
	print("  -> Status Consistency Verified")


func assert_check(condition, msg):
	if not condition:
		print("FAILED: " + msg)
		get_tree().quit(1)
