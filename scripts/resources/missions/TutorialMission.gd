@tool
extends MissionConfig


func _init():
	mission_name = "Training Day"
	description = "A simple patrol to get your paws dirty."
	map_size = Vector2(15, 15)
	reward_kibble = 50

	# Wave 1
	var w1 = WaveDefinition.new()
	w1.budget_points = 3  # 3 Rushers
	w1.wave_message = "Contact! Small group of rushers."
	w1.allowed_archetypes.append("Rusher")

	# Wave 2
	var w2 = WaveDefinition.new()
	w2.budget_points = 6  # 3 Snipers or 6 Rushers
	w2.wave_message = "Reinforcements incoming!"
	w2.allowed_archetypes.append("Rusher")
	w2.allowed_archetypes.append("Sniper")
	w2.guaranteed_spawns = {"Sniper": 1}

	waves = [w1, w2]
