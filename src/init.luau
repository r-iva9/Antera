--!strict
--!optimize 2

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
const VERSION = table.freeze {major = 1, minor = 0, patch = 1, release = false}

------------
-- CONFIG

const CONFIG = table.freeze {
	--[[
		Frequency of spring updates in the spring solver
		the `k` spring stiffness constant
		and a speed coefficient for all springs created
	]]
	SpringRateHZ = 80,
	SpringStiffness = 3,
	SpringSpeedCoefficient = 5,


	--[[
		Last frame requirements (LFR) for (goal-value) delta and velocity
		if the delta AND velocity*delta are lower than these values respectively,
		the spring ends it's work and sets value to goal, making it the last frame of the spring animation
	]]
	SpringLFRDelta = 0.01,
	SpringLFRVelocity = 4*1e-4,

	--[[
		When merging amplifieds, nonkeyed values with (their actual numeric keys) lower or equal to this value,
		Antera will upscale to the next lowest numeric nonkey of the bigger amplified so that nonkeyed values don't override
		in short, care about this number only if you for some reason make numeric amplified keys
	]]
	AmplifiedMergeNonkeyLimit = 12,

	--[[
		Whether to make a warning when Antera detects a wrong type of value
		passed for a property of an instance, and whether to change it regardless
	]]
	WarnWrongPropertyTypes = true,
	WriteWrongPropertyTypes = false,

	--[[
		Whether to make a warning when Antera detects an attempt to change a 
		read-only property, and whether to change it regardless
	]]
	WarnReadonlyProperties = true,
	WriteReadonlyProperties = false,

	--[[
		Whether to make a warning when Antera detects an attempt to change a 
		write-only property, and whether to change it regardless
	]]
	WarnWriteonlyProperties = true,
	WriteWriteonlyProperties = true,

	--[[
		Whether to make a warning when a nonexistent event was passed to Antera:OnEvent
		Whether to look for and warn corrections, for example Clicked --> MouseButton1Click
		Whether to correct it, if corrections were found
	]]
	WarnWrongEvents = true,
	WarnConfusableEvents = true,
	FixConfusableEvents = true,

	--[[
		Whether to make a warning when Antera detects an event that has an abnormal Listen permit
		Whether to try and listen (conect) to it regardless
	]]
	WarnUnlistenableEvents = true,
	ConnectUnlistenableEvents = true,

	--[[
		Whether to make a warning when Antera detects a property that could be a typo or mistake
		Whether to automatically correct it
	]]
	WarnConfusableProperties = true,
	FixConfusableProperties = false,

	-- The path to a modulescript returning a table of
	-- {ClassName = {Property = Value}} defaults for Antera.New
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
const RunService = game:GetService("RunService")
const Players = game:GetService("Players")

const Templates = if CONFIG.MountTemplates then require(CONFIG.MountTemplates) :: table else {}

Log.ErrorAssert(
	true,
	(script :: any == nil) or ((script and script.Parent ~= nil) and (script.Parent:FindFirstChild "Anex" ~= nil)),
	"Anex is required but wasn't found. Make sure Antera and Anex are in the same directory."
)
const Anex = require (script.Parent.Anex) --"../Anex/src" --
Log.ErrorAssert(true, (Anex.IsState ~= nil and Anex.Statify ~= nil), "Anex is of outdated version! Make sure your Anex is at least v1.1.0+")

const Antera = {
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
	An `Amplified` table. Amplified tables are tables integrated with reactive functionality<br>and fully suited for UI.
	<br>Amplifieds represent an `Anex State` containing a table value. The amplified reference differs from the actual value returned by `TheAmplified()`

	Within amplifieds, values of specific types are changed:
	- ***functions*** are called immediately. The returned result is then
		<br>the actual value of the key *(referenced via `TheAmplified().key`*,
		<br>however the function is preserved and *referenced via `TheAmplified.key`*

	- ***tables*** are merged with the amplified, having that all new values face the same treatment.
		<br>The table can still be referenced via `TheAmplified.key` however the actual value will 
		<br>be `nil` unless specified in the table itself.
		
		Nesting table values in the declaration will create ***orders***: second nest -- second order, and so on.
		<br>This is purposed for race conditions appearing when a key needs an another key.

	- ***Anex States*** are connected with the Amplified, the actual value is the state value.
		<br>Changing the state changes the value in the Amplified and calls Amplified connections as well.
		<br>The state is referenced via `TheAmplified.key`; the actual value of it via `TheAmplified().key`

		Since the Amplified itself is a state, making a value Amplified will nest these changes.
		<br>An amplified as a value will return it's table value, which is then merged,
		<br>so including an amplified one in another will "merge" them. Updating the nested one will update the bigger one.
		<br>The bigger one will always include keys of the nested one, unless changed otherwise.

	Amplifieds have a multitude of utilities, such as `Antera.OnSet`, `Antera.Mount` or `Antera.OnEvent`.
]]
export type Amplified<T = table> = setmetatable<
{}, 
{
	__amp: true,
	__index: setmetatable<
	State<T> & {
		--[[
			Update the value of a key if it's connected. Doing this with
			- ***function values*** will call the function again and set the key to the returned value;
			- ***state values*** will get the value from the state and set the key to it.
		]]
		Update: (self: Amplified<T>, key: any) -> any,
		
		--[[
			Insert a new NonKey value into the Amplified.
		]]
		NonKey: (self: Amplified<T>, value: any) -> any,

		--[[
			A hook that fires connections with (amplified, mounted) whenever the amplified is mounted on an instance.
		]]
		Mounted: Anex.Hook<Mounted<T>>,

		--[[
			*DO NOT TOUCH THIS*: exposure of internal amplified updaters.
		]]
		__Updaters: { [any]: fn | table },

		--[[
			Destroy the Amplified, doing this will
			- eliminate all mounted objects of this amplified
			- eliminate all event connections made
		]]
		Destroy: (...any?) -> (),
	}, {
		__index: setmetatable<
			{ [any]: fn | table }, --UPDATERS
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

--[[
	A special table value that is treated as a special object in Amplifieds.
	<br> `K` generic represents the specialvalue's `kind` singleton

	Applications of this include `Antera.OnSet`, `ForSet`, `OnEvent` and `Child`
]]
export type SpecialValue<K> = {
	__kind: K,
	__prop: string | { string },
	__arg: any?,
	__fn: fn,
}

--[[
	A mounted object representing a connection between an Amplified and an Instance.
	<br>Updating any key in the amplified will update it on the instance as a property, if it's valid.
]]
export type Mounted<T = table> = setmetatable<
{
	Instance: Instance,
	Amplified: Amplified<T>,
	Destroy: <A...>(A...) -> ()
},
{
	__index: Amplified<T>,
	__newindex: Amplified<T>,
	__call: (...any) -> T
}>

--[[
	Internal spring that updates a single number value
]]
type SpringProcess = {
	Goal: number,
	Value: number,
	Velocity: number,
	Force: number,
	CriticalDamping: number, --derived
	Damping: number,
	Speed: number,

	Step: (SpringProcess?) -> any,
	Close: (...any) -> (),

	Remove: (...any) -> (),
	Add: (...any) -> (),

	SetSpeed: (SpringProcess, number) -> (),
	SetDamping: (SpringProcess, number) -> (),
	SetGoal: (SpringProcess, number) -> (),
}

--[[
	Types of values that can currently be animated with Springs
]]
export type Animatable = 
	number |
	--string |
	table | --this is an unsupported type, if i leave this commented the type solver bugs out lol
	Vector2 |
	Vector2int16 |
	Vector3 |
	Vector3int16 |
	UDim |
	UDim2 |
	Rect |
	Color3 |
	--ColorSequence | --antera plans to support these and table soon, as of the moment i am lazy and tired
	--NumberSequence |
	ColorSequenceKeypoint |
	CFrame

--[[
	A spring object purposed for runtime animations.
	<br>Creating a spring object will create the needed amount of SpringProcesses,<br>varying the number for optimization if some aren't needed.
]]
export type Spring<T = any> = State<T> & {
	Velocity: T,
	Goal: T,
	Damping: number,
	Speed: number,

	--[[
		Detaches the spring from the Antera's spring solver
	]]
	Detach: (...any) -> (),

	--[[
		Attaches the spring to the Antera's spring solver
	]]
	Attach: (...any) -> (),

	SetDamping: (Spring<T>, damping: number) -> (),
	SetSpeed: (Spring<T>, speed: number) -> (),
	SetGoal: (Spring<T>, goal: T) -> (),

	--[[
		Sets goal in `sec` seconds to `goal` if the `goal` remains unchanged during this time
	]]
	DelayGoal: (Spring<T>, sec: number, goal: T) -> (),

	--[[
		Update the spring, by setting it's value to the one that it should have at the moment
	]]
	Update: (...any) -> (),
}

type AnteraValue<T> = index<typeof(Antera) & {[any]: never}, T>
type AnexValue<T> = index<typeof(Anex) & table, T>

--[[
	Used for the `Antera.Import` tail types, `index` is a singleton with a number, like `"4"`
]]
type function importTail(t: type, index: type)
	assert(t.tag)
	assert(index.tag)

	const args: any = string.split(t:value() :: string, "/")

	for k, v in args do
		args[k] = AnteraValue(types.singleton(v))
		if args[k] == types.never then
			args[k] = AnexValue(types.singleton(v))
		end
	end

	const typeargs: { type } = args :: any

	local i: string = index:value() :: string

	for k = 1, 25 do
		if tostring(k) == i and typeargs[k] then
			return typeargs[k]
		end
	end

	return types.any
end

------------
-- SPRING SOLVER

const SpringProcesses: {[SpringProcess]: true} = {}
const Springs: {[any]: true} = {} --[spring]: true

do
	local t = 0
	const hz = CONFIG.SpringRateHZ

	RunService.Heartbeat:Connect(function(dt)
		task.defer(function()
			debug.profilebegin(`[Antera] Spring Solver (per spring updates: {math.floor((t+dt)*hz)})`)
			t += dt
			
			while t > 1/hz do
				-- step each SpringProcess, SpringProcesses update a coordinate each in data,
				-- Vector3 for example, instead of converting back and forth
				for sp in SpringProcesses do
					sp.Step()
				end
				t -= 1/hz
			end

			-- update each Spring, now that springprocesses have made a step each
			for sp: any in Springs do
				sp:Update()
			end

			debug.profileend()
		end)
	end)
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
@native
const function isspecial(t: any): boolean
	return (typeof(t) == "table" and rawget(t, "__kind") and rawget(t, "__prop") and rawget(t, "__fn")) and true or false
end

--- For amplifieds, returns the next numeric key (non-key)
@native
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

--- Returns true if the value is a state and an amplified, and false if not
@native
const function isamplified<T>(t: T): boolean
	return (typeof(t) == "table" and isstate(nil, t) and getmetatable(t) and ref(getmetatable(t)).__amp == true)
			and true
		or false
end

--- Returns true if the value is a mounted object, and false if not
@native
const function ismounted<T>(t: T & table): boolean
	return (typeof(t) == "table" and not isstate(nil, t) and rawget(t, "Instance") and rawget(t, "Amplified") and rawget(t, "Destroy")) and true or false
end

@native
const function newspecial<K>(kind: K, prop: string | { string }, fn: fn, arg: any?): SpecialValue<K>
	return {
		__kind = kind,
		__prop = prop,
		__arg = arg,
		__fn = fn,
		Destroy = function(self: any)
			table.clear(self)
			self = nil
		end,
	}
end

--[[
	Creates a new spring process that represents a single number value slowly moving toward it's goal
]]
const function springprocess(value: number, damping: number, speed: number): SpringProcess
	const k = CONFIG.SpringStiffness
	speed *= CONFIG.SpringSpeedCoefficient

	local self = {
		Goal = value,
		Value = value,
		Velocity = 0,
		Force = 0,
		CriticalDamping = 2*math.sqrt(k*speed),
		Damping = damping*2*math.sqrt(k*speed),
		Speed = speed,
	}

	local delta = self.Goal - self.Value

	self.SetSpeed = function(_: SpringProcess, speed: number)
		speed *= CONFIG.SpringSpeedCoefficient
		self.Speed = speed
		self.CriticalDamping = 2*math.sqrt(k*speed)
		self.Damping = self.CriticalDamping*self.Damping
	end

	self.SetDamping = function(_: SpringProcess, damping: number)
		self.Damping = self.CriticalDamping*damping
	end

	self.SetGoal = function(_: SpringProcess, goal: number)
		self.Goal = goal
		delta = self.Goal - self.Value
		self:Add()
	end

	self.Remove = function()
		SpringProcesses[self] = nil
	end

	self.Add = function()
		SpringProcesses[self] = true
	end

	self.Step = function(_: SpringProcess?)
		local x = self.Goal - self.Value

		if self.Value == self.Goal then self:Remove(); return self.Value
		elseif math.abs(x) < CONFIG.SpringLFRDelta*math.abs(delta) and math.abs(self.Force * self.Speed) < CONFIG.SpringLFRVelocity*math.abs(delta) then
			-- end the spring if it's too close to the end and it's velocity is too little (last frame)
			self.Value = self.Goal
			self.Force = 0
			self.Velocity = 0
			self:Remove() --remove the spring from the spring solver, this self-optimizes

			return self.Value
		end

		const dt = 1 / CONFIG.SpringRateHZ

		--[[
			F = -kx = ma
			having m = 1:
			F = -kx = a
			a = -kx

			x = goal - value
			value += a <=> value += -k(goal - value)

			delta v = Ft/m = Ft
			delta pos = v*t
		]]

		self.Force = k*x
		self.Velocity += self.Force * dt * self.Speed --speed appearance

		self.Value += self.Velocity * dt

		-- damping force Fd = -cv
		-- delta v = Fd*t
		const dampingForce = -self.Damping*self.Velocity
		self.Velocity += dampingForce*dt

		return self.Value
	end

	self.Close = function(...)
		self:Remove()
		table.clear(self)
		self = nil :: never
	end

	--SpringProcesses[self] = true --no need for value == goal

	return self
end

--[[
	A shortcut used in springs, that generates the needed amount of springprocesses for<br>the value's type, configures the `setter` and `Update` method of the spring
]]
const function generateSprings(self: Spring, springs: {SpringProcess}, damping: number, speed: number, goals: (any) -> ...any, update: (...any) -> any, ...: any)
	const values = {...}
	for i=1, #values do
		springs[i] = springprocess(values[i], damping, speed)
	end

	self:Setter(function(_, value)
		self.Goal = value
		const goals = {goals(value)}
		for i=1, #goals do
			springs[i]:SetGoal(goals[i])
		end

		self:Attach()
		return self()
	end)

	function self:Update(...)
		self.Val = update(unpack(springs))
		self:Fire(self.Val)

		if self.Val == self.Goal then
			self:Detach()
		end
	end
end

--- Deeply clones table `t`, ignoring inner tables only if they are states or SpecialValues
@native
const function deepClone(t: table)
	const result = {}

	for k, v in pairs(t) do
		if typeof(v) == "table" and not isstate(nil, v) and not isspecial(v) then
			result[k] = deepClone(v)
			continue
		end

		result[k] = v
	end

	return result
end

--- Returns `true` if `v` is present in table `t`, and `false` if not
@native
const function hasValue(t: table, v: any)
	for _, val in t do
		if val==v then return true end
	end
	return false
end

-- Confusable events, properties and what to recommend
-- clickdetector just confused me and i dont want to open docs
-- If you disable warnings and enable the Fix configs then these are aliases <<<<<<
const ConfusableEvents = {
	any = {
		MouseButtonClick = "MouseButton1Click",
		MouseClicked = "MouseButton1Click",
		MouseClick = "MouseButton1Click",
		OnClick = "MouseButton1Click",
		onClick = "MouseButton1Click",
		Click = "MouseButton1Click",
		Clicked = "MouseButton1Click",
		MouseHover = "MouseEnter",
		MouseHovered = "MouseEnter",
		Hovered = "MouseEnter",
		MouseLeft = "MouseLeave",
	},
	ClickDetector = {
		MouseButton1Click = "MouseClick",
		MouseButtonClick = "MouseButton1Click",
		Click = "MouseClick",
		MouseClicked = "MouseClick",
		OnClick = "MouseClick",
		onClick = "MouseClick",
		Clicked = "MouseClick",
	}
}
const ConfusableProperties = {
	UIAspectRatioConstraint = {
		Ratio = "AspectRatio"
	},
	UICorner = {
		Radius = "CornerRadius",
		Corner = "CornerRadius",
		Ratio = "CornerRadius"
	},
	UIStroke = {
		Stroke = "Thickness",
		Color3 = "Color",
		BrickColor = "Color",
		BackgroundColor3 = "Color",
		Mode = "ApplyStrokeMode",
	},
}

const function checkConfusableProperties(instanceClass: string, prop: string)
	return if ConfusableProperties[instanceClass] then ConfusableProperties[instanceClass][prop] else nil
end
const function checkConfusableEvents(instanceClass: string, event: string)
	return if ConfusableEvents[instanceClass] then ConfusableEvents[instanceClass][event] else ConfusableEvents.any[event]
end

-- tables of [classname] = {property = ReflectedProperty or ReflectedEvent} 
-- are used to store and avoid repetitive ReflectionService api calls
const ClassPropertiesMemo = {}
const ClassEventsMemo = {}

--[[
	For mounting: apply a property to an instance, passing all checks, write and read permissions included
]]
const function applyProperty(instance: Instance, prop: string, value: any?): (...any?)
	const ClassProperty: never = ClassPropertiesMemo[instance.ClassName][prop]
	if not ClassProperty :: any then 
		const confused = checkConfusableProperties(instance.ClassName, prop)
		if confused then 
			Log.Warn(
				string.format("Attempt to set nonexistent property '%s' on instance '%s' (%s).\n\tPerhaps you meant '%s'?", prop, instance.Name, instance.ClassName, confused)
				.. (confused and CONFIG.FixConfusableProperties and " Applying..." or "")
			)
		end
		return (confused and CONFIG.FixConfusableProperties) and applyProperty(instance, confused, value) or nil  
	end

	const Write = ClassProperty.Permits.Write
	const Read = ClassProperty.Permits.Read

	if Write == Enum.SecurityCapability.InternalTest or Write == Enum.SecurityCapability.RobloxEngine or (RunService:IsServer() and tostring(Write) == "LocalUser") then 
		Log.WarnAssert(CONFIG.WarnReadonlyProperties, false, 
			string.format("WarnReadonlyProperties: Cannot set the property '%s' on instance '%s' (%s) to %s: it is read-only.", 
			prop, instance.Name, instance.ClassName, tostring(value))
		)
		if not CONFIG.WriteReadonlyProperties then return nil end
	end

	if Read == Enum.SecurityCapability.InternalTest or Read == Enum.SecurityCapability.RobloxEngine or (RunService:IsServer() and tostring(Read) == "LocalUser") then 
		Log.WarnAssert(CONFIG.WarnWriteonlyProperties, false, 
			string.format("WarnWriteonlyProperties: The property '%s' on instance '%s' (%s) is write-only.", 
			prop, instance.Name, instance.ClassName)
		)
		if not CONFIG.WriteWriteonlyProperties then return nil end
	end

	if typeof(value) ~= ClassProperty.Type.ScriptType then
		-- exception: roblox automatically converts numbers into strings
		if typeof(value) == "number" and ClassProperty.Type.ScriptType == "string" then
			ref(instance)[prop] = value 
			return nil
		end
		Log.WarnAssert(CONFIG.WarnWrongPropertyTypes, false, 
			string.format("WarnWrongPropertyTypes: Attempt to set the property '%s' on instance '%s' (%s) to %s (%s); expected %s", 
			prop, instance.Name, instance.ClassName, tostring(value), typeof(value), ClassProperty.Type.ScriptType)
		)
		if not CONFIG.WriteWrongPropertyTypes then return nil end
	end

	ref(instance)[prop] = value
end

--[[
	For mounting: connect a function to an instance's event, passing all checks, listening permissions included
]]
const function applyEvent(instance: Instance, event: string, fn: fn): RBXScriptConnection?
	const ClassEvent: never = ClassEventsMemo[instance.ClassName][event]
	if not ClassEvent :: any then 
		const confused = checkConfusableEvents(instance.ClassName, event)
		Log.Warn(string.format(
			"Attempt to connect to a nonexistent event '%s' on instance '%s' (%s)", 
			event, instance.Name, instance.ClassName) 
			.. (confused and string.format("\n\tPerhaps you meant '%s'?", confused) or "")
			.. (confused and CONFIG.FixConfusableEvents and " Applying..." or "")
		)
		return (confused and CONFIG.FixConfusableEvents) and applyEvent(instance, confused, fn) or nil 
	end

	const Listen = ClassEvent.Permits.Listen

	if Listen == Enum.SecurityCapability.InternalTest or Listen == Enum.SecurityCapability.RobloxEngine or (RunService:IsServer() and tostring(Listen) == "LocalUser") then 
		Log.WarnAssert(CONFIG.WarnUnlistenableEvents, false, 
			string.format("WarnUnlistenableEvents: The event '%s' on instance '%s' (%s) cannot be listened to.", 
			event, instance.Name, instance.ClassName)
		)
		warn(Listen, ClassEvent.Permits)
		if not CONFIG.ConnectUnlistenableEvents then return nil end
	end

	return ref(instance)[event]:Connect(fn)
end

const function applyChangeEvent(instance: Instance, prop: string, fn: fn): RBXScriptConnection?
	const ClassProperty: never = ClassPropertiesMemo[instance.ClassName][prop]
	if not ClassProperty :: any then 
		Log.Warn(string.format(
			"Attempt to connect to a GetPropertyChangedSignal for a nonexistent property '%s' on instance '%s' (%s)", 
			prop, instance.Name, instance.ClassName)
		)
		return nil
	end
	
	return instance:GetPropertyChangedSignal(prop):Connect(fn)
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

--[[
	Creates a Spring state into the `container`.
	<br>Springs are used to smoothly animate values with spring physics.

	`damping < 1` makes an *underdamped* spring: will overshoot<br>
	`damping = 1` makes a *critically damped* spring: perfect not to overshoot or speed up<br>
	`damping > 1` makes an *overdamped* spring: will arrive faster

	Constants:
	- **c** = `critical * damping`, **critical damping** = `2sqrt(k*speed)`
	- **m** = `1`
	- modify stiffness **k** in Antera's CONFIG
	- **speed** multiplies velocity
]]
Antera.Spring = function<S, T>(container: S, value: Animatable & T, damping: number, speed: number): Spring<T>
	container = if container ~= Anex and container ~= Antera then container else nil
	const self: Spring = Anex.State(container, value) :: any

	Log.ErrorAssert(true, damping~=nil, `Antera:Spring received nil damping {speed~=nil and "and speed" or ""} parameter{speed~=nil and "s" or ""}`)
	Log.ErrorAssert(true, speed~=nil, "Antera:Spring received nil speed parameter")

	self.Speed = speed
	self.Damping = damping
	self.Goal = value
	self.Velocity = 0

	const springs: {SpringProcess} = {}

	--generate springprocesses
	if typeof(value) == "number" then
		springs[1] = springprocess(value, damping, speed)
		self:Setter(function(_, value)
			self.Goal = value
			springs[1]:SetGoal(value)
			self:Attach()
			return self()
		end)
		function self:Update(...)
			self.Val = springs[1].Value
			self:Fire(self.Val)

			if self.Val == self.Goal then
				self:Detach()
			end
		end
	elseif typeof(value) == "Vector2" then
		generateSprings(self, springs, damping, speed,
			function(new) --goals
				return new.X, new.Y
			end,
			function(x, y) --self:Update
				return Vector2.new(x.Value, y.Value)
			end,
			value.X, value.Y) --start values
	elseif typeof(value) == "Vector2int16" then
		generateSprings(self, springs, damping, speed,
			function(new) --goals
				return new.X, new.Y
			end,
			function(x, y) --self:Update
				return Vector2int16.new(x.Value, y.Value)
			end,
			value.X, value.Y) --start values
	elseif typeof(value) == "Vector3" then
		generateSprings(self, springs, damping, speed,
			function(new) --goals
				return new.X, new.Y, new.Z
			end,
			function(x, y, z) --self:Update
				return Vector3.new(x.Value, y.Value, z.Value)
			end,
			value.X, value.Y, value.Z) --start values
	elseif typeof(value) == "Vector3int16" then
		generateSprings(self, springs, damping, speed,
			function(new) --goals
				return new.X, new.Y, new.Z
			end,
			function(x, y, z) --self:Update
				return Vector3int16.new(x.Value, y.Value, z.Value)
			end,
			value.X, value.Y, value.Z) --start values
	elseif typeof(value) == "UDim" then
		generateSprings(self, springs, damping, speed,
			function(new: UDim) --goals
				return new.Scale, new.Offset
			end,
			function(scale, offset) --self:Update
				return UDim.new(scale.Value, offset.Value)
			end,
			value.Scale, value.Offset) --start values
	elseif typeof(value) == "UDim2" then
		generateSprings(self, springs, damping, speed,
			function(new: UDim2) --goals
				return new.X.Scale, new.X.Offset, new.Y.Scale, new.Y.Offset
			end,
			function(xscale, xoffset, yscale, yoffset) --self:Update
				return UDim2.new(xscale.Value, xoffset.Value, yscale.Value, yoffset.Value)
			end,
			value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset) --start values
	elseif typeof(value) == "Rect" then
		generateSprings(self, springs, damping, speed,
			function(new: Rect) --goals
				return new.Min, new.Max
			end,
			function(min, max) --self:Update
				return Rect.new(min.Value, max.Value)
			end,
			value.Min, value.Max) --start values
	elseif typeof(value) == "Color3" then
		generateSprings(self, springs, damping, speed,
			function(new: Color3) --goals
				return new.R, new.G, new.B
			end,
			function(R, G, B) --self:Update
				return Color3.new(R.Value, G.Value, B.Value)
			end,
			value.R, value.G, value.B) --start values
	elseif typeof(value) == "ColorSequenceKeypoint" then
		generateSprings(self, springs, damping, speed,
			function(new: ColorSequenceKeypoint) --goals
				return new.Time, new.Value.R, new.Value.G, new.Value.B
			end,
			function(Time, R, G, B) --self:Update
				return ColorSequenceKeypoint.new(Time.Value, Color3.new(R.Value, G.Value, B.Value))
			end,
			value.Time, value.Value.R, value.Value.G, value.Value.B) --start values
	elseif typeof(value) == "CFrame" then
		generateSprings(self, springs, damping, speed,
			function(new: CFrame) --goals
				return new.X, new.Y, new.Z, 
					new.X + new.LookVector.X, new.Y + new.LookVector.Y, new.Z + new.LookVector.Z, 
					new.UpVector.X, new.UpVector.Y, new.UpVector.Z
			end,
			function(posX, posY, posZ, lookatX, lookatY, lookatZ, upX, upY, upZ) --self:Update
				return CFrame.lookAt(
					Vector3.new(posX.Value, posY.Value, posZ.Value), 
					Vector3.new(lookatX.Value, lookatY.Value, lookatZ.Value),
					Vector3.new(upX.Value, upY.Value, upZ.Value)
				)
			end,
			value.X, value.Y, value.Z, 
			value.X + value.LookVector.X, value.Y + value.LookVector.Y, value.Z + value.LookVector.Z, 
			value.UpVector.X, value.UpVector.Y, value.UpVector.Z) --start values

			-- FIXME: position is alright, they're pointing in different directions
			-- FIXED: lookvector and lookat are different, the upvector is still relevant for accuracy
	end

	self:Deleter(function()
		for _, spring in springs do
			spring.Close()
		end
		self:Detach()
	end)

	function self:SetDamping(damping: number)
		self.Damping = damping
		for i=1, #springs do
			springs[i]:SetDamping(damping)
		end
	end

	function self:SetSpeed(speed: number)
		self.Speed = speed
		for i=1, #springs do
			springs[i]:SetSpeed(speed)
		end
	end

	function self:Attach(...)
		Springs[self] = true
	end

	function self:Detach(...)
		Springs[self] = nil
	end

	function self:SetGoal(goal: T)
		self(goal)
	end

	function self:DelayGoal(sec: number, goal: T)
		const prevgoal = self.Goal
		task.delay(sec, function()
			if self.Goal ~= prevgoal then return end
			self(goal)
		end)
	end

	return self
end

--- Returns `true` if `t` is a `Mounted` object and `false` if not
Antera.IsMountedObj = function<S, T>(self: S, t: T): boolean
	return ismounted(t or self)
end

--- Returns `true` if `t` is an `Amplified` and `false` if not
Antera.IsAmplified = function<S, T>(self: S, t: T): boolean
	return isamplified(t or self)
end

--- Returns `true` if `t` is a `SpecialValue` object and `false` if not
Antera.IsSpecial = function<S, T>(self: S, t: T): boolean
	return isspecial(t or self)
end

--[[
	A *client-only* function to support starting the bootstrapper.<br>Waits until the LocalPlayer exists and returns it.
	```luau
	const Player = Antera:YieldForPlayer()
	```
]]
Antera.YieldForPlayer = function<S>(self: S): Player
	Log.ErrorAssert(true, RunService:IsClient(), "Attempt to call Antera:YieldForPlayer() on the server.")
	const Player = Players.LocalPlayer

	if Player then return Player end
	repeat task.wait() until Players.LocalPlayer

	return Players.LocalPlayer
end

--[[
	A *client-only* function to support starting the bootstrapper.<br>Waits until the LocalPlayer's character exists and returns it.<br> Should be used after `Antera:YieldForPlayer()`
	```luau
	const Player = Antera:YieldForPlayer()
	const Char = Antera:YieldForPlayerCharacter()
	```
]]
Antera.YieldForPlayerCharacter = function<S>(self: S): Model
	Log.ErrorAssert(true, RunService:IsClient(), "Attempt to call Antera:YieldForPlayerCharacter() on the server.")
	const Player = Players.LocalPlayer

	if Player.Character then return Player.Character end
	repeat task.wait() until Players.LocalPlayer.Character

	return Players.LocalPlayer.Character :: Model
end

--[[
	Identical to `Antera.New`, except creates a `ScreenGui` under `LocalPlayer.PlayerGui` with the specified `name`,<br>`ResetOnSpawn = false` and `IgnoreGuiInset = true`
	```luau
	Antera:GUI "Main" {
		Button = Antera:New "TextButton" {
			Antera.Child,
			Size = UDim2.fromScale(1, 1)
		}
	}
	```
]]
Antera.GUI = function<S>(container: S, name: string)
	return function<T>(amplified: (T & table) | Amplified<T>)
		const instance = Instance.new("ScreenGui")
		instance.Name = name
		instance.ResetOnSpawn = false
		instance.IgnoreGuiInset = true

		const mounted = Antera.Mount(container, instance, amplified)

		instance.Parent = game:GetService "Players".LocalPlayer.PlayerGui
		return mounted
	end
end

--[[
	*Shortcut for `Antera.Mount(container, Instance.new(instanceClass), amplified)`*
	<br>Creates a new instance of `instanceClass` and mounts `amplified` on it,<br>also applies templates if specified in CONFIG.

	```luau
	Antera:New "Part" {
		Parent = workspace,
		Position = Vector3.new(0, 5, 0),
		Name = "KillBrick",

		Antera:OnEvent "Touched" (function(self, mounted, hit)
			if not hit.Parent or not hit.Parent:FindFirstChild("Humanoid") then return end
			hit.Parent.Humanoid.Health = 0
		end)
	})
	```
]]
Antera.New = function<S, T>(container: S, instanceClass: string)
	return function<T>(amplified: (T & table) | Amplified<T>)
		const instance = Instance.new(instanceClass)

		-- get properties of class
		if not ClassPropertiesMemo[instanceClass] then
			const Properties = ReflectionService:GetPropertiesOfClass(instanceClass)

			ClassPropertiesMemo[instanceClass] = {} :: table
			for _, prop in Properties do
				ClassPropertiesMemo[instanceClass][prop.Name] = prop
			end
		end

		-- template default values
		if Templates[instanceClass] then
			for prop, value in Templates[instanceClass] do
				applyProperty(instance, prop, value)
			end
		end

		return Antera.Mount(container, instance, amplified)
	end
end

--[[
	Creates a new `Mounted` object into the `container`.
	<br>Mounteds represent a connection between the `amplified` and the `instance`,<br>reflecting every key as a property (if valid) and every change made in the `amplified`.

	```luau
	const part = Instance.New("Part")

	Antera:Mount(part, {
		Parent = workspace,
		Position = Vector3.new(0, 5, 0),
		Name = "KillBrick",

		Antera:OnEvent "Touched" (function(self, mounted, hit)
			if not hit.Parent or not hit.Parent:FindFirstChild("Humanoid") then return end
			hit.Parent.Humanoid.Health = 0
		end)
	})
	```
]]
Antera.Mount = function<S, T>(container: S, instance: Instance, amplified: (T & table) | Amplified<T>): Mounted<T>
	Log.ErrorAssert(true, instance, "Antera:Mount received no instance (2nd parameter)")
	Log.ErrorAssert(true, typeof(instance) == "Instance", "Antera:Mount received a non-instance (2nd parameter)")
	local self: Mounted<T>

	-- if a simple table is passed (common case)
	if not isamplified(amplified) then
		amplified = Antera.Amplify(container, amplified)
	end
	amplified = amplified :: Amplified<T>

	local connection = nil :: never

	-- storage for OnEvent connections
	const eventconnections: {[any]: RBXScriptConnection} = {}

	-- memo for OnEvents, not to reconnect each time the events update
	const eventsused: {[any]: SpecialValue<"OnEvent"> | SpecialValue<"OnChange">} = {}

	-- memo to unparent children once the value changes
	const children: {[any]: Instance} = {}

	self = setmetatable(
	{
		Instance = instance,
		Amplified = amplified,
		Destroy = function<A...>(...: A...)
			ref(amplified):Connect(connection, nil)
			for _, conn in eventconnections do
				conn:Disconnect()
			end
			table.clear(eventconnections)
			table.clear(children)

			self.Instance.Parent = nil

			table.clear(self)
			self = nil :: never
		end
	},
	{
		__index = amplified,
		__newindex = amplified,
		__call = function(_, ...)
			return (amplified :: Amplified<T>)(...)
		end
	}
	)

	-- properties

	const ClassName = instance.ClassName

	if not ClassPropertiesMemo[ClassName] then
		const Properties = ReflectionService:GetPropertiesOfClass(ClassName)

		ClassPropertiesMemo[ClassName] = {} :: table
		for _, prop in Properties do
			ClassPropertiesMemo[ClassName][prop.Name] = prop
		end
	end

	if not ClassEventsMemo[ClassName] then
		const Events = ref(ReflectionService):GetEventsOfClass(ClassName) --no luau lsp ill use it

		ClassEventsMemo[ClassName] = {} :: table
		for _, prop in Events do
			ClassEventsMemo[ClassName][prop.Name] = prop
		end
	end

	-- applying

	const function apply(k, v: any)
		-- children instances
		if ismounted(v) and (typeof(k) == "number" or hasValue(v.Amplified(), Antera.Child)) then
			v.Instance.Parent = instance
			children[k] = v.Instance
			-- set the amplified value key instead of direct parent?
		elseif typeof(k) == "number" and typeof(v) == "Instance" then
			v.Parent = instance
			children[k] = v

		-- events
		elseif isspecial(v) and v.__kind == "OnEvent" then
			eventsused[k] = v
			for _, event in v.__prop do
				eventconnections[k] = applyEvent(instance, event, 
					function(...) 
						return v.__fn(self, ...) --amplified is already specified as the first argument, this marks second as the mounted
					end)
			end

		-- onChange
		elseif isspecial(v) and ref(v).__kind == "OnChange" then
			v = ref(v) --typechecking loses its mind after the first elseif

			eventsused[k] = v
			for _, event in v.__prop do
				eventconnections[k] = applyChangeEvent(instance, event, 
					function(...)
						return v.__fn(self, ...) --amplified is already specified as the first argument, this marks second as the mounted
					end)
			end

		-- properties
		else
			applyProperty(instance, k, v)
		end
	end

	connection = function(_, k, v)
		-- incase it was an event
		const updater = rawget(ref(amplified).__Updaters, k)

		if updater ~= eventsused[k] then
			if eventconnections[k] then 
				eventconnections[k]:Disconnect()
				eventconnections[k] = nil
			end
			if isspecial(updater) and (updater.__kind == "OnEvent" or updater.__kind == "OnChange") then
				apply(k, updater)
			end
		end

		if updater == v then return end

		-- incase it was a child
		if children[k] then 
			children[k].Parent = nil
			children[k] = nil
		end

		apply(k, v)
	end

	ref(amplified):Connect(connection)
	for k, v in amplified() do
		connection(nil, k, v)
	end
	for k, v in ref(amplified).__Updaters do
		if amplified()[k] then continue end
		connection(nil, k, v)
	end

	-- misc

	if container ~= Antera then
		table.insert(container, self)
	end

	ref(amplified).Mounted:Fire(self)

	return self
end

--[[
	A SpecialValue that, when included in `Antera.New` with a key, makes the new instance a child.
	<br>This allows you to create child instances with keys to reference them.
	```luau
	Antera:GUI "Main" {
		Button = Antera:New "TextButton" {
			Antera.Child,
			Size = UDim2.fromScale(1, 1)
		}
	}
	```
]]
Antera.Child = newspecial<<"Child">>("Child", "None", "None" :: any)

--[[
	Identical to `Antera.OnSet`, except the function is called immediately.
	<br>Connects a function `fn` to be called whenever the specified ***amplified keys*** in `...` are changed.
	<br>When used with a key, the key is set to the returned value.

	```luau
	Antera:Amplify {
		foo = 10,

		Antera:ForSet "foo" (function(self, mounted)
			print(`foo is now {self.foo}`)
		end)
	})
	```
]]
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

--[[
	Connects a function `fn` to be called whenever the specified ***amplified keys*** in `...` are changed.
	<br>When used with a key, the key is set to the returned value. Originally it's `nil` or the specified `arg`.

	```luau
	Antera:Amplify {
		foo = 10,

		Antera:OnSet "foo" (function(self, mounted)
			print(`foo is now {self.foo}`)
		end)
	})
	```
]]
Antera.OnSet = function<S, T>(container: S, ...: string)
	local prop = { ... }
	return function(fn: (self: Amplified) -> any?, arg: any?): SpecialValue<"OnSet">
		local special = newspecial("OnSet" :: "OnSet", prop, fn :: fn, arg)

		if container ~= Antera then
			table.insert(container, special)
		end

		return special
	end
end

--[[
	Connects a function `fn` to an event or many events specified in `...`, when used in Amplifieds.
	<br>The function is called with the Amplified and the Mounted object passed first, 
	<br>then go the arguments passed by the signal.

	```luau
	Antera:New "Part" {
		Parent = workspace,
		Position = Vector3.new(0, 5, 0),
		Name = "KillBrick",

		Antera:OnEvent "Touched" (function(self, mounted, hit)
			if not hit.Parent or not hit.Parent:FindFirstChild("Humanoid") then return end
			hit.Parent.Humanoid.Health = 0
		end)
	})
	```
]]
Antera.OnEvent = function<S, T>(container: S, ...: string)
	local prop = { ... }
	return function(fn: (self: Amplified, mounted: Mounted, ...any) -> any?, arg: any?): SpecialValue<"OnEvent">
		local special = newspecial("OnEvent" :: "OnEvent", prop, fn :: fn, arg)

		if container ~= Antera then
			table.insert(container, special)
		end

		return special
	end
end

--[[
	Connects a function `fn` to the `GetPropertyChangedSignal(s)` for one
	<br>or multiple properties passed in `...`,  when used in Amplifieds.
	<br>The function is called with the Amplified, the Mounted object and the new value of the property that changed.

	```luau
	Antera:New "Part" {
		Parent = workspace,
		Position = Vector3.new(0, 5, 0),
		Anchored = true,
		Name = "Anchor",

		Antera:OnChange "Anchored" (function(self, mounted, anchored)
			print(`Part is now {anchored and "" or "not"} anchored`)
		end)
	})
	```
]]
Antera.OnChange = function<S, T>(container: S, ...: string)
	local prop = { ... }
	return function(fn: (self: Amplified, mounted: Mounted, ...any) -> any?, arg: any?): SpecialValue<"OnChange">
		local special = newspecial("OnChange" :: "OnChange", prop, fn :: fn, arg)

		if container ~= Antera then
			table.insert(container, special)
		end

		return special
	end
end

--[[
	Amplifies the given `tab` table.
	Amplified tables are tables integrated with reactive functionality<br>and fully suited for UI.

	Amplifieds have a multitude of utilities, such as `Antera.OnSet`, `Antera.Mount` or `Antera.OnEvent`.

	```luau
	const amp = Antera:Amplify {
		foo = 10,
		bar = function(self)
			return self.foo + 10
		end,

		{
			quux = "Hello world!"
		}
	}
	amp.foo = 20
	amp:Update("bar")
	```
]]
Antera.Amplify = function<S, T>(container: S, tab: T)
	const VALUE: table = {}

	local self: any = Anex.State(container, VALUE)

	--[[
		Custom Fire for Amplifieds; this will be removed with an Anex patch
	]]
	const connections = self.Connections
	self.Fire = function<S, K, V>(self: S, key: K, value: V): S
		for _, conn in connections do
			conn(self, key, value)
		end
		return self
	end

	self.Mounted = Anex.Hook<<any>>(container, nil)
	const mounteds: {Mounted} = {}
	self.Mounted:Connect(function(_, mounted)
		mounteds[#mounteds+1] = mounted
	end)

	const UPDATERS: table<any, fn> = {}
	const STATES: table<any, State> = {}
	const ONSETS: table = {}

	const AMPLIFIED = {}

	self.__Updaters = UPDATERS

	const ___nindex = function(_, k: any, v: any)
		if not self then return end
		-- case 3: if v was a state/different state, disconnect it

		const kstate = rawget(STATES, k)
		if kstate and kstate.Connect then
			kstate:Connect(UPDATERS[k])(nil)
			STATES[k] = nil
		end
		UPDATERS[k] = nil

		for _, st in ONSETS do
			st[k] = nil
		end

		const function nestval(key, val: any)
			val = ref(val)
			-- case 1, if v is amplified table then the table value is passed to nestval
			-- case 2, if v is a state
			if isstate(nil, val) then
				VALUE[key] = val()
				STATES[key] = val
				UPDATERS[key] = val 
				--[[ = function<A..., R...>(...: A...): R...
					return nestval(key, val()) :: any
				end]]
				val:Connect(function<A..., R...>(...: A...): R...
					return nestval(key, val()) :: any
				end)

				nestval(key, val())
				return

			-- case 6, if v is a function
			elseif typeof(ref(val)) == "function" then
				UPDATERS[key] = val
				--[[= function<A..., R...>(...: A...): R...
					return nestval(key, val(AMPLIFIED)) :: any
				end]]
				nestval(key, val(AMPLIFIED))
				UPDATERS[key] = val

			-- case 9, if v is a mounted object then its passed forward
			elseif ismounted(val) then
				VALUE[key] = val
				--TODO: add the mounted as the updaters[key]

				self:Fire(key :: any, val)
				if ONSETS[key] then
					for _, j in ONSETS[key] do
						j(AMPLIFIED)
					end
				end

			-- case 4, if v is ForSet is called immediately and via onsets and passes down a value
			-- onevent and onchange can only be handled by alloy.mount so they are passed forwards
			elseif isspecial(val) and val.__kind == "ForSet" then
				const fn = function<A..., R...>(...: A...): R...
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
				const fn = function<A..., R...>(...: A...): R...
					return nestval(key, val.__fn(AMPLIFIED)) :: any
				end

				for _, prop in pairs(val.__prop) do
					ONSETS[prop] = ONSETS[prop] or {}
					ONSETS[prop][key] = fn
				end

				-- turning OnSet into effect:
				UPDATERS[key] = val.__fn
				nestval(key, val.__arg) --__arg implementation (value after __fn)
				UPDATERS[key] = val.__fn --amp.val()

			-- case 10, OnEvent and OnChange require a new fn for Mount (this is a hack)
			elseif isspecial(val) and (ref(val).__kind == "OnEvent" or ref(val).__kind == "OnChange") then
				val = ref(val) --typechecking loses its mind again

				nestval(key, val.__arg)

				-- 2 different functions!
				const fn = val.__fn

				UPDATERS[key] = val --fn
				val.__fn = function<A..., R...>(...: A...): R...
					return nestval(key, fn(AMPLIFIED, ...)) :: any --uses ...
				end

			-- case 7, v is a table (nestval each key, value pair)
			elseif not isspecial(ref(val)) and typeof(val) == "table" then
				for k1, v1 in pairs(val) do
					if typeof(k1) == "number" and k1 <= CONFIG.AmplifiedMergeNonkeyLimit then
						k1 = nextnumerickey(VALUE)
					end
					nestval(k1, v1)
				end

			-- case 5, if its anything else: instance, number, vector3, etc.
			-- Antera.OnEvent, Antera.OnChange go here
			elseif self and VALUE then
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
		const updater = UPDATERS[key]
		return if updater and typeof(updater) == "function" then ___nindex(nil, key, UPDATERS[key]())
			elseif updater and typeof(updater) == "table" then ___nindex(nil, key, updater) else nil
	end

	self.NonKey = function(self: Amplified<T>, value: any): any
		const key = nextnumerickey(VALUE)
		___nindex(nil, key, value)
		return key
	end

	self.Destroy = function(...)
		for _, mounted in mounteds do
			if not mounted.Amplified then continue end
			mounted:Destroy()
		end

		--[[for k, v in VALUE do
			___nindex(nil, k, nil)
		end]] --not sure if this is needed: children and events are already disconnected by killing mounteds

		task.wait()
		table.clear(self)
		self = nil :: never
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

	--[[
		the AMPLIFIED itself is an empty table {}; this is done to trick __newindex to be called for every key and value.
		indexing AMPLIFIED will index self, which is a STATE merged with functions for Amplifieds.
		newindexing AMPLIFIED will call ___nindex, a big function which will in the end update VALUE, the actual 
		value of the STATE and the amplified.
		if the index is not in self, the STATE, then STATES are indexed.
		STATES is also the VALUE table (for keys=values) except the values are necessarily states, this is left after
		___nindex when the value is a state. 
		STATES are needed to acquire states when indexing the amplified: Amp.SomeState().
		in turn, the actual values of states are in VALUE, gotten in the same way as a STATE, via __call: Amp().SomeState.
		if the value wasn't found in STATES, UPDATERS are indexed.
		UPDATERS is the table of functions, serving the same purpose as STATES.
		via UPDATERS you can reference functions added to the amplified: Amp.SomeFunc() or their actual value from VALUE: Amp().SomeFunc.
		and finally, if the key isn't in UPDATERS, VALUE is indexed; this is for some trivial keys like `Key = 10`

		___nindex changes:
		- 1. trivial values are set normally
		- 2. functions are called, their return value is set normally
		- 3. states or amplified tables are set in STATES, their actual value is set normally, and they are connected to set normally
		- 4. tables (including when amplifieds are set normally) set normally all of their key-value pairs (they are "merged")
		- 5. OnSet and ForSet are set in ONSETS to be updated when their specified keys are set normally

		CAVEATS AND IMPROVEMENTS:
		- merge STATES and UPDATERS because they serve one purpose
		- allow tables into UPDATERS
		- Antera.NoMerge special value to be included in tables to avoid merging
		- Antera.Nil special value for merged table keys since nil values just aren't merged
		- Support for hooks, this was missed because Anex lacks Anex:IsHook()
		- Support for :Setter, this will modify keys and values set
		- Antera.OnMount for values that need the instance
		- Antera.Ignore for functions not to be called, tables not to be merged?
		- OnSet and ForSet should be called with the key that changed and value of it
	]]

	local next__order: any = {} --[number]: table -- various tables of the next order within the same order

	-- reevaluating given values in the initial table
	for k, v in pairs(tab) do
		-- to avoid overriding nonkeys (this is needed even here because we don't know the order):
		if typeof(k) == "number" and k <= CONFIG.AmplifiedMergeNonkeyLimit then
			k = nextnumerickey(VALUE) + #next__order
		end

		-- if v is a specialvalue, it's moved an order higher with a specific tag in the order table
		if isspecial(v) then
			next__order[#next__order + 1] = { k, v, __fromprev = true } --special values are automatically one order higher
			continue
		-- if it's just a table, then it's an order table and it should be moved up
		elseif typeof(v) == "table" and not isstate(nil, v) and not ismounted(v :: any) then
			next__order[#next__order + 1] = v
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
				-- to avoid overriding nonkeys:
				if typeof(k) == "number" and k <= CONFIG.AmplifiedMergeNonkeyLimit then
					k = nextnumerickey(VALUE) + #next__order
				end

				if isspecial(v) then
					next__order[#next__order + 1] = { k, v, __fromprev = true } --special values are automatically one order higher
					continue
				elseif typeof(v) == "table" and not isstate(nil, v) and not ismounted(v :: any) then
					next__order[#next__order + 1] = v
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

return table.freeze(Antera)
