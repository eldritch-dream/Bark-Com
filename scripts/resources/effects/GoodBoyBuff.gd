extends StatusEffect
class_name GoodBoyBuff


func _init():
	display_name = "Good Boy"
	duration = 3


func on_apply(unit: Node):
	print("StatusEffect: Who's a good boy? It's ", unit.name)
	SignalBus.on_request_floating_text.emit(
		unit.position + Vector3(0, 2.5, 0), "GOOD BOY!", Color.GOLD
	)
	# Apply Stat Mod
	# Assuming Unit has a mechanism for this.
	# We will implement 'modifiers' dict in Unit.gd
	if "modifiers" in unit:
		if not unit.modifiers.has("aim"):
			unit.modifiers["aim"] = 0
		unit.modifiers["aim"] += 10


func on_remove(unit: Node):
	if "modifiers" in unit and unit.modifiers.has("aim"):
		unit.modifiers["aim"] -= 10
		print("StatusEffect: Good Boy buff wore off.")
