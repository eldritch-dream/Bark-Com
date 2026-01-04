extends "res://scripts/entities/DestructibleCover.gd"
class_name Terminal

signal hack_complete(success: bool)

var is_hacked: bool = false
var difficulty: int = 0  # Modifier to hack chance?
var can_be_targeted: bool = false # Ignored by Enemy AI


func _ready():
	# super._ready() calls _setup_visuals() via virtual method call,
	# preventing double mesh creation.
	super._ready()

	max_hp = 9999  # Terminals are indestructible visually (or override take_damage)
	current_hp = max_hp
	add_to_group("Terminals")


func take_damage(_amount: int):
	# Terminals are immune to damage
	SignalBus.on_request_floating_text.emit(position, "IMMUNE", Color.GRAY)


func _setup_visuals():
	# Override to look like a Terminal (Blue Box/Console)
	mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.0, 2.0, 1.0)  # High Cover
	mesh.mesh = box

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.2, 0.8)  # Tech Blue
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.5, 1.0)
	mat.emission_energy_multiplier = 1.0
	mesh.material_override = mat

	mesh.position.y = 1.0  # Center of 2.0 height
	add_child(mesh)

	# Add Screen/Keyboard detail?
	# Simple emissive material change on hack


func attempt_hack(user_tech_score: int) -> bool:
	if is_hacked:
		print("Terminal already hacked!")
		return false

	# Difficulty Check logic handled by Ability usually,
	# but we can return success here if we want the logic on the object.
	# Plan said 70% + TechScore. Let's do the random roll in the Ability
	# and just have this receive the result, OR have this calculate it.
	# "Hacking takes 1 Action Point and has a success chance (Base 70% + TechScore)"
	# Let's verify logic in Ability, and just have this method be "resolve_hack(success)".
	# But the method name in plan was attempt_hack.
	# Let's sticking to plan: Ability calculates chance, calls this if success?
	# Or Ability calls this to performing the attempt?
	# Better: Ability calculates chance, rolls, then calls `on_hack_result(success)`.
	return false


func on_hack_result(success: bool):
	if success:
		is_hacked = true
		_update_visuals_hacked()
		emit_signal("hack_complete", true)
		SignalBus.on_request_floating_text.emit(
			position + Vector3(0, 2.5, 0), "HACKED!", Color.GREEN
		)
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Menu")  # Placeholder for Hack Sound
	else:
		emit_signal("hack_complete", false)  # Failure trigger
		SignalBus.on_request_floating_text.emit(
			position + Vector3(0, 2.5, 0), "ACCESS DENIED", Color.RED
		)
		if GameManager and GameManager.audio_manager:
			GameManager.audio_manager.play_sfx("SFX_Miss")  # Placeholder for Error


func _update_visuals_hacked():
	if mesh and mesh.material_override:
		var mat = mesh.material_override
		mat.albedo_color = Color(0.0, 0.8, 0.2)  # Green
		mat.emission = Color(0.2, 1.0, 0.2)
