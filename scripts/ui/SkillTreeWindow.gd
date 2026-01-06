extends PanelContainer
class_name SkillTreeWindow

var unit_data: Dictionary
var tree_data: ClassBarkTree

var nodes_map: Dictionary = {} # perk_id -> SkillTreeNode
var drawing_layer: Control

var tooltip_panel: PanelContainer
var tooltip_label: RichTextLabel

func _ready():
	_setup_ui()

func _setup_ui():
	# Ensuring visibility on top of Barracks
	z_index = 100 
	
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(800, 600)
	
	# Force center position relative to viewport (in case parent anchor fails)
	# But typically PRESET_CENTER works if parent is full rect.
	# If parent is root (Window/SubViewport), it should work.
	
	# Transparent BG styling for "Holo" look
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.0, 0.8, 1.0, 0.5) # tech blue border
	add_theme_stylebox_override("panel", sb)

	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)

	# HEADER
	var header = Label.new()
	header.text = "TACTICAL NEURAL INTERFACE"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	main_vbox.add_child(header)
	
	main_vbox.add_child(HSeparator.new())

	# TREE AREA (Center)
	var tree_margin = MarginContainer.new()
	tree_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_margin.add_theme_constant_override("margin_top", 40)
	tree_margin.add_theme_constant_override("margin_bottom", 40)
	tree_margin.add_theme_constant_override("margin_left", 100)
	tree_margin.add_theme_constant_override("margin_right", 100)
	main_vbox.add_child(tree_margin)

	# Drawing Layer (Behind nodes)
	drawing_layer = Control.new()
	drawing_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Connect draw
	drawing_layer.draw.connect(_on_draw_lines)
	tree_margin.add_child(drawing_layer)

	# Node Container (Vertical: Top Rank to Bot Rank?) 
	# Actually visual trees usually go Bottom -> Top or Top -> Bottom.
	# Let's do Bottom (Rank 2) -> Top (Rank 6).
	# So VBox order: Rank 6, Spacer, Rank 4, Spacer, Rank 2
	
	var tree_vbox = VBoxContainer.new()
	tree_vbox.alignment = BoxContainer.ALIGNMENT_CENTER # Center vertically
	tree_vbox.add_theme_constant_override("separation", 80) # Distance between Ranks
	tree_margin.add_child(tree_vbox)
	
	# Rows (We create placeholders to fill later)
	# Rank 6 (Top)
	var r6_hbox = HBoxContainer.new()
	r6_hbox.name = "Rank6"
	r6_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tree_vbox.add_child(r6_hbox)
	
	# Rank 4
	var r4_hbox = HBoxContainer.new()
	r4_hbox.name = "Rank4"
	r4_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	r4_hbox.add_theme_constant_override("separation", 150) # Spread out choices
	tree_vbox.add_child(r4_hbox)
	
	# Rank 2 (Bottom)
	var r2_hbox = HBoxContainer.new()
	r2_hbox.name = "Rank2"
	r2_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	r2_hbox.add_theme_constant_override("separation", 150)
	tree_vbox.add_child(r2_hbox)

	var close_btn = Button.new()
	close_btn.text = "CLOSE INTERFACE"
	close_btn.custom_minimum_size.y = 40
	close_btn.pressed.connect(func(): queue_free())
	main_vbox.add_child(close_btn)

	# Tooltip
	_setup_tooltip()

func _setup_tooltip():
	tooltip_panel = PanelContainer.new()
	tooltip_panel.visible = false
	tooltip_panel.top_level = true # Ignore parent layout constraints
	tooltip_panel.z_index = 101 # Ensure above window (which is 100)
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.modulate = Color(1,1,1,0.9)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color.BLACK
	sb.border_color = Color.GOLD
	sb.border_width_bottom = 1
	tooltip_panel.add_theme_stylebox_override("panel", sb)
	
	tooltip_label = RichTextLabel.new()
	tooltip_label.fit_content = true
	tooltip_label.bbcode_enabled = true
	tooltip_label.custom_minimum_size = Vector2(250, 0)
	tooltip_panel.add_child(tooltip_label)
	
	# Add to main scene over everything? Or just child of window
	add_child(tooltip_panel)

func setup(unit_dict: Dictionary):
	unit_data = unit_dict
	var unit_class_name = unit_data.get("class", "Recruit")
	
	print("SkillTreeWindow: Setup for ", unit_data.get("name"), " | Class: ", unit_class_name)
	print("DEBUG Keys: ", unit_data.keys())
	
	# Load Tree Data
	# HARDCODED FOR NOW UNTIL REGISTRY
	var path = "res://assets/data/trees/" + unit_class_name + "BarkTree.tres"
	if ResourceLoader.exists(path):
		tree_data = load(path)
		print("SkillTreeWindow: Loaded tree from ", path)
	else:
		print("No tree found for ", unit_class_name, " at path: ", path)
		return

	_populate_nodes()

func _populate_nodes():
	var rank2_cont = find_child("Rank2", true, false)
	var rank4_cont = find_child("Rank4", true, false)
	var rank6_cont = find_child("Rank6", true, false)
	
	_create_rank_nodes(tree_data.rank_2_options, rank2_cont, 2)
	_create_rank_nodes(tree_data.rank_4_options, rank4_cont, 4)
	_create_rank_nodes(tree_data.rank_6_options, rank6_cont, 6)
	
	call_deferred("_queue_redraw") # Wait for layout

func _create_rank_nodes(options: Array, container: Container, rank: int):
	for perk in options:
		var node = SkillTreeNode.new()
		container.add_child(node)
		
		var state = _get_node_state(perk.id, rank)
		node.setup(perk, state)
		node.node_clicked.connect(_on_node_clicked)
		node.node_hovered.connect(_on_node_hovered)
		node.node_exited.connect(func(): tooltip_panel.visible = false)
		nodes_map[perk.id] = node

func _get_node_state(perk_id: String, rank: int) -> String:
	var unlocked = false
	if BarkTreeManager:
		unlocked = BarkTreeManager.has_perk(unit_data["name"], perk_id)
	
	if unlocked: return "LEARNED"
	
	var current_level = unit_data.get("level", 1)
	
	# Check if another perk in same rank is already learned (Exclusive Logic)
	# Iterate all perks in this rank from tree_data
	var rank_options = []
	if rank == 2: rank_options = tree_data.rank_2_options
	elif rank == 4: rank_options = tree_data.rank_4_options
	elif rank == 6: rank_options = tree_data.rank_6_options
	
	for other in rank_options:
		if other.id != perk_id:
			if BarkTreeManager.has_perk(unit_data["name"], other.id):
				return "SKIPPED" # Mutually exclusive

	if current_level >= rank:
		return "AVAILABLE"
	else:
		return "LOCKED"

func _on_node_clicked(perk_id: String):
	if BarkTreeManager:
		BarkTreeManager.unlock_perk(unit_data["name"], perk_id)
		# Refresh UI
		# Re-setup to update states
		
		# Update unit_data cache logic? 
		# BarkTreeManager updates persistent data. Unit.gd reads it.
		# We just need to refresh visual states.
		
		# Refresh Nodes
		for pid in nodes_map:
			var node = nodes_map[pid]
			# Find rank of this perk
			var rank = 2 # optimization needed but fine for now
			if _is_in_rank(pid, 4): rank = 4
			elif _is_in_rank(pid, 6): rank = 6
			
			var new_state = _get_node_state(pid, rank)
			node.setup(node.perk_resource, new_state)
			
		drawing_layer.queue_redraw()

func _is_in_rank(pid, rank):
	var list = []
	if rank==2: list=tree_data.rank_2_options
	elif rank==4: list=tree_data.rank_4_options
	elif rank==6: list=tree_data.rank_6_options
	for p in list: 
		if p.id==pid: return true
	return false

func _on_node_hovered(perk, pos):
	tooltip_panel.visible = true
	# Offset to avoid overlapping mouse and causing flicker
	tooltip_panel.global_position = pos + Vector2(30, -80)
	tooltip_label.text = "[color=gold][b]" + perk.display_name + "[/b][/color]\n" + perk.description

func _on_draw_lines():
	if not tree_data:
		return

	# Simple connections: Center to Center logic
	# We know the structure: 2 -> 2 -> 1
	# Rank 2 Left -> Rank 4 Left
	# Rank 2 Right -> Rank 4 Right
	# Rank 4 Both -> Rank 6 Center
	
	# Helper to get pos
	var r2_left = _get_node_pos(tree_data.rank_2_options, 0)
	var r2_right = _get_node_pos(tree_data.rank_2_options, 1)
	
	var r4_left = _get_node_pos(tree_data.rank_4_options, 0)
	var r4_right = _get_node_pos(tree_data.rank_4_options, 1)
	
	var r6 = _get_node_pos(tree_data.rank_6_options, 0)
	
	if r2_left and r4_left: _draw_connection(r2_left, r4_left)
	if r2_right and r4_right: _draw_connection(r2_right, r4_right)
	
	if r4_left and r6: _draw_connection(r4_left, r6)
	if r4_right and r6: _draw_connection(r4_right, r6)

func _get_node_pos(list, index):
	if list.size() > index:
		var pid = list[index].id
		if nodes_map.has(pid):
			var node = nodes_map[pid]
			# return local pos relative to drawing layer
			return node.global_position + node.size/2 - drawing_layer.global_position
	return null

func _draw_connection(from, to):
	var col = Color.DARK_GRAY
	# If BOTH nodes are Learned, color Gold? 
	# Or if 'from' is Learned and 'to' is Available?
	# Simple logic: If 'to' is Learned, line is Gold.
	
	# We need to look up node state map, but we don't have direct access here easily without checking nodes_map again.
	# Let's assume if 'to' node is LEARNED, line is gold.
	
	drawing_layer.draw_line(from, to, col, 2.0)

	
func _queue_redraw():
	drawing_layer.queue_redraw()
