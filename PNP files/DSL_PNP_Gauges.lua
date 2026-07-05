-- Gauges Script
-- 7/23/2016
-- v4.01d
--
-- Type "toggle gauges" to disable or enable this script.
--
-- Use the following code to set the hp, mana, and moves gauges:
-- raiseEvent("onPrompt", time, curhp, maxhp, curm, maxm, curmv, maxmv, exits)
--

dslpnp.gauges = dslpnp.gauges or {}
dslpnp.gauges.configs = dslpnp.gauges.configs or {}

local defaults = {
    height = "2%",
    width = "10%",
    display = "number",
    order = {"health", "mana", "moves"},
    colors = {health = "red", mana = "blue", moves = "green"},
    font_size = 12,
    font_colors = {health = "white", mana = "white", moves = "white"},
    x = 0, y = 40, origin = "bottomleft",
    orientation = "horizontal",
    layout = "horizontal",
    color_codes = {
        red = {"#FF0000","#BF0000","#BF0000","#7F0000"},
        vermilion = {"#FF3F00","#BF2F00","#BF2F00","#7F1F00"},
        orange = {"#FF7F00","#BF5F00","#BF5F00","#7F3F00"},
        amber = {"#FFBF00","#BF8F00","#BF8F00","#7F5F00"},
        yellow = {"#FFFF00","#BFBF00","#BFBF00","#7F7F00"},
        chartreuse = {"#BFFF00","#8FBF00","#8FBF00","#5F7F00"},
        lime = {"#7FFF00","#5FBF00","#5FBF00","#3F7F00"},
        emerald = {"#3FFF00","#2FBF00","#2FBF00","#1F7F00"},
        green = {"#00FF00","#00BF00","#00BF00","#007F00"},
        aquamarine = {"#00FF3F","#00BF2F","#00BF2F","#007F1F"},
        turquoise = {"#00FF7F","#00BF5F","#00BF5F","#007F3F"},
        viridian = {"#00FFBF","#00BF8F","#00BF8F","#007F5F"},
        cyan = {"#00FFFF","#00BFBF","#00BFBF","#007F7F"},
        sky = {"#00BFFF","#008FBF","#008FBF","#005F7F"},
        cobalt = {"#007FFF","#005FBF","#005FBF","#003F7F"},
        ultramarine = {"#003FFF","#002FBF","#002FBF","#001F7F"},
        blue = {"#0000FF","#0000BF","#0000BF","#00007F"},
        indigo = {"#3F00FF","#2F00BF","#2F00BF","#1F007F"},
        violet = {"#7F00FF","#5F00BF","#5F00BF","#3F007F"},
        purple = {"#BF00FF","#8F00BF","#8F00BF","#5F007F"},
        magenta = {"#FF00FF","#BF00BF","#BF00BF","#7F007F"},
        lavender = {"#FF00BF","#BF008F","#BF008F","#7F005F"},
        crimson = {"#FF007F","#BF005F","#BF005F","#7F003F"},
        lake = {"#FF003F","#BF002F","#BF002F","#7F001F"},
        white = {"#FFFFFF","#BFBFBF","#BFBFBF","#7F7F7F"},
        silver = {"#BFBFBF","#8F8F8F","#8F8F8F","#5F5F5F"},
        gray = {"#7F7F7F","#5F5F5F","#5F5F5F","#3F3F3F"},
        black = {"#3F3F3F","#2F2F2F","#2F2F2F","#1F1F1F"}
    }
}

local function config()
    local configs = dslpnp.config.gauges or {}
    configs = table.update(defaults,configs)
    dslpnp.gauges.configs = configs
    local style, gradstr
    local width, height = configs.width, configs.height
    local x,y = configs.x, configs.y
    local origin = configs.origin
    local orientation = configs.orientation
    local layout = configs.layout
    local color_codes = configs.color_codes

    if string.find(origin,"right") then
        x = x .. " + 16"
    end
    if orientation == "horizontal" then
        gradstr = "x1: 0, y1: 0, x2: 0, y2: 1,"
    elseif orientation == "vertical" then
        gradstr = "x1: 0, y1: 0, x2: 1, y2: 0,"
    end

    for k,v in ipairs(configs.order) do
        if k > 1 then
            if layout == "horizontal" then
                x = x .. " + " .. width
            elseif layout == "vertical" then
                y = y .. " + " .. height
            end
        end
        createGauge(v .. "_bar", 0, 0, 0, 0, nil, nil, orientation)
        windowManager.remove(v .. "_bar")
        windowManager.add(v .. "_bar", "gauge", x, y, width, height, origin)
        local gauge_colors = color_codes[configs.colors[v]]
        if #gauge_colors == 3 then
            table.insert(gauge_colors,2,gauge_colors[2])
        end
        local align_str, padding_str = "", ""
        if orientation == "vertical" then
            align_str = [[ qproperty-alignment: 'AlignHCenter | AlignTop';]]
            padding_str = [[ padding-bottom: 5px;]]
        else
            align_str = [[ qproperty-alignment: 'AlignLeft | AlignVCenter';]]
            padding_str = [[ padding-left: 5px;]]
        end
        setGaugeStyleSheet(v .. "_bar",[[background-color: QLinearGradient( ]] .. gradstr ..
            [[stop: 0]] .. gauge_colors[1] .. [[, stop: 0.2 ]] .. gauge_colors[1] .. [[, stop: 0.8 ]] .. gauge_colors[2] .. [[, stop: 1 ]] .. gauge_colors[2] .. [[);
            border-radius: 3;]],
            [[background-color: QLinearGradient( ]] .. gradstr ..
            [[stop: 0]] .. gauge_colors[3] .. [[, stop: 0.2 ]] .. gauge_colors[3] .. [[, stop: 0.8 ]] .. gauge_colors[4] .. [[, stop: 1 ]] .. gauge_colors[4] .. [[);
            border-radius: 3;]],
            padding_str .. [[ font-size: ]] .. configs.font_size .. [[; ]] .. align_str)
    end
    raiseEvent("onToggle","gauges","on")
    local total_w, total_h = windowManager.getValue("health_bar","width"), windowManager.getValue("health_bar","height")
    if layout == "horizontal" then
        total_w = total_w * 3
    elseif layout == "vertical" then
        total_h = total_h * 3
    end
    return total_w, total_h, origin
end

function dslpnp.gauges.setGauge(gauge, curVal, maxVal, text)
    if dslpnp.gauges.Active then
        maxVal = maxVal or curVal
        local configs = dslpnp.gauges.configs
        assert(gauge == "health" or gauge == "mana" or gauge == "moves", "Invalid gauge!")
        local display_type = configs.display
        local orientation = configs.orientation
        local color = configs.font_colors[gauge]
        local message = ""

        if display_type == "number" then
            message = string.title(gauge) .. ": " .. curVal .. "/" .. maxVal
        elseif display_type == "percent" then
            message = string.title(gauge) .. ": " .. math.round(100 * curVal / maxVal) .. "%"
        end
        message = text or message
        if orientation == "vertical" then
            message = string.gsub(message, ".", "%1<br>")
        end
        setGauge(gauge .. "_bar", curVal, maxVal)
        setGaugeText(gauge .. "_bar", message, color)
    end
end

--local function display_rage(damage, vamp)
--  dslpnp.battle.rage_info.damage,dslpnp.battle.rage_info.vamp
--  dslpnp.gauges.setGauge("health", 1, 1, "Dam: " .. damage .. " V: " .. vamp)
--end

local function toggle(setVal)
    dslpnp.gauges.Active = dslpnp.toggle("gauges",dslpnp.gauges.Active, setVal)
    if dslpnp.gauges.Active then
        showGauge("health_bar")
        showGauge("mana_bar")
        showGauge("moves_bar")
    else
        hideGauge("health_bar")
        hideGauge("mana_bar")
        hideGauge("moves_bar")
    end
end

function dslpnp.gauges.eventHandler(event, ...)
    if event == "onPrompt" and dslpnp.gauges.Active then
        if not string.find(dslpnp.prompt.curhp,"?") then
            dslpnp.gauges.setGauge("health", dslpnp.prompt.curhp_number, dslpnp.prompt.maxhp)
        else
            dslpnp.gauges.setGauge("health", 1, 1, "Dam: " .. dslpnp.battle.rage_info.damage .. " V: " .. dslpnp.battle.rage_info.vamp)
        end
        dslpnp.gauges.setGauge("mana", dslpnp.prompt.curm_number, dslpnp.prompt.maxm)
        dslpnp.gauges.setGauge("moves", dslpnp.prompt.curmv_number, dslpnp.prompt.maxmv)
    elseif event == "onToggle" and arg[1] == "gauges" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "gauges" then
        config()
    end
end

registerAnonymousEventHandler("onPrompt", "dslpnp.gauges.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.gauges.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.gauges.eventHandler")
