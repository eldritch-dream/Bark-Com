extends Node3D
class_name InteractiveObject

var grid_pos: Vector2
var grid_manager: GridManager


func initialize(pos: Vector2, gm: GridManager):
	grid_pos = pos
	grid_manager = gm
	position = gm.get_world_position(pos)


func interact(_unit):
	print("Interacted with generic object.")


func take_damage(_amount: int):
	pass
