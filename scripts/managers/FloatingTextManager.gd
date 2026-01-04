extends Node3D
class_name FloatingTextManager

# If configured as AutoLoad, this is globally accessible by name "FloatingTextManager"
# If not, we can use a static instance pattern.
static var instance: FloatingTextManager


func _init():
	if not instance:
		instance = self


func _ready():
	name = "FloatingTextManager"
	SignalBus.on_request_floating_text.connect(spawn_text)


# Spawns a floating text label at the given world position
func spawn_text(position: Vector3, text: String, color: Color = Color.WHITE):
	# print("FTM: Spawning '", text, "' at ", position) # Commented out for now


	var label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true  # Ensure distinct visibility? Or false for realism. Let's try false (depth sorted).
	# Actually, no_depth_test=true ensures it pops over geometry. Games usually want this.
	label.no_depth_test = true
	label.render_priority = 10  # Draw on top
	label.text = text
	label.modulate = color
	label.font_size = 48  # Scaled down later? Or just use pixel_size
	label.pixel_size = 0.005  #
	label.position = position + Vector3(0, 1.5, 0)  # Start above unit

	add_child(label)

	# Tween it
	var tween = create_tween()
	tween.set_parallel(true)

	# Float Up
	(
		tween
		. tween_property(label, "position:y", label.position.y + 1.5, 1.0)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_CUBIC)
	)
	# Fade Out
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN).set_trans(
		Tween.TRANS_QUAD
	)
	# Scale Up (Pop)
	tween.tween_property(label, "scale", Vector3(1.5, 1.5, 1.5), 0.3)

	# Cleanup
	await tween.finished
	label.queue_free()
