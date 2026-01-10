extends SceneTree

func _init():
	print("Debugger: Loading test_turn_manager.gd...")
	var script = load("res://tests/test_turn_manager.gd")
	if script:
		print("Debugger: Script Loaded Successfully!")
		var instance = script.new()
		print("Debugger: Instance Created.")
		get_root().add_child(instance)
		print("Debugger: Added to SceneTree.")
		
		# Allow some frames for async tests
		await create_timer(10.0).timeout
		instance.queue_free()
	else:
		print("Debugger: Failed to load script.")
	quit()
