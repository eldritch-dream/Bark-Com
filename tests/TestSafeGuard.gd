extends Node
# TestSafeGuard.gd
# Helper to prevent tests from ghosting (running forever).
# Autos-quits after a timeout.

var timeout: float = 30.0 # Default 30s timeout

func _ready():
	# Use SceneTreeTimer which works even if paused (usually)
	# But a Timer node is safer for cleaning up
	var timer = Timer.new()
	timer.wait_time = timeout
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(_on_timeout)
	add_child(timer)
	print("TestSafeGuard: Watchdog started. Timeout: ", timeout, "s")

func _on_timeout():
	print("!!! TestSafeGuard: TIMEOUT REACHED (", timeout, "s) !!!")
	print("!!! FORCE QUITTING TO PREVENT GHOSTING !!!")
	
	# Attempt to print stack trace?
	# print_stack() 
	
	get_tree().quit(1) # Return error code 1
