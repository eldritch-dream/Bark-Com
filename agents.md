# Agent Behavior & Project Guidelines

This document is the entry point for AI agents and developers working on BARK-COM. Following these rules avoids subtle regressions, especially around save data.

## 1. Project Context

**BARK-COM** is a tactical turn-based strategy game (XCOM-like) where you command a squad of genetically enhanced Corgis against Eldritch horrors ("The Whispers", "The Sprawling").

### Key Pillars
- **Tactical Depth**: Cover, Flanking, Overwatch, Action Points (AP).
- **Base Management**: An HQ ("The Kennel") with Barracks, Research, and Mission Control.
- **Persistent Roster**: Units have persistent stats, injuries, and progression. Death is permanent.
- **Visuals**: Procedural Corgi models and distinct enemy visual identities.

## 2. Core Architecture Rules (Strict)

> [!IMPORTANT]
> **Safety First**: Never risk corrupting the user's save data.

- **Persistence**: see [docs/architecture/persistence_rules.md](docs/architecture/persistence_rules.md).
  - `unit_class` string is the Source of Truth for identity. Never rely on Resources for identity.
  - On `restore_from_snapshot`, call `apply_class_stats(unit_class)` BEFORE recalculating derived stats. Verified at `scripts/entities/Unit.gd:1217`.
- **Testing**: see [docs/architecture/testing_protocols.md](docs/architecture/testing_protocols.md).
  - All tests must set `GameManager.TEST_MOCK_ENABLED = true`. When set, `GameManager` swaps the save path to `user://test_savegame.dat` (see `scripts/core/GameManager.gd:84`, `:769`).
  - Run tests via `tests/run_tests.ps1` (or `tests/run_tests_parallel.ps1` for the worker-based parallel pipeline).

## 3. Coding Standards (GDScript)

- **Logging**: Use `GameManager.log(LOG_PREFIX, …)` instead of `print()` — every script defines a `const LOG_PREFIX` at the top. (`GameManager.log` defined at `scripts/core/GameManager.gd:118`.)
- **Typing**: Strict static typing is preferred.
- **Instantiation**: Prefer code-first instantiation (`SomeClass.new()` from GDScript) over `.tscn` scene instantiation for logic-bearing nodes.

Full coding standards: [docs/dev_guide/coding_standards.md](docs/dev_guide/coding_standards.md).

## 4. Documentation Deep Dive

For heavier implementation work:

- **[Content Creation Guide](docs/dev_guide/content_creation.md)** — start here for new classes, enemies, items.
- **[System Map](docs/architecture/system_map.md)** — file locations for each concept.
- **[AI Architecture](docs/architecture/ai_system.md)** — `EnemyUnit`, state machine, behavior selection.
- **[Ability System](docs/architecture/ability_system.md)** — Resource-based abilities and `CombatResolver`.
- **[Tactical Grid](docs/architecture/tactical_grid.md)** — pathfinding, cover, and grid logic (all live in `GridManager.gd`).
- **[Signal Bus](docs/architecture/signal_bus.md)** — event-driven architecture decoupling logic, UI, and AV.

## 5. Autoloads (from `project.godot`)

In load order:
1. **SignalBus** — `scripts/managers/SignalBus.gd`. Central event hub.
2. **GameManager** — `scripts/core/GameManager.gd`. Global state machine (Base vs Mission), save/load orchestration (`save_game()`, `load_game()`).
3. **AIDebugger** — `scripts/utils/AIDebugger.gd`. Debug toggles for enemy AI overlays.
4. **InputManager** — `scripts/managers/InputManager.gd`. Raycasting (`on_tile_clicked` signal) and camera controls. Only processes input during `MISSION` or `BASE` states.
5. **CosmeticManager** — `scripts/managers/CosmeticManager.gd`. Cosmetic catalog and equipped state.
6. **BarkTreeManager** — `scripts/managers/BarkTreeManager.gd`. In-memory skill-tree (perks) state. Persistence is handled by `GameManager` reading/writing `BarkTreeManager.unlocked_perks`.

## 6. Per-Mission Singletons (not autoloads — instantiated by `MissionManager`)

- **GridManager** (`scripts/managers/GridManager.gd`) — owns the AStar graph AND cover calculations. Created per mission via `GridManager.new()`; held on `MissionManager.grid_manager`.
- **TurnManager**, **ObjectiveManager**, **VisionManager**, **FogManager**, **VFXManager**, **NemesisManager**, **CombatResolver** — also live under `scripts/managers/` but are mission-scoped, not global.

## 7. Current Tech Stack

- **Engine**: Godot 4.5 (Forward+ renderer; see `project.godot` `config/features`).
- **Language**: GDScript 2.0.
