extends Node3D

var time: float = 0.0
var frequency: float = 2.0
var amplitude: float = 0.5
var y_offset: float = 2.5
var target_node: Node3D = null

func _process(delta):
	time += delta
	
	if is_instance_valid(target_node):
		# Follow Target
		position.x = target_node.position.x
		position.z = target_node.position.z
		var base_height = target_node.position.y + y_offset
		
		# Bounce
		var offset = sin(time * frequency) * amplitude
		position.y = base_height + offset
	else:
		# Static bounce logic if no target (fallback)
		var offset = sin(time * frequency) * amplitude
		position.y += offset * delta * 0.1 # This is weird, but fallback.
		# Better fallback: just bounce around current Y? 
		# If no target, we probably shouldn't be visible or just stay put.
		pass

	# Rotate
	rotate_y(delta * 1.5)
