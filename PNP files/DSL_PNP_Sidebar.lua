-- Sidebar Script
-- 10/22/2016
-- v4.00e
--

dslpnp.sidebar = dslpnp.sidebar or {}
dslpnp.displayed = dslpnp.displayed or {}
dslpnp.sidebar.configs = dslpnp.sidebar.configs or {}

local displayed = {top = {},middle = {},bottom = {}}
local windows = {"top","middle","bottom"}

local defaults = {
    width = "20%",
    position = "right",
    top = {height = "20%"},
    middle = {height = "20%"},
    bottom = {height = "20%"}
}

function dslpnp.sidebar.maketab(section, name, text)
    table.insert(dslpnp.sidebar[section]["tabs"],name)
    local info = dslpnp.sidebar[section]
    windowManager.add(name,"label",info.x,info.y,info.width,"25px", info.origin)
    setLabelStyleSheet(name,[[
        border: 2px solid white;
        border-radius: 5px;
        qproperty-alignment: 'AlignHCenter | AlignVCenter';
        background-color: black;]])
    text = dslpnp.support.formatLabelText(text, dslpnp.sidebar.configs.tabFontSize,true,false,false,false,"white")
    echo(name, text)
    local width = windowManager.math(info.width,#dslpnp.sidebar[section]["tabs"],"divide")
    local x = windowManager.math(width,#dslpnp.sidebar[section]["tabs"] - 1,"multiply")
    x = windowManager.math(info.x, x, "add")
    for k,v in ipairs(dslpnp.sidebar[section]["tabs"]) do
        windowManager.resize(v,width,"25px")
        windowManager.move(v,x,info.y)
        x = windowManager.math(x,width,"subtract")
    end
end

function dslpnp.sidebar.display(name, windows, tab, extra)
    local section
    if table.contains(dslpnp.sidebar.top.tabs,tab) then
        section = "top"
    elseif table.contains(dslpnp.sidebar.middle.tabs,tab) then
        section = "middle"
    elseif table.contains(dslpnp.sidebar.bottom.tabs,tab) then
        section = "bottom"
    end
    if not section then return end
    local window_list = dslpnp.displayed[section] or {}
    local window_2 = window_list[2] or {}
    local info = dslpnp.sidebar[section] or {}
    if window_2.tab then
        setLabelStyleSheet(window_2.tab,[[
        border: 2px solid white;
        border-radius: 5px;
        qproperty-alignment: 'AlignHCenter | AlignVCenter';
        background-color: rgb(0,0,0)]])
    end
    if window_2.windows then
        for k,v in ipairs(window_2.windows) do
            windowManager.hide(v)
        end
    end
    window_2 = window_list[1] or {}
    if window_2.name and name ~= window_2.name then
        setLabelStyleSheet(window_2.tab,[[
            border: 2px solid white;
            border-radius: 5px;
            qproperty-alignment: 'AlignHCenter | AlignVCenter';
            background-color: rgb(50,50,50)]])

        raiseEvent("displayWindow", window_2.name, info.x, info.y .. " + 25px", info.half_width, info.height .. " - 25px", window_2.extra)
        raiseEvent("displayWindow", name, info.x .. " + " .. info.half_width, info.y .. " + 25px", info.half_width, info.height .. " - 25px", extra)
    else
        raiseEvent("displayWindow", name, info.x, info.y .. " + 25px", info.width, info.height .. " - 25px", extra)
    end
    setLabelStyleSheet(tab,[[
        border: 2px solid white;
        border-radius: 5px;
        qproperty-alignment: 'AlignHCenter | AlignVCenter';
        background-color: rgb(50,50,50)]])
    window_list[1] = {windows = windows, name = name, tab = tab, extra = extra}
    window_list[2] = window_2
    dslpnp.displayed[section] = window_list
end

local function config_display()
    local configs = table.update(displayed,dslpnp.sidebar.configs.display or {})
    for k,v in ipairs(windows) do
        if configs[v] and configs[v][2] then
            if type(configs[v][2]) == "table" then
                raiseEvent("onDisplay",configs[v][2][1],configs[v][2][2])
            else
                raiseEvent("onDisplay",configs[v][2])
            end
        end
        if configs[v] and configs[v][1] then
            if type(configs[v][1]) == "table" then
                raiseEvent("onDisplay",configs[v][1][1],configs[v][1][2])
            else
                raiseEvent("onDisplay",configs[v][1])
            end
        end
    end
end

local function fix_display()
    for k,v in ipairs(windows) do
        local window_list = table.update({{window = nil},{window = nil}},(dslpnp.displayed and dslpnp.displayed[v]) or {})
        if window_list[2].window then
            dslpnp.sidebar.display(window_list[2].window, window_list[2].tab, window_list[2].label, window_list[2].extra)
        end
        if window_list[1].window then
            dslpnp.sidebar.display(window_list[1].window, window_list[1].tab, window_list[1].label, window_list[1].extra)
        end
    end
end

local function toggle(setVal)
    dslpnp.sidebar.Active = dslpnp.toggle("sidebar",dslpnp.sidebar.Active, setVal)
    if dslpnp.sidebar.Active then

    else

    end
end

local function config()
    local configs = dslpnp.config.sidebar or {}
    configs = table.update(defaults,configs)
    dslpnp.sidebar.configs = configs
    local origin = "top" .. configs.position
    local x,y,width,height = 0, 0, configs.width, 0
    if configs.position == "top" then
        origin = "topleft"
        height = width
        width = 0
    end
    if origin == "topright" then x = 16 end
    local half_width = windowManager.math(width, 2, "divide")
    for k,v in ipairs(windows) do
        dslpnp.displayed[v] = dslpnp.displayed[v] or {}
        if configs.position == "top" then
            width = configs[v].height .. " - 6px"
            half_width = windowManager.math(width, 2, "divide")
        else
            height = configs[v].height
        end
        dslpnp.sidebar[v] = {x = x, y = y, width = width, height = height, origin = origin, half_width = half_width}
        dslpnp.sidebar[v]["tabs"] = {}
        for k2,v2 in ipairs(configs[v]) do
            raiseEvent("onConfig", v2, v, x, y .. " + 25px", width, height .. " - 25px", origin)
        end
        if configs.position == "top" then
            x = windowManager.math(x,width,"add")
        else
            y = windowManager.math(y,height,"add")
        end
    end

    config_display()
    raiseEvent("onToggle","sidebar","on")
end

function dslpnp.sidebar.eventHandler(event,...)
    if event == "onToggle" and arg[1] == "sidebar" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "sidebar" then
        config()
    elseif event == "sysWindowResizeEvent" then
        fix_display()
    end
end

registerAnonymousEventHandler("onToggle", "dslpnp.sidebar.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.sidebar.eventHandler")
registerAnonymousEventHandler("sysWindowResizeEvent", "dslpnp.sidebar.eventHandler")
