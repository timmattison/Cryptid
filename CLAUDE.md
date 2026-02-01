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
6. **Hook function parameters** - Always check `e and e.config` before accessing nested properties in UI hooks

See `BUGFIXES.md` for detailed examples and safe coding patterns.

## Code Review Checklist

### Deck Definitions

When adding new decks, verify:

- [ ] **Dependencies are minimal** - Only include dependencies that are strictly required for the deck to function. If a feature is optional (e.g., exotic jokers), use runtime checks (`Cryptid.enabled()`) instead of hard dependencies.
- [ ] **Atlas position exists** - Run `scripts/fill-atlas-placeholders.sh` if using a new position
- [ ] **Hooks check all parameters** - UI hooks like `can_buy(e)` must check `e and e.config` before accessing nested properties
- [ ] **Localization matches behavior** - Description should accurately reflect what the deck does

### Lovely Patches

When adding Lovely patches:

- [ ] **Nil-safe game state access** - Check globals like `G.GAME`, `G.shop_jokers` exist before use
- [ ] **Runtime feature checks** - Use `Cryptid.enabled('set_name')` for optional features
- [ ] **Seed uniqueness** - Include ante/round/slot in `pseudorandom()` seeds to avoid repeated results

### Shell Scripts

When adding shell scripts:

- [ ] **Quote all variables** - Use `"$var"` not `$var` to handle paths with spaces
- [ ] **Safe file operations** - Write to temp file first, then move for in-place updates
- [ ] **Error handling** - Use `set -e` at the top

## False Positives (Do Not Flag)

These patterns may look like issues but are intentional:

1. **`G.GAME.round_resets.ante` without nil check in Lovely patches** - When the patch runs (during shop setup), the game state is guaranteed to exist. This matches existing patterns in `spooky.toml`, `stake.toml`, etc.

2. **Global hook registration in `init` function** - Hooks like `can_buy` are registered globally when the mod loads, not per-run. This is correct because the hooks check for the deck modifier (`G.GAME.modifiers.cry_*`) before acting.
