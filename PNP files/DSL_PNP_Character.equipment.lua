-- Character Equipment Script
-- 8/09/2018
-- v4.01n
--

dslpnp.character.equipment = dslpnp.character.equipment or {}

dslpnp.character.equipment.help = {[[
    Character Script : Equipment Plugin

    When you view your equipment, it is automatically added to the database for that character.

    The following functions are available to help manage and/or use this information
    dslpnp.character.addItem(slot, flags, item, index, display)
    dslpnp.character.removeItem(slot)
    dslpnp.character.checkItem(slot)
    dslpnp.character.setItemKey(slot, key, slot_index, index)
    dslpnp.character.useItem(slot, command, location)

    The addItem function is used to add an item to a character's equipment. It takes the
    following arguments:
    Slot - The equipment slot the item will occupy. Possible slots are: light, finger1,
           finger2, neck1, neck2, torso, head, legs, feet, arms, hands, shield, body,
           waist, wrist1, wrist2, wielded, held, floating, sheathed, secondary, and quiver
    Flags - All the flags on the item, like "(Glowing)" or "(Humming)". These aren't
            currently used for anything, but are stored just in case they are needed or wanted.
    Item - The item name as it appears in inventory or while worn. For example:
           "an arcanium shield".
    Index - This is added to allow for equipment sets to be implimented later. Currently,
            this should be "1".
    Display - A true or false value to tell the script if it should notify you if the item
              being added is new.

    The removeItem function allows you to manually remove an item from a character's equipment.

    The checkItem function returns true if an item is stored in the equipment slot it
    is given, and false if one is not.

    The setItemKey function is used to change the keyword phrase used to work with an item.
    This is important for items that have keywords that do not line up with their displayed
    name. This is mainly used with the "set keyword" alias. To use the alias, use the
    following command:
        set keyword shield 'arcanium shield'  or  set keyword finger 'fancy ring' 1  or
        set keyword finger2 'ugly ring'  (the number at the end determine which finger,
        wrist, or neck slot to use if not specified otherwise)

    The useItem function is how you interact with items that are part of a character's equipment.
    Slot is used to identify the item you want
    Command is the command to use on the item (as it would be typed)
    Location identifies where the item is currently, it can be "worn", "inventory",
    "ground", or the name of a container it is inside of.
    Items will be removed or retrieved from their location so that they are located in
    your inventory before the command is executed.
    Example:
    dslpnp.character.useItem("wielded","wear","ground")
        this would retrieve your weapon from the ground and wield it.

]]}

local ring_index, neck_index, wrist_index
local key_words = {"a", "an", "the", "some", "of", "and"}
local slot_list = slot_list or {}

local function displayChar()
    if curChar.name then
        echo(" : Current character: " .. curChar.name)
    else
        echo(" : No character loaded.\n")
    end
end

local function parseKey(item)
    assert(type(item) == "string", "Invalid item!")
    item = string.gsub(item, "'s ", " ")
    item = string.gsub(item, ",", "")

    local equipment = dslpnp.character.getCharData("equipmentKeywords") or {}
    local key = equipment[item]

    local tbl = string.split(item," ")
    local k = 1
    while k < #tbl do
        if table.contains(key_words, tbl[k]) then table.remove(tbl,k) else k = k + 1 end
    end
    local new_key = table.concat(tbl," ")
    new_key = string.trim(new_key)

    if new_key == key then
        equipment[item] = nil
        dslpnp.character.setCharData(equipment, "equipmentKeywords")
    end
    return key or new_key
end

local function parseSlot(slot)
    assert(type(slot) == "string", "Invalid slot!")
    local words = {"worn ","used ","as ","on ","around ","about "," nearby"," weapon"}
    for k,v in ipairs(words) do
        slot = string.gsub(slot,v,"")
    end
    slot = string.trim(slot)
    return slot
end

local function addSlot(slot)
    assert(type(slot) == "string", "Invalid slot!")
    slot_list = dslpnp.character.getCharData("slot_list") or {}
    if not table.contains(slot_list, slot) then
        table.insert(slot_list, slot)
        dslpnp.character.setCharData(slot_list, "slot_list")
    end
end

local function gatherEQ()
    local name = dslpnp.character.getCharData("name")
    if name then
        echo(" : Current character: " .. name)
        dslpnp.triggers.enable("EQ Scanning Trigger")
        dslpnp.timers.register(1, [[dslpnp.triggers.disable("EQ Scanning Trigger")]])
        ring_index = 0
        neck_index = 0
        wrist_index = 0
    end
end

--local function setEquipmentKeywords(item, key, force)
--    local equipment = dslpnp.character.getCharData("equipmentKeywords") or {}
--    if force or not equipment[item] then
--        equipment[item] = key
--        dslpnp.character.setCharData(equipment, "equipmentKeywords")
--    end
--end

function dslpnp.character.equipment.addItem(slot, flags, item, index, display)
    if dslpnp.character.equipment.Active then
        if display == nil then display = true end
        assert(type(display) == "boolean", "Invalid display!")
        assert(type(slot) == "string", "Invalid slot!")
        assert(type(flags) == "string", "Invalid flags!")
        assert(type(item) == "string", "Invalid item!")
        -- index to be used for possible multiple item sets
        if not index then index = 1 end
        index = assert(tonumber(index), "Invalid index!")
        item = string.gsub(item,'"',"")
        item = string.gsub(item, "\n", "")
        slot = parseSlot(slot)
        if slot == "finger" then ring_index = ring_index + 1 ; slot = slot .. ring_index end
        if slot == "neck" then neck_index = neck_index + 1 ; slot = slot .. neck_index end
        if slot == "wrist" then wrist_index = wrist_index + 1 ; slot = slot .. wrist_index end
        local tmpItem = dslpnp.character.getCharData(slot) or {}

        if flags == "(nothing)" then item = "nothing" ; flags = "" end
        if slot == "light" then
            if item == "nothing" then
                raiseEvent("setLight","false")
            else
                raiseEvent("setLight","true")
            end
        end
        if (table.is_empty(tmpItem)) or (tmpItem[1] ~= item) then
            local key = parseKey(item)
            if display then
                echo(" : NEW ITEM")
                echo(" : '" .. key .. "'")
            end
            dslpnp.character.setCharData({item, flags, key, index}, slot)
--            setEquipmentKeywords(item, key, false)
        end
        addSlot(slot)
    end
end

function dslpnp.character.equipment.removeItem(slot)
    if dslpnp.character.equipment.Active then
        assert(type(slot) == "string" and dslpnp.character.getCharData(slot), "Invalid slot!")
        dslpnp.character.setCharData({"nothing", "", "nothing", 1}, slot)
        echo("Item in slot " .. slot .. " set to nothing.")
    end
end

function dslpnp.character.equipment.setItemKey(slot, key, slot_index, index)
    if dslpnp.character.Active then
        assert(type(slot) == "string", "Invalid slot!")
        assert(type(key) == "string", "Invalid keyword!")
        key = string.trim(key)
        if slot_index then slot = slot .. slot_index end
        if not index then index = 1 end
        index = assert(tonumber(index), "Invalid index!")
        local tmpItem = dslpnp.character.getCharData(slot)
        if not tmpItem or item == "nothing" or #key == 0 then return end
        dslpnp.character.setCharData({tmpItem[1], tmpItem[2], key, index}, slot)
        local equipment = dslpnp.character.getCharData("equipmentKeywords") or {}
        equipment[tmpItem[1]] = key
        dslpnp.character.setCharData(equipment, "equipmentKeywords")
--        setEquipmentKeywords(tmpItem[1], key, true)
        print(string.title(slot) .. " keyword set to '" .. key .. "'.")
    end
end

function dslpnp.character.equipment.checkItem(slot)
    assert(type(slot) == "string", "Invalid slot!")
    local tmpItem = dslpnp.character.getCharData(slot) or {}
    if tmpItem[1] and tmpItem[1] ~= "nothing" then return tmpItem[1] else return false end
end

function dslpnp.character.equipment.useItem(slot, command, location)
    if dslpnp.character.equipment.Active then
        tmpItem = assert(dslpnp.character.getCharData(slot), "Invalid slot!")
        assert(type(command) == "string", "Invalid command!")
        assert(not location or type(location) == "string", "Invalid location!")
        if not location then location = "worn" end
        local key = assert(tmpItem[3], "No keywords set!")
        local tmpstr = string.sub(slot,1,#slot-1) .. "1"
        local tmpSecond = dslpnp.character.getCharData(tmpstr) or {}
        if location == "worn" and string.sub(slot, -1) == "2" and tmpSecond[3] == tmpItem[3] then
            key = "2." .. key
        end
        if location == "ground" then
            send("get '" .. key .. "'")
        elseif location ~= "worn" and location ~= "inventory" then
            send("get '" .. key .. "' " .. location)
        end
    -- WORKAROUND TO LET BLESS BE USED UNTIL IT IS FIXED IN GAME -- SCORN SAYS "WILL NOT BE FIXED"
        if not string.find(command, "bless") then
            send(command .. " '" .. key .. "'")
        else
            send(command .. " " .. key)
        end
    end
end

function dslpnp.character.equipment.clearItemKeys()
    dslpnp.character.setCharData({},"equipmentKeywords")
    print("All custom item keywords cleared for this character.")
end

local function make_aliases()
    if not dslpnp.aliases.exists("Set Item Key Alias") then
        dslpnp.aliases.register("Set Item Key Alias",[[^set keyword (\w+) '([\w\s]+)'\s?(\w*)]], [[dslpnp.character.equipment.setItemKey(matches[2],matches[3],matches[4])]], true)
    end
    if not dslpnp.aliases.exists("Clear Item Keys Alias") then
        dslpnp.aliases.register("Clear Item Keys Alias",[[^clear keywords$]], [[dslpnp.character.equipment.clearItemKeys()]], true)
    end
end

local function make_triggers()
    local trigger_text
    if not dslpnp.triggers.exists("EQ Trigger") then
        trigger_text = [[^You are using:$]]
        dslpnp.triggers.register("EQ Trigger","regex",trigger_text,[[raiseEvent("onEQ",matches[1])]], true)
    end
    if not dslpnp.triggers.exists("EQ Scanning Trigger") then
        trigger_text = [[^<([a-z\s]+)>\s*([a-zA-Z\(\)\"\s]*?)\s*([a-zA-Z\-\'\"\s,]*)$]]
        dslpnp.triggers.register("EQ Scanning Trigger","regex",trigger_text,[[dslpnp.character.equipment.addItem(matches[2], matches[3], matches[4])]], false)
    end

end

local function toggle(setVal)
    dslpnp.character.equipment.Active = dslpnp.toggle("character : equipment", dslpnp.character.equipment.Active, setVal)
    if dslpnp.character.equipment.Active then
        if dslpnp.aliases.exists("Set Item Key Alias") then
            dslpnp.aliases.enable("Set Item Key Alias")
        end
    else
        if dslpnp.triggers.exists("EQ Scanning Trigger") then
            dslpnp.triggers.disable("EQ Scanning Trigger")
        end
        if dslpnp.aliases.exists("Set Item Key Alias") then
            dslpnp.aliases.disable("Set Item Key Alias")
        end
        if dslpnp.aliases.exists("Clear Item Keys Alias") then
            dslpnp.aliases.disable("Clear Item Keys Alias")
        end
    end
end

local function config()
    make_aliases()
    make_triggers()
    raiseEvent("onToggle","character.equipment","on")
    curChar = {}
end

function dslpnp.character.equipment.eventHandler(event, ...)
    if event == "onEQ" and dslpnp.character.equipment.Active then
        gatherEQ()
    elseif event == "onToggle" and arg[1] == "character.equipment" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "character.equipment" then
        config()
    end
end

registerAnonymousEventHandler("onEQ", "dslpnp.character.equipment.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.character.equipment.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.character.equipment.eventHandler")
