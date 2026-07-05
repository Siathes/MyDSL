-- History Script
-- 4/18/2014
-- v4.01c
--

dslpnp.history = dslpnp.history or {}

-- Use the following.history to help you set up helpfiles for your script.
-- dslpnp.history.help.topic will allow you to expand to additional, specific
-- topics for various aliases, triggers, timers or functions that you feel need
-- explaining. Be sure to reference your help topics in the "root" helpfile, provided
-- for as dslpnp.history.help[1]
dslpnp.history.help = dslpnp.history.help or {}
dslpnp.history.help[1] = [[
    History Script

    The history script is designed to be a user-input window. With easy-to-use functionality,
    it will allow players to capture lines from the MUD that they want to send to a window
    so that they don't miss important things in the fast-flowing text of the game. Some
    examples include, but are not limited to, spell effects landing on raid monsters (weaken,
    poison, plague), skills/spells coming off of cooldown or spells falling. Things that
    you don't want to miss. All of these things and more can be done with the history script's
    window.
]]

local defaults = {
    fontSize = 10,
	show_border = true,
    show_time = true,
    line_spacing = 1,
    real_time = false,
    military_time = false
}

local function lineSpace()
    for i=1,dslpnp.history.configs.line_spacing do
        echo("history_list","\n")
        echo(dslpnp.history.buffer,"\n")
    end
end

local function getTime()
	local time = " "
	if dslpnp.history.configs.show_time then
		if not dslpnp.history.configs.real_time then
			time = "{W " .. dslpnp.prompt.time .. ">{x " .. time
		elseif not dslpnp.history.configs.military_time then
			time = "{W " .. os.date("%I:%M%p") .. ">{x " .. time
		else
			time = "{W " .. os.date("%H:%M") .. ">{x " .. time
		end
	end
	return time
end

function dslpnp.history.write(text)
	local time = getTime()
	text = time .. text
    lineSpace()
    fprint("history_list",text,false)
    fprint(dslpnp.history.buffer,text,false)
end

function dslpnp.history.copy()
	-- added to prefix lines with time based on show_time config setting
	local time = getTime()
    selectCurrentLine()
    copy()
    lineSpace()
    fprint("history_list",time,false)
    fprint(dslpnp.history.buffer,time,false)
    appendBuffer("history_list")
    appendBuffer(dslpnp.history.buffer)
end

local function toggle(setVal)
    dslpnp.history.Active = dslpnp.toggle("history",dslpnp.history.Active, setVal)
    if dslpnp.history.Active then
		showWindow("history_tab")
	else
		hideWindow("history_list")
		hideWindow("history_label")
		hideWindow("history_tab")
    end
end

local function adjust_windows()
	local window, buffer, line, moved, text
	dslpnp.support.adjustWordWrap("history_list", dslpnp.history.configs.fontSize)
	buffer = dslpnp.history.buffer
	line = 0
	clearWindow("history_list")
	moved = moveCursor(buffer,1,line)
	while moved do
		selectCurrentLine(buffer)
		copy(buffer)
		line = line + 1
		moved = moveCursor(buffer,1,line)
		appendBuffer("history_list")
	end
end

local function make_win(window_name,x,y,width,height,origin)
    createMiniConsole("history_list",0,0,0,0)
	createLabel("history_label",0,0,0,0,1)
	windowManager.add("history_list","miniConsole",x,y,width,height,origin)
	windowManager.add("history_label","label",x,y,width,height,origin)
	setBackgroundColor("history_list",0,0,0,255)
	setMiniConsoleFontSize("history_list",dslpnp.history.configs.fontSize)
	setLabelStyleSheet("history_label",[[
		border: 2px solid white;
		border-radius: 5px;
		background-color: rgba(0,0,0,0)]])
	setLabelClickCallback("history_label","raiseEvent","onReveal","history")
	hideWindow("history_list")
	hideWindow("history_label")

    dslpnp.history.buffer = "history buffer"
	createBuffer(dslpnp.history.buffer)
    setWindowWrap(dslpnp.history.buffer,1000)
	createLabel("history_tab",0,0,0,0,1)
	setLabelClickCallback("history_tab","raiseEvent","onDisplay","history")
	dslpnp.sidebar.maketab(window_name,"history_tab","History")
    dslpnp.support.adjustWordWrap("history_list", windowManager.getValue("history_list","width"), dslpnp.history.configs.fontSize)
end

local function config(window_name,x,y,width,height,origin)
    dslpnp.history.configs = dslpnp.config.history or {}
	dslpnp.history.configs = table.update(defaults,dslpnp.history.configs)

    make_win(window_name,x,y,width,height,origin)
    raiseEvent("onToggle","history","on")
end

local function onReveal()
	hideWindow("history_label")
end

local function onDisplay()
	dslpnp.sidebar.display("history", {"history_list","history_label"}, "history_tab")
end

local function displayWindow(x,y,width,height)
	windowManager.move("history_list",x,y)
	windowManager.move("history_label",x,y)
	windowManager.resize("history_list",width,height)
	windowManager.resize("history_label",width,height)
	showWindow("history_list")
	if dslpnp.history.configs.show_border then
		showWindow("history_label")
	end
	adjust_windows()
end

function dslpnp.history.eventHandler(event,...)
    if event == "onToggle" and arg[1] == "history" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "history" then
        config(arg[2], arg[3], arg[4], arg[5], arg[6], arg[7])
    elseif event == "onDisplay" and arg[1] == "history" and dslpnp.history.Active then
        onDisplay()
	elseif event == "onReveal" and arg[1] == "history" and dslpnp.history.Active then
		onReveal()
	elseif event == "sysWindowResizeEvent" and dslpnp.history.Active then
		adjust_windows()
	elseif event == "displayWindow" and arg[1] == "history" and dslpnp.history.Active then
		displayWindow(arg[2],arg[3],arg[4],arg[5])
    end
end

registerAnonymousEventHandler("displayWindow", "dslpnp.history.eventHandler")
registerAnonymousEventHandler("sysWindowResizeEvent", "dslpnp.history.eventHandler")
registerAnonymousEventHandler("onReveal", "dslpnp.history.eventHandler")
registerAnonymousEventHandler("onDisplay", "dslpnp.history.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.history.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.history.eventHandler")
