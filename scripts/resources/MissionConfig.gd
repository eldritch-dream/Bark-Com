extends Resource
class_name MissionConfig

@export var mission_name: String = "Unknown Mission"
@export_multiline var description: String = " Survive."
@export var map_size: Vector2 = Vector2(20, 20)
@export var waves: Array[WaveDefinition] = []
@export var reward_kibble: int = 100
@export var is_final_defense: bool = false
@export var objective_type: int = 0 # 0=Deathmatch, 1=Rescue, 2=Retrieve, 3=Hacker, 4=Defense (Match ObjectiveManager)
@export var objective_target_count: int = 0
