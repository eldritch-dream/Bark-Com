# Architecture: Enemy AI System

## 1. Overview
The Enemy AI system is designed to provide challenge and variety through "Personality-Driven" behaviors. Standard enemies do not use a complex Utility AI; instead, they use a Behavior Tree-lite structure implemented via **State Machines** and **Modular Behaviors**.

## 2. Core Components

### `EnemyUnit.gd`
The base class for all enemies.
-   **Extends**: `Unit.gd` (inherits Movement, Stats, Status Effects).
-   **Responsibility**:
    -   Manages the Turn Loop (Start Turn -> Execute Actions -> End Turn).
    -   Holds the `AIBehaviorBase` reference.

### `AIBehaviorBase.gd`
The abstract strategy pattern that defines *how* an enemy thinks.
-   **Location**: `scripts/ai/AIBehaviorBase.gd`
-   **Key Methods**:
    -   `evaluate_position(unit, tile, target, grid_manager) -> float`: Scores a candidate tile.
    -   `evaluate_target(unit, target, grid_manager) -> float`: Scores a potential target.
    -   `get_special_action(unit, grid_manager) -> Dictionary`: Returns a special-ability action dict if the behavior wants to use one (e.g. grenade, mind fracture), or empty dict.
    -   `_get_self_preservation_score(unit, tile, target, gm) -> float`: Internal; penalizes exposed positions.

Note: `decide_action(all_units, grid_manager)` is a method on **`EnemyUnit`** (not on `AIBehaviorBase`). It orchestrates movement and attack selection by querying the behavior's scoring functions.

### Modular Behaviors (`scripts/ai/`)
Each enemy type instantiates a specific behavior script:
-   **RusherBehavior**: Aggressive. Prioritizes proximity and Flanking. Ignores cover safety if it can kill.
-   **SniperBehavior**: Defensive. Prioritizes long sightlines and High Ground.
-   **ExploderBehavior**: Suicidal. Rushes clusters of units to trigger `ExplodeAbility`.
-   **ControllerBehavior**: Support. Prioritizes buffing allies or debuffing the strongest player unit.

## 3. The AI Decision Loop

When `TurnManager.start_enemy_turn()` prompts an enemy to act (calls `unit.decide_action(all_units, grid_manager)`):

1.  **Context Building**: The Unit gathers `known_targets` (Player units in vision/memory).
2.  **Behavior Query**: `EnemyUnit` asks its `behavior` to `decide_action()`.
3.  **Action Selection**:
    -   **Attack**: If a valid target is in range and hit chance is good (Behavior determined).
    -   **Move**: If no attack is viable, the Behavior creates a heatmap of grid positions based on its personality (e.g. Rusher likes close, Sniper likes far). Pathfinding selects the best detailed tile.
    -   **Ability**: Special abilities (Grenades, Mind Fracture) are weighed against standard attacks.
4.  **Execution**: The Unit enters the `UnitMoveState` or executes the ability.
5.  **Chain Actions**: If AP remains, the loop repeats.

## 4. Debugging
Use the Visual Debug Context (Press `F3` in game, if enabled) to see:
-   Current Behavior Name.
-   Target Score for each visible unit.
-   Selected Tile destination.
