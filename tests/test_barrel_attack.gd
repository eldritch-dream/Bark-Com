extends Node

var root
var main_node
var grid_manager
var pmc
var signal_bus
var selected_unit
var barrel

func _ready():
	print("--- TEST START: Barrel Attack Crash Fix ---")
	root = self
	
	# Anti-Ghosting Safeguard
	root.add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# 1. Setup SignalBus Mock
	var sb_script = GDScript.new()
	sb_script.source_code = """
extends Node
signal on_combat_log_event(msg, color)
signal on_show_hit_chance(chance, details, pos)
signal on_hide_hit_chance
signal on_ui_select_unit(unit)
"""
	sb_script.reload()
	signal_bus = sb_script.new()
	root.add_child(signal_bus)
	
	# 2. Setup Main Mock
	main_node = Node.new()
	main_node.name = "MockMain"
	var m_script = GDScript.new()
	m_script.source_code = """
extends Node
var grid_manager
var execute_called = false
var last_target = null

func _execute_ability(ability, user, target, grid_pos):
	print('MockMain: _execute_ability called.')
	print('Target received: ', target)
	last_target = target
	execute_called = true

func _process_move_or_interact(pos):
	pass
"""
	m_script.reload()
	main_node.set_script(m_script)
	root.add_child(main_node)
	
	# 3. GridManager
	grid_manager = load("res://scripts/managers/GridManager.gd").new()
	main_node.add_child(grid_manager)
	main_node.grid_manager = grid_manager
	
	# 4. Units & Destructibles
	selected_unit = Node.new()
	selected_unit.name = "Hero"
	var u_script = GDScript.new()
	u_script.source_code = """
extends Node
var grid_pos = Vector2(0,0)
var current_ap = 0
var faction = 'Neutral'
var mobility = 0
var visible = true
var stats = {}
var primary_weapon = {}
"""
	u_script.reload()
	selected_unit.set_script(u_script)
	
	selected_unit.grid_pos = Vector2(5, 4)
	selected_unit.current_ap = 2
	selected_unit.faction = "Player"
	selected_unit.mobility = 10
	selected_unit.visible = true
	selected_unit.stats = {"accuracy": 100, "grit": 0}
	selected_unit.primary_weapon = {"range": 5}
	selected_unit.add_to_group("Units")
	main_node.add_child(selected_unit)
	
	barrel = Node.new()
	barrel.name = "ExplosiveBarrel"
	var b_script = GDScript.new()
	b_script.source_code = """
extends Node
var grid_pos = Vector2(0,0)
var faction = 'Neutral'
var visible = true
var position = Vector3(5, 0, 5)
var stats = {'defense': 0, 'evasion': 0}
func take_damage(amt): 
	print('Barrel took damage:', amt)
"""
	b_script.reload()
	barrel.set_script(b_script)
	
	barrel.grid_pos = Vector2(5, 5)
	barrel.faction = "Neutral"
	barrel.visible = true
	barrel.position = Vector3(5, 0, 5)
	barrel.stats = {"defense": 0, "evasion": 0} 
	barrel.add_to_group("Destructible")
	barrel.set("visible", true)
	
	main_node.add_child(barrel)
	
	# 5. PMC
	pmc = load("res://scripts/controllers/PlayerMissionController.gd").new()
	main_node.add_child(pmc)
	pmc._signal_bus = signal_bus
	pmc.grid_manager = grid_manager
	pmc.main_node = main_node
	pmc.selected_unit = selected_unit
	
	# Wait for groups to update
	await get_tree().process_frame
	await get_tree().process_frame
	
	# RUN TESTS
	_run_tests()
	
	print("--- TEST END ---")
	get_tree().quit()

func _run_tests():
	print("Test 1: Destructible Lookup...")
	var found = pmc._find_destructible_at(Vector2(5, 5))
	if found == barrel:
		print("PASS: Found barrel at (5,5)")
	else:
		print("FAIL: Did not find barrel. Found: ", found)

	print("Test 2: Preview Attack (Hover UI)...")
	# Connect listener
	root.set_meta("signal_emitted", false)
	var lambda = func(c, d, p): 
		root.set_meta("signal_emitted", true)
		print("Signal Received: Hit Chance Show")
	
	signal_bus.on_show_hit_chance.connect(lambda)
	
	# Mock Ability
	var mock_ab_script = GDScript.new()
	# StandardAttack usually expects Reference
	mock_ab_script.source_code = """
extends "res://scripts/abilities/StandardAttack.gd"
func get_valid_tiles(gm, user) -> Array[Vector2]: return [Vector2(5,5)]
func get_hit_chance_breakdown(gm, user, target): return {'hit_chance': 100, 'breakdown': 'Mock'}
"""
	mock_ab_script.reload()
	var mock_ability = mock_ab_script.new()
	
	pmc.default_attack = mock_ability
	pmc.selected_ability = null 
	pmc.current_input_state = pmc.InputState.TARGETING
	
	pmc._preview_attack(Vector2(5, 5))
	
	if root.get_meta("signal_emitted", false):
		print("PASS: UI Signal Emitted for Barrel.")
	else:
		print("FAIL: No UI Signal for Barrel.")

	print("Test 3: Ability Click (Crash Reproducer)...")
	# Need to ensure get_valid_tiles passes for click
	pmc._handle_ability_click(Vector2(5, 5))
	
	if main_node.execute_called:
		if main_node.last_target == barrel:
			print("PASS: Main._execute_ability called with BARREL target.")
		else:
			print("FAIL: Target was ", main_node.last_target)
	else:
		print("FAIL: Main._execute_ability NOT called.")
