extends Node

var root
var main_node
var grid_manager
var pmc
var signal_bus
var selected_unit
var terminal
var signal_data = {}

func _ready():
	print("--- TEST START: Feature Helpers (Grenade/Hack) ---")
	root = self
	
	# Anti-Ghosting Safeguard
	root.add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# 1. Setup SignalBus
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
	
	# Capture signals
	signal_bus.on_show_hit_chance.connect(func(c, d, p): signal_data = {'chance': c, 'details': d})
	signal_bus.on_hide_hit_chance.connect(func(): signal_data = {})
	
	# 2. Main
	main_node = Node.new()
	main_node.name = "MockMain"
	root.add_child(main_node)
	
	grid_manager = load("res://scripts/managers/GridManager.gd").new()
	main_node.add_child(grid_manager)
	# Populate grid for range checks
	for x in range(3, 8):
		for y in range(3, 8):
			grid_manager.grid_data[Vector2(x, y)] = {"world_pos": Vector3(x, 0, y), "type": 0, "is_walkable": true}
	
	# 3. Unit
	var u_script = GDScript.new()
	u_script.source_code = """
extends Node
var grid_pos = Vector2(5, 5)
var current_ap = 2
var faction = 'Player'
var mobility = 5
var visible = true
var stats = {'accuracy': 80}
var tech_score = 10
"""
	u_script.reload()
	selected_unit = u_script.new()
	selected_unit.name = "Grenadier"
	main_node.add_child(selected_unit)
	
	# 4. Terminal
	terminal = Node.new()
	terminal.name = "Terminal"
	var t_script = GDScript.new()
	t_script.source_code = """
extends Node
var grid_pos = Vector2(6, 5)
var is_hacked = false
var visible = true # Needed for visibility checks
"""
	t_script.reload()
	terminal.set_script(t_script)
	terminal.add_to_group("Terminals")
	main_node.add_child(terminal)
	
	# 5. PMC
	pmc = load("res://scripts/controllers/PlayerMissionController.gd").new()
	main_node.add_child(pmc)
	pmc._signal_bus = signal_bus
	pmc.grid_manager = grid_manager
	pmc.main_node = main_node
	pmc.selected_unit = selected_unit
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	_run_tests()
	get_tree().quit()

func _run_tests():
	# Test A: Grenade Helper (Ground Target)
	print("Test A: Grenade Helper (Ground Target)...")
	# Update: Use generic GrenadeToss script if possible, or mock
	var grenade_script = load("res://scripts/abilities/GrenadeToss.gd")
	var grenade_ability = grenade_script.new()
	grenade_ability.charges = 1 # Ensure valid
	
	pmc.selected_ability = grenade_ability
	pmc.current_input_state = pmc.InputState.ABILITY_TARGETING 
	
	# Hover empty tile (5, 6) next to unit
	signal_data = {}
	pmc._preview_attack(Vector2(5, 6))
	
	if signal_data.has('chance'):
		print("PASS: Grenade UI showed for empty tile. Chance: ", signal_data['chance'])
	else:
		print("FAIL: Grenade UI did not show for empty tile.")

	# Test B: Hack Helper (Terminal Target)
	print("Test B: Hack Helper (Terminal Target)...")
	var hack_script = load("res://scripts/abilities/HackAbility.gd")
	var hack_ability = hack_script.new()
	
	pmc.selected_ability = hack_ability
	pmc.current_input_state = pmc.InputState.ABILITY_TARGETING
	
	# Hover terminal tile (6, 5)
	signal_data = {}
	pmc._preview_attack(Vector2(6, 5))
	
	if signal_data.has('chance'):
		print("PASS: Hack UI showed for Terminal.")
	else:
		print("FAIL: Hack UI did not show for Terminal.")
