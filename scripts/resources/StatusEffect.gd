extends RefCounted
class_name StatusEffect

enum EffectType { BUFF, DEBUFF, NEUTRAL }

var display_name: String = "Status Effect"
var description: String = ""
var duration: int = 1  # Turns remaining
var type: EffectType = EffectType.NEUTRAL


func on_apply(unit: Node):
	# Virtual: Called when effect is first added
	pass


func on_turn_start(unit: Node):
	# Virtual: Called at start of unit's turn
	pass


func on_turn_start_with_grid(unit: Node, grid_manager: Node):
	# Virtual: Called if GridManager is available (overrides on_turn_start logic if implemented)
	on_turn_start(unit)  # Default fallback: just call normal start


func on_turn_end(unit: Node):
	# Virtual: Called at end of unit's turn
	duration -= 1
	pass


func on_remove(unit: Node):
	# Virtual: Called when effect is removed
	pass
