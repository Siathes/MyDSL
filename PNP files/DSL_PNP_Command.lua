-- Command Script
-- 11/08/2016
-- v4.00a
-- Originally by: Jor'Mox
-- Modified by: --
--

dslpnp.command = dslpnp.command or {}
dslpnp.command.configs = dslpnp.command.configs or {}

local defaults = {
    spam_guard = true,
    spam_count = 10,
    send_break = true,
    spam_break = "SPAM GUARD!!!",
    show_break = true,
}

local exempt = {'n','s','e','w','d','u','ne','nw','sw','se',
    'northeast','northwest','southeast','southwest',
    'north','south','east','west','up','down',}

local previous_command
local rep_count

local function config()
    local configs = table.update(defaults, dslpnp.config.command or {})
    dslpnp.command.configs = configs
end

function dslpnp.command.match(pattern)
    local match = string.match(previous_command, pattern)
    pattern = string.gsub(pattern,"^%^","")
    pattern = string.gsub(pattern,"%$$","")
    if match and match == previous_command and pattern ~= match then
        return false, "Pattern too generic."
    end
    return match
end

function dslpnp.command.eventHandler(event, command)
    if event == "onConfig" and command == "command" then
        config()
    else
        local configs = dslpnp.command.configs
        rep_count = ((previous_command == command and rep_count) or 0) + 1
        previous_command = command or nil
        if configs.spam_guard and rep_count > configs.spam_count and not table.contains(exempt,command) then
            raiseEvent("onSpamBreak",command)
            if configs.send_break then
                send(configs.spam_break, configs.show_break)
            end
        end
    end
end

registerAnonymousEventHandler("onConfig","dslpnp.command.eventHandler")
registerAnonymousEventHandler("sysDataSendRequest","dslpnp.command.eventHandler")
