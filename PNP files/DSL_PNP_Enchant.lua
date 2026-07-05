-- Enchant Script
-- 11/17/2015
-- v4.02b
--

dslpnp.enchant = dslpnp.enchant or {}
dslpnp.enchant.buttons = dslpnp.enchant.buttons or {}
dslpnp.enchant.configs = dslpnp.enchant.configs or {}
dslpnp.enchant.help = [[
Type "toggle enchant" to disable or enable this script.

To set the item to enchant, use the following command:
set item armor helmet  or  set item weapon fancy sword

To set containers to get items from, or to put finished items into, use the following command:
set item container bag  or  set item storage vault

To manually set or reset the enchantment level on an item manually, use the following command:
set enchant 5  or  reset enchant
]]

local defaults = {
    fontSize = 12,
    auto_enchant = 0
}

local current_items = {}
local current_enchant = {}
local current_type = nil
local button_list = {"enchant_button", "restore_button","disenchant_button", "identify_button", "get_item_button"}
local button_text = {"Enchant", "Restore", "Disenchant", "Identify", "Get Item"}
local enchanting = false

local function update_label()
    local text = "Item: " .. current_items[current_type] .. "<br>Enchant: "
    if current_enchant[current_type] == -1 then
        text = text .. "destroyed"
    else
        if current_type == "armor" then
            text = text .. "-" .. current_enchant[current_type]
        else
            text = text .. "+"  .. current_enchant[current_type] .. "/+" .. current_enchant[current_type]
        end
    end
    if dslpnp.enchant.configs.auto_enchant and dslpnp.enchant.configs.auto_enchant ~= 0 then
        text = text .. " (" .. dslpnp.enchant.configs.auto_enchant .. ")"
    end
    echo("enchant_label",dslpnp.support.formatLabelText(text, nil, true, false, false, false, "white"))
end

local function cast_on_item(spell, item_type)
    if item_type == nil then item_type = current_type end
    assert(item_type == "weapon" or item_type == "armor", "Type must be weapon or armor!")
    if spell ~= "identify" and spell ~= "disenchant" then spell = spell .. " " .. item_type end
    if type(current_items[item_type]) ~= "string" then
        echo("No " .. item_type .. " set!\n")
    end
    send("cast '" .. spell .. "' '" .. current_items[item_type] .. "'")
end

local function get_item(item_type)
    if item_type == nil then item_type = current_type end
    assert(item_type == "weapon" or item_type == "armor", "Type must be weapon or armor!")
    if type(current_items[item_type]) ~= "string" then
        echo("No " .. item_type .. " set!\n")
    end
    if type(current_items["container"]) ~= "string" then
        echo("No container set!\n")
    end
    if current_enchant[item_type] ~= -1 and current_items["storage"] ~= nil then
        send("put '" .. current_items[item_type] .. "' '" .. current_items["storage"] .. "'")
    end
    send("get '" .. current_items[item_type] .. "' '" .. current_items["container"] .. "'")
    dslpnp.enchant.reset_item(current_type)
end

function dslpnp.enchant.enchant_item(enchant, item_type, set_value)
    if dslpnp.enchant.Active then
        enchant = math.modf(tonumber(enchant))
        if set_value == nil then set_value = false end
        if item_type == nil then item_type = current_type end
        assert(item_type == "weapon" or item_type == "armor", "Type must be weapon or armor!")
        assert(set_value == true or set_value == false, "Invalid set_value!")
        if type(current_items[item_type]) ~= "string" then
            echo("No " .. item_type .. " set!\n")
        end
        if set_value then
            enchanting = false
            current_enchant[item_type] = enchant
        else
            assert(enchant >= 0 and enchant < 4, "Enchant value must be between 0 and 3!")
            if type(current_enchant[item_type]) ~= "number" then
                current_enchant[item_type] = enchant
            else
                current_enchant[item_type] = current_enchant[item_type] + enchant
            end
        end
        if enchanting and dslpnp.enchant.configs.auto_enchant ~= nil and current_enchant[item_type] < dslpnp.enchant.configs.auto_enchant then
            cast_on_item("enchant")
        else
            enchanting = false
            raiseEvent("onEnchantGoal",current_enchant[item_type])
        end
        current_type = item_type
        update_label()
        echo("\n" .. string.title(current_items[item_type]) .. " enchanted to " .. current_enchant[item_type] .. ".\n")
    end
end

function dslpnp.enchant.set_item(name, item_type)
    if dslpnp.enchant.Active then
        assert(type(name) == "string", "Invalid name!")
        assert(item_type == "weapon" or item_type == "armor" or item_type == "container" or item_type == "storage", "Type must be weapon, armor, container or storage!")
        if item_type == "armor" or item_type == "weapon" then
            if current_items[item_type] ~= name then
                current_enchant[item_type] = 0
            end
        end
        current_items[item_type] = name
        if item_type == "weapon" or item_type == "armor" then
            current_type = item_type
        end
        enchanting = false
        update_label()
        echo(string.title(item_type) .. " set to " .. name .. ".\n")
    end
end

function dslpnp.enchant.reset_item(item_type)
    if dslpnp.enchant.Active then
        if item_type == nil then item_type = current_type end
        assert(item_type == "weapon" or item_type == "armor", "Type must be weapon or armor!")
        if type(current_items[item_type]) ~= "string" then
            echo("No " .. item_type .. " set!\n")
        end
        enchanting = false
        current_enchant[item_type] = 0
        update_label()
    end
end

function dslpnp.enchant.set_auto_enchant(enchant)
    if dslpnp.enchant.Active then
        dslpnp.enchant.configs.auto_enchant = tonumber(enchant)
        echo("Auto-enchant set to: " .. enchant .. ".")
        update_label()
    end
end

function dslpnp.enchant.start_enchant()
    enchanting = true
    cast_on_item("enchant")
end

function dslpnp.enchant.stop_enchant()
    enchanting = false
end

function dslpnp.enchant.new_item()
    get_item()
end

function dslpnp.enchant.restore_item()
    cast_on_item("restore")
end

local function handle_button_press(button_name)
    if current_type ~= nil and type(current_items[current_type]) ~= "string" then
        if current_type ~= nil then
            echo("No " .. current_type .. " set!\n")
        else
            echo("No item set!\n")
        end
    end
    enchanting = false
    if button_name == "enchant_button" then
        enchanting = true
        cast_on_item("enchant")
    elseif button_name == "restore_button" then
        cast_on_item("restore")
    elseif button_name == "identify_button" then
        cast_on_item("identify")
    elseif button_name == "get_item_button" then
        get_item()
    elseif button_name == "disenchant_button" then
        cast_on_item("disenchant")
    end
end

local function handle_triggers(whole_text,match)
    if current_items[current_type] and (string.find(whole_text, current_items[current_type]) ~= nil or match == "Nothing seemed to happen") then
        if match == "glows blue" or match == "shimmers with a gold aura" then
            dslpnp.enchant.enchant_item(1)
        elseif match == "glows a brilliant blue" or match == "glows a brilliant gold" then
            dslpnp.enchant.enchant_item(2)
        elseif match == "glows a brilliant white" then
            dslpnp.enchant.enchant_item(3)
        elseif match == "glows brightly, then fades...oops" or match == "glows brightly, then fades to a dull color" or match == "restored to it's original form" then
            dslpnp.enchant.reset_item()
            raiseEvent("onEnchantFade")
        elseif match == "shivers violently and explodes" or match == "crumbles into dust" or match == "flares blindingly... and evaporates" then
            dslpnp.enchant.reset_item()
            current_enchant[current_type] = -1
            update_label()
            raiseEvent("onEnchantExplode")
        elseif match == "Nothing seemed to happen" then
            dslpnp.enchant.enchant_item(0)
        else
            display(match)
        end
    end
end

local function make_triggers()
    local trigger_text = {
        [[^.* (glows blue)]],
        [[^.* (glows a brilliant blue)]],
        [[^.* (glows a brilliant white)]],
        [[^.* (shivers violently and explodes)]],
        [[^.* (restored to it's original form)]],
        [[^.* (crumbles into dust)]],
        [[^.* (glows a brilliant gold)]],
        [[^.* (shimmers with a gold aura)]],
        [[^.* (glows brightly, then fades...oops)]],
        [[^.* (glows brightly, then fades to a dull color)]],
        [[^.* (flares blindingly... and evaporates)]],
        [[^(Nothing seemed to happen).$]]
    }
    local trigger_code = [[raiseEvent("onEnchant",matches[1], matches[2])]]
    for k = 1, #trigger_text do
        if not dslpnp.triggers.exists("Enchanting Trigger" .. k) then
            dslpnp.triggers.register("Enchanting Trigger" .. k,"regex",trigger_text[k],trigger_code,true)
        end
    end
end

local function make_aliases()
    if not dslpnp.aliases.exists("Set Item Alias") then
        dslpnp.aliases.register("Set Item Alias",[[^set item (\w+) (.+)$]],[[dslpnp.enchant.set_item(matches[3], matches[2])]],true)
    end

    if not dslpnp.aliases.exists("Reset Enchant Alias") then
        dslpnp.aliases.register("Reset Enchant Alias",[[^reset enchant$]], [[dslpnp.enchant.reset_item()]], true)
    end
    if not dslpnp.aliases.exists("Set Enchant Alias") then
        dslpnp.aliases.register("Set Enchant Alias",[[^set enchant (\d+)$]], [[dslpnp.enchant.enchant_item(matches[2], nil, true)]], true)
    end
    if not dslpnp.aliases.exists("Set Auto Enchant Alias") then
        dslpnp.aliases.register("Set Auto Enchant Alias",[[^set auto (\d+)$]],[[dslpnp.enchant.set_auto_enchant(matches[2])]],true)
    end
end

local function config(window_name,x,y,width,height,origin)
    local configs = dslpnp.config.enchant or {}
    configs = table.update(defaults,configs)
    dslpnp.enchant.configs = configs
    local b_height = windowManager.math(height,7,"divide")
    local e_height = windowManager.math(b_height,2,"multiply")
    createLabel("enchant_label",0,0,0,0,1)
    setLabelStyleSheet("enchant_label",[[
        background-color: black;
        border: 2px solid white;
        border-radius: 5px;
        font-size:  ]] .. configs.fontSize)

    windowManager.add("enchant_label","label",x,y,width,e_height,origin)
    hideWindow("enchant_label")
    y = y .. " + " .. e_height
    for k,v in ipairs(button_list) do
        createLabel(v,0,0,0,0,1)
        setLabelStyleSheet(v,[[
            background-color: black;
            border: 2px solid white;
            border-radius: 5px;
            font-size: ]] .. configs.fontSize)
        windowManager.add(v,"label",x,y,width,b_height,origin)
        dslpnp.enchant.buttons[k] = v
        echo(v,dslpnp.support.formatLabelText(button_text[k], nil, true, true, false, false, "white"))
        setLabelClickCallback(v,"raiseEvent","onButtonClick","enchant", v)
        hideWindow(v)
        y = y .. " + " .. b_height
    end

    createLabel("enchant_tab",0,0,0,0,1)
    setLabelClickCallback("enchant_tab","raiseEvent","onDisplay","enchant")
    dslpnp.sidebar.maketab(window_name,"enchant_tab","Enchanting")

    make_triggers()
    make_aliases()
    raiseEvent("onToggle","enchant","on")
end

local function onDisplay()
    local window_list = table.n_union({"enchant_label"},button_list)
    dslpnp.sidebar.display("enchant", window_list, "enchant_tab")
end

local function toggle(setVal)
    dslpnp.enchant.Active = dslpnp.toggle("enchant",dslpnp.enchant.Active, setVal)
    if dslpnp.enchant.Active then
        showWindow("enchant_tab")
        if dslpnp.aliases.exists("Set Item Alias") then
            dslpnp.aliases.enable("Set Item Alias")
        end
        if dslpnp.aliases.exists("Reset Enchant Alias") then
            dslpnp.aliases.enable("Reset Enchant Alias")
        end
        if dslpnp.aliases.exists("Set Enchant Alias") then
            dslpnp.aliases.enable("Set Enchant Alias")
        end
        if dslpnp.aliases.exists("Set Auto Enchant Alias") then
            dslpnp.aliases.enable("Set Auto Enchant Alias")
        end
    else
        hideWindow("enchant_tab")
        local window_list = table.n_union({"enchant_label"},button_list)
        for k,v in ipairs(window_list) do
            hideWindow(v)
        end
        if dslpnp.aliases.exists("Set Item Alias") then
            dslpnp.aliases.disable("Set Item Alias")
        end
        if dslpnp.aliases.exists("Reset Enchant Alias") then
            dslpnp.aliases.disable("Reset Enchant Alias")
        end
        if dslpnp.aliases.exists("Set Enchant Alias") then
            dslpnp.aliases.disable("Set Enchant Alias")
        end
        if dslpnp.aliases.exists("Set Auto Enchant Alias") then
            dslpnp.aliases.disable("Set Auto Enchant Alias")
        end
    end
end

local function displayWindow(x,y,width,height)
    height = windowManager.math(height,7,"divide")
    windowManager.move("enchant_label",x,y)
    windowManager.resize("enchant_label",width, windowManager.math(height,2,"multiply"))
    showWindow("enchant_label")
    y = y .. " + " ..  windowManager.math(height,2,"multiply")
    for k,v in ipairs(button_list) do
        windowManager.move(v,x,y)
        windowManager.resize(v,width, height)
        showWindow(v)
        y = y .. " + " ..  height
    end
end

function dslpnp.enchant.eventHandler(event, ...)
    if event == "onEnchant" and dslpnp.enchant.Active then
        handle_triggers(matches[1],matches[2])
    elseif event == "onButtonClick" and arg[1] == "enchant" and dslpnp.enchant.Active then
        handle_button_press(arg[2])
    elseif event == "onToggle" and arg[1] == "enchant" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "enchant" then
        config(arg[2], arg[3], arg[4], arg[5], arg[6], arg[7])
    elseif event == "onDisplay" and arg[1] == "enchant" and dslpnp.enchant.Active then
        onDisplay()
    elseif event == "displayWindow" and arg[1] == "enchant" and dslpnp.enchant.Active then
        displayWindow(arg[2], arg[3], arg[4], arg[5])
    end
end

registerAnonymousEventHandler("onToggle", "dslpnp.enchant.eventHandler")
registerAnonymousEventHandler("onEnchant", "dslpnp.enchant.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.enchant.eventHandler")
registerAnonymousEventHandler("onDisplay", "dslpnp.enchant.eventHandler")
registerAnonymousEventHandler("onButtonClick", "dslpnp.enchant.eventHandler")
registerAnonymousEventHandler("displayWindow", "dslpnp.enchant.eventHandler")
