extends Node

@export var initial_state: Node  # State (Typed loosely to avoid cache issues)

var current_state: Node  # State
var state_history: Array[Node] = []

const State = preload("res://scripts/fsm/State.gd")


func _ready():
	# await owner.ready # Owner is null for dynamic children
	# We rely on Parent being the Context.
	var parent_node = get_parent()
	if not parent_node.is_node_ready():
		await parent_node.ready

	for child in get_children():
		if child is State:
			child.state_machine = self
			child.context = parent_node

	if initial_state:
		change_state(initial_state)


func _process(delta):
	if current_state:
		current_state.update(delta)


func _physics_process(delta):
	if current_state:
		current_state.physics_update(delta)


func _unhandled_input(event):
	if current_state:
		current_state.handle_input(event)


func change_state(new_state_node: State, msg: Dictionary = {}):
	if current_state:
		current_state.exit()
		state_history.append(current_state)
		if state_history.size() > 5:
			state_history.pop_front()  # Keep history small

	current_state = new_state_node

	if current_state:
		current_state.enter(msg)
		# print("StateMachine: Entered ", current_state.name)


func transition_to(state_name: String, msg: Dictionary = {}):
	# DEBUG TRAP FOR SPITTER 5
	if get_parent() and get_parent().name == "Acid Spitter5":
		print("DEBUG: Acid Spitter5 transitioning to state: ", state_name)
		var stack = get_stack()
		if stack.size() > 1:
			print(" - Called from: ", stack[1]["source"], ":", stack[1]["line"], " func: ", stack[1]["function"])

	if not has_node(state_name):
		push_error("StateMachine: State " + state_name + " does not exist!")
		return

	change_state(get_node(state_name), msg)
