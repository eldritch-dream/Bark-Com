# Cover helper does not update after cover is destroyed

**Category:** Bug
**Source:** TODO.txt (Bugs)
**Original note:** "cover helper needs to update after cover gets destroyed"

The cover-indicator overlay on enemies/allies doesn't recompute when destructible cover is destroyed. Listen for cover-destroyed signal and refresh.
