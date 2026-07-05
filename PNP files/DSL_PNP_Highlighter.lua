-- Highlighter Script
-- 8/22/2018
-- v4.03c
--
-- War status can be toggled for entire clans and for individuals as follows:
-- set status Slayers
-- set status Jor'Mox enemy
-- set status 'white robes' ally
-- set status wargar neutral
-- set team Jor'Mox Card Sharks
--

dslpnp.highlighter = dslpnp.highlighter or {}
dslpnp.data.highlighter = dslpnp.data.highlighter or {}

dslpnp.highlighter.help = {}
dslpnp.highlighter.help[1] = [[
    Highlighter Script

    The Highlighter Script provides a visual cue for players to quickly identify what
    organization other characters belong to. It can also provide information such as
    level. This script is dependent on information gathered by the People Script and
    won't work without it.

    See Also:
    'Set Status' and 'Set Team'
]]
dslpnp.highlighter.help["set status"] = [[
    Highlighter Script : Set Status Alias

    Use this command to assign ally, neutral, or enemy status for individuals or
    organizations. By default, enemies will appear with a '*' after their name,
    and allies will appear with a '+' after their name. If no status is given,
    the status will alternate between 'enemy' and 'neutral'.

    Syntax:
    set status Jor'mox enemy
    set status Conclave ally
    set status Shalonesti
    ]]
dslpnp.highlighter.help["set team"] = [[
    Highlighter Script : Set Team Alias

    Use this command to assign individuals to arbitrary team designations. Team
    names will appear in square brackets before an individual's name, and may
    include color codes. To remove a team designation, set their team to 'none'.

    Syntax:
    set team Jor'Mox {YYinn
    set team Jor'Mox none
    ]]

local defaults = {
    highlight_clanners = true,
    show_clanner_level = false,
    show_kingdom_name = true,
    show_unaffiliated = false,
    show_team = false,
    enemy_sign = "*",
    ally_sign = "+",
    unaffiliated_sign = "^",
    colors = {
        ["Black Robes"] = "dsl_black",
        ["Red Robes"] = "dsl_lt_red",
        ["White Robes"] = "dsl_lt_white",
        ["Bloodlust"] = "dsl_red",
        ["Shalonesti"] = "dsl_green",
        ["Justice"] = "dsl_blue",
        ["Knighthood"] = "dsl_lt_blue",
        ["Shadow"] = "dsl_black",
        ["Slayers"] = "dsl_lt_yellow",
        ["Wargar"] = "dsl_lt_cyan",
        ["Chaos"] = "dsl_black",
        ["Loner"] = "dsl_lt_white",
        ["Renegade"] = "dsl_lt_white",
        ["Dragon"] = "dsl_lt_green",
        ["Demon"] = "dsl_black",
        ["Angel"] = "dsl_lt_white",
        ["Balanx"] = "dsl_blue",
    },
}

local status_info = status_info or {}

local fg_list = {}

local bg_list = {
    ["Black Robes"] = "black",
    ["Red Robes"] = "black",
    ["White Robes"] = "black",
    ["Bloodlust"] = "black",
    ["Shalonesti"] = "black",
    ["Justice"] = "black",
    ["Knighthood"] = "black",
    ["Shadow"] = "black",
    ["Slayers"] = "black",
    ["Wargar"] = "black",
    ["Chaos"] = "black",
    ["Loner"] = "black",
    ["Renegade"] = "black",
    ["Dragon"] = "black",
    ["Demon"] = "black",
    ["Angel"] = "black",
    ["Balanx"] = "black" }

local org_list = {
    "Black Robes",        "Red Robes",    "White Robes",        "Bloodlust",
    "Shalonesti",        "Justice",        "Knighthood",        "Shadow",
    "Slayers",            "Wargar",        "Chaos",            "Loner",
    "Renegade",            "Dragon",        "Demon",            "Angel",
    "Balanx","AR", "VR", "SH", "AL", "NT", "THAX",
    "Abaddon", "Marauders", "Ganth", "Nordmaar", "Darkonin", "Conclave"}

local function find_color(r,g,b)
    local d1,d2,d3, diff, closest, color
    for k,v in pairs(color_table) do
        d1 = r - v[1]
        d2 = g - v[2]
        d3 = b - v[3]
        diff = math.sqrt(d1^2 + d2^2 + d3^2)
        if diff == 0 then
            color = k
            break
        elseif diff <= (closest or diff) then
            closest = diff
            color = k
        end
    end
    return color
end

local function checkName(name)
    local info = dslpnp.people.getInfo(name)
    if not info then
        if string.ends(name,"'s") then
            name = string.sub(name,1,#name-2)
            info = dslpnp.people.getInfo(name)
        end
    end
    if not info then return nil else return name end
end

local function getColors(clan)
    if fg_list[clan] == nil then return false, false
    else return fg_list[clan], bg_list[clan]
    end
end

local function getStatus(org, name)
    local info = dslpnp.people.getInfo(name)
    if info.status == "enemy" then
        return "enemy"
    elseif info.status == "ally" then
        return "ally"
    end
    info = dslpnp.data.highlighter[org]
    if info == "enemy" then
        return "enemy"
    elseif info == "ally" then
        return "ally"
    end
    if string.find(org or "","Robes") then
        info = dslpnp.data.highlighter["Conclave"]
        if info == "enemy" then
            return "enemy"
        elseif info == "ally" then
            return "ally"
        end
    end
    return "neutral"
end

-- Public functions start here

function dslpnp.highlighter.changeStatus(clan, status)
    if dslpnp.highlighter.Active then
        local info, name
        assert(type(clan) == "string", "Invalid clan!")
        clan = string.trim(clan)
        clan = string.gsub(clan,"^'","")
        clan = string.gsub(clan,"'$","")
        if status and not table.contains({"enemy","neutral","ally", ""}, status) then
            print("Invalid status, must be enemy, neutral, or ally.")
            return
        end

        if status == "" then status = nil end
        clan = string.titleAll(clan)
        name = checkName(clan)
        if name then
            if not status then
                info = dslpnp.people.getInfo(name)
                if info.status ~= "enemy" then
                    status = "enemy"
                else
                    status = "neutral"
                end
            end
            dslpnp.people.setInfo(name,{status = status})
        else
            if not status then
                info = status_info[clan]
                if info ~= "enemy" then
                    status = "enemy"
                else
                    status = "neutral"
                end
            end
            status_info[clan] = status
            dslpnp.data.highlighter = status_info
            raiseEvent("saveData","highlighter")
        end
        echo("Status of " .. clan .. " set to " .. status .. ".\n")
    end
end

function dslpnp.highlighter.setTeam(name,team)
    local info
    if string.lower(team) == "none" then team = nil end
    name = checkName(name)
    if name then
        info = dslpnp.people.getInfo(name)
        if team then
            team = dslpnp.support.replaceColors(team)
        end
        info.team = team
        dslpnp.people.setInfo(name,info)
        name = string.title(name)
        if team then
            cecho(name .. " assigned to team " .. team .. "<reset>.")
        else
            echo("Team for " .. name .. " cleared.")
        end
    end
end

local function replaceNames(text,console)
    local configs = dslpnp.highlighter.configs or {}
    local line_num, col_num, r,g,b, color
    local name_count = {}
    local symbols = {enemy = configs.enemy_sign, ally = configs.ally_sign}
    for w in string.gmatch(text, "[A-Z][%a']+%a") do
        local name = checkName(w)
        if name ~= nil then
            color = "reset"
            if console then
                name_count[name] = (name_count[name] or 0) + 1
                col_num = selectString(name,name_count[name])
                if col_num ~= -1 then
                    r,g,b = getFgColor()
                    r = r or 255
                    g = g or 255
                    b = b or 255
                    color = find_color(r,g,b) or "reset"
                    line_num = getLineNumber()
                end
            end
            local info = dslpnp.people.getInfo(name)
            local status = getStatus(info.org,info.name)
            name = name .. (symbols[status] or "")
            if info.org_type == "clan" and configs.highlight_clanners then
                local myfg, mybg = getColors(info.org)
                if configs.show_clanner_level then name = "[" .. info.level .. "] " .. name end
                name = "<" .. myfg .. ">" .. name .. "<reset>"
            elseif info.org_type == "kingdom" and info.org and info.org ~= "" and configs.show_kingdom_name then
                name = "<dsl_lt_cyan>(<dsl_cyan>" .. info.org .. "<dsl_lt_cyan>)<".. color .."> " .. name .. "<reset>"
            elseif info.org_type == "kingdom" and info.org == "" and configs.show_unaffiliated then
                name = "<" .. color .. ">" .. name .. configs.unaffiliated_sign .. "<reset>"
            else
                name = "<" .. color .. ">" .. name .. "<reset>"
            end
            if configs.show_team and info.team then
                name = "<dsl_white>[<reset>" .. info.team .. "<dsl_white>]<reset> " .. name
            end
            if console and col_num ~= -1 then
                replace("")
                moveCursor(col_num,line_num)
                cinsertText(name)
            else
                return name
            end
        end
    end
end

function dslpnp.highlighter.highlight(text)
    return replaceNames(text,false)
end

local function make_aliases()
    if not dslpnp.aliases.exists("Set Status Alias") then
        dslpnp.aliases.register("Set Status Alias", [[^set status ('[a-zA-Z\'\s]+'|[a-zA-Z\']+)\s?((?<=\s)\w+|)]], [[dslpnp.highlighter.changeStatus(matches[2], matches[3])]], true)
    end
    if not dslpnp.aliases.exists("Set Team Alias") then
        dslpnp.aliases.register("Set Team Alias", [[^set team ([a-zA-Z\']+) (.*)$]],[[dslpnp.highlighter.setTeam(matches[2],matches[3])]],true)
    end
end

local function toggle(setVal)
    dslpnp.highlighter.Active = dslpnp.toggle("highlighter",dslpnp.highlighter.Active, setVal)
    if dslpnp.highlighter.Active then
        if dslpnp.aliases.exists("Set Status Alias") then
            dslpnp.aliases.enable("Set Status Alias")
        end
    else
        if dslpnp.aliases.exists("Set Status Alias") then
            dslpnp.aliases.disable("Set Status Alias")
        end
    end
end

local function config()
    dslpnp.highlighter.configs = table.update(defaults,dslpnp.config.highlighter or {})
    fg_list = dslpnp.highlighter.configs.colors
    -- Get any data on clans
    for k,v in ipairs(org_list) do
        status_info[v] = dslpnp.data.highlighter[v]
    end
    -- Clear out any data not on clans
    dslpnp.data.highlighter = status_info
    make_aliases()
    raiseEvent("onToggle","highlighter","on")
end

function dslpnp.highlighter.eventHandler(event, ...)
    if event == "onLine" and dslpnp.highlighter.Active then
        replaceNames(arg[1],true)
    elseif event == "onToggle" and arg[1] == "highlighter" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "highlighter" then
        config()
    end
end

registerAnonymousEventHandler("onLine", "dslpnp.highlighter.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.highlighter.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.highlighter.eventHandler")
