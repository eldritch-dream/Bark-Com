extends PanelContainer
class_name TalentSelectPopup

signal perk_selected(perk_id: String)

var title_label: Label
var container: HBoxContainer
var rank_level: int = 2

func _ready():
	_setup_ui()

func _setup_ui():
	# Modal Overlay Style
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(600, 400)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color.GOLD
	add_theme_stylebox_override("panel", sb)
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	title_label = Label.new()
	title_label.text = "PROMOTION AVAILABLE!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title_label)
	
	vbox.add_child(HSeparator.new())
	
	# The two choices
	container = HBoxContainer.new()
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 20)
	vbox.add_child(container)
	
	var close_btn = Button.new()
	close_btn.text = "Decide Later"
	close_btn.pressed.connect(func(): queue_free())
	vbox.add_child(close_btn)

func setup_choices(rank: int, choices: Array):
	rank_level = rank
	title_label.text = "RANK " + str(rank) + " PROMOTION"
	
	# Clear existing
	for c in container.get_children():
		c.queue_free()
	
	for i in range(choices.size()):
		var perk = choices[i]
		var btn = _create_choice_panel(perk)
		container.add_child(btn)

func _create_choice_panel(perk: Resource) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(250, 300)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let button catch input
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(margin)
	margin.add_child(vbox)
	
	# Icon
	var tex = TextureRect.new()
	tex.custom_minimum_size = Vector2(64, 64)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture = perk.icon if perk.icon else load("res://icon.svg") # Fallback
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(tex)
	
	# Name
	var lbl_name = Label.new()
	lbl_name.text = perk.display_name
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.add_theme_font_size_override("font_size", 20)
	lbl_name.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(lbl_name)
	
	vbox.add_child(HSeparator.new())
	
	# Desc
	var lbl_desc = RichTextLabel.new()
	lbl_desc.bbcode_enabled = true
	lbl_desc.text = perk.description
	lbl_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl_desc)
	
	# Click
	btn.pressed.connect(func(): _on_choice_selected(perk))
	
	return btn

func _on_choice_selected(perk):
	emit_signal("perk_selected", perk.id)
	queue_free()
