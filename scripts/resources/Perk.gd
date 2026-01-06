extends Resource
class_name Perk

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export_multiline var description: String = ""

# Metadata for specific logic (e.g. "mobility_bonus": 2)
@export var metadata: Dictionary = {}
