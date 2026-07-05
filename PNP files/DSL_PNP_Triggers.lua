-- Trigger Management Script
-- 3/24/2014
-- v4.00b
--

-- Note, this is designed to handle "temporary" triggers created by code.
-- These triggers may last the entire session, or only a brief while, depending
-- on how they are used.

-- For a later time: expand to accomodate tempColorTrigger, tempLineTrigger.

-- Updated to add tempComplexRegexTrigger. Script still in testing, proper
-- function is not guaranteed.

dslpnp.triggers = dslpnp.triggers or {}
dslpnp.triggers.__index = dslpnp.triggers
dslpnp.triggers.list = dslpnp.triggers.list or {}

dslpnp.triggers.help = [[
	dslpnp.triggers.register(name, style, pattern, code, active, owner) - returns trigger object
		Valid trigger styles: "substring", "regex", "exact match", "begin of line"
		Returned trigger can use the following methods:
			trig = dslpnp.triggers.register(name, style, pattern, code, active, owner)
			trig:disable()
			trig:enable()
			trig:kill()

	dslpnp.triggers.retrieve(name) - returns a trigger object matching the name given
	dslpnp.triggers.disable(name)
	dslpnp.triggers.enable(name)
	dslpnp.triggers.kill(name)
	dslpnp.triggers.exists(name)

	raiseEvent("resetTriggers") - this event will kill all current triggers
]]

--local trigger_list = trigger_list or {}

-- General Trigger Functions / Methods
local trigger_styles = {"subtstring","regex","exact match","begin of line","complex"}
local trigger_functions = {
	substring = tempTrigger,
	regex = tempRegexTrigger,
	complex = tempComplexRegexTrigger,
	["exact match"] = tempExactMatchTrigger,
	["begin of line"] = tempBeginOfLineTrigger,
	}

local function getNextID()
	local list = dslpnp.triggers.list or {}
	local id
	for k,v in ipairs(list) do
		if k ~= v.name then
			id = k
			break
		end
	end
	id = id or (#list + 1)
	return id
end

function dslpnp.triggers.register(name, style, pattern, code, active, owner, ...)
	if not table.contains(trigger_styles,style) then
		error("Invalid trigger style: Must be substring, regex, complex, exact match, or begin of line",2)
	end
	if not name then
		name = getNextID()
	end
	if dslpnp.triggers.list[name] then
		error("Trigger name already exists.",2)
	end
	if type(pattern) == "table" and style ~= "complex" then
		pattern = pattern[1]
	elseif style == "complex" then
		pattern = {pattern}
	end
	dslpnp.triggers.list[name] = {name = name, style = style, pattern = pattern, code = code, owner = owner, active = active, is_trigger = true}
	if style == "complex" then
		for k=1,10 do
			if not arg[k] then arg[k] = 0 end
		end
		arg.n = 10
		dslpnp.triggers.list[name].args = arg
	end
	if active then
		if style ~= "complex" then
			dslpnp.triggers.list[name].id = trigger_functions[style](pattern, code)
		else
			dslpnp.triggers.list[name].id = trigger_functions[style](name, pattern[1], code, unpack(dslpnp.triggers.list[name].args))
			for k=2,#pattern do
				dslpnp.triggers.addPattern(name,pattern[k])
			end
		end
	end

	local trigger = dslpnp.triggers.list[name]
	setmetatable(trigger,dslpnp.triggers)
	return trigger
end

function dslpnp.triggers.addPattern(name, pattern)
	local trigger
	if name.is_trigger then
		name = name.name
	end
	trigger = dslpnp.triggers.list[name]
	if (not trigger) or trigger.style ~= "complex" then
		error("No such complex trigger exists.",2)
	end
	if (not pattern) or pattern == "" then
		error("Invalid pattern.",2)
	end
	if not table.contains(trigger.pattern,pattern) then
		table.insert(trigger.pattern,pattern)
	end
	trigger.id = trigger_functions["complex"](trigger.name, pattern, trigger.code, unpack(trigger.args))
end

function dslpnp.triggers.disable(name)
	local trigger
	if name.is_trigger then
		name = name.name
	end
	trigger = dslpnp.triggers.list[name]
	if trigger then
		trigger.active = false
		if trigger.id then
			disableTrigger(trigger.id)
		end
	end
end

function dslpnp.triggers.enable(name)
	local trigger
	if name.is_trigger then
		name = name.name
	end
	if not dslpnp.triggers.list[name] then
		error("No such trigger exists.",2)
	end
	trigger = dslpnp.triggers.list[name]
	trigger.active = true
	if not trigger.id then
		if trigger.style ~= "complex" then
			trigger.id = trigger_functions[trigger.style](trigger.pattern, trigger.code)
		else
			trigger.id = trigger_functions[trigger.style](name, trigger.pattern[1], trigger.code, unpack(trigger.args))
			for k=2,#trigger.pattern do
				dslpnp.triggers.addPattern(name,trigger.pattern[k])
			end
		end
	else
		enableTrigger(trigger.id)
	end
end

function dslpnp.triggers.kill(name)
	if name.is_trigger then
		name = name.name
	end
	if dslpnp.triggers.list[name] and dslpnp.triggers.list[name].id then
		killTrigger(dslpnp.triggers.list[name].id)
	end
	dslpnp.triggers.list[name] = nil
end

function dslpnp.triggers.retrieve(name)
	local trigger
	trigger = dslpnp.triggers.list[name]
	if trigger then
		setmetatable(trigger,dslpnp.triggers)
	end
	return trigger
end

function dslpnp.triggers.exists(name)
	if dslpnp.triggers.list[name] then
		return true
	else
		return false
	end
end

local function reset()
	for k, v in pairs(dslpnp.triggers.list) do
		if v.id then
			killTrigger(v.id)
		end
		dslpnp.triggers.list[k] = nil
	end
end

function dslpnp.triggers.eventHandler(event, ...)
	if event == "resetTriggers" then
		reset()
	end
end

registerAnonymousEventHandler("resetTriggers","dslpnp.triggers.eventHandler")
