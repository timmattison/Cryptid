# Bug Fixes and Test Suite

This document describes the nil-access crash fixes, the test suite, and common patterns to avoid when writing Lua code for Balatro mods.

## Summary

- **24 bugs fixed** across 11 files
- **97 tests written** (72 Lua + 25 TypeScript)
- **2630 potential issues identified** by static analysis

## Bugs Fixed

### lib/overrides.lua - Colour Pre-initialization (4 fixes)

Colours like `G.C.CRY_EXOTIC` were only populated in `Game:update()` but could be accessed before the first frame rendered, causing crashes with "attempt to index field 'colour' (a nil value)".

| Colour | Fix |
|--------|-----|
| `G.C.CRY_EXOTIC` | Pre-initialized to `{ 0, 0, 0, 0 }` |
| `G.C.CRY_SELECTED` | Pre-initialized to `{ 0, 0, 0, 0 }` |
| `G.C.CRY_TAX_MULT` | Pre-initialized to `{ 0, 0, 0, 0 }` |
| `G.C.CRY_TAX_CHIPS` | Pre-initialized to `{ 0, 0, 0, 0 }` |

### lib/ui.lua - Variable Typo and Nil Checks (5 fixes)

| Bug | Fix |
|-----|-----|
| `_center` typo | Changed to `center` in soul_pos check |
| `G.shared_seals` nil access | Added `and G.shared_seals` before accessing |
| `G.shared_stickers` nil access | Added `and G.shared_stickers` before accessing |
| `table.remove` on nil | Added checks for `abc.nodes` and `abc.nodes[1]` |
| Recycling Fee big number comparison | Wrapped `G.GAME.dollars` comparison with `to_big()` for big number safety |

The Recycling Fee deck's sell button check compared `G.GAME.dollars < math.abs(card.sell_cost)` directly, but `G.GAME.dollars` can be a big number table (not a plain number) when using the big numbers feature. This caused "attempt to compare table with number" crash.

### items/code.lua - Nil Access in Consumables (4 fixes)

| Bug | Fix |
|-----|-----|
| `hook_config.colour` indexing | Wrapped in `if hook_config.colour then` |
| `percent` undefined in loops | Added `local percent = 0.85` in each patch loop |
| `cry_multiply` nil cards | Wrapped in `if cards[1] then` |
| `draw` consumable nil cards | Added `if not cards[1] then return end` |

### items/exotic.lua - Array Bounds (1 fix)

| Bug | Fix |
|-----|-----|
| `caeruleum` out-of-bounds | Added bounds check before accessing `G.jokers.cards[caeruleum_index]` |

### items/misc_joker.lua - Nil Table Key (1 fix)

| Bug | Fix |
|-----|-----|
| `thalia` nil rarity as table key | Added nil checks for `c.config.center.rarity` before using as key |

The `thalia` joker's `calc_xmult` function iterates through jokers and uses their rarity as a table key. If a joker has no rarity (nil), using nil as a table key causes "table index is nil" crash.

### items/tag.lua - Nil Table Key (1 fix)

| Bug | Fix |
|-----|-----|
| `epic` tag nil key as table key | Added nil checks for `v.config.center.key` before using as key |

The epic tag iterates jokers and uses their key as a table key to track which epic jokers are in possession.

### items/epic.lua - Nil Table Key (2 fixes)

| Bug | Fix |
|-----|-----|
| `set_ability` nil rarity as table key | Added `if v.rarity then` check before using as key |
| `banish` nil key as table key | Added nil checks for `card.config.center.key` before using as key |

### lib/ascended.lua - Nil config.object (1 fix)

| Bug | Fix |
|-----|-----|
| `cry_asc_UI_set` nil object | Added `if not (e.config and e.config.object) then return end` |

The UI callback function accessed `e.config.object` without checking if the UI element was fully initialized, causing "attempt to index field 'object' (a nil value)" in engine/ui.lua.

### items/exotic.lua - Nil config.object (1 fix, 2 locations)

| Bug | Fix |
|-----|-----|
| `hand_text_area` nil object | Added nil checks for `G.hand_text_area.handname.config.object` and `G.hand_text_area.chip_total.config.object` |

### lib/overrides.lua - Nil config.object (1 fix)

| Bug | Fix |
|-----|-----|
| `badges` deep chain nil | Added nil checks for `badges[i].nodes[1].nodes[2].config.object` |

### items/planet.lua - Infinite Loop (1 fix)

| Bug | Fix |
|-----|-----|
| `get_random_hand` infinite loop | Added `max_tries` counter with fallback return |

The `Cryptid.get_random_hand` function had a `while true` loop with no escape condition if all poker hands were hidden or in the ignore list. This caused the game to freeze indefinitely. Added a max iteration counter (1000) with a fallback that returns the first visible hand or first hand in list.

### lib/overrides.lua - Infinite Loop (1 fix)

| Bug | Fix |
|-----|-----|
| `Ace Aequilibrium` joker creation infinite loop | Added `max_tries` counter to break if no viable jokers found |

The `create_card` override for Ace Aequilibrium had a while loop that searched for a viable joker. If all jokers were locked, excluded, or exotic, the loop would run forever. Added max_tries counter that limits iterations to the number of jokers in the pool.

### lib/forcetrigger.lua - Joker Buffer Bug (1 fix)

| Bug | Fix |
|-----|-----|
| `Riff Raff` joker_buffer reset to 0 | Changed to decrement by jokers created |

When Riff Raff was retriggered multiple times (e.g., by multiple Chad jokers with 8-15 retriggers each), the `joker_buffer` was incorrectly reset to 0 instead of being decremented. This caused the game to lose track of queued joker creations, potentially creating 60+ jokers and causing a freeze/crash.

## Test Suite

### Lua Tests (72 tests)

Run with: `cd tests && lua run-all-tests.lua`

#### test-nil-safety.lua (35 tests)
Tests verifying the specific bug fixes work correctly:
- Colour pre-initialization tests
- G.shared_seals/G.shared_stickers nil check tests
- table.remove nil check tests
- cards[1] nil check tests
- hook_config.colour nil check tests
- Nil table key tests (thalia, epic tag, epic set_ability, epic banish)
- caeruleum array bounds check tests
- center vs _center variable tests
- percent variable definition tests

#### test-common-patterns.lua (37 tests)
Tests documenting safe vs unsafe patterns:
- `card.ability.extra` access patterns
- `G.GAME` nil access patterns
- `G.jokers.cards` iteration patterns
- `G.hand.cards` access patterns
- Chained method on array access
- `card.children` access patterns
- `card.base` access patterns
- `P.centers` variable key access
- Array offset/bounds patterns
- Deep property access chains
- Callback array index staleness
- Missing return in functions

### TypeScript Regression Tests (24 tests)

Run with: `npx tsx scripts/test-bug-fixes.ts`

These tests check the code structure to ensure fixes haven't been reverted. They verify:
- All 4 colours are pre-initialized in lib/overrides.lua
- All 4 nil checks exist in lib/ui.lua
- All 4 fixes exist in items/code.lua
- Bounds check exists in items/exotic.lua

## Static Analysis

Run with: `npx tsx scripts/find-lua-bugs.ts`

The static analysis tool found 2630 potential issues across the codebase. Most are likely false positives due to Balatro's framework guarantees, but the patterns identified are worth being aware of.

### High-Frequency Patterns

| Count | Pattern | Description |
|-------|---------|-------------|
| 1089 | `ability-extra-no-nil-check` | Accessing `card.ability.extra.x` without nil checks |
| 250 | `ggame-assignment-no-check` | Assigning to `G.GAME.x` without checking G.GAME exists |
| 244 | `game-area-no-check-jokers` | Accessing `G.jokers.cards` without nil check |
| 229 | `deep-property-access` | Long chains like `a.b.c.d` where any level could be nil |
| 157 | `possible-typo-underscore-var` | Variables starting with `_` that might be typos |
| 87 | `p-centers-variable-key-no-check` | Accessing `G.P.centers[var]` without checking key exists |
| 83 | `missing-return-in-calculate` | Calculate functions without return statements |
| 62 | `game-area-no-check-hand` | Accessing `G.hand.cards` without nil check |
| 55 | `array-offset-no-bounds-check` | Array access like `arr[i+1]` without bounds check |
| 54 | `children-access-no-check` | Accessing `card.children.x` without nil check |
| 47 | `chained-method-on-array-access` | Calling `arr[i]:method()` without checking arr[i] |

## Safe Coding Patterns

### Always check before deep access

```lua
-- BAD: Can crash if ability or extra is nil
local mult = card.ability.extra.mult

-- GOOD: Check each level
if card.ability and card.ability.extra then
    local mult = card.ability.extra.mult
end
```

### Always check array bounds

```lua
-- BAD: Can crash if i+1 exceeds array length
local next_card = G.jokers.cards[i + 1]
next_card:start_dissolve()

-- GOOD: Check bounds first
local next_idx = i + 1
if next_idx <= #G.jokers.cards and G.jokers.cards[next_idx] then
    G.jokers.cards[next_idx]:start_dissolve()
end
```

### Always check game areas exist

```lua
-- BAD: Can crash if G.jokers is nil
for i, card in ipairs(G.jokers.cards) do

-- GOOD: Check area exists
if G.jokers and G.jokers.cards then
    for i, card in ipairs(G.jokers.cards) do
```

### Pre-initialize colours

```lua
-- In initialization code, before first frame:
G.C.MY_CUSTOM_COLOUR = { 0, 0, 0, 0 }

-- Then update in Game:update():
G.C.MY_CUSTOM_COLOUR = { r, g, b, a }
```

### Use early returns for required parameters

```lua
-- GOOD: Early return if required data is missing
function my_consumable:use(card, area, copier)
    local cards = self:get_selected_cards()
    if not cards[1] then return end

    -- Rest of function can safely use cards[1]
end
```

### Wrap G.GAME.dollars comparisons in to_big()

`G.GAME.dollars` can be a big number table (not a plain Lua number) when using the big numbers feature. Direct comparisons will crash with "attempt to compare table with number".

```lua
-- BAD: Will crash if G.GAME.dollars is a big number table
if G.GAME.dollars < cost then

-- GOOD: Use to_big() to handle both regular numbers and big numbers
if to_big(G.GAME.dollars) < to_big(cost) then
```

The static analysis tool (`find-lua-bugs.ts`) now detects this pattern with the `dollars-comparison-no-to-big` check.
