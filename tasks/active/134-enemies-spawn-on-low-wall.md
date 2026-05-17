# Enemies spawn on low wall tiles with nowhere to go

**Category:** Bug
**Source:** TODO.txt (Bugs)
**Original note:** "enemies can spawn on low wall tiles with nowhere to go"

Enemy spawn picker is choosing low-wall tiles, leaving them stuck. Filter spawn candidates by walkability + at least one walkable neighbor.
