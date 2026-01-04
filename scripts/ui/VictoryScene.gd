extends Control

@onready var credits_label = $CreditsLabel
@onready var fireworks_container = $FireworksContainer

var credits_text = """
[center]
[b][font_size=64]VICTORY![/font_size][/b]

The Golden Hydrant is Safe.
The Eldritch Hordes have been repelled.
The Neighborhood is ours again.

[b][font_size=32]BARK COMMAND[/font_size][/b]

A Game by Ryan

[b]DEVELOPED WITH[/b]
Antigravity Agent

[b]DEDICATED TO[/b]
All the Good Boys and Girls
Who keep the nightmares at bay.

[b]SPECIAL THANKS[/b]
You, for playing.

[color=yellow]PRESS ANY KEY TO RETURN[/color]
[/center]
"""

var can_exit = false


func _ready():
	if credits_label:
		credits_label.text = credits_text

		# Simple Fade In
		credits_label.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(credits_label, "modulate:a", 1.0, 2.0)

	# Start Fireworks Loop
	_spawn_fireworks_loop()

	# Reset Game State?
	if GameManager:
		GameManager.invasion_progress = 0

	# Input Buffer (Prevent accidental skip)
	set_process_input(false)  # Hard disable input
	print("VictoryScene: Input Locked.")

	# Optional: Hide the "Press Any Key" line initially or dim it?
	# For now, just wait.

	await get_tree().create_timer(2.0).timeout

	print("VictoryScene: Input Unlocked.")
	set_process_input(true)

	# Visual Feedback: Flash the prompt
	if credits_label:
		# Use a tween to pulse the input prompt or just change color
		# Since it's BBCode, hard to tween just one line without redrawing.
		# Let's just flash the whole label or ignore for now.
		pass


func _input(event):
	# Removed can_exit check as set_process_input handles it

	if event is InputEventKey and event.pressed:
		print("VictoryScene: Key Pressed -> Returning.")
		_return_to_menu()
	elif event is InputEventMouseButton and event.pressed:
		print("VictoryScene: Mouse Pressed -> Returning.")
		_return_to_menu()


func _return_to_menu():
	get_tree().change_scene_to_file("res://scenes/Base.tscn")


func _spawn_fireworks_loop():
	while is_inside_tree():
		_spawn_firework()
		var delay = randf_range(0.5, 1.5)
		await get_tree().create_timer(delay).timeout


func _spawn_firework():
	if not fireworks_container:
		return

	var particle = CPUParticles2D.new()
	fireworks_container.add_child(particle)

	# Random Position
	var screen_size = get_viewport_rect().size
	particle.position = Vector2(randf() * screen_size.x, randf() * screen_size.y * 0.8)

	# Config
	particle.emitting = true
	particle.amount = 50
	particle.one_shot = true
	particle.explosiveness = 1.0
	particle.lifetime = 1.5
	particle.direction = Vector2(0, -1)
	particle.spread = 180.0
	particle.gravity = Vector2(0, 98)
	particle.initial_velocity_min = 100
	particle.initial_velocity_max = 300
	particle.scale_amount_min = 4.0
	particle.scale_amount_max = 8.0
	particle.color = Color(randf(), randf(), randf())  # Random Color

	# Cleanup
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(particle):
		particle.queue_free()
