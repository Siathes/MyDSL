-- Battle Condenser Script
-- 3/29/2018
-- v4.03h
--
-- Special Thanks to Gnome Power for all his work on this script
-- To Do: make script handle change to weapon flags display text
-- Type "toggle battle" to disable or enable this script.
--

-- Trigger Pattern
-- ^(You|[\w\-\s,']+?)(?:(?<=You)r|'s) ([a-zA-Z\s]+?) (?:does|[\>\<\=\*]*)\s?(m(?:a(?:ul|im)|iss)|de(?:cim|vast)ate|scratch|(?:graz|injur)e|hit|wound|H(?:ORRID|IDEOUS)|D(?:IS(?:EMBOWEL|MEMBER)|E(?:MOLISH|VASTATE)|READFUL)|M(?:A(?:SSACR|NGL)E|UTILATE)|GHASTLY|(?:(?:INDESCRIB|UNSPEAK)ABL|(?:OBLITER|ANNIHIL|ERADIC)AT)E)[esES]*\s?(?:things to|[\>\<\=\*]*) ([\w\-\s,']+)([\.!]+)$
-- Better pattern?
-- ^(You|[\w\-\s,']+?)(?:(?<=You)r|'s)?(?: ([\w\s]+?))?(?: do[es]*| [\>\<\=\*]*)(m(?:a(?:ul|im)|iss)|de(?:cim|vast)ate|scratch|(?:graz|injur)e|hit|wound|H(?:ORRID|IDEOUS)|D(?:IS(?:EMBOWEL|MEMBER)|E(?:MOLISH|VASTATE)|READFUL)|M(?:A(?:SSACR|NGL)E|UTILATE)|GHASTLY|(?:(?:INDESCRIB|UNSPEAK)ABL|(?:OBLITER|ANNIHIL|ERADIC)AT)E)[esES]*(?: things to| [\>\<\=\*]+|) ([\w\-\s,']+)([\.!]+)$

dslpnp.battle = dslpnp.battle or {}
dslpnp.battle.rage_info = {damage = 0, vamp = 0}

dslpnp.battle.help = {
    [[
    Battle Script

    The Battle Condenser Script allows customization of the text seen during combat,
    and creates a small window, the Battle window, that captures and displays combat
    text, even if it is hidden from the main window.

    The following configuration options are available:

    offset : a formatting option that sets a number of spaces to write at the beginning
             of each line in the Battle window.
    fontSize : a formatting option that sets the font size used in the Battle window.
    show_border : a formatting option that determins if a border will be displayed
                  around the Battle window.
    gag_combat : if true, this will hide all non-damage lines in combat.
    gag_non_damage : if true, this will hide all non-damage lines in combat.
                     (identical to gag_combat)
    show_damage : if true, this will show each damage line as it occurs, formatted
                  according to dam_format.
    show_damage_by_me : if true, this will show damage that you deal to any target.
    show_damage_to_me : if true, this will show damage that you receive from any attacker.
    summarize_damage : if true, a summary of all damage during a round will be displayed,
                       formatted according to summary_format.
    show_miss : if true, this will show misses.
    show_evade : if true, this will show evasions, such as dodge, parry, and shield block.
    show_flag : if true, this will show weapon flags.
    show_condition : if true, this will force your opponents condition to be displayed.
    dam_format : this is a string specifying how to format displayed damage,
                 it has the following options:
        %a : attacker
        %t : target
        %v : damage verb (i.e. 'slash')
        %n : damage noun (i.e. 'maims')
        %d : damage total
        %h : number of hits
        %s : number of swings
        %f : weapon flags
        %r : possessive ending (used following attacker when desired, %a%r)
        %p : the punctuation at the end of the damage line, a '.' or a '!'
        Color : you can use standard DSL color codes to assign colors to normally uncolored
                parts of this information, however they should not affect damage nouns, which
                have their own, assigned colors.
    summary_format : works exactly like dam_format, but controls how the round summary is displayed.

    Weapon flags, when displayed in a round summary, are shown as follows:
        mana drain = "M"
        vampiric = "H"
        holy = "O"
        unholy = "U"
        frost = "C"
        flaming = "F"
        shocking = "L"
        stun = "S"
    ]]
}

local defaults = {
    offset = 1,
    fontSize = 8,
    gag_combat = true,
    gag_non_damage = true,
    show_border = true,
    show_damage = false,
    show_damage_by_me = false,
    show_damage_to_me = false,
    show_miss = false,
    show_evade = false,
    show_flag = false,
    show_condition = false,
    summarize_damage = true,
    dam_format = "%a%r %n %v %t (%d)",
    summary_format = "%a%r %n %v %t (%d)"
    -- format options:
    -- %a = attacker,
    -- %t = target,
    -- %v = damage verb,
    -- %n = damage noun,
    -- %d = damage total,
    -- %h = number of hits,
    -- %s = number of swings,
    -- %f = weapon flags,
    -- %r = possessive ending,
    -- %p = punctuation
}
local dam_info = {
    miss = {0,"<dsl_yellow>miss","es"," "," ","dsl_yellow"},
    scratch = {2.5,"<dsl_green>scratch","es"," "," ","dsl_green"},
    graze = {6.5,"<dsl_green>graze","s"," "," ","dsl_green"},
    hit = {10.5,"<dsl_green>hit","s"," "," ","dsl_green"},
    injure = {14.5,"<dsl_green>injure","s"," "," ","dsl_green"},
    wound = {18.5,"<dsl_green>wound","s"," "," ","dsl_green"},
    maul = {22.5,"<dsl_green>maul","s"," "," ","dsl_green"},
    decimate = {26.5,"<dsl_green>decimate","s"," "," ","dsl_green"},
    devastate = {30.5,"<dsl_green>devastate","s"," "," ","dsl_green"},
    maim = {34.5,"<dsl_green>maim","s"," "," ","dsl_green"},
    MUTILATE = {38.5,"<dsl_lt_yellow>MUTILATE","S"," "," ","dsl_lt_yellow"},
    DISEMBOWEL = {42.5,"<dsl_lt_yellow>DISEMBOWEL","S"," "," ","dsl_lt_yellow"},
    DISMEMBER = {46.5,"<dsl_lt_yellow>DISMEMBER","S"," "," ","dsl_lt_yellow"},
    MASSACRE = {50.5,"<dsl_lt_yellow>MASSACRE","S"," "," ","dsl_lt_yellow"},
    MANGLE = {54.5,"<dsl_lt_yellow>MANGLE","S"," "," ","dsl_lt_yellow"},
    DEMOLISH = {58.5,"<dsl_lt_red>DEMOLISH","ES"," *** ", " *** ","dsl_lt_red"},
    DEVASTATE = {68,"<dsl_lt_red>DEVASTATE","S"," *** ", " *** ","dsl_lt_red"},
    OBLITERATE = {88,"<dsl_lt_red>OBLITERATE","S"," === ", " === ","dsl_lt_red"},
    ANNIHILATE = {113,"<dsl_lt_red>ANNIHILATE","S"," >>> ", " <<< ","dsl_lt_red"},
    ERADICATE = {138,"<dsl_lt_red>ERADICATE","S"," <<< ", " >>> ","dsl_lt_red"},
    GHASTLY = {163,"<dsl_lt_red>G<dsl_white>H<dsl_lt_red>A<dsl_white>S<dsl_lt_red>T<dsl_white>L<dsl_lt_red>Y",""," does "," things to ","dsl_lt_red"},
    HORRID = {188,"<dsl_lt_red>H<dsl_white>O<dsl_lt_red>R<dsl_white>R<dsl_lt_red>I<dsl_white>D",""," does "," things to ","dsl_lt_red"},
    DREADFUL = {213,"<dsl_lt_red>D<dsl_white>R<dsl_lt_red>E<dsl_white>A<dsl_lt_red>D<dsl_white>F<dsl_lt_red>U<dsl_white>L",""," does "," things to ","dsl_lt_red"},
    HIDEOUS = {238,"<dsl_lt_red>H<dsl_white>I<dsl_lt_red>D<dsl_white>E<dsl_lt_red>O<dsl_white>U<dsl_lt_red>S",""," does "," things to ","dsl_lt_red"},
    INDESCRIBABLE = {263,"<dsl_lt_red>I<dsl_white>N<dsl_lt_red>D<dsl_white>E<dsl_lt_red>S<dsl_white>C<dsl_lt_red>R<dsl_white>I<dsl_lt_red>B<dsl_white>A<dsl_lt_red>B<dsl_white>L<dsl_lt_red>E",""," does "," things to ","dsl_lt_red"},
    UNSPEAKABLE = {276,"<dsl_lt_red>U<dsl_white>N<dsl_lt_red>S<dsl_white>P<dsl_lt_red>E<dsl_white>A<dsl_lt_red>K<dsl_white>A<dsl_lt_red>B<dsl_white>L<dsl_lt_red>E",""," does "," things to ","dsl_lt_red"}
    }

local condition_info = {
    [" is in excellent condition."] = " [<green>100%<reset>]",
    [" has a few scratches."] = " [<green>90-99%<reset>]",
    [" has some small wounds and bruises."] = " [<green>75-89%<reset>]",
    [" has quite a few wounds."] = " [<green>50-74%<reset>]",
    [" has some big nasty wounds and scratches."] = " [<green>30-49%<reset>]",
    [" looks pretty hurt."] = " [<green>15-29%<reset>]",
    [" is in awful condition."] = " [<green>0-14%<reset>]"}
local flag_info = {
    L = "<dsl_lt_yellow>L",
    F = "<dsl_lt_red>F",
    C = "<dsl_lt_cyan>C",
    H = "<dsl_lt_magenta>H",
    M = "<dsl_lt_blue>M",
    S = "<dsl_green>S",
    U = "<dsl_black>U",
    O = "<dsl_white>O"
    }
local flag_list = {
    energy = "M",
    draw = "H",
    holy = "O",
    unholy = "U",
    freeze = "C",
    ice = "C",
    burn = "F",
    sear = "F",
    knock = "S",
    lightning = "L",
    shock = "L"
    }
local exceptions = {"You gain", "has big nasty", "Affects", "has some small", "Wimpy"}
local battle_data = {}
local last_attacker
local last_target
local last_noun

local function battle_format(format, attacker, possessive, noun, verb, target, punctuation, damage, swings, hits, flags)
    local data = {
        ["%%a"] = string.trim(attacker),     ["%%t"] = string.trim(target),
        ["%%n"] = string.trim(noun),         ["%%v"] = string.trim(verb),
        ["%%f"] = string.trim(flags),        ["%%d"] = string.trim(damage),
        ["%%h"] = string.trim(hits),         ["%%s"] = string.trim(swings),
        ["%%r"] = string.trim(possessive),   ["%%p"] = string.trim(punctuation),
        ["  "] = " ",           }
    for k,v in pairs(data) do
        format = string.gsub(format,k,v)
    end
    format = dslpnp.support.replaceColors(format)
    return format
end

local function display_damage(attacker, possessive, noun, verb, target, punctuation, damage)
    selectCurrentLine()
    replace("")
    local str = battle_format(dslpnp.battle.configs.dam_format, attacker, possessive, noun, verb, target, punctuation, damage, "", "", "")
    cecho(str)
end

local function add_battle_data(attacker, target, event, value, mod)
    battle_data[attacker] = battle_data[attacker] or {}
    battle_data[attacker][target] = battle_data[attacker][target] or {}
    battle_data[attacker][target][event] = battle_data[attacker][target][event] or {}
    local data = battle_data[attacker][target][event]

    if mod ~= "flag" then
        data.swings = (data.swings or 0) + 1
        if event ~= "evaded" then
            data.hits = (data.hits or 0) + ((mod ~= "miss" and 1) or 0)
            data.dam = (data.dam or 0) + value
        end
    else
        data.flags = data.flags or ""
        if not string.find(data.flags,value) then
            data.flags = data.flags .. value
        end
        if flag == "H" and attacker == "you" then
            dslpnp.battle.rage_info.vamp = (dslpnp.battle.rage_info.vamp or 0) + 2.5
        end
    end
end

local function handle_damage(attacker, noun, verb, target, punctuation)
    local configs = dslpnp.battle.configs or {}
    attacker = assert(string.trim(attacker),"Invalid attacker!")
    noun = assert(string.trim(noun), "Invalid damage noun!")
    target = assert(string.trim(target),"Invalid target!")
    punctuation = assert(punctuation,"Invalid punctuation!")
    for k,v in ipairs(exceptions) do
        if string.find(attacker, v) or string.find(noun, v) then return false end
    end
    local attack_info = assert(dam_info[verb], "Invalid damage verb!")
    local damAssign = attack_info[1]
    local damVerb = attack_info[2]
    if attacker ~= "You" or noun ~= "" then damVerb = damVerb .. attack_info[3] end
    damVerb = attack_info[4] .. damVerb .. "<reset>" .. attack_info[5]
    local possessive = ""
    if noun ~= "" then
        noun = " " .. noun
        possessive = (attacker == "You" and "r") or "'s"
    end
    noun = string.gsub(noun,"does","")
    target = string.gsub(target,"things to","")
    selectString(verb,1)
    local r,g,b = getFgColor()
    if r ~= color_table[attack_info[6]][1] and g ~= color_table[attack_info[6]][2] and b ~= color_table[attack_info[6]][3] then
        return
    end
    if verb ~= "miss" then
        -- report damage into the miniconsole
        cecho("battle_console"," " .. attacker .. possessive .. noun .. damVerb .. target .. punctuation .. " [" .. damAssign .. "]\n")
    end
    local show_damage = (configs.show_miss or verb ~= "miss") and (configs.show_damage or (configs.show_damage_by_me and attacker == "You") or (configs.show_damage_to_me and target == "you"))
    if show_damage then
        display_damage(attacker, possessive, noun, damVerb, target, punctuation, damAssign)
    end
    attacker = string.lower(attacker)
    target = string.lower(target)
    noun = string.lower(noun)
    -- collect data on attack
--    battle_data[attacker] = battle_data[attacker] or {}
--    battle_data[attacker][target] = battle_data[attacker][target] or {}
--    battle_data[attacker][target][noun] = battle_data[attacker][target][noun] or {}
--    battle_data[attacker][target][noun].swings = (battle_data[attacker][target][noun].swings or 0) + 1
--    battle_data[attacker][target][noun].dam = (battle_data[attacker][target][noun].dam or 0) + damAssign
--    battle_data[attacker][target][noun].hits = (battle_data[attacker][target][noun].hits or 0) + ((verb ~= "miss" and 1) or 0)
    add_battle_data(attacker,target,noun,damAssign)
    last_attacker = attacker
    last_target = target
    last_noun = noun

    if target == "you" then -- record damage taken while raging
        dslpnp.battle.rage_info.damage = (dslpnp.battle.rage_info.damage or 0) + damAssign
    end
    if not show_damage and string.trim(noun) ~= "trip" and string.trim(noun) ~= "kicked dirt" then deleteLine() end
end

local function handle_evasion(target, attacker)
    local configs = dslpnp.battle.configs or {}
    attacker = string.trim(string.lower(attacker))
    target = string.trim(string.lower(target))
    if string.sub(attacker,-2) == "'s" then
        attacker = string.sub(attacker, 1, -3) -- chop two last letters off
    elseif attacker == "your" then
        attacker = "you"
    elseif attacker == "" then
        attacker = "unknown"
    end
--    battle_data[attacker] = battle_data[attacker] or {}
--    battle_data[attacker][target] = battle_data[attacker][target] or {}
--    battle_data[attacker][target]["evaded"] = battle_data[attacker][target]["evaded"] or {}
--    battle_data[attacker][target]["evaded"]["swings"] = battle_data[attacker][target]["evaded"]["swings"] or 0
--    battle_data[attacker][target]["evaded"]["swings"] = battle_data[attacker][target]["evaded"]["swings"] + 1
    add_battle_data(attacker,target,"evaded")
    if (configs.gag_combat or configs.gag_non_damage or not configs.show_evade) then deleteLine() end
end

local function handle_flag(flag)
    flag = assert(flag_list[flag],"Invalid flag!")
    local tmp_str = getCurrentLine()
    if flag == "freeze" and tmp_str == "The panic of drowning freezes you in your tracks!" then
        return
    end
    if last_noun and last_target and last_attacker then
        add_battle_data(last_attacker,last_target,last_noun,flag,"flag")
--       battle_data[last_attacker][last_target][last_noun]["flags"] = battle_data[last_attacker][last_target][last_noun]["flags"] or ""
--       if not string.find(battle_data[last_attacker][last_target][last_noun]["flags"],flag) then
--           battle_data[last_attacker][last_target][last_noun]["flags"] = battle_data[last_attacker][last_target][last_noun]["flags"] .. flag
--       end
--       if flag == "H" and last_attacker == "you" then
--           dslpnp.battle.rage_info.vamp = (dslpnp.battle.rage_info.vamp or 0) + 2.5
--       end
        if (dslpnp.battle.configs.gag_combat or dslpnp.battle.configs.gag_non_damage or not dslpnp.battle.configs.show_flag) and flag ~= "S" then deleteLine() end
    end
end

local function handle_condition(name, condition)
    local configs = dslpnp.battle.configs or {}
    local percentage = ""
    if not table.is_empty(battle_data) and condition ~= " is DEAD!!" then
        percentage = condition_info[condition] or ""
        battle_data.screen_condition = "<red>" .. name .. "<reset>" .. condition .. percentage
        battle_data.window_condition = "<red>" .. name .. "<reset>" .. percentage .. "\n"
        if (not configs.show_condition) and ((configs.gag_combat or configs.gag_non_damage) and (not configs.summarize_damage)) then deleteLine() end
    elseif condition == " is DEAD!!" then
        battle_data.screen_condition = "<dsl_lt_magenta>" .. name .. condition .. "<reset>"
        battle_data.window_condition = "<red>" .. name .. "<reset>" .. condition .. "\n\n"
        if (not configs.show_condition) and ((configs.gag_combat or configs.gag_non_damage) and (not configs.summarize_damage)) then deleteLine() end
    end
end

local function calc_dam_verb(damage,attacker)
    local val, max
    attacker = string.trim(attacker)
    for k,v in pairs(dam_info) do
        if v[1] <= damage then
            max = max or v[1]
            if v[1] >= max then
                val = string.trim(((attacker == "You" and v[4] == " does " and " do ") or v[4]) .. v[2] .. ((attacker == "You" and "") or v[3]) .. "<reset>" .. v[5])
                max = v[1]
            end
        end
    end
    return val
end

local function insertNewLine()
    local curNum = getLineNumber()
    insertText("\n")
    wrapLine(curNum)
    moveCursor(0,curNum+1)
    selectCurrentLine()
    replace("")
end

local function output_damage()
    local first = true
    if dslpnp.battle.configs.summarize_damage and not table.is_empty(battle_data) then
        for k,v in pairs(battle_data) do
            if k ~= "screen_condition" and k ~= "window_condition" then
                local attacker = string.title(string.trim(k))
                for k2,v2 in pairs(v) do
                    local victim = string.title(string.trim(k2))
                    local hits,swings,dam,flags,nouns = 0,0,0,"",""
                    for k3,v3 in pairs(v2) do
                        if k3 ~= "evaded" then
                            flags = flags .. (v3.flags or "")
                            if nouns ~= "" then
                                nouns = nouns .. ", " .. string.trim(k3)
                            else
                                nouns = string.trim(k3)
                            end
                            if v3.dam then  dam = dam + v3.dam end
                            if v3.hits then hits = hits + v3.hits end
                        end
                        if v3.swings then swings = swings + v3.swings end
                    end
                    if swings > 0 then
                        local str = dslpnp.battle.configs.summary_format
                        local possessive = ""
                        if nouns ~= "" then
                            possessive = "'s"
                            if string.trim(attacker) == "You" then
                                possessive = "r"
                            end
                        end
--                        flags = string.gsub(flags,"L",flag_info.L)
--                        flags = string.gsub(flags,"F",flag_info.F)
--                        flags = string.gsub(flags,"C",flag_info.C)
--                        flags = string.gsub(flags,"H",flag_info.H)
--                        flags = string.gsub(flags,"M",flag_info.M)
--                        flags = string.gsub(flags,"S",flag_info.S)
--                        flags = string.gsub(flags,"U",flag_info.U)
--                        flags = string.gsub(flags,"O",flag_info.O)
                        for k,v in pairs(flag_info) do
                            flags = string.gsub(flags,k,v)
                        end
                        flags = flags .. "<reset>"
--                        str = string.gsub(str,"%%a",attacker)
--                        str = string.gsub(str,"%%t",victim)
--                        str = string.gsub(str,"%%n",nouns)
--                        str = string.gsub(str,"%%v",calc_dam_verb(dam))
--                        str = string.gsub(str,"%%f",flags)
--                        str = string.gsub(str,"%%d",dam)
--                        str = string.gsub(str,"%%h",hits)
--                        str = string.gsub(str,"%%s",swings)
--                        str = string.gsub(str,"%%r",possessive)
--                        str = string.gsub(str,"%%p",".")
--                        str = string.gsub(str,"  "," ")
                        str = battle_format(str, attacker, possessive, nouns, calc_dam_verb(dam), victim, punctuation, dam, swings, hits, flags)
--                        if first then
--                            first = false
--                            cecho(str)
--                        else
--                            cecho("\n"..str)
--                        end
                        cecho((first and "" or "\n") .. str)
                        first = false
                    end
                end
            end
        end
        if battle_data.screen_condition then
            cecho("\n"..battle_data.screen_condition)
        end
        if battle_data.window_condition then
            cecho("battle_console"," " .. battle_data.window_condition)
        end
        battle_data = {}
        for k=1, dslpnp.battle.configs.offset or 0 do
            echo("\n")
        end
    end
end

local function handle_prompt(curHP)
    local rage = dslpnp.battle.rage_info or {}
    if curHP == "???" then
        rage.damage = rage.damage or 0
        rage.vamp = rage.vamp or 0
        raiseEvent("onRage", rage.damage, rage.vamp)
    else
        rage.damage = 0
        rage.vamp = 0
    end
    if battle_data then
        output_damage()
    end
end

local function make_triggers()
    local trigger_text = {}
    trigger_text = {
            [[([\w\-\,\s\']+)( is in excellent condition.)[\s]*$]],
            [[([\w\-\,\s\']+)( has a few scratches.)[\s]*$]],
            [[([\w\-\,\s\']+)( has some small wounds and bruises.)[\s]*$]],
            [[([\w\-\,\s\']+)( has quite a few wounds.)[\s]*$]],
            [[([\w\-\,\s\']+)( has some big nasty wounds and scratches.)[\s]*$]],
            [[([\w\-\,\s\']+)( looks pretty hurt.)[\s]*$]],
            [[([\w\-\,\s\']+)( is in awful condition.)[\s]*$]],
            [[([\w\-\,\s\']+)( is DEAD!!)]]
            }
    for k,v in ipairs(trigger_text) do
        if not dslpnp.triggers.exists("Condition Trigger " .. k) then
            dslpnp.triggers.register("Condition Trigger " .. k,"regex",v,[[raiseEvent("onCondition",matches[2],matches[3])]],true)
        end
    end
    trigger_text =  [[^(You|[\w\-\s,']+?)(?:(?<=You)r|'s)?(?:\s?((?<=Your )[\w\s]+?|(?<='s )[\w\s]+?|))(?: do[es]*| [\>\<\=\*]+|) (m(?:a(?:ul|im)|iss)|de(?:cim|vast)ate|scratch|(?:graz|injur)e|hit|wound|H(?:ORRID|IDEOUS)|D(?:IS(?:EMBOWEL|MEMBER)|E(?:MOLISH|VASTATE)|READFUL)|M(?:A(?:SSACR|NGL)E|UTILATE)|GHASTLY|(?:(?:INDESCRIB|UNSPEAK)ABL|(?:OBLITER|ANNIHIL|ERADIC)AT)E)[esES]*(?: things to| [\>\<\=\*]+|) ([\w\-\s,']+)([\.!]+)$]]
    if not dslpnp.triggers.exists("Battle Damage Trigger") then
        dslpnp.triggers.register("Battle Damage Trigger","regex",trigger_text,[[raiseEvent("onCombat","damage",matches[2],matches[3],matches[4],matches[5],matches[6])]],true)
    end
    trigger_text = {
            [[(You|[\w\-\,\s\']+) (dodge)s? (your|[\w\-\,\s\']+) attack\.$]],
            [[(You|[\w\-\,\s\']+) (parry|parries) (your|[\w\-\,\s\']+) attack\.$]],
            [[(You|[\w\-\,\s\']+) (block)[s]? (your|[\w\-\,\s\']+) attack .*\.$]],
            [[(You|[\w\-\,\s\']+) (sense)[s]*() [they|you]+'re about to be hit and deflect[s]* the blow\.$]],
            [[(You|[\w\-\,\s\']+) (sense)[s]* (your|[\w\-\,\s\']+) attack coming and avoid[s]* its blow\.$]]
            }
    for k,v in ipairs(trigger_text) do
        if not dslpnp.triggers.exists("Evade Trigger " .. k) then
            dslpnp.triggers.register("Evade Trigger " .. k,"regex",v,[[raiseEvent("onCombat","evade",matches[2],matches[4])]],true)
        end
    end
    trigger_text = {
            [[[\w\-\,\s\']+ (freeze)s [\w\-\,\s\']+]],
            [[The cold touch of [\w\-\,\s\']+ surrounds you with (ice)]],
            [[You feel a surge of [\w\-\,\s\']+\'s (holy) wrath race through your body]],
            [[You feel a surge of [\w\-\,\s\']+\'s (unholy) wrath race through your body]],
            [[You feel something drawing your (energy) away]],
            [[[\w\-\,\s\']+ draws (energy) from [\w\-\,\s\']+]],
            [[[\w\-\,\s\']+ is (burn)ed by [\w\-\,\s\']+]],
            [[[\w\-\,\s\']+ (sear)s your flesh]],
            [[[\w\-\,\s\']+ is struck by (lightning) from [\w\-\,\s\']+]],
            [[[\w\-\,\s\']+ is (knock)ed to the ground by [\w\-\,\s\']+]],
            [[[\w\-\,\s\']+ (draw)s life from [\w\-\,\s\']+]],
            [[You feel [\w\-\,\s\']+ (draw)ing your life away]],
            [[[\w\-\,\s\']+ is (shock)ed by a .+]],
            [[^A flash of (holy) power erupts from [\w\-\,\s\']+ and hits [\w\-\,\s\']+!]]
            }
    for k,v in ipairs(trigger_text) do
        if not dslpnp.triggers.exists("Flag Trigger " .. k) then
            dslpnp.triggers.register("Flag Trigger " .. k,"regex",v,[[raiseEvent("onCombat","flag",matches[2])]],true)
        end
    end
end

local function config(window_name,x,y,width,height,origin)
    dslpnp.battle.windowList = {"battle_console","battle_label"}
    local configs = dslpnp.config.battle or {}
    if configs.dam_format and not configs.summary_format then
        configs.summary_format = configs.dam_format
    end
    configs = table.update(defaults,configs)

    dslpnp.battle.configs = configs
    createMiniConsole("battle_console",0,0,0,0)
    createLabel("battle_label",0,0,0,0,1)
    windowManager.add("battle_console","miniConsole",x,y,width,height,origin)
    windowManager.add("battle_label","label",x,y,width,height,origin)
    setBackgroundColor("battle_console",0,0,0,255)
    setMiniConsoleFontSize("battle_console",configs.fontSize)
    setLabelStyleSheet("battle_label",[[
        border: 2px solid white;
        border-radius: 5px;
        background-color: rgba(0,0,0,0)]])
    setLabelClickCallback("battle_label","raiseEvent","onReveal","battle")
    hideWindow("battle_console")
    hideWindow("battle_label")

    createLabel("battle_tab",0,0,0,0,1)
    setLabelClickCallback("battle_tab","raiseEvent","onDisplay","battle")
    dslpnp.sidebar.maketab(window_name,"battle_tab","Battle Info")

    make_triggers()
    raiseEvent("onToggle","battle","on")
end

local function onReveal()
    hideWindow("battle_label")
end

local function onDisplay()
    dslpnp.sidebar.display("battle", {"battle_label", "battle_console"}, "battle_tab")
end

local function toggle(setVal)
    dslpnp.battle.Active = dslpnp.toggle("battle",dslpnp.battle.Active, setVal)
    if dslpnp.battle.Active then
        showWindow("battle_tab")
    else
        hideWindow("battle_tab")
        hideWindow("battle_console")
        hideWindow("battle_label")
    end
end

local function displayWindow(x,y,width,height)
    windowManager.move("battle_console",x,y)
    windowManager.move("battle_label",x,y)
    windowManager.resize("battle_console",width,height)
    windowManager.resize("battle_label",width,height)
    showWindow("battle_console")
    if dslpnp.battle.configs.show_border then
        showWindow("battle_label")
    end
end

function dslpnp.battle.eventHandler(event, ...)
    if event == "onCombat" and dslpnp.battle.Active then
        if arg[1] == "damage" then
            handle_damage(arg[2],arg[3],arg[4],arg[5],arg[6])
        elseif arg[1] == "evade" then
            handle_evasion(arg[2],arg[3])
        elseif arg[1] == "flag" then
            handle_flag(arg[2])
        end
    elseif event == "onCondition" and dslpnp.battle.Active then
        handle_condition(arg[1],arg[2])
    elseif event == "updatePrompt" and dslpnp.battle.Active then
        handle_prompt(dslpnp.prompt.curhp_number)
    elseif event == "onToggle" and arg[1] == "battle" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "battle" then
        config(arg[2], arg[3], arg[4], arg[5], arg[6], arg[7])
    elseif event == "onDisplay" and arg[1] == "battle" and dslpnp.battle.Active then
        onDisplay()
    elseif event == "onReveal" and arg[1] == "battle" and dslpnp.battle.Active then
        onReveal()
    elseif event == "displayWindow" and arg[1] == "battle" and dslpnp.battle.Active then
        displayWindow(arg[2],arg[3],arg[4],arg[5])
    end
end

registerAnonymousEventHandler("onCombat", "dslpnp.battle.eventHandler")
registerAnonymousEventHandler("onCondition", "dslpnp.battle.eventHandler")
registerAnonymousEventHandler("updatePrompt", "dslpnp.battle.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.battle.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.battle.eventHandler")
registerAnonymousEventHandler("onDisplay", "dslpnp.battle.eventHandler")
registerAnonymousEventHandler("onReveal", "dslpnp.battle.eventHandler")
registerAnonymousEventHandler("displayWindow", "dslpnp.battle.eventHandler")
