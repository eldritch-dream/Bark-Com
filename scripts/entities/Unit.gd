extends CharacterBody3D
class_name Unit

const DEBUG_UNIT = false

signal on_death(unit)

# --- CONFIGURATION ---
@export_group("Identity")
@export var unit_name: String = ""  # The display name (e.g. "Dr. Bark")
@export var unit_class: String = "Recruit"
@export var faction: String = "Player"  # "Player", "Enemy"
@export var unit_portrait: Texture2D

@export_group("Stats")
@export var max_hp: int = 10
@export var current_hp: int = 10
@export var base_mobility: int = 6
var mobility: int:
	get:
		var val = base_mobility
		if BarkTreeManager:
			if BarkTreeManager.has_perk(name, "recruit_cardio"):
				val += 2
			
			if BarkTreeManager.has_perk(name, "scout_zoomies"):
				# Zoomies: +2 for first 2 turns
				var tm = get_tree().get_first_node_in_group("TurnManager")
				if tm and tm.turn_count <= 2:
					val += 2
			
			if BarkTreeManager.has_perk(name, "paramedic_field_medic"):
				val += 1
					
		# Status Modifiers
		if modifiers.has("mobility"):
			val += modifiers["mobility"]
			
		return max(1, val) # Minimum movement 1

@export var base_max_sanity: int = 100
var max_sanity: int:
	get:
		var val = base_max_sanity
		if BarkTreeManager and BarkTreeManager.has_perk(name, "recruit_good_boy"):
			val += 10
		if BarkTreeManager and BarkTreeManager.has_perk(name, "paramedic_field_medic"):
			val += 10
		return val
@export var current_sanity: int = 100
@export var max_ap: int = 3
@export var current_ap: int = 2:
	set(value):
		current_ap = value
		SignalBus.on_unit_stats_changed.emit(self)
@export var accuracy: int = 65
@export var defense: int = 10
@export var armor: int = 0
@export var crit_chance: int = 0
@export var damage_bonus: int = 0
@export var tech_score: int = 0
@export var willpower: int = 0

@export_group("Vision")
@export var vision_range: int = 4
@export var smell_range: int = 12

@export_group("Progression")
@export var current_xp: int = 0
@export var rank_level: int = 1
const XP_THRESHOLDS = {1: 0, 2: 100, 3: 300, 4: 600, 5: 1000}

@export_group("Data")
@export var current_class_data: Resource  # Type: ClassData
@export var abilities: Array[Resource] = []  # Type: Ability
var primary_weapon: WeaponData  # Equipment
@export var inventory: Array[Resource] = [null, null]  # Fixed size 2. Type: ConsumableData

# --- STATE ---
var visuals: UnitVisuals
var grid_pos: Vector2 = Vector2.ZERO
var is_moving: bool:
	get:
		if state_machine and state_machine.current_state:
			return state_machine.current_state.name == "Moving"
		return false

var has_moved: bool = false
var has_attacked: bool = false
var is_overwatch_active: bool = false
var overwatch_aim_bonus: int = 0

var is_dead: bool:
	get:
		if state_machine and state_machine.current_state:
			return state_machine.current_state.name == "Dead"
		return false

# Status Effects
var active_effects: Array = []  # Type: StatusEffect
var enemies_seen_this_turn: Array = []
var modifiers: Dictionary = {}

# State Machine
var state_machine: Node  # StateMachine

# Panic Limits
enum PanicState { NONE, FREEZE, RUN, BERSERK }
var current_panic_state = PanicState.NONE:
	set(value):
		if value != current_panic_state:
			# Remove Old Status
			if current_panic_state != PanicState.NONE:
				SignalBus.on_status_removed.emit(self, PanicState.keys()[current_panic_state])

			current_panic_state = value

			# Add New Status
			if current_panic_state != PanicState.NONE:
				SignalBus.on_status_applied.emit(self, PanicState.keys()[current_panic_state])

var panic_turn_count: int = 0

# Cosmetics
var equipped_cosmetics: Dictionary = {}  # Slot -> ItemID
var overwatch_shots_dodged_this_turn: int = 0

# --- SIGNALS ---
signal movement_finished


# --- LIFECYCLE ---
func _ready():
	add_to_group("Units")
	_setup_visuals()

	current_hp = max_hp
	current_sanity = max_sanity
	current_ap = max_ap

	# Default Weapon Check
	if not primary_weapon:
		primary_weapon = WeaponData.new()
		primary_weapon.display_name = "Bark"
		primary_weapon.damage = 3
		primary_weapon.weapon_range = 3

	SignalBus.on_unit_stats_changed.emit(self)

	# Attach Status UI
	var status_ui = load("res://scripts/ui/UnitStatusUI.gd").new()
	add_child(status_ui)

	_setup_fsm()


func _setup_fsm():
	var sm_script = load("res://scripts/fsm/StateMachine.gd")
	state_machine = sm_script.new()
	state_machine.name = "StateMachine"

	# Create States
	var idle = load("res://scripts/fsm/units/UnitIdleState.gd").new()
	idle.name = "Idle"
	state_machine.add_child(idle)

	var moving = load("res://scripts/fsm/units/UnitMoveState.gd").new()
	moving.name = "Moving"
	state_machine.add_child(moving)

	var panic = load("res://scripts/fsm/units/UnitPanicState.gd").new()
	panic.name = "Panic"
	state_machine.add_child(panic)

	var dead = load("res://scripts/fsm/units/UnitDeadState.gd").new()
	dead.name = "Dead"
	state_machine.add_child(dead)

	state_machine.initial_state = idle

	# Add to tree LAST so children are present when _ready runs
	add_child(state_machine)


func initialize(start_grid_pos: Vector2):
	grid_pos = start_grid_pos
	# Snap to world position (assuming GridManager exists globally or passed)
	update_cosmetics()


func _setup_visuals():
	pass  # Override in child classes


# --- CLASS & STATS ---
func apply_class_stats(cls_name: String):
	unit_class = cls_name
	abilities.clear()
	# Grant Universal Hack Ability
	abilities.append(load("res://scripts/abilities/HackAbility.gd").new())

	var loaded_from_resource = false

	# Try Data Resource
	var resource_path = "res://assets/data/classes/" + cls_name + "Data.tres"
	print("Unit: Attempting to load class data from: ", resource_path)
	if ResourceLoader.exists(resource_path):
		var class_data = load(resource_path)
		if class_data:
			print("Unit: Successfully loaded ClassData for ", cls_name)
			current_class_data = class_data
			max_hp = class_data.base_stats.get("max_hp", 10)
			current_hp = max_hp
			base_mobility = class_data.base_stats.get("mobility", 6)
			base_max_sanity = class_data.base_stats.get("max_sanity", 100) # Ensure base_max_sanity is set
			accuracy = class_data.base_stats.get("accuracy", 65)
			defense = class_data.base_stats.get("defense", 10)
			tech_score = class_data.base_stats.get("tech_score", 0)

			for script in class_data.starting_abilities:
				abilities.append(script.new())

			if DEBUG_UNIT:
				print(name + " applied ClassData: " + cls_name)
			# Do NOT return here, fall through to perks? 
			# Actually, if we return, we skip legacy fallback, which is good.
			# But we also skip perk injection logic at bottom.
			
			# We should skip legacy fallback only.
			loaded_from_resource = true

		else:
			print("Unit: ClassData load failed (null) for ", resource_path)
	else:
		print("Unit: Resource not found at ", resource_path)

	# Fallback (Legacy)
	if not loaded_from_resource:
		print("Unit: Falling back to legacy stats for ", cls_name)
		match cls_name:
			"Recruit":
				max_hp = 10
				base_mobility = 6
				abilities.append(load("res://scripts/abilities/GrenadeToss.gd").new())
			"Scout":
				max_hp = 8
				base_mobility = 8
				tech_score = 20
				abilities.append(load("res://scripts/abilities/OverwatchAbility.gd").new())
			"Heavy":
				max_hp = 14
				base_mobility = 4
				abilities.append(load("res://scripts/abilities/ScatterShot.gd").new())
				
			"Paramedic":
				max_hp = 10
				base_mobility = 6
				abilities.append(load("res://scripts/abilities/Triage.gd").new())
			"Grenadier":
				max_hp = 12
				base_mobility = 5
				abilities.append(load("res://scripts/abilities/GrenadeToss.gd").new())
			"Sniper":
				max_hp = 6
				base_mobility = 5
				abilities.append(load("res://scripts/abilities/OverwatchAbility.gd").new())
			_:
				print("Unknown Class: ", cls_name, ". Defaulting to Recruit.")
				max_hp = 10
				base_mobility = 6
				abilities.append(load("res://scripts/abilities/GrenadeToss.gd").new())

	current_hp = max_hp
	
	# Perk Abilities
	if BarkTreeManager:
		print("DEBUG_UNIT: Checking Perks for ", name)
		var unlocked = BarkTreeManager.get_unlocked_perks(name)
		print("DEBUG_UNIT: Unlocked Perks: ", unlocked)
		
		# Iterate all unlocked perks to find specific behaviors or re-inject logic?
		# learn_talent() handles ability injection safely (checks for duplicates).
		for perk_id in unlocked:
			# We need to load the resource to call learn_talent, OR logic inside learn_talent handles ID?
			# learn_talent takes a Resource.
			# We need to find the resource for the ID.
			# BarkTreeManager doesn't seem to have a lookup for ID -> Resource easily available here?
			# Actually, we can assume the path convention "heavy_perkname" or "rank_x..." but they are renamed now.
			# Better approach: BarkTreeManager should perhaps provide the resource or we search?
			# Or we rely on the fact that 'learn_talent' injects abilities when they are learned.
			# But on load, we need to re-apply.
			
			# HACK: Construct path based on convention or search known paths?
			# The paths are inconsistent (scout/scout_... vs heavy/heavy_... vs recruit/recruit_...).
			# Let's try to find it.
			var possible_folders = ["recruit", "scout", "heavy", "paramedic", "grenadier", "sniper"]
			var found_res = null
			for folder in possible_folders:
				var p = "res://assets/data/perks/" + folder + "/" + perk_id + ".tres"
				if ResourceLoader.exists(p):
					found_res = load(p)
					break
			
			if found_res:
				learn_talent(found_res)
			else:
				print("DEBUG_UNIT: Could not find resource for perk ID: ", perk_id)

	else:
		print("DEBUG_UNIT: BarkTreeManager not found!")


# --- ACTION LOGIC ---
func on_turn_start(all_units = [], grid_manager = null):
	current_ap = max_ap
	has_moved = false
	has_attacked = false
	enemies_seen_this_turn.clear()
	overwatch_shots_dodged_this_turn = 0
	
	_check_cooldowns_start()
	
	# Apply Panic
	apply_panic_effect(all_units, grid_manager)
	
	# Process Effects
	process_turn_start_effects(grid_manager)

	if has_method("check_zoomies_trigger"):
		call("check_zoomies_trigger")

	# Self Care Logic
	print("DEBUG: Self Care Check for ", name, ": ", has_perk("paramedic_self_care"), " HP:", current_hp, "/", max_hp)
	if has_perk("paramedic_self_care"):
		if current_hp < max_hp and current_hp > 0:
			heal(2)
			print(name, " self-cares for 2 HP.")



func _check_cooldowns_start():
	for ability in abilities:
		if ability.has_method("on_turn_start"):
			ability.on_turn_start(self)


func refresh_ap():
	current_ap = max_ap
	is_overwatch_active = false
	if DEBUG_UNIT:
		print(name, " AP refreshed to ", current_ap)


func spend_ap(amount: int) -> bool:
	if current_ap >= amount:
		current_ap -= amount
		SignalBus.on_unit_stats_changed.emit(self)
		if DEBUG_UNIT:
			print(name, " spent ", amount, " AP. Remaining: ", current_ap)
		
		# Check for end of turn
		var tm = get_tree().get_first_node_in_group("TurnManager")
		if tm and tm.has_method("check_auto_end_turn"):
			tm.check_auto_end_turn()

		return true
	if DEBUG_UNIT:
		print(name, " not enough AP!")
	return false


func get_weapon_damage() -> int:
	var val = 0
	if primary_weapon:
		val = primary_weapon.damage
	return val + damage_bonus


func gain_xp(amount: int):
	current_xp += amount
	if DEBUG_UNIT:
		print(name, " gained ", amount, " XP!")
	SignalBus.on_xp_gained.emit(name, amount)
	SignalBus.on_request_floating_text.emit(
		position + Vector3(0, 1, 0), "+" + str(amount) + " XP", Color.GOLD
	)
	_check_level_up()


func learn_talent(perk_res: Resource):
	if not perk_res:
		return
		
	print(name, " learning talent: ", perk_res.display_name)
	
	# Active Ability Injection
	if perk_res.get("metadata") and perk_res.metadata.has("active_ability"):
		var ability_name = perk_res.metadata["active_ability"]
		
		# Try "Ability" suffix first, then raw name
		var paths_to_try = [
			"res://scripts/abilities/" + ability_name + "Ability.gd",
			"res://scripts/abilities/" + ability_name + ".gd"
		]
		
		var found_script = null
		var final_path = ""
		
		for p in paths_to_try:
			if ResourceLoader.exists(p):
				found_script = load(p)
				final_path = p
				break
		
		if found_script:
			# Prevent Duplicates
			for a in abilities:
				if a.get_script().resource_path == final_path:
					print(" - Ability already learned: ", ability_name)
					return

			var abil_instance = found_script.new()
			abilities.append(abil_instance)
			print(" - Injected Ability: ", ability_name, " from ", final_path)
			
			# Refresh UI if selected? 
			# SignalBus.on_unit_stats_changed.emit(self) might handle it.
		else:
			print(" - ERROR: Ability script not found for ", ability_name, ". Tried: ", paths_to_try)

	recalculate_stats() # Apply passive bonuses immediately
	SignalBus.on_unit_stats_changed.emit(self)


func recalculate_stats():
	# 1. Reset to Base (from ClassData if available)
	if current_class_data:
		max_hp = current_class_data.base_stats.get("max_hp", 10)
		accuracy = current_class_data.base_stats.get("accuracy", 65)
		defense = current_class_data.base_stats.get("defense", 10)
		armor = current_class_data.base_stats.get("armor", 0)
		crit_chance = current_class_data.base_stats.get("crit_chance", 0)
		# Mobility handled via getter properties mostly, but base is set:
		base_mobility = current_class_data.base_stats.get("mobility", 6)
		willpower = current_class_data.base_stats.get("willpower", 0)
	
	# Reset other stats
	vision_range = 4
	smell_range = 12
	damage_bonus = 0
	
# 2. Level Bonuses
	if current_class_data and current_class_data.stat_growth:
		for stat in current_class_data.stat_growth:
			var growth = current_class_data.stat_growth[stat]
			var bonus = (rank_level - 1) * growth
			match stat:
				"max_hp": max_hp += bonus
				"willpower": willpower += bonus
				"max_sanity": base_max_sanity += bonus
				"accuracy": accuracy += bonus
				"defense": defense += bonus
				"mobility": base_mobility += bonus
				"tech_score": tech_score += bonus
	else:
		# Fallback (Hardcoded HP)
		var bonus_hp_level = (rank_level - 1) * 2
		max_hp += bonus_hp_level

	# 3. Refresh Ability Stats (Perks etc)
	for ability in abilities:
		if ability.has_method("update_stats"):
			ability.update_stats(self)

	if has_perk("heavy_bullet_sponge"):
		# Previous: max_hp += 4, defense += 1
		# New: Add 1 flat armor
		armor += 1
		print(name, " applies Bullet Sponge (+1 Armor)")
		
	if has_perk("heavy_lmg_mastery"):
		accuracy += 10
		crit_chance += 5
		print(name, " applies LMG Mastery (+10 Acc, +5% Crit)")

	if has_perk("sniper_eagle_eye"):
		vision_range += 4
		smell_range += 4
		accuracy += 10
		print(name, " applies Eagle Eye (+4 Vision/Smell, +10 Acc)")
		
	if has_perk("sniper_prepared_position"):
		defense += 15
		accuracy += 5
		print(name, " applies Prepared Position (+15 Def, +5 Acc)")
		
	if has_perk("sniper_vital_point"):
		crit_chance += 20
		damage_bonus += 3
		print(name, " applies Vital Point Targeting (+20% Crit, +3 Damage)")
	
	# Clamp Current
	current_hp = min(current_hp, max_hp)
	SignalBus.on_unit_stats_changed.emit(self)


# --- OVERWATCH ---
func enter_overwatch():
	# Vigilance Perk: +10 Aim on Overwatch
	var aim_bonus = 0
	if has_perk("recruit_vigilance"):
		aim_bonus = 10
		print(name, " enters Overwatch with Vigilance (+10 Aim).")
	
	# current_ap = 0 # DISABLED: Cost is handled by Ability now
	is_overwatch_active = true
	overwatch_aim_bonus = aim_bonus # Must store this for CombatResolver
	
	SignalBus.on_combat_action_started.emit(self, null, "Overwatch", position)
	SignalBus.on_request_floating_text.emit(position + Vector3(0, 2, 0), "OVERWATCH", Color.CYAN)


func move_to(target_grid_pos: Vector2, world_pos: Vector3):
	if faction == "Enemy":
		print("DEBUG: Enemy ", name, " calling move_to!")
		var stack = get_stack()
		if stack.size() > 1:
			print(" - Called from: ", stack[1]["source"], ":", stack[1]["line"], " func: ", stack[1]["function"])

	move_along_path([world_pos], [target_grid_pos])


func move_along_path(path_points: Array, grid_points: Array = []):
	if faction == "Enemy":
		print("DEBUG: Enemy ", name, " calling move_along_path!")
		var stack = get_stack()
		if stack.size() > 1:
			print(" - Called from: ", stack[1]["source"], ":", stack[1]["line"], " func: ", stack[1]["function"])

	if state_machine:
		state_machine.transition_to("Moving", {"world_path": path_points, "grid_path": grid_points})


# --- COMBAT & DAMAGE ---
func take_damage(amount: int):
	if is_dead:
		return
		
	var final_amount = float(amount)
	
	# Apply Vulnerable / Resistances
	if modifiers.has("damage_taken_mult"):
		# e.g. 0.15 for +15%
		final_amount *= (1.0 + modifiers["damage_taken_mult"])
		
	# Convert back to int.
	var damage_int = int(round(final_amount))
	
	# Armor Reduction
	# Shredded Armor logic will be handled by modifiers or status effects altering 'armor' before this call?
	# Or if 'armor' is just a variable, we use it directly.
	# "1 armor prevents 1 damage"
	var effective_armor = armor
	if modifiers.has("armor_change"):
		effective_armor += modifiers["armor_change"]
	effective_armor = max(0, effective_armor) # Cannot have negative effective armor
	
	damage_int -= effective_armor
	
	if damage_int < 1 and amount > 0: damage_int = 1 # Minimum 1 rule? Or can armor block fully? 
	# "1 armor prevents 1 damage". Usually allows 0 damage.
	# "(-2 flat armor min of 0" from request implies armor can be reduced.
	# If Damage < Armor, Damage = 0? Or always min 1?
	# User didn't specify min 1. XCOM usually allows 0 dmg with enough armor? 
	# Let's assume min 1 for now unless "Invulnerable". 
	# Actually, usually armor just reduces. If armor > damage, 0 damage.
	if damage_int < 0: damage_int = 0
	# Wait, usually game dsign prefers min 1 for "Hit".
	# User Request: "1 armor prevents 1 damage" 
	# Let's enforce min 1 for now to prevent unkillable units, unless explicitly 0.
	if damage_int < 1 and amount > 0: damage_int = 1
	
	var old_hp = current_hp
	current_hp = max(0, current_hp - damage_int)
	if DEBUG_UNIT:
		print(name, " took ", damage_int, " damage (Raw:", amount, " Armor:", effective_armor, "). HP: ", current_hp, "/", max_hp)

	SignalBus.on_unit_health_changed.emit(self, old_hp, current_hp)
	SignalBus.on_unit_stats_changed.emit(self)

	if damage_int > 0 and is_overwatch_active:
		is_overwatch_active = false
		if DEBUG_UNIT:
			print(name, " lost Overwatch due to damage.")

	SignalBus.on_request_floating_text.emit(global_position + Vector3(0, 2, 0), str(damage_int), Color.RED)

	if current_hp <= 0:
		# Ensure we don't process further logic if dead
		die()

	# Duplicate take_sanity_damage removed. Merged below.

	# Helpers moved/removed


func heal(amount: int):
	if is_dead:
		return

	var old_hp = current_hp
	current_hp = min(max_hp, current_hp + amount)
	SignalBus.on_unit_health_changed.emit(self, old_hp, current_hp)
	SignalBus.on_request_floating_text.emit(global_position + Vector3(0, 2, 0), str(amount), Color.GREEN)






func trigger_bond_growth(other_unit: Unit, value: int):
	if not GameManager:
		return
	if faction != "Player" or other_unit.faction != "Player":
		return

	GameManager.modify_bond(name, other_unit.name, value)
	SignalBus.on_request_floating_text.emit(position + Vector3(0, 2.5, 0), "Bond Up!", Color.PINK)


func get_active_bond_bonuses() -> Dictionary:
	var bonuses = {"willpower": 0, "aim": 0}
	if not GameManager:
		return bonuses

	# Find adjacent units
	var tm = get_tree().get_first_node_in_group("TurnManager")
	if not tm:
		return bonuses

	for u in tm.units:
		if (
			is_instance_valid(u)
			and u != self
			and "faction" in u
			and u.faction == "Player"
			and u.current_hp > 0
		):
			var dist = grid_pos.distance_to(u.grid_pos)
			if dist <= 1.5:  # Adjacent (including diagonal)
				var level = GameManager.get_bond_level(name, u.name)

				# Level 1: Buddy -> Willpower
				if level >= 1:
					bonuses["willpower"] += 5

				# Level 2: Packmate -> Aim
				if level >= 2:
					bonuses["aim"] += 10

	return bonuses


func get_aura_bonuses() -> Dictionary:
	var bonuses = {"aim": 0, "willpower": 0}
	if not GameManager:
		return bonuses

	# Find adjacent units (Radius 3 for Pack Leader)
	var tm = get_tree().get_first_node_in_group("TurnManager")
	if not tm:
		return bonuses

	for u in tm.units:
		if (
			is_instance_valid(u)
			and u != self
			and "faction" in u
			and u.faction == "Player"
			and u.current_hp > 0
		):
			var dist = grid_pos.distance_to(u.grid_pos)
			
			# Check for Pack Leader (Radius 3)
			# BarkTreeManager Hook
			if BarkTreeManager and BarkTreeManager.has_perk(u.name, "recruit_pack_leader"):
				if dist <= 3.0:
					bonuses["aim"] += 10
					bonuses["willpower"] += 5

	return bonuses


func die():
	if is_dead:
		return
	# is_dead = true # Handled by State
	print(name, " has died!")

	# SOUL PUP TRIGGER (Level 3)
	if GameManager:
		var tm = get_tree().get_first_node_in_group("TurnManager")
		if tm:
			for u in tm.units:
				if (
					is_instance_valid(u)
					and u != self
					and "faction" in u
					and u.faction == "Player"
					and u.current_hp > 0
				):
					var level = GameManager.get_bond_level(name, u.name)
					if level >= 3:
						# Trigger Berserk
						print(u.name, " goes BERSERK seeing their soul pup die!")
						u.current_panic_state = PanicState.BERSERK
						u.current_ap = u.max_ap * 2  # Double AP for rage
						SignalBus.on_request_floating_text.emit(
							u.position + Vector3(0, 2, 0), "NOOOOO!", Color.RED
						)

	# Emit Logic Signal for Main.gd (Persistence)
	on_death.emit(self)

	SignalBus.on_unit_died.emit(self)
	if state_machine:
		state_machine.transition_to("Dead")
	
	# Wait for animation (approx 2s or query AnimPlayer)
	# Using timer for safety as Visuals might be various
	await get_tree().create_timer(1.5).timeout
	queue_free()


# --- SANITY & PANIC ---
func take_sanity_damage(amount: int):
	# WILLPOWER REDUCTION (Bond Bonus)
	var reduction = 0
	if GameManager:
		var bonus = get_active_bond_bonuses()
		reduction = bonus["willpower"]

	var final_amount = max(0, amount - reduction)
	current_sanity = max(0, current_sanity - final_amount)

	if DEBUG_UNIT:
		print(name, " took ", final_amount, " sanity damage (Raw: ", amount, ", Willpower: ", reduction, "). Sanity: ", current_sanity)
	else:
		if final_amount > 0:
			print(name, " took ", final_amount, " sanity damage.")
	SignalBus.on_unit_stats_changed.emit(self)

	var color = Color.PURPLE
	var text = "-SANITY!"
	if reduction > 0:
		text = "-" + str(final_amount) + " (Resist)"
		color = Color.PLUM
	SignalBus.on_request_floating_text.emit(position + Vector3(0, 1.8, 0), text, color)

	_check_level_up()
	_check_panic_thresholds()


func heal_sanity(amount: int):
	current_sanity = min(max_sanity, current_sanity + amount)
	if DEBUG_UNIT:
		print(name, " recovered ", amount, " sanity.")
	SignalBus.on_unit_stats_changed.emit(self)

	if current_sanity > 3 and current_panic_state != PanicState.NONE:
		print(name, " calmed down.")
		current_panic_state = PanicState.NONE
		panic_turn_count = 0


func _check_panic_thresholds():
	if current_panic_state != PanicState.NONE:
		return  # Already panicking

	if current_sanity <= 0:
		# Guarantee Panic
		_roll_panic_type()
	elif current_sanity <= 20:  # Updated mostly for consistency
		if randf() < 0.5:
			_roll_panic_type()


func _process_panic_turn_start():
	if current_panic_state == PanicState.NONE:
		return

	panic_turn_count += 1
	print(name, " panic turn count: ", panic_turn_count, " State: ", current_panic_state)

	# 1. Berserk Limit (1 Turn)
	if current_panic_state == PanicState.BERSERK:
		if panic_turn_count >= 1:
			print(name, " is no longer Berserk.")
			current_panic_state = PanicState.NONE
			panic_turn_count = 0
			SignalBus.on_request_floating_text.emit(position + Vector3(0, 2, 0), "CALMED", Color.WHITE)

	# 2. General Panic Recovery (Chance after 3 turns?)
	elif panic_turn_count >= 3:
		if randf() < 0.3: # 30% chance to recover per turn after 3
			print(name, " snapped out of panic.")
			current_panic_state = PanicState.NONE
			panic_turn_count = 0
			SignalBus.on_request_floating_text.emit(position + Vector3(0, 2, 0), "RECOVERED", Color.WHITE)


func _roll_panic_type():
	var roll = randi() % 3
	match roll:
		0:
			state_machine.transition_to("Panic", {"type": "FREEZE"})
			current_panic_state = PanicState.FREEZE
		1:
			state_machine.transition_to("Panic", {"type": "RUN"})
			current_panic_state = PanicState.RUN
		2:
			state_machine.transition_to("Panic", {"type": "BERSERK"})
			current_panic_state = PanicState.BERSERK

	panic_turn_count = 2  # Duration


func apply_panic_effect(all_units: Array, grid_manager: GridManager) -> bool:
	if current_panic_state == PanicState.NONE:
		return false

	if state_machine:
		state_machine.transition_to("Panic", {"type": PanicState.keys()[current_panic_state]})
		return true

	return false


func get_fear_level() -> int:
	return max_sanity - current_sanity


# --- TALENTS & XP ---



func _check_level_up():
	var next_level = rank_level + 1
	if XP_THRESHOLDS.has(next_level) and current_xp >= XP_THRESHOLDS[next_level]:
		rank_level = next_level
		print(name, " LEVELED UP to Level ", rank_level, "!")
		SignalBus.on_level_up.emit(name, rank_level)
		SignalBus.on_request_floating_text.emit(
			position + Vector3(0, 2, 0), "LEVEL UP!", Color.GOLD
		)
		max_hp += 2
		current_hp += 2



func has_perk(tag: String) -> bool:
	if BarkTreeManager:
		# Check for class-specific prefix first (e.g. recruit_sit_stay)
		if unit_class:
			var prefix = unit_class.to_lower() + "_"
			var full_id = prefix + tag
			if BarkTreeManager.has_perk(name, full_id):
				return true
		
		# Check raw tag
		if BarkTreeManager.has_perk(name, tag):
			return true

	return false


# --- STATUS EFFECTS ---
func apply_effect(effect: StatusEffect):
	for existing in active_effects:
		if existing.display_name == effect.display_name:
			if DEBUG_UNIT:
				print(name, " refreshed effect: ", effect.display_name)
			existing.duration = effect.duration
			# Do NOT call on_apply again if refreshed, to avoid double text
			# effect.on_apply(self) 
			print(name, " refreshed effect: ", effect.display_name)
			return
	active_effects.append(effect)
	effect.on_apply(self)
	print(name, " applied effect: ", effect.display_name)
	SignalBus.on_status_applied.emit(self, effect.display_name)


func remove_effect(effect: StatusEffect):
	if active_effects.has(effect):
		active_effects.erase(effect)
		effect.on_remove(self)
		print(name, " removed effect: ", effect.display_name)
		SignalBus.on_status_removed.emit(self, effect.display_name)


func remove_effect_by_name(effect_name: String):
	for effect in active_effects:
		if effect.display_name == effect_name:
			remove_effect(effect)
			print(name, " cured of ", effect_name)
			return


func process_turn_start_effects(grid_manager = null):
	for effect in active_effects.duplicate():
		if effect.has_method("on_turn_start_with_grid") and grid_manager:
			effect.on_turn_start_with_grid(self, grid_manager)
		else:
			effect.on_turn_start(self)
		if effect.duration <= 0:
			remove_effect(effect)

	for ability in abilities:
		ability.on_turn_start(self)


func process_turn_end_effects():
	for effect in active_effects.duplicate():
		effect.on_turn_end(self)
		if effect.duration <= 0:
			remove_effect(effect)

	# Sit & Stay: +20 Defense if didn't attack
	# Apply AFTER clearing old effects so it lasts through enemy turn
	if has_perk("recruit_sit_stay"):
		if not has_attacked:
			# Check if already active to prevent double text
			var already_has = false
			for e in active_effects:
				if e.display_name == "Sit & Stay":
					already_has = true
					e.duration = 1 # Refresh
					print(name, " refreshes Sit & Stay.")
					break
			
			if not already_has:
				print(name, " triggers Sit & Stay (No attack this turn).")
				var buff = load("res://scripts/resources/statuses/SitStayStatus.gd").new()
				apply_effect(buff)


func _start_turn_updates():
	_process_panic_turn_start()
	process_turn_start_effects()





func _update_effects_start():
	process_turn_start_effects()


func use_item(slot_index: int, target_pos: Vector3, grid_manager) -> bool:
	if slot_index < 0 or slot_index >= inventory.size():
		return false
	var item = inventory[slot_index]
	if not item:
		return false

	if current_ap < 1:
		print("Not enough AP to use item!")
		return false

	print(name, " using item ", item.display_name)

	var success = CombatResolver.execute_item_effect(self, item, target_pos, grid_manager)

	if success:
		if item.consume_on_use:
			inventory[slot_index] = null

		current_ap -= 1
		SignalBus.on_unit_stats_changed.emit(self)
		return true

	return false


func on_seen_enemy(enemy_unit):
	if enemy_unit in enemies_seen_this_turn:
		return
	enemies_seen_this_turn.append(enemy_unit)
	if DEBUG_UNIT:
		print(name, " is horrified by ", enemy_unit.name, "!")
	take_sanity_damage(5)


# --- COSMETICS ---
func equip_cosmetic(item_id: String):
	if CosmeticManager and CosmeticManager.database.has(item_id):
		var item = CosmeticManager.database[item_id]
		equipped_cosmetics[item.slot] = item_id
		if DEBUG_UNIT:
			print(name, " equipped ", item.display_name)
		update_cosmetics()


func unequip_cosmetic(slot: String):
	if equipped_cosmetics.has(slot):
		equipped_cosmetics.erase(slot)
		update_cosmetics()


func update_cosmetics():
	if visuals:
		# VISUALS SYSTEM (Phase 78)
		for slot in ["HEAD", "BACK"]:
			var socket_key = "Head" if slot == "HEAD" else "Spine"

			if equipped_cosmetics.has(slot):
				var item_id = equipped_cosmetics[slot]
				# Ensure CosmeticManager exists (Global autolaod?)
				if CosmeticManager and CosmeticManager.database.has(item_id):
					var item_mesh = CosmeticManager.get_mesh_for_item(item_id)
					var item_data = CosmeticManager.database.get(item_id)

					if item_mesh and item_data:
						var mi = MeshInstance3D.new()
						mi.name = "Cosmetic_" + item_id
						mi.mesh = item_mesh
						var mat = StandardMaterial3D.new()
						mat.albedo_color = item_data.color_override
						mi.material_override = mat

						visuals.attach_cosmetic(socket_key, mi)
			else:
				# Clear
				visuals.attach_cosmetic(socket_key, null)
		return

	# LEGACY FALLBACK
	var mesh = get_node_or_null("Mesh")
	if not mesh:
		return

	for slot in ["HEAD", "BACK"]:
		var attach_node = _find_attachment_point(slot)
		if attach_node:
			for child in attach_node.get_children():
				if child.name.begins_with("Cosmetic_"):
					child.queue_free()

			if equipped_cosmetics.has(slot):
				var item_id = equipped_cosmetics[slot]
				var item_mesh = CosmeticManager.get_mesh_for_item(item_id)
				var item_data = CosmeticManager.database.get(item_id)

				if item_mesh and item_data:
					var mi = MeshInstance3D.new()
					mi.name = "Cosmetic_" + item_id
					mi.mesh = item_mesh
					var mat = StandardMaterial3D.new()
					mat.albedo_color = item_data.color_override
					mi.material_override = mat
					attach_node.add_child(mi)


func set_visual_mode(mode: String):
	# Switch visual transparency for Fog of War (GHOST mode)
	var mesh = get_node_or_null("Mesh")
	if not mesh:
		return

	# Create a unique material instance if correct type
	if not mesh.material_override:
		mesh.material_override = StandardMaterial3D.new()
		if faction == "Enemy":
			mesh.material_override.albedo_color = Color(1, 0, 0)

	var mat = mesh.material_override
	if mat is StandardMaterial3D:
		if mode == "GHOST":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.3  # Ghostly
		else:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color.a = 1.0


func _find_attachment_point(slot: String) -> Node3D:
	var mesh = get_node_or_null("Mesh")
	if not mesh:
		return null
	var node_name = "Attach_" + slot.capitalize()
	var node = mesh.get_node_or_null(node_name)
	if not node:
		node = Node3D.new()
		node.name = node_name
		mesh.add_child(node)
		if slot == "HEAD":
			node.position = Vector3(0, 0.4, 0.3)
		elif slot == "BACK":
			node.position = Vector3(0, 0.2, -0.2)
	return node


# --- SAVE DATA ---
func get_data_snapshot() -> Dictionary:
	var cls_name = "Recruit"
	if current_class_data:
		cls_name = current_class_data.display_name
	return {
		"name": name,
		"class": cls_name,
		"max_hp": max_hp,
		"sanity": current_sanity,
		"fallen": is_dead,
		"cosmetics": equipped_cosmetics.duplicate()
	}


func restore_from_snapshot(data: Dictionary):
	if data.has("name"): name = data["name"]
	if data.has("class"): unit_class = data["class"]
	if data.has("level"): rank_level = int(data["level"])
	if data.has("xp"): current_xp = int(data["xp"])
	if data.has("max_hp"): max_hp = int(data["max_hp"])
	if data.has("hp"): current_hp = int(data["hp"])
	if data.has("sanity"): current_sanity = int(data["sanity"])
	if data.has("fallen"): is_dead = data["fallen"]
	
	if data.has("cosmetics"):
		equipped_cosmetics = data["cosmetics"]
		update_cosmetics()
		
	# Recalculate derived stats (Applying level bonuses to Max HP again? No.)
	# If snapshot has max_hp, we trust it? 
	# OR we trust recalculate_stats?
	# Users requested "Correct numbers".
	# If we trust snapshot, we carry over the "Explosion" bug if it exists in save.
	# Safe approach: Restore Level/Class, then Recalculate Stats from scratch to match rules.
	# Then clamp HP to what was saved (or relative damage).
	
	recalculate_stats()
	# Apply damage calculated from snapshot difference?
	# If save said 10/46. Recalc says 46. We set current to 10.
	if data.has("hp"):
		current_hp = int(data["hp"])
		
	SignalBus.on_unit_stats_changed.emit(self)


func clear_negative_effects():
	# Use StatusEffect Type if available, plus legacy list as backup
	var legacy_list = ["Stunned", "Burning", "Bleeding", "Poisoned", "Panic", "Suppressed", "Disoriented", "Confused", "Shredded Armor"]
	
	for effect in active_effects.duplicate():
		var is_debuff = false
		if "type" in effect and effect.type == StatusEffect.EffectType.DEBUFF:
			is_debuff = true
		elif effect.display_name in legacy_list:
			is_debuff = true
			
		if is_debuff:
			remove_effect(effect)
			print(name, " cleansed of ", effect.display_name)
			SignalBus.on_request_floating_text.emit(position + Vector3(0, 2, 0), "CLEANSED", Color.WHITE)
	
	# Also clear panic
	if current_panic_state != PanicState.NONE:
		current_panic_state = PanicState.NONE
		panic_turn_count = 0
		print(name, " panic cleared!")
		SignalBus.on_request_floating_text.emit(position + Vector3(0, 2, 0), "CALM", Color.WHITE)

func get_hit_chance_breakdown(target_unit) -> Dictionary:
	# Standard Attack Calculation
	var base_acc = accuracy
	var defense_val = 0
	if "defense" in target_unit:
		defense_val = target_unit.defense
	
	# Cover
	var cover_val = 0
	# Cover logic requires GridManager usually. Unit doesn't have reference to GM easily unless passed or global.
	# We'll skip cover for this basic fallback OR try to access global GM if available.
	# For now, let's keep it simple: Base - Defense.
	
	var final = clamp(base_acc - defense_val - cover_val, 0, 100)
	
	return {
		"hit_chance": final,
		"breakdown": {
			"Base Accuracy": base_acc,
			"Enemy Defense": -defense_val,
			"Cover": -cover_val
		}
	}
