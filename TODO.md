# TODO

## High Priority

### Audit and fix all joker_buffer = 0 instances

There are ~20 instances of `joker_buffer = 0` across the codebase that may cause issues when jokers are retriggered multiple times. The buffer should be decremented by the number of jokers created, not reset to 0.

**Background:** Fixed one instance in `lib/forcetrigger.lua` for Riff Raff (commit d60d03ce), but similar bugs likely exist elsewhere.

**Affected Files:**
- `lib/forcetrigger.lua:121`
- `items/spooky.lua:1415, 1445`
- `items/m.lua:1083, 1113, 1553, 1600`
- `items/epic.lua:1432`
- `items/misc_joker.lua:2959, 3001, 3100, 3142, 3241, 3283, 3663, 3693, 3718, 4416, 10260, 10279`

**The Bug Pattern:**
```lua
// BAD: Resets buffer, losing track of other queued joker creations
G.GAME.joker_buffer = 0

// GOOD: Decrement by the number of jokers this event created
G.GAME.joker_buffer = math.max(0, G.GAME.joker_buffer - jokers_created)
```

**Steps to Audit:**
1. For each instance, check the context
2. Determine how many jokers are being created/removed
3. Replace `= 0` with proper decrement
4. Add test if applicable
