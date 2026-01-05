extends PanelContainer
class_name SquadMemberFrame

var unit_ref: Unit
var hp_bar: ProgressBar
var sanity_bar: ProgressBar
var ap_label: Label
var button: Button
var highlight: StyleBoxFlat

signal unit_selected(unit)


func initialize(unit: Unit):
	unit_ref = unit
	_setup_ui()
	refresh()

	# Connect signals
	if SignalBus.has_signal("on_unit_stats_changed"):
		SignalBus.on_unit_stats_changed.connect(_on_stats_changed)


func _setup_ui():
	# Style
	custom_minimum_size.x = 120  # Widen frame
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_width_left = 4
	style.border_color = Color.GRAY
	add_theme_stylebox_override("panel", style)
	highlight = style

	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Top: Name + AP
	var top = HBoxContainer.new()
	vbox.add_child(top)

	var name_l = Label.new()
	name_l.text = unit_ref.unit_name if unit_ref.unit_name else unit_ref.name
	# name_l.clip_text = true # Disable clipping to show full name
	# Or set min scale?
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 16)
	top.add_child(name_l)

	ap_label = Label.new()
	ap_label.text = "AP: 0"
	ap_label.add_theme_font_size_override("font_size", 16)
	ap_label.modulate = Color(0.7, 1.0, 1.0) # Cyan tint for visibility
	top.add_child(ap_label)

	# Middle: Portrait (Use UnitPortraitConfig)
	var port_script = load("res://scripts/ui/UnitPortraitConfig.gd")
	if port_script:
		var port = port_script.new()
		port.custom_minimum_size = Vector2(100, 100)  # Slightly larger
		vbox.add_child(port)
		port.update_portrait(unit_ref)
		# No rotation hint in HUD to stay clean
	else:
		# Fallback
		var port_bg = ColorRect.new()
		port_bg.custom_minimum_size = Vector2(80, 80)
		port_bg.color = Color(0.2, 0.2, 0.2)
		vbox.add_child(port_bg)

	# Overlay Button for clicking
	button = Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add to self (PanelContainer) so it covers children
	add_child(button)
	button.pressed.connect(
		func():
			if is_instance_valid(unit_ref):
				unit_selected.emit(unit_ref)
	)

	# Bottom: Bars
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size.y = 8
	hp_bar.show_percentage = false
	hp_bar.modulate = Color(0.8, 0.2, 0.2)  # Red
	vbox.add_child(hp_bar)

	sanity_bar = ProgressBar.new()
	sanity_bar.custom_minimum_size.y = 6
	sanity_bar.show_percentage = false
	sanity_bar.modulate = Color(0.4, 0.2, 0.8)  # Purple
	vbox.add_child(sanity_bar)


func refresh():
	if not is_instance_valid(unit_ref):
		return

	hp_bar.max_value = unit_ref.max_hp
	hp_bar.value = unit_ref.current_hp

	sanity_bar.max_value = unit_ref.max_sanity
	sanity_bar.value = unit_ref.current_sanity

	ap_label.text = "AP: " + str(unit_ref.current_ap)

	# Gray out if dead
	if unit_ref.current_hp <= 0:
		modulate = Color(0.5, 0.5, 0.5)


func _on_stats_changed(u):
	if u == unit_ref:
		refresh()


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(unit_ref):
			unit_selected.emit(unit_ref)


func set_selected(is_sel: bool):
	if is_sel:
		highlight.border_color = Color.GREEN
	else:
		highlight.border_color = Color.GRAY
	add_theme_stylebox_override("panel", highlight)
