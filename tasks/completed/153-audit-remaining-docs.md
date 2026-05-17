# Audit remaining docs for drift

**Category:** Tooling / Docs
**Source:** Follow-up from agents.md + system_map.md audit
**Status:** Completed 2026-05-17

The agents.md + system_map.md audit caught major drift (wrong autoload list, wrong file paths, references to files that don't exist like `SaveManager.gd`, `AStar_Path.gd`, `CoverSystem.gd`, `UnitClass.gd`). The rest of the docs almost certainly have similar rot — they were written off the same outdated mental model.

Walk each of these against the code and fix or remove drift:

**docs/architecture/**
- `ai_system.md` — verify against `scripts/entities/EnemyUnit.gd` and `scripts/fsm/`
- `ability_system.md` — verify against `scripts/resources/Ability.gd` + `scripts/abilities/`
- `bond_system.md`
- `memorial_system.md`
- `persistence_rules.md` — should still be authoritative, but verify
- `signal_bus.md` — confirm signal names listed match `scripts/managers/SignalBus.gd`
- `tactical_grid.md` — should reflect that pathfinding + cover both live in `GridManager.gd`
- `testing_protocols.md` — confirm `tests/run_tests.ps1` and parallel-pipeline references

**docs/dev_guide/**
- `coding_standards.md`
- `commit_conventions.md`
- `content_creation.md`
- `spawning_rules.md`
- `versioning.md`

**docs/mechanics/**
- `bonds.md`
- `combat_system.md`
- `sanity_panic.md`
- `xp_system.md`

**.agent/**
- `rules/behavior.md` — has overlap with `agents.md`; reconcile or remove duplication
- `workflows/build_and_deploy.md`

For each: read it, grep the symbols/paths/file names it references, and either fix in place or note specific drift items as their own follow-up tasks here.

---

## Resolution

Audited all listed docs. Fixes applied in place:

### `docs/architecture/ability_system.md`
- `CombatResolver` path corrected: `scripts/core/` → `scripts/managers/`
- `Ability` method names corrected:
  - `can_be_used(user, grid_manager)` → `can_use()` (no params)
  - `execute(user, target, grid_manager)` → `execute(user, target_unit, target_tile: Vector2, grid_manager)` (4 params)
  - `get_valid_targets(user, grid_manager)` → `get_valid_tiles(grid_manager, user)` (renamed, param order swapped)
- `cooldown` property → `cooldown_turns`; removed non-existent `target_type` enum
- `resolve_attack()` method corrected to `calculate_hit_chance()` / `resolve_standard_attack()`
- Usage flow updated with corrected method signatures

### `docs/architecture/ai_system.md`
- `AIBehaviorBase` interface corrected: `decide_action`/`score_position` don't exist on the base class. Actual methods: `evaluate_position`, `evaluate_target`, `get_special_action`, `_get_self_preservation_score`. `decide_action` is on `EnemyUnit`.
- `EnemyController` replaced with `TurnManager.start_enemy_turn()` (no EnemyController class exists)

### `docs/architecture/tactical_grid.md`
- GridManager method names corrected:
  - `get_path()` → `get_move_path()`
  - `get_cover_value()` → `get_best_cover_at()` (returns float, per-tile)
  - `is_tile_occupied()` → `get_unit_at_grid_pos()` / `is_tile_blocked()`
- Noted GridManager is per-mission (not global autoload)
- Noted cover math for hit chance lives in `CombatResolver.calculate_hit_chance()`

### `docs/architecture/signal_bus.md`
- `on_request_floating_text(pos, text, color)` → `(target, text, color)` (first param is `target` not `pos`)

### `docs/dev_guide/spawning_rules.md`
- `GridManager.is_tile_walkable()` → `GridManager.is_walkable()` (method name corrected)

### `.agent/rules/behavior.md`
- Replaced stale duplicate with a redirect to `agents.md` (which is the authoritative, up-to-date version)

### No drift found in:
- `docs/architecture/bond_system.md` — symbols verified (`trigger_bond_growth`, `get_active_bond_bonuses`, `clear_unit_bonds`, bond thresholds 10/25/50)
- `docs/architecture/memorial_system.md` — verified: `DMG_TYPE_*` constants, `COD_MAP`, `fallen_heroes`, `register_fallen_hero()` in `GameManager.gd`, `_on_unit_died` in `MissionManager.gd`
- `docs/architecture/persistence_rules.md` — still accurate
- `docs/architecture/testing_protocols.md` — `run_tests.ps1` and `run_tests_parallel.ps1` both exist; `TEST_MOCK_ENABLED` flag confirmed
- `docs/dev_guide/coding_standards.md` — accurate
- `docs/dev_guide/commit_conventions.md` — accurate
- `docs/dev_guide/content_creation.md` — `LevelGenerator.gd`, `EnemyModelFactory.gd`, `CorgiModelFactory.gd` all exist; `resources/weapons/` path correct
- `docs/dev_guide/versioning.md` — accurate
- `docs/mechanics/bonds.md` — thresholds 10/25/50 verified in code
- `docs/mechanics/combat_system.md` — crit 1.5x and 15 sanity damage verified in `CombatResolver.gd`
- `docs/mechanics/sanity_panic.md` — accurate
- `docs/mechanics/xp_system.md` — kill XP 50, mission victory XP 20, thresholds {100,300,600,1000} all verified
- `.agent/workflows/build_and_deploy.md` — references `build_game.ps1`, accurate
