# Player turn occasionally skipped, cause unclear

**Category:** Bug
**Source:** TODO.txt (Bugs)
**Original note:** "skipped player turn in some scenario not really clear how it happened, maybe because of a unit death?"

Player turn ends prematurely. Suspected trigger: unit death mid-turn or some state transition flipping the phase. Add logging around phase transitions and chase it down.
