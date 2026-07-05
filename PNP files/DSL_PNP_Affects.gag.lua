-- Affects Gag Script
-- 6/29/2014
-- v4.01a
--

-- Added comments at top for easy identification of the script and for version purposes (if someone has a script with a previous date, they know theirs is out of date)
-- You may also want to attribute this script to yourself up at the top, and provide any instructions or description there for other people

dslpnp.affects.gag = dslpnp.affects.gag or {}

dslpnp.affects.gag.help = [[
Affects Script : Gag Plugin

The gag plugin for the affects script will auto-update a player's affects tracking by
running a gagged affects send whenever they have a spell cast on them as recognized by
the spell list in the echoes plugin.
]]

local gag = false
local affCap = false

local function toggle(setVal)
	dslpnp.affects.gag.Active = dslpnp.toggle("affects : gag",dslpnp.affects.gag.Active, setVal)
end

local function config()
	local pattern = [[^\s+: modifies [\w\s'\-]+ by \-?\d+ for \d+ cycles]]
	if not dslpnp.triggers.exists("Affects Gag Trigger") then
		dslpnp.triggers.register("Affects Gag Trigger","regex",pattern,[[deleteLine()]],false)
	end
	raiseEvent("onToggle","affects.gag","on")
end

function dslpnp.affects.gag.eventHandler(event,...)
	if event == "onBlank" and gag and dslpnp.affects.gag.Active then
		gag = false
		affCap = false
		if dslpnp.triggers.exists("Affects Gag Trigger") then
			dslpnp.triggers.disable("Affects Gag Trigger")
		end
	elseif event == "onPrompt" and gag and dslpnp.affects.gag.Active then
		gag = false
		affCap = false
		if dslpnp.triggers.exists("Affects Gag Trigger") then
			dslpnp.triggers.disable("Affects Gag Trigger")
		end
	elseif event == "affectAdd" and dslpnp.affects.gag.Active then
		if not arg[2] then
			if not affCap then
				send("affects",false)
			end
			affCap = true
		elseif gag and arg[2] then
			deleteLine()
		end
	elseif event == "onAffect" and affCap and dslpnp.affects.gag.Active then
		gag = true
		deleteLine()
		if dslpnp.triggers.exists("Affects Gag Trigger") then
			dslpnp.triggers.enable("Affects Gag Trigger")
		end
	elseif event == "onToggle" and arg[1] == "affects.gag" then
		toggle(arg[2])
	elseif event == "onConfig" and arg[1] == "affects.gag" then
		config()
	end
end

registerAnonymousEventHandler("onToggle", "dslpnp.affects.gag.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.affects.gag.eventHandler")
registerAnonymousEventHandler("onBlank", "dslpnp.affects.gag.eventHandler")
registerAnonymousEventHandler("onPrompt", "dslpnp.affects.gag.eventHandler")
registerAnonymousEventHandler("affectAdd","dslpnp.affects.gag.eventHandler")
registerAnonymousEventHandler("onAffect", "dslpnp.affects.gag.eventHandler")
