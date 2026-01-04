extends Node
class_name GridManager

# Signals
signal grid_generated

# Grid Constants
const GRID_SIZE = Vector2(20, 20)
const TILE_SIZE = 2.0  # World units (3D)
const HEIGHT_STEP = 1.0  # Vertical Units (Y) per elevation layer

# Data Structures
# grid_data keys are Vector2 coordinates (x, y)
# Values are Dictionaries: { "type": int, "is_walkable": bool, "height": float, "world_pos": Vector3 }
var grid_data = {}

enum TileType { GROUND, OBSTACLE, COVER_HALF, COVER_FULL, RAMP, LADDER }

var astar: AStar3D


func _ready():
	# For testing, we can generate on ready.
	# In a real game, a customized GameController would call this.
	generate_grid()


func generate_grid():
	grid_data.clear()

	# Use LevelGenerator
	var generator = load("res://scripts/core/LevelGenerator.gd").new()
	grid_data = generator.generate_level()

	print("Grid generated with ", grid_data.size(), " tiles.")
	_setup_astar()
	emit_signal("grid_generated")


func _get_point_id(coord: Vector2) -> int:
	return int(coord.y) * 100 + int(coord.x)


func _setup_astar():
	astar = AStar3D.new()

	# 1. Add All Points
	for coord in grid_data:
		var data = grid_data[coord]
		var is_walkable = data.get("is_walkable", false)
		if is_walkable:
			var id = _get_point_id(coord)
			astar.add_point(id, get_world_position(coord))

	# 2. Connect Neighbors
	for coord in grid_data:
		var id = _get_point_id(coord)
		if not astar.has_point(id):
			continue

		var current_elev = grid_data[coord].get("elevation", 0)
		var current_type = grid_data[coord].get("type", TileType.GROUND)

		# Directions (Including Diagonals)
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
			var n_coord = coord + n
			var n_id = _get_point_id(n_coord)

			if astar.has_point(n_id):
				# Check Verticality
				var next_elev = grid_data[n_coord].get("elevation", 0)
				var next_type = grid_data[n_coord].get("type", TileType.GROUND)

				var diff = abs(next_elev - current_elev)

				var can_connect = false
				if diff == 0:
					can_connect = true
				elif diff == 1:
					# Allow if one of them is a Ramp/Ladder
					if current_type == TileType.RAMP or next_type == TileType.RAMP:
						can_connect = true
					elif current_type == TileType.LADDER or next_type == TileType.LADDER:
						can_connect = true

				if can_connect:
					astar.connect_points(id, n_id)

	# 3. Apply Traverse Weights (Ladders are slow)
	for coord in grid_data:
		var type = grid_data[coord].get("type", TileType.GROUND)
		var id = _get_point_id(coord)
		if astar.has_point(id):
			if type == TileType.LADDER:
				astar.set_point_weight_scale(id, 2.0)
			else:
				astar.set_point_weight_scale(id, 1.0)  # Default


func get_move_path(start: Vector2, end: Vector2) -> Array[Vector2]:
	var start_id = _get_point_id(start)
	var end_id = _get_point_id(end)

	if not astar.has_point(start_id) or not astar.has_point(end_id):
		return []

	var path_3d = astar.get_point_path(start_id, end_id)
	var path_2d: Array[Vector2] = []

	for p in path_3d:
		path_2d.append(get_grid_coord(p))

	return path_2d


func calculate_path_cost(path: Array[Vector2]) -> float:
	var total_cost = 0.0
	if path.size() < 2:
		return 0.0

	for i in range(1, path.size()):
		var prev = path[i - 1]
		var curr = path[i]

		# Base Distance cost (usually 1.0 or 1.414)
		var dist = prev.distance_to(curr)

		# Weight Multiplier
		var weight = 1.0
		var type = grid_data[curr].get("type", TileType.GROUND)
		if type == TileType.LADDER:
			weight = 2.0

		total_cost += dist * weight

	return total_cost


func is_valid_destination(coord: Vector2) -> bool:
	if not grid_data.has(coord):
		return false

	# Cannot end turn on a Ladder
	if grid_data[coord].get("type") == TileType.LADDER:
		return false

	# Must be walkable and not blocked by static obstacle
	return grid_data[coord].get("is_walkable", false)


func get_tile_data(coord: Vector2) -> Dictionary:
	return grid_data.get(coord, {})


func is_walkable(coord: Vector2) -> bool:
	var data = get_tile_data(coord)
	return data.get("is_walkable", false)


func is_tile_blocked(coord: Vector2) -> bool:
	# Checks dynamic AStar state (including units)
	if not astar:
		return true
	var id = _get_point_id(coord)
	if not astar.has_point(id):
		return true
	return astar.is_point_disabled(id)


const TILE_THICKNESS = 0.2
const RAMP_SURFACE_OFFSET = 0.5


func get_world_position(coord: Vector2) -> Vector3:
	var elev = 0
	if grid_data.has(coord):
		elev = grid_data[coord].get("elevation", 0)

	var pos = Vector3(coord.x * TILE_SIZE, elev * HEIGHT_STEP, coord.y * TILE_SIZE)

	if grid_data.has(coord):
		if grid_data[coord].has("world_pos"):
			pos = grid_data[coord]["world_pos"]

		var type = grid_data[coord].get("type", TileType.GROUND)

		# Define Surface Height based on Configured Thickness
		# Visual Meshes are instantiated CENTERED at 'pos'.
		# Surface is Top Face.
		if type == TileType.RAMP:
			pos.y += RAMP_SURFACE_OFFSET
		else:
			# Standard Tile
			pos.y += TILE_THICKNESS / 2.0

	return pos


func get_grid_coord(world_pos: Vector3) -> Vector2:
	var x = round(world_pos.x / TILE_SIZE)
	var y = round(world_pos.z / TILE_SIZE)
	return Vector2(x, y)


func get_nearest_walkable_tile(target: Vector2) -> Vector2:
	if is_walkable(target):
		return target

	# Spiral / BFS search for nearest
	var queue = [target]
	var visited = {target: true}

	while not queue.is_empty():
		var current = queue.pop_front()
		if is_walkable(current):
			return current

		var neighbors = [
			Vector2(0, 1),
			Vector2(0, -1),
			Vector2(1, 0),
			Vector2(-1, 0),
			Vector2(1, 1),
			Vector2(1, -1),
			Vector2(-1, 1),
			Vector2(-1, -1)
		]

		for n in neighbors:
			var next = current + n
			if not visited.has(next) and grid_data.has(next):
				visited[next] = true
				queue.append(next)

	return Vector2.ZERO  # Fallback (shouldn't happen on valid map)


func update_tile_state(
	coord: Vector2, walkable: bool, cover_height: float = 0.0, type: int = TileType.GROUND
):
	if not grid_data.has(coord):
		return

	var data = grid_data[coord]
	data["is_walkable"] = walkable
	data["cover_height"] = cover_height
	data["type"] = type

	# Update AStar
	if astar:
		var id = _get_point_id(coord)
		if astar.has_point(id):
			astar.set_point_disabled(id, not walkable)

	# Update Visuals?
	# GridVisualizer usually generates once.
	# We might want to signal this change if we want real-time visual updates of cell colors.
	# For now, gameplay logic is the priority.
	print(
		"GridManager: Updated tile ", coord, " -> Walkable: ", walkable, ", Cover: ", cover_height
	)


func refresh_pathfinding(units: Array, ignore_unit = null):
	# 1. Reset to Base Static State
	for coord in grid_data:
		var d = grid_data[coord]
		var walkable = d.get("is_walkable", false)
		var id = _get_point_id(coord)
		if astar.has_point(id):
			astar.set_point_disabled(id, not walkable)

	# 2. Mark Units as Obstacles
	for u in units:
		if is_instance_valid(u) and u.current_hp > 0 and u != ignore_unit:
			# Ensure we don't block the ignore_unit (active mover)
			var u_id = _get_point_id(u.grid_pos)
			if astar.has_point(u_id):
				astar.set_point_disabled(u_id, true)


func get_random_valid_position() -> Vector2:
	var keys = grid_data.keys()
	keys.shuffle()

	for coord in keys:
		var d = grid_data[coord]
		if d.get("is_walkable", false):
			# Added check against dynamic obstacles (units/crates)
			if not is_tile_blocked(coord) and not d.get("unit"):
				return coord

	return Vector2(-1, -1)


func get_reachable_tiles(start_pos: Vector2, max_move: int) -> Array[Vector2]:
	var reachable: Array[Vector2] = []
	var queue = [{"pos": start_pos, "cost": 0}]
	var visited = {start_pos: 0}  # Pos -> Cost
	
	reachable.append(start_pos)

	while not queue.is_empty():
		var current = queue.pop_front()
		
		# Get neighbors via AStar logic (connected points)
		var c_id = _get_point_id(current.pos)
		if not astar.has_point(c_id):
			continue
			
		var connections = astar.get_point_connections(c_id)
		for n_id in connections:
			var n_pos = get_grid_coord(astar.get_point_position(n_id))
			
			# Calculate Cost to neighbor
			var move_cost = 1
			if grid_data[n_pos].get("type") == TileType.LADDER:
				move_cost = 2
				
			var new_cost = current.cost + move_cost
			
			if new_cost <= max_move:
				# If better path or unvisited
				if not visited.has(n_pos) or new_cost < visited[n_pos]:
					visited[n_pos] = new_cost
					queue.append({"pos": n_pos, "cost": new_cost})
					if not reachable.has(n_pos):
						reachable.append(n_pos)
						
	return reachable
