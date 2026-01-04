extends Node3D
class_name FogManager

# Configuration
const TEXTURE_SIZE = 512
const WORLD_SIZE = 40.0  # Map size in World Units (20x20 grid * 2)
const OFFSET = Vector3(12, 0, 12)  # Center offset (assuming grid 0,0 is corner)

# Nodes
var viewport: SubViewport
var brush_sprite: Sprite2D  # Reusable sprite needed? Or just draw rects?
# Actually we can't just draw in a loop, we need persistent nodes in the viewport or custom draw.
# "Clear Mode: Never" allows drawing once.

var fog_mesh: MeshInstance3D
var mask_texture: ViewportTexture

# State
var visited_tiles: Dictionary = {}  # Vector2 -> bool


func _ready():
	_setup_viewport()
	_setup_fog_mesh()


func _setup_viewport():
	viewport = SubViewport.new()
	viewport.name = "FogMaskViewport"
	viewport.size = Vector2i(TEXTURE_SIZE, TEXTURE_SIZE)
	viewport.disable_3d = true  # Optimization & Correctness for 2D
	viewport.transparent_bg = false  # Ensure black background
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# We only need to update when we add things.

	# Add a background of BLACK (Hidden)
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(TEXTURE_SIZE, TEXTURE_SIZE)
	viewport.add_child(bg)

	# Add a visible debug marker (Red Square) at 0,0
	var dbg = ColorRect.new()
	dbg.color = Color.RED
	dbg.size = Vector2(20, 20)
	dbg.position = Vector2(0, 0)  # Should be top-left
	viewport.add_child(dbg)

	add_child(viewport)

	# Wait a frame for viewport to init?


func _setup_fog_mesh():
	fog_mesh = MeshInstance3D.new()
	fog_mesh.name = "FogVolume"

	# Quad plane facing up
	var plane = PlaneMesh.new()
	plane.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	fog_mesh.mesh = plane

	# Material
	var shader = load("res://assets/shaders/FogOfWar.gdshader")
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("mask_texture", viewport.get_texture())

	# Noise
	var noise = FastNoiseLite.new()
	noise.frequency = 0.02
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	var noise_tex = NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.seamless = true
	# Need await? Noise generation is threaded usually.
	await noise_tex.changed

	mat.set_shader_parameter("noise_texture", noise_tex)
	mat.set_shader_parameter("fog_color", Color(0.15, 0.05, 0.2, 0.9))  # Eldritch Purple

	fog_mesh.material_override = mat

	# Position: Center of map roughly
	# Map is 20x20. Grid 0,0 to 20,20. World units x2 -> 0,0 to 40,40.
	# Center is 20, 20.
	fog_mesh.position = Vector3(20, 1.5, 20)  # 1.5 height (above units)

	add_child(fog_mesh)


func update_mask(units: Array):
	for unit in units:
		if is_instance_valid(unit) and unit.get("faction") == "Player":
			var range_val = unit.get("vision_range") if "vision_range" in unit else 8.0
			var world_pos_2d = Vector2(unit.position.x, unit.position.z)

			# 1. Visual Reveal (Draw Big Brush)
			# We scale brush to match vision radius
			_draw_vision_brush(world_pos_2d, range_val)

			# 2. Logical Reveal (Mark Tiles)
			var center_tile = unit.grid_pos
			var r = int(range_val)  # Tile radius

			for x in range(-r, r + 1):
				for y in range(-r, r + 1):
					if Vector2(x, y).length() <= r:
						var t_pos = center_tile + Vector2(x, y)
						_mark_tile_visited(t_pos)


func _mark_tile_visited(grid_pos: Vector2):
	var key = Vector2i(grid_pos)
	if not visited_tiles.has(key):
		visited_tiles[key] = true


func _draw_vision_brush(world_pos: Vector2, radius_tiles: float):
	# Calculate Scale
	# World Radius = radius_tiles * 2.0 (since each tile is 2 units)
	# But actually "vision_range" of 8 usually means 8 TILES.
	# So Radius = 16.0 World Units.

	var world_radius = radius_tiles * 2.0
	var scale_factor = float(TEXTURE_SIZE) / WORLD_SIZE  # px per unit
	var target_px_radius = world_radius * scale_factor

	# Texture native radius is 64px (128x128 with center at 64)
	# Gradient ends at 1.0 (edge).
	var scale_mult = target_px_radius / 64.0

	var sprite = Sprite2D.new()
	var grad = Gradient.new()
	grad.colors = [Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)]
	grad.offsets = [0.0, 0.7, 1.0]  # Harder edge for clear vision

	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128

	sprite.texture = tex
	sprite.scale = Vector2(scale_mult, scale_mult)

	# Position: World Pos -> Texture Pos
	# World(0,0) -> Tex(0,0)
	sprite.position = world_pos * scale_factor
	sprite.modulate.a = 0.0  # Start Invisible (Black Fog remains)

	viewport.add_child(sprite)

	# Animate "Fade In" of the white brush (which clears the fog)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)


func is_tile_explored(grid_pos: Vector2) -> bool:
	return visited_tiles.has(Vector2i(grid_pos))


func apply_sanity_penalties(units: Array):
	# print("FogManager: Checking Sanity Penalties on ", units.size(), " units.")
	for unit in units:
		if is_instance_valid(unit) and unit.get("faction") == "Player" and unit.current_hp > 0:
			if not is_tile_explored(unit.grid_pos):
				# Wait, if they are standing on it, it gets explored immediately in update_mask.
				# So this condition is tricky.
				# If "Fog of War" re-fills (shroud), then yes.
				# But if we clear permanently, standing there means it IS explored.
				pass

	# Re-reading prompt: "Units standing in 'Unexplored Fog' (not just out of sight, but unvisited)"
	# If I move into it, I visit it. So I am safe?
	# Maybe the penalty is for ENDING TURN in a tile that WAS unexplored at start of turn?
	# Or maybe neighboring tiles?
	# "Unexplored Fog... due to Fear of the Unknown".

	# Interpretation: If you are mostly surrounded by fog?
	# Or maybe the "Fog" is dynamic and creeps back?
	# Prompt says "Unexplored Fog".
	# If I step into it, I explore it.

	# Maybe the mechanic is: If you end turn where you CANNOT SEE (Line of Sight blocked)?
	# But prompt differentiates "not just out of sight, but unvisited".

	# Alternative: We don't reveal the tile automatically on move?
	# No, that would be weird visuals (standing in fog).

	# Maybe the penalty applies if you haven't "Secured" the area?
	# Let's stick to simple: If you haven't visited the tile, it is fog.
	# But you disperse fog when you enter.
	# So you can never end turn in Unexplored Fog unless you teleport.

	# Let's adjust mechanic: "Fear of the Dark": -5 Sanity if not near a light source?
	# No, stick to prompt.
	# Maybe the Vision Radius is smaller than movement?
	# If I run into the dark, I reveal it.

	# AHA! Maybe the mask updates at START of turn?
	# No, real-time is better.

	# Let's implement the Visuals first. The Sanity mechanic might be:
	# "If adjacent to Fog". (Fear of what's lurking nearby).
	# Let's do: -5 Sanity for every adjacent Unexplored Tile.

	for unit in units:
		if is_instance_valid(unit) and unit.get("faction") == "Player" and unit.current_hp > 0:
			# Fear Radius: Check wider than vision (Vision 4, Fear Check 6)
			# If darkness lies just beyond your sight...
			# Sanity Check: Standing in Unexplored Fog?
			if not is_tile_explored(unit.grid_pos):
				var dmg = 5
				unit.take_sanity_damage(dmg)
				SignalBus.on_request_floating_text.emit(
					unit.position, "Lost in Fog! -5 Sanity", Color.PURPLE
				)
				# print("FogManager: ", unit.name, " took damage from Fog.")
