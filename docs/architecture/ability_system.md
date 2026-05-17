# Architecture: Ability System

## 1. Overview
B.A.R.K. uses a resource-based Ability system. Everything the unit does, including "Standard Attack" or "Reload", is wrapped as an `Ability`. This decouples the action logic from the Unit class.

## 2. Structure

### `Ability.gd`
The base script (`scripts/resources/Ability.gd`) defines the interface.
-   **Properties**:
    -   `display_name` (String)
    -   `ap_cost` (int)
    -   `cooldown_turns` (int) — note: `current_cooldown` tracks remaining turns
    -   `ability_range` (int)
    -   `uses_charges` (bool), `max_charges` / `charges` (int)
-   **Key Methods**:
    -   `can_use()`: Validation check (no params; checks cooldown and charges).
    -   `execute(user, target_unit, target_tile: Vector2, grid_manager)`: The effect logic.
    -   `get_valid_tiles(grid_manager, user)`: Returns `Array[Vector2]` of targetable grid coords.
    -   `get_hit_chance_breakdown(grid_manager, user, target)`: Optional; returns Dict for UI.
    -   `get_ai_score(user, target, grid_manager)`: Used by AI to evaluate ability priority.

### Ability Scripts (`scripts/abilities/`)
Concrete implementations extend `Ability.gd`.
-   **Example**: `GrenadeToss.gd` overrides `execute` to spawn a projectile scene and apply AOE damage via `CombatResolver`.
-   **Example**: `OverwatchAbility.gd` overrides `execute` to set the `is_overwatch_active` state on the user.

## 3. Combat Resolution (`CombatResolver.gd`)

To prevent spaghetti code in Ability scripts, `CombatResolver` handles the math of damage, hit chance, and status application centrally.

-   **Location**: `scripts/managers/CombatResolver.gd`
-   **Key functions**:
    -   `CombatResolver.calculate_hit_chance(attacker, target, grid_manager, from_pos, is_reaction)` → Dict `{hit_chance, breakdown, crit_chance}`.
    -   `CombatResolver.resolve_standard_attack(attacker, target, grid_manager)` — rolls hit/miss, applies damage and status effects, emits VFX signals.
    -   Calculates Damage (Weapon Base + Bonus - Armor).
    -   Awards 50 XP to attacker on kill.
    -   Logs the result.

## 4. Usage Flow
1.  **UI Interaction**: Player selects an Ability Button.
2.  **Targeting**: The ability's `get_valid_tiles(grid_manager, user)` highlights grid cells.
3.  **Confirmation**: Player clicks a valid target tile.
4.  **Execution**: `PlayerMissionController` calls `ability.execute(user, target_unit, target_tile, grid_manager)`.
5.  **Resolution**: The ability calls `CombatResolver.resolve_standard_attack()` or `CombatResolver.calculate_hit_chance()` to apply changes to the game state.
