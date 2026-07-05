-- Roller Script
-- 3/22/2018
-- v4.00c
--

dslpnp.roller = dslpnp.roller or {}
local roll_data = roll_data or {}
local stat_list = {"str", "int", "wis", "dex", "con", "total"}

dslpnp.roller.help = dslpnp.roller.help or {}
dslpnp.roller.help = [[
    Roller Script

    The roller script is designed to automate the process of rolling for stats on your
    characters. With the script, you can easily set a goal and tell the script to keep
    saying no until your goal number (of stat total) is successfully reached.

    To set your rolling target, use "set goal". Syntax: set goal #
    To view statistics about your rolls, use "roll stats".
    To reset your roll statistics, use "reset roll".
]]

local defaults = {
    goal = 230
}

local function newRoll(str, int, wis, dex, con)
    if dslpnp.roller.Active then
        str = assert(tonumber(str), "Invalid strength!")
        int = assert(tonumber(int), "Invalid intelligence!")
        wis = assert(tonumber(wis), "Invalid wisdom!")
        dex = assert(tonumber(dex), "Invalid dexterity!")
        con = assert(tonumber(con), "Invalid constitution!")
        roll_data.str = roll_data.str or {}
        table.insert(roll_data.str,str)
        roll_data.int = roll_data.int or {}
        table.insert(roll_data.int,int)
        roll_data.wis = roll_data.wis or {}
        table.insert(roll_data.wis,wis)
        roll_data.dex = roll_data.dex or {}
        table.insert(roll_data.dex,dex)
        roll_data.con = roll_data.con or {}
        table.insert(roll_data.con,con)
        local total = str + int + wis + dex + con
        roll_data.total = roll_data.total or {}
        table.insert(roll_data.total,total)
        if total >= dslpnp.roller.goal then
            cecho(" <red>==" .. total .. "==")
            raiseEvent("onAlert", "Mudlet - DSL", "Rolled: " .. total, false, false)
        else
            echo(" (" .. total .. ")")
            send("n", false)
        end
    end
end

local function calc_stats(stat)
    assert(table.contains(roll_data,stat),"Invalid stat!")
    local min, max, avg, stdev, z
    local stat_array = roll_data[stat]
    for k,v in ipairs(stat_array) do
        if k == 1 then
            min = v
            max = v
            avg = v
            stdev = 0
        else
            if v < min then min = v end
            if v > max then max = v end
            avg = avg + v
        end
    end
    avg = math.round(avg / #stat_array)
    stdev = math.round(math.stdev(stat_array),3)
    if stat == "total" then
        z = math.round((dslpnp.roller.goal - avg)/stdev,2)
    end
    return min, max, avg, stdev, z
end

function dslpnp.roller.set_goal(goal)
    dslpnp.roller.goal = assert(tonumber(goal),"Invalid goal!")
    print("Goal set to: " .. dslpnp.roller.goal .. ".")
end

function dslpnp.roller.reset()
    roll_data = {}
    print("Rolling data reset!")
end

function dslpnp.roller.show_stats()
    local min, max, avg, stdev
    local format = "%-5s: %3s %3s %3s %5s %s"
    print("Rolls: " .. #roll_data["str"])
    print(string.format(format,"","MIN","MAX","AVG","STDEV","Z"))
    for k,v in ipairs(stat_list) do
        min, max, avg, stdev, z = calc_stats(v)
        print(string.format(format,string.title(v), min, max, avg, stdev, z or ""))
    end
end

local function make_aliases()
    if not dslpnp.aliases.exists("Set Goal Alias") then
        dslpnp.aliases.register("Set Goal Alias", [[^set goal (.*)$]], [[dslpnp.roller.set_goal(matches[2])]],true)
    end
    if not dslpnp.aliases.exists("Roll Stats Alias") then
        dslpnp.aliases.register("Roll Stats Alias",[[^roll stats$]], [[dslpnp.roller.show_stats()]],true)
    end
    if not dslpnp.aliases.exists("Reset Roll Alias") then
        dslpnp.aliases.register("Reset Roll Alias",[[^reset roll$]], [[dslpnp.roller.reset()]])
    end
end

local function make_triggers()
    if not dslpnp.triggers.exists("Roll Trigger") then
        dslpnp.triggers.register("Roll Trigger", "regex", [[Str: (\d+)  Int: (\d+)  Wis: (\d+)  Dex: (\d+)  Con: (\d+)]], [[raiseEvent("onRoll",matches[2], matches[3], matches[4], matches[5], matches[6])]],true)
    end
end

local function toggle(setVal)
    dslpnp.roller.Active = dslpnp.toggle("roller",dslpnp.roller.Active, setVal)
    if dslpnp.roller.Active then
        if dslpnp.aliases.exists("Set Goal Alias") then dslpnp.aliases.enable("Set Goal Alias") end
        if dslpnp.aliases.exists("Roll Stats Alias") then dslpnp.aliases.enable("Roll Stats Alias") end
        if dslpnp.aliases.exists("Reset Roll Alias") then dslpnp.aliases.enable("Reset Roll Alias") end
    else
        if dslpnp.aliases.exists("Set Goal Alias") then dslpnp.aliases.disable("Set Goal Alias") end
        if dslpnp.aliases.exists("Roll Stats Alias") then dslpnp.aliases.disable("Roll Stats Alias") end
        if dslpnp.aliases.exists("Reset Roll Alias") then dslpnp.aliases.disable("Reset Roll Alias") end
    end
end

local function config()
    local configs = dslpnp.config.roller or {}
    configs = table.update(defaults,configs)
    dslpnp.roller.goal = configs.goal
    make_aliases()
    make_triggers()
    raiseEvent("onToggle","roller","on")
end

function dslpnp.roller.eventHandler(event, ...)
    if event == "onRoll" and dslpnp.roller.Active then
        newRoll(arg[1], arg[2], arg[3], arg[4], arg[5], arg[6])
    elseif event == "onToggle" and arg[1] == "roller" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "roller" then
        config()
    end
end

registerAnonymousEventHandler("onRoll", "dslpnp.roller.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.roller.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.roller.eventHandler")
