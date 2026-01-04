extends ConsumableData


func _init():
	display_name = "Medkit"
	description = "Restores 5 HP to a target unit."
	cost = 50
	effect_type = EffectType.HEAL
	value = 5
	range_tiles = 1
	consume_on_use = true
