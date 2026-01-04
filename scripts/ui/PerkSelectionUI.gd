extends PanelContainer
class_name PerkSelectionUI

signal perk_selected(talent)

var title_label: Label
var cards_container: HBoxContainer
var description_label: Label


func _ready():
	custom_minimum_size = Vector2(600, 400)

	var vbox = VBoxContainer.new()
	add_child(vbox)

	title_label = Label.new()
	title_label.text = "PROMOTION AVAILABLE!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title_label)

	vbox.add_child(HSeparator.new())

	cards_container = HBoxContainer.new()
	cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.add_theme_constant_override("separation", 20)
	vbox.add_child(cards_container)

	description_label = Label.new()
	description_label.text = "Select a perk..."
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(description_label)


func show_options(rank: int, talents: Array):
	title_label.text = "PROMOTION: RANK " + str(rank)

	# Clear old
	for c in cards_container.get_children():
		c.queue_free()

	# Create Cards
	for t in talents:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 300)
		btn.text = t.display_name + "\n\n" + t.description

		# Icon?
		# if t.icon: btn.icon = t.icon

		btn.pressed.connect(
			func():
				emit_signal("perk_selected", t)
				queue_free()
		)
		cards_container.add_child(btn)
