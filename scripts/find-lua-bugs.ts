#!/usr/bin/env npx tsx
/**
 * Static analysis script to find common Lua bug patterns in the Cryptid mod.
 * Scans for patterns that could cause crashes like nil access, undefined variables,
 * array bounds issues, and missing colour initializations.
 */

import { readFileSync, readdirSync, statSync } from "fs";
import { join, relative } from "path";

interface BugReport {
	file: string;
	line: number;
	pattern: string;
	code: string;
	severity: "error" | "warning" | "info";
}

const bugs: BugReport[] = [];

/**
 * Recursively get all Lua files in a directory
 */
function getLuaFiles(dir: string): string[] {
	const files: string[] = [];
	const entries = readdirSync(dir);

	for (const entry of entries) {
		const fullPath = join(dir, entry);
		const stat = statSync(fullPath);

		if (stat.isDirectory() && !entry.startsWith(".") && entry !== "node_modules") {
			files.push(...getLuaFiles(fullPath));
		} else if (entry.endsWith(".lua")) {
			files.push(fullPath);
		}
	}

	return files;
}

/**
 * Check for indexing into .colour without nil check
 */
function checkColourIndexing(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: accessing colour[n] without a nil check nearby
		const colourIndexMatch = line.match(/(\w+)\.colour\[(\d+)\]/);
		if (colourIndexMatch) {
			// Check if there's a nil check in the surrounding context (5 lines before)
			const context = lines.slice(Math.max(0, i - 5), i + 1).join("\n");
			const varName = colourIndexMatch[1];
			if (!context.includes(`if ${varName}.colour`) && !context.includes(`${varName}.colour and`)) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "colour-index-no-nil-check",
					code: line.trim(),
					severity: "error",
				});
			}
		}
	}
}

/**
 * Check for potential undefined variable usage (variable declared with different name than used)
 * NOTE: This has many false positives because Lua idiomatically uses _var for unused loop variables
 * Only flag if the _var is actually used (not just declared in a for loop)
 */
function checkUndefinedVariables(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: local x = ... followed by usage of _x (but not in a for loop pattern)
		const localMatch = line.match(/^(\s*)local\s+(\w+)\s*=(?!=)/);
		if (localMatch && !line.includes("for ")) {
			const varName = localMatch[2];
			// Check next 10 lines for underscore variant being used (not just declared)
			const nextLines = lines.slice(i + 1, i + 11);

			// Skip common false positives: single letter vars, loop vars
			if (varName.length === 1) continue;

			for (let j = 0; j < nextLines.length; j++) {
				const nextLine = nextLines[j];
				// Check if _varName is used (not just in a for loop declaration)
				if (
					nextLine.includes(`_${varName}`) &&
					!nextLine.includes(`local _${varName}`) &&
					!nextLine.match(/for\s+.*_${varName}/) &&
					!nextLine.match(/,\s*_${varName}\s+in/)
				) {
					// This might be a real typo
					bugs.push({
						file,
						line: lineNum,
						pattern: "possible-typo-underscore-var",
						code: `Declared '${varName}' but '_${varName}' used at line ${lineNum + j + 1}`,
						severity: "info", // Downgrade to info since many are false positives
					});
					break;
				}
			}
		}
	}
}

/**
 * Check for array access without bounds checking
 */
function checkArrayBounds(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: array[i + n] or array[i - n] without bounds check
		const arrayOffsetMatch = line.match(/(\w+)\[(\w+)\s*([+-])\s*(\d+)\]/);
		if (arrayOffsetMatch) {
			const context = lines.slice(Math.max(0, i - 5), i + 1).join("\n");
			const arrayName = arrayOffsetMatch[1];
			const indexVar = arrayOffsetMatch[2];
			const op = arrayOffsetMatch[3];
			const offset = arrayOffsetMatch[4];

			// Check if this looks like a cards array access
			if (arrayName.includes("cards") || arrayName.includes("jokers")) {
				// Check for bounds checking in context
				if (!context.includes(`< 1`) && !context.includes(`> #`) && !context.includes(`<= #`) && !context.includes(`>= 1`)) {
					bugs.push({
						file,
						line: lineNum,
						pattern: "array-offset-no-bounds-check",
						code: line.trim(),
						severity: "warning",
					});
				}
			}
		}
	}
}

/**
 * Check for play_sound calls with undefined percent variable
 */
function checkPlaySoundPercent(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: play_sound(..., percent) where percent might not be defined
		if (line.includes("play_sound") && line.includes("percent")) {
			// Check if percent is defined in the surrounding scope (50 lines before to account for closures)
			const context = lines.slice(Math.max(0, i - 50), i).join("\n");
			if (!context.includes("local percent")) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "undefined-percent-in-play-sound",
					code: line.trim(),
					severity: "error",
				});
			}
		}
	}
}

/**
 * Check for G.C.CRY_* colours used but not in the initialization list
 */
function checkColourInitialization(content: string, file: string, allContent: Map<string, string>): void {
	const lines = content.split("\n");

	// Find all G.C.CRY_* usages
	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		const cryColourMatches = line.matchAll(/G\.C\.CRY_(\w+)/g);
		for (const match of cryColourMatches) {
			const colourName = match[1];

			// Skip if this is a definition line
			if (line.includes(`G.C.CRY_${colourName} =`) || line.includes(`G.C["CRY_${colourName}"]`)) {
				continue;
			}

			// Check if this colour is initialized in overrides.lua
			const overridesContent = allContent.get("lib/overrides.lua") || "";
			const initPattern = new RegExp(`G\\.C\\.CRY_${colourName}\\s*=\\s*\\{`);
			const dynamicInitPattern = new RegExp(`Cryptid\\.C\\s*=\\s*\\{[^}]*${colourName}`);

			if (!initPattern.test(overridesContent)) {
				// Check if it's in the dynamic Cryptid.C table
				if (dynamicInitPattern.test(overridesContent)) {
					// It's dynamically initialized, but might not be pre-initialized
					const preInitPattern = new RegExp(`G\\.C\\.CRY_${colourName}\\s*=`);
					if (!preInitPattern.test(overridesContent)) {
						bugs.push({
							file,
							line: lineNum,
							pattern: "colour-not-pre-initialized",
							code: `G.C.CRY_${colourName} used but not pre-initialized (only in Cryptid.C)`,
							severity: "warning",
						});
					}
				}
			}
		}
	}
}

/**
 * Check for potential nil access on nested properties
 */
function checkNestedNilAccess(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: deep property access like a.b.c.d without safe_get or nil checks
		// Look for 4+ levels of property access
		const deepAccessMatch = line.match(/(\w+)\.(\w+)\.(\w+)\.(\w+)\.(\w+)/);
		if (deepAccessMatch) {
			const context = lines.slice(Math.max(0, i - 3), i + 1).join("\n");
			const rootVar = deepAccessMatch[1];

			// Skip if using safe_get or has nil checks
			if (!context.includes("safe_get") && !context.includes(`${rootVar} and`) && !context.includes(`if ${rootVar}`)) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "deep-property-access",
					code: line.trim(),
					severity: "info",
				});
			}
		}
	}
}

/**
 * Check for G.shared_* access without existence check
 */
function checkSharedAccess(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: G.shared_seals[x] or G.shared_stickers[x] without check
		const sharedMatch = line.match(/G\.(shared_\w+)\[([^\]]+)\]/);
		if (sharedMatch) {
			const context = lines.slice(Math.max(0, i - 3), i + 1).join("\n");
			const sharedName = sharedMatch[1];
			const key = sharedMatch[2];

			if (!context.includes(`G.${sharedName} and`) && !context.includes(`G.${sharedName}[${key}] and`)) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "shared-access-no-check",
					code: line.trim(),
					severity: "warning",
				});
			}
		}
	}
}

/**
 * Check for table.remove on nodes without checking if nodes exist
 */
function checkTableRemove(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: table.remove(x.nodes, n) without checking x.nodes exists
		const removeMatch = line.match(/table\.remove\(([^,]+)\.nodes/);
		if (removeMatch) {
			const context = lines.slice(Math.max(0, i - 3), i + 1).join("\n");
			const varName = removeMatch[1];

			if (!context.includes(`${varName}.nodes and`) && !context.includes(`if ${varName}.nodes`)) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "table-remove-no-check",
					code: line.trim(),
					severity: "warning",
				});
			}
		}
	}
}

/**
 * Check for division that could result in NaN (division by zero or near-zero)
 */
function checkDivisionByZero(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: / (#array - 0.998) which fails when array has 1 element
		const divMatch = line.match(/\/\s*\(#(\w+)\s*-\s*0\.998\)/);
		if (divMatch) {
			bugs.push({
				file,
				line: lineNum,
				pattern: "potential-div-by-near-zero",
				code: `Division by (#${divMatch[1]} - 0.998) could be ~0 when array has 1 element`,
				severity: "info",
			});
		}
	}
}

/**
 * Check for card.ability.extra.* access without nil checks
 */
function checkAbilityExtraAccess(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: card.ability.extra.something without using safe_get or nil checks
		const extraMatch = line.match(/(\w+)\.ability\.extra\.(\w+)/);
		if (extraMatch) {
			const context = lines.slice(Math.max(0, i - 5), i + 1).join("\n");
			const varName = extraMatch[1];

			// Skip if there's a nil check or safe_get nearby
			if (
				!context.includes("safe_get") &&
				!context.includes(`${varName}.ability and`) &&
				!context.includes(`${varName}.ability.extra and`) &&
				!context.includes(`if ${varName}.ability`)
			) {
				// Only flag if it's a direct access (not inside a safe_get call)
				if (!line.includes("safe_get")) {
					bugs.push({
						file,
						line: lineNum,
						pattern: "ability-extra-no-nil-check",
						code: line.trim(),
						severity: "info",
					});
				}
			}
		}
	}
}

/**
 * Check for G.P_CENTERS[key] access without nil check
 */
function checkPCentersAccess(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: G.P_CENTERS[variable] (not a string literal)
		const pCentersMatch = line.match(/G\.P_CENTERS\[([^\]"']+)\]/);
		if (pCentersMatch) {
			const context = lines.slice(Math.max(0, i - 3), i + 1).join("\n");
			const key = pCentersMatch[1];

			// Skip if there's a nil check
			if (!context.includes(`G.P_CENTERS[${key}] and`) && !context.includes(`if G.P_CENTERS[${key}]`)) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "p-centers-variable-key-no-check",
					code: line.trim(),
					severity: "info",
				});
			}
		}
	}
}

/**
 * Check for G.jokers.cards or G.hand.cards access without checking G.jokers/G.hand exists
 */
function checkGameAreaAccess(content: string, file: string): void {
	const lines = content.split("\n");
	const areas = ["jokers", "hand", "play", "deck", "discard", "consumeables"];

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		for (const area of areas) {
			// Pattern: G.area.cards without checking G.area exists
			const areaMatch = line.match(new RegExp(`G\\.${area}\\.cards`));
			if (areaMatch) {
				const context = lines.slice(Math.max(0, i - 5), i + 1).join("\n");

				if (!context.includes(`G.${area} and`) && !context.includes(`if G.${area}`)) {
					bugs.push({
						file,
						line: lineNum,
						pattern: `game-area-no-check-${area}`,
						code: line.trim(),
						severity: "info",
					});
				}
			}
		}
	}
}

/**
 * Check for array index access in callbacks that might execute after array changes
 * This is NOT a loop variable closure bug (Lua handles that correctly), but rather
 * that G.something.cards[i] might be different/nil by the time the callback runs
 */
function checkArrayAccessInCallbacks(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Look for G.E_MANAGER:add_event calls
		if (line.includes("G.E_MANAGER:add_event")) {
			// Look ahead at the callback body
			const callbackBlock = lines.slice(i, Math.min(i + 15, lines.length)).join("\n");

			// Check if callback uses array[i] pattern on mutable arrays
			const dangerousPattern = /G\.(hand|jokers|play|deck|discard|consumeables)\.cards\[(\w+)\]/;
			const match = callbackBlock.match(dangerousPattern);

			if (match) {
				const arrayName = match[1];
				const indexVar = match[2];

				// Check if there's a local capture before the event
				const contextBefore = lines.slice(Math.max(0, i - 5), i).join("\n");
				const hasCapture =
					contextBefore.includes(`local CARD = G.${arrayName}.cards[${indexVar}]`) ||
					contextBefore.includes(`local card = G.${arrayName}.cards[${indexVar}]`);

				if (!hasCapture) {
					bugs.push({
						file,
						line: lineNum,
						pattern: "array-access-in-callback",
						code: `G.${arrayName}.cards[${indexVar}] in callback - array may change before execution`,
						severity: "info", // Downgraded - often works fine in practice
					});
				}
			}
		}
	}
}

/**
 * Check for string concatenation with potentially nil values
 */
function checkStringConcatNil(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: .. variable .. where variable might be from a function that can return nil
		// Focus on dangerous patterns like: localize() result concatenation
		if (line.includes("..") && line.includes("localize(")) {
			// Check if the localize result is used directly in concatenation without tostring
			if (!line.includes("tostring") && !line.includes("or ")) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "concat-localize-no-fallback",
					code: line.trim(),
					severity: "info",
				});
			}
		}
	}
}

/**
 * Check for method calls on potentially nil card references
 */
function checkNilMethodCalls(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: variable:method() where variable comes from array access in same/recent line
		// e.g., G.jokers.cards[i]:juice_up()
		const chainedCallMatch = line.match(/(\w+)\[([^\]]+)\]:(\w+)\(/);
		if (chainedCallMatch) {
			const array = chainedCallMatch[1];
			const index = chainedCallMatch[2];
			const method = chainedCallMatch[3];

			// This is risky - accessing array element and immediately calling method
			if (array.includes("cards") || array.includes("jokers")) {
				const context = lines.slice(Math.max(0, i - 3), i + 1).join("\n");
				if (!context.includes(` and ${array}[${index}]`) && !context.includes(`if ${array}[${index}]`)) {
					bugs.push({
						file,
						line: lineNum,
						pattern: "chained-method-on-array-access",
						code: line.trim(),
						severity: "warning",
					});
				}
			}
		}
	}
}

/**
 * Check for potentially missing return statements in functions that seem to need them
 */
function checkMissingReturns(content: string, file: string): void {
	const lines = content.split("\n");
	let inFunction = false;
	let funcStartLine = 0;
	let braceDepth = 0;
	let hasReturn = false;
	let funcName = "";

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Detect function that looks like it should return something (loc_vars, calculate, etc.)
		const funcMatch = line.match(/(loc_vars|calculate|can_use|set_ability)\s*=\s*function/);
		if (funcMatch) {
			inFunction = true;
			funcStartLine = lineNum;
			funcName = funcMatch[1];
			hasReturn = false;
			braceDepth = 0;
		}

		if (inFunction) {
			// Track braces/ends
			const ends = (line.match(/\bend\b/g) || []).length;
			const funcs = (line.match(/\bfunction\b/g) || []).length;
			braceDepth += funcs - ends;

			if (line.includes("return")) {
				hasReturn = true;
			}

			// Function ended
			if (braceDepth < 0) {
				// loc_vars and calculate MUST return something
				if ((funcName === "loc_vars" || funcName === "calculate") && !hasReturn) {
					bugs.push({
						file,
						line: funcStartLine,
						pattern: "missing-return-in-" + funcName,
						code: `Function '${funcName}' may be missing a return statement`,
						severity: "warning",
					});
				}
				inFunction = false;
			}
		}
	}
}

/**
 * Check for accessing .children without nil check
 */
function checkChildrenAccess(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: something.children.specific_child without checking children exists
		const childrenMatch = line.match(/(\w+)\.children\.(\w+)/);
		if (childrenMatch) {
			const varName = childrenMatch[1];
			const childName = childrenMatch[2];
			const context = lines.slice(Math.max(0, i - 3), i + 1).join("\n");

			// Skip self.children which is usually safe in card methods
			if (varName === "self") continue;

			// Skip if there's a nil check
			if (
				!context.includes(`${varName}.children and`) &&
				!context.includes(`${varName}.children.${childName} and`) &&
				!context.includes(`if ${varName}.children`)
			) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "children-access-no-check",
					code: line.trim(),
					severity: "info",
				});
			}
		}
	}
}

/**
 * Check for rawset/rawget misuse or dangerous global assignments
 */
function checkGlobalAssignments(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: Assigning to G.GAME.* inside a function without checking G.GAME exists
		if (line.match(/G\.GAME\.\w+\s*=/) && !line.includes("G.GAME =")) {
			const context = lines.slice(Math.max(0, i - 10), i + 1).join("\n");

			if (!context.includes("if G.GAME") && !context.includes("G.GAME and")) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "ggame-assignment-no-check",
					code: line.trim(),
					severity: "info",
				});
			}
		}
	}
}

/**
 * Check for potential typos in common function/method names
 * Only check for truly wrong patterns, not case variations that might be intentional
 */
function checkCommonTypos(content: string, file: string): void {
	const lines = content.split("\n");

	// Only check for definite typos, not case variations
	const typoPatterns: Array<{ pattern: RegExp; correct: string }> = [
		{ pattern: /\bsmods\./g, correct: "SMODS." }, // lowercase smods is definitely wrong
		{ pattern: /\bG\.c\.[A-Z]/g, correct: "G.C." }, // G.c.SOMETHING is wrong
	];

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Skip comments
		if (line.trim().startsWith("--")) continue;

		for (const { pattern, correct } of typoPatterns) {
			if (pattern.test(line)) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "definite-typo",
					code: `Typo: should be '${correct}' - ${line.trim().substring(0, 60)}`,
					severity: "error",
				});
			}
		}
	}
}

/**
 * Check for accessing card.base.* without nil check on base
 */
function checkCardBaseAccess(content: string, file: string): void {
	const lines = content.split("\n");

	for (let i = 0; i < lines.length; i++) {
		const line = lines[i];
		const lineNum = i + 1;

		// Pattern: card.base.suit or card.base.value without checking base
		const baseMatch = line.match(/(\w+)\.base\.(suit|value|id|name)/);
		if (baseMatch) {
			const varName = baseMatch[1];
			const prop = baseMatch[2];
			const context = lines.slice(Math.max(0, i - 3), i + 1).join("\n");

			if (
				!context.includes(`${varName}.base and`) &&
				!context.includes(`if ${varName}.base`) &&
				!context.includes(`${varName} and ${varName}.base`)
			) {
				bugs.push({
					file,
					line: lineNum,
					pattern: "card-base-no-check",
					code: line.trim(),
					severity: "info",
				});
			}
		}
	}
}

// Main execution
// Use current working directory so symlinks work from other projects
const rootDir = process.cwd();
const luaFiles = getLuaFiles(rootDir);

console.log(`Scanning ${luaFiles.length} Lua files for potential bugs...\n`);

// Load all content first for cross-file checks
const allContent = new Map<string, string>();
for (const file of luaFiles) {
	const relPath = relative(rootDir, file);
	allContent.set(relPath, readFileSync(file, "utf-8"));
}

// Run all checks
for (const file of luaFiles) {
	const relPath = relative(rootDir, file);
	const content = allContent.get(relPath)!;

	checkColourIndexing(content, relPath);
	checkUndefinedVariables(content, relPath);
	checkArrayBounds(content, relPath);
	checkPlaySoundPercent(content, relPath);
	checkColourInitialization(content, relPath, allContent);
	checkNestedNilAccess(content, relPath);
	checkSharedAccess(content, relPath);
	checkTableRemove(content, relPath);
	checkDivisionByZero(content, relPath);
	checkAbilityExtraAccess(content, relPath);
	checkPCentersAccess(content, relPath);
	checkGameAreaAccess(content, relPath);
	checkArrayAccessInCallbacks(content, relPath);
	checkStringConcatNil(content, relPath);
	checkNilMethodCalls(content, relPath);
	checkMissingReturns(content, relPath);
	checkChildrenAccess(content, relPath);
	checkGlobalAssignments(content, relPath);
	checkCommonTypos(content, relPath);
	checkCardBaseAccess(content, relPath);
}

// Sort bugs by severity
const severityOrder = { error: 0, warning: 1, info: 2 };
bugs.sort((a, b) => {
	const sevDiff = severityOrder[a.severity] - severityOrder[b.severity];
	if (sevDiff !== 0) return sevDiff;
	return a.file.localeCompare(b.file) || a.line - b.line;
});

// Output results
const errorCount = bugs.filter((b) => b.severity === "error").length;
const warningCount = bugs.filter((b) => b.severity === "warning").length;
const infoCount = bugs.filter((b) => b.severity === "info").length;

if (bugs.length === 0) {
	console.log("No potential bugs found!");
} else {
	console.log(`Found ${bugs.length} potential issues (${errorCount} errors, ${warningCount} warnings, ${infoCount} info)\n`);

	for (const bug of bugs) {
		const icon = bug.severity === "error" ? "ERROR" : bug.severity === "warning" ? "WARN " : "INFO ";
		console.log(`[${icon}] ${bug.file}:${bug.line}`);
		console.log(`        Pattern: ${bug.pattern}`);
		console.log(`        ${bug.code}\n`);
	}
}

// Exit with error code if there are errors
process.exit(errorCount > 0 ? 1 : 0);
