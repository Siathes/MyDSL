-- Alias Management Script
-- 3/24/2014
-- v4.00b
--

-- Note, this is designed to handle "temporary" aliases created by code.
-- These aliases may last the entire session, or only a brief while, depending
-- on how they are used.

dslpnp.aliases = dslpnp.aliases or {}
dslpnp.aliases.__index = dslpnp.aliases
dslpnp.aliases.list = dslpnp.aliases.list or {}

dslpnp.aliases.help = [[
	dslpnp.aliases.register(name, pattern, code, active, owner) - returns alias object
		Returned alias can use the following methods:
			alias = dslpnp.aliases.register(name, pattern, code, active, owner)
			alias:disable()
			alias:enable()
			alias:kill()

	dslpnp.aliases.retrieve(name) - returns a alias object matching the name given
	dslpnp.aliases.disable(name)
	dslpnp.aliases.enable(name)
	dslpnp.aliases.kill(name)
	dslpnp.aliases.exists(name)

	raiseEvent("resetAliases") - this event will kill all current aliases
]]

--local alias_list = alias_list or {}

-- General alias Functions / Methods
function dslpnp.aliases.register(name, pattern, code, active, owner)
	if dslpnp.aliases.list[name] then
		error("alias name already exists.",2)
	end
	dslpnp.aliases.list[name] = {pattern = pattern, code = code, owner = owner, active = active, is_alias = true}
	if active then
		dslpnp.aliases.list[name].id = tempAlias(pattern, code)
	end

	local alias = dslpnp.aliases.list[name]
	setmetatable(alias,dslpnp.aliases)
	return alias
end

function dslpnp.aliases.disable(name)
	local alias
	if name.is_alias then
		name = name.name
	end
	if not dslpnp.aliases.list[name] then
		error("No such alias exists.",2)
	end
	alias = dslpnp.aliases.list[name]
	alias.active = false
	if alias.id then
		disableAlias(dslpnp.aliases.list[name].id)
	end
end

function dslpnp.aliases.enable(name)
	local alias
	if name.is_alias then
		name = name.name
	end
	if not dslpnp.aliases.list[name] then
		error("No such alias exists.",2)
	end
	alias = dslpnp.aliases.list[name]
	alias.active = true
	if not alias.id then
		alias.id = tempAlias(alias.pattern, alias.code)
	else
		enableAlias(alias.id)
	end
end

function dslpnp.aliases.kill(name)
	if name.is_alias then
		name = name.name
	end
	if dslpnp.aliases.list[name] and dslpnp.aliases.list[name].id then
		killAlias(dslpnp.aliases.list[name].id)
		dslpnp.aliases.list[name] = nil
	end
end

function dslpnp.aliases.retrieve(name)
	local alias
	alias = dslpnp.aliases.list[name]
	if alias then
		setmetatable(alias,dslpnp.aliases)
	end
	return alias
end

function dslpnp.aliases.exists(name)
	if dslpnp.aliases.list[name] then
		return true
	else
		return false
	end
end

local function reset()
	for k, v in pairs(dslpnp.aliases.list) do
		if v.id then
			killAlias(v.id)
		end
		dslpnp.aliases.list[k] = nil
	end
end

function dslpnp.aliases.eventHandler(event,...)
	if event == "resetAliases" then
		reset()
	end
end

registerAnonymousEventHandler("resetAliases","dslpnp.aliases.eventHandler")
