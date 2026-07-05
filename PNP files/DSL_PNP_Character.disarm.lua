-- Character Disarm Script
-- 3/05/2017
-- v4.02c
--

dslpnp.character.disarm = dslpnp.character.disarm or {}
dslpnp.character.disarm.configs = dslpnp.character.disarm.configs or {}

dslpnp.character.disarm.help = {[[
    Character Script : Disarm Plugin

    The disarm plugin relies on the character script and adds functionality to use your
    currently set weapons in order to rearm you quickly and efficiently. It also contains
    options such as "tilde" which allow you a bit more control over what happens when you're
    disarmed. The tilde option, for example, will send a tilde before rearming, clearing
    your in-game queue.

    At the moment, the plugin does not handle being blind well. This is a priority addition
    to the script, if you'd like to help test, let Jor'Mox know. For now, check out the
    rearm alias for these situations.

    Aliases:
    rearm (no arguments) - A simple alias that rearms you. Does not work while blind, but can
                           be used after blind wears off if your disarm trigger didn't fire.
]],
rearm = [[
    Character Script : Disarm Plugin
    Rearm Alias

    Syntax: rearm

    This simple alias does what the disarm plugin already does automatically, rearms you.
    However, the rearm alias provides that functionality through an already existing alias
    which can be handy if the disarm script doesn't fire (such as when blind) or other
    instances where your weapons have been removed and you quickly want to rearm them again.
]]}

local defaults = {
    tilde = true,
}

local have_light = true

local function checkVision()
    if dslpnp.prompt.room == "darkness" then
        if have_light then
            return "blind"
        else
            return "no light"
        end
    else
        return "can see"
    end
    return "error"
end

-- TODO: handle shield cleave
function dslpnp.character.disarm.rearm_shield(arg)
    if dslpnp.character.disarm.Active then
        local vision = checkVision()
    if not arg then arg = "full" end

    if dslpnp.character.disarm.configs.tilde then send("~") end

    if arg == "combat" then
        if vision == "can see" then
            if dslpnp.character.equipment.checkItem("shield") then
                dslpnp.character.equipment.useItem("shield", "wear", "ground")
            end
        else
            -- we can't see, so we can't do anything
        end
    else
        if dslpnp.character.equipment.checkItem("shield") then
            dslpnp.character.equipment.useItem("shield", "wear", "ground")
        end
    end
  end
end

function dslpnp.character.disarm.rearm(arg)
    if dslpnp.character.disarm.Active then
        local vision = checkVision()
        if not arg then arg = "full" end
        assert(arg == "combat" or arg == "full", "Invalid argument!")
        if dslpnp.character.disarm.configs.tilde then send("~") end
        if arg == "combat" then
            if vision == "blind" then
                if dslpnp.character.equipment.checkItem("secondary") and dslpnp.character.equipment.checkItem("sheathed") then
                    dslpnp.character.equipment.useItem("sheathed", "second", "worn")
                elseif dslpnp.character.equipment.checkItem("sheathed") then
                    dslpnp.character.equipment.useItem("sheathed", "wield", "worn")
                end
            elseif vision == "can see" then
                if dslpnp.character.equipment.checkItem("wielded") then
                    dslpnp.character.equipment.useItem("wielded", "wield", "ground")
                end
                if dslpnp.character.equipment.checkItem("secondary") then
                    dslpnp.character.equipment.useItem("secondary", "second", "inventory")
                end
            else
                if dslpnp.character.equipment.checkItem("wielded") and string.find(dslpnp.character.getCharData("wielded")[2],"Glowing") then
                    dslpnp.character.equipment.useItem("wielded", "wield", "ground")
                    if dslpnp.character.equipment.checkItem("secondary") and string.find(dslpnp.character.getCharData("secondary")[2],"Glowing") then
                        dslpnp.character.equipment.useItem("secondary", "second", "inventory")
                    end
                else
                    if dslpnp.character.equipment.checkItem("secondary") and dslpnp.character.equipment.checkItem("sheathed") then
                        dslpnp.character.equipment.useItem("sheathed", "second", "worn")
                    elseif dslpnp.character.equipment.checkItem("sheathed") then
                        dslpnp.character.equipment.useItem("sheathed", "wield", "worn")
                    end
                end
            end
        else
            if dslpnp.character.equipment.checkItem("wielded") then
                dslpnp.character.equipment.useItem("wielded", "wield", "ground")
            end
            if dslpnp.character.equipment.checkItem("sheathed") then
                dslpnp.character.equipment.useItem("sheathed", "sheath", "ground")
            end
            if dslpnp.character.equipment.checkItem("secondary") then
                dslpnp.character.equipment.useItem("secondary", "second", "ground")
            end
        end
    end
end

local function make_aliases()
    if not dslpnp.aliases.exists("Rearm Alias") then
        dslpnp.aliases.register("Rearm Alias", [[^rearm$]], [[dslpnp.character.disarm.rearm("full")]],true)
    end
end

local function make_triggers()
    local trigger_text
    if not dslpnp.triggers.exists("Disarmed Trigger 1") then
        trigger_text = [[^.+ DISARMS you and sends your weapon flying!]]
        dslpnp.triggers.register("Disarmed Trigger 1", "regex", trigger_text, [[raiseEvent("onDisarm")]],true)
    end
    if not dslpnp.triggers.exists("Disarmed Trigger 2") then
        trigger_text = [[^.+ grabs your weapon, and sends it flying!]]
        dslpnp.triggers.register("Disarmed Trigger 2", "regex", trigger_text, [[raiseEvent("onDisarm")]],true)
    end
    if not dslpnp.triggers.exists("Disarmed Trigger 3") then
        trigger_text = [[^.+ knocked loose from their hands by .*]]
        dslpnp.triggers.register("Disarmed Trigger 3", "regex", trigger_text, [[raiseEvent("onShieldDisarm")]],true)
    end
    if not dslpnp.triggers.exists("Disarmed Trigger 4") then
        trigger_text = [[^.+ controls your weapon, and sends it flying!]]
        dslpnp.triggers.register("Disarmed Trigger 4", "regex", trigger_text, [[raiseEvent("onDisarm")]],true)
    end
    if not dslpnp.triggers.exists("Hold Light Trigger") then
        trigger_text = [[^You light (.*) and hold it.$]]
        dslpnp.triggers.register("Hold Light Trigger", "regex", trigger_text, [[raiseEvent("holdLight",matches[2])]],true)
    end
    if not dslpnp.triggers.exists("Light Out Trigger") then
        trigger_text = [[^[\w\s]+ flickers and (goes out).$]]
        dslpnp.triggers.register("Light Out Trigger", "regex", trigger_text, [[raiseEvent("lightOut", matches[2])]],true)
    end

    if not dslpnp.triggers.exists("Shield Disarmed Trigger 1") then
        trigger_text = [[^.+ sends your shield flying with a powerful kick!]]
        dslpnp.triggers.register("Shield Disarmed Trigger 1", "regex", trigger_text, [[raiseEvent("onShieldDisarm")]],true)
    end

    if not dslpnp.triggers.exists("Shield Disarmed Trigger 2") then
        trigger_text = [[^.+ swings \w+ weapon viciously at your shield and sends it flying!]]
        dslpnp.triggers.register("Shield Disarmed Trigger 2", "regex", trigger_text, [[raiseEvent("onShieldDisarm")]],true)
    end

end

local function toggle(setVal)
    dslpnp.character.disarm.Active = dslpnp.toggle("character : disarm", dslpnp.character.disarm.Active, setVal)
    if dslpnp.character.disarm.Active then
        if dslpnp.aliases.exists("Rearm Alias") then
            dslpnp.aliases.enable("Rearm Alias")
        end
    else
        if dslpnp.aliases.exists("Rearm Alias") then
            dslpnp.aliases.disable("Rearm Alias")
        end
    end
end

local function config()
    local configs = dslpnp.config.character and dslpnp.config.character.disarm or {}
    dslpnp.character.disarm.configs = table.update(defaults, configs)
    make_aliases()
    make_triggers()
    raiseEvent("onToggle","character.disarm","on")
end

function dslpnp.character.disarm.eventHandler(event, ...)
    if event == "onDisarm" and dslpnp.character.disarm.Active then
        print(" Disarmed!")
        dslpnp.character.disarm.rearm("combat")
    elseif event == "onShieldDisarm" and dslpnp.character.disarm.Active then
        print(" Shield Disarmed!")
        dslpnp.character.disarm.rearm_shield("combat")
    elseif event == "holdLight" and dslpnp.character.disarm.Active then
        have_light = true
        dslpnp.character.equipment.addItem("light", "", arg[1], 1, false)
    elseif event == "lightOut" and dslpnp.character.disarm.Active then
        if dslpnp.character.getCharData("light",1) == arg[1] or arg[1] == "goes out" then
            have_light = false
            dslpnp.character.equipment.removeItem("light")
        end
    elseif event == "setLight" and dslpnp.character.disarm.Active then
        if arg[1] == "true" then
            have_light = true
        else
            have_light = false
        end
    elseif event == "onToggle" and (arg[1] == "disarm" or arg[1] == "character.disarm") then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "character.disarm" then
        config()
    end
end

registerAnonymousEventHandler("onDisarm", "dslpnp.character.disarm.eventHandler")
registerAnonymousEventHandler("onShieldDisarm", "dslpnp.character.disarm.eventHandler")
registerAnonymousEventHandler("holdLight", "dslpnp.character.disarm.eventHandler")
registerAnonymousEventHandler("lightOut", "dslpnp.character.disarm.eventHandler")
registerAnonymousEventHandler("setLight", "dslpnp.character.disarm.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.character.disarm.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.character.disarm.eventHandler")
