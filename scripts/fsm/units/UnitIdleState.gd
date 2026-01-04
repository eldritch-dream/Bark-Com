extends "res://scripts/fsm/State.gd"


func enter(_msg: Dictionary = {}):
	var unit = context as Unit
	if unit.visuals:
		unit.visuals.play_animation("Idle")


func update(_delta: float):
	# Check for "Fear of Unknown" or other continuous effects?
	# Usually Idle does nothing but wait for StateMachine.transition_to called by external events (Input, AI).
	pass
