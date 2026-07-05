-- File Send Script
-- 4/28/2016
-- by: Steven "Shanked" Blea
--

-- CHANGE NOTES
-- VERSION  4.03a
-- CHANGE   closeFile, sendNextLine, and timerSend "public"
-- CHANGE   timerSend NEW ARG len, defaults to 0.5
-- ADDED    openFile public function
-- ADDED    "file last" as an optional argument to resend the last file

dslpnp.filesend = dslpnp.filesend or {}
dslpnp.filesend.doStop = dslpnp.filesend.doStop or false

-- Aliases
-- file( noprotect)?
--  > You can type "file" by itself to open up a file dialog to select a file to send
--    to the game. Or, you can use the optional argument "noprotect" which will still
--    open up a file dialog, but will not allow you to stop a file from being sent
--    while in progress.
-- fstep( on|off)?
-- > Typing "fstep" alone steps through the file if file stepping is turned on. So,
--   rather than sending line by line on a timer, each line comes through only after
--   you send "fstep" to the client. File stepping may be toggled on or off via the
--   use of "fstep on" or "fstep off".

dslpnp.filesend.help = {[[
    File Send Script
    The file send script provides basic functionality for sending text files to the
    game. This is most useful for sending notes, updating descriptions and the like.
    However, advanced uses of the script could include some scripting functionality
    as well.

    File Send Help:
    help file
    help fstep

    2 Topics currently available.
]]}
dslpnp.filesend.help.file = [[
    args: "noprotect", ""
    syntax: ^file( noprotect)?
    Using "file" without an argument will open up a dialog window from which users can
    select a file to send to the MUD. Using the "noprotect" argument will do the same
    thing, but, users will not be able to stop the file mid-send like they would be
    able to with an ordinary file send.
]]
dslpnp.filesend.help.fstep = [[
    args: "on", "off", ""
    syntax: ^fstep( on|off)?
    Using fstep will step through the current file being sent IF file stepping is set
    to true. To turn file stepping on, simply use "fstep on" before sending your file
    and then use fstep to send it line by line.
]]

local fileTimer, protect, manualOn, currLine, file = nil, nil, false, 0, nil

-- CHANGE PUBLIC closeFile()
function dslpnp.filesend.closeFile()
    if file then
    	file:close()
    	file = nil
    end
    currLine = 0
    dslpnp.filesend.doStop = false
end

-- CHANGE PUBLIC sendNextLine()
function dslpnp.filesend.sendNextLine()

    currLine = currLine + 1
    local text = file:read(currLine)

    if not text then
        dslpnp.filesend.closeFile()
        return false
    elseif protect and dslpnp.filesend.doStop then
        dslpnp.filesend.closeFile()
        return false
    else
        text = (text ~= "" and text) or " "
        send(text)
        return true
    end

end

-- CHANGE PUBLIC timerSend()
function dslpnp.filesend.timerSend( len)
-- CHANGE NEW ARG len
    len = len or 0.5

    local text = dslpnp.filesend.sendNextLine()

    if text then
        if fileTimer then killTimer(fileTimer) end
        fileTimer = tempTimer(len, function () dslpnp.filesend.timerSend() end)
    end
end

-- NEW
function dslpnp.filesend.openFile(path,mode)
-- author: Shanked
    mode = mode or "read"
	if dslpnp.filesend.Active then
	    dslpnp.filesend.closeFile()
	    print("\nPNP> filesend > openFile: opening file: " .. path .. "\n")
	    if path ~= "" then
	        file = dslpnp.fileIO.open(path, "read")
	        if not manualOn then
	            dslpnp.filesend.timerSend()
	        end
	    end
	end
end

-- ADDED last parameter to file alias
function dslpnp.filesend.doFile( arg1)
    local last = false -- Resend the last file sent
    protect = false

	if dslpnp.filesend.Active then
        if      arg1 == "noprotect" then
                protect = "noprotect"

        elseif  arg1 == "last"      then
                last = true
        end

	    path = (last and (path or "")) or invokeFileDialog(true, [[Select a File to Open]])

	    dslpnp.filesend.closeFile()
	    echo("Opening file: " .. path)
	    if path ~= "" then
	        file = dslpnp.fileIO.open(path, "read")
	        if not manualOn then
	            dslpnp.filesend.timerSend()
	        end
        else
            print("\nPNP>filesend>error: no valid path selected.\n")
	    end
	end
end

function dslpnp.filesend.doFstep( arg1)
    if dslpnp.filesend.Active then
	    if arg1 == "on" then
	        manualOn = true
	        echo("Manual file stepping turned on.")
	    elseif arg1 == "off" then
	        manualOn = false
	        echo("Manual file stepping turned off.")
	        dslpnp.filesend.closeFile()
	    else
	        dslpnp.filesend.sendNextLine()
	    end
	end
end

local function toggle(setVal)
    -- Call toggle function to set on or off status for your script
    dslpnp.filesend.Active = dslpnp.toggle("filesend",dslpnp.filesend.Active, setVal)
    if dslpnp.filesend.Active then
        -- turn on things you need here, your script was just turned on
        if dslpnp.aliases.exists("File Alias") then dslpnp.aliases.enable("File Alias") end
        if dslpnp.aliases.exists("File Step Alias") then dslpnp.aliases.enable("File Step Alias") end
    else
        -- turn things off here, your script was just turned off
        if dslpnp.aliases.exists("File Alias") then dslpnp.aliases.disable("File Alias") end
        if dslpnp.aliases.exists("File Step Alias") then dslpnp.aliases.disable("File Step Alias") end
    end
end

local function config()
    -- do any required setup and make triggers and stuff here
    if not dslpnp.aliases.exists("File Alias") then
        dslpnp.aliases.register("File Alias", [[^file(?: (noprotect|last))?$]], [[dslpnp.filesend.doFile(matches[2])]], true)
    end
    if not dslpnp.aliases.exists("Stop Script Alias") then
        dslpnp.aliases.register("Stop Script Alias", [[^stop$]], [[raiseEvent("onScriptStop")]], true)
    else
    	enableAlias("Stop Script Alias")
    end
    if not dslpnp.aliases.exists("File Step Alias") then
        dslpnp.aliases.register("File Step Alias", [[^fstep(?: (on|off))?$]], [[dslpnp.filesend.doFstep(matches[2])]], true)
    end
    raiseEvent("onToggle","filesend","on")
end

function dslpnp.filesend.eventHandler(event,...)
    -- detect incoming events and respond to them here
    if event == "filesendEvent" and dslpnp.filesend.Active then
        -- note that this event will only be handled if your script is turned on
    elseif event == "onScriptStop" and dslpnp.filesend.Active then
        dslpnp.filesend.doStop = true
    elseif event == "onToggle" and arg[1] == "filesend" then
        toggle(arg[2])
    elseif event == "onConfig" and arg[1] == "filesend" then
        config()
    end
end

registerAnonymousEventHandler("onScriptStop", "dslpnp.filesend.eventHandler")
registerAnonymousEventHandler("filesendEvent", "dslpnp.filesend.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.filesend.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.filesend.eventHandler")
