extends Node

# Global Event Bus for Decoupling

# Unit Events
signal on_unit_health_changed(unit, old_hp: int, new_hp: int)
signal on_unit_stats_changed(unit)  # Covers AP, Sanity updates
signal on_unit_died(unit)

# Interaction Events
signal on_combat_log_event(text: String, color: Color)  # For scrolling combat log if we add one

# Turn Events
signal on_turn_changed(phase_name: String, turn_number: int)
signal on_phase_started(phase_name: String)

# Status Events
signal on_status_applied(unit, status_id: String)
signal on_status_removed(unit, status_id: String)

# Mission Events
signal on_mission_ended(victory: bool, rewards: int)

# Meta-Game Events
signal on_kibble_changed(new_amount: int)
signal on_unit_recruited(unit_data: Dictionary)
signal on_mission_selected(mission_id: String)
signal on_skin_changed()
signal on_xp_gained(unit_name: String, amount: int)
signal on_level_up(unit_name: String, new_level: int)

# UI Events
signal on_ui_force_update  # Catch-all for full refresh if needed
signal on_show_hit_chance(percent: int, breakdown: String)
signal on_hide_hit_chance
signal on_turn_banner_finished
signal on_request_floating_text(pos: Vector3, text: String, color: Color)
signal on_ui_select_unit(unit)
signal on_request_camera_focus(target_pos: Vector3)
signal on_request_vfx(vfx_name: String, pos: Vector3, rotation_vec: Vector3, parent: Node, look_at)

# Movement & Reaction Events
signal on_unit_move_step(unit, from_tile: Vector2, to_tile: Vector2)
signal on_unit_step_completed(unit)
signal on_reaction_fire_triggered(attacker, target)

# Cinematic Events
signal on_combat_action_started(attacker, target, action_type: String, target_pos: Vector3)
signal on_combat_action_finished(attacker)
signal on_cinematic_mode_changed(active: bool)
signal on_request_camera_zoom(target_pos: Vector3, zoom_level: float, duration: float)
