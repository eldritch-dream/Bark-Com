# Exploder still using ranged attack in some pathfinding cases

**Category:** Bug (possibly resolved)
**Source:** TODO.txt (Bugs)
**Original note:** "exploder still using ranged attack for some reason, in some cases where pathfinding determines theres no other way?"

Possibly fixed by `fix: exploder will now explode`. Need to reproduce: spawn an exploder in a scenario with no walkable path to a target and watch behavior. If still falls back to ranged, dig into AI fallback logic.
