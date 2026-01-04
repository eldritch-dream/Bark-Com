extends PanelContainer
class_name MissionSelectUI

var mission_container: HBoxContainer
var game_manager: _GameManager
var selected_indices: Array = []  # Indices of units in GameManager.roster that are selected
var max_squad_size = 4
var doom_meter: ProgressBar
var doom_label: Label


func _ready():
	_setup_ui()
	visible = false


func _setup_ui():
	# Root VBox
	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Header
	# SQUAD PREVIEW
	var squad_lbl = Label.new()
	squad_lbl.name = "SquadLabel"
	squad_lbl.text = "DEPLOYMENT SQUAD (0/" + str(max_squad_size) + ")"
	squad_lbl.add_theme_color_override("font_color", Color.CYAN)
	squad_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(squad_lbl)

	var squad_container = HBoxContainer.new()
	squad_container.alignment = BoxContainer.ALIGNMENT_CENTER
	# Force height so it doesn't collapse
	squad_container.custom_minimum_size = Vector2(0, 150)
	squad_container.name = "SquadContainer"
	vbox.add_child(squad_container)

	vbox.add_child(HSeparator.new())

	vbox.add_child(HSeparator.new())

	# Doomsday Meter
	var doom_container = VBoxContainer.new()
	vbox.add_child(doom_container)

	doom_label = Label.new()
	doom_label.text = "ELDRITCH INVASION"
	doom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	doom_label.add_theme_color_override("font_color", Color.VIOLET)
	doom_container.add_child(doom_label)

	doom_meter = ProgressBar.new()
	doom_meter.custom_minimum_size = Vector2(0, 20)
	doom_meter.max_value = 100
	doom_meter.show_percentage = true
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color.PURPLE
	doom_meter.add_theme_stylebox_override("fill", style)
	doom_container.add_child(doom_meter)

	vbox.add_child(HSeparator.new())

	# Scan Button
	var scan_btn = Button.new()
	scan_btn.name = "ScanButton"
	scan_btn.text = "SCAN FOR ACTIVITY"
	scan_btn.pressed.connect(_on_scan_pressed)
	vbox.add_child(scan_btn)

	# Missions Area
	mission_container = HBoxContainer.new()
	mission_container.custom_minimum_size = Vector2(400, 150)
	mission_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(mission_container)

	vbox.add_child(HSeparator.new())

	# Close Button
	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.pressed.connect(func(): visible = false)
	vbox.add_child(close_btn)


func initialize(gm: GameManager):
	game_manager = gm
	# Default Selection: First 4 Ready units
	selected_indices.clear()
	var ready = gm.get_ready_corgis()
	var count = 0

	# We need to map 'ready' back to roster indices or just store the unit objects/names.
	# Storing Names is safer for persistence/lookup.
	# Actually, get_ready_corgis returns references to the dicts in roster.
	# So we can just store the dicts references.

	# Let's find indices in the main roster to be precise.
	for i in range(gm.roster.size()):
		if gm.roster[i]["status"] == "Ready" and count < max_squad_size:
			selected_indices.append(i)
			count += 1

			count += 1

	_refresh_squad_preview()
	_update_doomsday_ui()


func _update_doomsday_ui():
	if not game_manager:
		return
	if not doom_meter:
		return

	var progress = game_manager.invasion_progress
	doom_meter.value = progress

	var scan_btn = find_child("ScanButton", true, false)

	if progress >= 100:
		doom_label.text = "!!! INVASION IMMINENT !!!"
		doom_label.add_theme_color_override("font_color", Color.RED)

		if scan_btn:
			scan_btn.text = "⚠️ LAUNCH BASE DEFENSE ⚠️"
			# Override connection? Actually Scan logic checks progress anyway.
	else:
		doom_label.text = "ELDRITCH INVASION: " + str(progress) + "%"
		if scan_btn:
			scan_btn.text = "SCAN FOR ACTIVITY"


func _refresh_squad_preview():
	var container = find_child("SquadContainer", true, false)
	if not container:
		return

	# Clear
	for c in container.get_children():
		c.queue_free()

	if not game_manager:
		return

	# Show ALL Ready units? Or just selected?
	# User wants to SELECT. So show ALL available options.
	# Filter Roster for "Ready" + currently selected (if status changes?)
	# Just show all "Ready" units for potential selection.

	var all_ready_indices = []
	for i in range(game_manager.roster.size()):
		if game_manager.roster[i]["status"] == "Ready":
			all_ready_indices.append(i)

	var portrait_script = load("res://scripts/ui/UnitPortraitConfig.gd")
	if not portrait_script:
		return

	for idx in all_ready_indices:
		var unit_data = game_manager.roster[idx]
		var is_selected = selected_indices.has(idx)

		# Card Container
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(100, 130)
		container.add_child(card)

		# Style based on selection
		if is_selected:
			card.modulate = Color.WHITE
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.1, 0.3, 0.1)
			style.border_width_bottom = 2
			style.border_color = Color.GREEN
			card.add_theme_stylebox_override("panel", style)
		else:
			card.modulate = Color(0.5, 0.5, 0.5)  # Dimmed

		# Interact
		card.gui_input.connect(
			func(ev):
				if (
					ev is InputEventMouseButton
					and ev.pressed
					and ev.button_index == MOUSE_BUTTON_LEFT
				):
					_toggle_unit_selection(idx)
		)

		var vbox = VBoxContainer.new()
		card.add_child(vbox)

		# Portrait
		var port = portrait_script.new()
		port.custom_minimum_size = Vector2(90, 90)
		vbox.add_child(port)
		port.update_portrait(unit_data)

		# Name
		var lbl = Label.new()
		lbl.text = unit_data["name"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.clip_text = true
		vbox.add_child(lbl)

	# Update Label
	var lbl = find_child("SquadLabel", true, false)
	if lbl:
		lbl.text = (
			"DEPLOYMENT SQUAD (" + str(selected_indices.size()) + "/" + str(max_squad_size) + ")"
		)


func _toggle_unit_selection(idx):
	if selected_indices.has(idx):
		selected_indices.erase(idx)
	else:
		if selected_indices.size() < max_squad_size:
			selected_indices.append(idx)
		else:
			print("Squad Full!")
			# Feedback?

	_refresh_squad_preview()


func _on_scan_pressed():
	# Clear previous
	for child in mission_container.get_children():
		child.queue_free()

	# Check Doomsday Protocol
	if game_manager and game_manager.invasion_progress >= 100:
		_create_base_defense_mission()
		return

	# Generate 3 Missions
	for i in range(3):
		var mission = _generate_random_mission()
		_create_mission_card(mission)


func _create_base_defense_mission():
	var m = MissionData.new()
	m.mission_name = "BASE DEFENSE"
	m.description = "THEY ARE HERE. PROTECT THE GOLDEN HYDRANT AT ALL COSTS."
	m.difficulty_rating = 5  # MAX
	m.reward_kibble = 500
	m.map_scene_path = "res://scenes/maps/BaseDefenseMap.tscn"  # Or logic to gen base map

	var card = Button.new()
	card.custom_minimum_size = Vector2(300, 140)
	card.modulate = Color.GOLD
	card.text = ">>> DEFEND THE BASE <<<\n\nSURVIVE 10 WAVES\nREWARD: VICTORY"
	card.pressed.connect(func(): _on_mission_selected(m))
	mission_container.add_child(card)


func _generate_random_mission() -> MissionData:
	var m = MissionData.new()
	var locations = ["Park", "Kitchen", "Backyard", "Basement"]
	var types = ["Patrol", "Assault", "Defense"]

	m.mission_name = locations.pick_random() + " " + types.pick_random()
	m.difficulty_rating = (randi() % 3) + 1  # 1-3
	m.reward_kibble = m.difficulty_rating * 25 + (randi() % 20)

	# Set description based on flavor
	match m.difficulty_rating:
		1:
			m.description = "Low activity detected. Standard bark protocol."
		2:
			m.description = "Suspicious movement. Bring treats."
		3:
			m.description = "Full scale invasion! Maximum borkdrive!"

	return m


func _create_mission_card(mission: MissionData):
	var card = Button.new()
	card.custom_minimum_size = Vector2(120, 140)

	# Difficulty Color
	var color_code = Color.GREEN
	if mission.difficulty_rating == 2:
		color_code = Color.YELLOW
	if mission.difficulty_rating == 3:
		color_code = Color.RED

	card.modulate = color_code
	card.text = (
		mission.mission_name
		+ "\n\n"
		+ "Diff: "
		+ str(mission.difficulty_rating)
		+ "\n"
		+ "Reward: "
		+ str(mission.reward_kibble)
	)

	card.pressed.connect(func(): _on_mission_selected(mission))
	mission_container.add_child(card)


func _on_mission_selected(mission: MissionData):
	if game_manager:
		if selected_indices.is_empty():
			print("Select at least one unit!")
			return

		var squad_data = []
		for idx in selected_indices:
			squad_data.append(game_manager.roster[idx])

		game_manager.start_mission(mission, squad_data)
