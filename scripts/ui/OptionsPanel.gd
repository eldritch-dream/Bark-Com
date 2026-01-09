extends PanelContainer
class_name OptionsPanel

var music_slider: HSlider
var sfx_slider: HSlider
var text_size_slider: HSlider
var text_size_value_label: Label

func _ready():
	_setup_ui()
	visible = false

func _setup_ui():
	# Background Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4)
	add_theme_stylebox_override("panel", style)
	
	set_anchors_preset(Control.PRESET_CENTER)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 300)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Audio Section
	vbox.add_child(_create_section_label("AUDIO"))
	
	vbox.add_child(Label.new())
	var m_label = Label.new()
	m_label.text = "Music Volume"
	vbox.add_child(m_label)

	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	if GameManager:
		music_slider.value = GameManager.settings.get("music_vol", 0.5)
	music_slider.value_changed.connect(_on_music_volume_changed)
	vbox.add_child(music_slider)

	vbox.add_child(Label.new())
	var s_label = Label.new()
	s_label.text = "SFX Volume"
	vbox.add_child(s_label)

	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	if GameManager:
		sfx_slider.value = GameManager.settings.get("sfx_vol", 0.5)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	vbox.add_child(sfx_slider)

	vbox.add_child(HSeparator.new())

	# Display Section
	vbox.add_child(_create_section_label("DISPLAY"))
	
	var fs_check = CheckBox.new()
	fs_check.text = "Fullscreen"
	var is_fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_check.button_pressed = is_fs
	fs_check.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(fs_check)
	
	vbox.add_child(Label.new()) # Spacer
	
	# Text Size
	var ts_hbox = HBoxContainer.new()
	vbox.add_child(ts_hbox)
	
	var ts_label = Label.new()
	ts_label.text = "Text Size"
	ts_hbox.add_child(ts_label)
	
	text_size_value_label = Label.new()
	text_size_value_label.text = "(18)"
	text_size_value_label.modulate = Color.GRAY
	ts_hbox.add_child(text_size_value_label)
	
	text_size_slider = HSlider.new()
	text_size_slider.min_value = 12
	text_size_slider.max_value = 32
	text_size_slider.step = 2
	# Default or Global
	var current_theme = ThemeDB.get_project_theme()
	var scene = get_tree().current_scene
	if scene and "theme" in scene and scene.theme:
		current_theme = scene.theme
	
	# Try to get from global resource if bound
	# But we can just default to 18
	text_size_slider.value = 18 
	if current_theme:
		text_size_slider.value = current_theme.default_font_size
		
	text_size_slider.value_changed.connect(_on_text_size_changed)
	vbox.add_child(text_size_slider)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	vbox.add_child(HSeparator.new())

	# Close Button
	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size.y = 40
	close_btn.pressed.connect(func(): visible = false)
	vbox.add_child(close_btn)

func _create_section_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color.GOLD)
	return l

func _on_music_volume_changed(val: float):
	if GameManager:
		GameManager.settings["music_vol"] = val
		GameManager._apply_audio_settings()

func _on_sfx_volume_changed(val: float):
	if GameManager:
		GameManager.settings["sfx_vol"] = val
		GameManager._apply_audio_settings()

func _on_fullscreen_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_text_size_changed(val: float):
	text_size_value_label.text = "(" + str(int(val)) + ")"
	
	# UPDATE GLOBAL THEME
	# We need to find the Theme resource used by GameUI / BaseScene
	# Since this panel is a child of GameUI or BaseScene, we can check usage.
	var theme_node = self
	var theme_res : Theme = null
	
	# Walk up to find a node with a Theme
	var p = get_parent()
	while p:
		if "theme" in p and p.theme:
			theme_res = p.theme
			break
		p = p.get_parent()
	
	if not theme_res:
		# Fallback: Load directly
		# This updates the resource in memory, which is shared if cached
		theme_res = load("res://resources/GameTheme.tres")
		
	if theme_res:
		var s = int(val)
		theme_res.default_font_size = s
		theme_res.set_font_size("font_size", "Label", s)
		theme_res.set_font_size("font_size", "Button", s)
		theme_res.set_font_size("normal_font_size", "RichTextLabel", s)
		theme_res.set_font_size("bold_font_size", "RichTextLabel", s)
		theme_res.set_font_size("italics_font_size", "RichTextLabel", s)
		theme_res.set_font_size("mono_font_size", "RichTextLabel", s)
		# ProgressBar usually smaller
		theme_res.set_font_size("font_size", "ProgressBar", max(10, s - 4))
		
		# Persist via GameManager?
		if GameManager:
			GameManager.settings["text_size"] = s

func open():
	# Refresh values on open
	if GameManager:
		music_slider.value = GameManager.settings.get("music_vol", 0.5)
		sfx_slider.value = GameManager.settings.get("sfx_vol", 0.5)
		if "text_size" in GameManager.settings:
			text_size_slider.value = GameManager.settings["text_size"]
			text_size_value_label.text = "(" + str(GameManager.settings["text_size"]) + ")"
	visible = true
