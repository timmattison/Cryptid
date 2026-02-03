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
// items/tag.lua - Nil table key fix
// ============================================================================

const tagContent = readFile("items/tag.lua");

test("epic tag has nil check for key before use as table key", () => {
	// Should check config.center.key is not nil before using as table key
	return (
		tagContent.includes("v.config and v.config.center and v.config.center.key") ||
		tagContent.includes("local epic_key = v.config and v.config.center and v.config.center.key")
	);
});

// ============================================================================
// items/epic.lua - Nil table key fixes
// ============================================================================

const epicContent = readFile("items/epic.lua");

test("epic set_ability has nil check for rarity before use as table key", () => {
	// Should check v.rarity is not nil before using as table key
	return epicContent.includes("if v.rarity then");
});

test("epic banish has nil check for key before use as table key", () => {
	// Should check card.config.center.key is not nil before using as table key
	return (
		epicContent.includes("card.config and card.config.center and card.config.center.key") ||
		epicContent.includes("local banish_key = card.config and card.config.center and card.config.center.key")
	);
});

// ============================================================================
// lib/ascended.lua - Nil config.object fix
// ============================================================================

const ascendedContent = readFile("lib/ascended.lua");

test("ascended UI callback has nil check for e.config.object", () => {
	// Should check e.config and e.config.object before accessing
	return ascendedContent.includes("e.config and e.config.object");
});

// ============================================================================
// items/exotic.lua - Nil config.object fix
// ============================================================================

test("exotic hand_text_area has nil check for config.object", () => {
	// Should check G.hand_text_area and nested objects before accessing
	return (
		exoticContent.includes("G.hand_text_area and G.hand_text_area.handname and G.hand_text_area.handname.config and G.hand_text_area.handname.config.object") ||
		exoticContent.includes("if G.hand_text_area and G.hand_text_area.handname")
	);
});

// ============================================================================
// lib/overrides.lua - Nil config.object fix
// ============================================================================

test("overrides Ace Aequilibrium loop has max iterations", () => {
	// Should have max_tries to prevent infinite loop when no viable jokers
	return overridesContent.includes("max_tries") && overridesContent.includes("tries > max_tries");
});

test("overrides badges has nil check for config.object", () => {
	// Should check the deep chain before accessing config.object
	return (
		overridesContent.includes("badges[i].nodes[1].nodes[2].config and badges[i].nodes[1].nodes[2].config.object") ||
		overridesContent.includes("and badges[i].nodes and badges[i].nodes[1] and badges[i].nodes[1].nodes")
	);
});

// ============================================================================
// lib/forcetrigger.lua - Riff Raff joker buffer fix
// ============================================================================

const forcetriggerContent = readFile("lib/forcetrigger.lua");

test("Riff Raff forcetrigger decrements joker_buffer instead of resetting to 0", () => {
	// Should decrement joker_buffer by jokers_queued, not reset to 0
	// Look for the pattern: joker_buffer - jokers_queued (or similar decrement)
	const riffRaffSection = forcetriggerContent.match(/Riff-raff[\s\S]*?joker_buffer[\s\S]*?return true/);
	if (!riffRaffSection) return false;
	return (
		riffRaffSection[0].includes("joker_buffer - jokers_queued") ||
		riffRaffSection[0].includes("math.max(0, G.GAME.joker_buffer - jokers_queued)")
	);
});

// ============================================================================
// items/planet.lua - Infinite loop fix
// ============================================================================

const planetContent = readFile("items/planet.lua");

test("get_random_hand has max iterations to prevent infinite loop", () => {
	// Should have a max iteration counter to prevent infinite loop
	return (
		planetContent.includes("max_iterations") ||
		planetContent.includes("max_tries") ||
		planetContent.includes("tries = ") ||
		(planetContent.includes("while") && planetContent.includes("iterations"))
	);
});

// ============================================================================
// lib/overrides.lua - YOLOEcon Deck tests
// ============================================================================

test("YOLOEcon reroll check comes after free_rerolls check", () => {
	// Free rerolls from jokers/tags should take priority over YOLOEcon fixed pricing
	// The free_rerolls check should come BEFORE the cry_yoloecon check
	const freeRerollsIndex = overridesContent.indexOf("free_rerolls > 0");
	const yoloeconRerollIndex = overridesContent.indexOf('if G.GAME.modifiers.cry_yoloecon then\n\t\tG.GAME.current_round.reroll_cost = 1');
	return freeRerollsIndex !== -1 && yoloeconRerollIndex !== -1 && freeRerollsIndex < yoloeconRerollIndex;
});

test("YOLOEcon Joker pricing has nil safety for rarity access", () => {
	// Should have: self.config and self.config.center and self.config.center.rarity
	return overridesContent.includes("self.config and self.config.center and self.config.center.rarity");
});

test("YOLOEcon Joker pricing handles cry_epic rarity", () => {
	// Should handle cry_epic as Rare-tier pricing ($3)
	return overridesContent.includes('rarity == "cry_epic"');
});

test("YOLOEcon Joker pricing documents intentional behavior for special rarities", () => {
	// Should have a comment explaining that cry_candy and cry_cursed use base price
	return overridesContent.includes("cry_candy") && overridesContent.includes("cry_cursed") && overridesContent.includes("intentionally");
});

// ============================================================================
// lib/ui.lua - Recycling Fee big number comparison fix
// ============================================================================

test("Recycling Fee dollars comparison uses to_big() for big number safety", () => {
	// G.GAME.dollars can be a big number table, so comparison must use to_big()
	// Should have: to_big(G.GAME.dollars) < to_big(math.abs(card.sell_cost))
	// NOT: G.GAME.dollars < math.abs(card.sell_cost)
	return (
		uiContent.includes("to_big(G.GAME.dollars) < to_big(math.abs(card.sell_cost))") &&
		!uiContent.includes("and G.GAME.dollars < math.abs(card.sell_cost)")
	);
});

// ============================================================================
// items/deck.lua - Recycling Fee Deck mechanic interaction tests
// ============================================================================

const deckContent = readFile("items/deck.lua");

test("Recycling Fee deck checks for Ember Stake (cry_no_sell_value)", () => {
	// Should skip applying recycling fee if Ember Stake is active
	// This prevents conflicting sell mechanics
	return deckContent.includes("cry_no_sell_value");
});

test("Recycling Fee deck checks for Rotten Egg mechanic (cry_rotten_amount)", () => {
	// Should skip applying recycling fee if Rotten Egg is controlling sell costs
	return deckContent.includes("cry_rotten_amount");
});

test("Recycling Fee deck exempts cursed jokers", () => {
	// Cursed jokers have sell_cost = 0 and shouldn't be overridden to -2
	// Should check for rarity == "cry_cursed"
	return (
		deckContent.includes('rarity == "cry_cursed"') ||
		deckContent.includes("rarity == 'cry_cursed'")
	);
});

test("Recycling Fee deck exempts Egg jokers", () => {
	// Both vanilla Egg (j_egg) and Cryptid Megg (j_cry_megg) should be exempt
	return deckContent.includes("j_egg") && deckContent.includes("j_cry_megg");
});

// ============================================================================
// lib/controller-input.lua - Config key consistency tests
// ============================================================================

const controllerInputContent = readFile("lib/controller-input.lua");
const configContent = readFile("config.lua");
const cryptidMainContent = readFile("Cryptid.lua");
const localizationContent = readFile("localization/en-us.lua");

test("controller-input.lua config key matches config.lua", () => {
	// The config key used in controller-input.lua should exist in config.lua
	// controller-input.lua uses: Cryptid_config.controller_buttons
	const usesControllerButtons = controllerInputContent.includes("Cryptid_config.controller_buttons");
	const configHasControllerButtons = configContent.includes('["controller_buttons"]');
	return usesControllerButtons && configHasControllerButtons;
});

test("Cryptid.lua UI toggle uses same config key as controller-input.lua", () => {
	// The ref_value in Cryptid.lua should match what controller-input.lua checks
	const cryptidRefValue = cryptidMainContent.includes('ref_value = "controller_buttons"');
	const controllerInputKey = controllerInputContent.includes("Cryptid_config.controller_buttons");
	return cryptidRefValue && controllerInputKey;
});

test("Cryptid.lua localize key matches localization file", () => {
	// The localize() call in Cryptid.lua should have a matching key in en-us.lua
	const cryptidLocalizeKey = cryptidMainContent.includes('localize("cry_controller_buttons")');
	const localizationHasKey = localizationContent.includes("cry_controller_buttons");
	return cryptidLocalizeKey && localizationHasKey;
});

// ============================================================================
// lovely/none.toml - BigNum overflow prevention tests
// ============================================================================

const noneTomlContent = readFile("lovely/none.toml");

test("none.toml level_up_hand patch uses to_big for chips", () => {
	// The payload should use to_big() to prevent overflow
	return noneTomlContent.includes("to_big(G.GAME.hands[hand].chips)");
});

test("none.toml level_up_hand patch uses to_big for mult", () => {
	// The payload should use to_big() for mult as well
	return noneTomlContent.includes("to_big(G.GAME.hands[hand].mult)");
});

test("none.toml level_up_hand patch uses to_big for l_chips", () => {
	// The per-level increment should also use to_big()
	return noneTomlContent.includes("to_big(G.GAME.hands[hand].l_chips)");
});

test("none.toml level_up_hand patch clamps chips to minimum", () => {
	// The pattern should clamp chips to prevent negative values
	// Pattern: new_chips < to_big(1) and to_big(1) or new_chips
	return noneTomlContent.includes("new_chips < to_big(1)");
});

test("none.toml payload does NOT use vulnerable pattern (chips without to_big)", () => {
	// The OLD vulnerable pattern was:
	// G.GAME.hands[hand].chips = G.GAME.hands[hand].chips + G.GAME.hands[hand].l_chips*amount
	// This should NOT be in the payload section (only in the pattern section we're replacing)

	// Extract the payload section for level_up_hand (matches payload containing G.GAME.hands[hand].level)
	const payloadMatch = noneTomlContent.match(/payload = '''[\s\S]*?G\.GAME\.hands\[hand\]\.level[\s\S]*?'''/);
	if (!payloadMatch) {
		console.error("  ERROR: Could not find level_up_hand payload in none.toml - TOML structure may have changed");
		return false;
	}

	const payload = payloadMatch[0];
	// The vulnerable pattern should NOT appear in the payload
	const vulnerablePattern = /G\.GAME\.hands\[hand\]\.chips\s*=\s*G\.GAME\.hands\[hand\]\.chips\s*\+\s*G\.GAME\.hands\[hand\]\.l_chips\s*\*\s*amount/;
	return !vulnerablePattern.test(payload);
});

// ============================================================================
// items/misc.lua - BigNum overflow prevention tests
// ============================================================================

const miscContent = readFile("items/misc.lua");

test("misc.lua cry_oversat uses to_big for chip arithmetic", () => {
	// Should use: to_big(G.GAME.hands[hand].chips) + to_big(...)
	return miscContent.includes("to_big(G.GAME.hands[hand].chips) + to_big(G.GAME.hands[hand].l_chips)");
});

test("misc.lua cry_glitched uses to_big for chip arithmetic", () => {
	// Should use: to_big(G.GAME.hands[hand].chips) + to_big(modc)
	return miscContent.includes("to_big(G.GAME.hands[hand].chips) + to_big(modc)");
});

test("misc.lua cry_noisy uses to_big for chip arithmetic", () => {
	// cry_noisy function should also use to_big pattern
	// Count occurrences - we should have 2 instances of this pattern (glitched and noisy)
	const pattern = /to_big\(G\.GAME\.hands\[hand\]\.chips\) \+ to_big\(modc\)/g;
	return countOccurrences(miscContent, pattern) >= 2;
});

test("misc.lua does NOT use vulnerable math.max pattern for hand chips", () => {
	// The old vulnerable pattern was:
	// G.GAME.hands[hand].chips = math.max(G.GAME.hands[hand].chips + modc, 1)
	const vulnerablePattern = /G\.GAME\.hands\[hand\]\.chips\s*=\s*math\.max\s*\(\s*G\.GAME\.hands\[hand\]\.chips\s*\+\s*modc/;
	return !vulnerablePattern.test(miscContent);
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
