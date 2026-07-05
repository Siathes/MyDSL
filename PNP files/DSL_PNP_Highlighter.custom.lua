-- Highlighter Script : Custom Plugin
-- 1/04/2016
-- v4.00c
--

dslpnp = dslpnp or {}
dslpnp.highlighter = dslpnp.highlighter or {}
dslpnp.highlighter.custom = dslpnp.highlighter.custom or {}

dslpnp.highlighter.custom.help = dslpnp.highlighter.custom.help or {}
dslpnp.highlighter.custom.help[1] = [[
    Highlighter Script : Custom Plugin

    This plugin allows you to override the default functionality of the
    Highlighter script, which highlights every instance of a name, and
    allows you to define your own lines on which the highlighter should
    trigger.

    Some lines are provided for you by default, those being:
    Where: Players near you:
    Farsight: You quest out with your magic in search of others.
    Scan: Looking around you see:

    Each of these lines are of the "next" class, meaning that they will
    turn on the highlighting trigger to capture all of the lines that follow
    until a prompt is hit.

    However, in defining your own lines, you can also set the "line" class,
    which will tell the trigger to highlight any instances of the name within
    that line.
]]

local defaults = {
    overwrite = true,
    triggers = {
        {pat = [[^Players near you:$]],class = "next"},
        {pat = [[^You quest out with your magic in search of others\.$]],class = "next"},
        {pat = [[^Looking around you see:$]],class = "next"},
        {pat = [[^[\w']+ clan gossips '.*'$]],class = "line"},
    }
}

local color = false

function dslpnp.highlighter.custom.highlight()
    dslpnp.triggers.enable("Custom Highlight All Trigger")
    color = true
end

local function toggle(setVal)
    dslpnp.highlighter.custom.Active = dslpnp.toggle("highlighter.custom",dslpnp.highlighter.custom.Active, setVal)
    if dslpnp.highlighter.custom.Active then
        if dslpnp.triggers.exists("Name Highlighter Trigger") then dslpnp.triggers.disable("Name Highlighter Trigger") end
        if dslpnp.highlighter.custom.configs then
            for i=1,#dslpnp.highlighter.custom.configs.triggers do
                if dslpnp.triggers.exists("Custom Highlight Trigger "..i) then dslpnp.triggers.enable("Custom Highlight Trigger "..i) end
            end
        end
    else
        if dslpnp.triggers.exists("Name Highlighter Trigger") then dslpnp.triggers.enable("Name Highlighter Trigger") end
        if dslpnp.highlighter.custom.configs then
            for i=1,#dslpnp.highlighter.custom.configs.triggers do
                if dslpnp.triggers.exists("Custom Highlight Trigger "..i) then dslpnp.triggers.disable("Custom Highlight Trigger "..i) end
            end
        end
    end
end

local function make_triggers()
    for k,v in ipairs(dslpnp.highlighter.custom.configs.triggers) do
        if not dslpnp.triggers.exists("Custom Highlight Trigger "..k) then
            local code
            if v.class == "next" then
                code = [[dslpnp.highlighter.custom.highlight()]]
            else
                code = [[raiseEvent("onLine",line)]]
            end
            dslpnp.triggers.register("Custom Highlight Trigger "..k,"regex",v.pat,code,true)
        end
    end
    if not dslpnp.triggers.exists("Custom Highlight All Trigger") then
        dslpnp.triggers.register("Custom Highlight All Trigger","regex",[[.]],[[raiseEvent("onLine",line)]])
        dslpnp.triggers.disable("Custom Highlight All Trigger")
    end
end

local function config()
    dslpnp.highlighter.custom.configs = dslpnp.config.highlighter.custom or {}
    dslpnp.highlighter.custom.configs = table.update(defaults,dslpnp.highlighter.custom.configs)
    make_triggers()
    raiseEvent("onToggle","highlighter.custom","on")
end

function dslpnp.highlighter.custom.eventHandler(event,...)
    if event == "onToggle" and arg[1] == "highlighter.custom" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "highlighter.custom" then
        config()
    elseif event == "onPrompt" and color then
        dslpnp.triggers.disable("Custom Highlight All Trigger")
        color = false
    end
end

registerAnonymousEventHandler("onLine","dslpnp.highlighter.custom.eventHandler")
registerAnonymousEventHandler("onPrompt","dslpnp.highlighter.custom.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.highlighter.custom.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.highlighter.custom.eventHandler")
