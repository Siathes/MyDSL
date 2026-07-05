-- Character : Spellup Script
-- 8/29/2018
-- v4.02l
--

dslpnp.character.spellup = dslpnp.character.spellup or {}
dslpnp.character.spellup.inProgress = false

dslpnp.character.spellup.help = [[
    Character Script : Spellup Plugin

    The spellup plugin for the character script is designed to provide players with an
    easy method to fireproof or bless their characters' equipment without having to go
    through the burdensome process of removing it piece by piece and manually typing
    everything out.

    To set how the script blesses or fireproofs gear, you use the setspell command.
    Syntax: setspell <bless|fireproof> <spell|wand|skill> <wand name or skill command>

    To bless or fireproof your gear, use the bless or fireproof commands.
    Syntax: bless <equipment slot> or bless all
    fireproof <equipment slot> or fireproof all

    To stop blessing or fireproofing, use the stop spellup command.
    Syntax: stop spellup
]]

local defaults = {
    auto_wimpy = true,
}

local spell_info = spell_info or {}
local current_spell, current_slot
local target_list = target_list or {}
local trigger_names = {
    "Character Spellup Success 1",
    "Character Spellup Success 2",
    "Character Spellup Success 3",
    "Character Spellup Success 4",
    "Character Spellup Success 5",
    "Character Spellup Success 6",
    "Character Spellup Success 7",
    "Character Spellup Success 8",
    "Character Spellup Success 9",
    "Character Spellup Fail 1",
    "Character Spellup Fail 2",
    "Character Spellup Fail 3",
    "Character Spellup Wand Missing 1",
    "Character Spellup Wand Missing 2",
    "Character Spellup Wand Explodes",
}


function dslpnp.character.spellup.spellupIgnore(spell,slot,remember)
    if dslpnp.character.spellup.Active then
        remember = remember or "yes"
        if remember == "yes" then
            remember = true
        else
            remember = false
        end
        local item = dslpnp.character.equipment.checkItem(slot)
        if not item then print("No such equipment slot, or no equipment in that slot.") return end
        local status = dslpnp.character.getCharData(slot,spell)
        if status == nil then status = true end
        status = not status
        dslpnp.character.setCharData(status,slot,spell)
        print(item .. ((status and " will once more be '") or " will no longer be '") .. spell .. "ed'.")
        if remember then
            dslpnp.character.setCharData(status,"ignoreList_"..spell,item)
        end
    end
end

local function check_cast(slot,spell)
    local status = dslpnp.character.getCharData(slot,spell)
    if status == nil then status = true end
    local item_status = dslpnp.character.getCharData("ignoreList_"..spell,dslpnp.character.equipment.checkItem(slot))
    if item_status == nil then item_status = true end
    return status and item_status
end

local function castSpell()
    if dslpnp.character.equipment.checkItem(current_slot) and check_cast(current_slot, current_spell) then
        -- kill previous failsafe timer
        dslpnp.timers.remove("Character Spellup Failsafe Timer")
        -- start new failsafe timer
        dslpnp.timers.register(20,dslpnp.character.spellup.stop,"Character Spellup Failsafe Timer")
        -- remove item to be cast on
        if not (spell_info[current_spell][1] == "wand" and current_slot == "held") then
            dslpnp.character.equipment.useItem(current_slot,"remove","worn")
        end

        -- determine command to use
        local cmd = "cast '" .. current_spell .. "'"
        if spell_info[current_spell][1] == "wand" then
            cmd = "zap"
        elseif spell_info[current_spell][1] == "skill" then
            cmd = spell_info[current_spell][2]
        end

        -- "cast" on item
        dslpnp.character.equipment.useItem(current_slot, cmd, "inventory")

        -- rewear item
        if not table.contains({"sheathed","secondary","held"}, current_slot) then
            dslpnp.character.equipment.useItem(current_slot, "wear", "inventory")
        elseif current_slot == "sheathed" then
            dslpnp.character.equipment.useItem(current_slot, "sheath", "inventory")
        elseif current_slot == "secondary" then
            dslpnp.character.equipment.useItem(current_slot, "second", "inventory")
        elseif current_slot == "held" and (spell_info[current_spell][1] ~= "wand" or table.is_empty(target_list)) then
            dslpnp.character.equipment.useItem(current_slot, "wear", "inventory")
        end
    else
        dslpnp.character.spellup.nextItem()
    end
end

function dslpnp.character.spellup.setSpellInfo(spell, cast_type, arg)
    if dslpnp.character.spellup.Active then
        arg = arg or ""
        if not cast_type then cast_type = "spell" end
        assert(table.contains({"bless","fireproof"},spell), "Invalid spell!")
        assert(cast_type == "spell" or cast_type == "wand" or cast_type == "skill", "Invalid spell type!")
        spell_info = dslpnp.character.getCharData("spell_info") or {}
        if cast_type == "spell" then
            spell_info[spell] = {}
        elseif cast_type == "skill" then
            spell_info[spell] = {"skill", arg}
        elseif cast_type == "wand" then
            spell_info[spell] = {"wand", arg}
        end
        dslpnp.character.setCharData(spell_info, "spell_info")
        print(string.title(spell) .. " set to " .. cast_type .. " " .. arg .. ".")
    end
end

function dslpnp.character.spellup.stop()
    if dslpnp.character.Active then
        for k,v in ipairs(trigger_names) do
            dslpnp.triggers.disable(v)
        end

        if dslpnp.character.spellup.inProgress then
            dslpnp.character.spellup.inProgress = false
            print("Spell up cancelled!")
        else
            print("Spell up complete.")
        end
        if spell_info[current_spell][1] == "wand" then
            dslpnp.character.equipment.useItem("held", "wear", "inventory")
        end
        if dslpnp.character.spellup.configs.auto_wimpy then
            send("wimpy", false)
        end
    end
end

function dslpnp.character.spellup.equipWand()
    if spell_info[current_spell][1] == "wand" then
        send("wear " .. spell_info[current_spell][2])
    end
end

function dslpnp.character.spellup.nextItem()
    local item = dslpnp.character.spellup.item
    local test
    dslpnp.character.spellup.waiting = false
    dslpnp.character.spellup.item = nil
    if item then
        test = dslpnp.character.getCharData(current_slot)
        if string.lower(test[1]) ~= string.lower(item) then
            return
        end
    end

    current_slot = table.remove(target_list,1)
    if current_slot then
        castSpell()
    else
        -- We're done spelling up
        dslpnp.timers.remove("Character Spellup Failsafe Timer")
        dslpnp.character.spellup.inProgress = false
        dslpnp.character.spellup.stop()
    end
end

function dslpnp.character.spellup.repeatItem()
    dslpnp.character.spellup.repeat_waiting = false
    castSpell()
end

function dslpnp.character.spellup.startSpellup(spell, target, resume)
    if dslpnp.character.spellup.Active then
        dslpnp.character.spellup.item = nil
        dslpnp.character.spellup.inProgress = true

        if not resume then
            if target ~= "all" and not dslpnp.character.equipment.checkItem(target) then print("No such equipment slot.") return end
            spell_info = dslpnp.character.getCharData("spell_info") or {}
            spell_info[spell] = spell_info[spell] or {}
            current_spell = spell

            if target ~= "all" then
                target_list = {target}
            else
                target_list = dslpnp.character.getCharData("slot_list") or {}
            end
            if spell_info[spell][1] == "wand" then
                dslpnp.character.spellup.equipWand()
            end
        end

        -- enable triggers
        for k,v in ipairs(trigger_names) do
            dslpnp.triggers.enable(v)
        end

        dslpnp.character.spellup.nextItem()
    end
end

local function make_triggers()
    local trigger_patterns = {
        [[(.*) glows with a holy aura\.$]],
        [[.* is too powerful for you to overcome\.$]],
        [[You protect .* from fire\.$]],
        [[.* is already protected from burning\.$]],
        [[.* is already blessed\.$]],
        [[You cover .* with mud\.$]],
        [[.* is already protected\.$]],
        [[You are not carrying that\.$]],
        [[You don't see that here\.$]],
    }
    for k,v in ipairs(trigger_patterns) do
        if not dslpnp.triggers.exists("Character Spellup Success " .. k) then
            dslpnp.triggers.register("Character Spellup Success " .. k, "regex", v, [[dslpnp.character.spellup.item = matches[2] dslpnp.character.spellup.waiting = true]],false)
        end
    end

    trigger_patterns = {
        [[You lost your concentration\.$]],
        [[Your efforts with .* produce only smoke and sparks\.$]],
        [[The mud is too wet and runs off\.$]],
    }
    for k,v in ipairs(trigger_patterns) do
        if not dslpnp.triggers.exists("Character Spellup Fail " .. k) then
            dslpnp.triggers.register("Character Spellup Fail " .. k, "regex", v, [[dslpnp.character.spellup.repeat_waiting = true]],false)
        end
    end

    trigger_patterns = {
        [[You hold nothing in your hand.$]],
        [[You can zap only with a wand.$]],
    }
    for k,v in ipairs(trigger_patterns) do
        if not dslpnp.triggers.exists("Character Spellup Wand Missing " .. k) then
            dslpnp.triggers.register("Character Spellup Wand Missing " .. k, "regex", v, [[dslpnp.character.spellup.stop()]],false)
        end
    end

    trigger_patterns = [[Your .* explodes into fragments.$]]
    if not dslpnp.triggers.exists("Character Spellup Wand Explodes") then
        dslpnp.triggers.register("Character Spellup Wand Explodes", "regex", trigger_patterns, [[dslpnp.character.spellup.equipWand()]],false)
    end
end

local function make_aliases()
    if not dslpnp.aliases.exists("Character Set Spell Alias") then
        dslpnp.aliases.register("Character Set Spell Alias", [[^setspell (\w+) (\w+)\s?([\w\s]*)$]], [[dslpnp.character.spellup.setSpellInfo(matches[2], matches[3], matches[4])]],true)
    end
    if not dslpnp.aliases.exists("Character Stop Spellup Alias") then
        dslpnp.aliases.register("Character Stop Spellup Alias", [[^stop spellup$]], [[dslpnp.character.spellup.stop()]],true)
    end
    if not dslpnp.aliases.exists("Character Spellup Alias") then
        dslpnp.aliases.register("Character Spellup Alias", [[^(bless|fireproof) (\w+)\s?(\w*)$]], [[dslpnp.character.spellup.startSpellup(matches[2],matches[3]..matches[4])]],true)
    end
    if not dslpnp.aliases.exists("Character Spellup Resume Alias") then
        dslpnp.aliases.register("Character Spellup Resume Alias", [[^resume spellup$]],[[dslpnp.character.spellup.startSpellup(nil,nil,true)]],true)
    end
    if not dslpnp.aliases.exists("Character Spellup Ignore Alias") then
        dslpnp.aliases.register("Character Spellup Ignore Alias", [[^ignore (bless|fireproof) (\w+)\s?(\d*)(?: (yes|no))?$]], [[dslpnp.character.spellup.spellupIgnore(matches[2],matches[3]..matches[4],matches[5])]],true)
    end
end

local function toggle(setVal)
    dslpnp.character.spellup.Active = dslpnp.toggle("character : spellup", dslpnp.character.spellup.Active, setVal)
    if dslpnp.character.spellup.Active then
        if dslpnp.aliases.exists("Character Set Spell Alias") then dslpnp.aliases.enable("Character Set Spell Alias") end
        if dslpnp.aliases.exists("Character Stop Spellup Alias") then dslpnp.aliases.enable("Character Stop Spellup Alias") end
        if dslpnp.aliases.exists("Character Spellup Alias") then dslpnp.aliases.enable("Character Spellup Alias") end
        if dslpnp.aliases.exists("Character Spellup Resume Alias") then dslpnp.aliases.enable("Character Spellup Resume Alias") end
    else
        if dslpnp.aliases.exists("Character Set Spell Alias") then dslpnp.aliases.disable("Character Set Spell Alias") end
        if dslpnp.aliases.exists("Character Stop Spellup Alias") then dslpnp.aliases.disable("Character Stop Spellup Alias") end
        if dslpnp.aliases.exists("Character Spellup Alias") then dslpnp.aliases.disable("Character Spellup Alias") end
        if dslpnp.aliases.exists("Character Spellup Resume Alias") then dslpnp.aliases.disable("Character Spellup Resume Alias") end
        for k,v in ipairs(trigger_names) do
            dslpnp.triggers.disable(v)
        end
    end
end

local function config()
    make_aliases()
    make_triggers()
    local configs = (dslpnp.config.character and dslpnp.config.character.spellup) or {}
    configs = table.update(defaults,configs)
    dslpnp.character.spellup.configs = configs
    raiseEvent("onToggle","character.spellup","on")
end

function dslpnp.character.spellup.eventHandler(event, ...)
    if event == "onPrompt" then
        if dslpnp.character.spellup.waiting then
            dslpnp.character.spellup.nextItem()
        elseif dslpnp.character.spellup.repeat_waiting then
            dslpnp.character.spellup.repeatItem()
        end
    elseif event == "onToggle" and (arg[1] == "spellup" or arg[1] == "character.spellup") then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "character.spellup" then
        config()
    end
end

registerAnonymousEventHandler("onToggle", "dslpnp.character.spellup.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.character.spellup.eventHandler")
registerAnonymousEventHandler("onPrompt", "dslpnp.character.spellup.eventHandler")
