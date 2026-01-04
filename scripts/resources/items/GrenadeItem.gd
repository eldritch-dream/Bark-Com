extends ConsumableData


func _init():
	display_name = "Tennis Ball Grenade"
	description = "Explosive toy. Deals damage in an area."
	cost = 100
	effect_type = EffectType.ABILITY
	range_tiles = 5
	consume_on_use = true
	ability_ref = load("res://scripts/abilities/ItemGrenadeToss.gd")
