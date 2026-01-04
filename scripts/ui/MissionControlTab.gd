extends PanelContainer
class_name MissionControlTab

var game_manager: _GameManager
var selected_indices: Array = []  # Indices in roster
var max_squad_size = 4

var squad_container: VBoxContainer
var mission_container: GridContainer
var launch_btn: Button
var doom_meter: ProgressBar
var doom_label: Label


func initialize(gm: GameManager):
	game_manager = gm
	_select_default_squad()
	_refresh_ui()


func _ready():
	_setup_ui()


func _setup_ui():
	# Root HBox for 2 Columns
	var main_hbox = HBoxContainer.new()
	add_child(main_hbox)

	# --- LEFT: SQUAD SELECTION ---
	var left_panel = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.4
	main_hbox.add_child(left_panel)

	var left_vbox = VBoxContainer.new()
	left_panel.add_child(left_vbox)

	var s_lbl = Label.new()
	s_lbl.text = "SQUAD SELECTION"
	s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_lbl.add_theme_font_size_override("font_size", 18)
	left_vbox.add_child(s_lbl)
	left_vbox.add_child(HSeparator.new())

	# Squad Scroll/Grid
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	squad_container = VBoxContainer.new()
	squad_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(squad_container)

	# --- RIGHT: MISSION MAP ---
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.6
	main_hbox.add_child(right_panel)

	var right_vbox = VBoxContainer.new()
	right_panel.add_child(right_vbox)

	var m_lbl = Label.new()
	m_lbl.text = "AVAILABLE OPERATIONS"
	m_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_lbl.add_theme_font_size_override("font_size", 18)
	m_lbl.add_theme_font_size_override("font_size", 18)
	right_vbox.add_child(m_lbl)
	right_vbox.add_child(HSeparator.new())

	# ELDRITCH METER
	var doom_container = VBoxContainer.new()
	right_vbox.add_child(doom_container)

	doom_label = Label.new()
	doom_label.text = "ELDRITCH INVASION"
	doom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	doom_label.add_theme_color_override("font_color", Color.VIOLET)
	doom_container.add_child(doom_label)

	doom_meter = ProgressBar.new()
	doom_meter.custom_minimum_size = Vector2(0, 20)
	doom_meter.max_value = 100
	doom_meter.show_percentage = true
	var style = StyleBoxFlat.new()
	style.bg_color = Color.PURPLE
	doom_meter.add_theme_stylebox_override("fill", style)
	doom_container.add_child(doom_meter)

	right_vbox.add_child(HSeparator.new())

	var scan_btn = Button.new()
	scan_btn.text = "SCAN FOR NEW MISSIONS (+1% INVASION)"
	scan_btn.pressed.connect(_on_manual_scan)
	right_vbox.add_child(scan_btn)

	# Mission Grid
	mission_container = GridContainer.new()
	mission_container.columns = 2
	mission_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(mission_container)

	# Bottom Action
	launch_btn = Button.new()
	launch_btn.text = "LAUNCH MISSION"
	launch_btn.custom_minimum_size = Vector2(0, 50)
	launch_btn.disabled = true
	launch_btn.pressed.connect(_on_launch_pressed)
	right_vbox.add_child(launch_btn)


func _select_default_squad():
	selected_indices.clear()
	if not game_manager:
		return

	var count = 0
	for i in range(game_manager.roster.size()):
		if game_manager.roster[i]["status"] == "Ready" and count < max_squad_size:
			selected_indices.append(i)
			count += 1


func _refresh_ui():
	_refresh_squad_list()
	_generate_missions()  # Auto-scan on open


func _refresh_squad_list():
	for c in squad_container.get_children():
		c.queue_free()

	if not game_manager:
		return

	var portrait_script = load("res://scripts/ui/UnitPortraitConfig.gd")

	# Filter only Ready units? Or all? Usually only Ready units can deploy.
	for i in range(game_manager.roster.size()):
		var unit = game_manager.roster[i]
		if unit["status"] != "Ready":
			continue

		var is_selected = selected_indices.has(i)

		# Row
		var hbox = HBoxContainer.new()
		squad_container.add_child(hbox)

		# Portrait
		if portrait_script:
			var p = portrait_script.new()
			p.custom_minimum_size = Vector2(80, 80)
			hbox.add_child(p)  # Add first to trigger _ready
			p.update_portrait(unit)

			# Rotation Hint
			p.tooltip_text = "Right-Click & Drag to Rotate"

		# Info
		var info_box = VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_box)

		var name_l = Label.new()
		name_l.text = unit["name"]
		info_box.add_child(name_l)

		var cls_l = Label.new()
		cls_l.text = unit.get("class", "Recruit") + " (Lvl " + str(unit["level"]) + ")"
		info_box.add_child(cls_l)

		# Toggle Button
		var btn = Button.new()
		btn.text = "SELECTED" if is_selected else "Select"
		btn.modulate = Color.GREEN if is_selected else Color.WHITE
		btn.toggle_mode = true
		btn.button_pressed = is_selected
		btn.pressed.connect(func(): _toggle_selection(i))
		hbox.add_child(btn)

		hbox.add_child(HSeparator.new())


func _toggle_selection(idx):
	if selected_indices.has(idx):
		selected_indices.erase(idx)
	else:
		if selected_indices.size() < max_squad_size:
			selected_indices.append(idx)

	_refresh_squad_list()
	_update_launch_state()


var selected_mission: MissionData = null
var scan_cost = 1

func _on_manual_scan():
	if game_manager:
		game_manager.reroll_missions()
	_generate_missions()


func _generate_missions():
	# Clear
	for c in mission_container.get_children():
		c.queue_free()
	selected_mission = null
	_update_launch_state()

	# Update Meter
	if game_manager and doom_meter:
		var progress = game_manager.invasion_progress
		doom_meter.value = progress

		# Check End Game
		if progress >= 100:
			doom_label.text = "!!! INVASION IMMINENT !!!"
			doom_label.add_theme_color_override("font_color", Color.RED)
			_create_base_defense_mission()
			return  # STOP NORMAL GENERATION

		else:
			doom_label.text = "ELDRITCH INVASION: " + str(progress) + "%"
			doom_label.add_theme_color_override("font_color", Color.VIOLET)

	if game_manager:
		var missions = game_manager.get_available_missions()
		for m in missions:
			_create_mission_card(m)

# _create_random_mission removed (Found in GameManager now)
func _create_base_defense_mission():
	var m = MissionData.new()
	m.mission_name = "BASE DEFENSE"
	m.description = "THEY ARE HERE. PROTECT THE GOLDEN HYDRANT AT ALL COSTS."
	m.difficulty_rating = 5  # MAX
	m.reward_kibble = 500
	m.map_scene_path = "res://scenes/maps/BaseDefenseMap.tscn"
	m.objective_type = 4  # DEFENSE
	m.objective_target_count = 1 # Must be 1 to trigger spawn loop

	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 100)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ">>> DEFEND THE BASE <<<\nSURVIVE 10 WAVES"
	btn.modulate = Color.GOLD
	btn.toggle_mode = true

	btn.pressed.connect(func(): _select_mission(m, btn))
	mission_container.add_child(btn)


func _create_mission_card(mission: MissionData):
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 100)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.toggle_mode = true

	var type_str = "Unknown"
	match mission.objective_type:
		0:
			type_str = "DEATHMATCH"
		1:
			type_str = "RESCUE"
		2:
			type_str = "RETRIEVE"
		3:
			type_str = "HACKER"

	btn.text = (
		mission.mission_name + "\nDiff: " + str(mission.difficulty_rating) + "\n[" + type_str + "]"
	)
	if mission.objective_target_count > 0:
		btn.text += "\nTargets: " + str(mission.objective_target_count)
	
	btn.text += "\nReward: " + str(mission.reward_kibble) + " Kibble"

	# Color code
	if mission.difficulty_rating == 2:
		btn.modulate = Color.YELLOW
	elif mission.difficulty_rating == 3:
		btn.modulate = Color(1, 0.5, 0.5)

	btn.pressed.connect(func(): _select_mission(mission, btn))
	mission_container.add_child(btn)


func _select_mission(m: MissionData, btn: Button):
	selected_mission = m
	# Visual toggle logic (manual since no group resource handy)
	for c in mission_container.get_children():
		c.set_pressed_no_signal(false)
	btn.set_pressed_no_signal(true)

	_update_launch_state()


func _update_launch_state():
	if selected_indices.size() > 0 and selected_mission != null:
		launch_btn.disabled = false
		launch_btn.text = "LAUNCH: " + selected_mission.mission_name
	else:
		launch_btn.disabled = true
		launch_btn.text = "SELECT SQUAD & MISSION"


func _on_launch_pressed():
	if not game_manager or not selected_mission:
		return

	var squad_data = []
	for idx in selected_indices:
		squad_data.append(game_manager.roster[idx])

	game_manager.start_mission(selected_mission, squad_data)
