# Cryptid Development Guidelines

## Bug Fixing Process

**MANDATORY: Test-Driven Bug Fixing**

When discovering or fixing any bug, you MUST follow this process:

1. **Write a test first** that reproduces the bug
   - Add to `tests/test-nil-safety.lua` for nil-access bugs
   - Add to `scripts/test-bug-fixes.ts` for regression testing
   - The test should demonstrate the crash or incorrect behavior

2. **Verify the test fails** on the original/unfixed code
   - Run `npx tsx scripts/test-bug-fixes.ts` for regression tests
   - Run `cd tests && lua run-all-tests.lua` for Lua tests
   - Document the failure (e.g., "Original code: 1 failed")

3. **Implement the fix**

4. **Verify the test passes** with the fix in place
   - Run the same tests again
   - Document the success (e.g., "Fixed code: 15 passed")

5. **Update documentation**
   - Add the bug and fix to `BUGFIXES.md`
   - Update test counts in the summary

### Example Workflow

```bash
# 1. Write test for the bug
# Edit tests/test-nil-safety.lua or scripts/test-bug-fixes.ts

# 2. Verify test fails on original code
git checkout origin/main -- path/to/buggy/file.lua
npx tsx scripts/test-bug-fixes.ts
# Should show: ✗ my new test

# 3. Restore and apply fix
git checkout HEAD -- path/to/buggy/file.lua
# Edit the file to fix the bug

# 4. Verify test passes
npx tsx scripts/test-bug-fixes.ts
# Should show: ✓ my new test

# 5. Update BUGFIXES.md and commit
```

## Test Organization

- `tests/test-runner.lua` - Lua test framework
- `tests/test-nil-safety.lua` - Tests for specific bug fixes
- `tests/test-common-patterns.lua` - Tests documenting safe coding patterns
- `tests/run-all-tests.lua` - Runs all Lua tests
- `scripts/test-bug-fixes.ts` - TypeScript regression tests (checks code structure)
- `scripts/find-lua-bugs.ts` - Static analysis tool

## Common Crash Patterns to Watch For

When reviewing or writing code, check for these patterns:

1. **Nil table keys** - Never use a potentially nil value as a table key
2. **Deep property access** - Check each level: `a and a.b and a.b.c`
3. **Array bounds** - Check `i >= 1 and i <= #arr` before accessing `arr[i]`
4. **Chained methods on arrays** - Check element exists before calling methods
5. **Colour access before initialization** - Pre-initialize colours to `{ 0, 0, 0, 0 }`

See `BUGFIXES.md` for detailed examples and safe coding patterns.

## Adding Custom Deck Assets

When adding a custom image as a deck's visual asset:

### File Structure

- Deck assets go in `assets/1x/` (71x95 pixels) and `assets/2x/` (142x190 pixels)
- Naming convention: `b_cry_<deck_key>.png` (e.g., `b_cry_recycling_fee.png`)

### Steps

1. **Resize the source image** to deck dimensions:
   ```bash
   magick source.png -resize 71x95! assets/1x/b_cry_<deck_key>.png
   magick source.png -resize 142x190! assets/2x/b_cry_<deck_key>.png
   ```

2. **Add atlas definition** in `lib/content.lua` (after other deck atlases around line 727):
   ```lua
   SMODS.Atlas({
       key = "<deck_key>",
       path = "b_cry_<deck_key>.png",
       px = 71,
       py = 95,
   })
   ```

3. **Update the deck definition** in `items/deck.lua`:
   ```lua
   atlas = "<deck_key>",  -- was "atlasdeck"
   pos = { x = 0, y = 0 },  -- single-sprite atlas uses (0,0)
   ```

4. **Delete the source image** after creating the assets

### Why pos = {x = 0, y = 0}?

Individual deck atlases contain only one 71x95 sprite, so the position is always (0, 0). The shared `atlasdeck` atlas contains multiple decks in a grid, which is why decks using it have positions like `{x = 4, y = 6}`.
