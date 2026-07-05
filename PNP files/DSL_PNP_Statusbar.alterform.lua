-- Statusbar Script : Alterform Plugin
-- 4/08/2014
-- v4.00c
--

-- need triggers to catch position change from skills like headbutt and roundhouse, and mounts dying.

dslpnp.statusbar.alterform = dslpnp.statusbar.alterform or {}

dslpnp.statusbar.alterform.help = [[
    Statusbar Script : Alterform Plugin

    This plugin provides functionality for the Statusbar Script to display
    the current time remaining on alterform for dragons.

    Use this in set prompt or set display to see the value: &a
]]

local function get_duration()
	local _, duration = (dslpnp.affects and dslpnp.affects.findAffect("alterform")) or nil
	dslpnp.prompt.alterform = duration or ""
end

local function toggle(setVal)
    dslpnp.statusbar.alterform.Active = dslpnp.toggle("statusbar : alterform",dslpnp.statusbar.alterform.Active, setVal)
end

local function config()
	if not table.contains(dslpnp.statusbar.data_vals, "&a") then
		table.insert(dslpnp.statusbar.data_vals,{"&a", "alterform"})
		dslpnp.prompt.alterform = ""
	end
    raiseEvent("onToggle","statusbar.alterform","on")
end

function dslpnp.statusbar.alterform.eventHandler(event,...)
    if event == "onToggle" and arg[1] == "statusbar.alterform" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "statusbar.alterform" then
        config()
    elseif event == "updatePrompt" then
    	get_duration()
    end
end

registerAnonymousEventHandler("onToggle", "dslpnp.statusbar.alterform.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.statusbar.alterform.eventHandler")
registerAnonymousEventHandler("updatePrompt", "dslpnp.statusbar.alterform.eventHandler")
