-- Gourd Script
-- 9/20/2016
-- v4.01e
--
-- Special thanks to eric for his contributions to this script.
--

dslpnp.gourd = dslpnp.gourd or {}
dslpnp.gourd.configs = dslpnp.gourd.configs or {}
dslpnp.gourd.help = [[
Type "toggle gourd" to disable or enable this script.

Using lore on a gourd will automatically add it to the current list of gourds
(loring one twice will place two copies on the list, so be careful). Gourds
are automatically removed when they evaporate. To refresh the list, type "scan
gourds". The current list will be cleared, and all gourds in your inventory
will be lored and added to the list. A gourd may be removed from the list
manually by using its number in the list using the following command:
remove gourd 5

Gourds may be selected to toss, quaff, or apply using either their number in
the list, or any spell on the gourd. Toss and apply use the normal commands.
Any item not found in the list will be sent to the mud directly, so you can
"toss stake" without any problems. To quaff a gourd, it is necessary to use
the "gq" command instead of the normal "quaff" command.
Examples:
apply 5  or  toss 'protection evil'  or  apply enchant
gq 7  or  gq cone
]]

local defaults = {
    fontSize = 10,
    show_border = true
}

local gourd_class = {
    new = function(self, name, name_index)
        local o = { name = name or "", name_index = name_index or 0, spell_list = {} }
        setmetatable(o, self)
        return o
    end,

    has_spell = function(self, spell)
        local found_spell = false
        for a, v in ipairs(self.spell_list) do
            if string.match(v,spell) then
                found_spell = true
            end
        end
        return found_spell
    end,

    num_spells = function(self)
        return #self.spell_list
    end,

    spells = function(self, a, v)
        if v and v ~= "reserved" then
            self.spell_list[a] = v
            return true
        else
            if a and a <= #self.spell_list then
                return self.spell_list[a]
            else
                return self.spell_list
            end
        end
    end,

    spell = function(self, a, v)
        return self.spells(self, a, v)
    end,

    __index = function(self, key)
        return getmetatable(self)[key]
    end,

}

local function newGourd(name, name_index)
    o = gourd_class:new(name, name_index)
    return o
end

-- Gourd methods:
-- newGourd(name, name_index)
-- spells(index, value)
-- has_spell(value)
-- num_spells()

local gourdDB = {}
local scanIndex = 0
local scanningGourds = false
local newGourdName
local lastGourdTossed

local function updateGourdList()
    local tmpStr = ""
    clearWindow("gourd_list")
    table.sort(gourdDB,function(a,b) if a.name ~= b.name then return a.name < b.name else return a.name_index > b.name_index end end)
    echo("gourd_list","\n ## : Spells\n")
    for a, v in ipairs(gourdDB) do
        if a < 10 then tmpStr = "  " .. a .. " : " else tmpStr = " " .. a .. " : " end
        for i2, v2 in ipairs(v:spells()) do
            tmpStr = tmpStr .. v2
            if i2 < v:num_spells() then tmpStr = tmpStr .. ", " end
        end
        echo("gourd_list",tmpStr .. "\n")
    end
    if scanningGourds then
        dslpnp.gourd.scanGourds()
    end
end

local function clearGourdList()
    gourdDB = {}
    updateGourdList()
end

local function gourdBySpell(spellName)
    for a, v in ipairs(gourdDB) do
        if v:has_spell(spellName) then return a, v.name_index .. "." .. v.name end
    end
    return false
end

local function gourdsByIndex(gourdIndex)
    gourdIndex = tonumber(gourdIndex)
    local tmpGourd = gourdDB[gourdIndex]
    if tmpGourd ~= nil then return gourdIndex, tmpGourd.name_index .. "." .. tmpGourd.name end
    return false
end

function dslpnp.gourd.addGourd(tName, tmp_spell_list)
    if dslpnp.gourd.Active then
        assert(type(tName) == "string","Invalid name!")
        tmp_spell_list = string.split(tmp_spell_list,"' '")
        assert(type(tmp_spell_list) == "table","Invalid spell list!")
        local tmpGourd = newGourd(tName, 1)
        if not scanningGourds then
            for a, v in ipairs(gourdDB) do
                if v.name == tName then
                    v.name_index = v.name_index + 1
                end
            end
        else
            for a, v in ipairs(gourdDB) do
                if v.name == tName then
                    tmpGourd.name_index = tmpGourd.name_index + 1
                end
            end
        end
        for a,v in ipairs(tmp_spell_list) do
            tmpGourd:spells(a,v)
        end
        table.insert(gourdDB, tmpGourd)
        updateGourdList()
    end
end

function dslpnp.gourd.scanGourds()
    if dslpnp.gourd.Active then
        if not scanningGourds then
            echo("Starting scan...\n")
            scanIndex = 0
            clearGourdList()
            scanningGourds = true
            dslpnp.triggers.enable("End Gourd Scanning Trigger")
            dslpnp.triggers.enable("Lore Gourd Fail Trigger")
        end
        scanIndex = scanIndex + 1
        send("lore " .. scanIndex .. ".gourd")
    end
end

function dslpnp.gourd.failedScan()
    scanIndex = scanIndex - 1
    dslpnp.gourd.scanGourds()
end

function dslpnp.gourd.endScan()
    if dslpnp.gourd.Active then
        scanningGourds = false
        dslpnp.triggers.disable("End Gourd Scanning Trigger")
        dslpnp.triggers.disable("Lore Gourd Fail Trigger")
        echo("\nScan complete.\n")
    end
end

function dslpnp.gourd.useGourd(gourdRef, toss)
    if dslpnp.gourd.Active then
        assert(type(gourdRef) == "string", "Invalid gourd reference!")
        local tmpName = ""
        local tmpIndex = false
        local tmpChk = string.find(gourdRef, "%d")
        if tmpChk ~= nil then
            tmpIndex, tmpName = gourdsByIndex(gourdRef)
        else
            tmpIndex, tmpName = gourdBySpell(gourdRef)
        end
        if tmpIndex then
            if toss == true then
                lastGourdTossed = tonumber(gourdRef) -- Gourd found, remember it
            else
                dslpnp.gourd.removeGourd(tmpIndex)
            end
            return tmpName
        end
        -- Gourd description cannot be found, or new login and haven't run "scan gourds" yet
        -- echo("\nError: Gourd not found. Use 'scan gourds'")
        return gourdRef
    end
end

function dslpnp.gourd.removeGourd(gourdIndex)
    if dslpnp.gourd.Active then
        assert(tonumber(gourdIndex) ~= nil, "Invalid gourd index!")
        local tmpName = gourdDB[tonumber(gourdIndex)].name
        local tmpIndex = gourdDB[tonumber(gourdIndex)].name_index
        for i,v in ipairs(gourdDB) do
            if v.name == tmpName then
                if v.name_index > tmpIndex then v.name_index = v.name_index - 1 end
            end
        end
        table.remove(gourdDB, gourdIndex)
        updateGourdList()
        lastGourdTossed = nil
    end
end

local function evaporateGourd(tmpName)
    if dslpnp.gourd.Active then
        assert(type(tmpName) == "string", "Invalid gourd name!")
        local tmpIndex
        tmpIndex, tmpName = gourdBySpell(tmpName)
        dslpnp.gourd.removeGourd(tmpIndex)
    end
end

local function make_triggers()
    local trigger_text
    if not dslpnp.triggers.exists("Gourd Evaporation Trigger") then
        dslpnp.triggers.register("Gourd Evaporation Trigger","regex",[[^.* potion gourd of (.*) has evaporated from disuse.]], [[raiseEvent("onEvaporate",matches[2])]],true)
    end
    if not dslpnp.triggers.exists("Gourd Toss Trigger") then -- Gourd throwing trigger
          dslpnp.triggers.register("Gourd Toss Trigger","regex",[[^You throw a gourd right at .*]], [[raiseEvent("onToss")]],true)
     end
    if not dslpnp.triggers.exists("Lore Gourd Name Trigger") then
        dslpnp.triggers.register("Lore Gourd Name Trigger","regex", [[Name\(s\): 'witch potion gourd ([a-zA-Z\s]*)']], [[raiseEvent("onNewGourd", "name", matches[2])]],true)
    end
    if not dslpnp.triggers.exists("Lore Gourd Spells Trigger") then
        dslpnp.triggers.register("Lore Gourd Spells Trigger","regex", [[Level \d+ spells of: '(.*)'.]], [[raiseEvent("onNewGourd", "spells", matches[2])]],false)
    end
    if not dslpnp.triggers.exists("Lore Gourd Fail Trigger") then
        dslpnp.triggers.register("Lore Gourd Fail Trigger","regex",[[^Can't make heads or tails of it.]], [[raiseEvent("onGourdLoreFail")]], false)
    end
    if not dslpnp.triggers.exists("End Gourd Scanning Trigger") then
        dslpnp.triggers.register("End Gourd Scanning Trigger","regex",[[You do not have that item.]],[[dslpnp.gourd.endScan()]],false)
    end

end

local function make_aliases()
    if not dslpnp.aliases.exists("Toss Gourd Alias") then
        dslpnp.aliases.register("Toss Gourd Alias", [[^(toss|tos) (\w+|'\w+\s?\w*')\s?(\d+\.\w*|['\w]*)$]], [[send("toss '" .. dslpnp.gourd.useGourd(string.gsub(matches[3],"'",""),true) .. "' " .. matches[4],false)]],true)
    end
    if not dslpnp.aliases.exists("Multi Item Block Alias") then -- block (index.spellname) hybrid search, e.g. 2.frog
          dslpnp.aliases.register("Multi Item Block Alias", [[^(toss|tos|apply|appl|app) (\d+\.\w+)\s?(\d+\.\w*|['\w]*)$]], [[echo("\nSyntax error: <toss #> or <toss 'spell name'>, where the name's first occurrence will match.\nCommands: toss, apply, or remove")]],true)
     end
    if not dslpnp.aliases.exists("Quaff Gourd Alias") then
        dslpnp.aliases.register("Quaff Gourd Alias",[[^gq [']?([\w\s]+)[']?$]],[[send("quaff '" .. dslpnp.gourd.useGourd(matches[2]) .. "'",false)]],true)
    end
    if not dslpnp.aliases.exists("Apply Gourd Alias") then
        dslpnp.aliases.register("Apply Gourd Alias",[[^apply (\w+|'\w+\s?\w*')\s?(['\w]*)$]],[[send("apply '" .. dslpnp.gourd.useGourd(string.gsub(matches[2],"'","")) .. "' " .. matches[3],false)]],true)
    end
    if not dslpnp.aliases.exists("Scan Gourds Alias") then
        dslpnp.aliases.register("Scan Gourds Alias",[[^scan gourds$]],[[dslpnp.gourd.scanGourds()]],true)
    end
    if not dslpnp.aliases.exists("Remove Gourd Alias") then
        dslpnp.aliases.register("Remove Gourd Alias",[[^remove gourd (\d+)$]],[[dslpnp.gourd.removeGourd(matches[2])]],true)
    end
    if not dslpnp.aliases.exists("Drop Gourd Alias") then
        dslpnp.aliases.register("Drop Gourd Alias",[[^gd [']?([\w\s]+)[']?$]],[[send("drop '" .. dslpnp.gourd.useGourd(matches[2]) .. "'",false)]],true)
    end
end

local function toggle(setVal)
    dslpnp.gourd.Active = dslpnp.toggle("gourd",dslpnp.gourd.Active, setVal)
    if dslpnp.gourd.Active then
        if dslpnp.aliases.exists("Multi Item Block Alias") then dslpnp.aliases.enable("Multi Item Block Alias") end
        if dslpnp.aliases.exists("Toss Gourd Alias") then dslpnp.aliases.enable("Toss Gourd Alias") end
        if dslpnp.aliases.exists("Quaff Gourd Alias") then dslpnp.aliases.enable("Quaff Gourd Alias") end
        if dslpnp.aliases.exists("Apply Gourd Alias") then dslpnp.aliases.enable("Apply Gourd Alias") end
        if dslpnp.aliases.exists("Scan Gourds Alias") then dslpnp.aliases.enable("Scan Gourds Alias") end
        if dslpnp.aliases.exists("Remove Gourd Alias") then dslpnp.aliases.enable("Remove Gourd Alias") end
        if dslpnp.aliases.exists("Drop Gourd Alias") then dslpnp.aliases.enable("Drop Gourd Alias") end

        showWindow("gourd_tab")
    else
        if dslpnp.triggers.exists("End Gourd Scanning Trigger") then dslpnp.triggers.disable("End Gourd Scanning Trigger") end
        if dslpnp.triggers.exists("Lore Gourd Spells Trigger") then dslpnp.triggers.disable("Lore Gourd Spells Trigger") end
        if dslpnp.aliases.exists("Multi Item Block Alias") then dslpnp.aliases.disable("Multi Item Block Alias") end
        if dslpnp.aliases.exists("Toss Gourd Alias") then dslpnp.aliases.disable("Toss Gourd Alias") end
        if dslpnp.aliases.exists("Quaff Gourd Alias") then dslpnp.aliases.disable("Quaff Gourd Alias") end
        if dslpnp.aliases.exists("Apply Gourd Alias") then dslpnp.aliases.disable("Apply Gourd Alias") end
        if dslpnp.aliases.exists("Scan Gourds Alias") then dslpnp.aliases.disable("Scan Gourds Alias") end
        if dslpnp.aliases.exists("Remove Gourd Alias") then dslpnp.aliases.disable("Remove Gourd Alias") end
        if dslpnp.aliases.exists("Drop Gourd Alias") then dslpnp.aliases.disable("Drop Gourd Alias") end

        hideWindow("gourd_list")
        hideWindow("gourd_label")
        hideWindow("gourd_tab")
    end
end

local function config(window_name,x,y,width,height,origin)
    dslpnp.gourd.windowList = {"gourd_list","gourd_label"}
    local configs = dslpnp.config.gourd or {}
    configs = table.update(defaults,configs)
    dslpnp.gourd.configs = configs
    createMiniConsole("gourd_list",0,0,0,0)
    createLabel("gourd_label",0,0,0,0,1)
    windowManager.add("gourd_list","miniConsole",x,y,width,height,origin)
    windowManager.add("gourd_label","label",x,y,width,height,origin)
    setBackgroundColor("gourd_list",0,0,0,255)
    setMiniConsoleFontSize("gourd_list",configs.fontSize)
    setLabelStyleSheet("gourd_label",[[
        border: 2px solid white;
        border-radius: 5px;
        background-color: rgba(0,0,0,0)]])
    setLabelClickCallback("gourd_label","raiseEvent","onReveal","gourd")
    hideWindow("gourd_list")
    hideWindow("gourd_label")

    createLabel("gourd_tab",0,0,0,0,1)
    setLabelClickCallback("gourd_tab","raiseEvent","onDisplay","gourd")
    dslpnp.sidebar.maketab(window_name,"gourd_tab","Gourds")

    make_triggers()
    make_aliases()
    raiseEvent("onToggle","gourd","on")
end

local function onReveal()
    hideWindow("gourd_label")
end

local function onDisplay()
    dslpnp.sidebar.display("gourd",{"gourd_list","gourd_label"}, "gourd_tab")
end

local function displayWindow(x,y,width,height)
    windowManager.move("gourd_list",x,y)
    windowManager.move("gourd_label",x,y)
    windowManager.resize("gourd_list",width,height)
    windowManager.resize("gourd_label",width,height)
    showWindow("gourd_list")
    if dslpnp.gourd.configs.show_border then
        showWindow("gourd_label")
    end
end

function dslpnp.gourd.eventHandler(event, ...)
    if event == "onToggle" and arg[1] == "gourd" then
        toggle(arg[2])
    elseif event == "onEvaporate" and dslpnp.gourd.Active then
        evaporateGourd(arg[1])
    elseif event == "onToss" and dslpnp.gourd.Active then
          dslpnp.gourd.removeGourd(lastGourdTossed)
    elseif event == "onNewGourd" and dslpnp.gourd.Active then
        if arg[1] == "name" then
            newGourdName = arg[2]
            dslpnp.triggers.enable("Lore Gourd Spells Trigger")
        elseif arg[1] == "spells" then
            dslpnp.gourd.addGourd(newGourdName, arg[2])
            dslpnp.triggers.disable("Lore Gourd Spells Trigger")
        end
    elseif event == "onGourdLoreFail" then
        dslpnp.gourd.failedScan()
    elseif event == "onConfig" and arg[1] == "gourd" then
        config(arg[2], arg[3], arg[4], arg[5], arg[6], arg[7])
    elseif event == "onDisplay" and arg[1] == "gourd" and dslpnp.gourd.Active then
        onDisplay()
    elseif event == "onReveal" and arg[1] == "gourd" and dslpnp.gourd.Active then
        onReveal()
    elseif event == "displayWindow" and arg[1] == "gourd" and dslpnp.gourd.Active then
        displayWindow(arg[2],arg[3],arg[4],arg[5])
    elseif event == "onClearGourdList" then
        clearGourdList()
    end
end

registerAnonymousEventHandler("onToss", "dslpnp.gourd.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.gourd.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.gourd.eventHandler")
registerAnonymousEventHandler("onDisplay", "dslpnp.gourd.eventHandler")
registerAnonymousEventHandler("onReveal", "dslpnp.gourd.eventHandler")
registerAnonymousEventHandler("onEvaporate", "dslpnp.gourd.eventHandler")
registerAnonymousEventHandler("onNewGourd", "dslpnp.gourd.eventHandler")
registerAnonymousEventHandler("displayWindow", "dslpnp.gourd.eventHandler")
registerAnonymousEventHandler("onGourdLoreFail", "dslpnp.gourd.eventHandler")
registerAnonymousEventHandler("onClearGourdList", "dslpnp.gourd.eventHandler")
