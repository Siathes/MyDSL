-- Affects : Respell Script
-- 2/09/2017
-- v4.00b
--

dslpnp.affects.respell = dslpnp.affects.respell or {}
dslpnp.affects.respell.help = [[
Affects : Respell

This script provides a single alias, that is used to recast tracked spells that
are no longer affecting you, as well as a list of spells given. Spells can also
be listed to not recast. Here is an example:

Tracked spells: Sanctuary, Haste, Pass Door, Fly
Command: respell protection evil,!sanctuary

This will recast any of haste, pass door, fly, and protection evil if they are
not currently affecting you, while not casting any of the ones that are.
]]

local songs_list = dslpnp.affects.songs_list
local skills_list = dslpnp.affects.skills_list

local function parseSpellList(spells)
    -- Adjusted to handle nil values and to accept any number of spaces around dividing commas
    local list = (spells and string.split(string.trim(spells), "%s*,%s*")) or {}
    local newList = {}

    for k,v in ipairs(list) do
        if string.starts(v,"!") then
            -- Simpler removal of leading !, used -1 for negated spells for simpler later comparisons
            newList[string.sub(v,2)] = -1
        else
            newList[v] = 0
        end
    end
    return newList
end

function dslpnp.affects.respell.cast(nospell)
    if dslpnp.affects.respell.Active then
        nospell = (nospell ~= "" and nospell) or nil
        local spellList = parseSpellList(nospell)
        local tracked = dslpnp.character.getCharData("trackedAffects") or {}
        local check, time
        -- Combining spellList and trackedAffects list
        for k,v in pairs(tracked) do
            if v and not spellList[k] then
                spellList[k] = 0
            end
        end

        for k,v in pairs(spellList) do
            if v ~= -1 then
                check, time = dslpnp.affects.findAffect(k)
                -- Check if affect is on list, and if present, must have no time left
                if not check or time < 0 then
                    v = 1
                end
            end
            -- Remove spells not to be re-cast
            spellList[k] = ((v > 0) and v) or nil
        end

        for k,v in pairs(spellList) do
            if v == 1 then
                if table.contains(songs_list,k) then
                    send("sing '"..k.."'")
                elseif table.contains(skills_list,k) then
                    send(k)
                else
                    send("cast '"..k.."'")
                end
            end
        end
    end
end

local function toggle(setVal)
    dslpnp.affects.respell.Active = dslpnp.toggle("affects : respell",dslpnp.affects.respell.Active, setVal)
    if dslpnp.affects.respell.Active then
        if dslpnp.aliases.exists("Affects Respell Alias") then dslpnp.aliases.enable("Affects Respell Alias") end
    else
        if dslpnp.aliases.exists("Affects Respell Alias") then dslpnp.aliases.disable("Affects Respell Alias") end
    end
end

local function config()
    if exists("Affects Respell Alias", "alias") == 0 then
        dslpnp.aliases.register("Affects Respell Alias",[[^respell(.*)$]],[[dslpnp.affects.respell.cast(matches[2])]],true)
    end
    raiseEvent("onToggle","affects.respell","on")
end

function dslpnp.affects.respell.eventHandler(event,...)
    if event == "onConfig" and arg[1] == "affects.respell" or arg[1] == "respell" then
        config()
    elseif event == "onToggle" and arg[1] == "affects.respell" or arg[1] == "respell" then
        toggle(arg[2])
    end
end

registerAnonymousEventHandler("onConfig","dslpnp.affects.respell.eventHandler")
registerAnonymousEventHandler("onToggle","dslpnp.affects.respell.eventHandler")
