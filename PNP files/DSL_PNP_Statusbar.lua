-- Status Bar Script
-- 6/19/2018
-- v4.02s
--
-- prompt <%t|%h|%H|%m|%M|%v|%V|%e|%x|%X|%g|%s|%q|%y|%L|%S|%a|%l|%d|%C|%f|%b|%p|%r>%c
--

-- need proper color behavior for %b and %p

dslpnp.statusbar = dslpnp.statusbar or {}
dslpnp.statusbar.configs = dslpnp.statusbar.configs or {}
dslpnp.prompt = dslpnp.prompt or {}

dslpnp.statusbar.help = {
[[
    Statusbar Script

    The statusbar script accomplishes two major things: First, it gathers information
    from a specific in-game prompt that can be used by other scripts. Second, it allows
    users to adjust their own "PNP prompt" to appear just like they would want their
    in-game prompt to appear. Furthermore, the statusbar script provides an extra "display"
    bar for extra prompt info that one might want to see, but not have on every line
    and also provides, via plugins, additional information either for the prompt or display
    that cannot be obtained through the in-game prompt, such as time remaining on the
    spell of alterform, or one's current position (standing, sitting, resting, or sleeping).

    Functions:
    dslpnp.prompt (global table, not a function)

    Aliases:
    set prompt (none|default|prev|*)?
    set display (none|default|prev|*)?

    See Also:
    prompt, set prompt, set display, dslpnp.prompt
]],
["set prompt"] = [[
    Statusbar Script
    Set Prompt Alias

    Syntax: set prompt (none|default|prev|*)?

    none - Using the argument of "none" will set your prompt to &n& which is a blank
        input, allowing for your prompt to "disappear" while still gathering necessary
        prompt info from the in-game prompt for plug and play.

    default - Using the argument of default allows you to set your prompt back to the
        default one, in case you somehow manage to screw things up and don't want
        to look up the formatting options to return it back to a more normal looking
        prompt.

    prev - Most useful in combination with the none argument. Prev will return your prompt
        back to its last iteration. So, if you have a nice prompt you like, but, want
        to turn it off for some rp and then turn it back on after, you can use
        "set prompt none" to turn it off and then "set prompt prev" to restore your
        prompt back.

    * - Stands for a wildcard argument. You can put any prompt info you want to see here
        to set your "PNP prompt" to display that info, just as you would a normal prompt.
        Type "pnphelp statusbar prompt" for more specific info.

    ? - All arguments are optional. "set prompt" without an argument will display your
        current prompt, which is useful for backing it up or sharing it with other players.
]],
["set display"] = [[
    Statusbar Script
    Set display Alias

    Syntax: set display (none|default|prev|*)?

    none - Using the argument of "none" will set your display to &n& which is a blank
        input, allowing for your display to "disappear" while still gathering necessary
        display info from the in-game display for plug and play.

    default - Using the argument of default allows you to set your display back to the
        default one, in case you somehow manage to screw things up and don't want
        to look up the formatting options to return it back to a more normal looking
        display.

    prev - Most useful in combination with the none argument. Prev will return your display
        back to its last iteration. So, if you have a nice display you like, but, want
        to turn it off for some rp and then turn it back on after, you can use
        "set display none" to turn it off and then "set display prev" to restore your
        display back.

    * - Stands for a wildcard argument. You can put any display info you want to see here
        to set your "PNP display" to display that info, just as you would a prompt in game.
        Type "pnphelp statusbar prompt" for more specific info.

    ? - All arguments are optional. "set display" without an argument will display your
        current display, which is useful for backing it up or sharing it with other players.
]],
["dslpnp.prompt"] = [[
    Statusbar Script
    dslpnp.prompt

    dslpnp.prompt is a lua table and is interacted with as such. If you type
    "lua display(dslpnp.prompt)" you can get a look at all of the values. However, they
    are also listed here:

        curm_number           curmv_number         curhp_number
        moves_percent_number  mana_percent_number  health_percent_number
        moves_percent         mana_percent         health_percent
        blood_points          blood_percent        day_time
        language              curm                 meritxp
        name                  exits                curxp
        curhp                 silver               flying
        time                  craftskill           maxmv
        wimpy                 stance               maxhp
        gold                  maxm                 qpoints
        room                  alignment            quiet
        xptnl

    You might also see some additional values, depending on what plugins you use,
    for example, the Statusbar Script : Posn Plugin gives dslpnp.prompt the "posn"
    value.

    You'll notice that both curhp_number and curhp exist. This is because the script
    automatically prepares curhp with the proper formatting to display is white, yellow
    or red depending on your current health value in relation to your max health value.
    As a result, curhp_number exists, to allow one to easily get the raw number for use
    in their own scripts.

    To access a prompt value, you use normal lua methods for accessing a table. For the
    less lua literate, you might want to ask for some help on the forums. However, here's
    a little info to jumpstart your progress.

    You can access from a table in a number of ways, but, there are two ways that are
    most common when you know the key (that is anything in the list above):
    dslpnp.prompt["key"] or dslpnp.prompt.key

    For instance, if you wanted to grab your character's current hp, you could use:
    dslpnp.prompt["curhp_number"] or dslpnp.prompt.curhp_number
]],
["prompt"] = [[
    Statusbar Script
    Prompt

    You can use the following values in your prompt or display via "set prompt" or
    "set display" just as you would use them in an in-game prompt. Thus, you can also
    use color codes, extra characters, and anything else to dress up and decorate your
    prompt and/or display, just the way you want it.

    name - Displays your current character's name.
    %h - Displays the current hp value just like the in-game equivalent.
    %H - Displays the max hp value just like the in-game equivalent.
    %m - Displays the current mana value just like the in-game equivalent.
    %M - Displays the max mana value just like the in-game equivalent.
    %v - Displays the current movement value just like the in-game equivalent.
    %V - Displays the max movement value just like the in-game equivalent.
    %t - Displays the time value just like the in-game equivalent.
    %T - Displays the time value just like the in-game equivalent.
    %e - Displays the exits value just like the in-game equivalent.
    %x - Displays the curxp value just like the in-game equivalent.
    %X - Displays the xptnl value just like the in-game equivalent.
    %g - Displays the gold value just like the in-game equivalent.
    %s - Displays the silver value just like the in-game equivalent.
    %q - Displays the qpoints value just like the in-game equivalent.
    %y - Displays the wimpy value just like the in-game equivalent.
    %L - Displays the meritxp value just like the in-game equivalent.
    %l - Displays the language value just like the in-game equivalent.
    %d - Displays the day time value just like the in-game equivalent.
    %D - Displays the day time value just like the in-game equivalent.
    %C - Displays the craftskill value just like the in-game equivalent.
    %f - Displays the flying value just like the in-game equivalent.
    %r - Displays the room value just like the in-game equivalent.
    %S - Displays the stance value just like the in-game equivalent.
    %b - Displays the blood percent value just like the in-game equivalent.
    %p - Displays the blood points value just like the in-game equivalent.
    health_percent - Displays a percentage value of your current hp related to its max value.
    mana_percent - Displays a percentage value of your mana related to its max value.
    moves_percent - Displays a percentage value of your moves related to its max value.
    %a - Displays the alignment value just like the in-game equivalent.
    %Q - Because the statusbar prompt covers your in-game prompt, including quiet-mode,
         you can use %Q to show whether or not you're in quiet-mode wherever you want in
         your prompt.
    &n& - This is a null character value used primarily for storing blank prompts so that
          "set prompt none" can function properly.

    An example prompt might look like this:
    set prompt %Q<health_percent{Rhp{x %m/{W%M{Bm moves_percent{Dmv{x> {W({g%e{W){x

    Which would like this in-game (assuming you aren't in quiet-mode), colored the way
    you prefer:
    <89%hp 234/560m 46%mv> (E)
]],
}

local defaults = {
    height = 40,
    width = "60%",
    x = 0, y = 0, origin = "bottomleft",
    fontSize = 11,
    display = [[{Gname{W | ({C%t{W) (%h/{W%H{xhp {W%m/{W%M{xm {W%v/{W%V{xmv{W) ({G%e{W)%c{G%d{W - {C%r{W]],
    echo = [[%Q{W<%h/{W%H{xhp {W%m/{W%M{xm {W%v/{W%V{xmv{W>{x]],
    color = "black",
    fontColor = "white",
    indent = "10px",
    font = "monaco",
    show_room_color = true,
    colors = {
        red = "128,0,0",
        lt_red = "255,0,0",
        blue = "0,0,128",
        lt_blue = "0,0,255",
        green = "0,179,0",
        lt_green = "0,255,0",
        yellow = "128,128,0",
        lt_yellow = "255,255,0",
        magenta = "128,0,128",
        lt_magenta = "255,0,255",
        cyan = "0,128,128",
        lt_cyan = "0,255,255",
        white = "255,255,255",
        black = "128,128,128",
        gray = "192,192,192"
    }
}

local color_codes = {
    r = "red",
    R = "lt_red",
    g = "green",
    G = "lt_green",
    b = "blue",
    B = "lt_blue",
    y = "yellow",
    Y = "lt_yellow",
    c = "cyan",
    C = "lt_cyan",
    m = "magenta",
    M = "lt_magenta",
    D = "black",
    W = "white",
    w = "white",
    x = "gray"
}

dslpnp.statusbar.data_vals = dslpnp.statusbar.data_vals or {
    {"name","name"},
    {"%%h","curhp"},
    {"%%H","maxhp"},
    {"%%m","curm"},
    {"%%M","maxm"},
    {"%%v","curmv"},
    {"%%V","maxmv"},
    {"%%t","time"},
    {"%%T","time"},
    {"%%e","exits"},
    {"%%x","curxp"},
    {"%%X","xptnl"},
    {"%%g","gold"},
    {"%%s","silver"},
    {"%%q","qpoints"},
    {"%%y","wimpy"},
    {"%%L","meritxp"},
    {"%%l","language"},
    {"%%d","day_time"},
    {"%%D","day_time"},
    {"%%C","craftskill"},
    {"%%f","flying"},
    {"%%r","room"},
    {"%%S","stance"},
    {"%%b","blood_percent"},
    {"%%p","blood_points"},
    {"health_percent","health_percent"},
    {"mana_percent","mana_percent"},
    {"moves_percent","moves_percent"},
    {"%%a","alignment"},
    {"%%Q","quiet"},
    {"%%o","cur_weight"},
    {"%%O","max_weight"},
    {"%%c","\n"},
    {"&n&",""}
}

local trig_pattern = [[^(\[Quiet\]\s*|)<([^\|]+)\|([\d\?\-]+)\|([\d\?]+)\|([\d\-]+)\|(\d+)\|([\d\-]+)\|(\d+)\|([^\|]*)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d+)\|(\d*)\|([\w ]+)\|(\w+)\|([^\|]+)\|([^\|]+)\|(\d+)(?:\|(\d*)\|(\d*))?\|([^\|]*)(?:\|(\d*)\|(\d*))?\|(.*)>]]
local trig_code = [[dslpnp.statusbar.refresh(matches)]]

local function config()
    local configs = dslpnp.config.statusbar or {}
    configs = table.update(defaults,configs)
    dslpnp.statusbar.configs = configs
    local width, height = configs.width, configs.height
    local x,y = configs.x, configs.y
    local origin = configs.origin
    local offset = (dslpnp.config.sidebar and dslpnp.config.sidebar.width) or "0"

    if string.find(origin,"right") then
        x = x .. " + " .. offset .. " + 16"
    end
    if not dslpnp.triggers.exists("Prompt Trigger") then
        dslpnp.triggers.register("Prompt Trigger","regex",trig_pattern,trig_code,true)
    end
    createLabel("status_bar", 0, 0, 0, 0, 1)
    windowManager.add("status_bar", "label", x, y, width, height, origin)
    setLabelStyleSheet("status_bar",[[
        padding-left: ]] .. configs.indent .. [[;
        qproperty-alignment: AlignVCenter; font-size: ]] .. configs.fontSize .. [[;
        background-color: ]] .. configs.color)
    if not dslpnp.aliases.exists("Set Prompt Alias") then
        dslpnp.aliases.register("Set Prompt Alias", [[^set prompt\s?((?<=\s).*|)$]], [[dslpnp.statusbar.set_prompt(matches[2])]], true)
    end
    if not dslpnp.aliases.exists("Set Display Alias") then
        dslpnp.aliases.register("Set Display Alias", [[^set display\s?((?<=\s).*|)$]], [[dslpnp.statusbar.set_display(matches[2])]], true)
    end
    raiseEvent("onToggle","statusbar","on")
end

local function parse_values(text)
    local data = dslpnp.prompt
    local vals = dslpnp.statusbar.data_vals
    for k,v in ipairs(vals) do
        if data[v[2]] then
            text = string.gsub(text,v[1],data[v[2]])
        else
            text = string.gsub(text,v[1],v[2] or "")
        end
    end
    return text
end

local function load_char()
    local prompt_val = dslpnp.character.getCharData("statusbar_prompt") or ""
    local display_val = dslpnp.character.getCharData("statusbar_display") or ""
    if prompt_val and prompt_val ~= "" then
        print(" : Custom Prompt")
        dslpnp.statusbar.configs.echo = prompt_val
    else
        print(" : Default Prompt")
        dslpnp.statusbar.configs.echo = (dslpnp.config.statusbar and dslpnp.config.statusbar.echo) or defaults.echo
    end
    if display_val and display_val ~= "" then
        dslpnp.statusbar.configs.display = display_val
    else
        dslpnp.statusbar.configs.display = (dslpnp.config.statusbar and dslpnp.config.statusbar.display) or defaults.display
    end
end

function dslpnp.statusbar.set_prompt(prompt_val)
    if dslpnp.statusbar.Active then
        prompt_val = prompt_val or ""
        if prompt_val == "none" then
            prompt_val = "&n&"
        elseif prompt_val == "default" then
            prompt_val = (dslpnp.config.statusbar and dslpnp.config.statusbar.echo) or defaults.echo
        elseif prompt_val == "prev" and dslpnp.character.getCharData("prev_prompt") then
            prompt_val = dslpnp.character.getCharData("prev_prompt")
        elseif prompt_val == "" or prompt_val == "display" then
            print("Current prompt: "..dslpnp.character.getCharData("statusbar_prompt"))
            return true
        end
        prev_prompt = dslpnp.character.getCharData("statusbar_prompt")
        if prev_prompt == "" or not prev_prompt then
            prev_prompt = (dslpnp.config.statusbar and dslpnp.config.statusbar.echo) or defaults.echo
        end
        dslpnp.character.setCharData(prev_prompt,"prev_prompt")
        dslpnp.character.setCharData(prompt_val,"statusbar_prompt")
        dslpnp.statusbar.configs.echo = prompt_val
        prompt_val = string.gsub(prompt_val,"{%a","")
        print("Prompt set to: " .. prompt_val)
    end
end

function dslpnp.statusbar.set_display(display_val)
    if dslpnp.statusbar.Active then
        display_val = display_val or ""
        if display_val == "none" then
            display_val = "&n&"
        elseif display_val == "default" then
            display_val = (dslpnp.config.statusbar and dslpnp.config.statusbar.display) or defaults.display
        elseif display_val == "prev" and dslpnp.character.getCharData("prev_display") then
            display_val = dslpnp.character.getCharData("prev_display")
        elseif display_val == "" or display_val == "display" then
            print("Current display: "..dslpnp.character.getCharData("statusbar_display"))
            return true
        end
        prev_display = dslpnp.character.getCharData("statusbar_display")
        if prev_display == "" or not prev_display then
            prev_display = (dslpnp.config.statusbar and dslpnp.config.statusbar.display) or defaults.display
        end
        dslpnp.character.setCharData(prev_display,"prev_display")
        dslpnp.character.setCharData(display_val,"statusbar_display")
        dslpnp.statusbar.configs.display = display_val
        display_val = string.gsub(display_val,"{%a","")
        print("Display set to: " .. display_val)
    end
end

local color_tbl = {
    [0] = "{x", "{D",       "{x",       "{R",
    "{r",       "{G",       "{g",       "{Y",
    "{y",       "{B",       "{b",       "{M",
    "{m",       "{C",       "{c",       "{W",
}

local function find_color(str)
    local test_str = string.gsub(str,"[-([)%]%^%$%.*+?%%]","%%%1")
    local start,stop = string.find(line,test_str)
    local ansi, color, pos
    local new_str, last = "", "{x"
    if start then
        for k = start,stop do
            pos = k - start + 1
            ansi = dslpnp.support.getAnsiColor(string.sub(str,pos),k)
            color = color_tbl[ansi]
            if new_str == "" then
                new_str = (color ~= last and color or "") .. string.sub(str,pos,pos)
            else
                new_str = new_str .. string.sub(str,pos,pos) .. (color ~= last and color or "")
            end
            last = color
        end
        if string.find(new_str,"{") and not string.ends(new_str,"{x") then
            new_str = new_str .. "{x"
        end
        return new_str
    else
        return nil
    end
end

function dslpnp.statusbar.refresh(prompt_vals)
    table.remove(prompt_vals,1)
    local configs = dslpnp.statusbar.configs
    local name = (dslpnp.character and dslpnp.character.getCharData("name")) or "None"
    local display_str = configs.display
    local echo_str = configs.echo
    local prev_time = dslpnp.prompt.time
    local data = {
        quiet = prompt_vals[1],
        time = prompt_vals[2],
        curhp = prompt_vals[3],
        maxhp = prompt_vals[4],
        curm = prompt_vals[5],
        maxm = prompt_vals[6],
        curmv = prompt_vals[7],
        maxmv = prompt_vals[8],
        exits = prompt_vals[9] or "",
        curxp = prompt_vals[10] or "",
        xptnl = prompt_vals[11] or "",
        gold = prompt_vals[12] or "",
        silver = prompt_vals[13] or "",
        qpoints = prompt_vals[14] or "",
        wimpy = prompt_vals[15] or "",
        meritxp = prompt_vals[16] or "",
        stance = prompt_vals[17] or "",
        alignment = prompt_vals[18] or "",
        language = prompt_vals[19] or "",
        day_time = prompt_vals[20] or "",
        craftskill = prompt_vals[21] or "",
        blood_percent = prompt_vals[22] or "",
        blood_points = prompt_vals[23] or "",
        flying = prompt_vals[24] or "",
        cur_weight = prompt_vals[25] or "",
        max_weight = prompt_vals[26] or "",
        room = prompt_vals[27] or "",
        name = name,

    }

    if configs.show_room_color then
        data.room = find_color(data.room) or data.room
    end

    data.health_percent = (tonumber(data.curhp) and math.round(100 * data.curhp / data.maxhp)) or "???"
    data.curhp_number = data.curhp
    data.health_percent_number = data.health_percent

    data.curm_number = data.curm
    data.mana_percent = math.round(100 * data.curm / data.maxm)
    data.mana_percent_number = data.mana_percent

    data.curmv_number = data.curmv
    data.moves_percent = math.round(100 * data.curmv / data.maxmv)
    data.moves_percent_number = data.moves_percent

    if data.quiet == "[Quiet] " then
        data.quiet = "{w[{cQuiet{w]{x "
    end

    if tonumber(data.curhp) and data.health_percent > 75 then
        data.curhp = "{W" .. data.curhp .. "{x"
        data.health_percent = "{W" .. data.health_percent .. "{W%{x"
    elseif tonumber(data.curhp) and data.health_percent > 50 then
        data.curhp = "{Y" .. data.curhp .. "{x"
        data.health_percent = "{Y" .. data.health_percent .. "{W%{x"
    else
        data.curhp = "{R" .. data.curhp .. "{x"
        data.health_percent = "{R" .. data.health_percent .. "{W%{x"
    end

    if data.mana_percent > 75 then
        data.curm = "{W" .. data.curm .. "{x"
        data.mana_percent = "{W" .. data.mana_percent .. "{W%{x"
    elseif data.mana_percent > 50 then
        data.curm = "{Y" .. data.curm .. "{x"
        data.mana_percent = "{Y" .. data.mana_percent .. "{W%{x"
    else
        data.curm = "{R" .. data.curm .. "{x"
        data.mana_percent = "{R" .. data.mana_percent .. "{W%{x"
    end

    if data.moves_percent > 75 then
        data.curmv = "{W" .. data.curmv .. "{x"
        data.moves_percent = "{W" .. data.moves_percent .. "{W%{x"
    elseif data.moves_percent > 50 then
        data.curmv = "{Y" .. data.curmv .. "{x"
        data.moves_percent = "{Y" .. data.moves_percent .. "{W%{x"
    else
        data.curmv = "{R" .. data.curmv .. "{x"
        data.moves_percent = "{R" .. data.moves_percent .. "{W%{x"
    end

    dslpnp.prompt = table.update(dslpnp.prompt,data)

    -- raising event to tell plugins to update prompt values
    raiseEvent("updatePrompt")
    if prev_time ~= data.time then
        raiseEvent("updateTick")
    end

    display_str = parse_values(display_str)
    display_str = dslpnp.support.replaceColors(display_str, true)
    echo_str = parse_values(echo_str)
    echo_str = dslpnp.support.replaceColors(echo_str, false)
    moveCursorEnd()
    local selLine = string.match(line,[[<[^>]+>%s*]])
    selectString(selLine,1)
	replace("")
	selLine = string.match(line,[[%[Quiet%] ]])
	if selLine then
	    selectString(selLine,1)
		replace("")
	end
    if echo_str ~= "" then
        cecho(echo_str .. "\n")
    end
    display_str = string.format([[<font face="%s"><span style="white-space: pre; font-size: %spt; color:%s">%s</span></font>]],configs.font, configs.fontSize, configs.fontColor, display_str)
    echo("status_bar",display_str)
    raiseEvent("onPrompt")
    if prev_time ~= data.time then
        raiseEvent("onTick")
    end
end

function dslpnp.statusbar.is_prompt(str)
    local test = rex.match(str,[[^(?:\[Quiet\]\s*|)<[^\|]+\|[\d\?]+\|[\d\?]+\|\d+\|\d+\|\d+\|\d+\|[^\|]*\|\d+\|\d+\|\d+\|\d+\|\d+\|\d+\|\d*\|\w+\|\w+\|[^\|]+\|[^\|]+\|\d+(?:\|\d*\|\d*)?\|[^\|]*(?:\|\d*\|\d*)?\|.*>]])
    return test == str
end

local function toggle(setVal)
    dslpnp.statusbar.Active = dslpnp.toggle("statusbar",dslpnp.statusbar.Active, setVal)
    if dslpnp.statusbar.Active then
        showWindow("status_bar")
        if dslpnp.aliases.exists("Set Prompt Alias") then dslpnp.aliases.enable("Set Prompt Alias") end
        if dslpnp.aliases.exists("Set Display Alias") then dslpnp.aliases.enable("Set Display Alias") end
    else
        hideWindow("status_bar")
        if dslpnp.aliases.exists("Set Prompt Alias") then dslpnp.aliases.disable("Set Prompt Alias") end
        if dslpnp.aliases.exists("Set Display Alias") then dslpnp.aliases.disable("Set Display Alias") end
    end
end

function dslpnp.statusbar.eventHandler(event, ...)
    if event == "characterLoaded" and dslpnp.statusbar.Active then
        load_char()
    elseif event == "onToggle" and arg[1] == "statusbar" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "statusbar" then
        config()
    end
end

registerAnonymousEventHandler("onToggle", "dslpnp.statusbar.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.statusbar.eventHandler")
registerAnonymousEventHandler("characterLoaded", "dslpnp.statusbar.eventHandler")
