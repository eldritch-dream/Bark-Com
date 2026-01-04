
func _build_survivor_data(u) -> Dictionary:
	var data = {
		"name": u.name,
		"hp": u.current_hp,
		"xp": u.current_xp,
		"level": u.rank_level,
		"sanity": u.current_sanity
	}
	# Sync Inventory (Persistence Fix)
	# Check property directly via get() regarding script vars
	var inv = u.get("inventory")
	if inv != null:
		data["inventory"] = inv
	elif "inventory" in u:
		data["inventory"] = u.inventory
		
	return data
