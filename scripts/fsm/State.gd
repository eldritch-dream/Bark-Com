extends Node

var state_machine: Node  # StateMachine
var context: Node  # The owner (Unit, etc)


# Virtual Methods
func enter(_msg: Dictionary = {}):
	pass


func exit():
	pass


func update(_delta: float):
	pass


func physics_update(_delta: float):
	pass


func handle_input(_event: InputEvent):
	pass
