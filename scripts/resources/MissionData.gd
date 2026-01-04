extends Resource
class_name MissionData

@export var mission_name: String = "Patrol"
@export var description: String = "Standard neighborhood patrol."
@export var map_scene_path: String = "res://scenes/Main.tscn"
@export var difficulty_rating: int = 1  # 1=Green, 2=Yellow, 3=Red
@export var reward_kibble: int = 50
@export var enemy_types: Array[Resource] = []  # List of EnemyData resources
@export var objective_type: int = 0  # 0=Deathmatch, 1=Rescue, 2=Retrieve, 3=Hacker
@export var objective_target_count: int = 0
