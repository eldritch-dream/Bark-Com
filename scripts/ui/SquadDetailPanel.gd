extends PanelContainer
class_name SquadDetailPanel

var tabs_container: HBoxContainer
var content_area: VBoxContainer
var card_instance: UnitInfoCard

var active_units: Array = []
var selected_unit_index: int = 0

func _ready():
	_setup_ui()
	visible = false

func _setup_ui():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4)
	add_theme_stylebox_override("panel", style)
	
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(800, 500)
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = "SQUAD TACTICAL DISPLAY"
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.pressed.connect(func(): close())
	header.add_child(close_btn)
	
	vbox.add_child(HSeparator.new())
	
	# Tabs
	tabs_container = HBoxContainer.new()
	vbox.add_child(tabs_container)
	
	vbox.add_child(HSeparator.new())
	
	# Content
	content_area = VBoxContainer.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_area)
	
	# Instance the Card
	var card_script = load("res://scripts/ui/UnitInfoCard.gd")
	if card_script:
		card_instance = card_script.new()
		content_area.add_child(card_instance)

func open(units: Array):
	active_units = units
	_refresh_tabs()
	if active_units.size() > 0:
		_select_tab(0)
	visible = true

func close():
	visible = false

func _refresh_tabs():
	for c in tabs_container.get_children():
		c.queue_free()
		
	for i in range(active_units.size()):
		var u = active_units[i]
		if not is_instance_valid(u): continue
		
		# Only players
		if "faction" in u and u.faction != "Player": continue
		
		var btn = Button.new()
		btn.text = u.unit_name
		btn.toggle_mode = true
		btn.pressed.connect(func(): _select_tab(i))
		tabs_container.add_child(btn)

func _select_tab(index: int):
	# Update Button States
	var children = tabs_container.get_children()
	for i in range(children.size()):
		children[i].set_pressed_no_signal(i == index)
		
	if index >= 0 and index < active_units.size():
		var u = active_units[index]
		if card_instance:
			card_instance.setup(u)
