extends Node

func _ready():
	print("--- TEST: Status Effects Logic ---")
	await get_tree().process_frame # Wait for autoloads stability
	
	# Load Scripts
	var UnitScript = load("res://scripts/entities/Unit.gd")
	var StunScript = load("res://scripts/resources/effects/StunEffect.gd")
	
	if not UnitScript or not StunScript:
		printerr("FAIL: Could not load required scripts.")
		get_tree().quit(1)
		return

	# 1. Setup Unit
	# Unit extends CharacterBody3D, usually needs to be in tree for some lookups, 
	# but for pure stats unit test it might work detached, 
	# EXCEPT Unit.gd uses get_tree() in some places (spend_ap->TurnManager).
	# apply_effect uses SignalBus (Autoload).
	
	var unit = UnitScript.new()
	unit.name = "TestUnit"
	add_child(unit) # Add to tree to be safe
	
	# Mock Stats
	unit.max_ap = 3
	unit.current_ap = 3
	unit.active_effects = []

	# 2. Apply Stun
	print("Testing apply_effect...")
	var stun = StunScript.new()
	stun.duration = 1
	
	unit.apply_effect(stun)
	
	if unit.active_effects.size() == 1 and unit.active_effects[0] == stun:
		print("PASS: Stun effect applied correctly.")
	else:
		printerr("FAIL: apply_effect did not add effect to active_effects.")
		get_tree().quit(1)
		return

	# 3. Turn Start Logic (Stun should drain AP)
	print("Testing process_turn_start_effects (AP Drain)...")
	
	# Call on_turn_start (which calls process_turn_start_effects)
	unit.on_turn_start()
	
	# Check AP
	if unit.current_ap == 0:
		print("PASS: Stun drained AP to 0.")
	else:
		printerr("FAIL: Stun failed to drain AP. Current AP: ", unit.current_ap)
		get_tree().quit(1)
		return

	# 4. Check Duration Decrement
	if stun.duration == 0:
		print("PASS: Effect duration decremented.")
	else:
		printerr("FAIL: Effect duration not decremented. Duration: ", stun.duration)
		get_tree().quit(1)
		return
		
	# 5. Next Turn (Effect should expire)
	print("Testing Effect Expiration...")
	unit.on_turn_start()
	
	if unit.active_effects.is_empty():
		print("PASS: Stun effect expired and removed.")
	else:
		print("FAIL: Stun still active. Size: ", unit.active_effects.size())
		get_tree().quit(1)
		return

	# 6. Verify AP restored after expiration
	# on_turn_start sets AP=Max, then process effects. 
	# Since effect removed, AP should stay Max.
	if unit.current_ap == unit.max_ap:
		print("PASS: AP restored in subsequent turn.")
	else:
		printerr("FAIL: AP not restored. AP: ", unit.current_ap)
		get_tree().quit(1)
		return

	print("--- Status Effects Test PASSED ---")
	get_tree().quit(0)
