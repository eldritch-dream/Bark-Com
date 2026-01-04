extends Resource
class_name EnemyData

@export var display_name: String = "Enemy"
@export var max_hp: int = 10
@export var mobility: int = 5
@export var visual_color: Color = Color.RED
@export var primary_weapon: WeaponData

enum AIBehavior { RUSHER, SNIPER, GENERIC }
@export var ai_behavior: AIBehavior = AIBehavior.GENERIC

@export var abilities: Array[Script] = []  # List of Ability scripts to attach
