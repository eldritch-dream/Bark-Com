extends Node

# Usage: godot -s tests/test_loot_ladder_crash.gd

func _ready():
	print("--- TEST START: Loot Ladder Crash ---")
	add_child(load("res://tests/TestSafeGuard.gd").new())
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
	for x in range(4, 9):
		for y in range(4, 9):
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
		
	print("--- PHASE 2: Ghost Lootbox on Ground ---")
	
	var ground_pos = Vector2(6, 6) # Defined as Ground in setup
	print("Testing Ground Tile: ", ground_pos)
	
	# Spawn Crate
	var crate2 = load("res://scripts/entities/LootCrate.gd").new()
	add_child(crate2)
	crate2.initialize(ground_pos, grid_manager)
	
	print("Spawned Crate 2 on Ground. Simulating Pickup...")
	crate2.interact(unit) # Re-use unit
	await get_tree().process_frame
	await get_tree().process_frame
	print("Crate 2 destroyed? ", not is_instance_valid(crate2) or crate2.is_queued_for_deletion())
	
	# Attempt Move
	print("Attempting move to Ground post-loot...")
	var valid_ground = grid_manager.is_valid_destination(ground_pos)
	print("Move Valid? ", valid_ground)
	
	if not valid_ground:
		print("FAIL: Ground tile became invalid after loot pickup?!")
	else:
		print("PASS: Ground tile remains valid.")
		
	var path_ground = grid_manager.get_move_path(unit.grid_pos, ground_pos)
	if path_ground.is_empty():
		print("FAIL: No path to ground tile?!")
	else:
		print("PASS: Path found to ground tile.")
		# Simulate movement logic
		# We expect this to execute cleanly
		unit.grid_pos = ground_pos
		print("Simulated Move Complete. No Crash.")

	print("--- PHASE 3: Two Dogs Scenario ---")
	# Scenario: Camille picks up loot. Ryan moves to tile.
	
	var tile_c3 = Vector2(7, 7) # Loot Tile
	var tile_camille = Vector2(7, 6)
	var tile_ryan = Vector2(7, 8)
	
	# Setup
	var camille = load("res://scripts/entities/Unit.gd").new()
	camille.name = "Camille"
	add_child(camille)
	camille.initialize(tile_camille)
	
	var ryan = load("res://scripts/entities/Unit.gd").new()
	ryan.name = "Ryan"
	add_child(ryan)
	ryan.initialize(tile_ryan)
	
	var crate3 = load("res://scripts/entities/LootCrate.gd").new()
	add_child(crate3)
	crate3.initialize(tile_c3, grid_manager)
	
	print("Camille picks up loot at ", tile_c3)
	crate3.interact(camille)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("Ryan attempts move to ", tile_c3)
	var valid_ryan = grid_manager.is_valid_destination(tile_c3)
	print("Ryan Move Valid? ", valid_ryan)
	
	if not valid_ryan:
		print("FAIL: Tile became invalid for Ryan?")
	else:
		print("PASS: Tile valid for Ryan.")
		
	var path_ryan = grid_manager.get_move_path(ryan.grid_pos, tile_c3)
	if path_ryan.is_empty():
		print("FAIL: No path for Ryan?")
	else:
		print("PASS: Path found for Ryan.")
		ryan.grid_pos = tile_c3
		print("Ryan moved successfully.")

	print("--- PHASE 4: Exact Repro (Camille Leaves, Ryan Enters) ---")
	var tile_c4 = Vector2(8, 6) # Crate
	var tile_camille_start = Vector2(8, 5)
	var tile_camille_away = Vector2(8, 4)
	var tile_ryan_start = Vector2(8, 8)
	
	# Setup
	var cam4 = load("res://scripts/entities/Unit.gd").new()
	cam4.name = "Camille_4"
	add_child(cam4)
	cam4.initialize(tile_camille_start)
	
	var ryan4 = load("res://scripts/entities/Unit.gd").new()
	ryan4.name = "Ryan_4"
	add_child(ryan4)
	ryan4.initialize(tile_ryan_start)
	
	var crate4 = load("res://scripts/entities/LootCrate.gd").new()
	add_child(crate4)
	crate4.initialize(tile_c4, grid_manager)
	
	print("1. Camille interacts with crate at ", tile_c4)
	crate4.interact(cam4)
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("2. Camille moves away to ", tile_camille_away)
	# Simulate Move Logic: pathfind + update grid_pos + refresh_pathfinding
	var p_away = grid_manager.get_move_path(cam4.grid_pos, tile_camille_away)
	if not p_away.is_empty():
		cam4.grid_pos = tile_camille_away
		# CRITICAL: Simulate Main.gd calling refresh after move
		grid_manager.refresh_pathfinding([cam4, ryan4]) 
	else:
		print("FAIL: Camille stuck?")
		
	print("3. Ryan attempts move to Loot Tile ", tile_c4)
	var valid_ryan4 = grid_manager.is_valid_destination(tile_c4)
	print("Ryan 4 Move Valid? ", valid_ryan4)
	
	if not valid_ryan4:
		print("FAIL: Tile invalid for Ryan 4?")
	
	var p_ryan4 = grid_manager.get_move_path(ryan4.grid_pos, tile_c4)
	if p_ryan4.is_empty():
		print("FAIL: No path for Ryan 4")
	else:
		print("PASS: Path found for Ryan 4")
		ryan4.grid_pos = tile_c4
		print("Ryan 4 moved successfully.")
		
	# CRITICAL: Verify Smart Loot Logic with DIRTY data
	print("4. Simulating DIRTY State (Force Free without Remove)")
	var dirty_tile = Vector2(8, 7) # Unused tile
	
	# Re-spawn a crate just to kill it dirty
	var dirty_crate = load("res://scripts/entities/LootCrate.gd").new()
	add_child(dirty_crate)
	# Register but do NOT use initialize (which sets up proper removal checks potentially) 
	# Or just manually register
	grid_manager.register_item(dirty_tile, dirty_crate)
	print("Dirty Crate Registered at ", dirty_tile)
	
	dirty_crate.free() # Immediate Force Kill
	print("Dirty Crate Freed. Checking GridManager sanitization...")
	
	var items = grid_manager.get_items_at(dirty_tile)
	print("Items found after Pruning: ", items.size())
	
	if items.size() == 0:
		print("PASS: GridManager auto-pruned the freed item.")
	else:
		print("FAIL: GridManager returned freed item!")
		for item in items:
			if not is_instance_valid(item):
				print("   -> Found Invalid Instance!")
			else:
				print("   -> Found Valid Instance: ", item.name)

	print("--- TEST END ---")
	get_tree().quit()
