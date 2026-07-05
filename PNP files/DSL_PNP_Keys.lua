-- Keys Script
-- 4/11/2014
-- v4.00b
--


dslpnp.keys = dslpnp.keys or {}
dslpnp.keys.configs = dslpnp.keys.configs or {}

dslpnp.keys.help = [[
DSL PNP - Keys Script

This script allows the number pad keys to be used as macros to execute various commands.
They can be used alone, or in combination with modifier keys (shift, alt, control, & meta).
Each key combination can be set in any of the following ways:

	As a string, the command will be sent as if you had typed it into the command line.
	This will also properly work with any aliases you have created.

	As a function, the custom function will be executed with no arguments.

	As a table, with the first entry as a function, the custom function will be executed
	with any following table entries used as arguments sent to the function.

	As nil, the key combination specified will be disabled as a macro, and will function
	as a normal key stroke.

Entire modifier key sets can be enabled or disabled by setting the associated "enabled"
value to true or false, as desired.
]]

defaults = {
	basic = {
		enabled = true,
		["1"] = "sw",
		["2"] = "s",
		["3"] = "se",
		["4"] = "w",
		["5"] = "scan",
		["6"] = "e",
		["7"] = "nw",
		["8"] = "n",
		["9"] = "ne",
		["0"] = "where",
		["."] = nil,
		["+"] = "d",
		["-"] = "u",
		["*"] = nil,
		["/"] = nil,
		["="] = nil,
		["clear"] = nil,
		["enter"] = nil
	},
	shift = {
		enabled = true,
		["1"] = "open southwest",
		["2"] = "open south",
		["3"] = "open southeast",
		["4"] = "open west",
		["5"] = nil,
		["6"] = "open east",
		["7"] = "open northwest",
		["8"] = "open north",
		["9"] = "open northeast",
		["0"] = nil,
		["."] = nil,
		["+"] = "open down",
		["-"] = "open up",
		["*"] = nil,
		["/"] = nil,
		["="] = nil,
		["clear"] = nil,
		["enter"] = nil
	},
	alt = {
		enabled = false,
		["1"] = "sw",
		["2"] = "s",
		["3"] = "se",
		["4"] = "w",
		["5"] = nil,
		["6"] = "e",
		["7"] = "nw",
		["8"] = "n",
		["9"] = "ne",
		["0"] = nil,
		["."] = nil,
		["+"] = "d",
		["-"] = "u",
		["*"] = nil,
		["/"] = nil,
		["="] = nil,
		["clear"] = nil,
		["enter"] = nil
	},
	control = {
		enabled = false,
		["1"] = "close sw",
		["2"] = "close s",
		["3"] = "close se",
		["4"] = "close w",
		["5"] = nil,
		["6"] = "close e",
		["7"] = "close nw",
		["8"] = "close n",
		["9"] = "close ne",
		["0"] = nil,
		["."] = nil,
		["+"] = "close d",
		["-"] = "close u",
		["*"] = nil,
		["/"] = nil,
		["="] = nil,
		["clear"] = nil,
		["enter"] = nil
	},
	meta = {
		enabled = true,
		["1"] = "close sw",
		["2"] = "close s",
		["3"] = "close se",
		["4"] = "close w",
		["5"] = nil,
		["6"] = "close e",
		["7"] = "close nw",
		["8"] = "close n",
		["9"] = "close ne",
		["0"] = nil,
		["."] = nil,
		["+"] = "close d",
		["-"] = "close u",
		["*"] = nil,
		["/"] = nil,
		["="] = nil,
		["clear"] = nil,
		["enter"] = nil
	},
}

local function execute(command)
	local check, errors = true, nil
	if type(command) == "string" then
		expandAlias(command)
	elseif type(command) == "function" then
		check, errors = pcall(command)
	elseif type(command) == "table" then
		local func, args = command[1], {}
		for k = 2,#command do
			table.insert(args,command[k])
		end
		check, errors = pcall(func, unpack(args))
	else
		print("Error: Invalid command for macro.")
	end
	if not check then
		display(errors)
	end
end

function dslpnp.keys.macro(key, mod)
	if dslpnp.keys.Active then
		local configs = dslpnp.keys.configs
		if not mod then mod = "basic" end
		if configs[mod].enabled and configs[mod][key] then
			execute(configs[mod][key])
		end
	end
end

local function config()
	local mods = {"basic","shift","alt","control","meta"}
	local keys = {"1","2","3","4","5","6","7","8","9","0","+","-","*","=","/","clear","enter"}
	local name
	local configs = table.update(defaults,dslpnp.config.keys or {})
	dslpnp.keys.configs = configs
	for k,v in ipairs(mods) do
		if configs[v].enabled then
			name = string.title(v)
			enableKey(name .. " Keypad Macros")
			if name == "Basic" then name = "Keypad" end
			name = name .. " "
			for k2, v2 in ipairs(keys) do
				if configs[v][v2] then
					enableKey(name .. v2)
				else
					disableKey(name .. v2)
				end
			end
		else
			disableKey(string.title(v) .. " Keypad Macros")
		end
	end
	raiseEvent("onToggle","keys","on")
end

local function toggle(setVal)
	dslpnp.keys.Active = dslpnp.toggle("keys",dslpnp.keys.Active, setVal)
	if dslpnp.keys.Active then
		enableKey("Keypad Macros")
	else
		disableKey("Keypad Macros")
	end
end

function dslpnp.keys.eventHandler(event, ...)
	if event == "onToggle" and arg[1] == "keys" then
		toggle(arg[2])
	elseif event == "onConfig" and arg[1] == "keys" then
		config()
	end
end

registerAnonymousEventHandler("onToggle", "dslpnp.keys.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.keys.eventHandler")
