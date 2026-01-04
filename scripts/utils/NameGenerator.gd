extends Node

var recruit_names: Array[String] = [
	# Human Names
	"Camille",
	"Ryan",
	"Jim",
	"Steve",
	"Walter",
	"Linda",
	"Kevin",
	"Barbara",
	"Gregory",
	"Susan",
	# Heavy Duty
	"Tank",
	"Bruiser",
	"Fang",
	"Dozer",
	"Rex",
	"Kane",
	"Vandal",
	"Grizzly",
	"Chopper",
	"Brick",
	"Titan",
	"Blitz",
	"Butch",
	"Spike",
	"Major",
	# Small but Mighty
	"Biscuit",
	"Nugget",
	"Waffles",
	"Pip",
	"Beans",
	"Mochi",
	"Tater Tot",
	"Jellybean",
	"Button",
	"Noodle",
	"Socks",
	"Pudding",
	"Shortstack",
	"Spud",
	"Loaf",
	# Tactical
	"Radar",
	"Echo",
	"Gizmo",
	"Sergeant Sniffs",
	"Lieutenant Licks",
	"Chewbarka",
	"Bark Twain",
	"Sherlock Bones",
	"Captain Cuddles",
	"Private Paws"
]

var enemy_prefixes: Array[String] = [
	"A lesser",
	"A fragment of",
	"The shadow of",
	"A reflection of",
	"The echo of",
	"A sliver of",
	"The memory of",
	"A servant of",
	"The ghost of",
	"An aspect of"
]

var enemy_names_abstract: Array[String] = [
	"The Nameless Mist",
	"The Crawling Chaos",
	"The Unseen",
	"The Void Stalker",
	"The Geometry of Guilt",
	"The Whispering Shadow",
	"The Absent God",
	"The Grey Noise",
	"The Entropy",
	"The Unbidden"
]

var enemy_names_fleshy: Array[String] = [
	"The Biomass",
	"The Many-Mouthed",
	"The Flesh Weaver",
	"The Carrion King",
	"The Bloat",
	"The Slithering Hunger",
	"The Gristle Lord",
	"The Weeping Sore",
	"The Bone Knitter",
	"The Viscera"
]

var enemy_names_suburbia: Array[String] = [
	"The False Mailman",
	"The Vacuum Void",
	"The Dark Hydrant",
	"The Twisted Leash",
	"The Infinite Fence",
	"The Stranger at the Door",
	"The Shadow Cat",
	"The Bad Neighbor",
	"The Lawn that Eats",
	"The Thunder-Clap"
]

var enemy_names_aquatic: Array[String] = [
	"The Deep One",
	"The Drowned God",
	"The Tide Walker",
	"The Abyssal Gaze",
	"The Wet Nurse",
	"The Coral Mind",
	"The Brine",
	"The Trench Dweller",
	"The Sucker-Arm",
	"The Ink"
]

var enemy_names_boss: Array[String] = [
	"He Who Waits",
	"The King in Yellow",
	"The Black Goat",
	"The Star-Spawn",
	"The Mind Flayer",
	"The World Eater",
	"The Final Silence",
	"The Harbinger",
	"The Pale Rider",
	"The End of Days"
]


func get_random_name(existing_names: Array = []) -> String:
	# Filter out used names
	var pool = recruit_names.filter(func(n): return not existing_names.has(n))

	if pool.is_empty():
		return "Rekruit " + str(randi() % 1000)

	return pool.pick_random()


func get_random_enemy_name(type_tag: String = "Generic") -> String:
	var prefix = enemy_prefixes.pick_random()
	var name_pool = []

	match type_tag:
		"Abstract":
			name_pool = enemy_names_abstract
		"Fleshy":
			name_pool = enemy_names_fleshy
		"Suburbia":
			name_pool = enemy_names_suburbia
		"Aquatic":
			name_pool = enemy_names_aquatic
		"Boss":
			# Bosses might not get prefixes? Or maybe "Avatar of..."
			# User said: "Prefix for lower-tier enemies"
			return enemy_names_boss.pick_random()
		_:
			# Mix non-boss
			name_pool = (
				enemy_names_abstract
				+ enemy_names_fleshy
				+ enemy_names_suburbia
				+ enemy_names_aquatic
			)

	var core_name = name_pool.pick_random()
	return prefix + " " + core_name
