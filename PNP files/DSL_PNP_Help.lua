-- Help Script
-- 9/11/2016
-- v4.03e
--

dslpnp.help = dslpnp.help or {}
dslpnp.help.topics = {} -- populated during config
dslpnp.help.all = [[
    DSLPNP Help

    DSLPNP provides a collection of preconfigured scripts and aliases for use with DSL.
    These scripts are highly customizable, and may be configured using the "Config Script"
    that you can find under the "DSL_PNP_4" folder in the Mudlet Scripts tab.

    You can find more detailed information about each script by reading the script
    specific help files.

    For example to find more information about the "Battle Condenser" script you can
    type in: <yellow>help dslpnp battle<reset>

    You can find a full list of topics below:
]]

local defaults = {
    line_length = 100,
}

local previous
local previous_name
local MAX_DEPTH = 3

local function findHelpTopics(script, name, depth)
    if depth > MAX_DEPTH then
        return
    end

    for topic,_ in pairs(script) do
        if topic == "help" then
            table.insert(dslpnp.help.topics, name)
        elseif topic ~= "__index" and type(script[topic]) == "table" then
            findHelpTopics(script[topic], name .. "." .. topic, depth + 1)
        end
    end
end

-- dynamically loads help topics from scripts
local function configureHelpTopics()
    dslpnp.help.topics = {}

    for topic,_ in pairs(dslpnp) do
        -- No need to index this helpfile
        if topic ~= "help" and type(dslpnp[topic]) == "table" then
            findHelpTopics(dslpnp[topic], topic, 1)
        end
    end

    table.sort(dslpnp.help.topics)
end

-- prints help for all configured topics
local function getHelpAll()
    local topics = dslpnp.help.topics
    local width,format_str = 0,""
    cecho(dslpnp.support.wrapLines(dslpnp.help.all,dslpnp.help.configs.line_length,"    "))
    echo("\n")
    for _, topic in ipairs(topics) do
        width = math.max(width,#topic)
    end
    width = width + 1
    format_str = "      %-"..width.."s %-"..width.."s %-"..width.."s\n"
    for i=1, #dslpnp.help.topics,3 do
        cecho(string.format(format_str, topics[i], topics[i+1], topics[i+2]))
    end
end

local function getHelp(main, sub)
    if not main or string.lower(main) == "all" then
        return getHelpAll()
    end

    local name = string.gsub(main,"%w+",string.title)

    if sub == "" or not sub then sub = 1 end
    main = string.lower(main)
    local tmp = string.split(main,"%.")
    local second
    if tmp[2] then
        main = tmp[1]
        second = tmp[2]
    end

    local script
    if dslpnp[main] then
        script = dslpnp[main]
        if second and script[second] then
            script = script[second]
        end
        previous = script
        previous_name = name
    else
        script = previous
        name = previous_name
        if sub ~= 1 then
            sub = main .. " " .. sub
        else
            sub = main
        end
        if script and script[sub] and script[sub].help then
            script = script[sub]
            name = name .. "." .. sub
            previous = script
            previous_name = name
            sub = 1
        end
    end

    if not script then
        print("No help on script: " .. name .. " available.")
        return
    end

    local help = script.help
    if type(help) == "table" and not help[sub] then
        for k,v in pairs(help) do
            if string.lower(k) == string.lower(sub) then
                sub = k
                break
            end
        end
    end
    if type(help) == "string" then
        cecho(dslpnp.support.wrapLines(help,dslpnp.help.configs.line_length,"    "))
    elseif help and help[sub] then
        cecho(dslpnp.support.wrapLines(help[sub],dslpnp.help.configs.line_length,"    "))

        -- Show user list of additional help keywords for this topic
        if type(help) == "table" then
            print("\n    For additional help see: ")
            for sub_help, _ in pairs(help) do
                if type(sub_help) == "string" and sub_help ~= sub then
                    cecho("    <yellow>help dslpnp " .. main .. " " .. sub_help .. "<reset>\n")
                end
            end
        end
    else
        if sub ~= 1 then
            print("No help on topic: " .. string.title(sub) .. " for script: " .. name .. " available.")
        else
            print("No help on script: " .. name .. " available.")
        end
    end
end

local function config()
    dslpnp.help.configs = table.update(defaults,dslpnp.config.help or {})
    if not dslpnp.aliases.exists("PNP Help Alias") then
        -- pnphelp <foo>
        -- help dslpnp <foo>
        -- help pnp <foo>
        -- <foo> is optional. If no topic is specified then "help all" will be displayed
        dslpnp.aliases.register("PNP Help Alias",[[^(?:pnphelp|help (?:dsl)?pnp)(?: ([\w\.]+)\s?(.*))?]],[[raiseEvent("onHelp",matches[2],matches[3])]],true)
    end

    configureHelpTopics()
end

function dslpnp.help.eventHandler(event, ...)
    if event == "onConfig" and arg[1] == "help" then
        config()
    elseif event == "onHelp" then
        getHelp(arg[1],arg[2])
    end
end

registerAnonymousEventHandler("onConfig","dslpnp.help.eventHandler")
registerAnonymousEventHandler("onHelp","dslpnp.help.eventHandler")
