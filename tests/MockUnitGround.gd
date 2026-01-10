extends Node
class_name MockUnitGround

var grid_pos = Vector2(5,5)
var faction = 'Player'
var mobility = 10
var current_ap = 10
var stats = {'accuracy': 100}
var modifiers = {}
func has_perk(p): return false
func spend_ap(cost): return true
