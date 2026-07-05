-- Affects Script
-- 8/29/2019
-- v4.02n
--
-- Type "toggle affects" to disable or enable this script.
--
-- Use the following code to add a new affect to the affects list:
-- raiseEvent("onAffect", affect name, affect duration, spacing)
--

dslpnp.affects = dslpnp.affects or {}
dslpnp.affects.affects_list = dslpnp.affects.affects_list or {}
dslpnp.affects.configs = dslpnp.affects.configs or {}

dslpnp.affects.help = {
    [[
    Affects Script

    This script tracks your affects in a window in the sidebar. The color of the
    affect name will change as it gets close to expiring, and spell names can be
    clicked to recast the spell.

    The following configuration options are available:

    fontSize : a formatting option that sets the font size used in the Affects window.

    show_border : a formatting option that determins if a border will be displayed
                  around the Affects window.

    columns : a formatting option that sets the number of columns in which affects
              will be displayed.

    column_width : a formatting option that sets the width, in characters, of each column.

    track_location : determins if tracked affects will be displayed at the "top" or "bottom"
                     of the affects list.

    highlight_time : sets the time remaining, in ticks, at which affects become highlighted.

    highlight_color : sets the color that affects will be highlighted in when their remaining
                      duration reaches the value set in highlight_time.

    Aliases:

    track affect <affect name> - use this alias to "track" an affect, so that it will appear
                                 in your affects list, even when it has expired.
    ]],
track = [[
    Affects Script
    Track Affect Alias

    Syntax: track affect <affect name>

    This alias takes the name of an affect, exactly as seen in your affects list, and uses
    it to track the given affect. When you are affected by it, the affect will show up as
    normal. But when it expires, it will not disappear from the list like other affects.
    Rather, it will be placed in a secondary list in the affects window with other tracked
    affects. This allows you to easily see when a specific affect is down, and to click
    on the affect name to quickly recast it.
    ]]
}

local defaults = {
    fontSize = 10,
    show_border = true,
    highlight_color = "red",
    highlight_time = 5,
    columns = 1,
    column_width = 18,
    track_location = "bottom",
    cast_command = "cast",
}

dslpnp.affects.songs_list = {
    "song of war",
    "no eyes",
    "weakness within",
    "we come, we come",
    "lullaby",
    "nightmare",
    "shield of words",
    "song of charm",
    "green leaf"
}
local songs_list = dslpnp.affects.songs_list

dslpnp.affects.skills_list = {
    "berserk",
    "sneak"
}
local skills_list = dslpnp.affects.skills_list

local spell_triggers = spell_triggers or {}

-- Searches currently listed affects for affectName, returns true and the remaining duration if found.
-- This function contributed by Octavius
function dslpnp.affects.findAffect(affectName)
    if dslpnp.affects.Active then
        for i, v in ipairs(dslpnp.affects.affects_list) do
            if affectName == string.trim(v[2]) then
                return true, v[1]
            end
        end
        return false, false
    end
end

local function make_links(tbl)
    local configs = dslpnp.affects.configs or {}
    configs = table.update(defaults,dslpnp.affects.configs)
    local window = "affects_list"
    local affs = table.copy(dslpnp.affects.affects_list)
    tbl = table.n_union(affs, tbl)
    for k,v in ipairs(tbl) do
        if type(v) == "table" then
            tbl[k][2] = string.cut(v[2],configs.column_width)
        else
            tbl[k] = string.cut(v,configs.column_width)
        end
    end
    local index = 1
    local check, text, line_text, duration
    repeat
        check = moveCursor(window,0,index)
        line_text = getCurrentLine(window)
        for w,n in rex.gmatch(line_text,[[\s*([a-zA-Z\s]+?)\s*:\s+([\w\?\-\*]+)]]) do
            if w and table.contains(tbl,w) and n ~= "**" then
                selectString(window,w,1)
                if table.contains(songs_list,w) then
                    setLink(window,[[send("sing ']] .. w .. [['")]],"Recast " .. w)
                elseif table.contains(skills_list,w) then
                    setLink(window,[[send("]] .. w .. [[")]],"Recast " .. w)
                else
                    setLink(window, string.format([[send("%s '%s'")]],configs.cast_command,w),"Recast " .. w)
                end
            end
        end
        index = index + 1
    until not check
end

local function updateAffects()
    local configs = dslpnp.affects.configs or {}
    configs = table.update(defaults,dslpnp.affects.configs)
    local display_list = {}
    local affects_line = ""
    local tracking_list = {}
    local aff
    if dslpnp.character then
        tracking_list = dslpnp.character.getCharData("trackedAffects") or {}
    end
    local inactive_list = {}
    -- refreshes affects list
    clearWindow("affects_list")
    cecho("affects_list",string.format("\n %-" .. configs.column_width .. "s : Time\n","Affect"))
    for k, v in ipairs(dslpnp.affects.affects_list) do
        tracking_list[v[2]] = nil
        aff = string.cut(v[2],configs.column_width)
        if v[1] >= 0 then
            if v[1] < configs.highlight_time then
                table.insert(display_list,string.format(" <%s>%-" .. configs.column_width .. "s : %2s<reset>",configs.highlight_color,aff, v[1]))
            else
                table.insert(display_list,string.format(" %-" .. configs.column_width .. "s : %2s",aff, v[1]))
            end
        elseif v[1] == -2 then
            table.insert(display_list,string.format(" %-" .. configs.column_width .. "s : **",aff))
        elseif v[1] == -1 then
            table.insert(display_list,string.format(" %-" .. configs.column_width .. "s : ??",aff))
        end
    end

    for k, v in pairs(tracking_list) do
        if v then
            table.insert(inactive_list,k)
        end
    end
    table.sort(inactive_list)

    if configs.track_location == "bottom" then
        for i = 1,#display_list,configs.columns do
            affects_line = ""
            for j = 1,configs.columns do
                affects_line = affects_line .. (display_list[i+j-1] or "")
            end
            cecho("affects_list",affects_line .. "\n")
        end
    else
        for k, v in ipairs(inactive_list) do
            cecho("affects_list",string.format(" %-" .. configs.column_width .. "s : --\n",string.cut(v,configs.column_width)))
        end
    end

    -- print separator line
    cecho("affects_list"," " .. string.rep("-",configs.column_width + 6) .. "\n")

    if configs.track_location == "top" then
        for i = 1,#display_list,configs.columns do
            affects_line = ""
            for j = 1,configs.columns do
                affects_line = affects_line .. (display_list[i+j-1] or "")
            end
            cecho("affects_list",affects_line .. "\n")
        end
    else
        for k, v in ipairs(inactive_list) do
            cecho("affects_list",string.format(" %-" .. configs.column_width .. "s : --\n",string.cut(v,configs.column_width)))
        end
    end

    make_links(inactive_list)
end

local function decrementAffects()
    -- reduces time left on affects by 1, removes items once they have expired
    local delList = {}
    for i, v in ipairs(dslpnp.affects.affects_list) do
        if v[1] > 0 then
            v[1] = v[1] - 1
        elseif v[1] == 0 then
            table.insert(delList, v[2])
        end
    end

    for i, v in ipairs(delList) do
        if table.contains(dslpnp.affects.affects_list,v) then
            raiseEvent("affectRemove",v)
            for k2,v2 in ipairs(dslpnp.affects.affects_list) do
                if v2[2] == v then
                    table.remove(dslpnp.affects.affects_list, k2)
                end
            end
        end
    end
    updateAffects()
end

local function clearAffects()
    if dslpnp.affects.Active then
        -- clears affects window and tracking list
        clearWindow("affects_list")
        while table.maxn(dslpnp.affects.affects_list) > 0 do
            raiseEvent("affectClear",dslpnp.affects.affects_list[1][2])
        end
        updateAffects()
    end
end

local function removeAffect(affectName)
    for i,v in ipairs(dslpnp.affects.affects_list) do
        if v[2] == affectName then
            table.remove(dslpnp.affects.affects_list,i)
        end
    end
    updateAffects()
end

local function addAffect(affectName, affectTime)
    if dslpnp.affects.Active then
        -- adds new affects to list, collected from "affects"
        local padding = "                  "
        local inList = false
        local valIndex = 0
        local i,v
        if affectTime == "" or not affectTime then affectTime = -1 end
        if affectTime ~= "permanently" then
            affectTime = tonumber(affectTime)
        else
            affectTime = -2
        end
        affectName = string.trim(affectName)
        for i,v in ipairs(dslpnp.affects.affects_list) do
            if v[2] == affectName then
                inList = true
                valIndex = i
            end
        end
        if inList then
            dslpnp.affects.affects_list[valIndex] = {affectTime, affectName}
        else
            table.insert(dslpnp.affects.affects_list, {affectTime, affectName})
        end
        table.sort(dslpnp.affects.affects_list,function(a,b) return a[1]<b[1] or (a[1]==b[1] and a[2]<b[2]) end)
        updateAffects()
    end
end

local function trackAffect(affectName)
    local tracked = not dslpnp.character.getCharData("trackedAffects", affectName)
    local message = string.title(affectName)
    dslpnp.character.setCharData(tracked, "trackedAffects", affectName)
    if tracked then
        message = message .. " now being tracked."
    else
        message = message .. " no longer being tracked."
    end
    echo(message)
end

local function make_triggers()
    local trigger_text = {
        [[^Spell: ([a-zA-Z\s]*?)(\s*): modifies .* for ([0-9]*) cycles]],
        [[^Spell: ([a-zA-Z\s]*?)(\s*): modifies .* (permanently)]],
        [[^Spell: ([a-zA-Z\s]*)$]],
        [[^Song : ([a-zA-Z,\s]*?)(\s*): modifies .* for ([0-9]*) cycles]],
        [[^Song : ([a-zA-Z,\s]*?)(\s*): modifies .* (permanently)]],
        [[^Song : ([a-zA-Z\s]*)$]]
        }
    for k,v in ipairs(trigger_text) do
        if not dslpnp.triggers.exists("New Affect Trigger "..k) then
            dslpnp.triggers.register("New Affect Trigger "..k, "regex", v, [[raiseEvent("affectAdd",matches[2], matches[4] or "-1")]], true)
        end
    end
    local trigger_text = {
        [[You are affected by the following spells:]],
        [[You are not affected by any spells.]]
        }
    for k,v in ipairs(trigger_text) do
        if not dslpnp.triggers.exists("Affects Trigger "..k) then
            dslpnp.triggers.register("Affects Trigger "..k, "regex", v, [[raiseEvent("onAffect")]], true)
        end
    end
end

local function make_aliases()
    if not dslpnp.aliases.exists("Track Affect Alias") then
        dslpnp.aliases.register("Track Affect Alias", [[^track affect (.+)$]], [[raiseEvent("onTrackAffect",matches[2])]], true)
    end
end

local function toggle(setVal)
    dslpnp.affects.Active = dslpnp.toggle("affects",dslpnp.affects.Active, setVal)
    if dslpnp.affects.Active then
        showWindow("affects_tab")
        if dslpnp.aliases.exists("Track Affect Alias") then dslpnp.aliases.enable("Track Affect Alias") end
    else
        hideWindow("affects_list")
        hideWindow("affects_label")
        hideWindow("affects_tab")
        if dslpnp.aliases.exists("Track Affect Alias") then dslpnp.aliases.disable("Track Affect Alias") end
    end
end

local function config(window_name,x,y,width,height,origin)
    dslpnp.affects.windowList = {"affects_list","affects_label"}
    dslpnp.affects.configs = dslpnp.config.affects or {}
    dslpnp.affects.configs = table.update(defaults,dslpnp.affects.configs)
    createMiniConsole("affects_list",0,0,0,0)
    createLabel("affects_label",0,0,0,0,1)
    windowManager.add("affects_list","miniConsole",x,y,width,height,origin)
    windowManager.add("affects_label","label",x,y,width,height,origin)
    setBackgroundColor("affects_list",0,0,0,255)
    setMiniConsoleFontSize("affects_list",dslpnp.affects.configs.fontSize)
    setLabelStyleSheet("affects_label",[[
        border: 2px solid white;
        border-radius: 5px;
        background-color: rgba(0,0,0,0)]])
    setLabelClickCallback("affects_label","raiseEvent","onReveal","affects")
    hideWindow("affects_list")
    hideWindow("affects_label")

    createLabel("affects_tab",0,0,0,0,1)
    setLabelClickCallback("affects_tab","raiseEvent","onDisplay","affects")
    dslpnp.sidebar.maketab(window_name,"affects_tab","Affects")

    make_triggers()
    make_aliases()
    raiseEvent("onToggle","affects","on")
end

local function onReveal()
    hideWindow("affects_label")
end

local function onDisplay()
    dslpnp.sidebar.display("affects", {"affects_list","affects_label"}, "affects_tab")
end

local function displayWindow(x,y,width,height)
    windowManager.move("affects_list",x,y)
    windowManager.move("affects_label",x,y)
    windowManager.resize("affects_list",width,height)
    windowManager.resize("affects_label",width,height)
    showWindow("affects_list")
    if dslpnp.affects.configs.show_border then
        showWindow("affects_label")
    end
end

function dslpnp.affects.eventHandler(event, ...)
    if event == "onTick" and dslpnp.affects.Active then
        decrementAffects()
    elseif event == "onAffect" and dslpnp.affects.Active then
        clearAffects()
    elseif event == "affectAdd" and dslpnp.affects.Active then
        addAffect(arg[1],arg[2])
    elseif event == "affectRemove" or event == "affectClear" and dslpnp.affects.Active then
        removeAffect(arg[1])
    elseif event == "onTrackAffect" and dslpnp.affects.Active then
        trackAffect(arg[1])
    elseif event == "onToggle" and arg[1] == "affects" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "affects" then
        config(arg[2], arg[3], arg[4], arg[5], arg[6], arg[7])
    elseif event == "onDisplay" and arg[1] == "affects" and dslpnp.affects.Active then
        onDisplay()
    elseif event == "onReveal" and arg[1] == "affects" and dslpnp.affects.Active then
        onReveal()
    elseif event == "displayWindow" and arg[1] == "affects" and dslpnp.affects.Active then
        displayWindow(arg[2],arg[3],arg[4],arg[5])
    end
end

registerAnonymousEventHandler("onTick", "dslpnp.affects.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.affects.eventHandler")
registerAnonymousEventHandler("onAffect", "dslpnp.affects.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.affects.eventHandler")
registerAnonymousEventHandler("onDisplay", "dslpnp.affects.eventHandler")
registerAnonymousEventHandler("onReveal", "dslpnp.affects.eventHandler")
registerAnonymousEventHandler("onTrackAffect", "dslpnp.affects.eventHandler")
registerAnonymousEventHandler("affectAdd", "dslpnp.affects.eventHandler")
registerAnonymousEventHandler("affectRemove", "dslpnp.affects.eventHandler")
registerAnonymousEventHandler("affectClear", "dslpnp.affects.eventHandler")
registerAnonymousEventHandler("displayWindow", "dslpnp.affects.eventHandler")
