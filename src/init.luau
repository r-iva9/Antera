--!strict
--!optimize 2
--!native

--[[
    ANTERA: Reactive UI Framework for the Allure Ecosystem
    By r-iva9
    Open source (MIT)
    https://github.com/r-iva9/Antera

	Requires (in the same directory)
	ANEX: Customizable state management for the Allure Ecosystem
    By r-iva9
    1.1.0+
    Open source (MIT)
    https://github.com/r-iva9/Anex

    ALLURE FULLSTACK ECOSYSTEM
    By r-iva9
	https://github.com/r-iva9/Allure
]]
const VERSION = "1.0.0"

------------
-- CONFIG

const CONFIG = table.freeze {
	WarnWrongPropertyTypes = true,
	WriteWrongPropertyTypes = false,

	WarnReadonlyProperties = true,
	WriteReadonlyProperties = false,

	WarnWriteonlyProperties = true,
	WriteWriteonlyProperties = true,

	-- The path to a modulescript returning a table of
	-- {classname = {property = value}} defaults for Antera.New
	MountTemplates = nil
}

------------
-- LOGGING

const Log = {
	Warn = function(...)
		local stack = debug.traceback("\n\n -------\t Stack Traceback \t-------", 2)
		warn("[Antera] " .. ... .. if stack then stack else "")
	end,
	WarnAssert = function(config: boolean, condition: boolean, ...)
		if condition or not config then
			return
		end
		local stack = debug.traceback("\n\n -------\t Stack Traceback \t-------", 2)
		warn("[Antera] " .. ... .. if stack then stack else "")
	end,
	Error = function(...)
		error("[Antera] " .. ...)
	end,
	ErrorAssert = function(config: boolean, condition: any?, ...)
		if not config then
			return
		end
		assert(condition, "[Antera] " .. ...)
	end,
}

------------
-- DEPENDENCIES

const ReflectionService = game:GetService("ReflectionService")
local RunService = game:GetService("RunService")

Log.ErrorAssert(
	true,
	script :: any == nil or ((script and script.Parent ~= nil) and (script.Parent:FindFirstChild "Anex" ~= nil)),
	"Anex is required but wasn't found. Make sure Antera and Anex are in the same directory."
)
const Anex = require (script.Parent.Anex) --"../Anex/src" --
Log.ErrorAssert(true, (Anex.IsState ~= nil and Anex.Statify ~= nil), "Anex is of outdated version! Make sure your Anex is at least v1.1.0+")

local Antera = {
	Name = "Antera",
	Version = VERSION,
	Author = "r-iva9",

	--- ALLURE
	Tags = {
		Priority = 1,
		Instance = script,
	},
	Dependencies = { Anex },
	Instance = script,
}

------------
-- TYPES

-- Luau type blanks
type table<K = any, V = any> = { [K]: V }
type fn = <A..., R...>(A...) -> R...
type ffor<R...> = <A...>(A...) -> R...
type with<A...> = <R...>(A...) -> R...
type withself<T, A...> = <R...>(self: T, A...) -> R...

-- Derived
type State<T = any> = Anex.State<T>
type Hook<T = any> = Anex.Hook<T>

-- Special
-- stylua: ignore
--[[
	Desc
]]
export type Amplified<T = table> = setmetatable<
{}, 
{
	__amp: true,
	__index: setmetatable<
	State<T> & {
		--[[
			Desc
		]]
		Update: (self: Amplified<T>, key: any) -> any,
		
		--[[
			Desc
		]]
		NonKey: (self: Amplified<T>, value: any) -> any
	}, {
		__index: setmetatable<
			{ [any]: fn }, --UPDATERS
			{ __index: setmetatable<
				{ [string]: State }, --STATES
				{
					__index: T --VALUE
				}>
			}>,
		__newindex: T
	}>,
	__newindex: (_: any, k: any, v: any) -> any?,
	__call: (_: any, k: any, v: any) -> any?,
}>

type AmplifiedConstructor = <S, T>(container: S, tab: T) -> Amplified<T>

export type SpecialValue<K> = {
	__kind: K,
	__prop: { string },
	__fn: fn,
}

export type Mounted<T = table> = {
	Instance: Instance,
	Amplified: Amplified<T>,
	Destroy: <A...>(A...) -> ()
}

type AnteraValue<T> = index<typeof(Antera) & {[any]: never}, T>
type AnexValue<T> = index<typeof(Anex) & table, T>

type function importTail(t: type, index: type)
	assert(t.tag)
	assert(index.tag)

	local args: any = string.split(t:value() :: string, "/")

	for k, v in args do
		args[k] = AnteraValue(types.singleton(v))
		if args[k] == types.never then
			args[k] = AnexValue(types.singleton(v))
		end
	end

	local typeargs: { type } = args :: any

	local i: string = index:value() :: string

	for k = 1, 25 do
		if tostring(k) == i and typeargs[k] then
			return typeargs[k]
		end
	end

	return types.any
end

------------
-- UTILITIES

--- Returns a typesafe reference to `t`
const function ref<T>(t: T): any
	return t :: any
end

--- Typecasts tail T... to ...any
const function reftail<T...>(...:T...): ...any
	return ...
end

--- Returns true if `t` is a specialValue table and false if not
const function isspecial(t: any): boolean
	return (typeof(t) == "table" and t.__kind and t.__prop and t.__fn) and true or false
end

--- For amplifieds, returns the next numeric key (non-key)
const function nextnumerickey(t: table): number
	local maxi = -1
	for k, v in pairs(t) do
		if typeof(k) == "number" and k > maxi then
			maxi = k
		end
	end
	return maxi + 1
end

const isstate = Anex.IsState
const statify = Anex.Statify

--- Returns a clear value: if given a state, returns it's value, if not, returns the value itself
const function valuefy<T>(t: State<T> | T): T
	return if isstate(nil, t) then ref(t)() else t
end

--- Returns true if the value is a state and an amplified, and false if not
const function isamplified<T>(t: T): boolean
	return (typeof(t) == "table" and isstate(nil, t) and getmetatable(t) and ref(getmetatable(t)).__amp == true)
			and true
		or false
end

const function newspecial<K>(kind: K, prop: { string }, fn: fn): SpecialValue<K>
	return {
		__kind = kind,
		__prop = prop,
		__fn = fn,
		Destroy = function(self: any)
			table.clear(self)
			self = nil
		end,
	}
end

--- Deeply clones table `t`, ignoring inner tables only if they are states or SpecialValues
const function deepClone(t: table)
	local result = {}

	for k, v in pairs(t) do
		if typeof(v) == "table" and not isstate(nil, v) and not isspecial(v) then
			result[k] = deepClone(v)
			continue
		end

		result[k] = v
	end

	return result
end

const ClassPropertiesMemo = {}
const ClassEventsMemo = {}

const function applyProperty(instance: Instance, prop: string, value: any?)
	if not ClassPropertiesMemo[instance.ClassName][prop] then return end
	const ClassProperty: never = ClassPropertiesMemo[instance.ClassName][prop]

	if (ClassProperty.Permits.Write and tostring(ClassProperty.Permits.Write) ~= "") or (RunService:IsServer() and tostring(ClassProperty.Permits.Write) == "LocalUser") then 
		Log.WarnAssert(CONFIG.WarnReadonlyProperties, false, 
			string.format("WarnReadonlyProperties: Cannot set the property %s on instance %s (%s) to %s: it is read-only.", 
			prop, instance.Name, instance.ClassName, tostring(value))
		)
		if not CONFIG.WriteReadonlyProperties then return end
	end

	if (ClassProperty.Permits.Read and tostring(ClassProperty.Permits.Read) ~= "") or (RunService:IsServer() and tostring(ClassProperty.Permits.Read) == "LocalUser") then 
		Log.WarnAssert(CONFIG.WarnWriteonlyProperties, false, 
			string.format("WarnWriteonlyProperties: The property %s on instance %s (%s) is write-only.", 
			prop, instance.Name, instance.ClassName)
		)
		if not CONFIG.WriteWriteonlyProperties then return end
	end

	if typeof(value) ~= ClassProperty.Type.ScriptType then
		Log.WarnAssert(CONFIG.WarnWrongPropertyTypes, false, 
			string.format("WarnWrongPropertyTypes: Attempt to set the property %s on instance %s (%s) to %s (%s); expected %s", 
			prop, instance.Name, instance.ClassName, tostring(value), typeof(value), ClassProperty.Type.ScriptType)
		)
		if not CONFIG.WriteWrongPropertyTypes then return end
	end

	ref(instance)[prop] = value
end

------------
-- ANTERA

--[[
	A typesafe shortcut for importing functions from Antera and Anex.<br>Returns perfectly correct types via a typefunction.
	```luau
	const Amplify, Effect = Antera:Import "Amplify/Effect"
	```
]]
Antera.Import = function<S, T>(
	self: S,
	imports: T | ""
): (
	importTail<T, "1">,
	importTail<T, "2">,
	importTail<T, "3">,
	importTail<T, "4">,
	importTail<T, "5">,
	importTail<T, "6">,
	importTail<T, "7">,
	importTail<T, "8">,
	importTail<T, "9">,
	importTail<T, "10">,
	importTail<T, "11">,
	importTail<T, "12">
)
	local args = string.split(imports, "/")

	for i, v in args do
		args[i] = (ref(Antera)[v]) or (ref(Anex)[v])
	end

	return reftail(table.unpack(args))
end

Antera.IsAmplified = function<S, T>(self: S, t: T): boolean
	return isamplified(t)
end

Antera.IsSpecial = function<S, T>(self: S, t: T): boolean
	return isspecial(t)
end

Antera.Mount = function<S, T>(container: S, instance: Instance, amplified: Amplified<T>): Mounted<T>
	Log.ErrorAssert(true, instance, "Antera:Mount received no instance (2nd parameter)")
	Log.ErrorAssert(true, typeof(instance) == "Instance", "Antera:Mount received a non-instance (2nd parameter)")
	local self: Mounted<T>

	self = {
		Instance = instance,
		Amplified = amplified,
		Destroy = function<A...>(...: A...)
			table.clear(self)
			self = nil :: never
		end
	}

	const ClassName = instance.ClassName

	if not ClassPropertiesMemo[ClassName] then
		const Properties = ReflectionService:GetPropertiesOfClass(ClassName)

		ClassPropertiesMemo[ClassName] = {} :: table
		for _, prop in Properties do
			ClassPropertiesMemo[ClassName][prop.Name] = prop
		end
	end
	const ClassProperties = ClassPropertiesMemo[ClassName]

	if not ClassEventsMemo[ClassName] then
		const Events = ref(ReflectionService):GetEventsOfClass(ClassName) --no ill use it

		ClassEventsMemo[ClassName] = {} :: table
		for _, prop in Events do
			ClassEventsMemo[ClassName][prop.Name] = prop
		end
	end
	const ClassEvents = ClassEventsMemo[ClassName]

	warn(ClassProperties, ClassEvents)

	applyProperty(instance, "Parent", workspace)
	applyProperty(instance, "Position", Vector3.new(5, 5, 5))
	applyProperty(instance, "Anchored", true)

	if container ~= Antera then
		table.insert(container, self)
	end

	return self
end

Antera.ForSet = function<S, T>(container: S, ...: string)
	local prop = { ... }
	return function(fn: fn): SpecialValue<"ForSet">
		local special = newspecial("ForSet" :: "ForSet", prop, fn)

		if container ~= Antera then
			table.insert(container, special)
		end

		return special
	end
end

Antera.OnSet = function<S, T>(container: S, ...: string)
	local prop = { ... }
	return function(fn: fn): SpecialValue<"OnSet">
		local special = newspecial("OnSet" :: "OnSet", prop, fn)

		if container ~= Antera then
			table.insert(container, special)
		end

		return special
	end
end

Antera.Amplify = function<S, T>(container: S, tab: T)
	local VALUE: table = {}

	local self: any = Anex:State(VALUE)

	local UPDATERS: table<any, fn> = {}
	local STATES: table<any, State> = {}
	local ONSETS: table = {}

	local AMPLIFIED = {}

	local ___nindex = function(_, k: any, v: any)
		-- case 3: if v was a state/different state, disconnect it

		local kstate = rawget(STATES, k)
		if kstate then
			kstate:Connect(UPDATERS[k])(nil)
			STATES[k] = nil
		end
		UPDATERS[k] = nil

		for _, st in ONSETS do
			st[k] = nil
		end

		local function nestval(key, val: any)
			val = ref(val)
			-- case 1, if v is amplified table then the table value is passed to nestval
			-- case 2, if v is a state
			if isstate(nil, val) then
				VALUE[key] = val()
				STATES[key] = val
				UPDATERS[key] = function<A..., R...>(...: A...): R...
					return nestval(key, val()) :: any
				end
				val:Connect(UPDATERS[key])

				nestval(key, val())
				return

			-- case 6, if v is a function
			elseif typeof(ref(val)) == "function" then
				UPDATERS[key] = val
				--[[= function<A..., R...>(...: A...): R...
					return nestval(key, val(AMPLIFIED)) :: any
				end]]
				nestval(key, val(AMPLIFIED))

			-- case 4, if v is ForSet is called immediately and via onsets and passes down a value
			-- onevent and onchange can only be handled by alloy.mount so they are passed forwards
			elseif isspecial(val) and val.__kind == "ForSet" then
				local fn = function<A..., R...>(...: A...): R...
					return nestval(key, val.__fn(AMPLIFIED)) :: any
				end

				for _, prop in val.__prop do
					ONSETS[prop] = ONSETS[prop] or {}
					ONSETS[prop][key] = fn
				end

				-- turning ForSet into effect:
				UPDATERS[key] = val.__fn --amp.val()
				nestval(key, val.__fn(AMPLIFIED)) --amp().val

			-- case 8, OnSet is called via onsets and passes no value
			elseif isspecial(val) and ref(val).__kind == "OnSet" then
				val = ref(val) --typechecking loses its mind
				local fn = function<A..., R...>(...: A...): R...
					return nestval(key, val.__fn(AMPLIFIED)) :: any
				end

				for _, prop in pairs(val.__prop) do
					ONSETS[prop] = ONSETS[prop] or {}
					ONSETS[prop][key] = fn
				end

				-- turning OnSet into effect:
				UPDATERS[key] = val.__fn --amp.val()
				-- nil value originally

			-- case 7, v is a table (nestval each key, value pair)
			elseif not isspecial(ref(val)) and typeof(val) == "table" then
				for k1, v1 in pairs(val) do
					if typeof(k1) == "number" and k1 <= 15 then
						k1 = nextnumerickey(VALUE)
					end
					nestval(k1, v1)
				end

			-- case 5, if its anything else: instance, number, vector3, etc.
			else
				VALUE[key] = val

				self:Fire(key :: any, val)
				if ONSETS[key] then
					for _, j in ONSETS[key] do
						j(AMPLIFIED)
					end
				end
			end
		end

		nestval(k, v)
	end

	self.Update = function(self: Amplified<T>, key: any): any
		return UPDATERS[key] and ___nindex(nil, key, UPDATERS[key]())
	end

	self.NonKey = function(self: Amplified<T>, value: any): any
		local key = nextnumerickey(VALUE)
		___nindex(nil, key, value)
		return key
	end

	setmetatable(self, {
		__index = STATES,
		__newindex = VALUE,
	})

	setmetatable(STATES, {
		__index = UPDATERS,
	})

	setmetatable(UPDATERS, {
		__index = VALUE,
	})

	setmetatable(AMPLIFIED, {
		__amp = true,
		__index = self,
		__newindex = ___nindex,
		__call = function(self, key, val): any
			if not key and not val then
				return VALUE
			end
			if not val then
				return self:NonKey(key)
			end
			return ___nindex(nil, key, val)
		end,
	})

	local next__order: any = {} --[number]: table -- various tables of the next order within the same order

	-- reevaluating given values in the initial table
	for k, v in pairs(tab) do
		-- if v is a specialvalue, it's moved an order higher with a specific tag in the order table
		if isspecial(v) then
			next__order[nextnumerickey(next__order)] = { k, v, __fromprev = true } --special values are automatically one order higher
			continue
		-- if it's just a table, then it's an order table and it should be moved up
		elseif typeof(v) == "table" and not isstate(nil, v) then
			next__order[k] = v
			continue
		end
		-- else it's a normal value
		___nindex(nil, k :: any, v)
	end

	-- // ordering
	repeat
		-- cloning the previous order and creating an empty next one
		local _nx: any = deepClone(next__order)
		next__order = {}

		for _, v0 in pairs(_nx) do
			-- if our 'order table' from the order has this tag then it's a special value simply moved higher
			if v0.__fromprev then
				___nindex(nil, v0[1], v0[2] :: any)
				continue
			end

			for k, v in pairs(v0) do
				if isspecial(v) then
					next__order[nextnumerickey(next__order)] = { k, v, __fromprev = true } --special values are automatically one order higher
					continue
				elseif typeof(v) == "table" and not isstate(nil, v) then
					next__order[k] = v
					continue
				end
				___nindex(nil, k :: any, v)
			end
		end

	--task.wait()
	until #next__order == 0

	if container ~= Antera then
		table.insert(container, AMPLIFIED)
	end

	return AMPLIFIED
end :: AmplifiedConstructor

return Antera
