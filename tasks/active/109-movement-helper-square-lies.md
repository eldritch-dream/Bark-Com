# Movement helper squares lie about valid squares

**Category:** Bug
**Source:** TODO.txt (Bugs)
**Original note:** "movement helper squares lie about valid squares sometimes still"

The reachability overlay shows tiles the unit can't actually reach. Likely a stale path-find result or a destructible/cover edge case. (Note: a related "movement squares need to update after enemy death" item already shipped.)
