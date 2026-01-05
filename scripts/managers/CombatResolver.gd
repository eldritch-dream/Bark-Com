extends Node
class_name CombatResolver

# Constants
const BASE_WEAPON_RANGE = 4  # Tiles
const DISTANCE_PENALTY_PER_TILE = 5  # 5% per tile beyond optimal
const COVER_PENALTY_HALF = 20
const COVER_PENALTY_FULL = 40


static func calculate_hit_chance(
	attacker,
	target,
	grid_manager: GridManager,
	from_pos: Vector2 = Vector2(-999, -999),
	is_reaction: bool = false
) -> Dictionary:
	var breakdown = ""

	# Determine Attack Source
	var attack_pos = attacker.grid_pos
	if from_pos != Vector2(-999, -999):
		attack_pos = from_pos

	# HEALING CHECK
	# Safe Safe Access for Faction
	var att_faction = attacker.get("faction") if "faction" in attacker else "Neutral"
	var targ_faction = target.get("faction") if "faction" in target else "Neutral"

	if att_faction == targ_faction:
		# Exception 1: Syringe Gun (Healing)
		if attacker.primary_weapon and attacker.primary_weapon.display_name == "Syringe Gun":
			return {"hit_chance": 100, "breakdown": "Medikit Match"}

		# Exception 2: Berserk (Panic State 3)
		# Accessing Unit enum safely (assuming attacker is Unit or has property)
		elif "current_panic_state" in attacker and attacker.current_panic_state == 3:  # Unit.PanicState.BERSERK
			# Proceed to calculation (Don't return 0)
			breakdown += "[Friendly Fire - BERSERK] "

		else:
			return {"hit_chance": 0, "breakdown": "Friendly Fire"}

	# 1. Base Accuracy
	var hit_chance = attacker.accuracy

	# Status Effect Modifiers
	if "modifiers" in attacker and attacker.modifiers.has("aim"):
		var mod = attacker.modifiers["aim"]
		hit_chance += mod
		breakdown += (
			"Base: " + str(attacker.accuracy) + " | Buffs: " + ("+" if mod > 0 else "") + str(mod)
		)
	else:
		breakdown += "Base: " + str(attacker.accuracy)

	# Bond Modifiers (Aim)
	if attacker.has_method("get_active_bond_bonuses"):
		var bond_bonus = attacker.get_active_bond_bonuses()
		if bond_bonus["aim"] > 0:
			hit_chance += bond_bonus["aim"]
			breakdown += " | Bond: +" + str(bond_bonus["aim"])

	# Reaction Fire Penalty (0.8x)
	if is_reaction:
		hit_chance *= 0.8
		breakdown += " | Reaction (x0.8)"

	# Use Weapon Range if avail, otherwise default to Unit stats or Basic
	var weapon_range = 3
	if attacker.primary_weapon:
		weapon_range = attacker.primary_weapon.weapon_range
	elif "attack_range" in attacker:
		weapon_range = attacker.attack_range

	# 2. Distance Penalty
	var dist = attack_pos.distance_to(target.grid_pos)
	if dist > weapon_range:
		# 5% penalty per tile outside optimal range
		var penalty = round((dist - weapon_range) * DISTANCE_PENALTY_PER_TILE)
		hit_chance -= penalty
		breakdown += " | Dist Pen: -" + str(penalty)

	# 3. Target Defense (Innate)
	var targ_def = target.defense if "defense" in target else 0
	if targ_def > 0:
		hit_chance -= targ_def
		breakdown += " | Def: -" + str(targ_def)

	# 4. Cover Penalty
	# Use new helper to check adjacent obstacles
	var cover_height = get_cover_height_at_pos(target.grid_pos, attack_pos, grid_manager)

	var cover_pen = 0

	if cover_height >= 2.0:  # Full Cover
		cover_pen = COVER_PENALTY_FULL
		if attacker.faction == "Player":
			cover_pen += 10  # Extra 10% penalty
			breakdown += " (Corgi vs High Cover)"
	elif cover_height >= 1.0:  # Half Cover
		cover_pen = COVER_PENALTY_HALF
		if attacker.faction == "Player":
			cover_pen -= 10
			breakdown += " (Corgi vs Low Cover)"

	if cover_pen > 0:
		# Reaction Fire ignores half of cover (Caught moving)
		if is_reaction:
			cover_pen = int(cover_pen * 0.5)
			breakdown += " | Cover(Reaction): -" + str(cover_pen)
		else:
			hit_chance -= cover_pen
			breakdown += " | Cover: -" + str(cover_pen)

		if is_reaction:
			hit_chance -= cover_pen

	# 5. Elevation (High Ground)
	var att_elev = 0
	var targ_elev = 0
	if grid_manager:
		att_elev = grid_manager.get_tile_data(attack_pos).get("elevation", 0)
		targ_elev = grid_manager.get_tile_data(target.grid_pos).get("elevation", 0)

	var crit_bonus = 0

	if att_elev > targ_elev:
		hit_chance += 15
		crit_bonus = 10
		breakdown += " | High Ground: +15"
	elif att_elev < targ_elev:
		hit_chance -= 10
		breakdown += " | Low Ground: -10"

	# Clamp
	hit_chance = clamp(hit_chance, 5, 100)

	return {"hit_chance": int(hit_chance), "breakdown": breakdown, "crit_chance": crit_bonus}


static func execute_item_effect(
	attacker, item, target_pos: Vector3, grid_manager: GridManager
) -> bool:
	print("CombatResolver: Executing Item ", item.display_name)

	# 1. Ability Logic (Grenades, etc)
	if item.ability_ref:
		var ability = item.ability_ref.new()
		if ability.has_method("execute"):
			var grid_coord = grid_manager.get_grid_coord(target_pos)
			ability.execute(attacker, null, grid_coord, grid_manager)
			return true

	# 2. Simple Effects (Heal, Stress)
	var grid_coord = grid_manager.get_grid_coord(target_pos)
	var target_unit = null
	var units = attacker.get_tree().get_nodes_in_group("Units")
	for u in units:
		if is_instance_valid(u) and "grid_pos" in u and u.grid_pos == grid_coord:
			target_unit = u
			break

	if not target_unit:
		print("CombatResolver: No target unit found for item execution.")
		return false

	if item.effect_type == ConsumableData.EffectType.HEAL:
		if target_unit.has_method("heal"):
			target_unit.heal(item.value)
			
			# Cure Poison
			if target_unit.has_method("remove_effect_by_name"):
				target_unit.remove_effect_by_name("Poison")
				
			# VFX/Text handled by Unit.heal()
			return true

	elif item.effect_type == ConsumableData.EffectType.STRESS_RELIEF:
		if target_unit.has_method("heal_sanity"):
			target_unit.heal_sanity(item.value)
			SignalBus.on_request_floating_text.emit(
				target_unit.position, "+%d SANITY" % item.value, Color.AZURE
			)
			return true

	return false


static func get_cover_height_at_pos(
	target_pos: Vector2, attacker_pos: Vector2, gm: GridManager
) -> float:
	# 1. Intrinsic Cover (Standing IN cover)
	var tile_data = gm.get_tile_data(target_pos)
	var max_cover = tile_data.get("cover_height", 0.0)

	# 2. Directional Cover (Standing BEHIND cover)
	var dir_to_attacker = (attacker_pos - target_pos).normalized()

	# Check 4 neighbors
	var neighbors = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]
	for n in neighbors:
		var neighbor_pos = target_pos + n
		if gm.grid_data.has(neighbor_pos):
			var n_data = gm.grid_data[neighbor_pos]
			var h = n_data.get("cover_height", 0.0)
			if h > 0.0:
				# Is this neighbor roughly towards the attacker?
				var dir_to_neighbor = n.normalized()
				# Dot product > 0.5 means angle < 60 degrees.
				if dir_to_attacker.dot(dir_to_neighbor) > 0.7:
					max_cover = max(max_cover, h)

	return max_cover


static func execute_attack(
	attacker, target, grid_manager: GridManager, is_reaction: bool = false
) -> String:
	# Safe Access for Faction
	var targ_faction = target.get("faction") if "faction" in target else "Neutral"

	# HEALING CHECK
	# Prevent Berserk units from healing (Logic override)
	var is_berserk = false
	if "current_panic_state" in attacker and "PanicState" in attacker:
		if attacker.current_panic_state == attacker.PanicState.BERSERK:
			is_berserk = true

	if attacker.faction == "Player" and targ_faction == "Player" and not is_berserk:
		if attacker.primary_weapon and attacker.primary_weapon.display_name == "Syringe Gun":
			SignalBus.on_combat_action_started.emit(attacker, target, "Heal", target.position)
			print(attacker.name, " heals ", target.name)
			if target.has_method("heal"):
				target.heal(4)

			# BOND GROWTH (Healing)
			if attacker.has_method("trigger_bond_growth"):
				attacker.trigger_bond_growth(target, 3)

			# VFX handled by Unit.heal()
			
			if GameManager and GameManager.audio_manager:
				GameManager.audio_manager.play_sfx("SFX_Menu")  # Placeholder

			SignalBus.on_combat_action_finished.emit(attacker)
			return "HEAL"
		else:
			return "FRIENDLY"

	SignalBus.on_combat_action_started.emit(attacker, target, "Attack", target.position)

	var result = calculate_hit_chance(
		attacker, target, grid_manager, Vector2(-999, -999), is_reaction
	)
	var chance = result["hit_chance"]

	print(
		attacker.name,
		" attacks ",
		target.name,
		"! Hit Chance: ",
		chance,
		"% [",
		result["breakdown"],
		"]"
	)

	# VFX: Muzzle Flash
	SignalBus.on_request_vfx.emit(
		"MuzzleFlash",
		attacker.position + Vector3(0, 1, 0),
		Vector3.ZERO,
		attacker,
		target.global_position
	)

	var roll = randi() % 100 + 1  # 4. Resolve

	# Determine damage for hit
	var damage = 3
	if attacker.primary_weapon:
		damage = attacker.primary_weapon.damage

	# Crit chance is not defined in the original context, assuming 0 for now
	# If crit mechanics are to be added, crit_chance needs to be calculated.
	var crit_chance = 5  # Base Crit
	if result.has("crit_chance"):
		crit_chance += result["crit_chance"]

	if roll <= chance:  # Changed hit_chance to chance to match existing variable
		# HIT
		var is_crit = roll <= crit_chance
		var final_damage = damage
		if is_crit:
			final_damage *= 1.5
			# Sanity Damage on Crit
			if targ_faction == "Player" and target.has_method("take_sanity_damage"):
				target.take_sanity_damage(15)
				print(target.name, " took CRIT SANITY DAMAGE!")

		target.take_damage(int(final_damage))

		# VFX: Impact
		if (
			target.is_in_group("Destructible")
			or (target is StaticBody3D and target.get_parent().is_in_group("Destructible"))
		):
			# Mechanical Impact (Sparks) - Reusing MuzzleFlash for now as it looks like sparks
			SignalBus.on_request_vfx.emit(
				"MuzzleFlash", target.position + Vector3(0, 0.5, 0), Vector3.ZERO, target, null
			)
		else:
			# Organic Impact (Blood)
			SignalBus.on_request_vfx.emit(
				"BloodSplatter", target.position + Vector3(0, 1, 0), Vector3.ZERO, target, null
			)

		# Audio: Hit
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Hit")
			if attacker.faction == "Player":
				GameManager.audio_manager.play_sfx("SFX_Bark")

		# Check for Kill
		var hp = target.current_hp if "current_hp" in target else 999
		if hp <= 0:
			if attacker.has_method("gain_xp"):
				attacker.gain_xp(50)
				print(attacker.name, " killed ", target.name, " and gained 50 XP!")

			# KILL TRACKING for Nemesis System
			# AVENGE TRIGGER (Relationship Growth)
			# "Kill an enemy attacking the other (+5)"
			if "target_unit" in target and is_instance_valid(target.target_unit):
				var victim_friend = target.target_unit
				if victim_friend != attacker and victim_friend.faction == "Player":
					# Killed the enemy who was targeting my friend!
					print(attacker.name, " avenged ", victim_friend.name, "!")
					if attacker.has_method("trigger_bond_growth"):
						attacker.trigger_bond_growth(victim_friend, 5)

			# KILL TRACKING for Nemesis System
			var dead_name = target.name
			if "unit_name" in target and target.unit_name != "":
				dead_name = target.unit_name

			if attacker.faction == "Enemy" and targ_faction == "Player":
				if "victim_log" in attacker:
					attacker.victim_log.append(dead_name)
					print(
						(
							"CombatResolver: "
							+ attacker.name
							+ " added "
							+ dead_name
							+ " to victim log."
						)
					)

			# Memorial Registration
			if targ_faction == "Player" and GameManager:
				# Ensure data snapshot has the correct name if 'register_fallen_hero' relies on it?
				# Actually register_fallen_hero takes 'unit_data'.
				# We should make sure get_data_snapshot() returns the right name or override it here?
				# Let's trust get_data_snapshot() does its job, OR pass a modified dict.
				var snapshot = target.get_data_snapshot()
				snapshot["name"] = dead_name
				GameManager.register_fallen_hero(snapshot, "Killed by " + attacker.name)

				GameManager.register_fallen_hero(snapshot, "Killed by " + attacker.name)

		SignalBus.on_combat_action_finished.emit(attacker)
		return "HIT"
	else:
		# MISS
		SignalBus.on_request_floating_text.emit(target.position, "MISS", Color.GRAY)

		# Audio: Miss
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Miss")

		SignalBus.on_combat_action_finished.emit(attacker)
		return "MISS"
