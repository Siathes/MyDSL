-- New Gauge Script
-- 6/11/2015
-- 4.00b

function createGauge(gaugeName, width, height, x, y, gaugeText, r, g, b, orientation)
    gaugeText = gaugeText or ""
    if type(r) == "string" then
        orientation = g
        r,g,b = getRGB(r)
    elseif r == nil then
        orientation = g
        -- default colors
        r,g,b = 128,128,128
    end
    orientation = orientation or "horizontal"
    if not table.contains({"horizontal","vertical","goofy","batty"},orientation) then
        error("createGauge: orientation must be horizontal, vertical, goofy, or batty",2)
    end
    local tbl = {width = width, height = height, x = x, y = y, text = gaugeText, r = r, g = g, b = b, orientation = orientation, value = 1}
    createLabel(gaugeName .. "_back", 0,0,0,0,1)
    setBackgroundColor(gaugeName .. "_back", r, g, b, 100)

    createLabel(gaugeName .. "_front", 0,0,0,0,1)
    setBackgroundColor(gaugeName .. "_front", r, g, b, 255)

    createLabel(gaugeName, 0,0,0,0,1)
    setBackgroundColor(gaugeName, 0, 0, 0, 0)

    -- save new values in table
    gaugesTable[gaugeName] = tbl
    resizeGauge(gaugeName, tbl.width, tbl.height)
    moveGauge(gaugeName, tbl.x, tbl.y)
    setGaugeText(gaugeName, gaugeText, "black")
    showGauge(gaugeName)
end

function hideGauge(gaugeName)
    if not gaugesTable[gaugeName] then
        error("hideGauge: no such gauge exists.",2)
    end
    hideWindow(gaugeName .. "_back")
    hideWindow(gaugeName .. "_front")
    hideWindow(gaugeName)
end

function showGauge(gaugeName)
    if not gaugesTable[gaugeName] then
        error("showGauge: no such gauge exists.",2)
    end
    showWindow(gaugeName .. "_back")
    showWindow(gaugeName .. "_front")
    showWindow(gaugeName)
end

function resizeGauge(gaugeName, width, height)
    if not gaugesTable[gaugeName] then
        error("resizeGauge: no such gauge exists.",2)
    end
    if not (width and height) then
        error("resizeGauge: need to have both width and height.",2)
    end
    resizeWindow(gaugeName .. "_back", width, height)
    resizeWindow(gaugeName, width, height)
    -- save new values in table
    gaugesTable[gaugeName].width, gaugesTable[gaugeName].height = width, height
    setGauge(gaugeName, gaugesTable[gaugeName].value, 1)
end

function moveGauge(gaugeName, x, y)
    if not gaugesTable[gaugeName] then
        error("moveGauge: no such gauge exists.",2)
    end
    if not (x and y) then
        error("moveGauge: need to have both X and Y dimensions.",2)
    end
    moveWindow(gaugeName .. "_back", x, y)
    moveWindow(gaugeName, x, y)
    -- save new values in table
    gaugesTable[gaugeName].x, gaugesTable[gaugeName].y = x, y
    setGauge(gaugeName, gaugesTable[gaugeName].value, 1)
end

function setGaugeStyleSheet(gaugeName, css, cssback, csstext)
    if not setLabelStyleSheet then return end -- mudlet 1.0.5 and lower compatibility
    if not gaugesTable[gaugeName] then
        error("setGaugeStyleSheet: no such gauge exists.",2)
    end
    setLabelStyleSheet(gaugeName .. "_back", cssback or css)
    setLabelStyleSheet(gaugeName .. "_front", css)
    setLabelStyleSheet(gaugeName, csstext or "")
end

function setGaugeText(gaugeName, gaugeText, r, g, b)
    if not gaugesTable[gaugeName] then
        error("setGaugeText: no such gauge exists.",2)
    end
    if r ~= nil then
        if g == nil then
            r,g,b = getRGB(r)
        end
    else
        r,g,b = 0,0,0
    end
    gaugeText = gaugeText or ""
    local echoString = [[<font color="#]] .. RGB2Hex(r,g,b) .. [[">]] .. gaugeText .. [[</font>]]
    echo(gaugeName, echoString)
    -- save new values in table
    gaugesTable[gaugeName].text = echoString
end

function setGauge(gaugeName, currentValue, maxValue, gaugeText)
    if not gaugesTable[gaugeName] then
        error("setGauge: no such gauge exists.",2)
    end
    if not (currentValue and maxValue) then
        error("setGauge: need to have both current and max values.",2)
    end
    local value = currentValue / maxValue
    -- save new values in table
    gaugesTable[gaugeName].value = value
    local info = gaugesTable[gaugeName]
    local x,y,w,h = info.x, info.y, info.width, info.height

    if info.orientation == "horizontal" then
    resizeWindow(gaugeName .. "_front", w * value, h)
    moveWindow(gaugeName .. "_front", x, y)
    elseif info.orientation == "vertical" then
    resizeWindow(gaugeName .. "_front", w, h * value)
    moveWindow(gaugeName .. "_front", x, y + h * (1 - value))
    elseif info.orientation == "goofy" then
    resizeWindow(gaugeName .. "_front", w * value, h)
    moveWindow(gaugeName .. "_front", x + w * (1 - value), y)
    elseif info.orientation == "batty" then
    resizeWindow(gaugeName .. "_front", w, h * value)
    moveWindow(gaugeName .. "_front", x, y)
    end
    if gaugeText then
        setGaugeText(gaugeName, gaugeText)
    end
end
