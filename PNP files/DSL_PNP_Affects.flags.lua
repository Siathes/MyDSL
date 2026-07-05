-- Affect Flags Script
-- 9/01/2016
-- v4.01h
--
-- You may also have "flags" displayed with your prompt to display spells that are affecting you visually.
-- Individual flags may be turned on and off using the following command:
-- flag spell_name (flag sanctuary or flag protection evil, for example)
--
-- To make a flag to turn on without checking your affects, create a trigger to detect the spell affect starting or stopping and do the following:
-- dslpnp.affects.toggleSpell("sanctuary",true)  -> This would turn Sanctuary on
-- dslpnp.affects.toggleSpell("sanctuary",false) -> This would turn Sanctuary off
-- Done properly, this can be useful to show spells that frequently are recast, as well as to detect a spell being dispelled.
--

dslpnp.affects.flags = dslpnp.affects.flags or {}
dslpnp.affects.flags.list = dslpnp.affects.flags.list or {}
dslpnp.affects.flags.configs = dslpnp.affects.flags.configs or {}

local default_flags_list = {"sanctuary", "haste", "bless", "fly", "pass door",
    "protection good", "protection evil", "protection neutral"}
local defaults = {
    flag_border_left = "(",
    flag_border_right = ")",
    flag_border_color = "white",
    flag_color = "dsl_lt_yellow",
    flags_list = default_flags_list,
    highlight_time = 5,
    highlight_color = "dsl_lt_red",
    abbreviations = {},
}

local function flags_display()
    local line_pos
    local configs = dslpnp.affects.flags.configs
    local str
    local flags = ""
    -- get flying status from prompt info
    local info = dslpnp.affects.flags.list["flying"]
    local flying = dslpnp.prompt.flying
    local normal_format = string.format("<%s>%s<%s>%s<%s>%s<reset>",configs.flag_border_color, configs.flag_border_left, configs.flag_color,"%s",configs.flag_border_color, configs.flag_border_right)
    local highlight_format = string.format("<%s>%s<%s>%s<%s>%s<reset>",configs.flag_border_color, configs.flag_border_left, configs.highlight_color,"%s",configs.flag_border_color, configs.flag_border_right)
    if flying == "" then flying = false else flying = true end
    if info then
        dslpnp.affects.flags.list["flying"] = {info[1], flying}
    end

    local _,time
    for k,v in pairs(dslpnp.affects.flags.list) do
        if v[1] and v[2]then
            _,time = dslpnp.affects.findAffect( (k ~= "flying" and k) or "fly")
            if time then
                str = string.format(((time > configs.highlight_time) and normal_format) or highlight_format, (configs.abbreviations[k] or string.titleAll(k)))
                flags = flags .. str
            end
        end
    end
    dslpnp.prompt.flags = flags
end

local function checkFlags(spell)
    if dslpnp.affects.flags.list[spell] == nil then
        return false
    else
        return dslpnp.affects.flags.list[spell][1]
    end
end

function dslpnp.affects.flags.setFlags(spell, track, active)
    if dslpnp.affects.flags.Active then
        local ending = ""
        if spell == "fly" then spell = "flying" end
        if track == nil or track == "" then track = not checkFlags(spell) end
        if active == nil then active = dslpnp.affects.findAffect(spell) end
        if track == "false" then track = false end
        if active == "false" then active = false end

        dslpnp.affects.flags.list[spell] = {track, active}
        if track == true or track == "true" then
            ending = "on."
        else
            ending = "off."
        end
        echo("\n" .. string.titleAll(spell) .. " flags " .. ending)
    end
end

function dslpnp.affects.flags.toggleSpell(name, value)
    if dslpnp.affects.flags.Active then
        if name == "fly" then name = "flying" end
        if dslpnp.affects.flags.list[name] ~= nil then
            if value == nil or value == "" then
                dslpnp.affects.flags.list[name][2] = not dslpnp.affects.flags.list[name][2]
            else
                dslpnp.affects.flags.list[name][2] = value
            end
        end
    end
end

local function make_aliases()
    if not dslpnp.aliases.exists("Flag Spell Alias") then
        dslpnp.aliases.register("Flag Spell Alias", [[^flag (.*)$]], [[dslpnp.affects.flags.setFlags(matches[2])]],true)
    end
end

local function toggle(setVal)
    dslpnp.affects.flags.Active = dslpnp.toggle("affects : flags",dslpnp.affects.flags.Active, setVal)
    if dslpnp.affects.flags.Active then
        if dslpnp.aliases.exists("Flag Spell Alias") then dslpnp.aliases.enable("Flag Spell Alias") end
    else
        if dslpnp.aliases.exists("Flag Spell Alias") then dslpnp.aliases.disable("Flag Spell Alias") end
    end
end

local function config()
    local configs = dslpnp.config.affects.flags or {}
    configs = table.update(defaults,configs)
    dslpnp.affects.flags.configs = configs
    local flag_list = configs.flags_list
    dslpnp.affects.flags.list = {}
    for k,v in ipairs(flag_list) do
        if v == "fly" then v = "flying" end
        dslpnp.affects.flags.list[v] = {true, false}
    end
    if not table.contains(dslpnp.statusbar.data_vals, "&f") then
        table.insert(dslpnp.statusbar.data_vals,{"&f", "flags"})
        dslpnp.prompt.flags = ""
    end
    make_aliases()
    raiseEvent("onToggle","affects.flags","on")
end

function dslpnp.affects.flags.eventHandler(event, ...)
    if event == "updatePrompt" and dslpnp.affects.flags.Active then
        flags_display()
    elseif event == "onToggle" and (arg[1] == "flags" or arg[1] == "affects.flags") then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "affects.flags" then
        config()
    elseif event == "affectAdd" and dslpnp.affects.flags.Active then
        dslpnp.affects.flags.toggleSpell(arg[1], true)
    elseif event == "affectRemove" or event == "affectClear" and dslpnp.affects.flags.Active then
        dslpnp.affects.flags.toggleSpell(arg[1], false)
    end
end

registerAnonymousEventHandler("onToggle", "dslpnp.affects.flags.eventHandler")
registerAnonymousEventHandler("updatePrompt", "dslpnp.affects.flags.eventHandler")
registerAnonymousEventHandler("affectAdd", "dslpnp.affects.flags.eventHandler")
registerAnonymousEventHandler("affectRemove", "dslpnp.affects.flags.eventHandler")
registerAnonymousEventHandler("affectClear", "dslpnp.affects.flags.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.affects.flags.eventHandler")
