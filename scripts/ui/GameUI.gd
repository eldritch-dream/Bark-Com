extends CanvasLayer
class_name GameUI

# References
var turn_manager
var selected_unit

# UI Elements
var turn_banner_overlay: ColorRect
var turn_banner_label: Label

var hp_bar: ProgressBar
var hp_label: Label
var ap_bar: ProgressBar
var ap_label: Label
var sanity_bar: ProgressBar
var sanity_label: Label

var hit_chance_panel: PanelContainer
var hit_chance_breakdown: VBoxContainer

# Restored References
var top_bar_label: Label
var unit_card_panel: PanelContainer
var unit_name_label: Label
var action_bar_container: HBoxContainer
var status_log_label: RichTextLabel
var mission_end_panel: Panel
var hit_chance_label: Label

# Phase 57: Squad List
var squad_container: VBoxContainer
var squad_frames: Array = []  # List of SquadMemberFrame

signal action_requested(action_name)
signal ability_requested(ability)
signal item_requested(item, slot_index)
signal end_turn_requested


func _setup_ui():
	# 0. ROOT CONTROL (Anchor Reference)
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through empty space
	add_child(root)

	# 1. TURN BANNER (FullScreen Overlay)
	turn_banner_overlay = ColorRect.new()
	turn_banner_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	turn_banner_overlay.color = Color(0, 0, 0, 0.0)
	turn_banner_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(turn_banner_overlay)

	turn_banner_label = Label.new()
	# Center Horizontally, start above top screen
	turn_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	turn_banner_label.text = "MISSION START"
	turn_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_banner_label.add_theme_font_size_override("font_size", 64)
	turn_banner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	turn_banner_label.add_theme_constant_override("outline_size", 10)
	turn_banner_label.modulate.a = 0.0
	turn_banner_overlay.add_child(turn_banner_label)

	# 1.5. SQUAD LIST (Left HUD)
	var squad_panel = PanelContainer.new()
	# Anchor Top Left (shifted down)
	squad_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	squad_panel.offset_left = 20
	squad_panel.offset_top = 100  # Leave room for header/terminal
	squad_panel.grow_horizontal = Control.GROW_DIRECTION_END
	# Make it transparent bg
	var sp_style = StyleBoxEmpty.new()
	squad_panel.add_theme_stylebox_override("panel", sp_style)
	root.add_child(squad_panel)

	squad_container = VBoxContainer.new()
	squad_container.add_theme_constant_override("separation", 10)
	squad_panel.add_child(squad_container)

	# 2. BOTTOM PANEL (Card + Actions)
	var bottom_panel = PanelContainer.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom_panel)

	var h_split = HBoxContainer.new()
	h_split.custom_minimum_size.y = 140
	bottom_panel.add_child(h_split)

	# Unit Card (Left)
	unit_card_panel = PanelContainer.new()
	unit_card_panel.custom_minimum_size = Vector2(300, 140)
	h_split.add_child(unit_card_panel)

	var v_card = VBoxContainer.new()
	unit_card_panel.add_child(v_card)

	# Name
	unit_name_label = Label.new()
	unit_name_label.text = "No Selection"
	unit_name_label.add_theme_font_size_override("font_size", 22)
	unit_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_card.add_child(unit_name_label)

	# Bars
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size.y = 24
	hp_bar.show_percentage = false
	var hp_style_bg = StyleBoxFlat.new()
	hp_style_bg.bg_color = Color(0.2, 0.2, 0.2)
	var hp_style_fill = StyleBoxFlat.new()
	hp_style_fill.bg_color = Color(0.8, 0.2, 0.2)
	hp_bar.add_theme_stylebox_override("background", hp_style_bg)
	hp_bar.add_theme_stylebox_override("fill", hp_style_fill)
	v_card.add_child(hp_bar)

	hp_label = Label.new()
	hp_label.text = "HP 10/10"
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_bar.add_child(hp_label)
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	ap_bar = ProgressBar.new()
	ap_bar.custom_minimum_size.y = 20
	ap_bar.show_percentage = false
	var ap_style_fill = StyleBoxFlat.new()
	ap_style_fill.bg_color = Color(0.2, 0.6, 0.8)
	ap_bar.add_theme_stylebox_override("fill", ap_style_fill)
	v_card.add_child(ap_bar)

	ap_label = Label.new()
	ap_label.text = "AP 2/2"
	ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_bar.add_child(ap_label)
	ap_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Sanity Bar (Purple)
	sanity_bar = ProgressBar.new()
	sanity_bar.custom_minimum_size.y = 16
	sanity_bar.show_percentage = false
	var san_style_fill = StyleBoxFlat.new()
	san_style_fill.bg_color = Color(0.6, 0.2, 0.8)  # Purple
	sanity_bar.add_theme_stylebox_override("fill", san_style_fill)
	v_card.add_child(sanity_bar)

	sanity_label = Label.new()
	sanity_label.text = "SAN 100/100"
	sanity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sanity_label.add_theme_font_size_override("font_size", 10)
	sanity_bar.add_child(sanity_label)
	sanity_label.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Action Bar (Center)
	action_bar_container = HBoxContainer.new()
	action_bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	h_split.add_child(action_bar_container)

	# Status Log (Right)
	status_log_label = RichTextLabel.new()
	status_log_label.custom_minimum_size = Vector2(300, 140)
	status_log_label.scroll_following = true
	status_log_label.text = "System Online."
	h_split.add_child(status_log_label)

	# 3. HIT CHANCE BREAKDOWN PANEL
	hit_chance_panel = PanelContainer.new()
	hit_chance_panel.visible = false
	hit_chance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block clicks
	root.add_child(hit_chance_panel)

	hit_chance_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hit_chance_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # Grow Left
	hit_chance_panel.custom_minimum_size = Vector2(250, 0)  # Auto height logic

	# Margin / Offsets
	hit_chance_panel.offset_top = 100
	hit_chance_panel.offset_right = -20
	# Important: Make sure bottom offset allows for content height.
	# If we want auto-height, we shouldn't anchor bottom to 0 statically if top IS 100.
	# But PRESET_TOP_RIGHT usually anchors bottom to 0.
	# Usage: offset_bottom determines the bottom edge relative to anchor top (0).
	# So offset_bottom must be > 100.
	# Let's give it plenty of room or use SIZE flags.
	# Actually, if we want it to autosize downward, we should ensure it has size.y.
	# Or, we can just set a minimal height via offset.
	hit_chance_panel.offset_bottom = 400  # Max height constraint? Or just initial. PanelContainer should override if content is larger?
	# Better: grow_vertical = BEGIN (Down) is default.

	var v_hit = VBoxContainer.new()
	hit_chance_panel.add_child(v_hit)

	hit_chance_label = Label.new()
	hit_chance_label.text = "HIT CHANCE"
	hit_chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_chance_label.add_theme_font_size_override("font_size", 24)
	v_hit.add_child(hit_chance_label)

	var sep = HSeparator.new()
	v_hit.add_child(sep)

	hit_chance_breakdown = VBoxContainer.new()
	v_hit.add_child(hit_chance_breakdown)

	# ABORT BUTTON (Top Right, below Hit Panel)
	var abort_btn = Button.new()
	abort_btn.text = "ABORT MISSION"
	abort_btn.modulate = Color(1, 0.4, 0.4)  # Reddish
	abort_btn.text = "ABORT MISSION"
	abort_btn.modulate = Color(1, 0.4, 0.4)  # Reddish
	abort_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	abort_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # Grow Leftwards
	abort_btn.offset_top = 20
	abort_btn.offset_right = -20
	abort_btn.custom_minimum_size = Vector2(200, 50)
	abort_btn.z_index = 10  # Ensure on top
	# Manual position: Anchor Top Right seems buggy in some setups if parents don't expand.
	# Let's try forcing position relative to viewport if needed, but anchors should work.

	root.add_child(abort_btn)
	abort_btn.pressed.connect(func(): action_requested.emit("Abort"))
	# print("GameUI: Abort Button Created.")

	# END TURN BUTTON (Bottom Right - Fixed)
	var end_turn_btn = Button.new()
	end_turn_btn.text = "END TURN"
	end_turn_btn.modulate = Color(1.0, 0.8, 0.2)  # Gold
	end_turn_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	end_turn_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	end_turn_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	end_turn_btn.offset_right = -20
	end_turn_btn.offset_bottom = -20
	end_turn_btn.custom_minimum_size = Vector2(150, 60)
	root.add_child(end_turn_btn)
	end_turn_btn.pressed.connect(_on_end_turn_clicked)

	# MISSION END
	mission_end_panel = Panel.new()
	mission_end_panel.visible = false
	root.add_child(mission_end_panel)
	mission_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	mission_end_panel.custom_minimum_size = Vector2(400, 200)

	var end_center = VBoxContainer.new()
	end_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_center.alignment = BoxContainer.ALIGNMENT_CENTER
	mission_end_panel.add_child(end_center)

	var end_label = Label.new()
	end_label.name = "Title"
	end_label.text = "MISSION COMPLETE"
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 32)
	end_center.add_child(end_label)

	var sub_label = Label.new()
	sub_label.name = "Sub"
	sub_label.text = "Press SPACE to Return"
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_center.add_child(sub_label)


var grid_manager


func initialize(tm, gm):
	turn_manager = tm
	grid_manager = gm
	# Old direct connection removed
	# turn_manager.turn_changed.connect(_on_turn_changed)


func _ready():
	_setup_ui()
	# Connect SignalBus
	SignalBus.on_unit_stats_changed.connect(_on_sb_unit_udpate)
	SignalBus.on_unit_health_changed.connect(_on_sb_health_update)
	SignalBus.on_turn_changed.connect(_on_sb_turn_changed)
	SignalBus.on_combat_log_event.connect(_on_sb_log_event)
	SignalBus.on_mission_ended.connect(_on_sb_mission_ended)
	SignalBus.on_show_hit_chance.connect(show_hit_chance)
	SignalBus.on_hide_hit_chance.connect(hide_hit_chance)
	SignalBus.on_ui_select_unit.connect(select_unit)
	SignalBus.on_cinematic_mode_changed.connect(_on_cinematic_mode)


func _on_cinematic_mode(active: bool):
	visible = !active


func select_unit(unit):
	# No more local connection management needed for stats
	selected_unit = unit

	if selected_unit:
		_update_unit_card()
		_refresh_action_bar(selected_unit)
	else:
		unit_name_label.text = "No Unit Selected"
		hp_label.text = ""
		ap_label.text = ""
		hp_bar.value = 0
		ap_bar.value = 0
		sanity_bar.value = 0
		# Clear buttons
		for child in action_bar_container.get_children():
			child.queue_free()


func _on_sb_unit_udpate(unit):
	if unit == selected_unit:
		_update_unit_card()
		_refresh_action_bar(selected_unit)


func _on_sb_health_update(unit, _old, _new):
	if unit == selected_unit:
		_update_unit_card()


func _on_sb_turn_changed(phase_name: String, turn_number: int):
	# top_bar_label REMOVED, use animated banner
	_show_turn_banner(phase_name, turn_number)

	# Detect Player Turn Start to refresh ability cooldown visuals
	if "PLAYER" in phase_name:
		if selected_unit:
			_refresh_action_bar(selected_unit)


func _on_sb_log_event(text: String, color: Color = Color.WHITE):
	log_message(text)


func _on_sb_mission_ended(victory: bool, rewards: int):
	# SPECIAL CASE: Base Defense Victory
	var parent = get_parent()
	if parent and "is_base_defense" in parent and parent.is_base_defense:
		if victory:
			# Do not show standard victory screen, wait for scene switch
			return

	if victory:
		show_victory(rewards)
	else:
		show_defeat()


func _refresh_action_bar(unit):
	# Clear existing buttons
	for child in action_bar_container.get_children():
		child.queue_free()

	# Always add basic Move/Attack/Wait
	if unit and "faction" in unit and unit.faction == "Player":
		_create_action_button("Move (1 AP)", func(): emit_signal("action_requested", "Move"))
		_create_action_button("Attack (1 AP)", func(): emit_signal("action_requested", "Attack"))

		# Dynamic Abilities
		for ability in unit.abilities:
			if ability:
				# HACK: Context Check for Hack Ability
				if ability.display_name == "Hack":
					var valid_tiles = ability.get_valid_tiles(grid_manager, unit)
					if valid_tiles.size() == 0:
						continue  # Hide button if no valid targets

				var btn_text = ability.display_name
				if ability.ap_cost > 0:
					btn_text += " (" + str(ability.ap_cost) + " AP)"

				var btn = _create_action_button(btn_text, func(): _on_ability_clicked(ability))

				if not ability.can_use():
					btn.disabled = true
					btn.text += " (CD: %d)" % ability.current_cooldown

		# Context Action: Retrieve
		_check_retrieve_action(unit)

		# Inventory
		if "inventory" in unit:
			for i in range(unit.inventory.size()):
				var item = unit.inventory[i]
				if item:
					var btn_text = item.display_name + " (1 AP)"
					var btn = _create_action_button(btn_text, func(): _on_item_clicked(item, i))
					if unit.current_ap < 1:
						btn.disabled = true

		_create_action_button("Wait", func(): _on_wait_clicked())


func _check_retrieve_action(unit):
	# Check for "Treat Bag" or "Lost Human" adjacent
	var objs = unit.get_tree().get_nodes_in_group("Objectives")
	for obj in objs:
		if is_instance_valid(obj) and (obj.name == "Treat Bag" or obj.name == "Lost Human"):
			var dist = unit.grid_pos.distance_to(obj.grid_pos)
			if dist <= 1.5:  # Adjacent or Diagonal
				# Use generic "Interact" label? Or specific?
				var label = "Retrieve"
				if obj.name == "Lost Human":
					label = "Rescue"
				_create_action_button(
					label + " (1 AP)", func(): emit_signal("action_requested", "Interact")
				)
				return


func on_ability_cancelled():
	log_message("Ability Cancelled.")
	# Maybe reset button states if they were highlighted?
	# Currently no visual state for "Selected Ability" on buttons other than disabled.
	pass


func _on_ability_clicked(ability: Ability):
	if selected_unit and selected_unit.faction == "Player":
		if selected_unit.is_moving:
			log_message("Unit is moving!")
			return

		if selected_unit.current_ap >= ability.ap_cost:
			emit_signal("ability_requested", ability)
		else:
			log_message("Not enough AP!")


func _on_item_clicked(item, slot_index):
	if selected_unit and selected_unit.faction == "Player":
		if selected_unit.is_moving:
			return
		if selected_unit.current_ap >= 1:
			emit_signal("item_requested", item, slot_index)
		else:
			log_message("Not enough AP!")


func update_unit_info(unit):
	selected_unit = unit
	_update_unit_card()
	_refresh_action_bar(unit)


func _update_unit_card():
	if not is_instance_valid(selected_unit):
		return

	unit_name_label.text = selected_unit.name

	# Update Bars
	hp_bar.max_value = selected_unit.max_hp
	hp_bar.value = selected_unit.current_hp
	hp_label.text = "HP: %d/%d" % [selected_unit.current_hp, selected_unit.max_hp]

	# AP Bar
	if "max_ap" in selected_unit and selected_unit.max_ap > 0:
		ap_bar.visible = true
		ap_bar.max_value = selected_unit.max_ap
		ap_bar.value = selected_unit.current_ap
		ap_label.text = "AP: %d/%d" % [selected_unit.current_ap, selected_unit.max_ap]
	else:
		ap_bar.visible = false

	if "max_sanity" in selected_unit and selected_unit.max_sanity > 0:
		sanity_bar.visible = true
		sanity_bar.max_value = selected_unit.max_sanity
		sanity_bar.value = selected_unit.current_sanity
		sanity_label.text = "SAN: %d/%d" % [selected_unit.current_sanity, selected_unit.max_sanity]
	else:
		sanity_bar.visible = false

	# BONDS DISPLAY
	var v_card = unit_card_panel.get_child(0)
	var bond_label = v_card.get_node_or_null("BondLabel")
	if not bond_label:
		bond_label = Label.new()
		bond_label.name = "BondLabel"
		bond_label.add_theme_font_size_override("font_size", 10)
		bond_label.modulate = Color(1, 0.5, 0.5)
		v_card.add_child(bond_label)

	if GameManager:
		var bond_text = ""
		for other in turn_manager.units:
			if (
				is_instance_valid(other)
				and other != selected_unit
				and "faction" in other
				and other.faction == "Player"
			):
				var lvl = GameManager.get_bond_level(selected_unit.name, other.name)
				if lvl > 0:
					var rank_char = "♥"
					if lvl == 2:
						rank_char = "♥♥"
					if lvl == 3:
						rank_char = "♥♥♥"

					# Check adjacency for "Active" color?
					var dist = selected_unit.grid_pos.distance_to(other.grid_pos)
					var active = dist <= 1.5

					if active:
						bond_text += "[ON] " + other.name + " " + rank_char + "\n"
					else:
						bond_text += other.name + " " + rank_char + "\n"

		bond_label.text = bond_text


var active_banner_tween: Tween


func _show_turn_banner(phase: String, turn: int):
	if active_banner_tween:
		active_banner_tween.kill()

	turn_banner_label.text = "TURN %d\n%s" % [turn, phase]
	# Color Logic
	if "PLAYER" in phase:
		turn_banner_label.modulate = Color(0.2, 0.8, 1.0)  # Cyan
	elif "ENEMY" in phase:
		turn_banner_label.modulate = Color(1.0, 0.2, 0.2)  # Red
	else:
		turn_banner_label.modulate = Color(0.6, 1.0, 0.6)  # Greenish for Environ

	# Animation (Tween)
	active_banner_tween = create_tween()
	var tw = active_banner_tween
	tw.set_parallel(true)

	# Reset state first
	turn_banner_overlay.color.a = 0.0
	turn_banner_label.position.y = -100
	turn_banner_label.modulate.a = 0.0

	# Fade In Background
	tw.tween_property(turn_banner_overlay, "color:a", 0.5, 0.5)
	# Slide Text
	(
		tw
		. tween_property(turn_banner_label, "position:y", 300, 0.5)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tw.tween_property(turn_banner_label, "modulate:a", 1.0, 0.3)

	# Wait
	tw.chain().tween_interval(1.5)

	# Fade Out
	tw.chain().tween_property(turn_banner_overlay, "color:a", 0.0, 0.5)
	tw.parallel().tween_property(turn_banner_label, "modulate:a", 0.0, 0.5)

	# Signal Finished
	tw.chain().tween_callback(func(): SignalBus.on_turn_banner_finished.emit())


func _on_turn_changed(state):
	var state_name = "UNKNOWN"
	match state:
		0:
			state_name = "PLAYER PHASE"
		1:
			state_name = "ENEMY PHASE"
		2:
			state_name = "ENVIRONMENT PHASE"

	top_bar_label.text = "TURN %d: %s" % [turn_manager.turn_count, state_name]


func _create_action_button(text: String, callback: Callable):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 60)
	btn.pressed.connect(callback)
	# Audio Hook
	btn.pressed.connect(
		func():
			if GameManager and GameManager.audio_manager:
				GameManager.audio_manager.play_sfx("SFX_Menu")
	)
	action_bar_container.add_child(btn)
	return btn


func _on_wait_clicked():
	if selected_unit and is_instance_valid(selected_unit) and selected_unit.faction == "Player":
		if selected_unit.is_moving:
			log_message("Unit is moving!")
			return

		selected_unit.spend_ap(selected_unit.current_ap)  # End turn effectively
		log_message(selected_unit.name + " waits.")
		# Check Auto End
		if turn_manager and turn_manager.has_method("check_auto_end_turn"):
			turn_manager.check_auto_end_turn()


func _on_end_turn_clicked():
	log_message("Player requested End Turn.")
	emit_signal("action_requested", "EndTurn")


func log_message(msg: String):
	print("UI LOG: ", msg)  # Debug to console
	status_log_label.add_text(msg + "\n")


func show_victory(rewards: int = 50):
	_show_end_screen("VICTORY!", "Rewards: " + str(rewards) + " Kibble\nPress SPACE to Extract.")


func show_defeat():
	_show_end_screen("DEFEAT...", "Your squad has fallen.\nPress SPACE to Retreat.")


func _show_end_screen(title: String, subtitle: String):
	mission_end_panel.visible = true
	# Structure is Panel -> VBox -> Labels
	var container = mission_end_panel.get_child(0)
	container.get_node("Title").text = title
	container.get_node("Sub").text = subtitle


func show_hit_chance(percent: int, breakdown: String):
	hit_chance_panel.visible = true
	hit_chance_label.text = "HIT CHANCE: %d%%" % percent

	# Clear old children from breakdown vbox
	for c in hit_chance_breakdown.get_children():
		c.queue_free()

	# Parse Breakdown String (Expected Format: "Base: 80 | Cover: -20")
	var parts = breakdown.split("|")
	for p in parts:
		var lbl = Label.new()
		lbl.text = p.strip_edges()
		if "-" in p:
			lbl.modulate = Color(1, 0.5, 0.5)  # Reddish for penalties
		else:
			lbl.modulate = Color(0.7, 1, 0.7)  # Greenish for bonuses/base
		hit_chance_breakdown.add_child(lbl)


# --- Phase 57: Squad Selection & Tab Cycling ---
func initialize_squad_list(units: Array):
	# print("GameUI: initialize_squad_list called with ", units.size(), " units.")
	# Clear existing
	for c in squad_container.get_children():
		c.queue_free()
	squad_frames.clear()

	var frame_script = load("res://scripts/ui/SquadMemberFrame.gd")
	if not frame_script:
		return

	for u in units:
		if "faction" in u and u.faction == "Player":
			var frame = frame_script.new()
			squad_container.add_child(frame)
			frame.initialize(u)
			frame.unit_selected.connect(_on_squad_frame_clicked)
			squad_frames.append(frame)
			# print("GameUI: Added frame for ", u.name)

	# print("GameUI: Total frames created: ", squad_frames.size())


func _on_squad_frame_clicked(unit):
	_select_unit(unit)


func _select_unit(unit):
	if selected_unit == unit:
		return

	selected_unit = unit
	update_unit_info(unit)

	# Highlight Frame
	for f in squad_frames:
		f.set_selected(f.unit_ref == unit)

	# Emit signal so Main knows to focus camera / update selection
	emit_signal("unit_selection_changed", unit)


func _input(event):
	if event.is_action_pressed("ui_focus_next"):  # TAB
		_cycle_unit_selection()


func _cycle_unit_selection():
	if squad_frames.is_empty():
		return

	var current_idx = -1
	for i in range(squad_frames.size()):
		if squad_frames[i].unit_ref == selected_unit:
			current_idx = i
			break

	# Cycle
	for i in range(squad_frames.size()):
		current_idx = (current_idx + 1) % squad_frames.size()
		var n_unit = squad_frames[current_idx].unit_ref
		if n_unit.current_hp > 0:
			_select_unit(n_unit)
			return


signal unit_selection_changed(unit)


func hide_hit_chance():
	if hit_chance_panel:
		hit_chance_panel.visible = false
