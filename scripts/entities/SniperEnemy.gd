extends EnemyUnit
class_name SniperEnemy


func _ready():
	super._ready()  # Initialize base stuff

	# Sniper Stats
	name = "Watcher Eye"
	max_hp = 6
	current_hp = 6
	mobility = 3  # Slow
	accuracy = 85  # Deadly
	defense = 0  # Squishy
	vision_range = 10
	attack_range = 10  # Sniper Range

	# Equip Weapon (To ensure CombatResolver uses correct range)
	var rifle = WeaponData.new()
	rifle.display_name = "Eldritch Eye"
	rifle.damage = 4
	rifle.weapon_range = 10
	primary_weapon = rifle

	# Visual Debug
	if has_node("Label3D"):
		$Label3D.text = "SNIPER"
		$Label3D.modulate = Color.CYAN


func get_ideal_distance() -> int:
	return 10  # Stay back!


func evaluate_tile(tile: Vector2, target, gm: GridManager) -> float:
	var score = 0.0

	# A. Distance logic (Stay far away)
	var ideal = get_ideal_distance()
	var dist = tile.distance_to(target.grid_pos)
	var deviation = abs(dist - ideal)

	# Penalty for deviation from ideal range
	score -= (deviation * 2.0)

	# B. Self-Preservation (High Cover for me)
	var my_cover = CombatResolver.get_cover_height_at_pos(tile, target.grid_pos, gm)
	if my_cover >= 2.0:
		score += 60.0  # LOVES High Cover (Incentivized)
	elif my_cover >= 1.0:
		score += 30.0

	# C. Offense (Clear Sightlines)
	# Check cover OF THE TARGET from THIS TILE
	var target_cover = CombatResolver.get_cover_height_at_pos(target.grid_pos, tile, gm)

	if target_cover <= 0.0:
		score += 50.0  # Huge bonus for Flanking / Open Shot
	elif target_cover >= 1.0:
		score -= 40.0  # Hates shooting into cover (wastes ammo)

	# D. Hit Chance (Sanity Check)
	# Only if in range, verify we can even hit
	if dist <= float(attack_range):
		var combat_data = CombatResolver.calculate_hit_chance(self, target, gm, tile)
		if combat_data["hit_chance"] < 40:
			score -= 100.0  # NEVER take bad shots
		elif combat_data["hit_chance"] > 70:
			score += 10.0

	return score
