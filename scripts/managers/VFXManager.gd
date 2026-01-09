extends Node
class_name VFXManager

# Singleton
static var instance: VFXManager

var vfx_library = {
	"MuzzleFlash": preload("res://assets/vfx/MuzzleFlash.tscn"),
	"BloodSplatter": preload("res://assets/vfx/BloodSplatter.tscn"),
	"HealSparkles": preload("res://assets/vfx/HealSparkles.tscn"),
	"Explosion": load("res://scripts/vfx/ExplosionVFX.gd"),
	"FireLoop": load("res://scripts/vfx/FireLoopVFX.gd")
}


func _init():
	if not instance:
		instance = self


func _ready():
	name = "VFXManager"
	SignalBus.on_request_vfx.connect(spawn_vfx)


func spawn_vfx(
	vfx_name: String,
	global_pos: Vector3,
	rotation_vec: Vector3 = Vector3.ZERO,
	parent: Node = null,
	look_at_target = null
):
	if not vfx_library.has(vfx_name):
		print("VFXManager: Missing VFX -> ", vfx_name)
		return

	var res = vfx_library[vfx_name]
	var vfx
	if res is PackedScene:
		vfx = res.instantiate()
	elif res is Script:
		vfx = res.new()
	else:
		return

	if parent:
		parent.add_child(vfx)
	else:
		get_tree().root.add_child(vfx)

	vfx.global_position = global_pos

	if look_at_target != null and look_at_target is Vector3:
		vfx.look_at(look_at_target, Vector3.UP)
	elif rotation_vec != Vector3.ZERO:
		vfx.rotation = rotation_vec

	print("VFXManager: Spawned ", vfx_name, " at ", global_pos)


func spawn_looping_vfx(vfx_name: String, parent: Node) -> Node3D:
	if not vfx_library.has(vfx_name):
		print("VFXManager: Missing Looping VFX -> ", vfx_name)
		return null

	var res = vfx_library[vfx_name]
	var vfx
	if res is PackedScene:
		vfx = res.instantiate()
	elif res is Script:
		vfx = res.new()
	else:
		return null

	if parent:
		parent.add_child(vfx)
		vfx.position = Vector3.ZERO  # Local zero
	else:
		get_tree().root.add_child(vfx)

	print("VFXManager: Spawned Looping ", vfx_name)
	return vfx


func spawn_projectile(
	start_pos: Vector3, end_pos: Vector3, projectile_type: String, on_hit_callback: Callable
):
	# Create Projectile Mesh
	var proj = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	proj.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.DARK_GREEN if projectile_type == "Grenade" else Color.YELLOW
	proj.material_override = mat

	get_tree().root.add_child(proj)
	proj.global_position = start_pos

	# Parabolic Arc Tween
	var duration = 0.8
	var peak_height = 4.0

	var tween = create_tween()
	tween.set_parallel(true)

	# Motion Logic
	if projectile_type == "Bullet":
		# Direct Linear Shot (very fast)
		duration = 0.15 
		tween.tween_property(proj, "global_position", end_pos, duration)
		
	else:
		# Default / Grenade (Parabolic Arc)
		var mid_time = duration / 2.0
		tween.tween_property(proj, "global_position:x", end_pos.x, duration).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(proj, "global_position:z", end_pos.z, duration).set_trans(Tween.TRANS_LINEAR)
		
		(tween.tween_property(proj, "global_position:y", start_pos.y + peak_height, mid_time)
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD))
		(tween.chain().tween_property(proj, "global_position:y", end_pos.y, mid_time)
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD))

	# Rotate for fun
	var spin_tween = create_tween()  # Separate to not chain
	spin_tween.tween_property(proj, "rotation_degrees", Vector3(360, 360, 0), duration)

	# On Complete
	await tween.finished

	# Explosion VFX
	if projectile_type == "Grenade":
		spawn_vfx("Explosion", end_pos)

	proj.queue_free()

	# Execute Damage Logic
	if on_hit_callback:
		on_hit_callback.call()
