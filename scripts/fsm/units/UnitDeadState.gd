extends "res://scripts/fsm/State.gd"


func enter(_msg: Dictionary = {}):
	# Play Death Anim
	var unit = context as Unit
	if unit.visuals:
		unit.visuals.play_animation("Die")

	# Disable collisions (though usually handled by queue_free or logic in Unit.die())
	# This state is mostly marking "don't accept commands".
