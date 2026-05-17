# Architecture: Tactical Grid System

## 1. Overview
The Tactical Grid is the foundation of gameplay. It manages movement, cover, line-of-sight, and object placement. It acts as the bridge between 3D world coordinates and abstract 2D grid logic.

## 2. Core Components

### `GridManager.gd`
Per-mission manager (not a global autoload — created by `MissionManager`).
-   **Grid Coordinates**: `Vector2(x, z)`.
-   **World Coordinates**: `Vector3(x, y, z)`.
-   **Key Responsibilities**:
    -   `get_move_path(start: Vector2, end: Vector2) -> Array[Vector2]`: AStar pathfinding.
    -   `get_best_cover_at(coord: Vector2) -> float`: Returns cover rating at a tile (used for AI scoring).
    -   `is_tile_blocked(coord: Vector2) -> bool`: True if occupied by wall/prop.
    -   `get_unit_at_grid_pos(coord: Vector2) -> Node`: Returns occupying unit or null.
    -   `is_walkable(coord: Vector2) -> bool`: True if passable (not blocked, not out of bounds).
    -   `is_valid_destination(coord: Vector2) -> bool`: Combines walkability + occupancy check.
    -   `get_reachable_tiles(start_pos, max_move) -> Array[Vector2]`: BFS for movement range.

Cover math (hit chance penalties) lives in `CombatResolver.calculate_hit_chance()`, which queries GridManager internally.

### `TacticalMap` (Scene)
The visual representation.
-   **GridMap Node**: Godot's built-in `GridMap` is often used for rendering the floor/walls, but `GridManager` maintains the logical data.

## 3. Pathfinding Logic
1.  **AStar Initialization**: On level load, `GridManager` scans the map.
2.  **Passability**: Tiles are marked Walkable or Blocked. Blocked tiles (Walls, Props) are excluded from the AStar graph.
3.  **Dynamic Updates**: When a Unit moves or an obstacle is destroyed, the grid occupancy is updated. (Optimized to avoid full graph rebuilds).

## 4. Cover System
Cover is directional.
-   **Logic**: A raycast or adjacent check is performed from the Target towards the Attacker.
-   **Types**:
    -   **High Cover**: Walls, High Props. Provides significant Defense bonus.
    -   **Low Cover**: Low walls, Crates. Provides moderate Defense bonus.
    -   **Flanking**: If the attack angle bypasses the cover object (i.e., attacker is 90 degrees or more to the side), cover is negated.

## 5. Line of Sight (Fog of War)
Implemented via `VisionManager` (often coupled with `GridManager`).
-   Raycasts determine visibility from Unit Head Position to Target Head Position.
-   Fog of War obscures unseen tiles visually.
