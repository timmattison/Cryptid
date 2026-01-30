--- Controller shoulder button support for Cryptid
--- Adds gamepad shoulder button functionality for controller-only play.
---
--- Features:
--- - Left Shoulder (L1/LB): Select/toggle highlight on focused card
--- - Right Shoulder (R1/RB): Flip double-sided cards
--- - Both Shoulders Together: Select all cards in hand
---
--- Design Notes:
--- - Single-shoulder actions are debounced (50ms) to allow time for both-shoulder detection
--- - Button release events are always processed regardless of game state to keep internal
---   state synchronized (prevents stuck button states if paused while holding)
--- - The spelling "consumeables" matches the game's variable naming (G.consumeables)

--- Debounce delay in seconds for single-shoulder actions.
--- This gives time to detect both-shoulder presses before firing single actions.
local SHOULDER_DEBOUNCE_DELAY = 0.05

--- Track shoulder button states for "both pressed" detection
local shoulder_state = {
	left_pressed = false,
	right_pressed = false,
	both_action_fired = false,
	pending_action = nil, -- Tracks pending single-shoulder action for debounce
}

--- Check if the controller shoulders feature is enabled in config.
--- @return boolean True if feature is enabled (default true if not set)
local function is_feature_enabled()
	-- Default to enabled if config doesn't exist or value not set
	if not Cryptid_config then
		return true
	end
	-- Explicit false check (nil or true means enabled)
	return Cryptid_config.controller_shoulders ~= false
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

--- Cancel any pending single-shoulder action.
local function cancel_pending_action()
	shoulder_state.pending_action = nil
end

--- Schedule a single-shoulder action with debounce delay.
--- The action will be cancelled if both shoulders are pressed before it fires.
--- @param button string The button that was pressed
local function schedule_single_action(button)
	-- Cancel any existing pending action
	cancel_pending_action()

	-- Mark that we have a pending action
	shoulder_state.pending_action = button

	-- Use game's event manager for delayed execution
	if G.E_MANAGER then
		G.E_MANAGER:add_event(Event({
			trigger = "after",
			delay = SHOULDER_DEBOUNCE_DELAY,
			func = function()
				-- Check if this action is still pending (not cancelled by both-press)
				if shoulder_state.pending_action ~= button then
					return true
				end

				-- Check if both buttons are now pressed (cancel single action)
				if shoulder_state.left_pressed and shoulder_state.right_pressed then
					shoulder_state.pending_action = nil
					return true
				end

				-- Check if the button is still held
				if button == "leftshoulder" and shoulder_state.left_pressed then
					Cryptid.shoulder_select_focused()
				elseif button == "rightshoulder" and shoulder_state.right_pressed then
					Cryptid.shoulder_flip_card()
				end

				shoulder_state.pending_action = nil
				return true
			end,
		}))
	else
		-- Fallback: execute immediately if event manager not available
		if button == "leftshoulder" then
			Cryptid.shoulder_select_focused()
		elseif button == "rightshoulder" then
			Cryptid.shoulder_flip_card()
		end
	end
end

--- Handle shoulder button input for gamepad controls.
--- Processes left/right shoulder button presses for card selection and flipping.
--- @param button string The LÖVE gamepad button name ("leftshoulder" or "rightshoulder")
--- @param pressed boolean True if button was pressed, false if released
function Cryptid.handle_shoulder_button(button, pressed)
	-- Only process if the feature is enabled
	if not is_feature_enabled() then
		return
	end

	-- Update button state
	if button == "leftshoulder" then
		shoulder_state.left_pressed = pressed
	elseif button == "rightshoulder" then
		shoulder_state.right_pressed = pressed
	else
		return
	end

	-- On release: reset state flags
	if not pressed then
		shoulder_state.both_action_fired = false
		-- Don't cancel pending action on release - let it complete if scheduled
		return
	end

	-- Check for both shoulders pressed (select all hand cards)
	if shoulder_state.left_pressed and shoulder_state.right_pressed then
		-- Cancel any pending single-shoulder action
		cancel_pending_action()

		if not shoulder_state.both_action_fired then
			shoulder_state.both_action_fired = true
			Cryptid.select_all_hand_cards()
		end
		return
	end

	-- Schedule single shoulder action with debounce
	schedule_single_action(button)
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
function Cryptid.shoulder_select_focused()
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

	-- Support selecting hand cards with L1
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
function Cryptid.shoulder_flip_card()
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

--- Check if controller shoulder button feature should be active.
--- Returns false if we're in menus, paused, or overlay is shown.
--- @return boolean True if shoulder button handling should be active
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

--- Reset shoulder button state.
--- Call this when the game state changes unexpectedly to prevent stuck states.
function Cryptid.reset_shoulder_state()
	shoulder_state.left_pressed = false
	shoulder_state.right_pressed = false
	shoulder_state.both_action_fired = false
	shoulder_state.pending_action = nil
end

-- Hook into LÖVE's gamepad event handlers
local original_gamepadpressed = love.handlers.gamepadpressed
love.handlers.gamepadpressed = function(joystick, button)
	-- Call original handler first
	if original_gamepadpressed then
		original_gamepadpressed(joystick, button)
	end

	-- Handle shoulder buttons during gameplay
	if should_handle_controller_input() then
		Cryptid.handle_shoulder_button(button, true)
	end
end

local original_gamepadreleased = love.handlers.gamepadreleased
love.handlers.gamepadreleased = function(joystick, button)
	-- Call original handler first
	if original_gamepadreleased then
		original_gamepadreleased(joystick, button)
	end

	-- Always process shoulder button releases to keep internal state synchronized.
	-- This prevents stuck button states if the game is paused/menu opened while holding.
	-- We only filter to shoulder buttons to avoid unnecessary processing.
	if button == "leftshoulder" or button == "rightshoulder" then
		Cryptid.handle_shoulder_button(button, false)
	end
end
