extends "res://scripts/resources/StatusEffect.gd"


func _init():
	display_name = "Frozen"
	duration = 1


func on_apply(unit: Node):
	print(unit.name, " is Frozen in fear! Cannot move.")
	if "current_ap" in unit:
		unit.current_ap = 0

	SignalBus.on_request_floating_text.emit(unit.position + Vector3(0, 2, 0), "FROZEN", Color.BLUE)


func on_turn_start(unit: Node):
	# Re-apply AP removal if it persists across turns
	if "current_ap" in unit:
		unit.current_ap = 0
		print(unit.name, " is still Frozen.")
