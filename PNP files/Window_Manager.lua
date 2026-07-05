-- Window Manager Script --
--  Zachary Hiland
--  10/22/2016
--  v2.00c
--
--  Functions Details
--
--      windowManager.create(name, type, x, y, width, height, origin, [font_size]) or windowManager.add(info_table)
--      creates a window and adds it to the windowManager
--
--      info_table must have a valid entry for each argument, by the same name, as in the normal function call
--      name - name of already created window (label, miniConsole, gauge, mapper, menu, or autowrap)
--          Note: for a mapper window, use any name you like, so long as it isn't the name of some other object
--      type - identify the type of window, must be label, miniConsole, gauge, mapper, or menu
--      x - distance horizontally from the origin corner
--      y - distance vertically from the origin corner
--      width - width of window
--      height - height of window
--      origin - corner to act as origin for this window, must be topleft, topright, bottomleft, or bottomright
--      font_size - only used for autowrap windows, will be automatically set as the font size for the created window
--
--      note: all measurements should be numbers, or strings with values measured in percent or pixels (or unlabeled)
--          if a measurement contains both percent and pixel values (or multiple values of the same type), they should be separated
--          by a "+" symbol. Example: "25% + 50px + 16"
--      important: no negative numbers
--
--      windowManager.add(name, type, x, y, width, height, origin, font_size) or windowManager.create(info_table)
--      adds an already created window to the windowManager, uses the exact same arguments as those in the "create" function
--
--      windowManager.remove(name)
--      removes a window from the windowManager
--
--      windowManager.move(name, x, y)
--      moves a window with the windowManager
--
--      windowManager.resize(name, width, height)
--      resizes a window with the windowManager
--
--      windowManager.relocate(name, origin)
--      changes the corner acting as the origin for a window in the windowManager
--
--      windowManager.show(name)
--      shows a window that is managed by windowManager (you can also use showWindow or showGauge functions)
--          Note: this is only really important for a mapper window
--
--      windowManager.hide(name)
--      hides a window that is managed by windowManager (you can also use hideWindow or hideGauge functions)
--          Note: this is only really important for a mapper window
--
--      windowManager.getValue(name, value)
--      returns the calculated size or position values, or the origin, for a window in the windowManager
--
--      windowManager.math(value1, value2, operation)
--      allows addition and subtraction of measurements with each other,
--      and multiplication and division of a measurement by a normal number
--
--      windowManager.simplify(measurement)
--      returns a simplified version of a measurement (all percent and pixel values are combined together)
--
--      windowManager.refresh(name)
--      sets the size and location of a window in the windowManager using previously set values
--      note: generally this function does not need to be called
--
--      windowManager.refreshAll()
--      note: this function is called automatically when a sysWindowResizeEvent event occurs,
--          and generally does not need to be called manually
--
--      windowManager.createBuffer(name)
--      creates a buffer to be used with an autowrap window, only needed if miniconsole added manually to windowManager
--
--      windowManager.append(name)
--      appends text to an autowrap window, works just like appendBuffer()
--
--      windowManager.echo(name, text)
--      echoes text to an autowrap window. cecho, decho, and hecho are also available.
--
--      windowManager.clear(name)
--      clears an autowrap window.
--
--      windowManager.setFontSize(name, font_size)
--      sets the font size for an autowrap window.

windowManager = windowManager or {}
windowManager.list = windowManager.list or {}

local function calcScaledNum(scale,num)
    scale_table = string.split(scale," %+ ")
    if #scale_table > 2 then
        scale = windowManager.simplify(scale)
        scale_table = string.split(scale," %+ ")
    end
    scale = 0
    if #scale_table == 2 then
        scale = string.cut(scale_table[1],#scale_table[1] - 1) * num / 100
        scale = scale + string.gsub(scale_table[2],"px","")
    elseif string.find(scale_table[1],"%%") then
        scale = string.cut(scale_table[1],#scale_table[1] - 1) * num / 100
    else
        scale = string.gsub(scale_table[1],"px","")
    end
    scale = math.floor(scale + 0.5)
    return scale
end

local function rewrap_window(name)
    local info = windowManager.list[name]
    local buffer = name .. "_windowManager_buffer"
    local wrap = math.floor(windowManager.getValue(name,"width") / calcFontSize(info.font))
    local line, moved
    setWindowWrap(name,wrap)
    clearWindow(name)
    line = 0
    moved = moveCursor(buffer,1,line)
    while moved do
        selectCurrentLine(buffer)
        copy(buffer)
        line = line + 1
        moved = moveCursor(buffer,1,line)
        appendBuffer(name)
    end
end

function windowManager.simplify(measure)
    measure = string.gsub(measure,"%s*-%s*([%d%%]+)"," + -%1")
    measure = string.gsub(measure,"%-%-","")
    measure = string.gsub(measure,"%+%s*%+","+")
    measure = string.gsub(measure,"^%s*%+","")
    local measure_table = string.split(measure,"+")
    local percent, pixel = 0,0
    for k,v in ipairs(measure_table) do
        v = string.trim(v)
        if string.find(v,"%%") then
            v = string.gsub(v,"%%","")
            if not tonumber(v) then display(measure) end
            percent = percent + v
        elseif v ~= "" then
            v = string.gsub(v,"px","")
            if not tonumber(v) then display(measure) end
            pixel = pixel + v
        end
    end
    percent = math.floor(1000 * percent + .5) / 1000
    pixel = math.floor(1000 * pixel + .5) / 1000
    if percent == 0 then
        measure = pixel .. "px"
    elseif pixel == 0 then
        measure = percent .. "%"
    else
        measure = percent .. "% + " .. pixel .. "px"
    end
    return measure
end

function windowManager.math(measure,num,op)
    if not table.contains({"multiply","divide", "add", "subtract"},op) then
        error("windowManager.math: bad argument #3 \"operation\", must be add, subtract, multiply or divide",2)
    end
    if op == "divide" or op == "multiply" then
        if string.find(num,"%%") then
            num = string.gsub(num,"%%","") / 100
        end
        if not tonumber(num) then
            error("windowManager.math: bad argument #2 \"num\", must be a number",2)
        end
        num = tonumber(num)
        measure = string.gsub(measure,"%s*-%s*([%d%%]+)"," + -%1")
        measure = string.gsub(measure,"%+%s*%+","+")
        measure = string.gsub(measure,"^%s*%+","")
        local measure_table = string.split(measure,"+")
        if op == "divide" then num = 1 / num end
        for k,v in ipairs(measure_table) do
            v = string.trim(v)
            v = (string.gsub(v,"([%d%.]+).*","%1") * num) .. string.gsub(v,".*[%d%.]+(.*)","%1")
            measure_table[k] = v
        end
        measure = table.concat(measure_table," + ")
    else
        if op == "subtract" then
            num = windowManager.math(num,"-1","multiply")
        end
        measure = measure .. " + " .. num
        measure = string.gsub(measure,"([^%s%+%-]+)%s*-%s*([%d%.%-]+)","%1 + -%2")
    end
    return windowManager.simplify(measure)
end

function windowManager.create(name, window_type, ...)
    local tbl = {}
    local is_table = false
    if type(name) == "table" then
        table.update(tble,name)
        name = tbl.name
        window_type = tbl.type
        is_table = true
    end
    if type(window_type) ~= "string" then
        error("windowManager.create: bad argument #2 \"type\", must be string.",2)
    end
    window_type = string.lower(window_type)
    if not table.contains({"label","miniconsole","gauge","mapper","menu","autowrap"},window_type) then
        error("windowManager.create: invalid type",2)
    end
    if window_type == "label" then
        createLabel(name, 0,0,0,0,1)
    elseif window_type == "miniconsole" then
        createMiniConsole(name,0,0,0,0)
    elseif window_type == "gauge" then
        createGauge(name,0,0,0,0)
    elseif window_type == "menu" then
        createMenu(name,0,0,0,0)
    elseif window_type == "autowrap" then
        createMiniConsole(name,0,0,0,0)
        createBuffer(name .. "_windowManager_buffer")
        setWindowWrap(name .. "_windowManager_buffer",1000)
    end
    if is_table then
        return windowManager.add(tbl)
    else
        return windowManager.add(name, window_type, ...)
    end
end

function windowManager.makeBuffer(name)
    createBuffer(name .. "_windowManager_buffer")
    setWindowWrap(name .. "_windowManager_buffer",1000)
end

function windowManager.add(name, window_type, x, y, w, h, origin, font)
    local tbl = {}
    if type(name) == "table" then
        tbl = table.update(tbl,name)
        name = tbl.name
        x = tbl.x
        y = tbl.y
        w = tbl.width
        h = tbl.height
        origin = tbl.origin
        window_type = tbl.type
        font = tbl.font_size
        tbl = {}
    end
    font = font or 10
    if not name then
        error("windowManager.add: bad argument #1 \"name\".",2)
    end
    windowManager.list[name] = nil
    if type(window_type) ~= "string" then
        error("windowManager.add: bad argument #2 \"type\", must be string.",2)
    end
    window_type = string.lower(window_type)
    if not table.contains({"label","miniconsole","gauge","mapper","menu","autowrap"},window_type) then
        error("windowManager.add: invalid type",2)
    end
    if not (x and y and w and h) then
        error("windowManager.add: must have x, y, width, and height.",2)
    end
    origin = origin or "topleft"
    origin = string.lower(origin)
    if not table.contains({"topleft","topright","bottomleft","bottomright"},origin) then
        error("windowManager.add: bad argument #7 \"origin\".",2)
    end
    x = windowManager.simplify(x)
    y = windowManager.simplify(y)
    w = windowManager.simplify(w)
    h = windowManager.simplify(h)
    tbl = {
        type = window_type,
        x = x, y = y, h = h, w = w,
        origin = origin}
    if window_type == "autowrap" then
        tbl.font = font
        setMiniConsoleFontSize(name, font)
    end
    windowManager.list[name] = tbl
    windowManager.refresh(name)
end

function windowManager.remove(name)
    windowManager.list[name] = nil
end

function windowManager.refresh(name, main_w, main_h)
    local info = windowManager.list[name]
    if not info then error("windowManager.refresh: no such window.",2) end
    local x,y,w,h,origin,win_type = info.x, info.y, info.w, info.h, info.origin, info.type
    if not (main_w and main_h) then
        main_w, main_h = getMainWindowSize()
    end
    w = calcScaledNum(w,main_w)
    x = calcScaledNum(x,main_w)
    h = calcScaledNum(h,main_h)
    y = calcScaledNum(y,main_h)
    if string.find(origin,"right") then
        x = main_w - x - w
    end
    if string.find(origin,"bottom") then
        y = main_h - y - h
    end
    if win_type == "gauge" then
        moveGauge(name,x,y)
        resizeGauge(name,w,h)
    elseif win_type == "mapper" then
        if not info.hide then
            createMapper(x,y,w,h)
        end
    elseif win_type == "menu" then
        moveMenu(name,x,y)
        resizeMenu(name,w,h)
    else
        moveWindow(name,x,y)
        resizeWindow(name,w,h)
        if win_type == "autowrap" then
            rewrap_window(name)
        end
    end
end

function windowManager.resize(name, w, h)
    local info = windowManager.list[name]
    if not info then error("windowManager.resize: no such window.",2) end
    if not (w and h) then error("windowManager.resize: must have both width and height.",2) end
    w = windowManager.simplify(w)
    h = windowManager.simplify(h)
    windowManager.list[name].w = w
    windowManager.list[name].h = h
    windowManager.refresh(name)
end

function windowManager.move(name, x, y)
    local info = windowManager.list[name]
    if not info then error("windowManager.move: no such window.",2) end
    if not (x and y) then error("windowManager.move: must have both x and y.",2) end
    x = windowManager.simplify(x)
    y = windowManager.simplify(y)
    windowManager.list[name].x = x
    windowManager.list[name].y = y
    windowManager.refresh(name)
end

function windowManager.relocate(name, origin)
    local info = windowManager.list[name]
    if not info then error("windowManager.relocate: no such window.",2) end
    origin = origin or "topleft"
    origin = string.lower(origin)
    if not table.contains({"topleft","topright","bottomleft","bottomright"},origin) then
        error("windowManager.relocate: bad argument #2 \"origin\".",2)
    end
    windowManager.list[name].origin = origin
    windowManager.refresh(name)
end

function windowManager.hide(name)
    local info = windowManager.list[name]
    if not info then error("windowManager.hide: no such window.",2) end
    local info = windowManager.list[name]
    if info.type == "gauge" then
        hideGauge(name)
    elseif info.type == "mapper" then
        windowManager.list[name].hide = true
        createMapper(0,0,0,0)
    elseif info.type == "menu" then
        hideMenu(name)
    else
        hideWindow(name)
    end
end

function windowManager.show(name)
    local info = windowManager.list[name]
    if not info then error("windowManager.show: no such window.",2) end
    local info = windowManager.list[name]
    if info.type == "gauge" then
        showGauge(name)
    elseif info.type == "mapper" then
        windowManager.list[name].hide = false
        windowManager.refresh(name)
    elseif info.type == "menu" then
        showMenu(name)
    else
        showWindow(name)
    end
end

function windowManager.setFontSize(name, font_size)
    local info = windowManager.list[name]
    if not info then error("windowManager.setFontSize: no such window.",2) end
    windowManager.list[name].font = font_size
    setMiniConsoleFontSize(name, font_size)
    windowManager.refresh(name)
end

function windowManager.clear(name)
    local info = windowManager.list[name]
    if not info then error("windowManager.clear: no such window.",2) end
    clearWindow(name)
    clearWindow(name .. "_windowManager_buffer")
end

function windowManager.append(name)
    local info = windowManager.list[name]
    if not info then error("windowManager.append: no such window.",2) end
    appendBuffer(name)
    appendBuffer(name .. "_windowManager_buffer")
end

function windowManager.echo(name, text)
    local info = windowManager.list[name]
    if not info then error("windowManager.echo: no such window.",2) end
    echo(name, text)
    echo(name .. "_windowManager_buffer", text)
end

function windowManager.cecho(name, text)
    local info = windowManager.list[name]
    if not info then error("windowManager.cecho: no such window.",2) end
    cecho(name, text)
    cecho(name .. "_windowManager_buffer", text)
end

function windowManager.hecho(name, text)
    local info = windowManager.list[name]
    if not info then error("windowManager.hecho: no such window.",2) end
    hecho(name, text)
    hecho(name .. "_windowManager_buffer", text)
end

function windowManager.decho(name, text)
    local info = windowManager.list[name]
    if not info then error("windowManager.decho: no such window.",2) end
    decho(name, text)
    decho(name .. "_windowManager_buffer", text)
end

function windowManager.getValue(name, value)
    local info = windowManager.list[name]
    if not info then error("windowManager.getValue: no such window.",2) end
    if not table.contains({"x","y","width","height","w","h","origin"},value) then
        error("windowManager.getValue: no such value.",2)
    end
    local sys_w, sys_h = getMainWindowSize()
    if value == "width" then value = "w" end
    if value == "height" then value = "h" end
    local tmp = windowManager.list[name][value]
    if value == "w" or value == "x" then
        tmp = calcScaledNum(tmp,sys_w)
    elseif value == "h" or value == "y" then
        tmp = calcScaledNum(tmp,sys_h)
    end
    return tmp
end

function windowManager.refreshAll()
    local main_w, main_h = getMainWindowSize()
    for k,v in pairs(windowManager.list) do
        windowManager.refresh(k, main_w, main_h)
    end
end

registerAnonymousEventHandler("sysWindowResizeEvent", "windowManager.refreshAll")
