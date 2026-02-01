--- Controller button support for Cryptid
--- Adds gamepad button functionality for controller-only play.
---
--- Features:
--- - Y Button: Select/toggle highlight on focused card
--- - Right Stick Press (R3): Flip double-sided cards
--- - Left Stick Press (L3): Select all cards in hand
---
--- Design Notes:
--- - This file is auto-loaded by Cryptid.lua via NFS.getDirectoryItems("lib/")
---   No explicit require() is needed - all files in lib/ are loaded automatically.
--- - The config key "controller_buttons" must match in: config.lua, Cryptid.lua, and here.
---   See scripts/test-bug-fixes.ts for regression tests that verify this consistency.
--- - The spelling "consumeables" matches the game's variable naming (G.consumeables)

--- Check if the controller buttons feature is enabled in config.
--- @return boolean True if feature is enabled (default true if not set)
local function is_feature_enabled()
	-- Default to enabled if config doesn't exist or value not set
	if not Cryptid_config then
		return true
	end
	-- Explicit false check (nil or true means enabled)
	return Cryptid_config.controller_buttons ~= false
end

--- Check if we're in a valid game state for selecting hand cards.
--- @return boolean True if hand card selection is allowed
local function can_select_hand_cards()
	if not G.STATE or not G.STATES then
		return false
	end
	return G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.DRAW_TO_HAND
end

--- Get the maximum number of cards that can be highlighted in hand.
--- @return number The highlight limit, or a large number if unlimited
local function get_hand_highlight_limit()
	if G.hand and G.hand.config and G.hand.config.highlighted_limit then
		return G.hand.config.highlighted_limit
	end
	-- Default to a large number if no limit is set
	return 999
end

--- Get the current number of highlighted cards in hand.
--- @return number The count of currently highlighted cards
local function get_current_highlight_count()
	if G.hand and G.hand.highlighted then
		return #G.hand.highlighted
	end
	return 0
end

--- Handle controller button input for gamepad controls.
--- Processes Y, L3, and R3 button presses for card selection and flipping.
--- @param button string The LÖVE gamepad button name
function Cryptid.handle_controller_button(button)
	-- Only process if the feature is enabled
	if not is_feature_enabled() then
		return
	end

	if button == "y" then
		Cryptid.controller_select_focused()
	elseif button == "rightstick" then
		Cryptid.controller_flip_card()
	elseif button == "leftstick" then
		Cryptid.select_all_hand_cards()
	end
end

--- Select all cards currently in the player's hand.
--- Only works during the hand selection phase of gameplay.
--- Respects the hand's highlighted_limit configuration.
function Cryptid.select_all_hand_cards()
	-- Validate G.hand exists and has cards
	if not G.hand then
		return
	end
	if not G.hand.cards or #G.hand.cards == 0 then
		return
	end

	-- Check if we're in a state where we can select cards
	if not can_select_hand_cards() then
		return
	end

	local limit = get_hand_highlight_limit()
	local current_count = get_current_highlight_count()
	local cards_added = 0

	-- Select cards up to the limit
	for _, card in ipairs(G.hand.cards) do
		if not card.highlighted then
			-- Check if we've hit the limit
			if current_count + cards_added >= limit then
				break
			end
			G.hand:add_to_highlighted(card, true)
			cards_added = cards_added + 1
		end
	end

	-- Only play sound if we actually selected cards
	if cards_added > 0 then
		play_sound("cardSlide1", 0.5)
	end
end

--- Toggle selection on the currently focused card using controller navigation.
--- Works with jokers, hand cards, and consumables.
function Cryptid.controller_select_focused()
	-- Get the currently focused element from controller
	if not G.CONTROLLER or not G.CONTROLLER.cursor_hover then
		return
	end

	local target = G.CONTROLLER.cursor_hover.target
	if not target then
		return
	end

	-- Ensure target has an area property
	if not target.area then
		return
	end

	-- Check if target is a card in the jokers area
	if G.jokers and target.area == G.jokers then
		-- Toggle highlight on joker
		if target.highlighted then
			G.jokers:remove_from_highlighted(target)
		else
			G.jokers:add_to_highlighted(target, true)
		end
		play_sound("cardSlide1", 0.5)
		return
	end

	-- Support selecting hand cards with Y
	if G.hand and target.area == G.hand then
		if can_select_hand_cards() then
			if target.highlighted then
				-- Deselect if already highlighted
				G.hand:remove_from_highlighted(target)
			else
				-- Check highlight limit before adding
				local limit = get_hand_highlight_limit()
				local current_count = get_current_highlight_count()
				if current_count < limit then
					G.hand:add_to_highlighted(target, true)
				end
			end
			play_sound("cardSlide1", 0.5)
		end
		return
	end

	-- Support consumables too (note: game uses spelling "consumeables")
	if G.consumeables and target.area == G.consumeables then
		if target.highlighted then
			G.consumeables:remove_from_highlighted(target)
		else
			G.consumeables:add_to_highlighted(target, true)
		end
		play_sound("cardSlide1", 0.5)
		return
	end
end

--- Flip a double-sided card if the currently focused card has that edition.
--- Only works on cards with the cry_double_sided edition.
function Cryptid.controller_flip_card()
	-- Get the currently focused element from controller
	if not G.CONTROLLER or not G.CONTROLLER.cursor_hover then
		return
	end

	local target = G.CONTROLLER.cursor_hover.target
	if not target then
		return
	end

	-- Only flip cards with double-sided edition
	if not target.edition then
		return
	end
	if not target.edition.cry_double_sided then
		return
	end

	-- Verify flip_side method exists
	if not target.flip_side then
		return
	end

	target:flip_side()
	play_sound("card1", 1)
	target:juice_up(0.3, 0.3)
end

--- Check if controller button feature should be active.
--- Returns false if we're in menus, paused, or overlay is shown.
--- @return boolean True if controller button handling should be active
local function should_handle_controller_input()
	-- Validate G.STAGE and G.STAGES exist
	if not G.STAGE or not G.STAGES then
		return false
	end

	-- Only active during gameplay
	if G.STAGE ~= G.STAGES.RUN then
		return false
	end

	-- Disabled when paused
	if G.SETTINGS and G.SETTINGS.paused then
		return false
	end

	-- Disabled when overlay menu is shown
	if G.OVERLAY_MENU then
		return false
	end

	return true
end

-- Hook into LÖVE's gamepad event handler
local original_gamepadpressed = love.handlers.gamepadpressed
love.handlers.gamepadpressed = function(joystick, button)
	-- Call original handler first
	if original_gamepadpressed then
		original_gamepadpressed(joystick, button)
	end

	-- Handle controller buttons during gameplay
	if should_handle_controller_input() then
		Cryptid.handle_controller_button(button)
	end
end
