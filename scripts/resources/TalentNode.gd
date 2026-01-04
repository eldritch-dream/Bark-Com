extends Resource
class_name TalentNode

@export var display_name: String = "Talent"
@export var description: String = "Adds a bonus."
@export var icon: Texture2D
@export var stat_modifiers: Dictionary = {}  # e.g. {"mobility": 2, "max_hp": 1}
@export var ability_script: Script  # Optional: Script to Attach as Ability
@export var passive_tag: String = ""  # Optional: specialized tag checked by code (e.g. "low_profile")


# Helper to check if it grants an ability
func grants_ability() -> bool:
	return ability_script != null
