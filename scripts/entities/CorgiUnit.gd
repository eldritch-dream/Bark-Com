extends "res://scripts/entities/Unit.gd"
class_name CorgiUnit

# Corgi Specifics
var is_splooting: bool = false
var turns_without_attack: int = 0
var base_mobility: int


func _ready():
	super._ready()
	base_mobility = mobility


func _setup_visuals():
	# Use UnitVisuals
	visuals = UnitVisuals.new()
	visuals.name = "UnitVisuals"
	add_child(visuals)

	# Generate Model
	var gen_data = PlaceholderCorgiGenerator.generate_corgi(visuals)

	# Pass data to Visuals
	visuals.setup(gen_data["anim_player"], gen_data["sockets"])

	# COLLISION SHAPE (Essential for Raycast Selection)
	var col = CollisionShape3D.new()
	var col_shape = CapsuleShape3D.new()
	col_shape.height = 1.0
	col_shape.radius = 0.3
	col.shape = col_shape
	col.position.y = 0.5
	add_child(col)

	name = "Corgi"


# --- Abilities ---


# Passive: Low Profile
# This would be called by the Damage/Hit calculation system.
# returns true if this unit benefits from Low Profile
func has_low_profile() -> bool:
	return true


func get_defense_modifier(_cover_type) -> int:
	# Bonus from Low Profile?
	# Implementation: The CombatResolver checks for "CorgiUnit" type directly or we can make it cleaner here.
	# For now, kept logic in CombatResolver as requested, but we can boost base defense.
	return 0


# Active: Sploot
func activate_sploot():
	if is_splooting:
		print(name, " is already splooting!")
		return

	is_splooting = true
	mobility = 0
	print(name, " used SPLOOT! Defense UP, Mobility 0.")
	# In a real system, we'd apply a status effect modifier for Defense here.


func deactivate_sploot():
	if is_splooting:
		is_splooting = false
		mobility = base_mobility
		print(name, " stood up. Mobility restored.")


# Passive: Zoomies
# Should be called at the start of a turn
func check_zoomies_trigger():
	if turns_without_attack >= 3:
		mobility = base_mobility * 2
		print(name, " has ZOOMIES! Mobility doubled to ", mobility)
	else:
		mobility = base_mobility  # Reset if it was doubled last turn and used?
		# Or maybe Zoomies is a one-turn buff? Assuming one turn for now.


# Active: Bark
# AOE Buff
func bark(allies: Array):
	print(name, " used BARK!")
	for ally in allies:
		if ally != self and position.distance_to(ally.position) < 5.0:  # 5 unit radius
			ally.heal_sanity(2)
			print(" - ", ally.name, " feels less afraid.")


func on_attack():
	turns_without_attack = 0


func on_turn_end():
	# If didn't attack this turn (logic to be handled by TurnManager/Actions)
	# For now, manually incrementing for testing
	turns_without_attack += 1
	# Deactivate sploot at start of next turn? Or user toggled?
	# Usually 'Hunker Down' lasts until move or next turn. Let's say user must deactivate or it lasts 1 turn.
	# For now, leaving as toggle.
