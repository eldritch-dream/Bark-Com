extends Ability
class_name OverwatchAbility


func _init():
	display_name = "Overwatch"
	ap_cost = 2  # Expensive action


func get_valid_tiles(grid, user) -> Array[Vector2]:
	# Self-targeting only
	return [user.grid_pos]


func execute(user, target_unit, target_tile, grid_manager):
	if user.has_method("enter_overwatch"):
		user.enter_overwatch()
		return user.name + " enters Overwatch!"
	return "Error: Unit cannot overwatch."
