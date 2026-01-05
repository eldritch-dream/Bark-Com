class_name ClassIconManager
extends RefCounted

const SHEET_PATH = "res://assets/ui/class_icons_sheet.jpg"

# Cache
static var _atlas_texture: Texture2D
static var _icons = {}

static func get_class_icon(c_name: String) -> Texture2D:
	if not _atlas_texture:
		if ResourceLoader.exists(SHEET_PATH):
			_atlas_texture = load(SHEET_PATH)
		
			# Fallback: Load Image directly (if Import failed)
		if not _atlas_texture:
			# Image.load_from_file is static and returns Image or null
			var img = Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
			if img:
				_atlas_texture = ImageTexture.create_from_image(img)
			else:
				push_error("ClassIconManager: Failed to load image from " + SHEET_PATH)
				return null
	
	if not _atlas_texture:
		return null

	if _icons.has(c_name):
		return _icons[c_name]
		
	# Create AtlasTexture logic
	# Grid is 3x3. Assuming square image.
	var w = _atlas_texture.get_width() / 3
	var h = _atlas_texture.get_height() / 3
	
	# Mapping based on prompt order:
	# Row 1: Recruit, Sniper, Gunner
	# Row 2: Medic, Scout, Tank
	# Row 3: Rusher, Spitter, Whisperer
	
	var row = 0
	var col = 0
	
	match c_name:
		"Recruit": 
			row = 0; col = 0
		"Sniper": 
			row = 0; col = 1
		"Gunner": 
			row = 0; col = 2
		"Medic": 
			row = 1; col = 0
		"Scout": 
			row = 1; col = 1
		"Tank", "Heavy": 
			row = 1; col = 2
		"Rusher": 
			row = 2; col = 0
		"Spitter": 
			row = 2; col = 1
		"Whisperer": 
			row = 2; col = 2
		_:
			# Default/Fallback (Recruit)
			row = 0; col = 0
			
	var atlas = AtlasTexture.new()
	atlas.atlas = _atlas_texture
	atlas.region = Rect2(col * w, row * h, w, h)
	
	_icons[c_name] = atlas
	return atlas
