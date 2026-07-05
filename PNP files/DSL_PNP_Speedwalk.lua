-- Speedwalk Script
-- 4/27/2018
-- v4.01c
--

dslpnp.speedwalk = dslpnp.speedwalk or {}
dslpnp.data.speedwalk = dslpnp.data.speedwalk or {}

dslpnp.speedwalk.help = {[[
    Speedwalk Script

    The speedwalk script allows players to easily set paths and access them via name in
    order to cut down on the number of commands to be manually sent in order to get from
    point A to point B.

    Aliases:
    walk ('name name'|name)
    set path ('name'|name) (d1,d2,d3)
    reverse ('name name'|name)
    show paths
]],
["walk"] = [[
    Speedwalk Script
    Walk Alias

    Syntax: walk ('name name'|name)

    name - There's only one argument for the walk alias, but, multi-word names with spaces
        need to be put in single quotes. For instance, if you set a path for 'Gahboom Hill'
        as opposed to Gahboom. If your name is a single word, you can leave it out of the
        quotes.

    Giving the walk alias a name will tell it to send the given set of directions from the
    path associated with that name to the MUD. Make sure you're in the same room as where
    you set the path!
]],
["set path"] = [[
    Speedwalk Script
    Set Path Alias

    Syntax: set path ('name'|name) (d1,d2,d3)

    name - There's only one argument for the walk alias, but, multi-word names with spaces
        need to be put in single quotes. For instance, if you set a path for 'Gahboom Hill'
        as opposed to Gahboom. If your name is a single word, you can leave it out of the
        quotes.

    d1,d2,d3,...,dn - D stands for direction, though, one is not limited to simply n,nw,w,sw,
        s,se,e,ne,u, and d. Anything that you might need to do in a specific path can be
        entered in followed by a comma with the next direction until you hit the last one.
        So, if you need to get a stick from a log and then walk east?
        set path SomePlace ...,get stick log,e,...
        The ... stands for the rest of the directions you might have in the path, a full
        path would look something like this:

     set path 'Some Random Place' e,se,3e,n,nw,4n,get stick log,e,ne,put stick hole,n

     Once you enter that in, you will have stored a new place under 'Some Random Place'
     which you can now access with the walk and reverse aliases.

]],
["reverse"] = [[
    Speedwalk Script
    Reverse Alias

    Syntax: reverse ('name name'|name)

    name - There's only one argument for the walk alias, but, multi-word names with spaces
        need to be put in single quotes. For instance, if you set a path for 'Gahboom Hill'
        as opposed to Gahboom. If your name is a single word, you can leave it out of the
        quotes.

    This works just like the walk alias, except in reverse. If you give it a path name, it
    will take the path it finds, but walk it backwards. This is very useful if you need to
    walk from point A to point B and back to point A without much detour.
]],
["show paths"] = [[
    Speedwalk Script
    Show Paths Alias

    Syntax: show paths

    This will display a list of all speedwalk paths currently set, in no particular order.
    Each path will be shown with its name followed by the 'path' stored under that name.
]]
}

local pathlist = pathlist or {}
local reversedir = {
        n = "s",        ne = "sw",      e = "w",        se = "nw",
        s = "n",        sw = "ne",      w = "e",        nw = "se",
        u = "d",        d = "u",        out = "in",     ["in"] = "out",
        north = "south",                northeast = "southwest",
        east = "west",                  southeast = "northwest",
        south = "north",                southwest = "northeast",
        west = "east",                  northwest = "southeast",
        up = "down",                    down = "up"     }

local function walk_timer(walklist)
    send(table.remove(walklist, 1))
    if #walklist==0 then dslpnp.timers.remove("Speedwalk Delay Timer") end
end

function dslpnp.speedwalk.walk(path_name, backward, delay)
    if dslpnp.speedwalk.Active then
        pathname = string.gsub(path_name,"^'(.*)'%","%1")
        backward = backward and "backward" or "forward"
        delay = delay or 0
        local walklist = string.split(dslpnp.data.speedwalk[path_name][backward],",")
        if delay > 0 then
            dslpnp.timers.register(delay, function() walk_timer(walklist) end, "Speedwalk Delay Timer", true)
            walk_timer(walklist)
        else
            sendAll(unpack(walklist))
        end
    end
end

function dslpnp.speedwalk.goTo(path, delay)
    if dslpnp.speedwalk.Active then
        delay = delay or 0
        local walklist = (path and string.split(path,",")) or speedWalkDir or {}
        if delay > 0 then
            dslpnp.timers.register(delay, function() walk_timer(walklist) end, "Speedwalk Delay Timer", true)
            walk_timer(walklist)
        else
            sendAll(unpack(walklist))
        end
    end
end

local function splitdirs(dirlist)
    local tmp
    local dirs = {}
    while(dirlist ~= "") do
        tmp = string.sub(dirlist,1,2)
        if not reversedir[tmp] then
            tmp = string.sub(dirlist,1,1)
            dirlist = string.sub(dirlist,2,#dirlist)
        else
            dirlist = string.sub(dirlist,3,#dirlist)
        end
        table.insert(dirs,tmp)
    end
    return dirs
end

function dslpnp.speedwalk.set_walk(path_name, path_string)
    if dslpnp.speedwalk.Active then
        if path_string and path_string ~= "" then
            local tmp_tbl = string.split(path_string,",")
            local path_tbl, reverse_tbl = {}, {}
            local count, dir = 1, 1, ""
            for k,v in ipairs(tmp_tbl) do
                v = string.trim(v)
                if string.find(v," ") or not (string.find(v,"%d") or reversedir[v]) then
                    table.insert(path_tbl,v)
                else
                    for v2 in string.gmatch(v,"%d*%a+") do
                        count = string.match(v2,"%d+") or 1
                        dir = string.gsub(v2,"%d","")
                        if not reversedir[dir] then
                            -- make a function to call here
                            dir = splitdirs(dir)
                            for a = 1, count do
                                table.insert(path_tbl,dir[1])
                            end
                            for a = 2,#dir do
                                table.insert(path_tbl,dir[a])
                            end
                        else
                            for a = 1, count do
                                table.insert(path_tbl,dir)
                            end
                        end
                    end
                end
            end

            local k, index = #path_tbl, 1

            while path_tbl[k] do
                if string.starts(path_tbl[k],"unlock") then
                    reverse_tbl[index] = reverse_tbl[index-1]
                    reverse_tbl[index-1] = reverse_tbl[index-2]
                    reverse_tbl[index-2] = path_tbl[k]
                elseif reversedir[path_tbl[k]] then
                    reverse_tbl[index] = path_tbl[k]
                else
                    reverse_tbl[index] = reverse_tbl[index-1]
                    reverse_tbl[index-1] = path_tbl[k]
                end
                index = index + 1
                k = k - 1
            end
            for k,v in ipairs(reverse_tbl) do
                reverse_tbl[k] = reversedir[v] or string.gsub(v,"(%a+ )(.+)", function(w1,w2) if reversedir[w2] then return w1 .. reversedir[w2] end return w1 .. w2 end)
            end
            dslpnp.data.speedwalk[path_name] = {forward = table.concat(path_tbl,","), backward = table.concat(reverse_tbl,",")}
            print("Path " .. path_name .. " set.")
        else
            dslpnp.data.speedwalk[path_name] = nil
            print("Path " .. path_name .. " cleared.")
        end
        raiseEvent("saveData","speedwalk")
    end
end

function dslpnp.speedwalk.show_paths()
    print("List of speedwalk paths:")
    for k,v in pairs(dslpnp.data.speedwalk) do
        print("   " .. k .. " : " .. v.forward)
    end
end

local function config()
    if not dslpnp.aliases.exists("Set Path Alias") then
        dslpnp.aliases.register("Set Path Alias", [[^set path ([\w']+|'[\w\s']+') (.+)]],[[dslpnp.speedwalk.set_walk(matches[2],matches[3])]],true)
    end
    if not dslpnp.aliases.exists("Walk Alias") then
        dslpnp.aliases.register("Walk Alias", [[^walk ([\w']+|'[\w\s']+')]],[[dslpnp.speedwalk.walk(matches[2],false,.2)]],true)
    end
    if not dslpnp.aliases.exists("Reverse Alias") then
        dslpnp.aliases.register("Reverse Alias", [[^reverse ([\w']+|'[\w\s']+')]],[[dslpnp.speedwalk.walk(matches[2],true,.2)]],true)
    end
    if not dslpnp.aliases.exists("Show Speedwalk Paths Alias") then
        dslpnp.aliases.register("Show Speedwalk Paths Alias", [[^show paths$]],[[dslpnp.speedwalk.show_paths()]],true)
    end
    if not dslpnp.aliases.exists("GoTo Alias") then
        dslpnp.aliases.register("GoMap Alias", [[^gomap(?: (.+))?]],[[dslpnp.speedwalk.goTo(matches[2])]],true)
    end
    -- Turn script on
    raiseEvent("onToggle","speedwalk","on")
end

local function toggle(setVal)
    -- Call toggle function to set on or off status for script
    dslpnp.speedwalk.Active = dslpnp.toggle("speedwalk",dslpnp.speedwalk.Active, setVal)
    if dslpnp.speedwalk.Active then
        if dslpnp.aliases.exists("Set Path Alias") then dslpnp.aliases.enable("Set Path Alias") end
        if dslpnp.aliases.exists("Walk Alias") then dslpnp.aliases.enable("Walk Alias") end
        if dslpnp.aliases.exists("Reverse Alias") then dslpnp.aliases.enable("Reverse Alias") end
        if dslpnp.aliases.exists("Show Speedwalk Paths Alias") then dslpnp.aliases.enable("Show Speedwalk Paths Alias") end
        if dslpnp.aliases.exists("GoTo Alias") then dslpnp.aliases.enable("Reverse Alias") end
    else
        if dslpnp.aliases.exists("Set Path Alias") then dslpnp.aliases.disable("Set Path Alias") end
        if dslpnp.aliases.exists("Walk Alias") then dslpnp.aliases.disable("Walk Alias") end
        if dslpnp.aliases.exists("Reverse Alias") then dslpnp.aliases.disable("Reverse Alias") end
        if dslpnp.aliases.exists("Show Speedwalk Paths Alias") then dslpnp.aliases.disable("Show Speedwalk Paths Alias") end
        if dslpnp.aliases.exists("GoMap Alias") then dslpnp.aliases.disable("Reverse Alias") end
    end
end

function dslpnp.speedwalk.eventHandler(event, ...)
    if event == "onToggle" and arg[1] == "speedwalk" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "speedwalk" then
        config()
    end
end

registerAnonymousEventHandler("onToggle", "dslpnp.speedwalk.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.speedwalk.eventHandler")
