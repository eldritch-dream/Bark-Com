extends Ability
class_name SplootHeal


func _init():
	display_name = "Sploot"
	ap_cost = 1  # Ends turn effectively? Or just high cost.
	# Let's stick to the plan: "Ends turn immediately".
	# We can model this by consuming all AP in execute.
	ability_range = 0


func get_valid_tiles(_grid_manager: GridManager, user) -> Array[Vector2]:
	return [user.grid_pos]  # Self only


func execute(user, _target_unit, _target_tile: Vector2, _grid_manager: GridManager) -> String:
	user.heal(4)
	# Consume all AP
	if user.current_ap > 0:
		user.spend_ap(user.current_ap)
		
	SignalBus.on_combat_action_finished.emit(user)
	return "Splooting time. Turn skipped."
