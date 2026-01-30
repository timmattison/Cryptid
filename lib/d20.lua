-- d20.lua - APIs for D20 content

-- Currently this is very empty since D20 hasn't been fully implemented yet, but it should have a lot more later.

--Will be moved to D20 file when that gets added
function Cryptid.roll(seed, min, max, config)
	local val
	local max_tries = 1000
	local tries = 0
	while not val or (config and config.ignore_value == val) do
		tries = tries + 1
		if tries > max_tries then
			-- Safety exit: return any valid value
			return min
		end
		-- Vary the seed each iteration to avoid deterministic loops
		val = pseudorandom(seed .. "_try" .. tries, min, max)
	end
	return val
end
