#!/usr/bin/env lua
--- Tests for common Lua patterns that can cause crashes in Balatro mods
--- These tests exercise dangerous patterns to ensure proper nil handling

package.path = package.path .. ";./?.lua"

local TestRunner = require("test-runner")
local T = TestRunner

-- ============================================================================
-- MOCK SETUP
-- ============================================================================

local function create_mock_G()
	return {
		C = {},
		GAME = {},
		jokers = nil,
		hand = nil,
		play = nil,
		deck = nil,
		consumeables = nil,
		discard = nil,
		P = { centers = {} },
	}
end

local function create_mock_card()
	return {
		ability = nil,
		children = nil,
		config = {},
		base = nil,
	}
end

-- ============================================================================
-- CARD.ABILITY.EXTRA ACCESS TESTS (1089 warnings)
-- Most common crash pattern: accessing card.ability.extra without nil check
-- ============================================================================

T:test("card.ability.extra: nil ability crashes", function()
	local card = create_mock_card()

	T:assertThrows(function()
		local value = card.ability.extra
	end, "Accessing ability.extra on nil ability should crash")
end)

T:test("card.ability.extra: nil extra crashes", function()
	local card = create_mock_card()
	card.ability = {} -- ability exists but no extra

	-- In Lua, accessing nil table key returns nil, doesn't crash
	-- But accessing a property OF that nil value would crash
	local extra = card.ability.extra
	T:assertNil(extra, "extra should be nil")

	T:assertThrows(function()
		local value = card.ability.extra.mult
	end, "Accessing property of nil extra should crash")
end)

T:test("card.ability.extra: safe pattern with nested checks", function()
	local card = create_mock_card()

	T:assertNoThrow(function()
		-- Safe pattern: check each level
		local mult = nil
		if card.ability and card.ability.extra and card.ability.extra.mult then
			mult = card.ability.extra.mult
		end
		T:assertNil(mult, "mult should be nil with safe access")
	end, "Nested nil checks should not crash")
end)

T:test("card.ability.extra: safe pattern with single check", function()
	local card = create_mock_card()
	card.ability = { extra = { mult = 4 } }

	local mult = nil
	if card.ability and card.ability.extra then
		mult = card.ability.extra.mult
	end

	T:assertEqual(4, mult, "Should get mult value")
end)

-- ============================================================================
-- G.GAME ACCESS TESTS (250 warnings)
-- ============================================================================

T:test("G.GAME: nil GAME crashes on assignment", function()
	local G = { GAME = nil }

	T:assertThrows(function()
		G.GAME.some_flag = true
	end, "Assigning to nil GAME should crash")
end)

T:test("G.GAME: safe pattern checks GAME exists", function()
	local G = { GAME = nil }

	T:assertNoThrow(function()
		if G.GAME then
			G.GAME.some_flag = true
		end
	end, "Checking GAME before assignment should not crash")
end)

T:test("G.GAME: works when initialized", function()
	local G = { GAME = {} }

	G.GAME.some_flag = true
	T:assertEqual(true, G.GAME.some_flag, "Should set flag")
end)

-- ============================================================================
-- G.JOKERS.CARDS ACCESS TESTS (244 warnings)
-- ============================================================================

T:test("G.jokers.cards: nil jokers crashes", function()
	local G = create_mock_G()

	T:assertThrows(function()
		local count = #G.jokers.cards
	end, "Accessing cards on nil jokers should crash")
end)

T:test("G.jokers.cards: nil cards crashes", function()
	local G = create_mock_G()
	G.jokers = {} -- jokers exists but no cards

	T:assertThrows(function()
		local count = #G.jokers.cards
	end, "Accessing nil cards should crash")
end)

T:test("G.jokers.cards: safe iteration pattern", function()
	local G = create_mock_G()

	T:assertNoThrow(function()
		if G.jokers and G.jokers.cards then
			for i, card in ipairs(G.jokers.cards) do
				-- process card
			end
		end
	end, "Safe iteration should not crash")
end)

T:test("G.jokers.cards: works when populated", function()
	local G = create_mock_G()
	G.jokers = { cards = { { name = "j1" }, { name = "j2" } } }

	local count = 0
	if G.jokers and G.jokers.cards then
		count = #G.jokers.cards
	end

	T:assertEqual(2, count, "Should count 2 jokers")
end)

-- ============================================================================
-- G.HAND.CARDS ACCESS TESTS (62 warnings)
-- ============================================================================

T:test("G.hand.cards: nil hand crashes", function()
	local G = create_mock_G()

	T:assertThrows(function()
		local card = G.hand.cards[1]
	end, "Accessing cards on nil hand should crash")
end)

T:test("G.hand.cards: safe index access", function()
	local G = create_mock_G()
	G.hand = { cards = { { rank = "A" }, { rank = "K" } } }

	local card = nil
	if G.hand and G.hand.cards and G.hand.cards[1] then
		card = G.hand.cards[1]
	end

	T:assertNotNil(card, "Should get first card")
	T:assertEqual("A", card.rank, "First card should be Ace")
end)

-- ============================================================================
-- CHAINED METHOD ON ARRAY ACCESS TESTS (47 warnings)
-- Pattern: G.jokers.cards[i]:method() without checking cards[i] exists
-- ============================================================================

T:test("chained method: nil element crashes", function()
	local G = create_mock_G()
	G.jokers = { cards = {} } -- empty array

	T:assertThrows(function()
		G.jokers.cards[1]:start_dissolve()
	end, "Calling method on nil array element should crash")
end)

T:test("chained method: out of bounds crashes", function()
	local G = create_mock_G()
	G.jokers = {
		cards = {
			{ name = "j1", start_dissolve = function() end },
		},
	}

	T:assertThrows(function()
		G.jokers.cards[2]:start_dissolve() -- only 1 card
	end, "Calling method on out-of-bounds element should crash")
end)

T:test("chained method: safe pattern with existence check", function()
	local G = create_mock_G()
	G.jokers = { cards = {} }
	local idx = 1

	T:assertNoThrow(function()
		if G.jokers and G.jokers.cards and G.jokers.cards[idx] then
			-- Would call G.jokers.cards[idx]:start_dissolve()
			local card = G.jokers.cards[idx]
		end
	end, "Checking element exists before method call should not crash")
end)

T:test("chained method: works with valid index", function()
	local G = create_mock_G()
	local dissolved = false
	G.jokers = {
		cards = {
			{
				name = "j1",
				start_dissolve = function()
					dissolved = true
				end,
			},
		},
	}

	if G.jokers and G.jokers.cards and G.jokers.cards[1] then
		G.jokers.cards[1]:start_dissolve()
	end

	T:assert(dissolved, "Method should have been called")
end)

-- ============================================================================
-- CARD.CHILDREN ACCESS TESTS (54 warnings)
-- ============================================================================

T:test("card.children: nil children crashes", function()
	local card = create_mock_card()

	T:assertThrows(function()
		local center = card.children.center
	end, "Accessing children on nil should crash")
end)

T:test("card.children.center: safe pattern", function()
	local card = create_mock_card()

	T:assertNoThrow(function()
		local center = nil
		if card.children and card.children.center then
			center = card.children.center
		end
	end, "Checking children before access should not crash")
end)

T:test("card.children.center: works when populated", function()
	local card = create_mock_card()
	card.children = { center = { x = 100, y = 200 } }

	local center = nil
	if card.children and card.children.center then
		center = card.children.center
	end

	T:assertNotNil(center, "Should get center")
	T:assertEqual(100, center.x, "Should have x position")
end)

-- ============================================================================
-- CARD.BASE ACCESS TESTS (36 warnings)
-- ============================================================================

T:test("card.base: nil base crashes", function()
	local card = create_mock_card()

	T:assertThrows(function()
		local suit = card.base.suit
	end, "Accessing base on nil should crash")
end)

T:test("card.base: safe pattern", function()
	local card = create_mock_card()

	T:assertNoThrow(function()
		local suit = nil
		if card.base and card.base.suit then
			suit = card.base.suit
		end
	end, "Checking base before access should not crash")
end)

-- ============================================================================
-- P.CENTERS VARIABLE KEY ACCESS TESTS (87 warnings)
-- Pattern: G.P.centers[variable_key] without checking key exists
-- ============================================================================

T:test("P.centers: missing key returns nil", function()
	local G = create_mock_G()
	G.P = { centers = { ["j_joker"] = { name = "Joker" } } }

	local key = "j_nonexistent"
	local center = G.P.centers[key]

	T:assertNil(center, "Missing key should return nil")
end)

T:test("P.centers: accessing property of missing key crashes", function()
	local G = create_mock_G()
	G.P = { centers = {} }

	local key = "j_nonexistent"

	T:assertThrows(function()
		local name = G.P.centers[key].name
	end, "Accessing property of nil center should crash")
end)

T:test("P.centers: safe pattern with existence check", function()
	local G = create_mock_G()
	G.P = { centers = {} }

	local key = "j_nonexistent"

	T:assertNoThrow(function()
		local name = nil
		if G.P.centers[key] then
			name = G.P.centers[key].name
		end
	end, "Checking key exists should not crash")
end)

-- ============================================================================
-- ARRAY OFFSET/BOUNDS TESTS (55 warnings)
-- ============================================================================

T:test("array offset: i+1 can exceed bounds", function()
	local arr = { "a", "b", "c" }
	local i = 3 -- last valid index

	T:assertNoThrow(function()
		-- In Lua, out of bounds returns nil
		local next = arr[i + 1]
		T:assertNil(next, "Out of bounds should be nil")
	end, "Out of bounds access returns nil in Lua")
end)

T:test("array offset: accessing property of nil crashes", function()
	local arr = { { name = "a" }, { name = "b" } }
	local i = 2

	T:assertThrows(function()
		local name = arr[i + 1].name -- arr[3] is nil
	end, "Accessing property of nil element should crash")
end)

T:test("array offset: safe pattern with bounds check", function()
	local arr = { { name = "a" }, { name = "b" } }
	local i = 2

	T:assertNoThrow(function()
		local name = nil
		local next_idx = i + 1
		if next_idx <= #arr and arr[next_idx] then
			name = arr[next_idx].name
		end
	end, "Bounds check should prevent crash")
end)

T:test("array offset: i-1 can go below 1", function()
	local arr = { { name = "a" }, { name = "b" } }
	local i = 1

	T:assertThrows(function()
		local name = arr[i - 1].name -- arr[0] is nil in Lua
	end, "Accessing property of arr[0] should crash")
end)

T:test("array offset: safe lower bound check", function()
	local arr = { { name = "a" }, { name = "b" } }
	local i = 1

	T:assertNoThrow(function()
		local name = nil
		local prev_idx = i - 1
		if prev_idx >= 1 and arr[prev_idx] then
			name = arr[prev_idx].name
		end
	end, "Lower bound check should prevent crash")
end)

-- ============================================================================
-- DEEP PROPERTY ACCESS TESTS (229 warnings)
-- Pattern: a.b.c.d without checking intermediate levels
-- ============================================================================

T:test("deep access: any nil level crashes", function()
	local obj = { a = { b = nil } }

	T:assertThrows(function()
		local value = obj.a.b.c.d
	end, "Deep access through nil should crash")
end)

T:test("deep access: safe pattern checks each level", function()
	local obj = { a = { b = nil } }

	T:assertNoThrow(function()
		local value = nil
		if obj.a and obj.a.b and obj.a.b.c and obj.a.b.c.d then
			value = obj.a.b.c.d
		end
	end, "Checking each level should not crash")
end)

T:test("deep access: works when fully populated", function()
	local obj = { a = { b = { c = { d = "found" } } } }

	local value = nil
	if obj.a and obj.a.b and obj.a.b.c then
		value = obj.a.b.c.d
	end

	T:assertEqual("found", value, "Should get deep value")
end)

-- ============================================================================
-- CALLBACK ARRAY ACCESS TESTS (21 warnings)
-- Pattern: Using array index inside callback where array may have changed
-- ============================================================================

T:test("callback array: index may be stale", function()
	local arr = { "a", "b", "c" }
	local captured_idx = 2

	-- Simulate array modification
	table.remove(arr, 1)

	-- Now captured_idx points to wrong element
	T:assertEqual("c", arr[captured_idx], "Index 2 now points to 'c' not 'b'")
end)

T:test("callback array: safe pattern captures value not index", function()
	local arr = { { name = "a" }, { name = "b" }, { name = "c" } }
	local captured_value = arr[2] -- capture the actual object

	-- Simulate array modification
	table.remove(arr, 1)

	-- captured_value still points to original object
	T:assertEqual("b", captured_value.name, "Captured value is still 'b'")
end)

-- ============================================================================
-- MISSING RETURN IN FUNCTIONS TESTS
-- These test that functions should return values
-- ============================================================================

T:test("calculate function: should return a value", function()
	-- Pattern: calculate functions should return something for the game to use
	local function bad_calculate()
		local result = 42
		-- Missing return!
	end

	local function good_calculate()
		local result = 42
		return result
	end

	T:assertNil(bad_calculate(), "Bad calculate returns nil")
	T:assertEqual(42, good_calculate(), "Good calculate returns value")
end)

T:test("loc_vars function: should return table", function()
	-- Pattern: loc_vars should return a table for localization
	local function bad_loc_vars()
		local vars = { 1, 2, 3 }
		-- Missing return!
	end

	local function good_loc_vars()
		local vars = { 1, 2, 3 }
		return { vars = vars }
	end

	T:assertNil(bad_loc_vars(), "Bad loc_vars returns nil")
	T:assertNotNil(good_loc_vars(), "Good loc_vars returns table")
	T:assertNotNil(good_loc_vars().vars, "Good loc_vars has vars")
end)

-- ============================================================================
-- RUN TESTS
-- ============================================================================

local success = T:run()
os.exit(success and 0 or 1)
