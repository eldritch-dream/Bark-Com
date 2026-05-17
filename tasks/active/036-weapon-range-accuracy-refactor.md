# Refactor weapon system negative range multiplier to accuracy

**Category:** Refactor
**Source:** TODO.txt
**Original note:** "Refactor weapon system negative multiplier based range to accuracy calc"

Range falloff is currently expressed as a "negative multiplier"; move it into the accuracy calculation so the math is clearer and easier to balance. Check `scripts/systems/CombatResolver.gd` and weapon resources.
