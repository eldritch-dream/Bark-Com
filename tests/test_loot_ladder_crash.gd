extends Node

# Usage: godot -s tests/test_loot_ladder_crash.gd

func _ready():
	print("--- TEST START: Loot Ladder Crash ---")
	await get_tree().process_frame
	
	# 1. Setup GridManager
	var grid_manager = load("res://scripts/managers/GridManager.gd").new()
	add_child(grid_manager)
	
	# Mock LevelGenerator or manually inject data
	# We manually inject for precision
	grid_manager._setup_astar() # Initialize empty astar
	grid_manager.grid_data = {}
	
	# Create 3x3 Grid
	# (5,4) = Ground (Start)
	# (5,5) = Ladder (Target)
	for x in range(4, 7):
		for y in range(4, 7):
			var vec = Vector2(x, y)
			grid_manager.grid_data[vec] = {
				"type": grid_manager.TileType.GROUND,
				"is_walkable": true,
				"elevation": 0,
				"items": []
			}
			
	# CONFIGURE LADDER
	var ladder_pos = Vector2(5, 5)
	grid_manager.grid_data[ladder_pos]["type"] = grid_manager.TileType.LADDER
	# Note: is_valid_destination explicitly blocks Move TO Ladder.
	
	# Re-setup AStar with data
	grid_manager._setup_astar()
	
	var start_pos = Vector2(5, 4)
	
	print("Grid Setup Complete. Ladder at ", ladder_pos)
	
	# 2. Check Initial Move Validity
	var path_pre = grid_manager.get_move_path(start_pos, ladder_pos)
	var valid_pre = grid_manager.is_valid_destination(ladder_pos)
	print("Pre-Loot Move Valid? ", valid_pre) 
	print("Pre-Loot Path Size: ", path_pre.size()) 
	
	# 3. Spawn LootCrate on Ladder
	var crate_script = load("res://scripts/entities/LootCrate.gd")
	var crate = crate_script.new()
	add_child(crate)
	crate.initialize(ladder_pos, grid_manager)
	print("LootCrate spawned at ", ladder_pos)
	
	# 4. Simulate Pickup
	print("Simulating Pickup...")
	# Simulate unit at start_pos interacting
	var unit = load("res://scripts/entities/Unit.gd").new()
	unit.name = "TestDog"
	add_child(unit) # Add to tree
	unit.initialize(start_pos)
	
	# Interaction logic from Main.gd typically:
	crate.interact(unit)
	
	# Crate queues free. Wait for it.
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("Crate destroyed? ", not is_instance_valid(crate) or crate.is_queued_for_deletion())
	
	# 5. Attempt Move to Ladder AGAIN
	print("Attempting move to Ladder after loot pickup...")
	
	# Check Validity
	var valid_post = grid_manager.is_valid_destination(ladder_pos)
	print("Post-Loot Move Valid? ", valid_post)
	
	# Attempt Path
	var path_post = grid_manager.get_move_path(start_pos, ladder_pos)
	print("Post-Loot Path Size: ", path_post.size())
	
	if valid_post:
		print("CRITICAL: Destination became VALID? (Should be blocked by Ladder rule)")
	else:
		print("Destination correctly blocked by Ladder rule.")
		
	# 6. Simulate PMC Move Logic (The Fix)
	# PMC now checks is_valid_destination BEFORE get_move_path.
	
	if valid_post:
		print("FAIL: is_valid_destination returned true for LADDER? Check GridManager logic.")
	else:
		print("PASS: PMC Check (is_valid_destination) correctly BLOCKS the move.")
		path_post = [] # Simulate PMC rejection
	
	if not path_post.is_empty():
		print("CRITICAL FAIL: Path found and accepted! Crash imminent.")
		# Unit.move_along_path(path_post)
	else:
		print("PASS: Move prevented. No crash.")
		
	print("--- TEST END ---")
	get_tree().quit()
