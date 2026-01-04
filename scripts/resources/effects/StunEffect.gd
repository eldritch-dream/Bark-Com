extends StatusEffect
class_name StunEffect


func _init():
	display_name = "Stunned"
	duration = 1  # One turn stun


func on_apply(unit: Node):
	print("StatusEffect: ", unit.name, " is STUNNED!")
	SignalBus.on_request_floating_text.emit(
		unit.position + Vector3(0, 2.5, 0), "STUNNED!", Color.YELLOW
	)
	if unit.get("current_ap") != null:
		unit.current_ap = 0
		SignalBus.on_unit_stats_changed.emit(unit)


func on_turn_start(unit: Node):
	# Drain AP
	if unit.get("current_ap") != null:
		unit.current_ap = 0
		print("StatusEffect: Stun drained AP from ", unit.name)
		SignalBus.on_request_floating_text.emit(
			unit.position + Vector3(0, 2.5, 0), "NO AP!", Color.YELLOW
		)
