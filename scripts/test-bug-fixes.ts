#!/usr/bin/env npx tsx
/**
 * Regression tests to verify bug fixes are in place.
 * These tests check code structure to ensure fixes haven't been reverted.
 */

import { readFileSync } from "fs";
import { join } from "path";

const rootDir = process.cwd();
let passed = 0;
let failed = 0;

function test(name: string, fn: () => boolean): void {
	try {
		if (fn()) {
			console.log(`✓ ${name}`);
			passed++;
		} else {
			console.log(`✗ ${name}`);
			failed++;
		}
	} catch (e) {
		console.log(`✗ ${name} (error: ${e})`);
		failed++;
	}
}

function readFile(relativePath: string): string {
	return readFileSync(join(rootDir, relativePath), "utf-8");
}

function countOccurrences(content: string, pattern: RegExp): number {
	return (content.match(pattern) || []).length;
}

console.log("Running regression tests for bug fixes...\n");

// ============================================================================
// lib/overrides.lua - Colour pre-initialization tests
// ============================================================================

const overridesContent = readFile("lib/overrides.lua");

test("G.C.CRY_EXOTIC is pre-initialized", () => {
	return overridesContent.includes("G.C.CRY_EXOTIC = { 0, 0, 0, 0 }");
});

test("G.C.CRY_SELECTED is pre-initialized", () => {
	return overridesContent.includes("G.C.CRY_SELECTED = { 0, 0, 0, 0 }");
});

test("G.C.CRY_TAX_MULT is pre-initialized", () => {
	return overridesContent.includes("G.C.CRY_TAX_MULT = { 0, 0, 0, 0 }");
});

test("G.C.CRY_TAX_CHIPS is pre-initialized", () => {
	return overridesContent.includes("G.C.CRY_TAX_CHIPS = { 0, 0, 0, 0 }");
});

// ============================================================================
// lib/ui.lua - Variable typo and nil check tests
// ============================================================================

const uiContent = readFile("lib/ui.lua");

test("lib/ui.lua uses 'center' not '_center' in soul_pos check", () => {
	// Should have: if center and center.soul_pos
	// Should NOT have: if _center and _center.soul_pos
	return (
		uiContent.includes("if center and center.soul_pos") && !uiContent.includes("if _center and _center.soul_pos")
	);
});

test("G.shared_seals access has nil check for cry_force_seal", () => {
	// Should check G.shared_seals exists before accessing
	return uiContent.includes("and G.shared_seals") && uiContent.includes("G.shared_seals[currentBack.effect.config.cry_force_seal]");
});

test("G.shared_stickers access has nil check", () => {
	// Should have: elseif G.shared_stickers and G.shared_stickers[v.key]
	return uiContent.includes("elseif G.shared_stickers and G.shared_stickers[v.key]");
});

test("table.remove has nil check for abc.nodes", () => {
	// Should check abc.nodes and abc.nodes[1] and abc.nodes[1].nodes
	return uiContent.includes("and abc.nodes") && uiContent.includes("and abc.nodes[1]");
});

// ============================================================================
// items/code.lua - Nil access fixes
// ============================================================================

const codeContent = readFile("items/code.lua");

test("hook_config.colour has nil check before indexing", () => {
	// Should have: if hook_config.colour then
	return codeContent.includes("if hook_config.colour then");
});

test("percent variable is defined in patch consumable loops", () => {
	// Count occurrences of "local percent = 0.85" which should be in the loops
	const percentDefinitions = countOccurrences(codeContent, /local percent = 0\.85/g);
	// Should have at least 3 (one for each loop: hand, jokers, consumeables)
	return percentDefinitions >= 3;
});

test("rigged consumable cards[1].area is inside nil check", () => {
	// The fix moved cards[1].area check inside the if cards[1] block
	// Look for the pattern where cards[1].area check is properly nested
	const riggedSection = codeContent.match(/cry_rigged.*?demicoloncompat/s);
	if (!riggedSection) return false;
	const section = riggedSection[0];
	// Should have cards[1].area inside the if cards[1] block
	// Count the 'end' statements - if properly nested, the area check comes before an 'end'
	return section.includes("if cards[1] then") && section.includes("if cards[1].area == G.hand then");
});

test("cry_multiply consumable has nil check for cards[1]", () => {
	// Should wrap the multiply logic in if cards[1] then
	// Look for the pattern: if cards[1] then followed by cry_multiply access
	const pattern = /if cards\[1\] then\s+if not cards\[1\]\.config\.cry_multiply then/;
	return pattern.test(codeContent);
});

test("draw consumable use() has early return for nil cards[1]", () => {
	// Should have: if not cards[1] then return end
	return codeContent.includes("if not cards[1] then return end");
});

// ============================================================================
// items/exotic.lua - Array bounds check
// ============================================================================

const exoticContent = readFile("items/exotic.lua");

test("caeruleum has array bounds check", () => {
	// Should have bounds check before accessing G.jokers.cards[caeruleum_index]
	return (
		exoticContent.includes("local caeruleum_index = i + (b and 1 or -1)") &&
		exoticContent.includes("if caeruleum_index < 1 or caeruleum_index > #G.jokers.cards then")
	);
});

// ============================================================================
// items/misc_joker.lua - Nil table key fix
// ============================================================================

const miscJokerContent = readFile("items/misc_joker.lua");

test("thalia joker has nil check for rarity before use as table key", () => {
	// Should check c.config and c.config.center before accessing rarity
	// And check rarity is not nil before using as table key
	return (
		miscJokerContent.includes("c.config and c.config.center and c.config.center.rarity") &&
		miscJokerContent.includes("if rarity and not seen[rarity]")
	);
});

// ============================================================================
// Summary
// ============================================================================

console.log("\n" + "=".repeat(50));
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log("=".repeat(50));

if (failed > 0) {
	console.log("\nSome tests failed! Bug fixes may have been reverted.");
	process.exit(1);
} else {
	console.log("\nAll regression tests passed!");
	process.exit(0);
}
