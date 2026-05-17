# Spawning & Instantiation Guide

> [!IMPORTANT]
> **Rule #1**: Never assume a unit or object is in the Scene Tree immediately after instantiation.

This guide defines the strict rules for spawning Units, Objectives, and Props in BARK-COM. Following these rules prevents common errors like `get_node()` failures and invalid grid placement.

## 1. The Golden Lifecycle

When creating game entities (Units, Objectives), you must follow this order:

1.  **Instantiation**: `var unit = unit_script.new()`
2.  **Configuration**: Set properties (`name`, `faction`, stats) *before* checking tree-dependent logic.
3.  **Registration**: Add to Scene Tree (`add_child(unit)`).
4.  **Initialization**: Call `unit.initialize(pos)` or `unit.enter_mission()`.

### ❌ Bad Practice (The "Tree Fallacy")
```gdscript
var unit = Unit.new()
# ERROR: accessing mobility might call get_node("/root/BarkTreeManager") before add_child!
print(unit.mobility) 
add_child(unit)
```

### ✅ Good Practice
```gdscript
var unit = Unit.new()
add_child(unit)
# SAFE: Unit is in tree, singletons are accessible.
print(unit.mobility)
```

## 2. Unit.gd Safety Rules

The `Unit` class relies on global Autoloads (`BarkTreeManager`, `TurnManager`) for stat calculation. 

**Guideline**: All property getters that access global singletons MUST check `is_inside_tree()`.

```gdscript
var mobility: int:
    get:
        var val = base_mobility
        if is_inside_tree(): # CRITICAL CHECK
            var btm = get_node_or_null("/root/BarkTreeManager")
            if btm: ...
        return val
```

## 3. Spawning Objectives

When placing objects on the Grid:

1.  **Validation**: ALWAYS check `GridManager.grid_data.has(pos)` or `GridManager.is_walkable(pos)`.
    - *Note*: `GridManager` does **NOT** have an `is_tile_walkable()` method. Use `is_walkable()` or `is_valid_destination()`.
2.  **Clearance**: Use `ObjectiveSpawner._ensure_tile_clear(pos)` to remove existing walls/props if necessary.
3.  **Parenting**: Add objectives to `GridManager` or a dedicated container, not the root, to ensure they clean up with the mission.

## 4. Factory Usage

Use `MissionManager` or `UnitSpawner` (Legacy) for standard enemies.

- **Standard**: `MissionManager.spawn_enemy_at(type, pos)`
- **Manual**:
```gdscript
var enemy = load("res://scenes/entities/enemies/" + type + ".tscn").instantiate()
# OR
var enemy = load("res://scripts/entities/enemies/" + type + ".gd").new()
enemy.initialize(pos)
add_child(enemy)
```

## 5. Terminal & Debugging

- Use the **Terminal (`~`)** to test spawning logic safely.
- Command: `spawn <Archetype> <x> <y>`
- Command: `doomsday` (Triggers Final Mission)
