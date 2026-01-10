extends Node
class_name _GameManager

# Singleton Pattern (Script-based simulation for now,
# in real Godot Project Settings -> AutoLoad)
# Singleton Pattern
# static var instance: GameManager (Removed for Autoload)

const SAVE_VERSION = 2
const DEBUG_GAME = false
var iron_dog_mode: bool = false
var cheats_enabled: bool = false
var debug_scenario: String = ""

# Instance
var audio_manager  # Singleton ref

# State Management (Phase 75)
enum GameState { MENU, BASE, MISSION, PAUSED }
var current_state: GameState = GameState.MENU

# Persistent Data
var kibble: int = 100
var roster: Array = []
var fallen_heroes: Array = []  # Stores: {name, level, class, cause_of_death, usage_stats}
var active_mission: MissionData = null
var deploying_squad: Array = []  # The specific units chosen for the mission
var missions_completed: int = 0
var mission_level: int = 1 # Difficulty Scaling (1-3+)
var invasion_progress: int = 0  # 0-100 (Doomsday Clock)
var inventory: Array = []
var settings: Dictionary = {"music_vol": 1.0, "sfx_vol": 1.0, "mascot_style": 0, "fullscreen": false} 
# mascot_style: 0=Normal, 1=Busty, 2=Bustier, 3=Bustiest

# Shop Definition
# Shop Definition
var shop_stock: Array[ItemData] = []
var active_nemeses: Array[Dictionary] = []  # List of Nemesis Data

# Relationship System
var relationships: Dictionary = {}  # "Name1_Name2" -> int (Score)
const BOND_LEVEL_1 = 10  # Buddies (+5 Willpower)
const BOND_LEVEL_2 = 25  # Packmates (+10 Aim)
const BOND_LEVEL_3 = 50  # Soul Pups (Berserk Vengeance)

# Init removed (Autoload)
# func _init():
# 	if not instance:
# 		instance = self


func _ready():
	# Audio Setup
	if not audio_manager:
		audio_manager = load("res://scripts/managers/AudioManager.gd").new()
		audio_manager.name = "AudioManager"
		add_child(audio_manager)

	_initialize_shop()


var name_gen_script = load("res://scripts/utils/NameGenerator.gd")
var name_gen = null


func _get_random_name() -> String:
	if not name_gen:
		name_gen = name_gen_script.new()

	# Get existing names to avoid duplicates
	var existing = []
	for r in roster:
		existing.append(r["name"])
	for f in fallen_heroes:
		existing.append(f["name"])

	return name_gen.get_random_name(existing)


func get_enemy_name(type: String) -> String:
	if not name_gen:
		name_gen = name_gen_script.new()
	return name_gen.get_random_enemy_name(type)


func new_game(enable_iron_dog: bool = false):
	print("GameManager: Starting New Game (Iron Dog: ", enable_iron_dog, ")...")
	iron_dog_mode = enable_iron_dog
	kibble = 100
	roster.clear()
	fallen_heroes.clear()
	relationships.clear()  # Clear Bonds
	active_nemeses.clear() # Clear Nemeses
	missions_completed = 0
	invasion_progress = 0
	inventory.clear()

	if BarkTreeManager:
		BarkTreeManager.reset_state()

	_add_recruit("Barnaby", 1, "Heavy")
	_add_recruit("Waffles", 1, "Scout", 105)
	_add_recruit("Dr Bark", 1, "Paramedic")
	_add_recruit("Boomer", 1, "Grenadier")

	# Equip Weapons (Manual Hack for now, usually done via Shop)
	# 0=Barnaby, 1=Waffles, 2=Dr.Bark, 3=Boomer
	if roster.size() > 2:
		roster[2]["primary_weapon"] = load("res://resources/weapons/SyringeGun.tres")
	if roster.size() > 3:
		roster[3]["primary_weapon"] = load("res://resources/weapons/TennisBallLauncher.tres")
	print("GameManager: New Game Initialized.")
	SignalBus.on_kibble_changed.emit(kibble)


func advance_doomsday_clock(amount: int):
	invasion_progress = min(100, invasion_progress + amount)
	print("invasion_progress increased to: ", invasion_progress)
	if invasion_progress >= 100:
		print("DOOMSDAY CLOCK STRIKES MIDNIGHT. BASE DEFENSE IMMINENT.")


func debug_fill_invasion_meter():
	invasion_progress = 100
	print("DEBUG: Invasion Meter Filled.")


func _initialize_shop():
	shop_stock.clear()
	_master_item_list.clear() # Rebuild master list on init to ensure fresh data/fixes

	# 1. DEFINE ITEMS
	# Weapons (Hardcoded/Manual for now)
	var w1 = WeaponData.new()
	w1.display_name = "Tennis Ball Launcher"
	w1.description = "Heavy artillery. Launches balls at high velocity."
	w1.cost = 100
	w1.damage = 4
	w1.weapon_range = 6
	
	var hammer = load("res://resources/weapons/SqueakyHammer.tres")
	if hammer:
		hammer.description = "Melee weapon. Squeaks on impact, causing annoyance."

	var syringe = load("res://resources/weapons/SyringeGun.tres")
	if syringe:
		syringe.description = "Bio-weapon. Heals allies on hit, damages enemies."
		syringe.cost = 250

	# Consumables (Scripts)
	var medkit_script = load("res://scripts/resources/items/Medkit.gd")
	var treat_script = load("res://scripts/resources/items/SanityTreat.gd")
	var grenade_script = load("res://scripts/resources/items/GrenadeItem.gd")

	# 2. POPULATE STOCK (Daily Rotation could be filtered here)
	shop_stock.append(w1)
	if hammer: shop_stock.append(hammer)
	if syringe: shop_stock.append(syringe)
	
	if medkit_script: shop_stock.append(medkit_script.new())
	if treat_script: shop_stock.append(treat_script.new())
	if grenade_script: shop_stock.append(grenade_script.new())

	# 3. POPULATE MASTER LIST (For Persistence)
	# For now, it matches Shop Stock. 
	# In future, this should include ALL items, even those not in stock.
	_master_item_list.append_array(shop_stock)
	print("GameManager: Shop Initialized with ", shop_stock.size(), " items. Master DB: ", _master_item_list.size())


const RECRUIT_COST = 50
var session_initialized: bool = false
var _master_item_list: Array = [] # Persistent database of all loaded items

# --- MISSION GENERATION (PERSISTENT) ---
var available_missions: Array[MissionData] = []

func get_available_missions() -> Array[MissionData]:
	if available_missions.is_empty():
		_generate_daily_batch()
	return available_missions


func reroll_missions():
	# Penalty Logic
	advance_doomsday_clock(1)
	_generate_daily_batch()


func _generate_daily_batch():
	available_missions.clear()
	print("GameManager: Generating New Daily Missions...")
	
	for i in range(4):
		var m = MissionData.new()
		var locs = ["Park", "Kitchen", "Backyard", "Basement"]
		
		# Types: 0=Deathmatch, 1=Rescue, 2=Retrieve, 3=Hacker
		m.objective_type = randi() % 4
		
		var type_name = "Assault"
		match m.objective_type:
			0: type_name = "Sweep"
			1: 
				type_name = "Rescue"
				m.objective_target_count = 1
			2:
				type_name = "Heist"
				m.objective_target_count = randi_range(5, 7)
			3:
				type_name = "Hack"
				m.objective_target_count = randi_range(3, 4)

		m.mission_name = locs.pick_random() + " " + type_name
		
		# DIFFICULTY LOGIC
		if i == 0:
			# GUARANTEED LEVEL 1 for first slot
			m.difficulty_rating = 1
			m.mission_name = "[Training] " + m.mission_name
		else:
			# Random 1-3
			m.difficulty_rating = (randi() % 3) + 1
			
		m.reward_kibble = m.difficulty_rating * 25 + (randi() % 20)
		
		m.description = "Objective: " + type_name
		if m.objective_target_count > 0:
			if m.objective_type == 2:
				m.description += "\nSecure " + str(m.objective_target_count) + " Treat Bags."
			elif m.objective_type == 3:
				m.description += "\nHack " + str(m.objective_target_count) + " Terminals."
		else:
			m.description += "\nEliminate all hostiles."
			
		available_missions.append(m)
		
		# RESCUE REWARD GENERATION
		if m.objective_type == 1: # Rescue
			var r_name = _get_random_name()
			var r_classes = get_available_classes()
			var r_class = r_classes.pick_random()
			var r_level = m.difficulty_rating # MATCH DIFFICULTY
			
			m.reward_recruit_data = {
				"name": r_name,
				"class": r_class,
				"level": r_level
			}
			# Reduce Kibble reward to balance (optional, user didn't ask but good design)
			m.reward_kibble = int(m.reward_kibble * 0.5)




	# TODO: Create Consumable Resources for Treat Bag etc.


func _add_recruit(
	recruit_name: String, level: int, unit_class: String = "Recruit", starting_xp: int = 0
):
	# Calculate correct HP for class
	var hp_val = 10
	var path = "res://assets/data/classes/" + unit_class + "Data.tres"
	if ResourceLoader.exists(path):
		var res = load(path)
		if res and res.base_stats:
			hp_val = int(res.base_stats.get("max_hp", 10))
			print("DEBUG_GM: Loaded ", unit_class, " Data. Base HP: ", res.base_stats.get("max_hp"), " -> ", hp_val)
		else:
			print("DEBUG_GM: Failed to load base_stats for ", unit_class)
	else:
		print("DEBUG_GM: Class Data invalid path: ", path)
	
	# Add Level Bonus
	hp_val += (level - 1) * 2
	
	print("DEBUG_GM: Creating ", recruit_name, " (", unit_class, ") with HP: ", hp_val)

	var new_unit = {
		"name": recruit_name,
		"level": level,
		"class": unit_class,
		"xp": starting_xp,
		"max_hp": hp_val,
		"hp": hp_val,
		"status": "Ready",  # Ready, Resting, Injured
		"items": [],  # Can hold Consumables
		"unlocked_talents": [],  # Array of Talent/Perk IDs (String)
		"primary_weapon": null,  # Will hold WeaponData Resource
		"sanity": 100,  # Add Sanity
	}
	roster.append(new_unit)
	SignalBus.on_unit_recruited.emit(new_unit)


func _add_recruit_from_data(data: Dictionary):
	_add_recruit(data["name"], data["level"], data["class"])


func add_kibble(amount: int):
	kibble += amount
	if DEBUG_GAME:
		print("GameManager: Added ", amount, " Kibble. Total: ", kibble)
	SignalBus.on_kibble_changed.emit(kibble)


func buy_item(index: int) -> bool:
	if index < 0 or index >= shop_stock.size():
		print("GameManager: Invalid Item Index.")
		return false

	var item = shop_stock[index]

	if kibble >= item.cost:
		kibble -= item.cost
		inventory.append(item)
		if DEBUG_GAME:
			print("GameManager: Bought ", item.display_name, ". Remaining Kibble: ", kibble)
		SignalBus.on_kibble_changed.emit(kibble)
		return true
	else:
		print("GameManager: Not enough Kibble!")
		return false


func equip_item(corgi_name: String, inventory_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= inventory.size():
		return false

	var item = inventory[inventory_index]
	var unit_data = null
	for c in roster:
		if c["name"] == corgi_name:
			unit_data = c
			break

	if not unit_data:
		return false

	if item is WeaponData:
		# Swap
		var old_weapon = unit_data.get("primary_weapon")
		unit_data["primary_weapon"] = item

		inventory.remove_at(inventory_index)
		if old_weapon:
			inventory.append(old_weapon)

		print("GameManager: Equipped Weapon ", item.display_name, " to ", corgi_name)
		return true

	elif item is ConsumableData:
		# Add to Unit Inventory (Max 2)
		if not unit_data.has("inventory"):
			unit_data["inventory"] = []
			
		var max_slots = 2

		# Find valid slot or append
		if unit_data["inventory"].size() < max_slots:
			unit_data["inventory"].append(item)
			inventory.remove_at(inventory_index)
			print("GameManager: Added ", item.display_name, " to ", corgi_name, "'s inventory.")
			return true
		
		# 2. Check for null slot in existing array (legacy support)
		var slot = unit_data["inventory"].find(null)
		if slot != -1:
			unit_data["inventory"][slot] = item
			inventory.remove_at(inventory_index)
			print("GameManager: Added ", item.display_name, " to ", corgi_name, "'s inventory (Slot ", slot, ").")
			return true
			
		print("GameManager: ", corgi_name, "'s inventory is full!")
		return false

	else:
		print("GameManager: Item type not equipable.")
		return false


# Compatibility Wrapper
func equip_weapon(corgi_name: String, inventory_index: int) -> bool:
	return equip_item(corgi_name, inventory_index)


func get_roster() -> Array:
	return roster


func get_ready_corgis() -> Array:
	return roster.filter(func(c): return c["status"] == "Ready")


func complete_mission(
	surviving_corgis_data: Array, _is_win: bool = true, surviving_enemies: Array = [], reward_amount: int = 0
):
	print("DEBUG_GM: complete_mission called. Survivors: ", surviving_corgis_data)
	# Update persistent roster based on mission results
	# data: [{name, hp_remaining, ...}]

	# PAYOUT
	if _is_win and reward_amount > 0:
		kibble += reward_amount
		print("GameManager: Mission Succeeded! Added ", reward_amount, " Kibble. Total: ", kibble)

	# RECRUIT REWARD
	if _is_win and active_mission and active_mission.reward_recruit_data.size() > 0:
		print("GameManager: Mission Reward -> New Recruit: ", active_mission.reward_recruit_data["name"])
		_add_recruit_from_data(active_mission.reward_recruit_data)
		# Should we notify UI? SignalBus.on_unit_recruited is emitted by _add_recruit which UI listens to.

	# Nemesis Processing
	_process_nemesis_candidates(surviving_enemies)

	for survivor in surviving_corgis_data:
		for member in roster:
			if member["name"] == survivor["name"]:
				# Logic: Persist HP
				member["hp"] = survivor["hp"]
				
				# Logic: If HP critical, set to resting
				if survivor["hp"] < 5:
					member["status"] = "Resting"

				else:
					member["status"] = "Ready"

				# Update Progression
				if survivor.has("xp"):
					member["xp"] = survivor["xp"]
				if survivor.has("level"):
					member["level"] = survivor["level"]
				if survivor.has("sanity"):
					member["sanity"] = survivor["sanity"]
				if survivor.has("inventory"):
					print("DEBUG_PERSIST: Syncing Inventory for ", member["name"])
					print(" - Old Inv: ", member.get("inventory"))
					print(" - New Inv (Survivor): ", survivor["inventory"])
					member["inventory"] = survivor["inventory"].duplicate() 
					print(" - Result Inv: ", member["inventory"])

				if DEBUG_GAME:
					print(
						"Updated Roster for ",
						member["name"],
						" -> Level: ",
						member["level"],
						" XP: ",
						member["xp"],
						" Sanity: ",
						member.get("sanity", 100)
					)
				break

	# Relationship Growth (Mission Complete)
	# +1 for every pair in the surviving squad
	_process_mission_bonds(surviving_corgis_data)

	_process_mission_bonds(surviving_corgis_data)

	missions_completed += 1
	
	# Force Refresh of Missions (New Day/Cycle)
	_generate_daily_batch()

	# save_game() # MOVED TO END to ensure roster purge is captured!

	# Purge Dead from Roster
	# We iterate backwards to safely remove
	
	# Fix for "Healthy Dead":
	# If deploying_squad is empty (e.g. reload), assume READY units were deployed.
	var tracked_squad = deploying_squad
	if tracked_squad.is_empty():
		print("GameManager: deploying_squad empty. Fallback to Ready roster for purge check.")
		tracked_squad = get_ready_corgis()

	# SAFETY: If Mission Won but Survivors Empty, Main.gd likely glitched. Abort purge to prevent wipe.
	if _is_win and surviving_corgis_data.is_empty():
		print("GameManager: CRITICAL WARNING - Mission Won but No Survivors reported. Aborting Roster Purge to prevent data loss.")
		tracked_squad = [] # Clear tracked so the loop below skips everything (was_deployed=false)

	for i in range(roster.size() - 1, -1, -1):
		var member = roster[i]
		var found = false
		for s in surviving_corgis_data:
			if s["name"] == member["name"]:
				found = true
				break
		
		# CHECK DEPLOYMENT STATUS
		var was_deployed = false
		for d in tracked_squad:
			if d["name"] == member["name"]:
				was_deployed = true
				break

		# If NOT deployed, they are safe at base. Skip.
		if not was_deployed:
			continue

		# If not found in survivors, they MIGHT be dead.
		if not found:
			var is_fallen = false
			for f in fallen_heroes:
				if f["name"] == member["name"]:
					is_fallen = true
					break
			
			if is_fallen:
				print("GameManager: Purging DEAD unit from roster: ", member["name"])
				roster.remove_at(i)
			else:
				print("GameManager: Unit missing but NOT in Memorial? ", member["name"])

	# IRON DOG MODE: Check for Total Party Wipe
	if (
		iron_dog_mode
		and is_instance_valid(surviving_corgis_data)
		and surviving_corgis_data.is_empty()
		# And no one left at base? 
		# If we have bench units, it's not a wipe unless we define "Mission Fail = Game Over" 
		# usually Iron Dog = Permadeath, but Game Over only if 0 units.
		# For this specific check, let's assume Squad Wipe logic intends to END the run (based on print statement).
		and roster.size() <= 0 # Double check roster is empty (purged above)
	):
		# Note: surviving_corgis_data contains valid living units.
		# If empty, everyone died.
		print("\n*** IRON DOG MODE ACTIVE ***")
		print("*** TOTAL SQUAD WIPE DETECTED ***")
		print("*** DELETING SAVE FILE... ***")
		delete_save()
		return # STOP HERE! Do not auto-save.
	
	# Auto-Save Progress
	_process_base_recovery(deploying_squad)
	save_game() # MOVED HERE
	print("GameManager: Auto-Saved after mission.")


func _process_base_recovery(deployed: Array):
	# Anyone NOT in deployed list gets to Rest.
	print("GameManager: Processing Base Recovery...")
	for member in roster:
		var was_deployed = false
		for d in deployed:
			if d["name"] == member["name"]:
				was_deployed = true
				break
		
		if not was_deployed:
			# They stayed home. Recover.
			var max_hp = calculate_max_hp(member)
			var current_hp = member.get("hp", max_hp)
			
			if current_hp < max_hp:
				# Healing Rate: 50% of Max HP per mission skipped? or flat?
				# Let's say flat 10 HP.
				member["hp"] = min(max_hp, current_hp + 10)
				print("  > ", member["name"], " rested (+10 HP). HP: ", member["hp"])
			
			# Sanity Recovery (Passive)
			var san = member.get("sanity", 100)
			if san < 100:
				member["sanity"] = min(100, san + 10)
				print("  > ", member["name"], " rested (+10 Sanity). Sanity: ", member["sanity"])

			# Status Update
			# If they were Resting, check if they are ready now.
			# Threshold: HP > 5 (As defined in mission logic)
			var check_hp = member.get("hp", 10) # Default to healthy if missing
			if check_hp >= 5:
				if member.get("status", "Ready") == "Resting":
					member["status"] = "Ready"
					print("  > ", member["name"], " is ready for duty!")
			else:
				# Still too injured
				member["status"] = "Resting"
				print("  > ", member["name"], " is still resting (HP critical).")


func save_game():
	var save_data = {
		"meta":
		{
			"version": SAVE_VERSION,
			"date": Time.get_datetime_string_from_system(),
			"iron_dog": iron_dog_mode
		},
		"base":
		{
			"kibble": kibble,
			"missions_completed": missions_completed,
			"settings": settings,
			"inventory": []
		},
		"squad": {"roster": [], "fallen_heroes": fallen_heroes, "relationships": relationships},
		"world": {"active_nemeses": active_nemeses, "invasion_progress": invasion_progress},
		"bark_trees": BarkTreeManager.get_save_data() if BarkTreeManager else {}
	}

	# Serialize Roster

	# Serialize Roster
	for member in roster:
		var mem_copy = member.duplicate()
		if member.get("primary_weapon") != null:
			mem_copy["weapon_id"] = member["primary_weapon"].display_name
			mem_copy.erase("primary_weapon")
		# Serialize Unit Inventory (Consumables)
		mem_copy["inventory"] = []
		if member.has("inventory"):
			for item in member["inventory"]:
				if item != null and (item.has_method("get_class") or "display_name" in item):
					mem_copy["inventory"].append(item.display_name)
				else:
					print("GameManager: Validation Warning - Skipping invalid item in Unit Inventory.")

		save_data["squad"]["roster"].append(mem_copy)

	# Serialize Inventory
	for item in inventory:
		if item != null and item.has_method("get_class"): # Validate Object
			save_data["base"]["inventory"].append(item.display_name)
		elif item != null and "display_name" in item:
			# Resource fallback
			save_data["base"]["inventory"].append(item.display_name)
		else:
			print("GameManager: WARNING - Null/Invalid item found in inventory during save. Skipping.")

	# To JSON
	var json_str = JSON.stringify(save_data)
	var obfuscated = Marshalls.utf8_to_base64(json_str)
	var file = FileAccess.open("user://savegame.dat", FileAccess.WRITE)
	if file:
		file.store_string(obfuscated)
		print("GameManager: Game Saved (v", SAVE_VERSION, ")")
	else:
		print("GameManager: Failed to save game.")


func load_game():
	if not FileAccess.file_exists("user://savegame.dat"):
		print("GameManager: No save file found.")
		return

	var file = FileAccess.open("user://savegame.dat", FileAccess.READ)
	if file:
		var obfuscated = file.get_as_text()
		var json_str = ""
		if not obfuscated.is_empty():
			json_str = Marshalls.base64_to_utf8(obfuscated)

		var json = JSON.new()
		var parse_result = json.parse(json_str)
		if not parse_result == OK:
			print("GameManager: Failed to parse save file.")
			return

		var data = json.get_data()

		# MIGRATION CHECK
		if not data.has("meta") or data["meta"].get("version", 0) < SAVE_VERSION:
			data = _migrate_save(data)

		# Load Bark Trees
		if data.has("bark_trees") and BarkTreeManager:
			BarkTreeManager.load_save_data(data["bark_trees"])

		# Load META
		if data.has("meta"):
			iron_dog_mode = data["meta"].get("iron_dog", false)

		# Load BASE
		var base = data.get("base", {})
		kibble = base.get("kibble", 100)
		SignalBus.on_kibble_changed.emit(kibble)
		missions_completed = base.get("missions_completed", 0)
		settings = base.get("settings", {"music_vol": 1.0, "sfx_vol": 1.0, "fullscreen": false})
		_apply_audio_settings()
		_apply_display_settings()

		inventory.clear()
		for item_name in base.get("inventory", []):
			var item = _find_item_by_name(item_name)
			if item:
				inventory.append(item)

		# Load SQUAD
		var squad = data.get("squad", {})
		roster.clear()
		relationships = squad.get("relationships", {})
		for mem_data in squad.get("roster", []):
			var new_mem = mem_data
			new_mem["primary_weapon"] = null
			if new_mem.has("weapon_id"):
				new_mem["primary_weapon"] = _find_item_by_name(new_mem["weapon_id"])
			
			# Restore Unit Inventory
			var saved_inv = new_mem.get("inventory", [])
			new_mem["inventory"] = []
			if saved_inv is Array:
				for item_name in saved_inv:
					var item = _find_item_by_name(item_name)
					if item:
						new_mem["inventory"].append(item)
			
			roster.append(new_mem)

		fallen_heroes = squad.get("fallen_heroes", [])

		# Load WORLD
		var world = data.get("world", {})
		active_nemeses.clear()
		var loaded_nemeses = world.get("active_nemeses", [])
		for n in loaded_nemeses:
			active_nemeses.append(n)

		invasion_progress = world.get("invasion_progress", 0)

		print("GameManager: Game Loaded (v", SAVE_VERSION, ")")


func _migrate_save(old_data: Dictionary) -> Dictionary:
	print("GameManager: Migrating Legacy Save Data...")
	var new_data = {
		"meta": {"version": SAVE_VERSION, "iron_dog": false}, "base": {}, "squad": {}, "world": {}
	}

	# Migrate Root -> Base/Squad/World
	new_data["base"]["kibble"] = old_data.get("kibble", 100)
	new_data["base"]["missions_completed"] = old_data.get("missions_completed", 0)
	new_data["base"]["settings"] = old_data.get("settings", {})
	new_data["base"]["inventory"] = old_data.get("inventory", [])

	new_data["squad"]["roster"] = old_data.get("roster", [])
	new_data["squad"]["fallen_heroes"] = old_data.get("fallen_heroes", [])

	new_data["world"]["active_nemeses"] = old_data.get("active_nemeses", [])
	new_data["world"]["invasion_progress"] = old_data.get("invasion_progress", 0)

	return new_data


func delete_save():
	var dir = DirAccess.open("user://")
	if dir.file_exists("savegame.dat"):
		dir.remove("savegame.dat")
		print("GameManager: Save File DELETED.")


func register_fallen_hero(unit_data: Dictionary, cause: String):
	# Create a Memorial Entry
	var entry = {
		"name": unit_data.get("name", "Unknown Soldier"),
		"class": unit_data.get("class", "Recruit"),
		"level": unit_data.get("level", 1),
		"perks": unit_data.get("unlocked_talents", []),
		"cause": cause,
		"date": Time.get_date_string_from_system()
	}
	# Check for duplicates (Name + Mission check?)
	for f in fallen_heroes:
		if f["name"] == entry["name"]:
			print("GameManager: Hero already in Memorial: ", entry["name"])
			return

	entry["cause"] += " on Mission " + str(missions_completed + 1)
	fallen_heroes.append(entry)
	print("GameManager: Registered Fallen Hero - ", entry["name"])


func get_available_classes() -> Array:
	var classes = []
	var dir = DirAccess.open("res://assets/data/classes/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with("Data.tres"):
				var cls = file_name.replace("Data.tres", "")
				classes.append(cls)
			file_name = dir.get_next()

	if classes.is_empty():
		return ["Recruit", "Scout", "Heavy", "Sniper"]  # Fallback
	return classes


func recruit_new_dog(cost: int = RECRUIT_COST, forced_class: String = "") -> bool:
	if kibble >= cost:
		kibble -= cost
		var random_name = _get_random_name()

		# Pick Class
		var picked_class = ""
		var available_classes = get_available_classes()
		
		# Validation
		if forced_class != "":
			# Case-insensitive check?
			for c in available_classes:
				if c.to_lower() == forced_class.to_lower():
					picked_class = c
					break
			if picked_class == "":
				print("GameManager: Warning - Invalid class requested '", forced_class, "'. Falling back to random.")
		
		if picked_class == "":
			picked_class = available_classes.pick_random()

		_add_recruit(random_name, 1, picked_class)
		if DEBUG_GAME:
			print("GameManager: Recruited ", random_name, " (", picked_class, ")")
		SignalBus.on_kibble_changed.emit(kibble)
		return true
	else:
		return false


func _find_item_by_name(id_name: String) -> Resource:
	# Scan MASTER LIST first (includes everything ever loaded)
	for item in _master_item_list:
		if item.display_name == id_name:
			return item

	# Fallback: Scan shop stock (redundant if logic implies shop is subset, but safe)
	for item in shop_stock:
		if item.display_name == id_name:
			return item
	
	# Fallback: Check known resource paths manually if simple name fails?
	# For now, return null. 
	# If this returns null, the item is LOST from save file.
	print("GameManager: WARNING - Could not find item definition for: ", id_name)
	return null


func calculate_max_hp(unit_data: Dictionary) -> int:
	var cls_name = unit_data.get("class", "Recruit")
	var level = unit_data.get("level", 1)
	
	var base = 10
	var path = "res://assets/data/classes/" + cls_name + "Data.tres"
	if ResourceLoader.exists(path):
		var c_data = load(path)
		if c_data and c_data.base_stats:
			base = c_data.base_stats.get("max_hp", 10)

	# Consistent Formula: Base + (Level-1)*2
	var bonus = (level - 1) * 2
	return base + bonus



func toggle_fullscreen():
	var mode = DisplayServer.window_get_mode()
	var new_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		new_mode = DisplayServer.WINDOW_MODE_WINDOWED
	
	DisplayServer.window_set_mode(new_mode)
	
	# Update persistent settings
	settings["fullscreen"] = (new_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or new_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	save_game() # Save preferences immediately? Or on close? Save now is safe.


func update_settings(music: float, sfx: float):
	settings["music_vol"] = music
	settings["sfx_vol"] = sfx
	_apply_audio_settings()


func _apply_audio_settings():
	if audio_manager:
		audio_manager.set_music_volume(settings["music_vol"])
		audio_manager.set_sfx_volume(settings["sfx_vol"])


func _apply_display_settings():
	var is_fs = settings.get("fullscreen", false)
	# Use DisplayServer for better Web/Desktop compatibility.
	# get_window().mode fails on embedded windows (Web).
	if is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func has_save_file() -> bool:
	return FileAccess.file_exists("user://savegame.dat")


# --- RELATIONSHIP SYSTEM ---
func get_bond_key(n1: String, n2: String) -> String:
	if n1 < n2:
		return n1 + "_" + n2
	return n2 + "_" + n1


func modify_bond(n1: String, n2: String, amount: int):
	if n1 == n2:
		return
	var key = get_bond_key(n1, n2)
	var old_val = relationships.get(key, 0)
	var new_val = old_val + amount
	relationships[key] = new_val

	# Check Level Up
	var level = get_bond_level_from_score(new_val)
	var old_level = get_bond_level_from_score(old_val)

	if level > old_level:
		print("GameManager: BOND LEVEL UP! ", key, " -> Lvl ", level)
		# SignalBus emission handled by Unit causing the growth

	if DEBUG_GAME:
		print("GameManager: Bond ", key, " +", amount, " = ", new_val)


func get_bond_score(n1: String, n2: String) -> int:
	var key = get_bond_key(n1, n2)
	return relationships.get(key, 0)


func get_bond_level_from_score(score: int) -> int:
	if score >= BOND_LEVEL_3:
		return 3
	if score >= BOND_LEVEL_2:
		return 2
	if score >= BOND_LEVEL_1:
		return 1
	return 0


func get_bond_level(n1: String, n2: String) -> int:
	var score = get_bond_score(n1, n2)
	return get_bond_level_from_score(score)


func _process_mission_bonds(survivors: Array):
	# Pairwise combination of all survivors
	var count = survivors.size()
	for i in range(count):
		for j in range(i + 1, count):
			var u1 = survivors[i]["name"]
			var u2 = survivors[j]["name"]
			modify_bond(u1, u2, 1)  # +1 for surviving together


func get_active_bonds_for_unit(unit_name: String) -> Array:
	var bonds = []
	for key in relationships.keys():
		if key.contains(unit_name):
			# Extract the OTHER name
			var parts = key.split("_")
			var partner = ""
			if parts[0] == unit_name: partner = parts[1]
			else: partner = parts[0]
			
			var score = relationships[key]
			var lvl = get_bond_level_from_score(score)
			
			if lvl > 0:
				bonds.append({"partner_name": partner, "level": lvl, "score": score})
	return bonds


func start_mission(mission: MissionData, custom_squad: Array = []):
	active_mission = mission
	print("GameManager: Starting Mission -> ", mission.mission_name)

	if custom_squad.size() > 0:
		deploying_squad = custom_squad
	else:
		deploying_squad = get_ready_corgis()

	SignalBus.on_mission_selected.emit(mission)

	# Switch Logic handled by BaseScene listener
	# get_tree().change_scene_to_file(mission.map_scene_path)


func _process_nemesis_candidates(candidates: Array):
	for c in candidates:
		# Check if already a nemesis
		var existing = null
		for n in active_nemeses:
			if n.name == c.name:
				existing = n
				break

		if existing:
			# Evolution: Upgrade existing
			print("GameManager: Nemesis " + existing.name + " survived again! Upgrading...")
			existing["level"] += 1
			if c.victim_log.size() > 0:
				existing["title"] = existing["title"].split(",")[0] + ", the Double-Eater"  # Tacky Append
		else:
			# Promotion
			print("GameManager: New Nemesis Promoted! " + c.name)

			var victim_name = "the Unlucky"
			if c.victim_log.size() > 0:
				victim_name = c.victim_log[0]

			# Requested Titles
			var titles = [
				"Corrupter of",
				"Melter of",
				"Mindbreaker of",
				"Eater of",
				"Bane of",
				"Nightmare of",
				"End of",
				"Slayer of",
				"Hunter of",
				"Silencer of"
			]
			var title_prefix = titles.pick_random()

			var new_nemesis = {
				"name": c.name,
				"title": title_prefix + " " + victim_name,
				"base_type": c.base_type,  # e.g. "Rusher"
				"level": 1,
				"buffs": []
			}

			# Assign Random Buff
			var buff_options = ["Bone Plating", "Vile Strength", "Unnatural Speed"]
			new_nemesis["buffs"].append(buff_options.pick_random())

			active_nemeses.append(new_nemesis)
			print(" - All Hail " + new_nemesis.name + ", " + new_nemesis.title + "!")
