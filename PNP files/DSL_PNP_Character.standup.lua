-- Character Standup Script
-- 10/27/2014
-- v4.00a
--

dslpnp.character.standup = dslpnp.character.standup or {}
dslpnp.character.standup.configs = dslpnp.character.standup.configs or {}

dslpnp.character.standup.help = [[
    Character Script : Standup Plugin

    This script checks for the common cases where you get knocked down, and tries to have
    you stand up.
]]

local defaults = {
	tilde = true,
}

local function make_triggers()
	local trigger_text
	if not dslpnp.triggers.exists("Standup Trigger 1") then
		trigger_text = [[^(.+) knocking you senseless.$]]
		dslpnp.triggers.register("Standup Trigger 1", "regex", trigger_text, [[raiseEvent("onKnockdown")]],true)
	end
end

local function toggle(setVal)
	dslpnp.character.standup.Active = dslpnp.toggle("character : standup", dslpnp.character.standup.Active, setVal)
end

local function config()
	local configs = dslpnp.config.character and dslpnp.config.character.standup or {}
	dslpnp.character.standup.configs = table.update(defaults, configs)
	make_aliases()
	make_triggers()
	raiseEvent("onToggle","character.standup","on")
end

function dslpnp.character.standup.standup()
  if dslpnp.character.standup.configs.tilde then send("~") end
  send("stand")
end

function dslpnp.character.standup.eventHandler(event, ...)
	if event == "onKnockdown" and dslpnp.character.standup.Active then
		print(" Kocked down!!")
		dslpnp.character.standup.standup()
	elseif event == "onToggle" and (arg[1] == "standup" or arg[1] == "character.standup") then
		toggle(arg[2])
	elseif event == "onConfig" and arg[1] == "character.standup" then
		config()
	end
end

registerAnonymousEventHandler("onKnockdown", "dslpnp.character.standup.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.character.disarm.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.character.disarm.eventHandler")
