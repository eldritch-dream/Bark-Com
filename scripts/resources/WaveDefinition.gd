extends Resource
class_name WaveDefinition

@export var budget_points: int = 5
@export var allowed_archetypes: Array[String] = []
@export var guaranteed_spawns: Dictionary = {}  # e.g. {"Nemesis": 1, "Rusher": 2}
@export var wave_message: String = "Incoming Wave!"
