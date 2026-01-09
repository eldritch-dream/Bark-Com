extends Ability
class_name FlashbangToss

var max_charges: int = 1
var current_charges: int = 1
var initialized: bool = false

func _init():
	display_name = "Flashbang"
	ap_cost = 2
	ability_range = 5
	cooldown_turns = 3 # Keep cooldown or use charges? 
	# User didn't specify strict Charge system for Flashbang, but Grenadier typically uses charges for grenades. 
	# Let's stick to Cooldown for now unless requested, OR use same Heavy Gear logic? 
	# Heavy Gear says "Adds +1 Charge to Grenades". Might apply here too.
	# Let's assume Flashbang is a "Grenade" type.
	# For simplicity/safety, let's use Cooldowns (can use once per 3 turns), OR Charges (1/mission).
	# "GrenadeToss" is the default ability. Flashbang is special. XCOM Flashbangs are items usually.
	# Here it's a perk ability. Abilities usually have cooldowns.
	# But if it's a "Grenade", Heavy Gear *should* apply?
	# Let's use Cooldown for active abilities to avoid running out of "fun" buttons, unless it's very powerful.
	# Stun is very powerful. 1 Charge per mission makes sense for balance.
	# BUT, user said "Heavy Gear... existing grenade ability...". Didn't explicitly say Flashbang.
	# I will Use Cooldowns for Flashbang to differentiate.
	
	cooldown_turns = 4
var base_aoe_radius: float = 4.0
var aoe_radius: float = 4.0

func on_turn_start(user):
	super.on_turn_start(user)
	update_stats(user)

func update_stats(user):
	# Check for Bombardier (Passive Range)
	if user.has_method("has_perk") and user.has_perk("grenadier_bombardier"):
		ability_range = 8
	else:
		ability_range = 5
		
	# Check for Big Bada Boom
	aoe_radius = base_aoe_radius
	if user.has_method("has_perk") and user.has_perk("grenadier_big_bada_boom"):
		aoe_radius += 1.0


func get_valid_tiles(grid_manager: GridManager, user) -> Array[Vector2]:
	return grid_manager.get_tiles_in_radius(user.grid_pos, ability_range)


func execute(user, _target_unit, target_tile: Vector2, grid_manager: GridManager) -> String:
	if not user.spend_ap(ap_cost):
		return "Not enough AP!"

	var target_pos = grid_manager.get_world_position(target_tile)
	SignalBus.on_combat_action_started.emit(user, null, "Flashbang", target_pos)
	
	# Radius Use Property
	var tiles_to_hit = grid_manager.get_tiles_in_radius(target_tile, aoe_radius)

	print(user.name, " throws FLASHBANG at ", target_tile)

	var on_impact = func():
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Grenade") # Reuse or specific Flash sound

		for tile in tiles_to_hit:
			var units = user.get_tree().get_nodes_in_group("Units")
			for u in units:
				if u.grid_pos == tile and u.current_hp > 0:
					# Friendly Fire? Yes.
					u.take_damage(1)
					
					# Apply Stun (Uses StunEffect resource)
					var stun_res = load("res://scripts/resources/effects/StunEffect.gd")
					if stun_res:
						var stun = stun_res.new()
						u.apply_effect(stun)
					
					# Apply Aim Debuff (Needs new effect or raw modifier)
					# Let's create 'DisorientedEffect'
					var disorient_res = load("res://scripts/resources/effects/DisorientedEffect.gd")
					if disorient_res:
						var dis = disorient_res.new()
						u.apply_effect(dis)
					else:
						# Manual modifier fallback if script doesn't exist yet
						if u.modifiers.has("accuracy"):
							u.modifiers["accuracy"] -= 20
						else:
							u.modifiers["accuracy"] = -20
							
						print(u.name, " is DISORIENTED (-20 Aim)")
						SignalBus.on_request_floating_text.emit(u.position + Vector3(0,2,0), "DISORIENTED", Color.ORANGE)

		SignalBus.on_combat_action_finished.emit(user)

	# VFX
	var start_pos = user.position + Vector3(0, 1.5, 0)
	var end_pos = target_pos
	
	if VFXManager.instance:
		VFXManager.instance.spawn_projectile(start_pos, end_pos, "Grenade", on_impact)
	else:
		on_impact.call()

	start_cooldown()
	return "Flashbang out!"
