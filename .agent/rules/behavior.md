---
trigger: always_on
---

# Agent Behavior & Project Guidelines

> **This file is a thin redirect.** The authoritative agent guidelines live in [`agents.md`](../../agents.md) at the project root. Read that file first.

Key rules summarized here for quick reference (may lag behind `agents.md`):

- **Save data safety**: All tests must set `GameManager.TEST_MOCK_ENABLED = true`.
- **Persistence**: `unit_class` string is the source of truth; call `apply_class_stats()` before recalculating stats.
- **Logging**: Use `GameManager.log(LOG_PREFIX, …)` — never `print()`.
- **Testing**: Run via `tests/run_tests.ps1` or `tests/run_tests_parallel.ps1`.
- **GridManager** is per-mission (not a global autoload). Access it via `MissionManager.grid_manager`.

For everything else — autoload list, tech stack, doc links — see `agents.md`.
