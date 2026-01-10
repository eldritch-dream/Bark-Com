extends Node

var pmc
var grid_manager
var selected_unit
var signal_data = {}

func _ready():
	print("--- TEST START: Ground Targeting Abilities (Runner Mode) ---")
	
	# Anti-Ghosting Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	setup_env()
	
	# Execute Async
	run_all_tests()

func run_all_tests():
	await test_ability("GrenadeToss", load("res://scripts/abilities/GrenadeToss.gd"), 80)
	await test_ability("Flashbang", load("res://scripts/abilities/FlashbangToss.gd"), 80)
	await test_ability("RocketLauncher", load("res://scripts/abilities/RocketLauncherAbility.gd"), 100)
	await test_ability("ScatterShot", load("res://scripts/abilities/ScatterShot.gd"), 100)
	await test_ability("SuppressionFire", load("res://scripts/abilities/SuppressionFireAbility.gd"), 100)
	await test_ability("IncendiaryGrenade", load("res://scripts/abilities/IncendiaryGrenade.gd"), 80)
	
	print("--- ALL GROUND TARGETING TESTS PASSED ---")
	print("Exiting...")
	get_tree().quit()

func setup_env():

	# 1. Spy on Real SignalBus
	# It should be available as 'SignalBus' global
	if not get_node_or_null("/root/SignalBus"):
		printerr("CRITICAL: SignalBus Autoload NOT found. Test will fail.")
		get_tree().quit(1)
		return
		
	var sb = get_node("/root/SignalBus")
	sb.on_show_hit_chance.connect(func(c, d, p): 
		signal_data = {'chance': c}
		# print("Debug: Hit Chance Signal: ", c)
	)
	sb.on_hide_hit_chance.connect(func(): 
		signal_data = {}
		# print("Debug: Hide Signal")
	)
	
	# 2. GridManager
	# We use real class but custom instance
	grid_manager = load("res://scripts/managers/GridManager.gd").new()
	add_child(grid_manager)
	
	# Setup Data (Ground Tile)
	# (5,5) = Unit, (5,6) = Ground
	# grid_data values must be Dictionary with 'type', 'is_walkable' etc
	grid_manager.grid_data[Vector2(5,5)] = {"type": 0, "is_walkable": true, "world_pos": Vector3(5,0,5)}
	grid_manager.grid_data[Vector2(5,6)] = {"type": 0, "is_walkable": true, "world_pos": Vector3(5,0,6)}
	
	# Override is_valid_destination via script logic or mocking?
	# Real GridManager.is_valid_destination checks grid_data.
	# We populated it, so it should be true.
	

	# 3. Unit
	var MockUnitScript = load("res://tests/MockUnitGround.gd")
	if not MockUnitScript:
		printerr("CRITICAL: Failed to load MockUnitGround.gd")
		get_tree().quit(1)
		return
		
	selected_unit = MockUnitScript.new()
	selected_unit.name = "TestUnit"
	add_child(selected_unit)
	
	# 4. PMC
	pmc = load("res://scripts/controllers/PlayerMissionController.gd").new()
	add_child(pmc)
	pmc._signal_bus = get_node("/root/SignalBus")
	pmc.grid_manager = grid_manager
	pmc.main_node = self # We mock Main as self (Node) which has no methods, so fallbacks trigger
	pmc.selected_unit = selected_unit
	pmc.current_input_state = pmc.InputState.ABILITY_TARGETING

func test_ability(name, script, expected_chance):
	print("Testing ", name, "...")
	var ability = script.new()
	if "charges" in ability: ability.charges = 1
	
	pmc.selected_ability = ability
	
	# Reset signal capture
	signal_data = {}
	
	var ground_tile = Vector2(5, 6)
	
	# Call _preview_attack (Verified Unified Logic)
	pmc._preview_attack(ground_tile)
	
	await get_tree().process_frame # Signals are immediate, but safe to wait? No, emit is immediate.
	
	if signal_data.has('chance'):
		if signal_data['chance'] == expected_chance:
			print("PASS: ", name, " showed ", expected_chance, "%")
		else:
			print("FAIL: ", name, " showed ", signal_data['chance'], "% expected ", expected_chance, "%")
			get_tree().quit(1)
	else:
		print("FAIL: ", name, " did NOT show hit chance on ground.")
		get_tree().quit(1)
