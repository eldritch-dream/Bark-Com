extends "res://scripts/entities/ObjectiveUnit.gd"
class_name LootCrate

# Config
@export var loot_table: Array[Resource] = []  # Array[ConsumableData]


func _ready():
	super._ready()
	unit_name = "Supply Crate"
	faction = "Neutral"
	can_be_targeted = false
	add_to_group("Interactive") # Required for Main.gd interaction check

	# Visuals (Box)
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	mesh_inst.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.GOLD
	mesh_inst.material_override = mat
	add_child(mesh_inst)


var grid_manager_ref
func initialize(pos: Vector2, _grid_manager = null):
	super.initialize(pos)
	
	# Fallback if not passed (Legacy spawner compatibility)
	if not _grid_manager:
		_grid_manager = get_tree().get_first_node_in_group("GridManager")
	
	grid_manager_ref = _grid_manager
	# LootCrate specific logic
	if _grid_manager and "grid_data" in _grid_manager:
		if _grid_manager.has_method("register_item"):
			_grid_manager.register_item(pos, self)
		# No longer occupying "unit" slot, so it is walkable by default.


func interact(user_unit):
	print(user_unit.name, " interacts with Supply Crate!")

	# Grant Item
	var item_granted = false
	if loot_table.size() > 0:
		var item = loot_table.pick_random()
		if _give_item_to_unit(user_unit, item):
			item_granted = true
			SignalBus.on_request_floating_text.emit(
				position + Vector3(0, 2, 0), "Found " + item.display_name + "!", Color.YELLOW
			)
		else:
			SignalBus.on_request_floating_text.emit(
				position + Vector3(0, 2, 0), "Inventory Full!", Color.RED
			)

	# OM Notification removed - OM handles this in its own flow now.
		
	# Fallback self-destruction if NOT a mission objective (Active Mission != Retrieve?)
	# But actually, OM handles destruction for TreatBags.
	# If this is just random loot, we should destroy it if item taken.
	# Rely on OM? If OM didn't destroy it (because not Retrieve), we should?
	if item_granted and is_instance_valid(self):
		# Only destroy if NOT in TreatBags group (Mission Critical) or if we decide random loot persists?
		# For now, let's assume OM handles "TreatBags". If not TreatBag, destroy.
		if not is_in_group("TreatBags"):
			if grid_manager_ref and grid_manager_ref.has_method("remove_item"):
				grid_manager_ref.remove_item(grid_pos, self)
			queue_free()


func take_damage(_amount: int):
	# Immune to damage
	SignalBus.on_request_floating_text.emit(position + Vector3(0,2,0), "IMMUNE", Color.GRAY)



func _give_item_to_unit(unit, item) -> bool:
	if "inventory" in unit:
		for i in range(unit.inventory.size()):
			if unit.inventory[i] == null:
				unit.inventory[i] = item
				print("Added ", item.display_name, " to ", unit.name, " slot ", i)
				return true
	return false
