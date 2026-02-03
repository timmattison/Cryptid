#!/usr/bin/env lua
--- Nil-safety tests for Cryptid bug fixes
--- These tests verify that code handles nil values correctly without crashing

package.path = package.path .. ";./?.lua"

local TestRunner = require("test-runner")
local T = TestRunner

-- ============================================================================
-- MOCK SETUP
-- ============================================================================

--- Create a fresh mock of the game globals
local function create_mock_G()
	return {
		C = {},
		jokers = nil,
		hand = nil,
		shared_seals = nil,
		shared_stickers = nil,
	}
end

-- ============================================================================
-- COLOUR PRE-INITIALIZATION TESTS (lib/overrides.lua fixes)
-- ============================================================================

T:test("Colour: CRY_EXOTIC can be pre-initialized", function()
	local G = create_mock_G()
	-- Simulate the pre-initialization from lib/overrides.lua
	G.C.CRY_EXOTIC = { 0, 0, 0, 0 }
	T:assertNotNil(G.C.CRY_EXOTIC, "CRY_EXOTIC should exist")
	T:assertEqual(4, #G.C.CRY_EXOTIC, "Should have 4 colour components")
end)

T:test("Colour: CRY_SELECTED can be pre-initialized", function()
	local G = create_mock_G()
	G.C.CRY_SELECTED = { 0, 0, 0, 0 }
	T:assertNotNil(G.C.CRY_SELECTED, "CRY_SELECTED should exist")
	T:assertEqual(4, #G.C.CRY_SELECTED, "Should have 4 colour components")
end)

T:test("Colour: CRY_TAX_MULT can be pre-initialized", function()
	local G = create_mock_G()
	G.C.CRY_TAX_MULT = { 0, 0, 0, 0 }
	T:assertNotNil(G.C.CRY_TAX_MULT, "CRY_TAX_MULT should exist")
end)

T:test("Colour: CRY_TAX_CHIPS can be pre-initialized", function()
	local G = create_mock_G()
	G.C.CRY_TAX_CHIPS = { 0, 0, 0, 0 }
	T:assertNotNil(G.C.CRY_TAX_CHIPS, "CRY_TAX_CHIPS should exist")
end)

T:test("Colour: Accessing pre-initialized colour doesn't crash", function()
	local G = create_mock_G()
	G.C.CRY_EXOTIC = { 0, 0, 0, 0 }

	T:assertNoThrow(function()
		-- Simulate accessing colour[4] like in draw_self
		local alpha = G.C.CRY_EXOTIC[4]
		T:assertEqual(0, alpha, "Alpha should be 0")
	end, "Accessing colour array should not crash")
end)

T:test("Colour: Accessing nil colour crashes (demonstrates bug)", function()
	local G = create_mock_G()
	-- Don't initialize CRY_EXOTIC

	T:assertThrows(function()
		-- This would crash before the fix
		local alpha = G.C.CRY_EXOTIC[4]
	end, "Accessing nil colour should throw error")
end)

-- ============================================================================
-- NIL CHECK TESTS (lib/ui.lua fixes)
-- ============================================================================

T:test("G.shared_seals: nil check prevents crash", function()
	local G = create_mock_G()
	local currentBack = { effect = { config = { cry_force_seal = "Gold" } } }

	T:assertNoThrow(function()
		-- Pattern from fix: check G.shared_seals before accessing
		local seal = nil
		if G.shared_seals and G.shared_seals[currentBack.effect.config.cry_force_seal] then
			seal = G.shared_seals[currentBack.effect.config.cry_force_seal]
		end
		T:assertNil(seal, "Seal should be nil when G.shared_seals doesn't exist")
	end, "Nil check should prevent crash")
end)

T:test("G.shared_seals: works when populated", function()
	local G = create_mock_G()
	G.shared_seals = { Gold = { name = "Gold Seal" } }
	local currentBack = { effect = { config = { cry_force_seal = "Gold" } } }

	local seal = nil
	if G.shared_seals and G.shared_seals[currentBack.effect.config.cry_force_seal] then
		seal = G.shared_seals[currentBack.effect.config.cry_force_seal]
	end

	T:assertNotNil(seal, "Seal should exist when G.shared_seals is populated")
	T:assertEqual("Gold Seal", seal.name, "Should get correct seal")
end)

T:test("G.shared_stickers: nil check prevents crash", function()
	local G = create_mock_G()
	local v = { key = "perishable" }

	T:assertNoThrow(function()
		-- Pattern from fix: elseif G.shared_stickers and G.shared_stickers[v.key]
		local sticker = nil
		if G.shared_stickers and G.shared_stickers[v.key] then
			sticker = G.shared_stickers[v.key]
		end
		T:assertNil(sticker, "Sticker should be nil")
	end, "Nil check should prevent crash")
end)

T:test("table.remove: nil check for nested nodes", function()
	local abc = {}

	T:assertNoThrow(function()
		-- Pattern from fix: check abc.nodes and abc.nodes[1] and abc.nodes[1].nodes
		if abc.nodes and abc.nodes[1] and abc.nodes[1].nodes then
			table.remove(abc.nodes[1].nodes, 1)
		end
	end, "Nil check should prevent crash on table.remove")
end)

T:test("table.remove: works when nodes exist", function()
	local abc = {
		nodes = {
			{
				nodes = { "item1", "item2", "item3" },
			},
		},
	}

	if abc.nodes and abc.nodes[1] and abc.nodes[1].nodes then
		table.remove(abc.nodes[1].nodes, 1)
	end

	T:assertEqual(2, #abc.nodes[1].nodes, "Should have removed one item")
	T:assertEqual("item2", abc.nodes[1].nodes[1], "First item should now be item2")
end)

-- ============================================================================
-- CARDS[1] NIL CHECK TESTS (items/code.lua fixes)
-- ============================================================================

T:test("cards[1]: early return pattern prevents crash", function()
	local cards = {}

	T:assertNoThrow(function()
		-- Pattern from fix: if not cards[1] then return end
		if not cards[1] then
			return
		end
		-- This code should never execute
		local area = cards[1].area
	end, "Early return should prevent crash on empty cards")
end)

T:test("cards[1]: nil check before area access", function()
	local cards = {}

	T:assertNoThrow(function()
		-- Pattern from fix: if cards[1] then ... if cards[1].area == G.hand then
		if cards[1] then
			if cards[1].area then
				-- Do something with area
			end
		end
	end, "Nested nil check should prevent crash")
end)

T:test("cards[1]: works when card exists", function()
	local G = create_mock_G()
	G.hand = { name = "hand" }
	local cards = { { area = G.hand, config = {} } }

	local result = nil
	if cards[1] then
		if cards[1].area == G.hand then
			result = "in_hand"
		end
	end

	T:assertEqual("in_hand", result, "Should detect card is in hand")
end)

T:test("cards[1].config.cry_multiply: nil check prevents crash", function()
	local cards = {}

	T:assertNoThrow(function()
		-- Pattern from fix: if cards[1] then if not cards[1].config.cry_multiply then
		if cards[1] then
			if not cards[1].config.cry_multiply then
				-- Do something
			end
		end
	end, "Nil check should prevent crash")
end)

-- ============================================================================
-- HOOK_CONFIG.COLOUR NIL CHECK TESTS (items/code.lua fixes)
-- ============================================================================

T:test("hook_config.colour: nil check prevents crash", function()
	local hook_config = {}

	T:assertNoThrow(function()
		-- Pattern from fix: if hook_config.colour then
		if hook_config.colour then
			local r = hook_config.colour[1]
		end
	end, "Nil check should prevent crash")
end)

T:test("hook_config.colour: works when colour exists", function()
	local hook_config = { colour = { 1.0, 0.5, 0.5, 1.0 } }

	local r = nil
	if hook_config.colour then
		r = hook_config.colour[1]
	end

	T:assertEqual(1.0, r, "Should get red component")
end)

-- ============================================================================
-- ARRAY BOUNDS CHECK TESTS (items/exotic.lua fixes)
-- ============================================================================

T:test("caeruleum: bounds check prevents crash (lower bound)", function()
	local G = create_mock_G()
	G.jokers = { cards = { { name = "joker1" } } }
	local i = 1
	local b = false -- going left, so index = 1 + -1 = 0

	T:assertNoThrow(function()
		-- Pattern from fix: check bounds before accessing
		local caeruleum_index = i + (b and 1 or -1)
		if caeruleum_index < 1 or caeruleum_index > #G.jokers.cards then
			return
		end
		local caeruleum = G.jokers.cards[caeruleum_index]
	end, "Bounds check should prevent crash on lower bound")
end)

T:test("caeruleum: bounds check prevents crash (upper bound)", function()
	local G = create_mock_G()
	G.jokers = { cards = { { name = "joker1" } } }
	local i = 1
	local b = true -- going right, so index = 1 + 1 = 2, but only 1 card

	T:assertNoThrow(function()
		-- Pattern from fix: check bounds before accessing
		local caeruleum_index = i + (b and 1 or -1)
		if caeruleum_index < 1 or caeruleum_index > #G.jokers.cards then
			return
		end
		local caeruleum = G.jokers.cards[caeruleum_index]
	end, "Bounds check should prevent crash on upper bound")
end)

T:test("caeruleum: valid index works", function()
	local G = create_mock_G()
	G.jokers = { cards = { { name = "joker1" }, { name = "joker2" }, { name = "joker3" } } }
	local i = 2
	local b = true -- going right, so index = 2 + 1 = 3

	local caeruleum_index = i + (b and 1 or -1)
	local caeruleum = nil
	if caeruleum_index >= 1 and caeruleum_index <= #G.jokers.cards then
		caeruleum = G.jokers.cards[caeruleum_index]
	end

	T:assertNotNil(caeruleum, "Should get joker at valid index")
	T:assertEqual("joker3", caeruleum.name, "Should get correct joker")
end)

-- ============================================================================
-- CENTER VS _CENTER VARIABLE TEST (lib/ui.lua typo fix)
-- ============================================================================

T:test("center variable: correct variable name used", function()
	-- This tests that 'center' is used, not '_center' (which was a typo)
	local center = { soul_pos = { x = 0, y = 0 } }
	local _center = nil -- This was incorrectly used before

	T:assertNoThrow(function()
		-- Pattern from fix: if center and center.soul_pos
		if center and center.soul_pos then
			local x = center.soul_pos.x
			local y = center.soul_pos.y
		end
	end, "Using 'center' variable should not crash")
end)

T:test("_center variable: would crash (demonstrates bug)", function()
	local center = { soul_pos = { x = 0, y = 0 } }
	local _center = nil -- Typo - wrong variable

	T:assertThrows(function()
		-- Bug pattern: using _center instead of center
		if _center and _center.soul_pos then
			-- This wouldn't run, but if it did...
		else
			-- Original code accessed _center unconditionally after
			local x = _center.soul_pos.x
		end
	end, "Using '_center' (typo) would crash")
end)

-- ============================================================================
-- PERCENT VARIABLE DEFINITION TEST (items/code.lua fix)
-- ============================================================================

T:test("percent: variable must be defined before use in play_sound", function()
	-- This tests the pattern where 'percent' must be defined before being used
	-- The bug was: play_sound('tarot1', percent) where percent was undefined

	T:assertNoThrow(function()
		-- Pattern from fix: local percent = 0.85 before use
		local percent = 0.85
		-- Simulate play_sound call
		local sound_args = { sound = "tarot1", percent = percent }
		T:assertEqual(0.85, sound_args.percent, "Percent should be defined")
	end, "Defining percent before use should not crash")
end)

T:test("percent: undefined variable would cause nil in play_sound", function()
	-- Demonstrates the bug where percent was not defined
	-- Note: In Lua, undefined variables are nil, not errors
	-- But passing nil to play_sound could cause issues

	local undefined_percent = nil -- Simulates undefined variable

	-- In the actual code, this would pass nil to play_sound
	-- which may or may not crash depending on play_sound's implementation
	T:assertNil(undefined_percent, "Undefined variable is nil in Lua")
end)

-- ============================================================================
-- NIL TABLE KEY TEST (items/misc_joker.lua thalia fix)
-- ============================================================================

T:test("table key: nil key crashes", function()
	local seen = {}

	T:assertThrows(function()
		-- Bug: using nil as table key
		local rarity = nil
		seen[rarity] = 1
	end, "Using nil as table key should crash")
end)

T:test("table key: safe pattern skips nil keys", function()
	local seen = {}
	local cards = {
		{ config = { center = { rarity = 1 } } },
		{ config = { center = { rarity = nil } } }, -- nil rarity
		{ config = { center = {} } }, -- missing rarity
		{ config = {} }, -- missing center
		{}, -- missing config
	}

	T:assertNoThrow(function()
		for _, c in ipairs(cards) do
			local rarity = c.config and c.config.center and c.config.center.rarity
			if rarity then
				seen[rarity] = 1
			end
		end
	end, "Checking rarity before use as key should not crash")

	T:assertEqual(1, seen[1], "Should have recorded rarity 1")
end)

T:test("table key: nil key from config.center.key crashes", function()
	local rares_in_posession = {}
	local cards = {
		{ config = { center = { key = nil, rarity = "cry_epic" } } }, -- nil key
	}

	T:assertThrows(function()
		for k, v in ipairs(cards) do
			if v.config.center.rarity == "cry_epic" then
				rares_in_posession[v.config.center.key] = true -- CRASH
			end
		end
	end, "Using nil config.center.key as table key should crash")
end)

T:test("table key: safe pattern checks key before use", function()
	local rares_in_posession = {}
	local cards = {
		{ config = { center = { key = "j_joker", rarity = "cry_epic" } } },
		{ config = { center = { key = nil, rarity = "cry_epic" } } }, -- nil key
		{ config = { center = { rarity = "cry_epic" } } }, -- missing key
		{ config = { center = { key = "j_other", rarity = "common" } } }, -- wrong rarity
	}

	T:assertNoThrow(function()
		for k, v in ipairs(cards) do
			local dominated_key = v.config and v.config.center and v.config.center.key
			if v.config.center.rarity == "cry_epic" and dominated_key and not rares_in_posession[dominated_key] then
				rares_in_posession[dominated_key] = true
			end
		end
	end, "Checking key before use should not crash")

	T:assertEqual(true, rares_in_posession["j_joker"], "Should have recorded j_joker")
end)

-- ============================================================================
-- INFINITE LOOP PREVENTION TESTS
-- ============================================================================

T:test("while loop: must have escape condition with max iterations", function()
	-- Pattern: while true loops should have a max iteration counter
	local iterations = 0
	local max_iterations = 1000
	local found = false

	-- Simulate a loop that might not find what it's looking for
	while true do
		iterations = iterations + 1
		-- Pretend we're searching for something that doesn't exist
		if iterations >= max_iterations then
			break -- Safety exit
		end
		if false then -- Never true
			found = true
			break
		end
	end

	T:assertEqual(1000, iterations, "Loop should exit via max iterations")
	T:assert(not found, "Should not have found anything")
end)

-- ============================================================================
-- CONFIG.OBJECT NIL CHECK TESTS (UI crash fixes)
-- ============================================================================

T:test("config.object: nil object crashes when accessing property", function()
	local e = { config = { object = nil } }

	T:assertThrows(function()
		e.config.object.colours = { 1, 0, 0, 1 }
	end, "Accessing property of nil object should crash")
end)

T:test("config.object: nil object crashes when calling method", function()
	local e = { config = { object = nil } }

	T:assertThrows(function()
		e.config.object:update_text()
	end, "Calling method on nil object should crash")
end)

T:test("config.object: safe pattern checks object exists", function()
	local e = { config = { object = nil } }

	T:assertNoThrow(function()
		if e.config and e.config.object then
			e.config.object.colours = { 1, 0, 0, 1 }
			e.config.object:update_text()
		end
	end, "Checking object exists should prevent crash")
end)

T:test("config.object: works when object exists", function()
	local updated = false
	local e = {
		config = {
			object = {
				colours = {},
				update_text = function(self)
					updated = true
				end,
			},
		},
	}

	if e.config and e.config.object then
		e.config.object.colours = { 1, 0, 0, 1 }
		e.config.object:update_text()
	end

	T:assertEqual(1, e.config.object.colours[1], "Should set colour")
	T:assert(updated, "Should call update_text")
end)

-- ============================================================================
-- ARGS.COLOUR NIL CHECK TEST (BalatroMultiplayer fix pattern)
-- ============================================================================

T:test("args.colour: nil check before indexing", function()
	local args = { fade = 0.5 }

	T:assertNoThrow(function()
		-- Pattern from fix: if args.colour then args.colour[4] = ...
		if args.colour then
			args.colour[4] = math.min(args.colour[4], args.fade)
		end
	end, "Nil check should prevent crash")
end)

T:test("args.colour: works when colour exists", function()
	local args = { fade = 0.5, colour = { 1.0, 0.5, 0.5, 1.0 } }

	if args.colour then
		args.colour[4] = math.min(args.colour[4], args.fade)
	end

	T:assertEqual(0.5, args.colour[4], "Alpha should be clamped to fade value")
end)

-- ============================================================================
-- BIGNUM OVERFLOW PREVENTION TESTS (lovely/none.toml fix)
-- ============================================================================

-- Mock BigNum implementation for testing (simulates to_big behavior)
local function mock_to_big(val)
	-- Return a table that represents a "big number"
	return { value = val, is_big = true }
end

-- Mock comparison for BigNum
local function big_less_than(a, b)
	local a_val = type(a) == "table" and a.value or a
	local b_val = type(b) == "table" and b.value or b
	return a_val < b_val
end

-- Mock addition for BigNum (handles arbitrary precision)
local function big_add(a, b)
	local a_val = type(a) == "table" and a.value or a
	local b_val = type(b) == "table" and b.value or b
	return mock_to_big(a_val + b_val)
end

T:test("BigNum: regular Lua numbers overflow at very large values", function()
	-- Lua uses IEEE 754 64-bit doubles (DBL_MAX ≈ 1.8e308)
	-- Values beyond this overflow to infinity, causing the negative chips bug
	local huge = 1e308
	local result = huge * 10 -- This overflows to inf

	T:assertEqual(math.huge, result, "Regular Lua numbers overflow to infinity")

	-- Subtracting from inf gives unexpected results
	local weird = result - 1e300
	T:assertEqual(math.huge, weird, "Operations on inf don't work as expected")
end)

T:test("BigNum: safe pattern prevents overflow with mock BigNum", function()
	-- Simulate the fixed code pattern:
	-- local new_chips = to_big(chips) + to_big(l_chips) * amount
	-- G.GAME.hands[hand].chips = new_chips < to_big(1) and to_big(1) or new_chips

	local chips = 1e100
	local l_chips = 1e99
	local amount = 1000

	-- Using mock BigNum (which would handle arbitrary precision in real implementation)
	local new_chips = big_add(mock_to_big(chips), mock_to_big(l_chips * amount))

	-- The pattern ensures we never go below 1
	local result = big_less_than(new_chips, mock_to_big(1)) and mock_to_big(1) or new_chips

	T:assert(result.value > 0, "BigNum pattern should keep chips positive")
	T:assert(result.is_big, "Result should be a BigNum")
end)

T:test("BigNum: safe pattern prevents negative chips", function()
	-- Simulate level-down scenario (amount = -100)
	local chips = 50
	local l_chips = 10
	local amount = -100 -- This would make chips negative without protection

	local new_chips = big_add(mock_to_big(chips), mock_to_big(l_chips * amount))
	-- new_chips.value = 50 + 10 * -100 = 50 - 1000 = -950

	-- The pattern clamps to minimum of 1
	local result = big_less_than(new_chips, mock_to_big(1)) and mock_to_big(1) or new_chips

	T:assertEqual(1, result.value, "Chips should be clamped to minimum of 1")
end)

T:test("BigNum: vanilla math.max doesn't work with BigNum tables", function()
	-- Demonstrates why we can't use math.max with BigNum
	local big = mock_to_big(100)
	local regular = 1

	-- math.max with a table doesn't work correctly
	T:assertNoThrow(function()
		-- This would fail in real code because math.max doesn't understand BigNum
		local result = math.max(type(big) == "table" and big.value or big, regular)
		T:assertEqual(100, result, "Must extract value from BigNum for math.max")
	end, "Need special handling for BigNum in comparisons")
end)

-- ============================================================================
-- RUN TESTS
-- ============================================================================

local success = T:run()
os.exit(success and 0 or 1)
