extends StatusEffect
class_name BurningEffect

var damage_per_turn: int = 2

func _init():
	display_name = "Burning"
	description = "Takes 2 Damage at start of turn."
	duration = 2
	type = EffectType.DEBUFF
	icon = preload("res://assets/icons/status/burning.svg")

func on_apply(unit: Node):
	print("StatusEffect: ", unit.name, " caught FIRE!")
	SignalBus.on_request_floating_text.emit(
		unit.position + Vector3(0, 2.5, 0), "BURNING!", Color.ORANGE
	)

func on_turn_start(unit: Node):
	if unit.has_method("take_damage"):
		unit.take_damage(damage_per_turn)
		print("StatusEffect: ", unit.name, " burns for ", damage_per_turn)
