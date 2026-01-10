extends Node

var grid_viz
var grid_manager

func _ready():
	print("--- TEST START: GridVisualizer Vertex Fix ---")
	
	# Mock GridManager
	grid_manager = load("res://scripts/managers/GridManager.gd").new()
	add_child(grid_manager)
	grid_manager.grid_data[Vector2(0,0)] = {"world_pos": Vector3(0,0,0)}

	# Visualizer
	grid_viz = load("res://scripts/ui/GridVisualizer.gd").new()
	grid_viz.grid_manager = grid_manager
	add_child(grid_viz)
	
	print("Testing Single Point Path (Should NOT error)...")
	# This triggers the error "Too few vertices" if not fixed
	grid_viz.preview_path([Vector2(0,0)])
	
	# Wait for frame
	await get_tree().process_frame
	
	print("Testing Empty Path (Should be fine)...")
	grid_viz.preview_path([])
	
	print("Testing Valid Path (Should be fine)...")
	grid_viz.preview_path([Vector2(0,0), Vector2(0,0)])
	
	print("--- TEST END ---")
	get_tree().quit()
