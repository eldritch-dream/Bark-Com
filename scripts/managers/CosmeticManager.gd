extends Node
# class_name _CosmeticManager
# class_name CosmeticManager

# Static Database
static var database: Dictionary = {}


static func ensure_init():
	if database.is_empty():
		_register_defaults()


static func _register_defaults():
	# 1. Top Hat
	_add_item("top_hat", "Top Hat", "HEAD", "Rank:3", Color.BLACK)
	# 2. Cone of Shame
	_add_item("cone_shame", "Cone of Shame", "HEAD", "Sanity:20", Color(0.9, 0.9, 0.9, 0.5))
	# 3. Tactical Vest
	_add_item("tac_vest", "Tactical Vest", "BACK", "Class:Heavy", Color(0.2, 0.2, 0.2))
	# 4. Monocle
	_add_item("monocle", "Monocle", "HEAD", "Class:Sniper", Color.GOLD)
	# 5. Bandana (Red)
	_add_item("bandana_red", "Bandana (Red)", "HEAD", "Default", Color.RED)
	# 6. Bow Tie
	_add_item("bow_tie", "Bow Tie", "BACK", "Default", Color.BLACK)
	# 7. Medkit Pack
	_add_item("medkit_pack", "Medkit Pack", "BACK", "Class:Paramedic", Color.WHITE)
	# 8. Antenna
	_add_item("antenna", "Antenna", "HEAD", "Class:Scout", Color.GRAY)
	# 9. NVG
	_add_item("nvg", "Night Vision", "HEAD", "Rank:5", Color.GREEN)
	# 10. Crown
	_add_item("crown", "Crown", "HEAD", "Rank:10", Color.GOLD)


static func _add_item(id, name, slot, req, color = Color.WHITE):
	var item = CosmeticItem.new()
	item.id = id
	item.display_name = name
	item.slot = slot
	item.unlock_condition = req
	item.color_override = color
	database[id] = item


static func get_unlocked_items(unit) -> Array:
	ensure_init()
	var unlocked = []
	for id in database:
		if _check_requirement(unit, database[id].unlock_condition):
			unlocked.append(database[id])
	return unlocked


static func _check_requirement(unit, req: String) -> bool:
	if req == "Default":
		return true

	var parts = req.split(":")
	var type = parts[0]
	var val = parts[1] if parts.size() > 1 else ""

	match type:
		"Rank":
			return unit.rank_level >= int(val)
		"Class":
			return unit.current_class_data and unit.current_class_data.display_name == val
		"Sanity":
			return unit.current_sanity <= int(val)
	return false


static func get_mesh_for_item(id: String) -> Mesh:
	ensure_init()
	# ... (Rest of logic is fine, just accessing database)
	var item = database.get(id)
	if not item:
		return null

	match id:
		"top_hat":
			var m = CylinderMesh.new()
			m.top_radius = 0.15
			m.bottom_radius = 0.15
			m.height = 0.3
			return m
		"cone_shame":
			var m = CylinderMesh.new()
			m.top_radius = 0.3
			m.bottom_radius = 0.1
			m.height = 0.3
			return m
		"tac_vest":
			var m = BoxMesh.new()
			m.size = Vector3(0.4, 0.1, 0.4)
			return m
		"monocle":
			var m = CylinderMesh.new()
			m.top_radius = 0.05
			m.bottom_radius = 0.05
			m.height = 0.02
			return m
		"crown":
			var m = CylinderMesh.new()
			m.top_radius = 0.2
			m.bottom_radius = 0.15
			m.height = 0.1
			return m
		_:
			var m = BoxMesh.new()
			m.size = Vector3(0.1, 0.1, 0.1)
			return m
