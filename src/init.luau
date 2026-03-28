--!strict
--!optimize 2
--!native

--[[
    Antera: Customizable state management for the Allure Ecosystem
    By r-iva9
    1.0.0
    Open source (MIT)
    https://github.com/r-iva9/Antera

    ALLURE FULLSTACK ECOSYSTEM
    By r-iva9
	https://github.com/r-iva9/Allure
]]

------------
-- TYPES

--[=[
	luau type blanks
]=]

type table<K = any, V = any> = { [K]: V }
type fn = <A..., R...>(A...) -> R...
type ffor<R...> = <A...>(A...) -> R...
type with<A...> = <R...>(A...) -> R...
type withself<T, A...> = <R...>(self: T, A...) -> R...

------------
-- UTILITY

local Antera = nil :: never

--- Returns a typesafe reference to `t`
local function ref<T>(t: T): any
	return t :: any
end

--- Returns `true` is the value is a State and `false` if not
local function isstate(value: any): boolean
	return typeof(value) == "table" and value.Val ~= nil and value.Connect and value.Fire and value.Setter
end

------------
-- ANTERA

Antera = {
	Name = "Antera",
	Version = "1.0.0",
	Author = "r-iva9",

	--- ALLURE
	Tags = {
		Priority = 0,
		Instance = script,
	},
	Dependencies = {},
	Instance = script,
}

return Antera
