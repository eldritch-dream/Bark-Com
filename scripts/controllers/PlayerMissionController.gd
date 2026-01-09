extends Node
class_name PlayerMissionController

const StandardAttack = preload("res://scripts/abilities/StandardAttack.gd")
var default_attack: StandardAttack

# Input States
enum InputState {
	SELECTING,
	MOVING,
	TARGETING,        # Standard Attack
	ABILITY_TARGETING,
	ITEM_TARGETING,
	CINEMATIC
}

# Dependencies (Injected)
var main_node: Node
var grid_manager
var turn_manager # TurnManager
var game_ui      # GameUI
var _signal_bus  # SignalBus (Injected)

# State
var current_input_state: int = InputState.SELECTING
var selected_unit = null
var selected_ability = null # Ability Resource/Script
var pending_item_action = null
var pending_item_slot: int = -1

# Signals (To update UI/Visuals)
signal input_state_changed(new_state)
signal selection_changed(unit)

func initialize(entry_main, entry_gm, entry_tm, entry_ui, entry_sb):
	main_node = entry_main
	grid_manager = entry_gm
	turn_manager = entry_tm
	game_ui = entry_ui
	_signal_bus = entry_sb
	_signal_bus = entry_sb
	default_attack = StandardAttack.new()
	print("PlayerMissionController: Initialized.")

func set_input_state(new_state: int):
	current_input_state = new_state
	emit_signal("input_state_changed", new_state)
	
	# Clear visuals on state change?
	if new_state == InputState.SELECTING:
		_clear_overlays()
	
	# Show Visuals for New State
	if new_state == InputState.MOVING and selected_unit:
		var gv = _get_grid_visualizer()
		if gv and grid_manager:
			var reachable = grid_manager.get_reachable_tiles(selected_unit.grid_pos, selected_unit.mobility)
			gv.show_highlights(reachable, Color(0, 0, 1, 0.4)) # Blue transparent
			
	if new_state == InputState.ABILITY_TARGETING and selected_unit and selected_ability:
		var gv = _get_grid_visualizer()
		if gv and grid_manager:
			var valid = selected_ability.get_valid_tiles(grid_manager, selected_unit)
			gv.show_highlights(valid, Color(1, 0, 0, 0.4)) # Red transparent

func _clear_overlays():
	if main_node.has_method("_clear_targeting_visuals"):
		main_node._clear_targeting_visuals()
	else:
		# Fallback until Main refactor is complete
		var gv = main_node.get_node_or_null("GridVisualizer")
		if gv:
			gv.clear_highlights()
			gv.clear_preview_path()
			gv.clear_preview_aoe()
			gv.clear_hover_cursor()
		if _signal_bus:
			_signal_bus.on_hide_hit_chance.emit()

func handle_tile_clicked(grid_pos: Vector2, button_index: int):
	# print("PMC: handle_tile_clicked at ", grid_pos, " Btn: ", button_index, " State: ", current_input_state)
# ... (Lines 59-109 Unchanged)

	# Validation
	if not main_node or not grid_manager:
		return

	# Cancel / Back
	if button_index == MOUSE_BUTTON_RIGHT:
		cancel_action()
		return

	match current_input_state:
		InputState.MOVING:
			# Preview execution happens in handle_mouse_hover
			_handle_move_click(grid_pos)
		
		InputState.ABILITY_TARGETING:
			_handle_ability_click(grid_pos)
			
		InputState.TARGETING:
			# Now standardized!
			_handle_ability_click(grid_pos)
		
		InputState.ITEM_TARGETING:
			_handle_item_click(grid_pos)
			
		InputState.SELECTING:
			_handle_selection_click(grid_pos)
			
		_:
			if _signal_bus:
				_signal_bus.on_hide_hit_chance.emit()


func handle_mouse_hover(grid_pos: Vector2):
	var gv = _get_grid_visualizer()
	if not gv: return

	# Delegate Global Hover Logic (Cursor Shape, etc) to Main
	if main_node and main_node.has_method("_on_mouse_hover"):
		main_node._on_mouse_hover(grid_pos)


	# Prevent hover updates during execution
	if turn_manager and turn_manager.is_handling_action:
		if _signal_bus:
			_signal_bus.on_hide_hit_chance.emit()
		return

	match current_input_state:
		InputState.MOVING:
			_preview_movement(grid_pos, gv)
		
		InputState.ABILITY_TARGETING:
			_preview_ability(grid_pos, gv)
			
		InputState.TARGETING:
			_preview_attack(grid_pos)
			
		InputState.ITEM_TARGETING:
			# Reuse Ability Preview? Items mostly AOE or Single Target.
			# But selected_ability is likely null. We need pending_item_action (Item Resource).
			_preview_item(grid_pos, gv)
			
		InputState.SELECTING:
			# Restore Legacy UX: Show hit chance if hovering enemy
			var unit = _get_unit_at(grid_pos)
			if unit and unit != selected_unit and unit.get("faction") == "Enemy":
				_preview_attack(grid_pos)
			else:
				gv.clear_preview_path()
				gv.clear_preview_aoe()
				if _signal_bus:
					_signal_bus.on_hide_hit_chance.emit()

		_:
			gv.clear_preview_path()
			gv.clear_preview_aoe()
			if _signal_bus:
				_signal_bus.on_hide_hit_chance.emit()


# --- Handlers ---

func _handle_selection_click(grid_pos: Vector2):
	var target_unit = _get_unit_at(grid_pos)
	print("PMC: Attempting Select at ", grid_pos, ". Found: ", target_unit)
	
	# Friendly Switching
	if target_unit and target_unit.get("faction") == "Player" and target_unit != selected_unit:
		select_unit(target_unit)
		return

	# Select Unit (if nothing selected or clicking valid target)
	if target_unit and target_unit.get("faction") != "Neutral":
		select_unit(target_unit)
	elif target_unit and target_unit.get("faction") == "Neutral":
		# Special Interaction (Smart Click)
		# If clicking a Neutral Interactable (LootCrate), try to interact
		if target_unit.is_in_group("Interactive") or target_unit.is_in_group("Objectives"):
			print("PMC: Clicked Neutral Interactive. Delegating to Main.")
			if main_node.has_method("_process_move_or_interact"):
				main_node._process_move_or_interact(grid_pos)

	
	# Deselect if clicking empty ground? (Optional)
	if not target_unit:
		# select_unit(null) ? 
		pass

func select_unit(unit):
	selected_unit = unit
	emit_signal("selection_changed", unit)
	# Sync Main? Main uses signals mostly now.
	if _signal_bus:
		_signal_bus.on_ui_select_unit.emit(unit)
	# Main._set_selected_unit(unit) # Legacy call if needed

func _handle_move_click(grid_pos: Vector2):
	print("PMC: _handle_move_click. Unit: ", selected_unit)
	if not selected_unit: return

	# 1. Check Interaction First
	var interactive = _get_interactive_at(grid_pos)
	if interactive:
		print("PMC: Interactive object clicked. Delegating to Main.")
		if main_node.has_method("_process_move_or_interact"):
			main_node._process_move_or_interact(grid_pos)
		return

	# 2. Validate Path for Movement
	var path = grid_manager.get_move_path(selected_unit.grid_pos, grid_pos)
	print("PMC: Path size: ", path.size())
	if path.size() > 0:
		# Validation: Mobility
		var cost = grid_manager.calculate_path_cost(path)
		if cost > selected_unit.mobility:
			print("PMC: Selected move invalid. Too far. Cost: ", cost)
			if _signal_bus:
				_signal_bus.on_combat_log_event.emit("Too Far!", Color.ORANGE)
			return

		# Delegate execution to Main (which handles movement coroutine)
		# Or emit signal?
		if main_node.has_method("_process_move_or_interact"):
			main_node._process_move_or_interact(grid_pos)
		
		# Reset state usually happens after move starts
		# But for now, we can reset to IDLE/SELECTING? 
		# If blocking, Main changes state. If async, we wait.
		# Let's assume Main handles state reset or we reset here?
		# Legacy: _process_move_or_interact does blocking move.
		set_input_state(InputState.SELECTING)

func _handle_ability_click(grid_pos: Vector2):
	var target = _get_unit_at(grid_pos)
	
	# Determine ability (Standardize Legacy)
	var ability = selected_ability
	if not ability and current_input_state == InputState.TARGETING:
		ability = default_attack
	
	# 1. Validation Logic
	if ability:
		var valid_tiles = ability.get_valid_tiles(grid_manager, selected_unit)
		if not valid_tiles.has(grid_pos):
			print("PMC: Clicked Tile ", grid_pos, " is out of range/invalid.")
			# Optional: Feedback UI
			if _signal_bus:
				_signal_bus.on_combat_log_event.emit("Out of Range", Color.RED)
			return

	# Execute
	if main_node.has_method("_execute_ability"):
		main_node._execute_ability(ability, selected_unit, target, grid_pos)
	
	# Reset
	cancel_action()

func _handle_item_click(grid_pos: Vector2):
	if not pending_item_action:
		print("PMC: No item pending.")
		cancel_action()
		return
		
	var item = pending_item_action
	var target = _get_unit_at(grid_pos)
	
	# Validate Range
	var range_val = 1
	if "range" in item:
		range_val = item.range
	elif "ability_range" in item:
		range_val = item.ability_range
		
	if selected_unit.grid_pos.distance_to(grid_pos) > range_val: # Simple distance check for now
		print("PMC: Item Out of Range.")
		if _signal_bus:
			_signal_bus.on_combat_log_event.emit("Out of Range", Color.RED)
		return

	# Execute via Main (Legacy wrapper around Unit.use_item)
	if main_node.has_method("_execute_item"):
		main_node._execute_item(selected_unit, item, pending_item_slot, target, grid_pos)
		
	# Reset
	cancel_action()
# ... (Rest of Handlers Unchanged) ...

func _preview_movement(grid_pos: Vector2, gv: Node):
	if not selected_unit: return
	
	var path = grid_manager.get_move_path(selected_unit.grid_pos, grid_pos)
	if path.size() > 0:
		var color = Color.CYAN
		# Check Mobility
		var cost = grid_manager.calculate_path_cost(path)
		if cost > selected_unit.mobility:
			color = Color.ORANGE
		
		gv.preview_path(path, color)
	else:
		gv.clear_preview_path()

func _preview_ability(grid_pos: Vector2, gv: Node):
	# 1. Path Clearing
	gv.clear_preview_path()
	
	# 2. AOE Preview
	if selected_ability and "aoe_radius" in selected_ability:
		var r = selected_ability.aoe_radius
		var aoe_tiles = [] 
		# Simple AOE logic
		var r_tiles = ceil(r) + 1
		for x in range(grid_pos.x - r_tiles, grid_pos.x + r_tiles + 1):
			for y in range(grid_pos.y - r_tiles, grid_pos.y + r_tiles + 1):
				var t = Vector2(x, y)
				if grid_manager.grid_data.has(t) and grid_pos.distance_to(t) <= r:
					aoe_tiles.append(t)
		gv.preview_aoe(aoe_tiles, Color(1, 0.4, 0.4, 0.4))
	else:
		gv.clear_preview_aoe()
	
	# 3. Hit Chance Logic (The Refactored One)
	var target_obj = _get_unit_at(grid_pos)
	
	# Fallback for interactives (Terminals)
	if not target_obj:
		# Use existing helper for destructibles (includes Terminals if they extend DestructibleCover)
		target_obj = _find_destructible_at(grid_pos)
		
	var is_valid = false
	if target_obj and target_obj != selected_unit:
		# Visibility Check (Fog of War) (Props usually visible but good to check)
		var is_visible = true
		if "visible" in target_obj: is_visible = target_obj.visible
		
		if is_visible:
			# Unit Check
			if target_obj.is_in_group("Units"):
				if target_obj.get("faction") != selected_unit.get("faction") or target_obj.has_method("take_damage"):
					is_valid = true
			# Terminal/Prop Check (For Hack or Sabotage)
			elif target_obj.is_in_group("Terminals") or target_obj.is_in_group("Destructible"):
				# Allow if ability is relevant (Duck Typing via get_hit_chance return)
				# Or generic "Interactable" check.
				# For now, we trust the ability to yield empty dict if invalid.
				is_valid = true

	if is_valid:
		var info = selected_ability.get_hit_chance_breakdown(grid_manager, selected_unit, target_obj)
		if not info.is_empty() and info.has("hit_chance"):
			
			# Parse Breakdown Dictionary to String
			var breakdown_str = ""
			if info.has("breakdown") and info["breakdown"] is Dictionary:
				for key in info["breakdown"]:
					var val = info["breakdown"][key]
					var sign_str = "+" if val >= 0 else ""
					breakdown_str += "%s: %s%d\n" % [key, sign_str, val]
			elif info.has("breakdown") and info["breakdown"] is String:
				breakdown_str = info["breakdown"]
				
			# Standard Offset 1.8 confirmed
			if _signal_bus:
				_signal_bus.on_show_hit_chance.emit(info["hit_chance"], breakdown_str, target_obj.position + Vector3(0, 1.8, 0))
	else:
		if _signal_bus:
			_signal_bus.on_hide_hit_chance.emit()

func _preview_attack(grid_pos: Vector2):
	# Replaces Main._handle_hover logic for hit chance display
	var target_unit = _get_unit_at(grid_pos)
	
	var is_valid_target = false
	if target_unit and target_unit != selected_unit and ("visible" in target_unit and target_unit.visible):
		# 1. Check Faction Match (Enemy)
		if "faction" in target_unit and "faction" in selected_unit:
			if target_unit.faction != selected_unit.faction:
				is_valid_target = true
		# 2. Check Destructible (Barrel/Prop) - Must have take_damage
		elif target_unit.has_method("take_damage"):
			is_valid_target = true

	if is_valid_target:
		# Use selected_ability (which should be set to default_attack for TARGETING)
		# Or fallback if null
		var ability_to_check = selected_ability
		if not ability_to_check and current_input_state == InputState.TARGETING:
			ability_to_check = default_attack

		if ability_to_check:
			var info = ability_to_check.get_hit_chance_breakdown(grid_manager, selected_unit, target_unit)
			if not info.is_empty() and info.has("hit_chance"):
			
				# Parse Breakdown Dictionary to String
				var breakdown_str = ""
				if info.has("breakdown") and info["breakdown"] is Dictionary:
					for key in info["breakdown"]:
						var val = info["breakdown"][key]
						var sign_str = "+" if val >= 0 else ""
						breakdown_str += "%s: %s%d\n" % [key, sign_str, val]
				elif info.has("breakdown") and info["breakdown"] is String:
					breakdown_str = info["breakdown"]

				if _signal_bus:
					_signal_bus.on_show_hit_chance.emit(info["hit_chance"], breakdown_str, target_unit.position + Vector3(0, 1.8, 0))
	else:
		if _signal_bus:
			_signal_bus.on_hide_hit_chance.emit()


func _preview_item(grid_pos: Vector2, gv: Node):
	gv.clear_preview_path()
	
	if pending_item_action:
		var item = pending_item_action
		var r = item.aoe_radius if "aoe_radius" in item else 0
		
		if r > 0:
			var aoe_tiles = [] 
			var r_tiles = ceil(r) + 1
			for x in range(grid_pos.x - r_tiles, grid_pos.x + r_tiles + 1):
				for y in range(grid_pos.y - r_tiles, grid_pos.y + r_tiles + 1):
					var t = Vector2(x, y)
					if grid_manager.grid_data.has(t) and grid_pos.distance_to(t) <= r:
						aoe_tiles.append(t)
			gv.preview_aoe(aoe_tiles, Color(0.2, 1.0, 0.2, 0.4)) # Green for Items
		else:
			gv.clear_preview_aoe()
			
		# Hit Chance Helper for Items (e.g. Grenades)
		if item.get("ability_ref"):
			var ability_res = item.get("ability_ref")
			# Check if it's a script or resource class
			if ability_res is Script or ability_res is Resource:
				var ab = ability_res.new()
				# Use refactored check
				var info = ab.get_hit_chance_breakdown(grid_manager, selected_unit, null)
				
				if not info.is_empty() and info.has("hit_chance"):
					var breakdown_str = ""
					if info.has("breakdown") and info["breakdown"] is Dictionary:
						for key in info["breakdown"]:
							var val = info["breakdown"][key]
							var sign_str = "+" if val >= 0 else ""
							breakdown_str += "%s: %s%d\n" % [key, sign_str, val]
					
					if _signal_bus:
						var world_target = grid_manager.get_world_position(grid_pos)
						_signal_bus.on_show_hit_chance.emit(info["hit_chance"], breakdown_str, world_target + Vector3(0, 1.0, 0))
				else:
					if _signal_bus: _signal_bus.on_hide_hit_chance.emit()
				
				# Cleanup temp instance (GDScript is ref counted usually but explict free if Object?) 
				# ReferenceCounted (Resource/Ability) automatically freed.
		
	else:
		gv.clear_preview_aoe()


# --- Actions ---

func cancel_action():
	set_input_state(InputState.SELECTING)
	selected_ability = null
	pending_item_action = null
	if game_ui and game_ui.has_method("log_message"):
		game_ui.log_message("Command Cancelled.")
	# Clear visuals handled by set_input_state -> _clear_overlays


# --- Helpers ---

func _get_unit_at(grid_pos: Vector2):
	# Main has this helper _get_unit_at_grid. Reimplement to avoid call overhead?
	# Or rely on Main?
	# Better to implement cleanly here using Scene Tree or GridManager lookup.
	# GridManager doesn't track units. 
	# Main.spawned_units is list.
	# Let's iterate scene tree units for robustness.
	if not is_inside_tree(): return null
	var units = get_tree().get_nodes_in_group("Units")
	for u in units:
		if is_instance_valid(u) and "grid_pos" in u and u.grid_pos == grid_pos and u.current_hp > 0:
			return u
	return null

func _get_grid_visualizer():
	if main_node and main_node.has_node("GridVisualizer"):
		return main_node.get_node("GridVisualizer")
	return null

func _find_destructible_at(grid_pos: Vector2):
	var props = main_node.get_tree().get_nodes_in_group("Destructible")
	for p in props:
		var prop = p
		if p is StaticBody3D:
			prop = p.get_parent()
		if is_instance_valid(prop) and "grid_pos" in prop and prop.grid_pos == grid_pos:
			return prop
	return null

func _get_interactive_at(grid_pos: Vector2):
	if not is_inside_tree(): return null
	var props = get_tree().get_nodes_in_group("Interactive")
	for p in props:
		if is_instance_valid(p) and "grid_pos" in p and p.grid_pos == grid_pos:
			return p
	return null
