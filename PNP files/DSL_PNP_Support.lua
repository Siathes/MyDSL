-- Support Script
-- 6/19/2018
-- v4.04d
--
-- Provided functions:
-- dslpnp.support.adjustWordWrap(window, width, font_size) or dslpnp.support.adjustWordWrap(window, font_size) -- for windowManager windows only
-- dslpnp.support.replaceColors(text, for_label) or dslpnp.support.replaceColors(text)
-- dslpnp.support.formatLabelText(text, font_size, center, bold, italic, underline, font)
-- dslpnp.support.getAnsiColor(text, start)
-- fprint(window, text, wrap) or fprint(window, text) or fprint(text, wrap) or fprint(text)
-- sendQueue(cmd,wait,cmd,...)
--

dslpnp.support = dslpnp.support or {}

-- Add DSL default colors to color table
color_table.dsl_red = {128,0,0}
color_table.dsl_lt_red = {255,0,0}
color_table.dsl_yellow = {128,128,0}
color_table.dsl_lt_yellow = {255,255,0}
color_table.dsl_green = {0,179,0}
color_table.dsl_lt_green = {0,255,0}
color_table.dsl_blue = {0,0,128}
color_table.dsl_lt_blue = {0,0,255}
color_table.dsl_cyan = {0,128,128}
color_table.dsl_lt_cyan = {0,255,255}
color_table.dsl_magenta = {128,0,128}
color_table.dsl_lt_magenta = {255,0,255}
color_table.dsl_black = {128,128,128}
color_table.dsl_lt_white = {255,255,255}
color_table.dsl_white = {192,192,192}
color_table.dsl_orange = {168,42,0}
color_table.dsl_pink = {210,42,126}
color_table.dsl_brown = {126,42,0}
color_table.dsl_purple = {42,42,126}

-- Table of in game color codes, and corresponding cecho colors
dslpnp.support.color_codes = {
    ["{r"] = "<dsl_red>",
    ["{R"] = "<dsl_lt_red>",
    ["{y"] = "<dsl_yellow>",
    ["{Y"] = "<dsl_lt_yellow>",
    ["{g"] = "<dsl_green>",
    ["{G"] = "<dsl_lt_green>",
    ["{b"] = "<dsl_blue>",
    ["{B"] = "<dsl_lt_blue>",
    ["{c"] = "<dsl_cyan>",
    ["{C"] = "<dsl_lt_cyan>",
    ["{m"] = "<dsl_magenta>",
    ["{M"] = "<dsl_lt_magenta>",
    ["{w"] = "<dsl_white>",
    ["{W"] = "<dsl_lt_white>",
    ["{D"] = "<dsl_black>",
    ["{o"] = "<dsl_orange>",
    ["{p"] = "<dsl_pink>",
    ["{n"] = "<dsl_brown>",
    ["{u"] = "<dsl_purple>",
    ["{x"] = "<reset>",
    ["{-"] = "~",
    ["{n"] = "\n"
}

local function html_color(text)
    local tbl = string.split(text,"\n")
    for k,v in ipairs(tbl) do
        v = string.gsub(v, "<([%a_]+)>", function (s) if color_table[s] then return [[<font style="color:rgb(]] .. table.concat(color_table[s],",") .. [[)">]] elseif s == "reset" then return [[<\font>]] else return s end end,1)
        v = string.gsub(v, "<([%a_]+)>", function (s) if color_table[s] then return [[<\font><font style="color:rgb(]] .. table.concat(color_table[s],",") .. [[)">]] elseif s == "reset" then return [[<\font>]] else return s end end)
        v = v .. [[<\font>]]
        v = string.gsub(v, [[<\font><\font>]],[[<\font>]])
        tbl[k] = v
    end
    text = table.concat(tbl,"<br>")
    return text
end

function dsend(...)
    for k,v in ipairs(arg) do
        if dslpnp.editor and not dslpnp.editor.open then
            send(v,dslpnp.support.debug)
        else
            local encl = (string.find(v,'"') and not string.find(v,"'") and "'") or '"'
            send([[.v ]]..encl..v,dslpnp.support.debug)
        end
    end
end

function dslpnp.support.formatLabelText(text, fontSize, center, bold, italic, underline, r, g, b, font)
    assert(type(text) == "string", "dslpnp.support.formatLabelText: bad argument #1 \"text\", must be a string.")
    assert(type(fontSize) == "number" or fontSize == nil,"dslpnp.support.formatLabelText: bad argument #2 \"fontSize\", must be number.")
    assert(type(center) == "boolean" or center == nil, "dslpnp.support.formatLabelText: bad argument #3 \"center\", must be true or false.")
    assert(type(bold) == "boolean" or bold == nil, "dslpnp.support.formatLabelText: bad argument #4 \"bold\", must be true or false.")
    assert(type(italic) == "boolean" or italic == nil, "dslpnp.support.formatLabelText: bad argument #5 \"italic\", must be true or false.")
    assert(type(underline) == "boolean" or underline == nil, "dslpnp.support.formatLabelText: bad argument #6 \"underline\", must be true or false.")
    if type(g) == "string" then
        font = g
        g = nil
    end
    if r ~= nil then
        if g == nil then
            r,g,b = getRGB(r)
        end
    end
    text = string.gsub(text,"\n","<br>")
    if fontSize then text = [[<span style="font-size: ]] .. fontSize .. [[px">]] .. text .. [[</span>]] end
    if font then text = [[<span style="font-family: ']] .. font .. [['">]] .. text .. [[</span>]] end
    if center then text = "<center>" .. text .. "</center>" end
    if bold then text = "<b>" .. text .. "</b>" end
    if italic then text = "<i>" .. text .. "</i>" end
    if underline then text = "<u>" .. text .. "</u>" end
    if r then text = string.format("<span style='color: rgb(%d,%d,%d)'>" .. text .. "</span>", r, g, b) end
    return text
end

function dslpnp.support.replaceColors(text, for_label)
    local codes = dslpnp.support.color_codes
    text = string.gsub(text, "({[%a%-])", function (s) return codes[s] or s end)
    if for_label then
        text = html_color(text)
    end
    return text
end

function getColorWildcard(color)
        local color = tonumber(color)
        local startc, endc
        local results = {}

        for i = 0, string.len(line) - 1 do
                selectSection(i, 1)
                if isAnsiFgColor(color) then
                        if not startc then
                                startc = i + 1
                                endc = i + 1
                        else
                                endc = i + 1
                                if i == line:len() then
                                        results[#results + 1] = line:sub(startc, endc)
                                end
                        end
                elseif startc then
                        results[#results + 1] = line:sub(startc, endc)
                        startc = nil
                end
        end
        return results[1] and results or false
end

function dslpnp.support.getAnsiColor(text,start)
    text = string.gsub(text,"[-([)%]%^%$%.*+?%%]","%%%1")
    local start,stop = string.find(line,text,start or 1)
    if selectSection(start,stop - stop + 1) then
        for k=0,15 do
            if isAnsiFgColor(k) then
                return k
            end
        end
    end
    return false
end

function dslpnp.support.adjustWordWrap(window, width, font_size)
    if not font_size then
        font_size = width
        width = windowManager.getValue(window,"width") or 0
    end
    local wrap = math.floor(width / calcFontSize(font_size))
    setWindowWrap(window,wrap)
end

local function get_word_length(word)
    word = string.gsub(word,"<[%a_]+>","")
    return #word
end

function dslpnp.support.wrapLines(text,length,pad)
    pad = pad or ""
    if not (text and length) then
        error("wrapLines: missing arguments, text to wrap and line length are both required.",2)
    end
    local output, line_str, line_len = "","",0
    local pre_formatted = {}
    text = string.gsub(text,"<[bB][rR]>","<pre></pre>")
    for word in string.gmatch(text,"<[pP][rR][eE]>(.-)</[pP][rR][eE]>") do
        table.insert(pre_formatted,word)
    end
    text = string.gsub(text,"<[pP][rR][eE]>.-</[pP][rR][eE]>","<pre>")
    text = string.gsub(text,"\n%s*\n"," <new_line> ")
    for word in string.gmatch(text,"%S+") do
        line_len = line_len + get_word_length(word) + 1
        if line_len + #pad > length or word == "<new_line>" or word == "<pre>" then
            output = output .. line_str .. "\n"
            line_str = ""
            line_len = get_word_length(word)
        end
	    line_str = line_str .. " " .. word
    end
    output = output .. line_str
    output = string.gsub(output,"<new_line>","\n")
    output = string.gsub(output,"\n *(%S)","\n"..pad.."%1")
    output = string.gsub(output,"^ *(%S)",pad.."%1")
	output = string.gsub(output,"<pre> *(%S)","<pre>\n"..pad.."%1")
    output = string.gsub(output,"<pre> *",function() return table.remove(pre_formatted,1) end)
    return output
end

function dslpnp.support.unpack(tbl)
    local new = {}
    for k,v in pairs(tbl) do
        table.insert(new,k)
        table.insert(new,v)
    end
    return unpack(new)
end

function dslpnp.support.repack(tbl)
    local new, newTbl = {}, {}
    for k=1,#tbl,2 do
        newTbl[new[k]] = new[k+1]
    end
    return newTbl
end

function fprint(window, text, wrap)
    if type(text) == "boolean" or not text then
        wrap = text
        text = window
        window = nil
    end
    if wrap == nil then wrap = true end
    if wrap then text = "\n" .. text .. "\n" end
    text = dslpnp.support.replaceColors(text)
    if not window then
        cecho(text)
    else
        cecho(window,text)
    end
end

local function fix_tabs()
    local text = line
    local pos = selectString("\t",1)
    while pos ~= -1 do
        replace(string.rep(" ",8 - math.fmod(pos,8)))
        pos = selectString("\t",1)
    end
end


local runQueue
function runQueue(tbl)
    local info = table.remove(tbl,1)
    if info then
        local run = function()
                send(info[2])
                runQueue(tbl)
            end
        if info[1] ~= 0 then
            tempTimer(info[1], run)
        else
            run()
        end
    end
end

function sendQueue(...)
    local tbl = {}
    local args = arg
    for k,v in ipairs(args) do
        if k % 2 == 1 and type(v) ~= "number" then
            table.insert(args,k,0)
        end
    end
    for k = 1,#args,2 do
        tbl[(k + 1) / 2] = {args[k],args[k+1]}
    end
    runQueue(tbl)
end

local function config()
    if not dslpnp.triggers.exists("Tab Fix Trigger") then
        dslpnp.triggers.register("Tab Fix Trigger","regex","\t",[[raiseEvent("onTab")]],true)
    end
    if not dslpnp.triggers.exists("Blank Line Trigger") then
        dslpnp.triggers.register("Blank Line Trigger","regex",[[^\s*$]],[[raiseEvent("onBlank")]],true)
    end
    if not dslpnp.aliases.exists("Toggle Alias") then
        dslpnp.aliases.register("Toggle Alias",[[^toggle ([\w\.]+)\s?((?<=\s)\w+|)$]],[[raiseEvent("onToggle",matches[2],matches[3])]],true)
    end
    if not dslpnp.aliases.exists("Update Package Alias") then
        dslpnp.aliases.register("Update Package Alias",[[^update package$]],[[dslpnp.update.update_package()]],true)
    end
    if not dslpnp.aliases.exists("Initialize Alias") then
        dslpnp.aliases.register("Initialize Alias",[[^initialize$]],[[dslpnp.initialize()]],true)
    end
    if not dslpnp.aliases.exists("Fix Prompt Alias") then
        dslpnp.aliases.register("Fix Prompt Alias",[[^fix prompt$]],[[send("prompt <%t|%h|%H|%m|%M|%v|%V|%e|%x|%X|%g|%s|%q|%y|%L|%S|%a|%l|%d|%C|%b|%p|%f|%o|%O|%r>%c",false)]],true)
    end

    dslpnp.support.debug = (dslpnp.config.support and dslpnp.config.support.debug) or false
end

function dslpnp.support.eventHandler(event, ...)
    if event == "onConfig" and arg[1] == "support" then
        config()
    elseif event == "onConfigEnd" then
        if not dslpnp.triggers.exists("New Line Trigger") then
            dslpnp.triggers.register("New Line Trigger","regex",[[^]],[[raiseEvent("onLine",line)]],true)
        end
    elseif event == "onToggle" and arg[1] == "debug" then
        if dslpnp.support.debug then
            dslpnp.support.debug = false
            fprint("{RDebug mode toggled off.")
        else
            dslpnp.support.debug = true
            fprint("{GDebug mode toggled on.")
        end
    elseif event == "onTab" then
        fix_tabs()
    end
end

registerAnonymousEventHandler("onConfig","dslpnp.support.eventHandler")
registerAnonymousEventHandler("onConfigEnd","dslpnp.support.eventHandler")
registerAnonymousEventHandler("onTab","dslpnp.support.eventHandler")
