extends StatusEffect
class_name PoisonEffect


func _init():
	display_name = "Poisoned"
	duration = 3  # Lasts 3 turns by default


func on_turn_end(unit: Node):
	super.on_turn_end(unit)
	if unit.has_method("take_damage"):
		print("StatusEffect: Poison dealing damage to ", unit.name)
		unit.take_damage(2)
		# Add float text?
		if unit.has_node("Label3D"):  # Quick hack or use FloatingTextManager
			# FloatingTextManager is singleton
			SignalBus.on_request_floating_text.emit(
				unit.position + Vector3(0, 2, 0), "POISON!", Color.GREEN
			)
