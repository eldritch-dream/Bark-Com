extends ConsumableData


func _init():
	display_name = "Sanity Treat"
	description = "A delicious snack. Restores 20 Sanity."
	cost = 75
	effect_type = EffectType.STRESS_RELIEF
	value = 20  # Restores 20 Sanity
	range_tiles = 1
	consume_on_use = true
	# No VFX needed here, handled by CombatResolver (Floating Text)
