-- Moon Tracking Script
-- 3/02/2014
-- v4.00c
--
-- Type "toggle moons" to disable or enable this script.
-- Information is displayed whenever you information on the affects of the moons (l moons or lunar).
--
-- To disable by default, change "toggle("on")" in the setup function (below) to "toggle("off")".
--

dslpnp.moons = dslpnp.moons or {}

dslpnp.moons.help = dslpnp.moons.help or {}
dslpnp.moons.help[1] = [[
    Moons Script

    This is a basic script to provide some timing functionality when one looks at the
    moons. It will give predictions on lunar cycle changes so that you can more accurately
    plan for when a certain moon phase you're looking for will happen.
]]

local moonColor
local moonPhase
local moonTime
local tickLen = 42
local phaseTimes = {black = 66, red = 90, white = 108}
local phaseList = {
	["empty"] = "crescent waxing",
	["crescent waxing"] = "half waxing",
	["half waxing"] = "waxing three-quarters",
	["waxing three-quarters"] = "full",
	["full"] = "waning three-quarters",
	["waning three-quarters"] = "half waning",
	["half waning"] = "crescent waning",
	["crescent waning"] = "empty"}
local phaseSpaces = {
	["empty"] = "                 ",
	["crescent waxing"] = "       ",
	["half waxing"] = "           ",
	["waxing three-quarters"] = " ",
	["full"] = "                  ",
	["waning three-quarters"] = " ",
	["half waning"] = "           ",
	["crescent waning"] = "       "}
local moonInfo = {}

local function addTime(time)
	local sysTimeTbl = string.split(getTime(true, "hh:mm:ss:a"),":")
	local timeTbl = time:split(":")
	timeTbl[4] = sysTimeTbl[4]
	for a = 3,1,-1 do
		timeTbl[a] = tonumber(timeTbl[a])
		sysTimeTbl[a] = tonumber(sysTimeTbl[a])
		timeTbl[a] = math.floor(timeTbl[a] + sysTimeTbl[a])
		if timeTbl[a] > 59 then
			timeTbl[a] = math.floor(timeTbl[a] - 60)
			timeTbl[a-1] = math.floor(timeTbl[a-1] + 1)
		end
		if a == 1 then
			if timeTbl[a] > 12 then
				timeTbl[a] = math.floor(timeTbl[a] - 12)
				if timeTbl[4] == "am" and sysTimeTbl[1] < 12 then
					timeTbl[4] = "pm"
				else
					timeTbl[4] = "am"
				end
			end
		end
	end
	return string.format("%02d:%02d:%02d %s",timeTbl[1],timeTbl[2],timeTbl[3],timeTbl[4])
end

local function calculateTime(ticks, basetime)
	local timeTbl = {}
	local totalTime = tickLen * tonumber(ticks)
	for a = 3,1,-1 do
		totalTime,timeTbl[a] = math.modf(totalTime/60)
		timeTbl[a] = timeTbl[a]*60
	end
	if basetime ~= nil then
		local baseTbl = basetime:split(":")
		for a = 3,1,-1 do
			timeTbl[a] = timeTbl[a] + baseTbl[a]
			if timeTbl[a] > 59 then
				timeTbl[a] = timeTbl[a] - 60
				timeTbl[a-1] = timeTbl[a-1] + 1
			end
			timeTbl[a] = math.floor(timeTbl[a])
		end
	end
	return string.format("%02d:%02d:%02d",timeTbl[1],timeTbl[2],timeTbl[3])
end

local function display_moons(color, phase, time)
	if dslpnp.moons.Active then
		assert(color == "red" or color == "white" or color == "black", "Invalid color!")
		assert(table.contains(phaseList,phase), "Invalid phase!")
		assert(tonumber(time) ~= nil, "Invalid time!")
		local a, curphase, curtime, basetime
		moonColor = color
		curphase = phase
		curtime = time
		basetime = "0:00:00"
		echo("\n")
		for a = 1,8 do
			curphase = phaseList[curphase]
			basetime = calculateTime(curtime, basetime)
			curtime = phaseTimes[moonColor]
			echo(phaseSpaces[curphase] .. curphase .. " in " .. basetime .. " [ " .. addTime(basetime) .. " ]\n")
		end
	end
end

local function make_triggers()
	if not dslpnp.triggers.exists("Moons Trigger 1") then
        dslpnp.triggers.register("Moons Trigger 1","regex",[[The (.*) moon is (.*) and (.*).]],[[raiseEvent("onMoons","color",matches[2], "phase", matches[3])]],true)
    end
    if not dslpnp.triggers.exists("Moons Trigger 2") then
        dslpnp.triggers.register("Moons Trigger 2","regex",[[\[Mana .*\%\]  \[Saves .*\]  \[Casting .*\]  \[Regen .*\%\]  \[Cycles remaining (.*) \(.* Hours\)\]\s*]],[[raiseEvent("onMoons","time",matches[2])]],true)
    end
end

local function toggle(setVal)
	dslpnp.moons.Active = dslpnp.toggle("moons",dslpnp.moons.Active, setVal)
end

local function config()
	make_triggers()
	raiseEvent("onToggle","moons","on")
end

function dslpnp.moons.eventHandler(event, ...)
	if event == "onMoons" and dslpnp.moons.Active then
		if arg[1] ~= "time" then
			moonInfo[arg[1]] = arg[2]
			moonInfo[arg[3]] = arg[4]
		else
			moonInfo[arg[1]] = arg[2]
			display_moons(moonInfo.color, moonInfo.phase, moonInfo.time)
		end
	elseif event == "onToggle" and arg[1] == "moons" then
		toggle(arg[2])
	elseif event == "onConfig" and arg[1] == "moons" then
		config()
	end
end

registerAnonymousEventHandler("onMoons", "dslpnp.moons.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.moons.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.moons.eventHandler")
