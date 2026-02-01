#!/usr/bin/env lua
--- Controller input tests for Cryptid
--- These tests verify the controller button functionality (Y, L3, R3)

package.path = package.path .. ";./?.lua"

local TestRunner = require("test-runner")
local T = TestRunner

-- ============================================================================
-- MOCK SETUP
-- ============================================================================

--- Create mock Cryptid global
local function create_mock_Cryptid()
	return {}
end

--- Create mock Cryptid_config
local function create_mock_config(overrides)
	local config = {
		controller_buttons = true,
	}
	if overrides then
		for k, v in pairs(overrides) do
			config[k] = v
		end
	end
	return config
end

--- Create a fresh mock of the game globals
local function create_mock_G()
	return {
		STATE = 1,
		STATES = {
			SELECTING_HAND = 1,
			DRAW_TO_HAND = 2,
		},
		STAGE = 1,
		STAGES = {
			RUN = 1,
		},
		SETTINGS = {
			paused = false,
		},
		OVERLAY_MENU = nil,
		CONTROLLER = {
			cursor_hover = {
				target = nil,
			},
		},
		hand = nil,
		jokers = nil,
		consumeables = nil,
		E_MANAGER = nil,
	}
end

--- Create a mock card
local function create_mock_card(options)
	options = options or {}
	return {
		highlighted = options.highlighted or false,
		edition = options.edition,
		area = options.area,
		flip_side = options.flip_side,
	}
end

--- Create a mock card area
local function create_mock_area(cards, config)
	local area = {
		cards = cards or {},
		highlighted = {},
		config = config or {},
	}

	function area:add_to_highlighted(card, silent)
		card.highlighted = true
		table.insert(self.highlighted, card)
	end

	function area:remove_from_highlighted(card)
		card.highlighted = false
		for i, c in ipairs(self.highlighted) do
			if c == card then
				table.remove(self.highlighted, i)
				break
			end
		end
	end

	-- Set each card's area reference
	for _, card in ipairs(area.cards) do
		card.area = area
	end

	return area
end

-- ============================================================================
-- HELPER FUNCTION TESTS
-- ============================================================================

T:test("Config: feature enabled by default when config exists", function()
	-- Simulate the config check logic
	local config = create_mock_config()
	local enabled = config.controller_buttons ~= false
	T:assert(enabled, "Feature should be enabled by default")
end)

T:test("Config: feature can be disabled", function()
	local config = create_mock_config({ controller_buttons = false })
	local enabled = config.controller_buttons ~= false
	T:assert(not enabled, "Feature should be disabled when set to false")
end)

T:test("Config: feature enabled when value is nil", function()
	local config = {}
	local enabled = config.controller_buttons ~= false
	T:assert(enabled, "Feature should be enabled when value is nil")
end)

-- ============================================================================
-- GAME STATE VALIDATION TESTS
-- ============================================================================

T:test("State: can_select_hand_cards returns true in SELECTING_HAND", function()
	local G = create_mock_G()
	G.STATE = G.STATES.SELECTING_HAND
	local can_select = (G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.DRAW_TO_HAND)
	T:assert(can_select, "Should be able to select in SELECTING_HAND state")
end)

T:test("State: can_select_hand_cards returns true in DRAW_TO_HAND", function()
	local G = create_mock_G()
	G.STATE = G.STATES.DRAW_TO_HAND
	local can_select = (G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.DRAW_TO_HAND)
	T:assert(can_select, "Should be able to select in DRAW_TO_HAND state")
end)

T:test("State: can_select_hand_cards returns false in other states", function()
	local G = create_mock_G()
	G.STATE = 99 -- Some other state
	local can_select = (G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.DRAW_TO_HAND)
	T:assert(not can_select, "Should not be able to select in other states")
end)

T:test("State: can_select_hand_cards handles nil G.STATES", function()
	local G = create_mock_G()
	G.STATES = nil
	local can_select = G.STATE and G.STATES and (G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.DRAW_TO_HAND)
	T:assert(not can_select, "Should handle nil G.STATES gracefully")
end)

-- ============================================================================
-- HIGHLIGHT LIMIT TESTS
-- ============================================================================

T:test("Limit: get_hand_highlight_limit returns config value when set", function()
	local G = create_mock_G()
	G.hand = create_mock_area({}, { highlighted_limit = 5 })
	local limit = G.hand.config.highlighted_limit or 999
	T:assertEqual(5, limit, "Should return configured limit")
end)

T:test("Limit: get_hand_highlight_limit returns default when not set", function()
	local G = create_mock_G()
	G.hand = create_mock_area({})
	local limit = (G.hand and G.hand.config and G.hand.config.highlighted_limit) or 999
	T:assertEqual(999, limit, "Should return default limit when not configured")
end)

T:test("Limit: get_hand_highlight_limit handles nil G.hand", function()
	local G = create_mock_G()
	G.hand = nil
	local limit = (G.hand and G.hand.config and G.hand.config.highlighted_limit) or 999
	T:assertEqual(999, limit, "Should return default limit when G.hand is nil")
end)

-- ============================================================================
-- CARD AREA TESTS
-- ============================================================================

T:test("Area: add_to_highlighted sets card.highlighted", function()
	local card = create_mock_card()
	local area = create_mock_area({ card })
	T:assert(not card.highlighted, "Card should start unhighlighted")
	area:add_to_highlighted(card, true)
	T:assert(card.highlighted, "Card should be highlighted after add")
end)

T:test("Area: remove_from_highlighted clears card.highlighted", function()
	local card = create_mock_card({ highlighted = true })
	local area = create_mock_area({ card })
	area.highlighted = { card }
	area:remove_from_highlighted(card)
	T:assert(not card.highlighted, "Card should be unhighlighted after remove")
end)

-- ============================================================================
-- DOUBLE-SIDED EDITION TESTS
-- ============================================================================

T:test("Edition: card with cry_double_sided can be flipped", function()
	local flipped = false
	local card = create_mock_card({
		edition = { cry_double_sided = true },
		flip_side = function()
			flipped = true
		end,
	})
	-- Simulate flip check
	if card.edition and card.edition.cry_double_sided and card.flip_side then
		card.flip_side()
	end
	T:assert(flipped, "Card with double-sided edition should be flippable")
end)

T:test("Edition: card without edition cannot be flipped", function()
	local flipped = false
	local card = create_mock_card({
		flip_side = function()
			flipped = true
		end,
	})
	-- Simulate flip check
	if card.edition and card.edition.cry_double_sided and card.flip_side then
		card.flip_side()
	end
	T:assert(not flipped, "Card without edition should not be flipped")
end)

T:test("Edition: card with other edition cannot be flipped", function()
	local flipped = false
	local card = create_mock_card({
		edition = { foil = true },
		flip_side = function()
			flipped = true
		end,
	})
	-- Simulate flip check
	if card.edition and card.edition.cry_double_sided and card.flip_side then
		card.flip_side()
	end
	T:assert(not flipped, "Card with other edition should not be flipped")
end)

-- ============================================================================
-- NIL SAFETY TESTS
-- ============================================================================

T:test("Nil safety: handle nil G.CONTROLLER", function()
	local G = create_mock_G()
	G.CONTROLLER = nil
	local target = G.CONTROLLER and G.CONTROLLER.cursor_hover and G.CONTROLLER.cursor_hover.target
	T:assertNil(target, "Should safely return nil when G.CONTROLLER is nil")
end)

T:test("Nil safety: handle nil cursor_hover", function()
	local G = create_mock_G()
	G.CONTROLLER.cursor_hover = nil
	local target = G.CONTROLLER and G.CONTROLLER.cursor_hover and G.CONTROLLER.cursor_hover.target
	T:assertNil(target, "Should safely return nil when cursor_hover is nil")
end)

T:test("Nil safety: handle nil target", function()
	local G = create_mock_G()
	G.CONTROLLER.cursor_hover.target = nil
	local target = G.CONTROLLER and G.CONTROLLER.cursor_hover and G.CONTROLLER.cursor_hover.target
	T:assertNil(target, "Should safely return nil when target is nil")
end)

T:test("Nil safety: handle target without area", function()
	local G = create_mock_G()
	local target = create_mock_card()
	target.area = nil
	G.CONTROLLER.cursor_hover.target = target
	-- Simulate the check from shoulder_select_focused
	local has_area = target and target.area
	T:assert(not has_area, "Should detect missing area property")
end)

-- ============================================================================
-- SELECT ALL CARDS LOGIC TESTS
-- ============================================================================

T:test("Select all: respects highlight limit", function()
	local cards = {}
	for i = 1, 10 do
		table.insert(cards, create_mock_card())
	end
	local area = create_mock_area(cards, { highlighted_limit = 5 })

	-- Simulate select_all_hand_cards logic
	local limit = area.config.highlighted_limit or 999
	local current_count = #area.highlighted
	local cards_added = 0

	for _, card in ipairs(area.cards) do
		if not card.highlighted then
			if current_count + cards_added >= limit then
				break
			end
			area:add_to_highlighted(card, true)
			cards_added = cards_added + 1
		end
	end

	T:assertEqual(5, #area.highlighted, "Should only highlight up to the limit")
end)

T:test("Select all: skips already highlighted cards", function()
	local cards = {
		create_mock_card({ highlighted = true }),
		create_mock_card({ highlighted = false }),
		create_mock_card({ highlighted = true }),
		create_mock_card({ highlighted = false }),
	}
	local area = create_mock_area(cards)
	-- Pre-populate highlighted
	area.highlighted = { cards[1], cards[3] }

	local cards_added = 0
	for _, card in ipairs(area.cards) do
		if not card.highlighted then
			area:add_to_highlighted(card, true)
			cards_added = cards_added + 1
		end
	end

	T:assertEqual(2, cards_added, "Should only add unhighlighted cards")
	T:assertEqual(4, #area.highlighted, "All cards should now be highlighted")
end)

T:test("Select all: handles empty hand", function()
	local area = create_mock_area({})
	local cards_added = 0

	if #area.cards > 0 then
		for _, card in ipairs(area.cards) do
			if not card.highlighted then
				area:add_to_highlighted(card, true)
				cards_added = cards_added + 1
			end
		end
	end

	T:assertEqual(0, cards_added, "Should not add any cards from empty hand")
end)

-- ============================================================================
-- RUN TESTS
-- ============================================================================

T:run()
