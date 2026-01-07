extends PanelContainer
class_name UnitInfoCard

# UI Elements
var portrait_viewport: SubViewportContainer
var name_label: Label
var class_label: Label
var class_icon_rect: TextureRect
var level_label: Label
var status_label: Label

# "Mega Nerd" Labels
var stats_label: RichTextLabel
var weapon_details: RichTextLabel
var talents_label: RichTextLabel
var bond_label: RichTextLabel

var current_raw_data = null

func _ready():
	_setup_ui()
	if SignalBus.has_signal("on_perk_learned"):
		SignalBus.on_perk_learned.connect(_on_perk_learned)
	if SignalBus.has_signal("on_unit_stats_changed"):
		SignalBus.on_unit_stats_changed.connect(_on_stats_changed)

func _on_stats_changed(u):
	# Handle Object or Dictionary
	var u_name = ""
	if u is Object and u.has_method("get_class"):
		u_name = u.name
	elif u is Dictionary:
		u_name = u.get("name", "")
		
	var my_name = ""
	if current_raw_data is Object and current_raw_data.has_method("get_class"):
		my_name = current_raw_data.name
	elif current_raw_data is Dictionary:
		my_name = current_raw_data.get("name", "")
		
	if u_name != "" and u_name == my_name:
		setup(u)


func _on_perk_learned(u_name, p_id):
	# Refresh if we are viewing this unit
	if current_raw_data:
		var my_name = ""
		if current_raw_data is Object and current_raw_data.has_method("get_class"):
			my_name = current_raw_data.name
		elif current_raw_data is Dictionary:
			my_name = current_raw_data.get("name", "")
			
		if my_name == u_name:
			setup(current_raw_data)

func _setup_ui():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4)
	add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	# remove anchors preset logic which fights containers
	hbox.add_theme_constant_override("separation", 15)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	
	add_child(margin)
	margin.add_child(hbox)
	
	# --- COL 1: IDENTITY (Portrait, Name, Level) ---
	var col1 = VBoxContainer.new()
	col1.custom_minimum_size.x = 120
	hbox.add_child(col1)
	
	# PORTRAIT
	var portrait_script = load("res://scripts/ui/UnitPortraitConfig.gd")
	if portrait_script:
		portrait_viewport = portrait_script.new()
		portrait_viewport.custom_minimum_size = Vector2(120, 120)
		col1.add_child(portrait_viewport)
	else:
		var p_rect = TextureRect.new()
		p_rect.custom_minimum_size = Vector2(120, 120)
		col1.add_child(p_rect)
	
	col1.add_child(HSeparator.new())
	
	name_label = Label.new()
	name_label.text = "UNIT NAME"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	col1.add_child(name_label)
	
	class_label = Label.new()
	class_label.text = "Class"
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.modulate = Color.LIGHT_GRAY
	col1.add_child(class_label)
	
	level_label = Label.new()
	level_label.text = "Lvl 1"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col1.add_child(level_label)
	
	status_label = Label.new()
	status_label.text = "Active"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col1.add_child(status_label)
	
	# Icon Overlay (Top Left of Col1?)
	class_icon_rect = TextureRect.new()
	class_icon_rect.custom_minimum_size = Vector2(40, 40)
	class_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	class_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_center = CenterContainer.new()
	icon_center.add_child(class_icon_rect)
	col1.add_child(icon_center)

	col1.add_child(HSeparator.new())
	
	# [NEW] Prominent Skill Tree Button
	var btn_tree = Button.new()
	btn_tree.text = "SKILL TREE"
	btn_tree.custom_minimum_size = Vector2(0, 40)
	btn_tree.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_tree.add_theme_color_override("font_color", Color.GOLD)
	btn_tree.add_theme_font_size_override("font_size", 18)
	
	# Style box for button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.2, 0.3, 1.0)
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color.CYAN
	btn_style.corner_radius_top_left = 5
	btn_style.corner_radius_top_right = 5
	btn_style.corner_radius_bottom_left = 5
	btn_style.corner_radius_bottom_right = 5
	btn_tree.add_theme_stylebox_override("normal", btn_style)
	
	btn_tree.pressed.connect(_on_view_tree_clicked)
	col1.add_child(btn_tree)

	hbox.add_child(VSeparator.new())

	# --- COL 2: DATA DUMP (Stats, Weapon, Talents) ---
	var col2 = VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(col2)
	
	# ROW 1: CORE STATS (Table)
	var stat_title = Label.new()
	stat_title.text = "COMBAT ATTRIBUTES"
	stat_title.add_theme_color_override("font_color", Color.GOLD)
	col2.add_child(stat_title)
	
	stats_label = RichTextLabel.new()
	stats_label.fit_content = true
	stats_label.bbcode_enabled = true
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.add_theme_font_size_override("normal_font_size", 16)
	stats_label.add_theme_font_size_override("bold_font_size", 16)
	col2.add_child(stats_label)
	
	col2.add_child(HSeparator.new())
	
	# ROW 2: WEAPON & BONDS (Split)
	var row2 = HBoxContainer.new()
	row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col2.add_child(row2)
	
	# Weapon (Left)
	var w_vbox = VBoxContainer.new()
	w_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(w_vbox)
	var w_lbl = Label.new()
	w_lbl.text = "PRIMARY WEAPON"
	w_lbl.add_theme_color_override("font_color", Color.GOLD)
	w_vbox.add_child(w_lbl)
	
	weapon_details = RichTextLabel.new()
	weapon_details.fit_content = true
	weapon_details.bbcode_enabled = true
	weapon_details.add_theme_font_size_override("normal_font_size", 16)
	weapon_details.add_theme_font_size_override("bold_font_size", 16)
	w_vbox.add_child(weapon_details)
	
	row2.add_child(VSeparator.new())
	
	# Talents / Bonds (Right)
	var t_vbox = VBoxContainer.new()
	t_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(t_vbox)
	
	var t_lbl = Label.new()
	t_lbl.text = "TRAITS & TALENTS"
	t_lbl.add_theme_color_override("font_color", Color.GOLD)
	t_vbox.add_child(t_lbl)
	
	# View Tree Button (MOVED TO COL 1)
	
	talents_label = RichTextLabel.new()
	talents_label.fit_content = true
	talents_label.bbcode_enabled = true
	talents_label.add_theme_font_size_override("normal_font_size", 16)
	t_vbox.add_child(talents_label)
	
	# Bonds (Below Talents)
	t_vbox.add_child(HSeparator.new())
	var b_lbl = Label.new()
	b_lbl.text = "BONDS"
	b_lbl.add_theme_color_override("font_color", Color.GOLD)
	t_vbox.add_child(b_lbl)
	bond_label = RichTextLabel.new()
	bond_label.fit_content = true
	bond_label.bbcode_enabled = true
	t_vbox.add_child(bond_label)


func setup(data):
	current_raw_data = data
	var d = _parse_data(data)
	var raw_obj = data if (data is Object and data.has_method("get_class")) else null
	
	# Identity
	name_label.text = str(d.get("name", "Unknown"))
	class_label.text = str(d.get("class", "Recruit"))
	level_label.text = "Rank " + str(d.get("level", 1))
	status_label.text = str(d.get("status", "Active"))
	
	var stat = d.get("status", "Active")
	if stat == "Ready": status_label.modulate = Color.GREEN
	elif stat == "Active": status_label.modulate = Color.CYAN
	elif stat == "KIA": status_label.modulate = Color.RED
	else: status_label.modulate = Color.ORANGE

	if portrait_viewport and portrait_viewport.has_method("update_portrait"):
		portrait_viewport.update_portrait(raw_obj)
	if ClassIconManager:
		class_icon_rect.texture = ClassIconManager.get_class_icon(d.class)

	# --- STATS GRID ---
	# Dense Table format
	# Dense Table format
	var base_hp = int(d.get("hp",0))
	var base_max_hp = int(d.get("max_hp",10))
	var base_san = int(d.get("sanity",0))
	var base_max_san = int(d.get("max_sanity",100))
	var base_spd = int(d.get("mobility", 6))
	
	# --- AUGMENT STATS REMOVED ---
	# Stats are already calculated by Unit getters or passed correctly in 'd'.


	var hp = str(base_hp) + "/" + str(base_max_hp)
	var san = str(base_san) + "/" + str(base_max_san)
	var ap = str(d.get("ap",3))
	var spd = str(base_spd)
	
	# Defaults (Dynamic Lookup)
	var default_mobility = 6
	var default_max_sanity = 100
	var default_defense = 10
	var default_accuracy = 65
	var default_max_hp = 10
	
	var cls_name = d.get("class", "Recruit")
	var path = "res://assets/data/classes/" + cls_name + "Data.tres"
	if ResourceLoader.exists(path):
		var res = load(path)
		if res and res is ClassData:
			default_mobility = res.base_stats.get("mobility", 6)
			default_max_sanity = res.base_stats.get("max_sanity", 100)
			default_defense = res.base_stats.get("defense", 10)
			default_accuracy = res.base_stats.get("accuracy", 65)
			default_max_hp = res.base_stats.get("max_hp", 10)
	
	# Mobility
	if base_spd > default_mobility:
		spd = "[color=green]" + spd + "[/color]"

	# HP (Max)
	if base_max_hp > default_max_hp:
		hp = "[color=green]" + hp + "[/color]"

	# Sanity (Max)
	if base_max_san > default_max_sanity:
		san = "[color=green]" + san + "[/color]"
		
	# Defense
	var current_def = int(d.get("defense", 10))
	var def_str = str(current_def)
	if current_def > default_defense:
		def_str = "[color=green]" + def_str + "[/color]"

	# Accuracy
	var current_acc = int(d.get("accuracy", 65))
	var acc_str = str(current_acc) + "%"
	if current_acc > default_accuracy:
		acc_str = "[color=green]" + acc_str + "[/color]"
		
	var vis = str(d.get("vision", 4))
	var tch = str(d.get("tech", 0))
	
	var txt = "[table=4]"
	txt += "[cell]HP:[/cell][cell][color=red]" + hp + "[/color][/cell]"
	txt += "[cell]Sanity:[/cell][cell][color=purple]" + san + "[/color][/cell]"
	txt += "[cell]AP:[/cell][cell][color=cyan]" + ap + "[/color][/cell]"
	txt += "[cell]Mobility:[/cell][cell]" + spd + "[/cell]"
	txt += "[cell]Aim:[/cell][cell][color=yellow]" + acc_str + "[/color][/cell]" # Yellow if base, Green if buffed (handled inside acc_str)
	txt += "[cell]Defense:[/cell][cell]" + def_str + "[/cell]"
	txt += "[cell]Vision:[/cell][cell]" + vis + "[/cell]"
	txt += "[cell]Tech:[/cell][cell]" + tch + "[/cell]"
	
	# ROW 2 (Armor / Crit)
	var armor = str(d.get("armor", 0))
	var crit = str(d.get("crit", 0)) + "%"
	txt += "[cell]Armor:[/cell][cell][color=gray]" + armor + "[/color][/cell]"
	txt += "[cell]Crit:[/cell][cell][color=red]" + crit + "[/color][/cell]"
	
	txt += "[/table]"
	stats_label.text = txt

	# --- WEAPON ---
	var w_text = ""
	if d.primary_weapon:
		var w = d.primary_weapon # Resource or Dict
		var w_name = w.display_name if "display_name" in w else "Unknown"
		var w_dmg = str(w.damage) if "damage" in w else "?"
		var w_rng = str(w.weapon_range) if "weapon_range" in w else "?"
		var w_ammo_val = -1
		if w.get("ammo_capacity"): w_ammo_val = w.ammo_capacity
		elif "ammo_capacity" in w: w_ammo_val = w.ammo_capacity
		
		# Traits logic if available?
		
		w_text += "[b]" + w_name + "[/b]\n"
		w_text += "Damage: [color=red]" + str(w_dmg) + "[/color]\n"
		w_text += "Range: [color=yellow]" + str(w_rng) + "[/color] Tiles\n"
		var ammo_str = "Infinite" if w_ammo_val < 0 else str(w_ammo_val)
		w_text += "Ammo: " + ammo_str + "\n"
	else:
		w_text = "[color=gray]No Weapon Equipped[/color]"
	
	weapon_details.text = w_text

	# --- TALENTS ---
	var t_text = ""
	if d.unlocked_talents and d.unlocked_talents.size() > 0:
		for t in d.unlocked_talents:
			var t_name = t.display_name if "display_name" in t else (str(t) if t is String else "Unknown")
			t_text += "• " + t_name + "\n"
	else:
		t_text = "[i]No active talents.[/i]"
	
	talents_label.text = t_text
	
	# Bonds
	var bonds_txt = ""
	var bonds = d.get("bonds", [])
	if bonds.size() > 0:
		for b in bonds:
			bonds_txt += "❤ " + str(b.get("partner_name","?")) + " (Lv " + str(b.get("level",1)) + ")\n"
	else:
		bonds_txt = "[color=gray]No active bonds[/color]"
	
	if bond_label:
		bond_label.text = bonds_txt


func _parse_data(data) -> Dictionary:
	var d = {}
	
	# 1. READ RAW DATA (Object or Dict)
	var raw_class = "Recruit"
	var raw_level = 1
	var u_name = "Unknown"
	
	if data is Object and data.has_method("get_class"): 
		u_name = data.unit_name
		raw_class = data.unit_class
		raw_level = data.rank_level
		# For active objects, trust their current state (it should be correct in-game)
		d["name"] = u_name
		d["class"] = raw_class
		d["level"] = raw_level
		d["hp"] = data.current_hp; d["max_hp"] = data.max_hp
		d["sanity"] = data.current_sanity; d["max_sanity"] = data.max_sanity
		d["ap"] = data.max_ap
		d["mobility"] = data.mobility
		d["accuracy"] = data.accuracy
		d["defense"] = data.defense
		d["vision"] = data.vision_range if "vision_range" in data else 0
		d["primary_weapon"] = data.primary_weapon
		d["unlocked_talents"] = []
		if BarkTreeManager:
			d["unlocked_talents"] = BarkTreeManager.get_unlocked_perks(u_name)
		d["status"] = "Active"
		if "is_dead" in data and data.is_dead: d["status"] = "KIA"
		elif "current_panic_state" in data and data.current_panic_state > 0: d["status"] = "Panicked"
		d["tech"] = data.tech_score if "tech_score" in data else 0
		d["armor"] = data.armor if "armor" in data else 0
		d["crit"] = data.crit_chance if "crit_chance" in data else 0
		
		# Active Units don't need simulation, they are ALIVE.
		# Just load bonds.
		d["bonds"] = []
		if GameManager:
			d["bonds"] = GameManager.get_active_bonds_for_unit(u_name)
			
		return d

	elif data is Dictionary:
		d = data.duplicate(true)
		u_name = d.get("name", "Unknown")
		raw_class = d.get("class", "Recruit")
		raw_level = int(d.get("level", 1))
		
		# 2. RECONSTRUCT FROM BASE (Fixes Explosion)
		# Load Class Data
		var path = "res://assets/data/classes/" + raw_class + "Data.tres"
		var base_stats = {
			"max_hp": 10, "accuracy": 65, "defense": 0, "mobility": 6, "max_sanity": 100, 
			"crit_chance": 0, "armor": 0
		}
		
		if ResourceLoader.exists(path):
			var res = load(path)
			if res and "base_stats" in res:
				var bs = res.base_stats
				if "max_hp" in bs: base_stats["max_hp"] = bs.max_hp
				if "accuracy" in bs: base_stats["accuracy"] = bs.accuracy
				if "defense" in bs: base_stats["defense"] = bs.defense
				if "mobility" in bs: base_stats["mobility"] = bs.mobility
				if "max_sanity" in bs: base_stats["max_sanity"] = bs.max_sanity
				# Check for new stats in ClassData if added? 
				# Assuming ClassData structure matches Unit.gd expectations.
		
		# 3. APPLY CALCULATED STATS
		d["name"] = u_name
		d["class"] = raw_class
		d["level"] = raw_level
		
		# Base
		d["max_hp"] = base_stats["max_hp"]
		d["accuracy"] = base_stats["accuracy"]
		d["defense"] = base_stats["defense"]
		d["mobility"] = base_stats["mobility"]
		d["max_sanity"] = base_stats["max_sanity"]
		d["armor"] = 0
		d["crit"] = 0
		
		# Level Scaling (HP)
		var level_bonus_hp = (raw_level - 1) * 2
		d["max_hp"] += level_bonus_hp
		
		# 4. APPLY PERKS
		d["unlocked_talents"] = []
		if BarkTreeManager:
			d["unlocked_talents"] = BarkTreeManager.get_unlocked_perks(u_name)
			
		for perk_id in d["unlocked_talents"]:
			match perk_id:
				"heavy_bullet_sponge":
					d["armor"] += 1
				"heavy_lmg_mastery", "rank_2_lmg_mastery", "lmg_mastery":
					d["accuracy"] += 10
					d["crit"] += 5
					d["description"] = d.get("description", "") + " [LMG Mastery Active]"
				"recruit_cardio":
					d["mobility"] += 2
				"recruit_good_boy":
					d["max_sanity"] += 10
					
		# 5. RETAIN STATE
		# current_hp/sanity should be clamped to new max?
		# Or just read from memory. 
		# If Memory is corrupted (122), we clamp it.
		var raw_cur_hp = int(data.get("hp", 10))
		if raw_cur_hp > d["max_hp"]: raw_cur_hp = d["max_hp"] # Fix current HP explosion too
		d["hp"] = raw_cur_hp
		
		d["sanity"] = int(data.get("sanity", 100))
		
		d["ap"] = int(data.get("ap", 3))
		d["vision"] = int(data.get("vision", 4))
		d["tech"] = int(data.get("tech", 0))
		
		if not "primary_weapon" in d: d["primary_weapon"] = null
		if not "status" in d: d["status"] = "Ready"
		
		d["bonds"] = []
		if GameManager:
			d["bonds"] = GameManager.get_active_bonds_for_unit(u_name)
			
	return d

func _on_view_tree_clicked():
	# Find a parent to add window to
	var root = get_tree().root.get_child(0) # Main Scene
	
	# Check if we have valid data
	var name_txt = name_label.text
	if name_txt == "UNIT NAME": return
	
	# We need the full data dictionary. 
	# _parse_data() created a local copy, but we didn't store it class-wide.
	# We should really fix that design, but for now let's re-construct or access if possible.
	# Or just re-fetch from GameManager using Name.
	
	if GameManager:
		var roster = GameManager.get_roster()
		for member in roster:
			if member["name"] == name_txt:
				# OPTION: Wrap in CanvasLayer for Top-Most Z-Order
				var layer = CanvasLayer.new()
				layer.layer = 100
				root.add_child(layer)
				
				var scene = load("res://scripts/ui/SkillTreeWindow.gd").new()
				layer.add_child(scene)
				scene.setup(member)
				
				# Ensure scene cleans up layer when closed
				scene.tree_exited.connect(func(): layer.queue_free())
				return
