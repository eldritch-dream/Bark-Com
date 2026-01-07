extends Node3D

@export var grid_manager: GridManager

var tile_meshes = {}  # coord: Vector2 -> MeshInstance3D


func _ready():
	if not grid_manager:
		# Try to find it if not assigned
		grid_manager = get_node("../GridManager")

	if grid_manager:
		grid_manager.grid_generated.connect(_on_grid_generated)
	else:
		push_error("GridVisualizer: GridManager not found!")


# Enum matching LevelGenerator
enum Biome { INDOORS, GARDEN, STREET }


func _on_grid_generated():
	clear_visuals()
	visualize_grid()


func clear_visuals():
	for child in get_children():
		child.queue_free()
	tile_meshes.clear()


func clear_highlights():
	# Implies clearing selection/targeting overlays
	clear_debug_scores()
	if has_node("DebugLines"):
		get_node("DebugLines").queue_free()
	
	# Use free() instead of queue_free() to ensure immediate removal
	# preventing stacking names like Highlights2, Highlights3 if called rapidly
	var existing = get_node_or_null("Highlights")
	if existing:
		existing.free()
	# Check for duplicates just in case (e.g. Highlights2)
	for child in get_children():
		if child.name.begins_with("Highlights"):
			child.queue_free()


func show_highlights(tiles: Array, color: Color):
	clear_highlights() # Clear previous
	
	var container = Node3D.new()
	container.name = "Highlights"
	add_child(container)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.2 # More transparent per user request
	
	var mesh = BoxMesh.new()

	mesh.size = Vector3(1.6, 0.1, 1.6)
	
	for tile_entry in tiles:
		var world_pos = Vector3.ZERO
		
		if tile_entry is Vector2:
			# It's a grid coordinate
			if grid_manager:
				world_pos = grid_manager.get_world_position(tile_entry)
			else:
				continue
		elif tile_entry is Dictionary and tile_entry.has("world_pos"):
			# It's raw tile data
			world_pos = tile_entry["world_pos"]
		else:
			continue
		
		var mi = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = world_pos + Vector3(0, 0.6, 0) # Slightly above tile
		container.add_child(mi)


func visualize_grid():
	var data = grid_manager.grid_data

	for coord in data:
		var tile = data[coord]
		var pos = tile["world_pos"]
		var type = tile["type"]

		var mesh_instance = MeshInstance3D.new()
		var material = StandardMaterial3D.new()

		# DEFAULT SETTINGS
		var use_default_mesh = true
		var box_mesh = BoxMesh.new()
		# Use Shared Constant
		var thickness = GridManager.TILE_THICKNESS
		if grid_manager:
			thickness = grid_manager.TILE_THICKNESS

		box_mesh.size = Vector3(1.8, thickness, 1.8)

		# Color logic
		if tile["is_walkable"]:
			# Biome Coloring
			var biome = tile.get("biome", 1)  # Default Garden
			match biome:
				Biome.INDOORS:
					material.albedo_color = Color(0.8, 0.75, 0.7)  # Beige
				Biome.GARDEN:
					material.albedo_color = Color(0.2, 0.6, 0.2)  # Green
				Biome.STREET:
					material.albedo_color = Color(0.3, 0.3, 0.3)  # Dark Gray
				_:
					material.albedo_color = Color.GREEN

			# High Ground Tint
			if tile.get("elevation", 0) > 0:
				material.albedo_color = material.albedo_color.lightened(0.3)

			# SPECIAL TYPES
			if type == GridManager.TileType.RAMP:
				use_default_mesh = false
				var ramp_mesh = PrismMesh.new()
				ramp_mesh.left_to_right = 1.0  # Wedge shape
				ramp_mesh.size = Vector3(1.8, 1.0, 2.0)  # Height 1.0 to span gap
				mesh_instance.mesh = ramp_mesh
				material.albedo_color = Color(0.6, 0.5, 0.3)  # Wood

				# Auto-Orient Ramp
				# Find High Ground Neighbor (Must be HIGHER elevation and NOT a ramp itself)
				var neighbors = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
				for n in neighbors:
					var target = coord + n
					if data.has(target):
						var n_elev = data[target].get("elevation", 0)
						var n_type = data[target].get("type", 0)

						if (
							n_elev > tile.get("elevation", 0)
							and n_type != GridManager.TileType.RAMP
						):
							# Found High Ground Block. Face it.
							if n == Vector2(1, 0):
								mesh_instance.rotation_degrees.y = 0  # Up to +X
							elif n == Vector2(-1, 0):
								mesh_instance.rotation_degrees.y = 180  # Up to -X
							elif n == Vector2(0, 1):
								mesh_instance.rotation_degrees.y = -90  # Up to +Z
							elif n == Vector2(0, -1):
								mesh_instance.rotation_degrees.y = 90  # Up to -Z
							break

			elif type == GridManager.TileType.LADDER:
				use_default_mesh = false
				var ladder_mesh = BoxMesh.new()
				ladder_mesh.size = Vector3(0.6, 2.5, 0.2)  # Tall thin plank
				mesh_instance.mesh = ladder_mesh
				material.albedo_color = Color(0.5, 0.3, 0.1)  # Dark Wood

				# Auto-Orient Ladder against Wall
				var neighbors = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
				for n in neighbors:
					var target = coord + n
					if (
						data.has(target)
						and data[target].get("elevation", 0) > tile.get("elevation", 0)
					):
						# Found Wall. Place against it.
						pos += Vector3(n.x, 0, n.y) * 0.4  # Offset towards wall
						if n.x != 0:
							mesh_instance.rotation_degrees.y = 90  # Face X
						break

		else:
			if type == GridManager.TileType.COVER_HALF:
				material.albedo_color = Color.BLUE
				box_mesh.size.y = 1.0  # Half height
				pos.y += 0.5
			elif type == GridManager.TileType.COVER_FULL:
				material.albedo_color = Color.DARK_BLUE
				box_mesh.size.y = 2.0  # Full height
				pos.y += 1.0
			else:  # Obstacle
				material.albedo_color = Color.RED
				box_mesh.size.y = 2.0
				pos.y += 1.0

		# Assign Default Mesh if not special
		if use_default_mesh:
			mesh_instance.mesh = box_mesh

		mesh_instance.material_override = material
		mesh_instance.position = pos

		# Store Base Color for Fog Logic
		mesh_instance.set_meta("base_color", material.albedo_color)

		add_child(mesh_instance)

		# Manual Collision for robustness (For Raycast)
		var static_body = StaticBody3D.new()
		static_body.name = "TileBody_" + str(coord)
		var collision_shape = CollisionShape3D.new()
		var shape = BoxShape3D.new()

		# Sync Collider Size with Visual Thickness
		if use_default_mesh:
			shape.size = box_mesh.size
		else:
			shape.size = Vector3(1.8, 0.5, 1.8)  # Fallback for Ramp/Ladder collision

		collision_shape.shape = shape
		static_body.add_child(collision_shape)
		mesh_instance.add_child(static_body)

		tile_meshes[coord] = mesh_instance

		# Debug Label (Hidden for Fog test or managed separately)
		# For now, let's keep labels but maybe hide them in reset_vision if we want true fog?
		# Or just keep them for debug clarity.
		var label = Label3D.new()
		label.text = "Walkable" if tile["is_walkable"] else "Blocked"
		label.font_size = 32
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = pos + Vector3(0, 1.5, 0)
		label.modulate = Color.WHITE if tile["is_walkable"] else Color.RED
		add_child(label)
		# Also hide label if fogged?
		# To do that, we'd need to store reference to label too or make it child of mesh.
		# Simplest: make label child of mesh_instance
		label.reparent(mesh_instance)
		label.position = Vector3(0, 1.5, 0)  # Local pos


func reset_vision():
	for coord in tile_meshes:
		var mesh = tile_meshes[coord]
		mesh.visible = false


func reveal_visible(coord: Vector2):
	if tile_meshes.has(coord):
		var mesh = tile_meshes[coord]
		mesh.visible = true
		_apply_fog_color(mesh, false)


func reveal_fogged(coord: Vector2):
	if tile_meshes.has(coord):
		var mesh = tile_meshes[coord]
		mesh.visible = true
		_apply_fog_color(mesh, true)


func _apply_fog_color(mesh: MeshInstance3D, is_fogged: bool):
	var mat = mesh.material_override
	if not mat:
		return

	if is_fogged:
		# Dark Blue-Grey for Explored/Fogged tiles
		mat.albedo_color = Color(0.3, 0.3, 0.4)
	else:
		var base_col = mesh.get_meta("base_color", Color.WHITE)
		mat.albedo_color = base_col


# AI Debugging
var score_labels = {}  # coord: Vector2 -> Label3D


func show_debug_score(coord: Vector2, score: float):
	if not tile_meshes.has(coord):
		return

	var label: Label3D
	if score_labels.has(coord):
		label = score_labels[coord]
	else:
		label = Label3D.new()
		label.font_size = 64
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color.YELLOW
		tile_meshes[coord].add_child(label)
		label.position = Vector3(0, 2.5, 0)
		score_labels[coord] = label

	label.text = str(int(score))
	label.visible = true


func clear_debug_scores():
	for coord in score_labels:
		score_labels[coord].visible = false

	# Clear Debug Lines
	if has_node("DebugLines"):
		get_node("DebugLines").queue_free()


func draw_ai_intent(from: Vector3, to: Vector3, color: Color):
	var lines_node
	if has_node("DebugLines"):
		lines_node = get_node("DebugLines")
	else:
		lines_node = MeshInstance3D.new()
		lines_node.name = "DebugLines"
		lines_node.mesh = ImmediateMesh.new()
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		lines_node.material_override = mat
		add_child(lines_node)

	var mesh = lines_node.mesh as ImmediateMesh
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, lines_node.material_override)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(from + Vector3(0, 1, 0))
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(to + Vector3(0, 1, 0))
	mesh.surface_end()


func preview_path(points: Array, color: Color = Color.CYAN):
	clear_preview_path()
	
	if points.is_empty():
		return

	var lines_node = MeshInstance3D.new()
	lines_node.name = "PreviewPath"
	lines_node.mesh = ImmediateMesh.new()
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color # Fallback
	lines_node.material_override = mat
	add_child(lines_node)

	var mesh = lines_node.mesh as ImmediateMesh
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	
	for p in points:
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(p + Vector3(0, 0.5, 0)) # Lift slightly
		
	mesh.surface_end()


func clear_preview_path():
	var existing = get_node_or_null("PreviewPath")
	if existing:
		existing.free()


func show_hover_cursor(grid_pos: Vector2):
	clear_hover_cursor()
	
	if not grid_manager:
		return
		
	var world_pos = grid_manager.get_world_position(grid_pos)
	
	var cursor = MeshInstance3D.new()
	cursor.name = "HoverCursor"
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.7, 0.15, 1.7) # Slightly larger/thicker than highlights
	cursor.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.6 # Pop!
	cursor.material_override = mat
	
	cursor.position = world_pos + Vector3(0, 0.65, 0) # Just above highlights
	add_child(cursor)


func clear_hover_cursor():
	var existing = get_node_or_null("HoverCursor")
	if existing:
		existing.free()


func preview_aoe(tiles: Array, color: Color = Color(1, 0, 0, 0.4)):
	clear_preview_aoe()
	
	if tiles.is_empty():
		return
		
	var container = Node3D.new()
	container.name = "PreviewAoE"
	add_child(container)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.4 
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.6, 0.2, 1.6) # Slightly thicker/distinct
	
	for tile_entry in tiles:
		var world_pos = Vector3.ZERO
		if tile_entry is Vector2:
			if grid_manager:
				world_pos = grid_manager.get_world_position(tile_entry)
		elif tile_entry is Dictionary and tile_entry.has("world_pos"):
			world_pos = tile_entry["world_pos"]
			
		if world_pos != Vector3.ZERO:
			var mi = MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.position = world_pos + Vector3(0, 0.7, 0) # Raise above cursor
			container.add_child(mi)

func clear_preview_aoe():
	var existing = get_node_or_null("PreviewAoE")
	if existing:
		existing.free()
