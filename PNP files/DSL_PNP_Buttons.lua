-- Buttons Script
-- 8/09/2015
-- v4.01c
--

dslpnp.buttons = dslpnp.buttons or {}
dslpnp.buttons.commands = dslpnp.buttons.commands or {}
dslpnp.buttons.rows = dslpnp.buttons.rows or {}
dslpnp.buttons.labels = dslpnp.buttons.labels or {}
dslpnp.buttons.configs = dslpnp.buttons.configs or {}

dslpnp.buttons.help = [[
Creates a bank of buttons that can be set to send commands to the mud when clicked

To set the command for a button, use the following command:
set button number command

To name a button, use the following command:
name button number name

To clear the command currently stored in a button, use the following command:
clear button number

Examples:
set button 1 drink decanter
clear button 1
]]

local defaults = {
    rows = 4,
    columns = 6,
    fontSize = 12,
    commands = {},
    names = {},
}
local char_buttons = char_buttons or {}
local char_names = char_names or {}

local function click_button(index)
    if not dslpnp.buttons.commands[index] then
        echo("\nNo command set.")
    else
        expandAlias(dslpnp.buttons.commands[index])
    end
end

local function name_button(index, name, hide_echo, dont_save)
    local configs = dslpnp.buttons.configs or defaults
    if hide_echo == nil then hide_echo = false end
    assert(type(hide_echo) == "boolean", "Argument hide_echo must be a boolean value!")
    index = assert(tonumber(index),"Invalid index!")
    assert(type(name) == "string" or name == nil, "Invalid name!")
    if name == "" or not name then
        if dslpnp.buttons.commands[index] then
            echo(dslpnp.buttons.labels[index],dslpnp.support.formatLabelText(index .. ": " .. dslpnp.buttons.commands[index], configs.fontSize, true, false, false, false, "white"))
        else
            echo(dslpnp.buttons.labels[index],dslpnp.support.formatLabelText(tostring(index), configs.fontSize, true, true, false, false, "white"))
        end
        if not hide_echo then echo("\nClearing button " .. index .. " name.") end
        if not dont_save then
            char_names[index] = nil
        end
    else
        echo(dslpnp.buttons.labels[index],dslpnp.support.formatLabelText(name, configs.fontSize, true, false, false, false, "white"))
        if not hide_echo then echo("\nSetting button " .. index .. " name to '" .. name .. "'.") end
        if not dont_save then
            char_names[index] = name
        end
    end
    if not dont_save then
        dslpnp.character.setCharData(char_names, "button_names")
    end
end

local function set_button(index, cmd, hide_echo, dont_save)
    local configs = dslpnp.buttons.configs or defaults
    if hide_echo == nil then hide_echo = false end
    assert(type(hide_echo) == "boolean", "Argument hide_echo must be a boolean value!")
    index = assert(tonumber(index),"Invalid index!")
    assert(type(cmd) == "string" or cmd == nil, "Invalid command!")
    if cmd == "" or not cmd then
        dslpnp.buttons.commands[index] = nil
        if not dont_save then
            char_buttons[index] = nil
            char_names[index] = nil
        end
        echo(dslpnp.buttons.labels[index],dslpnp.support.formatLabelText(tostring(index), configs.fontSize, true, true, false, false, "white"))
        if not hide_echo then echo("\nClearing button " .. index .. ".") end
    else
        dslpnp.buttons.commands[index] = cmd
        if not dont_save then
            char_buttons[index] = cmd
            char_names[index] = nil
        end
        echo(dslpnp.buttons.labels[index],dslpnp.support.formatLabelText(index .. ": " .. dslpnp.buttons.commands[index], configs.fontSize, true, false, false, false, "white"))
        if not hide_echo then echo("\nSetting button " .. index .. " to '" .. cmd .. "'.") end
    end
    if not dont_save then
        dslpnp.character.setCharData(char_buttons, "buttons")
        dslpnp.character.setCharData(char_names, "button_names")
    end
end

local function load_char_buttons()
    local configs = dslpnp.buttons.configs or defaults
    char_buttons = dslpnp.character.getCharData("buttons") or {}
    char_names = dslpnp.character.getCharData("button_names") or {}
    local index_list = {}
    for k,v in pairs(configs.commands or {}) do
        set_button(k,v,true,true)
        index_list[k] = true
    end
    for k,v in pairs(configs.names or {}) do
       name_button(k, v, true, true)
    end
    for k,v in pairs(char_buttons) do
        set_button(k,v,true,true)
        index_list[k] = true
    end
    for k,v in ipairs(dslpnp.buttons.labels) do
        if not index_list[k] then
            set_button(k,"",true,true)
        end
    end
    for k,v in pairs(char_names) do
        name_button(k,v,true,true)
    end
end

local function make_alias()
    if not dslpnp.aliases.exists("Set Button Alias") then
        dslpnp.aliases.register("Set Button Alias",[[^set button (\d+) (.+)$]],[[raiseEvent("onButtonSet",matches[2], matches[3])]],true)
    end
    if not dslpnp.aliases.exists("Name Button Alias") then
        dslpnp.aliases.register("Name Button Alias",[[^name button (\d+) (.+)$]],[[raiseEvent("onButtonName",matches[2], matches[3])]],true)
    end
    if not dslpnp.aliases.exists("Clear Button Alias") then
        dslpnp.aliases.register("Clear Button Alias",[[^clear button (\d+)$]],[[raiseEvent("onButtonSet",matches[2], nil)]],true)
    end
end

local function config(window_name,x,y,width,height,origin)
    local configs = dslpnp.config.buttons or {}
    configs = table.update(defaults,configs)
    dslpnp.buttons.configs = configs
    local index = 0

    createLabel("button_tab",0,0,0,0,1)
    setLabelClickCallback("button_tab","raiseEvent","onDisplay","buttons")
    dslpnp.sidebar.maketab(window_name,"button_tab","Buttons")
    local b_width = windowManager.math(width,configs.columns,"divide")
    local b_height = windowManager.math(height,configs.rows,"divide")
    local cur_x, cur_y = x, y
    for k1 = 1,configs.rows do
        cur_x = x .. " + " .. width
        for k2 = 1,configs.columns do
            cur_x = windowManager.math(cur_x, b_width, "subtract")
            index = index + 1
            dslpnp.buttons.labels[index] = "button_label_" .. index
            createLabel(dslpnp.buttons.labels[index],0,0,0,0,1)
            windowManager.add(dslpnp.buttons.labels[index],"label",cur_x,cur_y,b_width,b_height,origin)
            setLabelStyleSheet(dslpnp.buttons.labels[index],[[
                background-color: black;
                border: 2px solid white;
                border-radius: 5px;
                qproperty-wordWrap: true;]])
            if dslpnp.buttons.commands[index] then
                echo(dslpnp.buttons.labels[index],dslpnp.support.formatLabelText(index .. ": " .. dslpnp.buttons.commands[index], configs.fontSize, true, false, false, false, "white"))
            else
                echo(dslpnp.buttons.labels[index],dslpnp.support.formatLabelText(tostring(index), configs.fontSize, true, true, false, false, "white"))
            end
            setLabelClickCallback(dslpnp.buttons.labels[index],"raiseEvent","onButtonClick","buttons",index)
        end
        cur_y = cur_y .. " + " .. b_height
    end
    for k,v in pairs(configs.commands or {}) do
        set_button(k, v, true, true)
    end
    for k,v in pairs(configs.names or {}) do
       name_button(k, v, true, true)
    end
    make_alias()
    raiseEvent("onToggle","buttons","on")
end

local function onDisplay()
    dslpnp.sidebar.display("buttons",dslpnp.buttons.labels, "button_tab")
end

local function displayWindow(x,y,width,height)
    local configs = dslpnp.buttons.configs or defaults
    local b_width = windowManager.math(width,configs.columns,"divide")
    local b_height = windowManager.math(height,configs.rows,"divide")
    local cur_x, cur_y, index = x, y, 0
    for k1 = 1,configs.rows do
        cur_x = x .. " + " .. width
        for k2 = 1,configs.columns do
            cur_x = windowManager.math(cur_x, b_width, "subtract")
            index = index + 1
            windowManager.move(dslpnp.buttons.labels[index],cur_x,cur_y)
            windowManager.resize(dslpnp.buttons.labels[index],b_width,b_height)
            showWindow(dslpnp.buttons.labels[index])
        end
        cur_y = cur_y .. " + " .. b_height
    end
end

local function toggle(setVal)
    dslpnp.buttons.Active = dslpnp.toggle("buttons",dslpnp.buttons.Active, setVal)
    if dslpnp.buttons.Active then
        if dslpnp.aliases.exists("Set Button Alias") then
            dslpnp.aliases.enable("Set Button Alias")
        end
        if dslpnp.aliases.exists("Name Button Alias") then
            dslpnp.aliases.enable("Name Button Alias")
        end
        if dslpnp.aliases.exists("Clear Button Alias") then
            dslpnp.aliases.enable("Clear Button Alias")
        end
        for k,v in ipairs(dslpnp.buttons.labels) do
            showWindow(v)
        end
        showWindow("button_tab")
    else
        if dslpnp.aliases.exists("Set Button Alias") then
            dslpnp.aliases.disable("Set Button Alias")
        end
        if dslpnp.aliases.exists("Name Button Alias") then
            dslpnp.aliases.disable("Name Button Alias")
        end
        if dslpnp.aliases.exists("Clear Button Alias") then
            dslpnp.aliases.disable("Clear Button Alias")
        end
        for k,v in ipairs(dslpnp.buttons.labels) do
            hideWindow(v)
        end
        hideWindow("button_tab")
    end
end

function dslpnp.buttons.eventHandler(event, ...)
    if event == "onButtonClick" and arg[1] == "buttons" and dslpnp.buttons.Active then
        click_button(arg[2])
    elseif event == "onButtonSet" and dslpnp.buttons.Active then
        set_button(arg[1],arg[2])
    elseif event == "onButtonName" and dslpnp.buttons.Active then
        name_button(arg[1],arg[2])
    elseif event == "onDisplay" and arg[1] == "buttons" and dslpnp.buttons.Active then
        onDisplay()
    elseif event == "onToggle" and arg[1] == "buttons" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "buttons" then
        config(arg[2], arg[3], arg[4], arg[5], arg[6], arg[7])
    elseif event == "displayWindow" and arg[1] == "buttons" and dslpnp.buttons.Active then
        displayWindow(arg[2], arg[3], arg[4], arg[5])
    elseif event == "characterLoaded" and dslpnp.buttons.Active then
        load_char_buttons()
    end
end

registerAnonymousEventHandler("onButtonClick", "dslpnp.buttons.eventHandler")
registerAnonymousEventHandler("onButtonSet", "dslpnp.buttons.eventHandler")
registerAnonymousEventHandler("onButtonName", "dslpnp.buttons.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.buttons.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.buttons.eventHandler")
registerAnonymousEventHandler("onDisplay", "dslpnp.buttons.eventHandler")
registerAnonymousEventHandler("displayWindow", "dslpnp.buttons.eventHandler")
registerAnonymousEventHandler("characterLoaded", "dslpnp.buttons.eventHandler")
