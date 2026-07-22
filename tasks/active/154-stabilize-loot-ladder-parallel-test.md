# Stabilize loot/ladder crash test under parallel execution

**Category:** Tooling
**Source:** Follow-up from task 001 verification

`tests/test_loot_ladder_crash_runner.tscn` consistently reports `FAIL: No path for Ryan 4` when run as part of a four-worker full-suite pass under Linux Godot 4.6.3, while the same target passes when run alone on both the task branch and pristine `origin/main`.

Determine whether the failure depends on random map generation, worker isolation, engine version, or shared parallel state. Make the test deterministic and ensure it remains meaningful rather than merely suppressing the pathfinding assertion.

Acceptance criteria:
- The test passes repeatedly both alone and in the parallel runner.
- The generated map/seed needed for the assertion is deterministic or logged sufficiently to reproduce a failure.
- No production pathfinding behavior is weakened solely to accommodate the test.
