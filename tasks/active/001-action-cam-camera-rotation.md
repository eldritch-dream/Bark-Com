# Action cam ignores camera rotation (q/e)

**Category:** Bug
**Source:** TODO.txt #10
**Original note:** "User expressed that the camera is weird after using q and e to rotate (likely the action cam is not set up to think about the camera being rotated)"

Action cam likely uses a fixed-orientation assumption. Needs to account for the current camera yaw when framing shots.
