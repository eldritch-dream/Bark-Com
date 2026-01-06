extends Ability

var description: String
var icon: Texture2D

func _init():
	display_name = "Run & Gun"
	description = "Gain +1 AP to extend your turn. Allows moving after shooting."
	ap_cost = 0
	cooldown_turns = 3
	icon = null
	# is_active = true # Redundant

func execute(user, target, target_grid, grid_manager):
	# Grant AP
	user.current_ap += 1
	if SignalBus:
		SignalBus.on_request_floating_text.emit(user.position, "+1 AP", Color.CYAN)
	
	# Start Cooldown
	start_cooldown()
	
	return "Run & Gun activated!"

func get_valid_tiles(grid_manager, user):
	# Self only
	return [user.grid_pos]
