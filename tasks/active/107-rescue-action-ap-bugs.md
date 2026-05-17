# Rescue action at 0 AP / does not end turn / goes to -1 AP

**Category:** Bug
**Source:** TODO.txt (consolidated from 3 entries)
**Original notes:**
- "rescue allowed with 0 AP? says costs 1 ap but i think 0 is ok"
- "rescue action can be taken at 0 ap -> goes to -1 ap"
- "using rescue as last action did not end the turn"

Inconsistent AP accounting for the rescue action. Decide whether rescue costs 0 or 1 AP, enforce that consistently, and make sure rescuing as the final action triggers the auto-end-turn check.
