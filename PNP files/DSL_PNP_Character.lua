-- Character Script
-- 2/23/2016
-- v4.01e
--

dslpnp.character = dslpnp.character or {}
dslpnp.data.character = dslpnp.data.character or {}

dslpnp.character.help = dslpnp.character.help or {}
dslpnp.character.help[1] = [[
    Character Script

    The Character Script is one of the core scripts of the DSL PNP structure and allows
    for many other scripts to store data individualized to each character. Furthermore,
    the Character Script stores data relevant to each character which can be accessed
    via global functions for the purposes of your own scripts, triggers, aliases, timers,
    keys and buttons.
]]

dslpnp.character.help.getchardata = [[
    dslpnp.character.getCharData(key, index)

    key: A string for the specific character data we're trying to retrieve, e.g. "name"
    index: an optional argument which will help us search for a key nested within another
           table. e.g. "arm" when you use a key of "eq_table"

    The getCharData() function has a fairly straightforward use: retrieving data and
    returning it for your own use in various functions, whether it be for scripts
    or just simple aliases, keys, buttons or triggers.

    For instance, local c = dslpnp.character.getCharData("name") is often used
    in order to distinguish which character is currently being played. Perfect for
    scripts, aliases and triggers which need to do different things based on the
    character, such as whether or not they want to quaff a potion or cast a spell.

    You can use the index argument to access data stored in tables. Referencing the
    earlier example, we can use local arm = dslpnp.character.getCharData("eq_table","arm")
    in order to get information on what is currently being worn in the arm slot of
    our current character.
]]


local defaults = {
    alert_on_name = true
    }

local curChar = curChar or {}

local function loadChars()
    dslpnp.data.character = dslpnp.data.character or {}
    local data = dslpnp.data.character or {}
    if not table.is_empty(curChar) and curChar.name then
        raiseEvent("saveData","character")
    end
end

local function saveChars()
    if not table.is_empty(curChar) and curChar.name then dslpnp.data.character[curChar.name] = curChar end
    if not dslpnp.timers.exists("Save Char Data Timer") then
        dslpnp.timers.register(1,[[raiseEvent("saveData","character")]],"Save Char Data Timer")
    end
end

local function clearChar(name)
    assert(type(name) == "string", "Invalid name!")
    dslpnp.data.character[name] = {}
    curChar = {}
    raiseEvent("saveData","character")
end

local function checkChar()
    if curChar.name then return true else return false end
end

local function displayChar()
    if curChar.name then
        echo(" : Current character: " .. curChar.name)
    else
        echo(" : No character loaded.\n")
    end
end

local function getScore(...)
    local prev_char = curChar.name or nil
    local info = {}
    for k = 1,#arg - 1, 2 do
        info[arg[k]] = arg[k+1]
    end

    curChar = dslpnp.data.character[info.name or prev_char] or {}
    curChar.blind = false
    if info.name then curChar.name = info.name end
    if info.level then curChar.level = tonumber(info.level) end
    if info.race then curChar.race = info.race end
    if info.hours then curChar.hours = tonumber(info.hours) end
    if info.class then curChar.class = info.class end
    if info.reclass then
        curChar.reclass = info.reclass
        saveChars()
    end
    if prev_char and prev_char ~= curChar.name or not prev_char then
	    if not dslpnp.data.character[curChar.name] then
	        dslpnp.data.character[curChar.name] = curChar
	    end
        raiseEvent("characterLoaded",curChar.name)
    end
end

function dslpnp.character.getCharData(key, index)
    if dslpnp.character.Active then
        if type(key) ~= "string" then error("Invalid key!",2) end
        local data
        if index then
            curChar[key] = curChar[key] or {}
            data = curChar[key][index]
        else
            data = curChar[key]
        end
        if type(data) == "table" then
            data = table.copy(data)
        end
        return data
    end
end

function dslpnp.character.setCharData(value, key, index)
    if dslpnp.character.Active then
        if value == nil then error("Invalid value!",2) end
        if type(key) ~= "string" then error("Invalid key!",2) end
        if index then
            curChar[key] = curChar[key] or {}
            curChar[key][index] = value
        else
            curChar[key] = value
        end
        saveChars()
    end
end

function dslpnp.character.clearCharData(key, index)
    if dslpnp.character.Active then
        if type(key) ~= "string" then error("Invalid key!",2) end
        if index then
            curChar[key] = curChar[key] or {}
            curChar[key][index] = nil
        else
            curChar[key] = nil
        end
        saveChars()
    end
end

function dslpnp.character.getLevel()
    return curChar["level"]
end

local function make_triggers()
    local trigger_text
    if not dslpnp.triggers.exists("Level Gain Trigger") then
        trigger_text = [[You raise a level!!  You gain (\d+) hit points, (\d+) mana, (\d+) move, and (\d+) practices\.]]
        dslpnp.triggers.register("Level Gain Trigger", "regex", trigger_text, [[raiseEvent("onLevel", matches[2], matches[3], matches[4], matches[5])]], true)
    end
    trigger_text = {[[^Score for ([\w\']+).*.$]],
        [[^LEVEL: (\d+) \s+ Race : (\w+[\s]?\w+) \s+ Played: (\d+) hours]],
        [[^YEARS: \d+ \s+ Class: (\w+[\s]?\w+) \s+ Log In:]],
        [[^SEX  : \w+ \s+ Reclass@: (\w+)]]}
    if not dslpnp.triggers.exists("Character Trigger 1") then
        dslpnp.triggers.register("Character Trigger 1", "regex", trigger_text[1], [[raiseEvent("onScore", "name", matches[2])]], true)
        dslpnp.triggers.register("Character Trigger 2", "regex", trigger_text[2], [[raiseEvent("onScore", "level", matches[2], "race", matches[3], "hours", matches[4])]], true)
        dslpnp.triggers.register("Character Trigger 3", "regex", trigger_text[3], [[raiseEvent("onScore", "class", matches[2])]], true)
        dslpnp.triggers.register("Character Trigger 4", "regex", trigger_text[4], [[raiseEvent("onScore", "reclass", matches[2])]], true)
    end
    if not dslpnp.triggers.exists("Login Trigger") then
        trigger_text = [[^WELCOME TO DARK & SHATTERED LANDS \(DSL\)]]
        dslpnp.triggers.register("Login Trigger","regex", trigger_text, "dslpnp.character.login = true", true)
    end
    if not dslpnp.triggers.exists("Whoami Trigger") then
        trigger_text = [[You are logged in as:\s+(.*)$]]
        dslpnp.triggers.register("Whoami Trigger","regex", trigger_text, [[raiseEvent("onScore", "name", matches[2])]],true)
    end
end

local function toggle(setVal)
    dslpnp.character.Active = dslpnp.toggle("character", dslpnp.character.Active, setVal)
    if dslpnp.character.Active then

    else

    end
end

local function config()
    make_triggers()
    raiseEvent("onToggle","character","on")
    curChar = {}
end

function dslpnp.character.eventHandler(event, ...)
    if event == "onPrompt" and dslpnp.character.Active then
        if dslpnp.character.login then
            dslpnp.character.login = false
            send("whoami",false)
        elseif not checkChar() then
            send("whoami",false)
        end
    elseif event == "onLevel" and dslpnp.character.Active and checkChar() then
        curChar.level = curChar.level + 1
        saveChars()
    elseif event == "onScore" and dslpnp.character.Active then
        getScore(unpack(arg))
    elseif event == "onToggle" and arg[1] == "character" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "character" then
        config()
    end
end

registerAnonymousEventHandler("onScore", "dslpnp.character.eventHandler")
registerAnonymousEventHandler("onPrompt", "dslpnp.character.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.character.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.character.eventHandler")
registerAnonymousEventHandler("onLevel", "dslpnp.character.eventHandler")
