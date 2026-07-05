-- Statusbar Script : Posn Plugin
-- 6/04/2014
-- v4.03d
--

-- need triggers to catch position change from skills like headbutt and roundhouse, and mounts dying.

dslpnp.statusbar.posn = dslpnp.statusbar.posn or {}

dslpnp.statusbar.posn.help = [[
    Statusbar Script : Posn Plugin

    This plugin provides functionality for the Statusbar Script to display
    the current position of one's character. Valid positions are: sitting,
    resting, standing, and sleeping. Flying is covered by a value already
    found in the prompt.

    Use this in set prompt or set display to see the value: &p
]]

function dslpnp.statusbar.posn.set_posn(posn, from_score)
    posn = string.title(posn)
    if from_score and posn == "Stand" then
    	if dslpnp.prompt.position == "Mounted" then
    		posn = "Mount"
    	end
    end
    if posn ~= "Mount" and posn ~= "Dismount" then
        posn = posn .. ((posn == "Sit" and "t") or "") .. "ing"
    elseif posn == "Dismount" then
        posn = "Standing"
    else
        posn = posn .. "ed"
    end
    dslpnp.prompt.position = posn
	raiseEvent("onPosnChange",string.lower(posn))
end

local function toggle(setVal)
    dslpnp.statusbar.posn.Active = dslpnp.toggle("statusbar : posn",dslpnp.statusbar.posn.Active, setVal)
end

local function make_triggers()
	if not dslpnp.triggers.exists("Position Capture Trigger") then
        dslpnp.triggers.register("Position Capture Trigger","regex",[[^You (?:go to )?(stand|rest|sit|sleep|mount|dismount)]],[[dslpnp.statusbar.posn.set_posn(matches[2])]],true)
    end
    if not dslpnp.triggers.exists("Waking Position Capture Trigger") then
        dslpnp.triggers.register("Waking Position Capture Trigger","regex",[[^You wake (?:up )?and (?:start )?(stand|sit|rest)]],[[dslpnp.statusbar.posn.set_posn(matches[2])]],true)
    end
    if not dslpnp.triggers.exists("Already Position Trigger") then
        dslpnp.triggers.register("Already Position Trigger","regex",[[^You are already (stand|rest|sleep|sit)t?ing(?: down)?\.]],[[dslpnp.statusbar.posn.set_posn(matches[2])]],true)
    end
	if not dslpnp.triggers.exists("Score Position Trigger") then
		dslpnp.triggers.register("Score Position Trigger","regex",[[^CON\s*:\s*\d+\(\d+\)\s*Pos\'n: (\w+?)ing]],[[dslpnp.statusbar.posn.set_posn(matches[2],true)]],true)
	end
	if not dslpnp.triggers.exists("Landing Capture Trigger") then
		dslpnp.triggers.register("Landing Capture Trigger","regex",[[^You (?:slowly float|float gently) to the ground\.$]],[[dslpnp.statusbar.posn.set_posn("stand",false)]],true)
	end
	if not dslpnp.triggers.exists("Stop Resting Trigger") then
		dslpnp.triggers.register("Stop Resting Trigger","regex",[[^You stop resting\.$]],[[dslpnp.statusbar.posn.set_posn("sit",false)]],true)
	end
end

local function config()
	if not table.contains(dslpnp.statusbar.data_vals, "&p") then
		table.insert(dslpnp.statusbar.data_vals,{"&p", "position"})
		dslpnp.prompt.position = ""
	end
	make_triggers()
    raiseEvent("onToggle","statusbar.posn","on")
end

function dslpnp.statusbar.posn.eventHandler(event,...)
    if event == "onToggle" and arg[1] == "statusbar.posn" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "statusbar.posn" then
        config()
    elseif event == "updatePrompt" then
    	if dslpnp.prompt.flying ~= "" then dslpnp.statusbar.posn.set_posn("Fly") end
    end
end

registerAnonymousEventHandler("onToggle", "dslpnp.statusbar.posn.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.statusbar.posn.eventHandler")
registerAnonymousEventHandler("updatePrompt", "dslpnp.statusbar.posn.eventHandler")
