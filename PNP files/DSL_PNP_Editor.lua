-- Editor Script
-- 3/10/2014
-- v4.00a
--

dslpnp.editor = dslpnp.editor or {}

dslpnp.editor.help = {[[
    Editor Script

    The editor script is designed to provide some extra functionality when within the
    in-game editor.

    Functions:
    psend("string"<,"string",...<,true or false>>)
]],
["psend"] = [[
    Editor Script
    psend("string"<,"string",...<,true or false>>)

    The psend() function works just like a sendAll or send function. Strings passed through
    as arguments will be sent to the MUD in the order they are placed in the function. Also,
    an optional final argument may be made of true or false on whether or not you want the
    text sent to echo back. However, as an additional function, it will prepend any lines
    sent with ".v '" in the event that you have the in-game editor open.

    Some examples:
    psend("dri decan")

    Will send: dri decan

    However, the above will only get sent once.

    The following:
    psend("dri decan", "dri decan", "dri decan")

    Will send the command three times. You can also use varied commands, such as:

    psend("get decan hoard", "dri decan", "put decan hoard")

    With any of the above examples, the text will be echoed back right before it sends
    to the MUD. However, the following:

    psend("dri decan", false)

    and

    psend("get decan hoard", "dri decan", "put decan hoard", false)

    Will send the text "invisibly" with no echo to your screen.
]],
}

dslpnp.editor.open = dslpnp.editor.open or false

local defaults = {}

function psend(...)
    if dslpnp.editor.open then
        for k,v in ipairs(arg) do
            if type(v) ~= "boolean" then
                arg[k] = ".v '"..v
            end
        end
    end
    sendAll(unpack(arg))
end

local function toggle(setVal)
    dslpnp.editor.Active = dslpnp.toggle("editor",dslpnp.editor.Active, setVal)
    if dslpnp.editor.Active then
        if dslpnp.triggers.exists("Enter Editor Mode Trigger") then dslpnp.triggers.enable("Enter Editor Mode Trigger") end
    else
        if dslpnp.triggers.exists("Enter Editor Mode Trigger") then dslpnp.triggers.disable("Enter Editor Mode Trigger") end
    end
end

local function make_trigger()
    local pattern = [[\-=======\- Entering APPEND Mode \-========\-]]
    local code = [[raiseEvent("onEditorOpen")]]
    if not dslpnp.triggers.exists("Enter Editor Mode Trigger") then
        dslpnp.triggers.register("Enter Editor Mode Trigger","regex",pattern,code)
    end
end

local function config()
    make_trigger()
    raiseEvent("onToggle","editor","on")
end

function dslpnp.editor.eventHandler(event,...)
    if event == "onToggle" and arg[1] == "editor" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "editor" then
        config()
    elseif event == "onEditorOpen" then
        dslpnp.editor.open = true
    elseif event == "onPrompt" and dslpnp.editor.open then
        raiseEvent("onEditorClose")
        dslpnp.editor.open = false
    end
end

registerAnonymousEventHandler("onPrompt", "dslpnp.editor.eventHandler")
registerAnonymousEventHandler("onEditorOpen", "dslpnp.editor.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.editor.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.editor.eventHandler")
