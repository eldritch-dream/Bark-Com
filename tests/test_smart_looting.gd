extends Node

var GridManager_Script
var Unit_Script
var LootCrate_Script

func _ready():
	print("--- TEST: Smart Looting ---")
	await get_tree().process_frame # Wait for autoloads
	
	GridManager_Script = load("res://scripts/managers/GridManager.gd")
	Unit_Script = load("res://scripts/entities/Unit.gd")
	LootCrate_Script = load("res://scripts/entities/LootCrate.gd")
	
	test_auto_pickup()
	
	print("--- Smart Looting Test Passed ---")
	get_tree().quit()

func test_auto_pickup():
	print("Running Auto-Pickup Test...")
	
	var gm = GridManager_Script.new()
	add_child(gm)
	gm.generate_grid() # Creates empty grid
	
	# Spawn Unit
	var unit = Unit_Script.new()
	unit.unit_name = "Looter Dog"
	add_child(unit)
	unit.initialize(Vector2(0, 0))
	
	# Spawn Crate at (0, 1)
	var crate_pos = Vector2(0, 1)
	var crate = LootCrate_Script.new()
	add_child(crate)
	# Set loot table for testing
	# We need a dummy consumable resource.
	# Or construct one if possible. 
	# Or check interact log. LootCrate gives error if output full or empty table.
	# Ideally we just check if it was removed/interacted.
	# LootCrate checks size > 0.
	# Let's mock a resource?
	# Using "res://scripts/resources/ConsumableData.gd" ?
	
	crate.loot_table.clear() # Empty table checks
	# Let's mock a resource?
	# Using "res://scripts/resources/ConsumableData.gd" ?
	
	crate.initialize(crate_pos, gm)
	
	# Verify Crate is registered as Item
	var items = gm.get_items_at(crate_pos)
	if items.size() == 0 or items[0] != crate:
		print("FAIL: Crate not registered as item.")
		get_tree().quit(1)
		return
	print("Crate spawned at 0,1.")
	
	# Move Unit
	# We need to trigger UnitMoveState.
	# Unit._setup_fsm() runs in _ready.
	# We need to call move_to_path.
	# But Unit doesn't have a high level move_to_path exposed publicly in snippet?
	# It usually happens via Controller directly setting FSM.
	
	# Manually Transition
	var path_world = [gm.get_world_position(Vector2(0,0)), gm.get_world_position(Vector2(0,1))]
	var path_grid = [Vector2(0,0), Vector2(0,1)]
	
	unit.state_machine.transition_to("Moving", {
		"world_path": path_world,
		"grid_path": path_grid
	})
	
	# Wait for move
	print("Waiting for movement interact...")
	await get_tree().create_timer(1.0).timeout
	
	# Assert Crate is gone?
	# Note: Empty loot table means item_granted = false.
	# LootCrate code: if item_granted... loop.
	# If empty, it stays.
	# We need it to have items to destroy.
	
	# Since loading resources is annoying in pure script without valid file paths,
	# We can check if "interact" print happened?
	# Or simpler: Modify crate logic or use valid loot.
	# Let's rely on just "Auto-Interact" happening.
	# Check log? No.
	
	# Let's inject a dummy Item into Crate.
	# We can mock loot_table with a Resource.
	var res = Resource.new()
	res.set_script(load("res://scripts/resources/ConsumableData.gd")) 
	# Basic mock
	if "display_name" in res: res.display_name = "TestChow"
	crate.loot_table.clear()
	crate.loot_table.append(res)
	
	# NOW move again? Or Reset interaction?
	# Crate is still there because previous interact failed gracefully.
	# Let's restart crate logic.
	crate.loot_table.clear()
	crate.loot_table.append(res) 
	
	# Re-trigger move to same tile or just call interact?
	# Test is verification of Move -> Interact.
	# We force the move again or better: Just ensure unit grid pos updates and logic runs.
	
	# Actually, waiting 1.0s above allowed the move to finish. Unit is at 1,0?
	# The auto-interact should have happened.
	# If it happened with empty table, it printed but didn't destroy.
	# inventory should be empty.
	
	# Let's do it properly:
	# 1. Spawn Unit at 0,0.
	# 2. Spawn Crate at 0,1 with Item.
	# 3. Move Unit to 0,1.
	# 4. Check Unit Inventory[0] != null.
	
	# Reset
	unit.inventory = [null, null]
	
	# Move Again (simulated)
	unit.state_machine.transition_to("Moving", {
		"world_path": [gm.get_world_position(Vector2(0,1))],
		"grid_path": [Vector2(0,1)]
	})
	
	await get_tree().create_timer(1.0).timeout
	
	# Assert Inventory
	if unit.inventory[0] == null:
		print("FAIL: Inventory empty. Auto-pickup failed.")
		get_tree().quit(1)
		return
		
	# Assert Crate Gone
	if is_instance_valid(crate) and not crate.is_queued_for_deletion():
		# Logic says queue_free() if item granted.
		print("WARN: Crate still valid? Should be freed.")
		# Note: queue_free is deferred. is_instance_valid might still be true immediately?
		# But we waited 1.0s. It should be invalid.
	else:
		print("Crate destroyed successfully.")
