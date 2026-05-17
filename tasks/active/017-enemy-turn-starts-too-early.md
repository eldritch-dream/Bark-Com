# Enemy turn starts before ally finishes moving or grenade animates

**Category:** Bug / UX
**Source:** TODO.txt #53
**Original note:** "User expressed that enemy turn should not be initiated until ally is done moving or grenade is done animating"

End-turn → enemy phase transition needs to await any in-flight unit movement and ability animations before handing off.
