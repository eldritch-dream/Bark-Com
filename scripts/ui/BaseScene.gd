extends Control
class_name BaseScene

# Represents the UI for the Base
# In a real scene, this would manage Control nodes.
# Here we simulate the interaction logic via console commands/simulated clicks.

var game_manager: _GameManager

# Visual Nodes
var ui_container: Control
var output_label: RichTextLabel
var input_field: LineEdit
var kibble_label: Label
# var mission_select_ui: MissionSelectUI # Deprecated

var active_mission_node: Node = null
var content_area: VBoxContainer


func _process(_delta):
	# Check if mission ended (node freed)
	if not ui_container.visible and not is_instance_valid(active_mission_node):
		_log("Mission Ended. Welcome back.")
		_create_terminal_view() # Reset to Home to ensure fresh data and clean state
		_update_header() # Refresh Kibble/Stuffs
		ui_container.visible = true
		input_field.grab_focus()

		# Audio: Return to Base Theme
		if game_manager.audio_manager:
			game_manager.audio_manager.play_music("Theme_Base")


func _ready():
	_initialize_managers()
	_setup_base_settings()
	_setup_ui()
	_connect_signals()
	_load_initial_state()


func _initialize_managers():
	# Ensure GameManager exists (Manual simulation of Singleton)
	game_manager = GameManager


func _setup_base_settings():
	# CRITICAL FIX: BaseScene is a Control (UI), so it blocks mouse input by default.
	# We must let input PASS THROUGH to the 3D world (Main.gd / CameraController).
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Audio: Base Theme
	if game_manager.audio_manager:
		game_manager.audio_manager.play_music("Theme_Base")


func _connect_signals():
	SignalBus.on_kibble_changed.connect(_on_kibble_changed)
	SignalBus.on_unit_recruited.connect(_on_unit_recruited)
	SignalBus.on_mission_selected.connect(_on_mission_start_signal)


func _load_initial_state():
	# Initial UI Update
	_on_kibble_changed(game_manager.kibble)

	# Auto-Load or Help
	# Auto-Load or Help
	if not game_manager.session_initialized and game_manager.has_save_file():
		game_manager.load_game()
		game_manager.session_initialized = true
		_log("--- SESSION RESTORED FROM AUTO-SAVE ---")
		_log("Welcome back, Commander.")
		_log("(Type 'help' for commands)")
	elif game_manager.session_initialized:
		_log("--- READY FOR DEPLOYMENT ---")
	else:
		# Critical Bug Fix #1: Auto-initialize New Game data if no save exists.
		# This prevents the "Empty Roster" state on first run.
		game_manager.new_game()
		
		# Optional: Auto-save immediately so they don't lose the init state?
		# game_manager.save_game() 
		
		_show_welcome_message()
		_log("New Campaign Initialized.")


func _show_welcome_message():
	_log("--- WELCOME TO THE DOGHOUSE ---")
	_log("COMMANDS:")
	_log(" 1. [roster] : View Barracks")
	_log(" 2. [shop]   : Visit Shop")
	_log(" 3. [deploy] : Start Mission")
	_log(" 4. [stash]  : View Inventory")
	_log(" 5. [save]   : Save Game")
	_log(" 6. [load]   : Load Game")
	_log(" 7. [new]    : New Game")
	_log("(Type command below and press Enter)")


func _setup_ui():
	# Container for toggling visibility
	ui_container = Control.new()
	ui_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui_container)

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1)  # Dark Grey
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_container.add_child(bg)

	# TAGLINE (Main Menu)
	var tagline = Label.new()
	tagline.text = '"Let\'s go for walkies... in HELL"'
	tagline.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))  # Blood Red
	tagline.add_theme_font_size_override("font_size", 18)
	tagline.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tagline.offset_top = 20  # Padding
	ui_container.add_child(tagline)

	# 1. Main Layout: VBox
	var main_layout = VBoxContainer.new()
	main_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Margins
	main_layout.offset_left = 10
	main_layout.offset_top = 10
	main_layout.offset_right = -10
	main_layout.offset_bottom = -10
	ui_container.add_child(main_layout)

	# 2. HEADER
	var header = _create_header()
	main_layout.add_child(header)

	main_layout.add_child(HSeparator.new())

	# 3. CONTENT AREA (Stack)
	content_area = VBoxContainer.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_layout.add_child(content_area)

	_create_terminal_view()

	main_layout.add_child(HSeparator.new())

	# 4. NAVIGATION BAR
	var navbar = _create_navbar()
	main_layout.add_child(navbar)

	# System Button (Append to navbar now or passed?)
	# Navbar is returned, so we can append here or inside _create_navbar.
	# But _create_navbar is modular. Let's append System here?
	# Actually, best to pass navbar to a helper or just add it here if main_layout is here?
	# Let's add System Menu to Navbar NOW.

	var sys_btn = MenuButton.new()
	sys_btn.text = "SYSTEM"
	sys_btn.custom_minimum_size = Vector2(100, 50)
	var popup = sys_btn.get_popup()
	popup.add_item("Save Game", 0)
	popup.add_item("Load Game", 1)
	popup.add_item("New Game", 2)
	popup.id_pressed.connect(_on_system_menu_item)
	navbar.add_child(sys_btn)

	_setup_settings_panel()
	_setup_settings_panel()
	# _setup_mission_control() # Removed old popover setup

	# Input Field Setup
	input_field = LineEdit.new()
	input_field.placeholder_text = "Terminal Command..."
	input_field.text_submitted.connect(_on_text_submitted)
	main_layout.add_child(input_field)


func _create_header() -> HBoxContainer:
	var header = HBoxContainer.new()
	header.custom_minimum_size.y = 40

	kibble_label = Label.new()
	kibble_label.text = "Kibble: --"
	kibble_label.add_theme_font_size_override("font_size", 24)
	header.add_child(kibble_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var help_btn = Button.new()
	help_btn.text = "HELP"
	help_btn.pressed.connect(_show_tutorial)
	header.add_child(help_btn)

	var opt_btn = Button.new()
	opt_btn.text = "OPTIONS"
	opt_btn.pressed.connect(_on_options_pressed)
	header.add_child(opt_btn)
	return header


func _create_terminal_view():
	_clear_content()
	# Default View: Terminal
	output_label = RichTextLabel.new()
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_label.scroll_following = true
	output_label.bbcode_enabled = true
	output_label.text = "System Initialized.\n"
	content_area.add_child(output_label)


func _create_navbar() -> HBoxContainer:
	var navbar = HBoxContainer.new()
	navbar.custom_minimum_size.y = 60
	navbar.alignment = BoxContainer.ALIGNMENT_CENTER

	_create_nav_btn(navbar, "TERMINAL", _show_terminal)
	_create_nav_btn(navbar, "BARRACKS", _show_roster)
	_create_nav_btn(navbar, "QUARTERMASTER", _show_shop)
	_create_nav_btn(navbar, "STASH", _show_inventory)
	_create_nav_btn(navbar, "THERAPY", _show_therapy)
	_create_nav_btn(navbar, "MEMORIAL", _show_memorial)
	_create_nav_btn(navbar, "DEPLOY", _show_mission_control)
	return navbar


var settings_panel: PanelContainer
var music_slider: HSlider
var sfx_slider: HSlider


func _setup_settings_panel():
	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.visible = false
	ui_container.add_child(settings_panel)

	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 200)
	settings_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "AUDIO SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Music Slider
	vbox.add_child(Label.new())
	var m_label = Label.new()
	m_label.text = "Music Volume"
	vbox.add_child(m_label)

	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = game_manager.settings["music_vol"]  # Init from persisted
	music_slider.value_changed.connect(_on_music_volume_changed)
	vbox.add_child(music_slider)

	# SFX Slider
	vbox.add_child(Label.new())
	var s_label = Label.new()
	s_label.text = "SFX Volume"
	vbox.add_child(s_label)

	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = game_manager.settings["sfx_vol"]  # Init from persisted
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	vbox.add_child(sfx_slider)

	vbox.add_child(HSeparator.new())

	# Fullscreen Toggle
	var fs_check = CheckBox.new()
	fs_check.text = "Fullscreen"
	# Check current state
	var is_fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_check.button_pressed = is_fs
	fs_check.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(fs_check)

	vbox.add_child(HSeparator.new())

	# Close Button
	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.pressed.connect(func(): settings_panel.visible = false)
	vbox.add_child(close_btn)


func _on_music_volume_changed(val: float):
	if game_manager:
		game_manager.settings["music_vol"] = val
		game_manager._apply_audio_settings()


func _on_sfx_volume_changed(val: float):
	if game_manager:
		game_manager.settings["sfx_vol"] = val
		game_manager._apply_audio_settings()


func _on_fullscreen_toggled(toggled_on: bool):
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# Signal Callbacks
func _on_kibble_changed(amount: int):
	if kibble_label:
		kibble_label.text = "Kibble: " + str(amount) + " Kib"


func _on_unit_recruited(unit_data: Dictionary):
	_log("recruitment_center > New recruit processed: " + unit_data["name"])
	_show_roster()
	_update_header()


func _on_mission_start_signal(_mission_name: String):
	_start_mission()


func _on_options_pressed():
	settings_panel.visible = true
	if game_manager and music_slider and sfx_slider:
		music_slider.value = game_manager.settings["music_vol"]
		sfx_slider.value = game_manager.settings["sfx_vol"]


# Input Handlers
func handle_input(command: String):
	# Normalize
	var cmd = command.to_lower().strip_edges()

	if cmd == "1" or cmd == "roster":
		_show_roster()
	elif cmd == "2" or cmd == "shop":
		_show_shop()
	elif cmd == "3" or cmd == "deploy":
		_start_mission()
	elif cmd == "4" or cmd == "inventory" or cmd == "stash":
		_show_inventory()
	elif cmd.begins_with("buy "):
		var index_str = cmd.substr(4)
		if index_str.is_valid_int():
			_buy_item(index_str.to_int())
		else:
			_log("Invalid Index. Usage: buy <number>")
	elif cmd.begins_with("equip "):
		# Usage: equip Barnaby 0
		var parts = command.split(" ", false)
		if parts.size() >= 3:
			var corgi_name = parts[1]
			var inv_idx = parts[2].to_int()
			_equip_item(corgi_name, inv_idx)
		else:
			_log("Usage: equip <CorgiName> <InventoryIndex>")
	elif cmd == "save":
		game_manager.save_game()
		_log("Game Saved.")
	elif cmd == "load":
		game_manager.load_game()
		_log("Game Loaded.")
	elif cmd == "new":
		game_manager.new_game()
		_log("New Game Started. Good luck!")
	elif cmd == "doomsday":
		game_manager.debug_fill_invasion_meter()
		_log("Invasion Meter set to 100%.")
	elif cmd == "busty":
		game_manager.settings["shop_skin"] = "sexy"
		_log("Quartermaster style updated (v4)... Use [shop] to view.")
		game_manager._apply_audio_settings() 
		GameManager.save_game()
	elif cmd == "bustier":
		game_manager.settings["shop_skin"] = "ultra"
		_log("Quartermaster style updated (v7)... Use [shop] to view.")
		game_manager._apply_audio_settings()
		GameManager.save_game()
	elif cmd == "normal":
		game_manager.settings["shop_skin"] = "default"
		_log("Quartermaster style restored (v3).")
		GameManager.save_game()
	elif cmd == "rich":
		game_manager.kibble += 1000000
		SignalBus.on_kibble_changed.emit(game_manager.kibble)
		game_manager.save_game()
		_log("Kibble Reserves boosted to 1,000,000! Enjoy the shopping spree.")
	elif cmd == "acidsplosion":
		game_manager.debug_scenario = "acidsplosion"
		_start_mission()
		_log("Initializing Acidsplosion Test Scenario...")
	elif cmd == "lootapalooza":
		game_manager.debug_scenario = "lootapalooza"
		_start_mission()
		_log("Initializing Lootapalooza: All Loot, No Bite.")
	elif cmd == "help" or cmd == "clear":
		output_label.text = ""
		_log("Commands: roster, shop, deploy, stash, save, load, new, buy <n>, equip <name> <n>")
	else:
		_log("Unknown command. Type 'help'.")


func _on_text_submitted(text: String):
	input_field.clear()
	_log("> " + text)
	handle_input(text)


func _log(text: String, color: String = ""):
	print(text)  # Keep console log too
	var final_text = text
	if color != "":
		final_text = "[color=" + color + "]" + text + "[/color]"
	
	if output_label:
		output_label.append_text(final_text + "\n")


# --- UI HELPERS ---
func _create_nav_btn(parent, text, callback):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 50)
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _clear_content():
	for child in content_area.get_children():
		child.visible = false  # Just hide generic children?
		# Actually, output_label is a child. We want to keep it, but hide it if not terminal.
		if child == output_label:
			child.visible = false
		else:
			child.queue_free()  # Destroy dynamic views


func _show_terminal():
	_clear_content()
	output_label.visible = true
	input_field.visible = true
	_log("Terminal Active.")


func _on_system_menu_item(id: int):
	match id:
		0:
			handle_input("save")
		1:
			handle_input("load")
		2:
			handle_input("new")


func _start_mission():
	_log("\n>>> DEPLOYING TO NEIGHBORHOOD >>>")
	_log("(Scene Switch triggered -> Loading Main.gd logic)")

	# Hide Base UI
	ui_container.visible = false

	# Instance Main
	var main_scene = load("res://scripts/core/Main.gd").new()
	main_scene.name = "Main"
	add_child(main_scene)
	active_mission_node = main_scene
	# Main._ready() will trigger generation.


func _show_roster():
	_clear_content()
	input_field.visible = false

	var title = Label.new()
	title.text = "BARRACKS (The Bed)"
	title.add_theme_font_size_override("font_size", 24)
	content_area.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for c in game_manager.get_roster():
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(250, 100)
		grid.add_child(card)

		# Visual Layout: [Portrait] [Info]
		var hbox = HBoxContainer.new()
		card.add_child(hbox)

		# PORTRAIT
		var portrait_script = load("res://scripts/ui/UnitPortraitConfig.gd")
		if portrait_script:
			var portrait = portrait_script.new()
			# portrait.custom_minimum_size assigned in _ready
			hbox.add_child(portrait)
			# We must wait for ready? or call update manually?
			# Since we just added it, _ready runs.
			# But we need to pass data.
			portrait.update_portrait(c)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(vbox)

		var name_lbl = Label.new()
		var cls_name = c.get("class", "Recruit")
		name_lbl.text = c["name"] + " [" + cls_name + "] (Lvl " + str(c["level"]) + ")"
		vbox.add_child(name_lbl)

		var status_lbl = Label.new()
		var status_txt = "Ready" if c["status"] == "Ready" else "Resting"
		status_lbl.text = "Status: " + status_txt
		status_lbl.modulate = Color.GREEN if c["status"] == "Ready" else Color.YELLOW
		vbox.add_child(status_lbl)

		# Stats (HP & Sanity)
		var max_hp = game_manager.calculate_max_hp(c)
		var hp_val = c.get("hp", max_hp)  # Default to Max if not set (fresh recruit)
		var san_val = int(c.get("sanity", 100))
		var hp_txt = "HP: " + str(hp_val) + "/" + str(max_hp)
		if san_val < 100:
			hp_txt += " | SAN: " + str(san_val) + "%"
		else:
			hp_txt += " | SAN: 100%"

		var stat_lbl = Label.new()
		stat_lbl.text = hp_txt
		# Color code low sanity
		if san_val < 50:
			stat_lbl.modulate = Color.VIOLET
		vbox.add_child(stat_lbl)

		var weapon_name = "Default Bark"
		if c.get("primary_weapon") and c["primary_weapon"] != null:
			weapon_name = c["primary_weapon"].display_name
		var w_lbl = Label.new()
		w_lbl.text = "Wpn: " + weapon_name
		vbox.add_child(w_lbl)

		# INVENTORY DISPLAY
		var inv_items = c.get("inventory", [])
		var item_names = []
		if not inv_items.is_empty():
			for item in inv_items:
				if item:
					item_names.append(item.display_name)
		
		# Now check actual items found
		if item_names.size() > 0:
			var inv_text = "Items: " + ", ".join(item_names)
			var inv_lbl = Label.new()
			inv_lbl.text = inv_text
			inv_lbl.add_theme_font_size_override("font_size", 12)
			inv_lbl.modulate = Color(0.7, 0.9, 1.0) # Light cyan
			vbox.add_child(inv_lbl)
		else:
			var inv_lbl = Label.new()
			inv_lbl.text = "Items: (Empty)"
			inv_lbl.add_theme_font_size_override("font_size", 12)
			inv_lbl.modulate = Color(0.5, 0.5, 0.5) # Gray
			vbox.add_child(inv_lbl)

		# PROMOTION CHECK
		var xp = c.get("xp", 0)
		var lvl = c.get("level", 1)
		# Simple Threshold: Level * 100 XP needed for NEXT level
		var needed = lvl * 100

		if xp >= needed:
			var promo_btn = Button.new()
			promo_btn.text = "PROMOTE! (Rank " + str(lvl + 1) + ")"
			promo_btn.modulate = Color.YELLOW
			promo_btn.pressed.connect(func(): _start_promotion(c))
			vbox.add_child(promo_btn)
		else:
			var xp_lbl = Label.new()
			xp_lbl.text = "XP: " + str(xp) + " / " + str(needed)
			xp_lbl.add_theme_font_size_override("font_size", 12)
			vbox.add_child(xp_lbl)

		# RELATIONSHIPS
		var bonds_found = false
		var bond_text = ""
		for other in game_manager.get_roster():
			if other["name"] == c["name"]:
				continue
			var bond_lvl = game_manager.get_bond_level(c["name"], other["name"])
			if bond_lvl > 0:
				if not bonds_found:
					bonds_found = true
					bond_text = "❤ Bonds:"

				var rank_name = "Buddy"
				if bond_lvl == 2:
					rank_name = "Packmate"
				elif bond_lvl == 3:
					rank_name = "Soul Pup"

				bond_text += "\n  - " + other["name"] + " (" + rank_name + ")"

		if bonds_found:
			var bond_lbl = Label.new()
			bond_lbl.text = bond_text
			bond_lbl.modulate = Color(1, 0.5, 0.5)  # Pinkish
			bond_lbl.add_theme_font_size_override("font_size", 12)
			vbox.add_child(bond_lbl)

		# CUSTOMIZATION BUTTON
		var look_btn = Button.new()
		look_btn.text = "CUSTOMIZE LOOK"
		look_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		look_btn.pressed.connect(func(): _show_customization_selector(c))
		vbox.add_child(look_btn)

	# RECRUITMENT BUTTON
	content_area.add_child(HSeparator.new())
	var recruit_btn = Button.new()
	var cost = 50
	if game_manager: cost = game_manager.RECRUIT_COST
	recruit_btn.text = "RECRUIT NEW DOG (" + str(cost) + " Kib)"
	recruit_btn.custom_minimum_size = Vector2(200, 50)
	recruit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	recruit_btn.pressed.connect(_on_recruit_pressed)
	content_area.add_child(recruit_btn)


func _on_recruit_pressed():
	if game_manager:
		_recruit_unit(game_manager.RECRUIT_COST)
	else:
		_recruit_unit(50)


func _recruit_unit(cost):
	if game_manager.recruit_new_dog(cost):
		_log("Recruited new dog!")
		_show_roster()
		# _update_header() # Assuming this is handled by signal
	else:
		_log("Not enough Kibble!")


func _show_shop():
	_clear_content()
	input_field.visible = false
	
	# Root HBox for Side-by-Side Layout
	var shop_root = HBoxContainer.new()
	shop_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.add_child(shop_root)
	
	# --- LEFT: Large Portrait ---
	var portrait_container = PanelContainer.new()
	# Fixed width container
	portrait_container.custom_minimum_size = Vector2(350, 0)
	portrait_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_root.add_child(portrait_container)
	
	# Use TextureRect for proper aspect ratio handling
	var portrait_rect = TextureRect.new()
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_container.add_child(portrait_rect)
	
	# Load Portrait Variant
	var art_path = "res://assets/images/QuarterMaster_v3.jpg"
	var skin = game_manager.settings.get("shop_skin", "default")
	
	if skin == "sexy":
		art_path = "res://assets/images/QuarterMaster_v4.jpg"
	elif skin == "ultra":
		art_path = "res://assets/images/QuarterMaster_v7.jpg"
	var tex = null
	
	if ResourceLoader.exists(art_path):
		tex = load(art_path)
		
	if not tex:
		# Fallback: Load from disk (e.g. if not imported yet)
		var img = Image.new()
		var abs_path = ProjectSettings.globalize_path(art_path)
		print("DEBUG: Loading portrait from: ", abs_path)
		var err = img.load(abs_path)
		if err == OK:
			tex = ImageTexture.create_from_image(img)
		else:
			print("DEBUG: Failed to load image. Error: ", err)
			
	if tex:
		portrait_rect.texture = tex
	else:
		# Fallback debug
		var debug_rect = ColorRect.new()
		debug_rect.color = Color.DARK_SLATE_GRAY
		# Ensure it has size
		debug_rect.custom_minimum_size = Vector2(350, 500)
		portrait_container.add_child(debug_rect)
		var debug_lbl = Label.new()
		debug_lbl.text = "IMG LOAD FAIL"
		portrait_container.add_child(debug_lbl)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 20
	shop_root.add_child(spacer)

	# --- RIGHT: Shop Content ---
	var right_col = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_root.add_child(right_col)
	
	var title = Label.new()
	title.text = "QUARTERMASTER"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.GOLD)
	right_col.add_child(title)

	var flav = Label.new()
	flav.text = '"Make sure you\'re well fed out there, sweetie."'
	flav.add_theme_font_size_override("font_size", 16)
	flav.modulate = Color(0.8, 0.8, 0.8)
	right_col.add_child(flav)
	
	right_col.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_child(scroll)

	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_vbox)

	var weapons = []
	var consumables = []
	var idx = 0
	for item in game_manager.shop_stock:
		if item is WeaponData:
			weapons.append({"item": item, "index": idx})
		else:
			consumables.append({"item": item, "index": idx})
		idx += 1

	if weapons.size() > 0:
		var w_lbl = Label.new()
		w_lbl.text = "WEAPONS"
		w_lbl.add_theme_font_size_override("font_size", 20)
		w_lbl.add_theme_color_override("font_color", Color.LIGHT_CORAL)
		content_vbox.add_child(w_lbl)
		content_vbox.add_child(HSeparator.new())
		for entry in weapons:
			_create_shop_row(content_vbox, entry["item"], entry["index"])
		var s = Control.new()
		s.custom_minimum_size.y = 20
		content_vbox.add_child(s)

	if consumables.size() > 0:
		var c_lbl = Label.new()
		c_lbl.text = "CONSUMABLES"
		c_lbl.add_theme_font_size_override("font_size", 20)
		c_lbl.add_theme_color_override("font_color", Color.LIGHT_GREEN)
		content_vbox.add_child(c_lbl)
		content_vbox.add_child(HSeparator.new())
		for entry in consumables:
			_create_shop_row(content_vbox, entry["item"], entry["index"])


func _create_shop_row(parent_node, item, index):
	var panel = _create_styled_panel_for_list()
	parent_node.add_child(panel)
	# parent_node.add_child(HSeparator.new()) # Panel has visual separation? Or use HSeparator between?
	# Let's clean up separators. Panel + Spacer is better.
	
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	# Icon (Placeholder)
	# var icon = TextureRect.new() ...

	# Info
	# Name / Cost
	var v_info = VBoxContainer.new()
	v_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v_info)

	var info = Label.new()
	info.text = item.display_name + " (" + str(item.cost) + " Kib)"
	v_info.add_child(info)
	
	if "description" in item and item.description != "":
		var desc = Label.new()
		desc.text = item.description
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v_info.add_child(desc)
	
	var buy_btn = Button.new()
	buy_btn.text = "BUY"
	buy_btn.pressed.connect(func(): _buy_item(index))
	row.add_child(buy_btn)


func _create_styled_panel_for_list() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	# Hover Modulate (Glow)
	panel.mouse_entered.connect(
		func():
			var tween = create_tween()
			tween.tween_property(panel, "modulate", Color(1.2, 1.2, 1.2), 0.1)
	)
	panel.mouse_exited.connect(
		func():
			var tween = create_tween()
			tween.tween_property(panel, "modulate", Color.WHITE, 0.1)
	)

	# Click SFX (Generic)
	panel.gui_input.connect(
		func(event):
			if (
				event is InputEventMouseButton
				and event.pressed
				and event.button_index == MOUSE_BUTTON_LEFT
			):
				if GameManager and GameManager.audio_manager:
					GameManager.audio_manager.play_sfx("SFX_Menu")
	)
	return panel


func _show_inventory(status_msg: String = "", status_color: String = ""):
	_clear_content()
	input_field.visible = false

	var title = Label.new()
	title.text = "STASH (Inventory)"
	title.add_theme_font_size_override("font_size", 24)
	content_area.add_child(title)

	if status_msg != "":
		var s_lbl = RichTextLabel.new()
		s_lbl.text = "[center][color=" + status_color + "]" + status_msg + "[/color][/center]"
		s_lbl.bbcode_enabled = true
		s_lbl.fit_content = true
		s_lbl.custom_minimum_size = Vector2(0, 30)
		content_area.add_child(s_lbl)
		content_area.add_child(HSeparator.new())

	if game_manager.inventory.is_empty():
		var l = Label.new()
		l.text = "(Empty)"
		content_area.add_child(l)
		return

	var list = VBoxContainer.new()
	content_area.add_child(list)

	var idx = 0
	for item in game_manager.inventory:
		var panel = _create_styled_panel_for_list()
		list.add_child(panel)
		list.add_child(HSeparator.new())

		var row = HBoxContainer.new()
		panel.add_child(row)

		var lbl = Label.new()
		lbl.text = item.display_name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		# Equip Button
		if item is WeaponData or item is ConsumableData:
			var equip_btn = Button.new()
			equip_btn.text = "EQUIP"
			var current_idx = idx
			equip_btn.pressed.connect(func(): _show_equip_selector(current_idx))
			row.add_child(equip_btn)

		idx += 1


func _show_equip_selector(item_idx: int):
	_clear_content()

	var item = game_manager.inventory[item_idx]

	var title = Label.new()
	title.text = "Equip " + item.display_name + " to whom?"
	title.add_theme_font_size_override("font_size", 24)
	content_area.add_child(title)

	var grid = GridContainer.new()
	grid.columns = 2
	content_area.add_child(grid)

	for c in game_manager.get_roster():
		var btn = Button.new()
		btn.text = c["name"] + " (Lvl " + str(c["level"]) + ")"
		btn.custom_minimum_size = Vector2(200, 60)
		btn.pressed.connect(
			func():
				var success = _equip_item(c["name"], item_idx)
				var msg = "Equipped Successfully!"
				var col = "green"
				if not success:
					msg = "Equip Failed (Inventory Full)"
					col = "red"
				_show_inventory(msg, col)  # Return to stash with message
		)
		grid.add_child(btn)

	var cancel = Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(_show_inventory)
	content_area.add_child(cancel)


func _buy_item(index: int):
	# Capture print from GM? GM prints to console.
	# Ideally GM should return bool/string.
	# For now, we trust GM console logs, but let's add UI feedback
	var success = game_manager.buy_item(index)
	if success:
		_log("Purchase Successful!")
	else:
		_log("Purchase Failed (Not enough kibble?)")


func _equip_item(corgi_name: String, idx: int) -> bool:
	var success = game_manager.equip_weapon(corgi_name, idx)
	if success:
		_log("Equipped successfully!", "green")
	else:
		_log("Equip Failed. (Inventory Full)", "red")
	return success


func _start_promotion(corgi_data: Dictionary):
	# 1. Load Data
	var cls_name = corgi_data.get("class", "Recruit")
	var path = "res://assets/data/classes/" + cls_name + "Data.tres"
	var class_data = null
	if ResourceLoader.exists(path):
		class_data = load(path)

	if not class_data:
		_log("No Class Data found for " + cls_name)
		# Just simple Stat Level Up? allow it?
		corgi_data["level"] += 1
		corgi_data["xp"] -= (corgi_data["level"] - 1) * 100  # Reset XP or keep accumulated? XCOM keeps accumulated total usually.
		# But here 'needed' was current_level * 100.
		# Let's subtract cost? Or just increment level is enough if Next Needed increases.
		# Needed = lvl * 100. So Lvl 1->2 needs 100. Lvl 2->3 needs 200. Total 300.
		# If we have 150 XP. Promote to Lvl 2.
		# New needed = 200. Current 150. Need 50 more. Correct.
		_log("Promoted to Level " + str(corgi_data["level"]) + "!")
		_show_roster()
		return

	# 2. Check Tree
	var next_rank = corgi_data["level"] + 1
	var choices = class_data.rank_tree.get(next_rank, [])

	if choices.size() > 0:
		# Show Selection UI
		var popup = load("res://scripts/ui/PerkSelectionUI.gd").new()
		ui_container.add_child(popup)
		popup.set_anchors_preset(Control.PRESET_CENTER)
		popup.show_options(next_rank, choices)

		popup.perk_selected.connect(func(talent): _apply_promotion(corgi_data, talent))
	else:
		# Just Stats
		_apply_promotion(corgi_data, null)


func _apply_promotion(corgi_data: Dictionary, talent: TalentNode):
	corgi_data["level"] += 1
	if talent:
		if not corgi_data.has("unlocked_talents"):
			corgi_data["unlocked_talents"] = []
		corgi_data["unlocked_talents"].append(talent.resource_path)  # Store Path or ID? Path is safer for loading.
		_log("Promoted! Learned: " + talent.display_name)
	else:
		_log("Promoted to Rank " + str(corgi_data["level"]))

	# Apply Stat Growth (Permanent roster stat boost?)
	# Our Unit.gd applies base_stats + talents dynamically.
	# But base HP growth?
	# We can store "bonus_hp" in roster dict?
	# Or just rely on Level to scale stats in Unit.gd?
	# Current Unit.gd uses base_stats ONLY from Class.
	# We should update Unit.gd to scale with Level too.
	# For now, let's just save.
	game_manager.save_game()
	_show_roster()


# --- THERAPY ---
func _show_therapy():
	print("DEBUG: _show_therapy called")
	_clear_content()
	output_label.visible = false

	var h = HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Ensure it expands vertically
	content_area.add_child(h)

	print("DEBUG: Therapy HBox added. Roster size: ", GameManager.roster.size())

	# List of Wounded/Insane Units
	var list_panel = PanelContainer.new()
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(list_panel)

	var scroll = ScrollContainer.new()
	list_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var label = Label.new()
	label.text = "PATIENTS (Sanity < 100)"
	vbox.add_child(label)

	for unit_data in GameManager.roster:
		var san = int(unit_data.get("sanity", 100))
		var max_san = 100

		# Styled Panel
		var panel = _create_styled_panel_for_list()
		vbox.add_child(panel)
		vbox.add_child(HSeparator.new())

		var row = HBoxContainer.new()
		panel.add_child(row)

		# Name
		var name_lbl = Label.new()
		name_lbl.text = (
			unit_data.get("name", "Unknown") + " (Lvl " + str(unit_data.get("level", 1)) + ")"
		)
		name_lbl.custom_minimum_size = Vector2(200, 0)
		row.add_child(name_lbl)

		# Sanity Bar
		var bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(300, 20)
		bar.max_value = max_san
		bar.value = san
		# Style: Violet
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color.BLUE_VIOLET
		bar.add_theme_stylebox_override("fill", sb)
		bar.show_percentage = false  # Disable default text to prevent overlap

		# Text Overlay
		var overlay = Label.new()
		overlay.text = str(san) + "/" + str(max_san)
		overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar.add_child(overlay)

		row.add_child(bar)

		# Treat Button
		if san < max_san:
			var btn = Button.new()
			btn.text = "Treat (20 Kib)"
			btn.pressed.connect(func(): _treat_unit(unit_data))
			row.add_child(btn)
		else:
			var status = Label.new()
			status.text = "Healthy"
			status.modulate = Color.GREEN
			row.add_child(status)


func _treat_unit(unit_data):
	var cost = 20
	if GameManager.kibble >= cost:
		GameManager.kibble -= cost
		unit_data["sanity"] = min(100, unit_data.get("sanity", 0) + 50)
		_log("Treated " + unit_data["name"] + ". Recovered 50 Sanity.")
		game_manager.save_game()

		# Refresh UI
		_show_therapy()
		_update_header()
	else:
		_log("Not enough Kibble! Need " + str(cost))


func _show_mission_control():
	_clear_content()
	input_field.visible = false

	var control_script = load("res://scripts/ui/MissionControlTab.gd")
	if control_script:
		var tab = control_script.new()
		tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_area.add_child(tab)
		tab.initialize(game_manager)


func _show_tutorial():
	_clear_content()
	input_field.visible = false
	
	var title = Label.new()
	title.text = "FIELD MANUAL"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_area.add_child(title)
	content_area.add_child(HSeparator.new())
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	
	# CONTROLS SECTION
	var c_lbl = Label.new()
	c_lbl.text = "TACTICAL CONTROLS"
	c_lbl.add_theme_color_override("font_color", Color.GOLD)
	c_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(c_lbl)
	
	var controls = [
		"LEFT CLICK: Select Unit / Move / Interact",
		"RIGHT CLICK: Cancel Action",
		"WASD / ARROWS: Pan Camera",
		"Q / E: Rotate Camera",
		"SCROLL WHEEL: Zoom Camera"
	]
	
	for c in controls:
		var l = Label.new()
		l.text = " • " + c
		vbox.add_child(l)
		
	vbox.add_child(HSeparator.new())
	
	# GAME LOOP SECTION
	var g_lbl = Label.new()
	g_lbl.text = "OPERATIONAL GUIDE"
	g_lbl.add_theme_color_override("font_color", Color.CYAN)
	g_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(g_lbl)
	
	var guide = """
The Golden Hydrant is under siege by Eldritch Monsters.
Your duty is to command the Bark-Commandos to hold the line.

1. DEPLOY: Choosing missions wisely.
   - [Retrieval]: Secure Treat Bags for supplies.
   - [Hacker]: Corrupt their terminals.
   - [Deathmatch]: Clear the sector.
   
2. PREPARE: Use Kibble to recruit new specialized dogs and buy gear.
   - Visit the [Quartermaster] for weapons and grenades.
   - Visit [Therapy] if your dogs are losing their minds (Low Sanity).
   
3. DEFEND: The Eldritch Invasion meter fills over time.
   - When it hits 100%, they will attack the Base.
   - You MUST be ready.
   
Good luck, Commander.
"""
	var g_text = Label.new()
	g_text.text = guide
	g_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(g_text)


# --- COSMETIC UI ---
func _show_customization_selector(unit_data):
	_clear_content()
	input_field.visible = false

	var title = Label.new()
	title.text = "Fitting Room: " + unit_data["name"]
	title.add_theme_font_size_override("font_size", 24)
	content_area.add_child(title)

	# Create Mock Unit (Data only) wrapper for check
	# We need a dummy object that has 'rank_level', 'current_class_data', 'current_sanity' for the checker.
	# Or make checker static and accepting dict.
	# Actually CosmeticManager._check_requirement expects an OBJECT (Unit.gd).
	# We can't easily mock that without instancing.
	# Workaround: Manually check or adapt check_requirement to accept Dict.
	# Or instantiate a dummy unit.
	var dummy = load("res://scripts/entities/Unit.gd").new()
	dummy.rank_level = unit_data.get("level", 1)
	dummy.current_sanity = unit_data.get("sanity", 100)
	var cls_name = unit_data.get("class", "Recruit")
	# Try load class data
	var cls_path = "res://assets/data/classes/" + cls_name + "Data.tres"
	if ResourceLoader.exists(cls_path):
		dummy.current_class_data = load(cls_path)

	var all_items = CosmeticManager.get_unlocked_items(dummy)
	dummy.queue_free()  # Clean up

	var slots = ["HEAD", "BACK"]

	for slot in slots:
		var s_lbl = Label.new()
		s_lbl.text = "SLOT: " + slot
		s_lbl.add_theme_color_override("font_color", Color.CYAN)
		content_area.add_child(s_lbl)

		# Grid
		var grid = GridContainer.new()
		grid.columns = 3
		content_area.add_child(grid)

		# "None" Option
		var none_btn = Button.new()
		none_btn.text = "UNEQUIP"
		none_btn.custom_minimum_size = Vector2(100, 40)
		none_btn.pressed.connect(func(): _equip_cosmetic_data(unit_data, slot, null))
		grid.add_child(none_btn)

		for item in all_items:
			if item.slot == slot:
				var btn = Button.new()
				btn.text = item.display_name
				btn.custom_minimum_size = Vector2(100, 40)

				# Highlight if equipped
				var current = unit_data.get("cosmetics", {}).get(slot, "")
				if current == item.id:
					btn.modulate = Color.GREEN

				btn.pressed.connect(func(): _equip_cosmetic_data(unit_data, slot, item.id))
				grid.add_child(btn)

		content_area.add_child(HSeparator.new())

	var back_btn = Button.new()
	back_btn.text = "BACK TO BARRACKS"
	back_btn.pressed.connect(_show_roster)
	content_area.add_child(back_btn)


func _equip_cosmetic_data(data: Dictionary, slot: String, item_id):
	if not data.has("cosmetics"):
		data["cosmetics"] = {}

	if item_id == null:
		if data["cosmetics"].has(slot):
			data["cosmetics"].erase(slot)
			_log("Unequipped " + slot)
	else:
		data["cosmetics"][slot] = item_id
		var item = CosmeticManager.database.get(item_id)
		_log("Equipped " + item.display_name)

	game_manager.save_game()
	_show_customization_selector(data)  # Refresh UI


func _update_header():
	if GameManager:
		kibble_label.text = "Kibble: " + str(GameManager.kibble) + " Kib"


# --- MEMORIAL WALL ---
func _show_memorial():
	_clear_content()
	output_label.visible = false

	var title = Label.new()
	title.text = "THE MEMORIAL WALL"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_area.add_child(title)

	content_area.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_area.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var heroes = GameManager.fallen_heroes
	if heroes.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No fallen heroes. Long may they reign."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(1, 1, 1, 0.5)
		list.add_child(empty_lbl)
		return

	for h in heroes:
		var panel = PanelContainer.new()
		# Enable Input for Hover Events
		panel.mouse_filter = Control.MOUSE_FILTER_PASS

		# Interaction: Hover Scale
		panel.mouse_entered.connect(
			func():
				var tween = create_tween()
				tween.tween_property(panel, "scale", Vector2(1.02, 1.02), 0.1)
		)
		panel.mouse_exited.connect(
			func():
				var tween = create_tween()
				tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.1)
		)

		# Interaction: Click for Somber Bark
		panel.gui_input.connect(
			func(event):
				if (
					event is InputEventMouseButton
					and event.pressed
					and event.button_index == MOUSE_BUTTON_LEFT
				):
					if GameManager and GameManager.audio_manager:
						GameManager.audio_manager.play_sfx("SFX_Bark", 0.05, 0.7)
		)
		list.add_child(panel)

		# Divider
		list.add_child(HSeparator.new())

		var hbox = HBoxContainer.new()
		panel.add_child(hbox)

		# Portrait / Icon Placeholder
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Placeholder texture - maybe a bone or a cross?
		# icon.texture = ...
		hbox.add_child(icon)

		var info_box = VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_box)

		var name_lbl = Label.new()
		var lvl = str(h.get("level", 1))
		name_lbl.text = (
			h.get("name", "Unknown") + " (" + h.get("class", "Recruit") + " - Lvl " + lvl + ")"
		)
		name_lbl.add_theme_font_size_override("font_size", 18)
		info_box.add_child(name_lbl)

		# Perks
		var perks = h.get("perks", [])
		if not perks.is_empty():
			var p_lbl = Label.new()
			p_lbl.text = "Known for: " + ", ".join(perks)
			p_lbl.add_theme_font_size_override("font_size", 10)
			p_lbl.modulate = Color(1, 0.8, 0.4)  # Goldish
			info_box.add_child(p_lbl)

		var date_lbl = Label.new()
		date_lbl.text = "Fallen: " + h.get("date", "Unknown Date")
		date_lbl.add_theme_font_size_override("font_size", 12)
		date_lbl.modulate = Color(0.7, 0.7, 0.7)
		info_box.add_child(date_lbl)

		var cause_lbl = Label.new()
		cause_lbl.text = h.get("cause", "Unknown Causes")
		cause_lbl.modulate = Color(1, 0.5, 0.5)  # Reddish
		info_box.add_child(cause_lbl)
