-- Timer Management Script
-- 3/24/2014
-- v4.00b
--

dslpnp.timers = dslpnp.timers or {}
dslpnp.timers.list = dslpnp.timers.list or {}
dslpnp.timers.stopWatchID = dslpnp.timers.stopWatchID or createStopWatch()

dslpnp.timers.help = [[
	dslpnp.timers.register(duration, code, name, repeated) - returns timer object
		Returned alias can use the following methods:
			timer = dslpnp.timers.register(duration, code, name, repeated)
			timer:remove()
			timer:checkTimer()

	dslpnp.timers.remove(name)
	dslpnp.timers.checkTimer(name)
	dslpnp.timers.exists(name)

	raiseEvent("resetTimers") - this event will kill all current timers
	raiseEvent("pauseTimers") - this event will pause all current timers
	raiseEvent("resumeTimers") - this event will resume all current timers
]]

local paused = false
local realTime = dslpnp.timers.stopWatchID

local function pauseTimers()
	paused = true
	stopStopWatch(realTime)
end

local function resumeTimers()
	paused = false
end

local function incrementTimers()
	if not paused then
		local list = dslpnp.timers.list or {}
		local expired = {}
		local elapsed = stopStopWatch(realTime)
		resetStopWatch(realTime)
		startStopWatch(realTime)
		for k,v in pairs(list) do
			list[k].time  = v.time - elapsed
			if list[k].time <= 0 then
				if not v.duration then
					table.insert(expired,v.name)
				else
					list[k].time = v.duration
				end
				local pass, errors = pcall(v.func)
				if not pass then
					raiseEvent("timerError",errors)
				end
			end
		end
		if not table.is_empty(expired) then
			for k,v in pairs(list) do
				if table.index_of(expired,v.name) then
					if type(k) == number then
						table.remove(list,k)
					else
						list[k] = nil
					end
				end
				if table.is_empty(expired) then
					break
				end
			end
		end
	end
end

local function getNextID()
	local list = dslpnp.timers.list or {}
	local id
	for k,v in ipairs(list) do
		if k ~= v.name then
			id = k
			break
		end
	end
	id = id or (#list + 1)
	return id
end

function dslpnp.timers.register(duration, code, name, repeated)
	local list = dslpnp.timers.list or {}
	name = name or getNextID()
	if list[name] then
		error("Register: Timer name already exists.",2)
	end
	if type(code) ~= "function" then
		code = loadstring(tostring(code))
	end
	if repeated and type(repeated) ~= "boolean" then
		error("Register: Timer repeated variable must be true, false, or nil.",2)
	end
	list[name] = {time = duration, func = code, name = name}
	if repeated then list[name].duration = duration end
	return name
end

function dslpnp.timers.remove(name)
	dslpnp.timers.list[name] = nil
end

function dslpnp.timers.checkTimer(name)
	local list = dslpnp.timers.list or {}
	if not list[name] then
		return nil
	else
		return list[name].time, list[name].func
	end
end

function dslpnp.timers.exists(name)
	if dslpnp.timers.list[name] then
		return true
	else
		return false
	end
end

local function reset()
	dslpnp.timers.list = {}
	raiseEvent("resumeTimers")
end

function dslpnp.timers.eventHandler(event, ...)
	if event == "timerTick" then
		incrementTimers()
	elseif event == "pauseTimers" then
		pauseTimers()
	elseif event == "resumeTimers" then
		resumeTimers()
	elseif event == "timerError" then
		display(arg)
	elseif event == "resetTimers" then
		reset()
	end
end


registerAnonymousEventHandler("timerTick","dslpnp.timers.eventHandler")
registerAnonymousEventHandler("pauseTimers","dslpnp.timers.eventHandler")
registerAnonymousEventHandler("resumeTimers","dslpnp.timers.eventHandler")
registerAnonymousEventHandler("timerError","dslpnp.timers.eventHandler")
registerAnonymousEventHandler("resetTimers","dslpnp.timers.eventHandler")
