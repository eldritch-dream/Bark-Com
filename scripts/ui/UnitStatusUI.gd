extends Node3D

# UnitStatusUI
# Displays overhead icons in a single text "Bar" to prevent overlap.

var unit
var active_statuses: Array = []  # Array of Strings (IDs)
var label: Label3D


func _ready():
	unit = get_parent()
	if not unit:
		queue_free()
		return

	# Create Main Label
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false  # World Space Scaling
	label.pixel_size = 0.004  # Doubled size (was 0.002)
	label.font_size = 64  # High Res
	label.outline_render_priority = 0
	label.outline_size = 12
	label.outline_modulate = Color.BLACK
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	# Position
	label.position = Vector3(0, 2.0, 0)
	add_child(label)

	# Connect Signals
	SignalBus.on_status_applied.connect(_on_status_applied)
	SignalBus.on_status_removed.connect(_on_status_removed)

	_refresh_full()


func _refresh_full():
	active_statuses.clear()

	# 1. Effects
	if "active_effects" in unit:
		for eff in unit.active_effects:
			active_statuses.append(eff.display_name)

	# 2. Panic State
	if "current_panic_state" in unit and unit.current_panic_state != 0:
		var keys = ["NONE", "FREEZE", "RUN", "BERSERK"]
		var idx = unit.current_panic_state
		if idx < keys.size():
			active_statuses.append(keys[idx])

	_update_label()


func _on_status_applied(u, status_id):
	if u != unit:
		return
	if not active_statuses.has(status_id):
		active_statuses.append(status_id)
		_update_label()


func _on_status_removed(u, status_id):
	if u != unit:
		return
	if active_statuses.has(status_id):
		active_statuses.erase(status_id)
		_update_label()


func _update_label():
	if active_statuses.is_empty():
		label.text = ""
		return

	var text = ""
	for id in active_statuses:
		text += _get_icon_emoji(id) + " "  # Add space padding

	label.text = text


func _get_icon_emoji(id):
	match id:
		"Poisoned", "Poison":
			return "🤢"
		"Stunned", "Stun":
			return "💫"
		"BERSERK":
			return "🤬"
		"FREEZE", "Frozen":
			return "🥶"
		"RUN", "Panic":
			return "😱"
		"Confused", "Mind Control":
			return "😵‍💫"
		"Good Boy":
			return "🦴"
		_:
			return "⚠️"
