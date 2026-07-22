# Action cam ignores camera rotation (q/e)

**Category:** Bug
**Source:** TODO.txt #10
**Original note:** "User expressed that the camera is weird after using q and e to rotate (likely the action cam is not set up to think about the camera being rotated)"

Action cam likely uses a fixed-orientation assumption. Needs to account for the current camera yaw when framing shots.

## Resolution

The cinematic camera now captures the player's current rotation alongside position and zoom, then restores that orientation after action, zoom, and death cinematics instead of resetting to the startup yaw. Added a regression scene that rotates the camera 45 degrees and verifies the cinematic reset preserves it.
Files touched: `scripts/systems/CinematicCamera.gd`, `tests/verify_cinematic_camera_rotation.gd`, `tests/verify_cinematic_camera_rotation.tscn`
Follow-ups created: 154 — Stabilize loot/ladder crash test under parallel execution
