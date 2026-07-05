-- People Script
-- 3/23/2021
-- v4.06a
--

dslpnp.people = dslpnp.people or {}
dslpnp.data.people = dslpnp.data.people or {}
dslpnp.people.configs = dslpnp.people.configs or {}

dslpnp.people.help = {
        [[
        PEOPLE SCRIPT

        The people script is a support script which is meant to be used by other
        scripts in order to pass information gathered from the who list about other
        characters in the game. Nothing special is needed to gather the information,
        which is found and updated whenever you look at any who list or use whois
        on a character.

        The people script also contains the following alias(es):
        <pre>  * show info</pre>
        <pre>  * show cinfo</pre>
        <pre>  * show kinfo</pre>
        <pre>  * show craft</pre>

        It also contains the following public functions and variables:
        <pre>  * people.showInfo()</pre>
        <pre>  * people.addPerson()</pre>
        <pre>  * people.removePerson()</pre>
        <pre>  * people.getInfo()</pre>
        <pre>  * people.setInfo()</pre>
        <pre>  * people.rank_list</pre>
        <pre>  * people.clan_list</pre>
        <pre>  * people.king_list</pre>
        ]],
    ["show info"] = [[
        PEOPLE SCRIPT : Show Info Alias

        show <info/kinfo/cinfo/craft> <name>

        The show info alias works sort of like an "offline" whois and displays the
        information in the following format:
        <pre>[lvl  Race Class] Org Name                            : Last Seen</pre>

        So if you were to use "show info Jor'Mox" you would get the following
        result.
        <pre>[21  Yinn Thi] (TH) Jor'Mox                        : 01-01-1918 12:00:01</pre>

        As an additional note. The show info alias will try to match as many
        targets as it can. So, for instance, "show info a" will grab all of the
        names you have that start with a and display them in the above format,
        followed by the number of characters found.
        ]],
    showInfo = [[
        PEOPLE SCRIPT : dslpnp.people.showInfo(show,name)

        The showInfo() function creates a displayed index of people matching the
        name, and belonging to and organization matching the show-type given.

        Parameters
        <br>
        <pre>show: limited string; not optional;</pre>
        Show is a type-defined string, and matches one of the following:
        <pre>  * kinfo       * cinfo       * info       *craft
        </pre>
        <pre>name: string; not optional</pre>
        Name is the search string. Any string is accepted, the more broad the
        string is, the more results it is likely to match. The more specific
        the string is, the less results it is likely to match.
        ]],
    addPerson = [[
        PEOPLE SCRIPT : dslpnp.people.addPerson(name,info)

        The addPerson() function is used to add characters, and their who-list
        details, to the People database. It does NOT update characters already on
        the list.

        Parameters
        <br>
        <pre>name: string; not optional</pre>
        The name to add to the People database. The name needs to be unique, if it
        is already in the database, addPerson() will do nothing.
        <br>
        <pre>info: table; not optional (needs at least name value)</pre>
        {org_type = "string", org = "string", name = "string", level = 00,
        race = "string", class = "string", craft = "string", craft_rank = "string"}
        The info parameters allow the user to specify information to be placed in
        the database in the entry of the NEW person added to the table.
        <pre>* org_type:   clan or kingdom</pre>
        <pre>* org:        name of the character's organization</pre>
        <pre>* name:       character name, properly formatted name, as the name</pre>
        <pre>              parameter for the function is made lower-case (Jor'Mox</pre>
        <pre>              instead of jor'mox)</pre>
        <pre>* level:      current character level (1-51)</pre>
        <pre>* race:       the race of the character (as seen on who list, s-elf,</pre>
        <pre>              m-dwarf, yinn, hum, etc...)</pre>
        <pre>* class:      the current character class (as seen on who list, clr, pri,</pre>
        <pre>              sam, cru, brd, etc...)</pre>
        <pre>* craft:      the current character craft (as seen on who craft, Miller,</pre>
        <pre>              Spellcrafter, Weaponsmith (Sharp), etc...)</pre>
        <pre>* craft_rank: the current character's craft rank (as seen on who craft,</pre>
        <pre>              Journeyman, Legendary Grand Master, Senior, etc...)</pre>
        ]],
    removePerson = [[
        PEOPLE SCRIPT : dslpnp.people.removePerson(name)

        The removePerson() function removes an already existing character from the
        People database. All information is dropped when this function is used.

        Parameters
        <br>
        <pre>name: string; not optional</pre>
        The name of the character you wish to remove from the database. If the
        person is not in the database, the function does nothing.
        ]],
    getInfo = [[
        PEOPLE SCRIPT : dslpnp.people.getInfo(name,info)

        The getInfo() function returns a table with the information requested about
        the character specified.

        Parameters
        <br>
        <pre>name: string; not optional</pre>
        The name of the character you wish to gather information on. If the person
        is not in the database, the function will do nothing.
        <br>
        <pre>info: string; optional</pre>
        This will return either all info on the named character if no argument is provided
        or return the indicated value from the info table. (see addPerson entry for info parameters)
        ]],
    setInfo = [[
        PEOPLE SCRIPT : dslpnp.people.setInfo(name, info)

        The setInfo() function allows a user to update character already existing in
        the People database.

        Parameters
        <br>
        <pre>name: string; not optional</pre>
        The name of the character whose information you wish to change. The
        character must already exist or setInfo() will do nothing. The name is
        case insensitive.
        <br>
        <pre>info: table; not optional, at least one parameter.</pre>
        The info table provided to this function represents the information about
        the provided character that you wish to update. Only the parameters
        specified in the table passed will be updated.  (see addPerson entry for
        info parameters)
        ]],
    rank_list =[[
        PEOPLE SCRIPT : dslpnp.people.rank_list

        The rank_list variable keeps track of ranks, so that they are not added as
        characters by the auto-update from the who-list. If you notice a rank is
        added as a character, it can be added to the list the script checks for by
        adding it to dslpnp.config.people{ title = ".." } in the Config Script.
        ]],
    clan_list =[[
        PEOPLE SCRIPT : dslpnp.people.clan_list

        A complete list of clans recognized by the People script. If a new clan is
        added, you may alter the list with the new clan's name until the script is
        updated.
        ]],
    king_list =[[
        PEOPLE SCRIPT : dslpnp.people.king_list

        A complete list of kingdoms recognized by the People script. If a new
        kingdom is added, you may alter the list with the new kingdom's name
        until the script is updated.
        ]],
    version =[[
        PEOPLE SCRIPT : Version
        <br>
        <pre>Current version: 4.05d</pre>
        Updated: 9/11/2016

        Change notes:
        <pre>* Help files:</pre>
        <pre>  > Added the following help files... </pre>
        <pre>    - showInfo   - addPerson   - removePerson</pre>
        <pre>    - getInfo    - setInfo     - rank_list</pre>
        <pre>    - clan_list  - king_list   - version</pre>
        <pre>* Error checking added to global functions.</pre>
        ]],
}

dslpnp.people.rank_list = {
    "Abbott",          "Academic",        "Acolyte",         "Actuary",
    "Adept",           "Admiral",         "Advisor",         "Ambassador",
    "Anchor",          "Apprentice",      "Arachnos",        "Arcanist",
    "Archduke",        "Architect",       "Archivist",       "Archmage",
    "Archmagus",       "Archon",          "Artificer",       "Artist",
    "Aspirant",        "Axebearer",       "Baron",           "Baroness",
    "Bayim",           "Bishop",          "Bleakborn",       "Bloodmage",
    "Boss",            "Brother",         "Brute",           "Butcher",
    "Cabin Person",    "CabinPerson",     "Cadet",           "Caliph",
    "Captain",         "Cardinal",        "Castellan",       "Centurion",
    "Champion",        "Chancellor",      "Chaplain",        "Chevalier",
    "Chieftan",        "Chronicler",      "Citizen",         "Cityguard",
    "Cleaver",         "Commander",       "Commoner",        "Conjuress",
    "Corporal",        "Count",           "Countess",        "Coxswain",
    "Crewman",         "Crownguard",      "Cultist",         "Culturalist",
    "Curate",          "Dame",            "Deacon",          "Deathlord",
    "Deathwarden",     "Deckhand",        "Defender",        "Devotee",
    "Digger",          "Disciple",        "Dread",           "Dreadlord",
    "Duchess",         "Duke",            "Earl",            "Elder",
    "Eliteguard",      "Emissary",        "Emperor",         "Emporer",
    "Ensign",          "Enslaver",        "Entertainer",     "Executioner",
    "Fallah",          "First-sworn",     "Fodder",          "Forerunner",
    "Freebooter",      "Gardener",        "General",         "Gladiator",
    "Godsworn",        "Grand-templar",   "Grunt",           "Guard",
    "Guardian",        "Guardsman",       "Harbinger",       "Headmaster",
    "Healer",          "Hellraiser",      "Hierophant",      "High",
    "High_mystic",     "Hollow",          "Honorable",       "Infernalist",
    "Initiate",        "Inquisitor",      "Instructor",      "Jaddah",
    "Journeyman",      "Jujumaster",      "Jujumon",         "King",
    "Knight",          "Kuldjargh",       "Lady",            "Laureate",
    "Legend",          "Librarian",       "Lich",            "Lich",
    "Lieutenant",      "Longbeard",       "Lord",            "Loremaster",
    "Maestro",         "Magistrate",      "Magus",           "Marine",
    "Marksman",        "Marquess",        "Marshal",         "Masrur",
    "Master",          "Master",          "Merchant",        "Merchant",
    "Midshipman",      "Minion",          "Minion",          "Minister",
    "Minstrel",        "Mistress",        "Monsignor",       "Monster",
    "Muse",            "Mystic",          "Najmuddin",       "Nameless",
    "Navigator",       "Neophyte",        "Noble",           "Notorious",
    "Novice",          "Novitiate",       "Oathsworn",       "Oathsworn",
    "Overseer",        "Pastor",          "Peddler",         "Petitioner",
    "Pilgrim",         "Pirate",          "Pontifex",        "Pontiff",
    "Postulant",       "Precursor",       "Prefect",         "Prelate",
    "Priest",          "Prince",          "Princess",        "Private",
    "Privateer",       "Proctor",         "Protector",       "Pupil",
    "Quarlani",        "Quartermaster",   "Queen",           "Queensguard",
    "Raider",          "Reaver",          "Recruit",         "Regent",
    "Renown",          "Researcher",      "Revenant",        "Ritualist",
    "Sage",            "Sailor",          "Samaritan",       "Savant",
    "Sayer",           "Sayyid",          "Sayyida",         "Scholar",
    "Scourge",         "Scout",           "Scribe",          "Seacurr",
    "Seadog",          "Seeker",          "Seer",            "Senator",
    "Seneschal",       "Sentinel",        "Sergeant",        "Servant",
    "Shade",           "Shortbeard",      "Sir",             "Sister",
    "Slave",           "Sojourner",       "Soldier",         "Songkeeper",
    "Songmaster",      "Sorcerer",        "Sorceress",       "Sorceror",
    "Speaker",         "Specialist",      "Spiritualist",    "Sprite",
    "Squib",           "Steward",         "Student",         "Sultan",
    "Sultana",         "Supreme",         "Swab",            "Swabbie",
    "Sworn",           "Templar",         "Thamaturge",      "Thane",
    "Thrall",          "Titan",           "Trader",          "Trainee",
    "Treasurer",       "Trooper",         "Underling",       "Urchin",
    "Vanguard",        "Veteran",         "Viscount",        "Viscountess",
    "Vizier",          "Warden",          "Warder",          "Warlord",
    "Warmaster",       "Watcher",         "Wizardess",       "Worm",
    "Wraith",          "Ghosts",          "Thaumaturge",     "Armorer",
    "Mumin",           "Warmage",         "Jihadin",         "Commissioner",
    "Faithful",        "Roper",           "Subcommander",    "Agent",
    "Page",            "Devout",          "Ghede",           "Javidan",
    "Ironborn",        "Tyro",            "Undertaker",      "Wizard",
    "Conjurer",        "Scholarch",       "Muhtasib",
}

dslpnp.people.king_list = {
    "AR", "VR", "SH", "AL", "NT", "THAX",
    "Abaddon", "Marauders", "Ganth", "Nordmaar", "Darkonin", "Gray Church", "Retired",
    Verminasia = "VR", Thaxanos = "THAX", Althainia = "AL",
    Arkane = "AR", ["New Thalos"] = "NT", Shalonesti = "SH", Retired = "Retired",
}

dslpnp.people.craft_list = {
    "Miner", "Lumberjack", "Hunter", "Smelter", "Miller", "Tanner",
    "Spellcrafter", "Tailor", "Armorcrafter", "Weaponsmith (Blunt)",
    "Weaponsmith (Sharp)"
}

dslpnp.people.clan_list = {
    "Black Robes",      "Red Robes",    "White Robes",      "Bloodlust",
    "Shalonesti",       "Justice",      "Knighthood",       "Shadow",
    "Slayers",          "Wargar",       "Chaos",            "Loner",
    "Renegade",         "Dragon",       "Demon",            "Angel",
    "Balanx",
}

local craft_ranks = {
    ["Helper"] = 1,
    ["Junior Apprentice"] = 2,
    ["Apprentice"] = 3,
    ["Neophyte"] = 4,
    ["Assistant"] = 5,
    ["Junior"] = 6,
    ["Journeyman"] = 7,
    ["Senior"] = 8,
    ["Master"] = 9,
    ["Grand Master"] = 10,
    ["Legendary Grand Master"] = 11}

local trigger_patterns = {
    [[^\[\s?(\d+)\s+([\w\-]+)\s+(\w+)\]\s*(?:\[AFK\]\s?)?(?:\[Quiet\]\s?)?(?:\(WANTED\)\s?)?(?:\(([\w\s]+)\))* ([\w\s\-']+)]],
    [[^\[\s?(\d+)() (\w+)\] (?:\(\w+\))*\((\w+)\)\s+([\w\s']+)]],
    [[^\[\s?(\d+)\s+([\w\-]+)\s+(\w+)\] (?:\[(?:AFK|Quiet)\]\s+)*[\[\(] ([\w\s]+)[\s\*]+[\]\)]\s?(?:\((?:Hostile|WANTED)\)\s+)*([\w\s\-']+)]],
    [[^\[\s?(\d+)() (\w+)\] [\(\[] ([\w\s]+)[\s\*]+[\]\)]\s+([\w']+)]],
    [[^([\w\']+) \- ([\w\s]+) (Spellcrafter|Armorcrafter|Tailor|Weaponsmith \(Blunt\)|Weaponsmith \(Sharp\)|Smelter|Tanner|Miller|Miner|Hunter|Lumberjack)]]}

local trigger_codes = {
    [[raiseEvent("onGatherPerson","kingdom",unpack(matches,2))]],
    [[raiseEvent("onGatherPerson","kingdom",unpack(matches,2))]],
    [[raiseEvent("onGatherPerson","clan",unpack(matches,2))]],
    [[raiseEvent("onGatherPerson","clan",unpack(matches,2))]],
    [[raiseEvent("onGatherPerson","craft",unpack(matches,2))]]}

local trigger_tbl = trigger_tbl or {}
local alias_tbl = alias_tbl or {}
local save_data = false

local defaults = {
    use_database = false,
    name_width = 40,
    show_names = 30,
    update_col = "<dsl_lt_yellow>",
    add_col = "<dsl_lt_red>",
    clan_colors = {
        ["Black Robes"] = "<dsl_black>",    ["Red Robes"] = "<dsl_lt_red>",     ["White Robes"] = "<dsl_lt_white>",
        ["Bloodlust"] = "<dsl_red>",        ["Shalonesti"] = "<dsl_green>",     ["Justice"] = "<dsl_blue>",
        ["Knighthood"] = "<dsl_lt_blue>",   ["Shadow"] = "<reset>",             ["Slayers"] = "<dsl_lt_yellow>",
        ["Wargar"] = "<dsl_lt_cyan>",       ["Chaos"] = "<dsl_black>",          ["Loner"] = "<dsl_lt_white>",
        ["Renegade"] = "<dsl_lt_white>",    ["Dragon"] = "<dsl_lt_green>",      ["Demon"] = "<dsl_black>",
        ["Angel"] = "<dsl_lt_white>",       ["Balanx"] = "<dsl_lt_blue>",
    },
    titles = {}
}

local function format_person_info(info,craft)
    local configs = dslpnp.people.configs
    local text
    if not craft then
        text = string.format("[%2d %6s %3s] ", info.level or "", info.race or "", info.class or "")
        if info.org_type == "clan" then
            text = text .. "[ " .. configs.clan_colors[info.org] .. info.org .. "<reset> ] " .. string.format("%-" .. configs.name_width - #info.org - 5 .."s",info.name)
        elseif info.org_type == "kingdom" then
            if info.org and info.org ~= "" then
                text = text .. "<dsl_lt_cyan>(<dsl_cyan>" .. info.org .. "<dsl_lt_cyan>)<reset> " .. string.format("%-" .. configs.name_width - #info.org - 3 .."s",info.name)
            else
                text = text .. string.format("%-" .. configs.name_width .. "s",info.name)
            end
        end
    else
        text = string.format("[%2s] %s - %s %s",info.level or "", info.name or "", info.craft_rank or "", info.craft or "")
        text = string.format("%-60s",text)
    end
    text = text .. " : " .. os.date("%c", info.last_seen._timestamp)
    return "\n" .. text
end

function dslpnp.people.showInfo(show,name)
    if dslpnp.people.Active then
        if not name or name == "" then
            error("showInfo: invalid name to be searched for.",2)
        end
        if not table.contains({"info","kinfo","cinfo","craft"},show) then
            error("showInfo: invalid show string, must be kinfo, cinfo, info, or craft.",2)
        end
        local configs = dslpnp.people.configs
        local text, index = "", 0
        local info = {}
        local org_type
        name = string.lower(name)
        if show == "kinfo" then
            org_type = "kingdom"
            for k,v in pairs(dslpnp.people.king_list) do
                if string.starts(string.lower(k), name) then
                    name = v
                    break
                end
            end
        elseif show == "cinfo" then
            org_type = "clan"
            if string.starts("conclave",string.lower(name)) then
                dslpnp.people.showInfo(show,"White Robes")
                dslpnp.people.showInfo(show,"Red Robes")
                dslpnp.people.showInfo(show,"Black Robes")
                return
            end
        end

        if configs.use_database then name = name .. "%" end
        if show == "info" then
            if configs.use_database then
                info = db:fetch(dsl_db.people,db:like(dsl_db.people.name,name),{dsl_db.people.level},true)
            else
                for k,v in pairs(dslpnp.data.people) do
                    if string.starts(string.lower(v.name),name) then
                        table.insert(info,v)
                    end
                end
            end
        elseif show ~= "craft" then
            if configs.use_database then
                info = db:fetch(dsl_db.people,{db:like(dsl_db.people.org,name),db:eq(dsl_db.people.org_type,org_type)},{dsl_db.people.level},true)
            else
                name = string.lower(name)
                for k,v in pairs(dslpnp.data.people) do
                    if v.org_type == org_type and string.starts(string.lower(v.org),name) then
                        table.insert(info,v)
                    end
                end
            end
        else
            if configs.use_database then
                info = db:fetch(dsl_db.people,db:like(dsl_db.people.craft,name),{dsl_db.people.level},true)
            else
                name = string.lower(name)
                for k,v in pairs(dslpnp.data.people) do
                    if v.craft and string.starts(string.lower(v.craft),name) then
                        table.insert(info,v)
                    end
                end
            end

            local function sort_craft(a,b)
                if b and craft_ranks[a.craft_rank] > craft_ranks[b.craft_rank] then
                    return true
                end
                return false
            end

            table.sort(info,sort_craft)
        end
        index = 0
        for k,v in pairs(info) do
            if configs.show_names == "all" or v.last_seen._timestamp > os.time() - configs.show_names * 86400 then
                if show == "craft" then
                    text = format_person_info(v,true)
                else
                    text = format_person_info(v)
                end
                index = index + 1
                cecho(text)
            end
        end
        echo("\n\nPlayers found: " .. index .. "\n")
    end
end

function dslpnp.people.addPerson(name,info)
    if dslpnp.people.Active then
        if not name or name == "" then
            error("addPerson: invalid name to add.",2)
            -- Put check here for name already existing.
        end
        if not info.name then
            error("addPerson: invalid info table, you need at least the character's name (info.name) to add someone.",2)
        end
        local configs = dslpnp.people.configs
        if configs.use_database then
            if table.is_empty(db:fetch(dsl_db.people,db:eq(dsl_db.people.name,name,true))) then
                db:add(dsl_db.people, info)
                cecho(" : ".. configs.add_col .. info.name .. " added.")
                info = db:fetch(dsl_db.people,db:eq(dsl_db.people.name,name,true))[1]
                info.last_seen = db:Timestamp(getTime())
                db:update(dsl_db.people,info)
            end
        else
            name = string.lower(name)
            info.last_seen = db:Timestamp(getTime())
            if not dslpnp.data.people[name] then
                dslpnp.data.people[name] = info
                save_data = true
                cecho(" : ".. configs.add_col .. info.name .. " added.")
            end
        end
    end
end

function dslpnp.people.removePerson(name)
    if dslpnp.people.Active then
        if not name or name == "" then
            error("removePerson: invalid name to remove.",2)
        end
        local configs = dslpnp.people.configs
        if configs.use_database then
            db:delete(dsl_db.people,db:eq(dsl_db.people.name,name,true))
        else
            dslpnp.data.people[string.lower(name)] = nil
        end
    end
end

function dslpnp.people.getInfo(name, info)
    if dslpnp.people.Active then
        if not name or name == "" then
            error("getInfo: invalid name.",2)
        end
        if info and not table.contains({"org_type","org","name","level","class","race","craft","craft_rank"},info) then
            error("getInfo: invalid info category, must be nil or one of: org_type, org, name, level, class, race, craft, or craft_rank",2)
        end
        local configs = dslpnp.people.configs
        local infoTbl = {}
        if configs.use_database then
            infoTbl = db:fetch(dsl_db.people,db:eq(dsl_db.people.name,name,true))[1]
        else
            infoTbl = dslpnp.data.people[string.lower(name)] or nil
        end
        if infoTbl and infoTbl[info] then
            return infoTbl[info]
        else
            return infoTbl
        end
    end
end

function dslpnp.people.setInfo(name, info)
    if dslpnp.people.Active then
        if not name or name == "" then
            error("setInfo: invalid name to be updated.",2)
        end
        if #info > 1 then
            error("setInfo: You need at least one valid info table entry to update.",2)
        end
        local configs = dslpnp.people.configs
        local data
        name = string.lower(name)
        if configs.use_database then
            data = db:fetch(dsl_db.people,db:eq(dsl_db.people.name,name,true))[1]
        else
            data = dslpnp.data.people[name]
        end
        data = table.update(data,info)
        if configs.use_database then
            db:update(dsl_db.people,data)
        else
            dslpnp.data.people[name] = data
        end
    end
end

local function parse_name(name)
    -- Remove words from rank list
    for i, v in ipairs(dslpnp.people.rank_list) do
        name = string.gsub(name, v .. " ", "")
    end
    -- Remove leading and trailing spaces
    name = string.trim(name)
    -- Remove everything but the first word
    name = string.gsub(name,"^([%w']+).*","%1")
    return name
end

local function gather_info(org_type,lvl,race,class,org,name)
    local configs = dslpnp.people.configs
    local new = {}
    -- Ignoring Imms
    if not tonumber(lvl) or tonumber(lvl) < 52 then
        if org_type ~= "craft" then
            -- Make sure the organization is one of those listed
            if org_type == "clan" then
                if not table.contains(dslpnp.people.clan_list,org) then return end
            elseif org_type == "kingdom" then
                if org ~= "" and not table.contains(dslpnp.people.king_list,org) then return end
            end
            -- Filter out rank and title words, then grab first word as name
            name = parse_name(name)
            -- Replace long versions of kingdom names with short versions
            if org_type == "kingdom" and org ~= "" then
                org = dslpnp.people.king_list[org] or org
            end
            -- Assemble new info on named person
            new = {name = name, level = lvl, race = race, class = class, org = org, org_type = org_type}
            -- Remove empty data from list
            for k,v in pairs(new) do
                if v == "" and k ~= "org" then new[k] = nil end
            end
        else -- read in data from whocraft
            name = lvl
            rank = race
            craft = class
            new = {name = name, craft_rank = rank, craft = craft}
        end
        -- Get current info on named person
        name = string.lower(name)
        local info
        if configs.use_database then
            info = db:fetch(dsl_db.people, db:eq(dsl_db.people.name,new.name))
            if not table.is_empty(info) then info = info[1] end
        else
            info = dslpnp.data.people[name] or {}
        end
        if table.is_empty(info) then
            dslpnp.people.addPerson(name,new)
        else
            local updated = table.complement(new,info)
            if not table.is_empty(updated) then
                info = table.update(info,new)
                cecho(" : ".. configs.update_col .. new.name .. " updated.")
                raiseEvent("peopleUpdate",dslpnp.support.unpack(updated))
            end
            info.last_seen = db:Timestamp(getTime())
            if configs.use_database then
                db:update(dsl_db.people, info)
            else
                dslpnp.data.people[name] = info
                save_data = true
            end
        end
    end
end

local function config()
    -- Load configs from Config script
    local configs = table.update(defaults,dslpnp.config.people or {})
    dslpnp.people.configs = configs
    dslpnp.people.rank_list = table.n_union(dslpnp.people.rank_list, configs.titles)
    for k,v in ipairs(dslpnp.people.rank_list) do
        if string.find(v,"-",1,true) and not string.find(v,"%-",1,true) then
            dslpnp.people.rank_list[k] = string.gsub(v,"%-","%%-")
        end
    end
    -- set this so that functions work properly to import old data
    dslpnp.people.Active = true
    -- Clear out any records using a listed rank as a name
    for k,v in ipairs(dslpnp.people.rank_list) do
        dslpnp.people.removePerson(v)
    end
    for k,v in ipairs(trigger_tbl) do
        killTrigger(v)
    end
    -- Create triggers to capture info on people
    for k,v in ipairs(trigger_patterns) do
        if not dslpnp.triggers.exists("People Trigger "..k) then
            dslpnp.triggers.register("People Trigger "..k,"regex",v,trigger_codes[k], true)
        end
    end
    if not dslpnp.aliases.exists("Show Info Alias") then
        dslpnp.aliases.register("Show Info Alias", "^show (craft|[ck]?info) ([\\w']+)","dslpnp.people.showInfo(matches[2],matches[3])", true)
    end
    -- Turn script on
    raiseEvent("onToggle","people","on")
end

local function toggle(setVal)
    -- Call toggle function to set on or off status for script
    dslpnp.people.Active = dslpnp.toggle("people",dslpnp.people.Active, setVal)
    if dslpnp.people.Active then
        -- Enable Triggers if on
        for k,v in ipairs(trigger_tbl) do
            dslpnp.triggers.enable(v)
        end
    else
        -- Disable Triggers if not
        for k,v in ipairs(trigger_tbl) do
            dslpnp.triggers.disable(v)
        end
    end
end

function dslpnp.people.eventHandler(event, ...)
    if event == "onGatherPerson" and dslpnp.people.Active then
        -- Pass info from triggers on to function for handling
        gather_info(unpack(arg))
    elseif event == "onPrompt" and dslpnp.people.Active and save_data then
        save_data = false
        raiseEvent("saveData","people")
    elseif event == "onToggle" and arg[1] == "people" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "people" then
        config()
    end
end

registerAnonymousEventHandler("onGatherPerson","dslpnp.people.eventHandler")
registerAnonymousEventHandler("onPrompt", "dslpnp.people.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.people.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.people.eventHandler")
