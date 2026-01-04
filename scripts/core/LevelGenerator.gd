extends Node
class_name LevelGenerator

# Constants
const CHUNK_SIZE = 5

# Tile Codes for Template
# . = Ground
# # = Wall (Obstacle)
# H = High Cover (e.g. Sofa, Hydrant)
# L = Low Cover (e.g. Flower Bed, Low Wall)

const CHUNK_KITCHEN = ["##.##", "#...#", ".H.H.", ".....", "##.##"]

const CHUNK_GARDEN = ["L...L", ".....", "..L..", ".....", "L...L"]

const CHUNK_STREET = [".....", ".H.H.", ".....", ".H.H.", "....."]

const CHUNK_HILL = [".^^^.", "^+++^", "^+++^", "^+++^", ".^^^."]

const CHUNK_TRENCH = ["+++++", "^...^", "^.L.^", "^...^", "+++++"]

const CHUNK_NEST = ["####.", "#+++^", "#+.+^", "#+L+^", ".^^^."]

const CHUNK_BRIDGE = [".^.^.", ".+.+.", ".+.+.", ".+.+.", ".^.^."]

const CHUNK_LADDER_TEST = [".....", ".H+++", ".=H+.", ".H+++", "....."]  # Single Ladder at (1,2)

const CHUNK_SPLIT_LEVEL = ["+++++", "+...=", "+.L.=", "+...=", "....."]

const CHUNK_PARK = [".....", ".L.L.", ".....", ".L.L.", "....."]

const CHUNK_ALLEY = ["#####", "#...#", "L...L", "#...#", "#####"]

const CHUNK_ROOFTOP = [".....", ".=+++", ".=+++", ".=+++", "....."]

const CHUNK_PILLBOX = [".###.", "#+++#", "#+++#", "#=+=#", "....."]

const CHUNK_LABYRINTH = ["##.##", ".....", ".###.", ".....", "##.##"]

# Map Biome Types to Colors in Visualizer later?
enum Biome { INDOORS, GARDEN, STREET }


func generate_level() -> Dictionary:
	var final_grid = {}
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# Layout: 2x2 Chunks for 10x10 map
	var attempts = 0
	var max_attempts = 10
	var valid_map = false

	while attempts < max_attempts and not valid_map:
		final_grid.clear()
		attempts += 1

		# Generate 4x4 Chunks
		for cx in range(4):
			for cy in range(4):
				var type_roll = rng.randi() % 14
				var template = []
				var biome = Biome.GARDEN

				match type_roll:
					0:
						template = CHUNK_KITCHEN
						biome = Biome.INDOORS
					1:
						template = CHUNK_GARDEN
						biome = Biome.GARDEN
					2:
						template = CHUNK_STREET
						biome = Biome.STREET
					3:
						template = CHUNK_HILL
						biome = Biome.STREET
					4:
						template = CHUNK_TRENCH
						biome = Biome.STREET
					5:
						template = CHUNK_NEST
						biome = Biome.STREET
					6:
						template = CHUNK_BRIDGE
						biome = Biome.STREET
					7:
						template = CHUNK_LADDER_TEST
						biome = Biome.STREET
					8:
						template = CHUNK_SPLIT_LEVEL
						biome = Biome.STREET
					9:
						template = CHUNK_PARK
						biome = Biome.GARDEN
					10:
						template = CHUNK_ALLEY
						biome = Biome.STREET
					11:
						template = CHUNK_ROOFTOP
						biome = Biome.STREET
					12:
						template = CHUNK_PILLBOX
						biome = Biome.STREET
					13:
						template = CHUNK_LABYRINTH
						biome = Biome.STREET

				# Rotation
				var rots = rng.randi() % 4
				template = _rotate_template(template, rots)

				_stitch_chunk(final_grid, template, cx * CHUNK_SIZE, cy * CHUNK_SIZE, biome)

		# Validation
		if _validate_connectivity(final_grid):
			valid_map = true
			print("LevelGenerator: Map Validated on attempt ", attempts)
		else:
			print("LevelGenerator: Map Rejected on attempt ", attempts, ". Retrying...")

	if not valid_map:
		print("LevelGenerator: CRITICAL FAIL. Generating Emergency Safe Map.")
		_generate_safe_map(final_grid)

	return final_grid


func _validate_connectivity(grid: Dictionary) -> bool:
	# Flood Fill from assumed Player Start
	# Main.gd spawns at (1, 1)
	var start = Vector2(1, 1)

	# Try explicit start + immediate neighbors (spawn region)
	if not grid.has(start) or not grid[start].get("is_walkable"):
		var potential = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(2, 1), Vector2(1, 2)]
		for p in potential:
			if grid.has(p) and grid[p].get("is_walkable"):
				start = p
				break

	# If the spawn region is completely unwalkable, this map is bad for spawning.
	# We should NOT fallback to random keys, because then we might validate an island the player isn't on.
	if not grid.has(start) or not grid[start].get("is_walkable"):
		return false  # Spawn area is blocked

	if not grid.has(start) or not grid[start].get("is_walkable"):
		return false  # No walkable tiles?

	var total_walkable = 0
	for k in grid:
		if grid[k].get("is_walkable"):
			total_walkable += 1

	var reachable = 0
	var queue = [start]
	var visited = {start: true}

	while not queue.is_empty():
		var current = queue.pop_front()
		reachable += 1

		# Logic mimics GridManager connection logic implicitly or explicitly
		# We need to respect standard movement rules (Neighbors + Ramps + Ladders)
		# Since we don't have GridManager instance here, we must replicate checks or be permissive.
		# Simplest is checking GridManager compatibility logic:
		var current_elev = grid[current].get("elevation", 0)
		var current_type = grid[current].get("type", 0)  # 0=Ground

		var neighbors = [
			Vector2(1, 0),
			Vector2(-1, 0),
			Vector2(0, 1),
			Vector2(0, -1),
			Vector2(1, 1),
			Vector2(1, -1),
			Vector2(-1, 1),
			Vector2(-1, -1)
		]

		for n in neighbors:
			var next_pos = current + n
			if not grid.has(next_pos):
				continue
			if visited.has(next_pos):
				continue

			var next_data = grid[next_pos]
			if not next_data.get("is_walkable"):
				continue

			# Height Check (Replicating GM logic)
			var next_elev = next_data.get("elevation", 0)
			var next_type = next_data.get("type", 0)
			var diff = abs(next_elev - current_elev)

			var valid_move = false
			if diff == 0:
				valid_move = true
			elif diff == 1:
				if current_type == 4 or next_type == 4:  # RAMP
					valid_move = true
				elif current_type == 5 or next_type == 5:  # LADDER
					valid_move = true

			if valid_move:
				visited[next_pos] = true
				queue.append(next_pos)

	var ratio = float(reachable) / float(total_walkable)
	# print("Flood Fill: ", reachable, "/", total_walkable, " (", ratio, ")")
	return ratio >= 0.9


func _generate_safe_map(grid: Dictionary):
	grid.clear()
	# Just flat ground
	for x in range(20):
		for y in range(20):
			var pos = Vector2(x, y)
			grid[pos] = {
				"type": 0,  # GROUND
				"is_walkable": true,
				"cover_height": 0.0,
				"elevation": 0,
				"biome": 1,
				"world_pos": Vector3(x * 2.0, 0, y * 2.0)
			}


func _rotate_template(original: Array, times: int) -> Array:
	if times == 0:
		return original

	var current = original.duplicate()
	# Rotate 90 degrees clockwise 'times' times
	for t in range(times):
		var rotated = []
		for i in range(CHUNK_SIZE):
			var row_str = ""
			for j in range(CHUNK_SIZE):
				# Matrix Rotation:
				# Rotated[row][col] = Original[size-1-col][row]
				# Wait, i is ROW index for destination?
				# Let's verify standard algorithm:
				# dest[i][j] = src[N-1-j][i]

				var src_r = CHUNK_SIZE - 1 - j
				var src_c = i
				row_str += current[src_r][src_c]
			rotated.append(row_str)
		current = rotated
	return current


func _stitch_chunk(
	grid_data: Dictionary, template: Array, offset_x: int, offset_y: int, biome: int
):
	for y in range(CHUNK_SIZE):
		var row = template[y]
		for x in range(CHUNK_SIZE):
			var char_code = row[x]
			var global_coord = Vector2(offset_x + x, offset_y + y)

			var type = GridManager.TileType.GROUND
			var is_walkable = true
			var cover_height = 0.0

			match char_code:
				"#":
					type = GridManager.TileType.OBSTACLE
					is_walkable = false
					cover_height = 2.0
				"H":
					type = GridManager.TileType.COVER_FULL
					is_walkable = false
					cover_height = 2.0
				"L":
					type = GridManager.TileType.COVER_HALF
					is_walkable = true
					cover_height = 1.0
				".":
					pass  # Default Ground
				"+":
					# High Ground
					grid_data[global_coord] = {
						"type": GridManager.TileType.GROUND,
						"is_walkable": true,
						"cover_height": 0.0,
						"elevation": 1,
						"biome": biome,
						"world_pos": Vector3(global_coord.x * 2.0, 1.0, global_coord.y * 2.0)
					}
					continue
				"^":
					# Ramp (Base 0 -> 1)
					grid_data[global_coord] = {
						"type": GridManager.TileType.RAMP,
						"is_walkable": true,
						"cover_height": 0.0,
						"elevation": 0,  # Base of ramp
						"biome": biome,
						"world_pos": Vector3(global_coord.x * 2.0, 0.5, global_coord.y * 2.0)  # Midpoint visual?
					}
					continue
				"=":
					# Ladder (Vertical Access)
					# Elevation 0, connects to Elevation 1 via GridManager logic
					grid_data[global_coord] = {
						"type": GridManager.TileType.LADDER,
						"is_walkable": true,  # Walkable BUT restricted ending (handled in Main/GM)
						"cover_height": 0.0,
						"elevation": 0,
						"biome": biome,
						"world_pos": Vector3(global_coord.x * 2.0, 0.0, global_coord.y * 2.0)
					}
					continue

			grid_data[global_coord] = {
				"type": type,
				"is_walkable": is_walkable,
				"cover_height": cover_height,
				"biome": biome,  # Store biome for coloring
				"world_pos": Vector3(global_coord.x * 2.0, 0, global_coord.y * 2.0)
			}
