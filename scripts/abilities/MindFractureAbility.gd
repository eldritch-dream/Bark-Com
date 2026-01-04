extends "res://scripts/resources/Ability.gd"

# Custom fields not in base Ability
var description: String = "Psionic attack that exploits low Sanity. Causes Confusion."
var vfx_scene_path: String = "res://scenes/vfx/MindFracture.tscn"


func _init():
	display_name = "Mind Fracture"
	ap_cost = 2
	ability_range = 5
	cooldown_turns = 2


# Override
func get_valid_tiles(grid_manager: GridManager, user) -> Array[Vector2]:
	var tiles: Array[Vector2] = []
	var start_pos = user.grid_pos

	# Simple circle range
	for x in range(-ability_range, ability_range + 1):
		for y in range(-ability_range, ability_range + 1):
			var dist = abs(x) + abs(y)  # Manhattan
			if dist <= ability_range and dist > 0:
				var t = start_pos + Vector2(x, y)
				if grid_manager.is_within_bounds(t):
					# Check Line of Sight? (Optional for now)
					tiles.append(t)
	return tiles


# Override
func execute(user, target_unit, _target_tile: Vector2, _grid_manager: GridManager) -> String:
	if not target_unit:
		return "Missed (No Target)"

	# Calculate Hit Chance
	# 2.0 Calculation: Scaled Resist based on Sanity
	# Formula: Resist = Clamp(Sanity, 5, 95)
	# High Sanity (>90) -> 95% Resist (5% Hit)
	# Low Sanity (0) -> 5% Resist (95% Hit)

	var current_sanity = 0
	if "current_sanity" in target_unit:
		current_sanity = target_unit.current_sanity

	var resist_chance = clamp(current_sanity, 5, 95)
	var hit_chance = 100 - resist_chance

	# Roll
	var roll = randi() % 100
	print("Mind Fracture Roll: ", roll, " vs Chance: ", hit_chance)

	if roll < hit_chance:
		print("Mind Fracture HITS ", target_unit.name)
		# Apply Confusion
		var status_script = load("res://scripts/resources/statuses/ConfusedStatus.gd")
		if status_script and target_unit.has_method("apply_effect"):
			var status = status_script.new()
			target_unit.apply_effect(status)
		return "Mind Shattered!"
	else:
		print("Mind Fracture MISSED ", target_unit.name)
		return "Resisted"
