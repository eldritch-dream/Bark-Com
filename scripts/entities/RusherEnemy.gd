extends EnemyUnit
class_name RusherEnemy


func _ready():
	super._ready()  # Initialize base stuff

	# Rusher Stats
	name = "Feral Hound"
	max_hp = 8
	current_hp = 8
	mobility = 6  # Fast
	accuracy = 70
	defense = 5
	attack_range = 1  # Melee

	# Visual Debug
	if has_node("Label3D"):
		$Label3D.text = "RUSHER"
		$Label3D.modulate = Color.ORANGE


func get_ideal_distance() -> int:
	return 1  # Melee preference


func evaluate_tile(tile: Vector2, target, gm: GridManager) -> float:
	var score = 0.0

	# A. Aggressive Distance Logic
	var dist = tile.distance_to(target.grid_pos)

	# Massive penalty for distance (Force them to close the gap)
	score -= (dist * 20.0)

	# Bonus for being in attack range (1.5 for diagonals, 1.0 for straight)
	if dist <= 1.5:
		score += 100.0  # PRIORITY 1: Be able to bite.

	# B. Minor Cover Value (Don't let it distract from rushing)
	var cover_h = CombatResolver.get_cover_height_at_pos(tile, target.grid_pos, gm)
	score += (cover_h * 5.0)  # Weak cover bonus (+10 max)

	# C. Flanking (Bonus if target is exposed)
	var target_cover_h = CombatResolver.get_cover_height_at_pos(target.grid_pos, tile, gm)
	if target_cover_h <= 0.0:
		score += 10.0

	# D. Hit Chance (Only matters if in range)
	if dist <= 1.5:
		var combat_data = CombatResolver.calculate_hit_chance(self, target, gm, tile)
		if combat_data["hit_chance"] > 50:
			score += 20.0

	return score
