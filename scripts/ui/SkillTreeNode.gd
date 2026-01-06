extends PanelContainer
class_name SkillTreeNode

signal node_clicked(perk_id: String)
signal node_hovered(perk: Perk, node_global_pos: Vector2)
signal node_exited()

var perk_id: String
var perk_resource: Perk
var state: String = "LOCKED" # LOCKED, AVAILABLE, LEARNED, SKIPPED

var icon_rect: TextureRect
var border_style: StyleBoxFlat

# Colors
const COL_LOCKED = Color(0.2, 0.2, 0.2, 0.8)
const COL_AVAILABLE = Color(0.0, 0.8, 1.0, 1.0) # Cyan
const COL_LEARNED_GOLD = Color(1.0, 0.84, 0.0, 1.0) # Gold
const COL_SKIPPED = Color(0.1, 0.1, 0.1, 0.5)

func _ready():
	_setup_ui()

func _setup_ui():
	custom_minimum_size = Vector2(80, 80)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Base Style
	border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	border_style.border_width_left = 3
	border_style.border_width_top = 3
	border_style.border_width_right = 3
	border_style.border_width_bottom = 3
	border_style.corner_radius_top_left = 10
	border_style.corner_radius_top_right = 10
	border_style.corner_radius_bottom_left = 10
	border_style.corner_radius_bottom_right = 10
	border_style.border_color = COL_LOCKED
	add_theme_stylebox_override("panel", border_style)
	
	# Icon
	icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.modulate = Color(0.5, 0.5, 0.5) # Dimmed by default
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_rect)
	
	# Interactions
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_exited():
	emit_signal("node_exited")

func setup(perk: Perk, current_state: String):
	perk_resource = perk
	perk_id = perk.id
	state = current_state
	
	if perk.icon:
		icon_rect.texture = perk.icon
	else:
		# Placeholder icon if missing
		icon_rect.texture = load("res://icon.svg") 
	
	_update_visuals()

func _update_visuals():
	match state:
		"LOCKED":
			border_style.border_color = COL_LOCKED
			border_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
			icon_rect.modulate = Color(0.3, 0.3, 0.3)
		
		"AVAILABLE":
			border_style.border_color = COL_AVAILABLE
			# Pulsing logic could be added in _process or with Tween
			border_style.bg_color = Color(0.0, 0.2, 0.3, 0.9)
			icon_rect.modulate = Color(0.8, 1.0, 1.0)
			
		"LEARNED":
			# METALLIC GOLD LOOK
			border_style.border_color = COL_LEARNED_GOLD
			border_style.bg_color = Color(0.4, 0.3, 0.1, 0.9) # Dark gold BG
			border_style.shadow_color = COL_LEARNED_GOLD
			border_style.shadow_size = 5
			icon_rect.modulate = Color(1.2, 1.1, 0.8) # Brighten
			
		"SKIPPED":
			border_style.border_color = Color(0.1, 0.1, 0.1, 0.2)
			border_style.bg_color = Color(0.05, 0.05, 0.05, 0.5)
			icon_rect.modulate = Color(0.1, 0.1, 0.1)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == "AVAILABLE":
			emit_signal("node_clicked", perk_id)
		elif state == "LEARNED":
			print("Already learned!")

func _on_mouse_entered():
	emit_signal("node_hovered", perk_resource, global_position)
