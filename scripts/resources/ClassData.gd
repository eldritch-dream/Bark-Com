extends Resource
class_name ClassData

@export var display_name: String = "Recruit"
@export var description: String = "A brave dog."
@export var icon: Texture2D

# Base Stats at Rank 1
@export var base_stats: Dictionary = {"max_hp": 10, "mobility": 6, "accuracy": 65, "defense": 10}

# Stat Growth per Rank (Applied automatically on level up)
@export var stat_growth: Dictionary = {"max_hp": 1, "accuracy": 2}

# Talent Tree
# Dictionary: Key = Rank (int), Value = Array[TalentNode] (Options)
# Example: 2: [Zoomies, LowProfile]
@export var rank_tree: Dictionary = {}

# Starting Ability Scripts (Array of Scripts)
@export var starting_abilities: Array[Script] = []

# Bark Tree (Progression)
# Key: Level (int), Value: Array of TalentNode Resources or Paths
@export var talent_tree: Dictionary = {}
