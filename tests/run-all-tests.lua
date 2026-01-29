#!/usr/bin/env lua
--- Run all Cryptid tests and show summary

print("=" .. string.rep("=", 59))
print("CRYPTID TEST SUITE")
print("=" .. string.rep("=", 59))
print("")

local function run_test_file(filename)
	print("Running " .. filename .. "...")
	print("")
	local handle = io.popen("lua " .. filename .. " 2>&1")
	local result = handle:read("*a")
	local success = handle:close()
	print(result)
	return success
end

local nil_safety_success = run_test_file("test-nil-safety.lua")
print("")
local patterns_success = run_test_file("test-common-patterns.lua")

print("")
print("=" .. string.rep("=", 59))
print("SUMMARY")
print("=" .. string.rep("=", 59))
print("nil-safety tests:     " .. (nil_safety_success and "PASS" or "FAIL"))
print("common-patterns tests: " .. (patterns_success and "PASS" or "FAIL"))
print("")
print("These tests verify nil-safety patterns and common crash")
print("scenarios. See scripts/test-bug-fixes.ts for static")
print("regression tests that check code structure.")

local all_passed = nil_safety_success and patterns_success
os.exit(all_passed and 0 or 1)
