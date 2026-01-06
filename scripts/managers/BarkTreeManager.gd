extends Node

# Dictionary mapping Unit GUID (String) -> Array[PerkID (String)]
# Example: { "unit_123": ["recruit_cardio", "recruit_vigilance"] }
var unlocked_perks: Dictionary = {}

func _ready():
	print("BarkTreeManager initialized.")

func unlock_perk(unit_guid: String, perk_id: String):
	if not unlocked_perks.has(unit_guid):
		unlocked_perks[unit_guid] = []
	
	if not perk_id in unlocked_perks[unit_guid]:
		unlocked_perks[unit_guid].append(perk_id)
		print("BarkTreeManager: Unlocked ", perk_id, " for unit ", unit_guid)
		# Save logic would go here (or be handled by GameManager saving everything)
		SignalBus.on_perk_learned.emit(unit_guid, perk_id)
		SignalBus.on_unit_stats_changed.emit(null) # Null unit forces global update? Or pass unit if we had it.

func has_perk(unit_guid: String, perk_id: String) -> bool:
	if unlocked_perks.has(unit_guid):
		return perk_id in unlocked_perks[unit_guid]
	return false

func get_unlocked_perks(unit_guid: String) -> Array:
	return unlocked_perks.get(unit_guid, [])

# Persistence Methods (Called by GameManager)
func get_save_data() -> Dictionary:
	return unlocked_perks

func load_save_data(data: Dictionary):
	if data:
		unlocked_perks = data
		print("BarkTreeManager: Loaded perk data.")
