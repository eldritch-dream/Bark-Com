extends "res://scripts/entities/DestructibleCover.gd"
class_name VolatileCover

# Volatile Properties
@export var explosion_range: int = 3
@export var explosion_damage: int = 10
@export var fuse_turns: int = 1  # 0 = Instant, 1 = Next Turn

var fuse_timer: int = 0
var is_burning: bool = false
var fire_vfx_node: Node3D
var is_exploding: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()
	# Connect to Turn Signal to tick fuse
	if not SignalBus.on_turn_changed.is_connected(_on_turn_changed):
		SignalBus.on_turn_changed.connect(_on_turn_changed)


func take_damage(amount: int):
	take_damage_custom(amount, "Normal")


# OVERRIDE
func take_damage_custom(amount: int, damage_source_type: String = "Normal"):
	if has_meta("is_detonating"):
		return

	current_hp -= amount
	SignalBus.on_request_floating_text.emit(position, str(amount), Color.YELLOW)

	# Check for Detonation Triggers
	var should_detonate = false
	if current_hp <= 0:
		should_detonate = true
	elif fuse_turns <= 0:
		should_detonate = true

	if should_detonate:
		if damage_source_type == "Explosion":
			# CHAIN REACTION: Instant (No Camera)
			detonate()
		else:
			# PRIMARY TRIGGER: Cinematic
			_play_cinematic_sequence()
	else:
		# Delayed Fuse
		_start_fire()


func _start_fire():
	if is_burning:
		return
	is_burning = true
	fuse_timer = fuse_turns

	print(name, " is BURNING! Fuse: ", fuse_timer)
	SignalBus.on_request_floating_text.emit(position + Vector3(0, 2, 0), "BURNING!", Color.ORANGE)

	# Visuals: Fire Loop
	_spawn_fire_vfx()

	# If fuse is 0, detonate immediately (Used only if called directly, not via take_damage_custom cinematic path)
	if fuse_timer <= 0:
		detonate()


func _play_cinematic_sequence():
	# Mark as burning/busy so we don't double trigger
	is_burning = true
	
	print(name, " triggering Cinematic Explosion! Pos: ", position, " Global: ", global_position)
	
	# 1. Start Visuals (Flames)
	_spawn_fire_vfx()
	SignalBus.on_request_floating_text.emit(position + Vector3(0, 2, 0), "CRITICAL!", Color.RED)
	
	# 2. Camera Zoom
	SignalBus.on_request_camera_zoom.emit(position, 8.0, 2.0)
	
	# 3. Wait
	await get_tree().create_timer(2.0, true, false, true).timeout
	
	# 4. Boom
	detonate()


func _spawn_fire_vfx():
	var vfx_man = get_tree().get_first_node_in_group("VFXManager")
	if vfx_man and vfx_man.has_method("spawn_looping_vfx"):
		fire_vfx_node = vfx_man.spawn_looping_vfx("FireLoop", self)


func _on_turn_changed(phase, _turn_num):
	if not is_burning:
		return
	if phase == "PLAYER PHASE":  # Tick at start of player turn
		if is_exploding:
			return # Already handling it
			
		fuse_timer -= 1
		print(name, " fuse tick -> ", fuse_timer)
		
		if fuse_timer <= 0:
			is_exploding = true
			# Cinematic Sequence
			print(name, " is about to explode! Starting Cinematic...")
			SignalBus.on_cinematic_mode_changed.emit(true) # Block Input/Turns
			
			# 1. Zoom (2 seconds total: 0.5s in, 1.5s hold/out)
			# We'll request 2.0s duration.
			SignalBus.on_request_camera_zoom.emit(position, 8.0, 2.0)
			
			# 2. Wait for camera + flames
			# We await 2.0s to let the player admire the impending doom
			print(name, " awaiting timer...")
			await get_tree().create_timer(2.0, true, false, true).timeout
			print(name, " timer done. Detonating!")
			
			# 3. Detonate (Camera will auto-reset after 2.0s + reset time)
			detonate()
			
			# Release Cinematic (in case detonate didn't kill us immediately, though it should)
			SignalBus.on_cinematic_mode_changed.emit(false)


func detonate():
	if is_burning and fuse_timer < 0:
		return  # Already detonated?
	# Better guard:
	if current_hp <= 0 and not is_burning and fuse_turns > 0:
		# Edge case logic, but simplest is a distinct flag.
		pass

	# RECURSION GUARD:
	# If we are already exploding, don't explode again.
	if has_meta("is_detonating"):
		return
	set_meta("is_detonating", true)

	print(name, " DETONATES!")

	# 1. Spawn VFX
	SignalBus.on_request_vfx.emit("Explosion", position, Vector3.ZERO, null, null)
	SignalBus.on_request_floating_text.emit(position + Vector3(0, 3, 0), "BOOM!", Color.RED)

	# 2. Deal Damage (AOE)
	# Find all Units and Volatile Objects in range
	var center = grid_pos

	# Units
	var units = get_tree().get_nodes_in_group("Units")
	for unit in units:
		if is_instance_valid(unit) and not unit.is_dead:
			var dist = center.distance_to(unit.grid_pos)
			if dist <= explosion_range:
				if unit.has_method("take_damage"):
					print(" - Explosion hits unit ", unit.name)
					unit.take_damage(explosion_damage)

	# Other Volatile Objects (Chain Reaction)
	var props = get_tree().get_nodes_in_group("Destructible")
	for p in props:
		# Resolve actual script object
		var prop = p
		if p is StaticBody3D:
			prop = p.get_parent()

		if is_instance_valid(prop) and prop != self and "grid_pos" in prop:
			var dist = center.distance_to(prop.grid_pos)
			if dist <= explosion_range:
				if prop.has_method("take_damage_custom"):
					print(" - Explosion hits prop ", prop.name)
					prop.take_damage_custom(999, "Explosion")  # Trigger Instant
				elif prop.has_method("take_damage"):
					prop.take_damage(999)  # Destroy normal cover

	# 3. Destroy Self
	# Remove Fire VFX if valid
	if fire_vfx_node and is_instance_valid(fire_vfx_node):
		fire_vfx_node.queue_free()

	destroy()  # Parent method
