-- Chat Script
-- 9/23/2015
-- v4.02e
-- Type "toggle chat" to disable or enable this script.
--
-- Use the following code to put a chat message in the chat windows:
-- raiseEvent("onChat", line_text, channel, text)
--
-- Chat windows may be switched between by clicking on the tabs.
--

dslpnp.chat = dslpnp.chat or {}
dslpnp.chat.tabs = dslpnp.chat.tabs or {}
dslpnp.chat.windows = dslpnp.chat.windows or {}
dslpnp.chat.buffers = dslpnp.chat.buffers or {}
dslpnp.chat.configs = dslpnp.chat.configs or {}

dslpnp.chat.help = dslpnp.chat.help or {}
dslpnp.chat.help[1] = [[
Chat Script

Chat script provides functionality, along with the sidebar script, to copy various
lines from the main window related to chat (kingdom/clan, says, tells, etc...) to a
side window which can be easier to look through in order to find something that
someone might have said.
]]

local channels_list = {
    {"All", "all"},
    {"Public", "yell", "shout", "clan gossip", "gossip"},
    {"Clan", "ooc clan", "ooc kingdom", "clan", "kingdom"},
    {"Private", "group tell", "say", "tell", "whisper"}
}
local defaults = {
    fontSize = 8,
    channels = channels_list,
    show_border = false,
    gag = {},
}

local channel_patterns = {
    ["say"] = "[sS]ay",
    ["whisper"] = "[wW]hisper",
    ["group tell"] = "[tT]ell[s]? [tT]he [gG]roup",
    ["tell"] = "[tT]ell",
    ["yell"] = "[yY]ell",
    ["shout"] = "[sS]hout",
    ["clan gossip"] = "[cC]lan [gG]ossip",
    ["gossip"] = "[gG]ossip",
    ["ask"] = "ask",
    ["answer"] = "answer",
    ["bloodbath"] = "[bB]loodbath",
    ["auction"] = "auction",
    ["quest"] = "[qQ]uest",
    ["ooc kingdom"] = "[oO][oO][cC] [kK]ingdom",
    ["kingdom"] = "[kK]ingdom",
    ["ooc clan"] = "[oO][oO][cC] [cC]lan",
    ["clan"] = "[cC]lan",
    ["ooc"] = "OOC",
    ["grats"] = "[gG]rats",
    ["radio"] = "[rR]adio",
    ["thaxanos"] = "[tT]haxanos",
    ["shalonesti"] = "[sS]halonesti",
    ["conclave"] = "[cC]onclave",
    ["newbie"] = "Newbie",
    ["pray"] = "pray",
    ["broadcast"] = "\[BROADCAST [\w\s\']+\]",
    ["imm"] = "imm",
}

local function process_text(cur_line, channel)
    assert(type(cur_line) == "string", "Invalid current line!")
    assert(type(channel) == "string", "Invalid channel!")
    channel = string.lower(channel)
    if channel == "kingdoms" then channel = "kingdom" end
    if string.find(channel,"tell") then
        local target = rex.match(cur_line,[[^\a?(?:\((?:An )?Imm\))?[\w\'\s]+? tells? ([\w\s]+) '.*']])
        if target == "the group" then channel = "group tell" else channel = "tell" end
    end
    selectCurrentLine()
    copy()
    for k,v in ipairs(dslpnp.chat.configs.channels) do
        if table.contains(v,channel) or table.contains(v,"all") then
            appendBuffer(dslpnp.chat.windows[k])
            appendBuffer(dslpnp.chat.buffers[k])
        end
    end
    if table.contains(dslpnp.chat.configs.gag, channel) then
        deleteLine()
    end
end

local function adjust_windows()
    local window, buffer, line, moved, text
    for k,v in ipairs(dslpnp.chat.windows) do
        dslpnp.support.adjustWordWrap(v, dslpnp.chat.configs.fontSize)
        buffer = dslpnp.chat.buffers[k]
        line = 0
        clearWindow(v)
        moved = moveCursor(buffer,1,line)
        while moved do
            selectCurrentLine(buffer)
            copy(buffer)
            line = line + 1
            moved = moveCursor(buffer,1,line)
            appendBuffer(v)
        end
    end
end

local function make_triggers(channels_list)
    local trigger_text = ""
    for k,v in ipairs(channels_list) do
        for k2 = 2,#v do
            if v[k2] ~= "all" then
                if channel_patterns[v[k2]] then
                    trigger_text = trigger_text .. channel_patterns[v[k2]] .. "|"
                end
            end
        end
    end
    trigger_text = string.sub(trigger_text,1,#trigger_text - 1)
    trigger_text = [[^\a?(?:[\[\(][\w\s@]+[\]\)]\s*)*[\w\'\s]+?[\[\(]?(]] .. trigger_text .. [[)[\]\)]?[\w\s\(\)\':]*? \'(.*)\'$]]
    trigger_text = {trigger_text}
    if table.contains(channels_list,"thaxanos") then
        table.insert(trigger_text, [[^\(([tT]haxanos)\)[\w\s\(\):]*? \'(.*)\'$]])
    end
    if table.contains(channels_list,"shalonesti") then
        table.insert(trigger_text, [[^\(([sS]halonesti)\)[\w\s\(\):]*? \'(.*)\'$]])
    end
    if table.contains(channels_list,"kingdom") then
        table.insert(trigger_text, [[^([kK]ingdom[s]?)[\w\s\(\):]*? \'(.*)\'$]])
    end
    if table.contains(channels_list,"conclave") then
        table.insert(trigger_text, [[^\(([cC]onclave)\)[\w\s\(\):]*? \'(.*)\'$]])
    end
    if table.contains(channels_list,"broadcast") then
        table.insert(trigger_text, [[^\[(BROADCAST) [\w\s\']+\].*$]])
    end
    for k,v in ipairs(trigger_text) do
        if not dslpnp.triggers.exists("Chat Trigger "..k) then
            dslpnp.triggers.register("Chat Trigger "..k,"regex",v,[[raiseEvent("onChat",matches[1],matches[2],matches[3])]],true)
        end
    end
end

local function config(window_name,x,y,width,height,origin)
    local configs = dslpnp.config.chat or {}
    local new = false
    if configs.channels then new = true end
    configs = table.update(defaults,configs)
    if new then configs.channels = dslpnp.config.chat.channels end
    dslpnp.chat.configs = configs

    dslpnp.chat.tabs = dslpnp.chat.tabs or {}
    dslpnp.chat.windows = dslpnp.chat.windows or {}
    dslpnp.chat.labels = dslpnp.chat.labels or {}

    for k,v in ipairs(configs.channels) do
            dslpnp.chat.buffers[k] = "chat" .. v[1] .. "buffer"
            createBuffer(dslpnp.chat.buffers[k])
            setWindowWrap(dslpnp.chat.buffers[k],1000)
            createMiniConsole("chat" .. v[1],0,0,0,0)
            setMiniConsoleFontSize("chat" .. v[1], configs.fontSize)
            setBackgroundColor("chat" .. v[1], 0,0,0,255)
            windowManager.add("chat" .. v[1], "miniConsole", x, y, width, height, origin)
            dslpnp.support.adjustWordWrap("chat" .. v[1], windowManager.getValue("chat" .. v[1],"width"), configs.fontSize)
            createLabel("chat_label" .. v[1],0,0,0,0,1)
            windowManager.add("chat_label" .. v[1], "label", x, y, width, height, origin)
            setLabelStyleSheet("chat_label" .. v[1], [[
                    border: 2px solid white;
                    border-radius: 5px;
                    background-color: rgba(0,0,0,0)]])
            setLabelClickCallback("chat_label" .. v[1], "raiseEvent","onReveal","chat",k)
            hideWindow("chat" .. v[1])
            hideWindow("chat_label" .. v[1])

            createLabel("chat_tab" .. v[1],0,0,0,0,1)
            setLabelClickCallback("chat_tab" .. v[1],"raiseEvent","onDisplay","chat", k)
            dslpnp.sidebar.maketab(window_name,"chat_tab" .. v[1],v[1])

            dslpnp.chat.tabs[k] = "chat_tab" .. v[1]
            dslpnp.chat.windows[k] = "chat" .. v[1]
            dslpnp.chat.labels[k] = "chat_label" .. v[1]
    end
    make_triggers(configs.channels)
    raiseEvent("onToggle","chat","on")
end

local function onReveal(index)
    hideWindow(dslpnp.chat.labels[index])
end

local function onDisplay(index)
    dslpnp.sidebar.display(dslpnp.chat.windows[index],{dslpnp.chat.windows[index], dslpnp.chat.labels[index]}, dslpnp.chat.tabs[index],index)
    adjust_windows()
end

local function displayWindow(x,y,width,height,index)
    windowManager.move(dslpnp.chat.windows[index],x,y)
    windowManager.move(dslpnp.chat.labels[index],x,y)
    windowManager.resize(dslpnp.chat.windows[index],width,height)
    windowManager.resize(dslpnp.chat.labels[index],width,height)
    showWindow(dslpnp.chat.windows[index])
    if dslpnp.chat.configs.show_border then
        showWindow(dslpnp.chat.labels[index])
    end
end

local function toggle(setVal)
    dslpnp.chat.Active = dslpnp.toggle("chat",dslpnp.chat.Active, setVal)
    for k,v in ipairs(dslpnp.chat.configs.channels) do
        if dslpnp.chat.Active then
            showWindow(dslpnp.chat.tabs[k])
        else
            hideWindow(dslpnp.chat.tabs[k])
            hideWindow(dslpnp.chat.windows[k])
            hideWindow(dslpnp.chat.labels[k])
        end
    end
end

function dslpnp.chat.eventHandler(event, ...)
    if event == "onChat" and dslpnp.chat.Active then
        process_text(arg[1], arg[2])
    elseif event == "onToggle" and arg[1] == "chat" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "chat" then
        config(arg[2],arg[3],arg[4],arg[5],arg[6],arg[7])
    elseif event == "onDisplay" and arg[1] == "chat" and dslpnp.chat.Active then
        onDisplay(arg[2])
    elseif event == "onReveal" and arg[1] == "chat" and dslpnp.chat.Active then
        onReveal(arg[2])
    elseif event == "sysWindowResizeEvent" and dslpnp.chat.Active then
        adjust_windows()
    elseif event == "displayWindow" and string.find(arg[1],"chat") and dslpnp.chat.Active then
        displayWindow(arg[2],arg[3],arg[4],arg[5],arg[6])
    end
end

registerAnonymousEventHandler("onChat", "dslpnp.chat.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.chat.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.chat.eventHandler")
registerAnonymousEventHandler("onDisplay", "dslpnp.chat.eventHandler")
registerAnonymousEventHandler("onReveal", "dslpnp.chat.eventHandler")
registerAnonymousEventHandler("sysWindowResizeEvent", "dslpnp.chat.eventHandler")
registerAnonymousEventHandler("displayWindow", "dslpnp.chat.eventHandler")
