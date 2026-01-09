extends SceneTree

# godot -s tests/test_ability_interface.gd

func _init():
	print("--- Starting Ability Interface Tests ---")
	
	test_base_ability()
	test_mock_ability_override()
	test_pmc_logic_check()
	
	print("--- All Ability Tests Passed ---")
	quit()

func test_base_ability():
	print("Test 1: Base Ability Contract")
	var ability = Ability.new()
	
	# 1. get_hit_chance_breakdown
	var info = ability.get_hit_chance_breakdown(null, null, null)
	assert_check(info.is_empty(), "Base hit chance should be empty dict")
	
	# 2. get_valid_tiles
	var tiles = ability.get_valid_tiles(null, null)
	assert_check(tiles.size() == 0, "Base valid tiles should be empty array")
	
	# 3. execute
	var result = ability.execute(null, null, Vector2(0,0), null)
	assert_check(result == "Base ability executed.", "Base execute should return default string")
	
	print("  -> Base Ability OK")

func test_mock_ability_override():
	print("Test 2: Mock Ability Override")
	var ability = MockAbility.new()
	
	var info = ability.get_hit_chance_breakdown(null, null, null)
	assert_check(not info.is_empty(), "Mock ability info should not be empty")
	assert_check(info.has("hit_chance"), "Mock ability should have hit_chance")
	assert_check(info.hit_chance == 95, "Mock ability should return 95%")
	
	print("  -> Mock Ability OK")

func test_pmc_logic_check():
	print("Test 3: PMC Logic Simulation")
	
	var base_ability = Ability.new()
	var mock_ability = MockAbility.new()
	
	# Replicating PMC Logic from Refactor
	# if is_valid:
	#   var info = selected_ability.get_hit_chance_breakdown(...)
	#   if not info.is_empty() and info.has("hit_chance"):
	#       ...
	
	# Case A: Base Ability
	var base_info = base_ability.get_hit_chance_breakdown(null, null, null)
	var base_shows_ui = false
	if not base_info.is_empty() and base_info.has("hit_chance"):
		base_shows_ui = true
	assert_check(base_shows_ui == false, "Base ability logic should Evaluate FALSE for UI")
	
	# Case B: Mock Ability
	var mock_info = mock_ability.get_hit_chance_breakdown(null, null, null)
	var mock_shows_ui = false
	if not mock_info.is_empty() and mock_info.has("hit_chance"):
		mock_shows_ui = true
	assert_check(mock_shows_ui == true, "Mock ability logic should Evaluate TRUE for UI")
	
	print("  -> PMC Logic OK")


# --- Helpers ---
func assert_check(condition, msg):
	if not condition:
		print("FAILED: " + msg)
		quit(1)

# --- MOCKS ---
class MockAbility extends Ability:
	func get_hit_chance_breakdown(_grid_manager, _user, _target) -> Dictionary:
		return {
			"hit_chance": 95,
			"breakdown": {"Base": 100, "Cover": -5}
		}

	func get_valid_tiles(_grid_manager, _user) -> Array[Vector2]:
		return [Vector2(1,1)]
