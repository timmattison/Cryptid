--- Simple Lua test runner for Cryptid nil-safety tests
--- Provides basic assertions and test organization

local TestRunner = {
	tests = {},
	passed = 0,
	failed = 0,
	errors = {},
}

--- Register a test
--- @param name string Test name
--- @param func function Test function
function TestRunner:test(name, func)
	table.insert(self.tests, { name = name, func = func })
end

--- Assert that a condition is true
--- @param condition boolean The condition to check
--- @param message string Optional message on failure
function TestRunner:assert(condition, message)
	if not condition then
		error(message or "Assertion failed")
	end
end

--- Assert two values are equal
--- @param expected any Expected value
--- @param actual any Actual value
--- @param message string Optional message on failure
function TestRunner:assertEqual(expected, actual, message)
	if expected ~= actual then
		local msg = message or ""
		error(string.format("%s\nExpected: %s\nActual: %s", msg, tostring(expected), tostring(actual)))
	end
end

--- Assert that a value is not nil
--- @param value any Value to check
--- @param message string Optional message on failure
function TestRunner:assertNotNil(value, message)
	if value == nil then
		error(message or "Expected value to not be nil")
	end
end

--- Assert that a value is nil
--- @param value any Value to check
--- @param message string Optional message on failure
function TestRunner:assertNil(value, message)
	if value ~= nil then
		error(message or string.format("Expected nil but got: %s", tostring(value)))
	end
end

--- Assert that a function throws an error
--- @param func function Function that should throw
--- @param message string Optional message on failure
function TestRunner:assertThrows(func, message)
	local success = pcall(func)
	if success then
		error(message or "Expected function to throw an error")
	end
end

--- Assert that a function does NOT throw an error
--- @param func function Function that should not throw
--- @param message string Optional message on failure
function TestRunner:assertNoThrow(func, message)
	local success, err = pcall(func)
	if not success then
		error((message or "Expected function to not throw") .. "\nError: " .. tostring(err))
	end
end

--- Assert that a table contains a key
--- @param tbl table Table to check
--- @param key any Key to look for
--- @param message string Optional message on failure
function TestRunner:assertHasKey(tbl, key, message)
	if tbl[key] == nil then
		error(message or string.format("Expected table to have key: %s", tostring(key)))
	end
end

--- Run all registered tests
function TestRunner:run()
	print("Running " .. #self.tests .. " tests...\n")
	print(string.rep("-", 60))

	for _, test in ipairs(self.tests) do
		io.write(string.format("%-50s ", test.name))
		local success, err = pcall(test.func)
		if success then
			print("[PASS]")
			self.passed = self.passed + 1
		else
			print("[FAIL]")
			self.failed = self.failed + 1
			table.insert(self.errors, { name = test.name, error = err })
		end
	end

	print(string.rep("-", 60))
	print(string.format("\nResults: %d passed, %d failed\n", self.passed, self.failed))

	if #self.errors > 0 then
		print("Failures:")
		print(string.rep("-", 60))
		for _, e in ipairs(self.errors) do
			print("\n" .. e.name .. ":")
			print("  " .. tostring(e.error))
		end
	end

	return self.failed == 0
end

--- Reset the test runner state (for running multiple test files)
function TestRunner:reset()
	self.tests = {}
	self.passed = 0
	self.failed = 0
	self.errors = {}
end

return TestRunner
