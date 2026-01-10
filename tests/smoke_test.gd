extends Node

func _ready():
	print("🚬 Smoke Test: Starting...")
	
	# Instantiate the main game scene
	var main_scene_res = load("res://scenes/Base.tscn")
	if not main_scene_res:
		printerr("❌ Smoke Test FAILED: Main scene not found!")
		get_tree().quit(1)
		return

	var main_scene = main_scene_res.instantiate()
	add_child(main_scene)
	print("✅ Smoke Test: Main scene instantiated successfully.")
	
	# Anti-Ghosting Safeguard
	add_child(load("res://tests/TestSafeGuard.gd").new())
	
	# Wait for a few seconds to ensure no immediate crash
	await get_tree().create_timer(5.0).timeout
	
	print("✅ Smoke Test: 5 seconds passed without crash.")
	print("🚬 Smoke Test: PASSED.")
	
	main_scene.queue_free()
	await get_tree().process_frame # Allow cleanup frame
	
	get_tree().quit(0)
