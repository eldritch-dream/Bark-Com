extends Resource
class_name CosmeticItem

@export var id: String
@export var display_name: String
@export var mesh_path: String = ""  # Path to mesh resource
@export var slot: String = "HEAD"  # HEAD, BACK, FACE
@export var unlock_condition: String = ""  # "Rank:X", "Class:Y", "Default"

# Optional: Color override?
@export var color_override: Color = Color.WHITE
