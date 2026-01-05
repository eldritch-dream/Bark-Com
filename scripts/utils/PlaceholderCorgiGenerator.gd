extends RefCounted
class_name PlaceholderCorgiGenerator


static func generate_corgi(parent: Node3D) -> Dictionary:
	# Returns { "anim_player": AnimationPlayer, "sockets": Dictionary }

	# 1. Root Pivot (Center of mass)
	var root = Node3D.new()
	root.name = "CorgiRoot"
	parent.add_child(root)

	# Materials
	var fur_mat = StandardMaterial3D.new()
	fur_mat.albedo_color = Color(0.8, 0.52, 0.25)  # Peru-ish Color

	var white_mat = StandardMaterial3D.new()
	white_mat.albedo_color = Color.WHITE

	# 2. Body (Sausage)
	var body = MeshInstance3D.new()
	var body_mesh = CapsuleMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.2
	body_mesh.radial_segments = 16
	# Rotate capsule to be horizontal? Capsule is vertical by default (Y).
	# We want it along Z (forward/back) or X. Default forward is -Z.
	body_mesh.height = 1.0  # Shorten slightly

	body.mesh = body_mesh
	body.material_override = fur_mat
	body.rotation.x = deg_to_rad(-90)
	body.position.y = 0.4
	root.add_child(body)

	# 3. Head
	var head = MeshInstance3D.new()
	var head_mesh = BoxMesh.new()
	head_mesh.size = Vector3(0.5, 0.5, 0.5)
	head.mesh = head_mesh
	head.material_override = fur_mat
	head.position = Vector3(0, 0.5, -0.4)  # Forward/Up
	root.add_child(head)

	# Snout (Rounded)
	var snout = MeshInstance3D.new()
	var snout_mesh = CylinderMesh.new()
	snout_mesh.top_radius = 0.15  # Back (Base) - Wider
	snout_mesh.bottom_radius = 0.10  # Front (Tip) - Narrower
	snout_mesh.height = 0.3
	snout.mesh = snout_mesh
	snout.material_override = white_mat
	snout.position = Vector3(0, -0.1, -0.3)  # Front of head, lower
	snout.rotation.x = deg_to_rad(90)  # Point forward
	head.add_child(snout)

	# Nose Tip
	var nose = MeshInstance3D.new()
	var nose_mesh = SphereMesh.new()
	nose_mesh.radius = 0.08
	nose_mesh.height = 0.16
	nose.mesh = nose_mesh

	var black_mat = StandardMaterial3D.new()
	black_mat.albedo_color = Color.BLACK
	nose.material_override = black_mat
	# Local Y- is Forward because of Rotation X=90
	nose.position = Vector3(0, -0.15, 0)
	snout.add_child(nose)

	# Eyes
	var eye_mesh = SphereMesh.new()
	eye_mesh.radius = 0.06
	eye_mesh.height = 0.12

	var eye_l = MeshInstance3D.new()
	eye_l.mesh = eye_mesh
	eye_l.material_override = black_mat
	eye_l.position = Vector3(-0.15, 0.15, -0.22)
	head.add_child(eye_l)

	var eye_r = MeshInstance3D.new()
	eye_r.mesh = eye_mesh
	eye_r.material_override = black_mat
	eye_r.position = Vector3(0.15, 0.15, -0.22)
	head.add_child(eye_r)

	# Ears
	var ear_l = MeshInstance3D.new()
	var ear_mesh = PrismMesh.new()
	ear_mesh.size = Vector3(0.2, 0.3, 0.1)
	ear_l.mesh = ear_mesh
	ear_l.material_override = fur_mat
	ear_l.position = Vector3(-0.2, 0.35, 0)
	ear_l.rotation.z = deg_to_rad(15)
	head.add_child(ear_l)

	var ear_r = MeshInstance3D.new()
	ear_r.mesh = ear_mesh
	ear_r.material_override = fur_mat
	ear_r.position = Vector3(0.2, 0.35, 0)
	ear_r.rotation.z = deg_to_rad(-15)
	head.add_child(ear_r)

	# 4. Legs (Little Stubs)
	var leg_mesh = CylinderMesh.new()
	leg_mesh.top_radius = 0.1
	leg_mesh.bottom_radius = 0.1
	leg_mesh.height = 0.4

	var leg_positions = [
		Vector3(-0.25, 0.2, 0.3),  # Back Left
		Vector3(0.25, 0.2, 0.3),  # Back Right
		Vector3(-0.25, 0.2, -0.3),  # Front Left
		Vector3(0.25, 0.2, -0.3)  # Front Right
	]

	var legs = []
	for pos in leg_positions:
		var leg = MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.material_override = white_mat
		leg.position = pos
		root.add_child(leg)
		legs.append(leg)

	# 5. Sockets
	var sockets = {}

	# Head Socket (Hat)
	var head_socket = Node3D.new()
	head_socket.name = "Socket_Head"
	head_socket.position = Vector3(0, 0.3, 0)  # Top of head
	head.add_child(head_socket)
	sockets["Head"] = head_socket

	# Spine Socket (Backpack/Weapon)
	var spine_socket = Node3D.new()
	spine_socket.name = "Socket_Spine"
	spine_socket.position = Vector3(0, 0.3, 0)  # Top of body
	body.add_child(spine_socket)  # Attached to body mesh for rotation
	sockets["Spine"] = spine_socket

	# 6. AnimationPlayer
	var anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	parent.add_child(anim_player)

	# Create Library
	var lib = AnimationLibrary.new()

	# -- IDLE --
	var idle_anim = Animation.new()
	idle_anim.loop_mode = Animation.LOOP_LINEAR
	idle_anim.length = 2.0

	# Breathe (Scale/Pos of Body)
	var track = idle_anim.add_track(Animation.TYPE_VALUE)
	idle_anim.track_set_path(track, str(root.name) + "/" + str(body.name) + ":scale")
	idle_anim.track_insert_key(track, 0.0, Vector3.ONE)
	idle_anim.track_insert_key(track, 1.0, Vector3(1.02, 1.02, 1.0))
	idle_anim.track_insert_key(track, 2.0, Vector3.ONE)

	lib.add_animation("Idle", idle_anim)

	# -- RUN --
	var run_anim = Animation.new()
	run_anim.loop_mode = Animation.LOOP_LINEAR
	run_anim.length = 0.4

	# Bounce Body
	track = run_anim.add_track(Animation.TYPE_VALUE)
	run_anim.track_set_path(track, str(root.name) + "/" + str(body.name) + ":position:y")
	run_anim.track_insert_key(track, 0.0, 0.4)
	run_anim.track_insert_key(track, 0.2, 0.5)  # Hop
	run_anim.track_insert_key(track, 0.4, 0.4)

	# Rotate Legs? (Complex for logic, let's just bounce)

	lib.add_animation("Run", run_anim)

	# -- ATTACK --
	var atk_anim = Animation.new()
	atk_anim.length = 0.5

	# Lunge forward
	track = atk_anim.add_track(Animation.TYPE_VALUE)
	atk_anim.track_set_path(track, str(root.name) + ":position:z")
	atk_anim.track_insert_key(track, 0.0, 0.0)
	atk_anim.track_insert_key(track, 0.2, -0.5)  # Lunge
	atk_anim.track_insert_key(track, 0.5, 0.0)

	lib.add_animation("Attack", atk_anim)

	# -- DIE --
	var die_anim = Animation.new()
	die_anim.length = 1.0

	# Rotate Body over
	track = die_anim.add_track(Animation.TYPE_VALUE)
	die_anim.track_set_path(track, str(root.name) + ":rotation:z")
	die_anim.track_insert_key(track, 0.0, 0.0)
	die_anim.track_insert_key(track, 0.5, deg_to_rad(90))  # Flop
	die_anim.track_insert_key(track, 1.0, deg_to_rad(90))

	lib.add_animation("Die", die_anim)

	anim_player.add_animation_library("", lib)

	return {"anim_player": anim_player, "sockets": sockets}
