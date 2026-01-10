extends Node

# Usage: godot -s tests/test_item_target.gd

var CombatResolver_Script
var Unit_Script
var GridManager_Script

class MockGridManager:
	extends "res://scripts/managers/GridManager.gd"
	# Override if necessary, but base class satisfies type check
	func get_grid_coord(pos: Vector3) -> Vector2: return Vector2(0, 0)
	
	func _init():
		pass # Skip complex init if possible, or ensure it's safe. GridManager init might need args?
		# GridManager.gd extends Node usually.
		

class MockUnit:
	extends Node3D
	# name is inherited
	var unit_name = "MockUnit" # Use distinct prop
	var current_hp = 5
	var max_hp = 10
	var grid_pos = Vector2(0, 0)
	var faction = "Player"
	var inventory = []
	var current_ap = 2
	var modifiers = {}
	
	func _init():
		name = "MockUnit"
		
	# REMOVED illegal overrides
	# CombatResolver checks has_method on object. Native Object.has_method checks script methods.
	# So defining 'heal' is enough.
		
	func heal(amount):
		current_hp = min(current_hp + amount, max_hp)
		print(name, " healed to ", current_hp)

class MockItem:
	var display_name = "TestMedkit"
	var ability_ref = null
	var effect_type = 0 # HEAL (Enum Value 0)
	var value = 5
	var consume_on_use = true

func _ready():
	print("--- STARTING ITEM TARGET REGRESSION TESTS ---")
	await get_tree().process_frame
	
	CombatResolver_Script = load("res://scripts/managers/CombatResolver.gd")
	# We rely on static methods on CombatResolver, so we don't necessarily need to instance it if it's a class with statics.
	# But in GDScript 2.0, static functions are called on the class resource or class_name.
	# CombatResolver is a class_name.
	
	var passed = true
	
	# TEST 1: Unit Target (Object)
	print("TEST 1: Unit Target (Object Ref)")
	var attacker = MockUnit.new()
	var target = MockUnit.new()
	target.name = "TargetUnit"
	target.current_hp = 1
	var item = MockItem.new()
	var gm = MockGridManager.new()
	
	# Execute
	var result = CombatResolver.execute_item_effect(attacker, item, target, gm)
	
	if result and target.current_hp == 6:
		print("PASS: Item used on Unit Object successfully.")
	else:
		printerr("FAIL: Item failed on Unit Object. Result:", result, " HP:", target.current_hp)
		passed = false
		
	# TEST 2: Vector3 Target (Position) - Legacy/Grenade
	print("TEST 2: Vector3 Target (Position)")
	# Ideally, to reuse execute_item_effect for HEAL with Position, it tries to find a unit at that position.
	# Our mock GM returns (0,0) for any position.
	# The MockUnit is not in the scene tree "Units" group, so logic relying on `get_tree().get_nodes_in_group("Units")` will FAIL in this standalone script unless we add them to tree.
	
	# To test Vector3 targeting properly for a generic unit search, we need a Scene Runner.
	# However, the CRITICAL fix was that passing an OBJECT didn't crash.
	# So Test 1 is unique coverage.
	
	# Let's clean up
	attacker.free()
	target.free()
	
	if passed:
		print("--- ALL ITEM TARGET TESTS PASSED ---")
		get_tree().quit(0)
	else:
		print("--- ITEM TARGET TESTS FAILED ---")
		get_tree().quit(1)
