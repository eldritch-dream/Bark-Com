extends Node

const ROTATED_YAW_DEGREES := 45.0
const ROTATION_TOLERANCE := 0.1


func _ready() -> void:
	add_child(load("res://tests/TestSafeGuard.gd").new())
	await get_tree().process_frame
	await _verify_rotation_is_restored()


func _verify_rotation_is_restored() -> void:
	var camera := Camera3D.new()
	add_child(camera)

	var cinematic := CinematicCamera.new(camera)
	add_child(cinematic)
	await get_tree().process_frame

	camera.rotation_degrees.y = ROTATED_YAW_DEGREES

	var attacker := Node3D.new()
	add_child(attacker)
	cinematic._on_action_started(attacker, null, "Grenade", Vector3(4.0, 0.0, 4.0))
	cinematic._kill_tween()

	# A death camera may interrupt the action shot. It must retain the original
	# player-selected return state rather than capturing the in-flight camera.
	camera.rotation_degrees.y = 0.0
	var victim := Node3D.new()
	add_child(victim)
	cinematic._on_unit_died(victim)
	cinematic._kill_tween()

	cinematic._reset_camera()
	await get_tree().create_timer(1.0).timeout

	if absf(camera.rotation_degrees.y - ROTATED_YAW_DEGREES) > ROTATION_TOLERANCE:
		await _finish(
			1,
			"Cinematic camera restored yaw %.2f instead of the player's %.2f-degree rotation."
			% [camera.rotation_degrees.y, ROTATED_YAW_DEGREES],
			[attacker, victim, cinematic, camera]
		)
		return

	await _finish(
		0,
		"PASS: Cinematic camera preserved the player's rotated yaw.",
		[attacker, victim, cinematic, camera]
	)


func _finish(exit_code: int, message: String, nodes: Array[Node]) -> void:
	print(message if exit_code == 0 else "FAIL: " + message)
	for node in nodes:
		node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(exit_code)
