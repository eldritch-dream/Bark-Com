extends Node3D
class_name UnitVisuals

# References
var animation_player: AnimationPlayer
var sockets: Dictionary = {}  # "Head", "Spine", etc. -> Node3D (Bone/Marker)

# State
var current_anim: String = ""


func setup(anim_player: AnimationPlayer, socket_map: Dictionary):
	animation_player = anim_player
	sockets = socket_map

	# Default Idle
	play_animation("Idle")


func play_animation(anim_name: String):
	if not animation_player:
		return
	if current_anim == anim_name:
		return

	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
		current_anim = anim_name
	else:
		# Fallback
		if anim_name != "Idle":
			play_animation("Idle")


func attach_cosmetic(socket_name: String, cosmetic_node: Node3D):
	if sockets.has(socket_name):
		var socket = sockets[socket_name]
		# Clear existing?
		for child in socket.get_children():
			child.queue_free()

		if cosmetic_node:
			socket.add_child(cosmetic_node)
			cosmetic_node.position = Vector3.ZERO
			cosmetic_node.rotation = Vector3.ZERO
	else:
		print("Visuals: Socket '", socket_name, "' not found!")
