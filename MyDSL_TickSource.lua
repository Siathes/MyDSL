
--[[=====================================================================
  MyDSL.TickSource v4C1 PNP40
  ----------------------------------------------------------------------
  Shared tick timing authority for MyDSL.

  Reviewed source:
    - PNP DSL_PNP_Ticktimer.lua
      defaults: average=40, window=5, increment=0.25
      smoothing: if measured within window, 90% old average + 10% measured;
                 otherwise reset to configured average.

  Contract:
    - Listen to gmcp.tick.
    - Maintain MyDSL.DB.tick.
    - Raise MyDSL.Tick.Pulse on true game ticks.
    - Raise MyDSL.Tick.Updated on live countdown updates.
    - No display code here.
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.TickSource = MyDSL.TickSource or {}

local T = MyDSL.TickSource
T.version = "TickSource v4C1 PNP40"
T.config = T.config or {}
T.config.average = tonumber(T.config.average or 40) or 40
T.config.window = tonumber(T.config.window or 5) or 5
T.config.increment = tonumber(T.config.increment or 0.25) or 0.25
T.config.warnTime = tonumber(T.config.warnTime or 5) or 5
T.config.closeTime = tonumber(T.config.closeTime or 15) or 15
T.debug = T.debug == true

T.state = T.state or {
  running = false,
  ticks = 0,
  current = 0,
  average = T.config.average,
  remaining = nil,
  percent = 0,
  source = "none",
  lastMeasured = nil,
  lastTickAt = nil,
  lastWarnSecond = nil,
}

local function ce(msg)
  cecho("\n<cyan>[MyDSL.TickSource]<reset> " .. tostring(msg) .. "\n")
end

local function dbg(msg)
  if T.debug then ce("debug: " .. tostring(msg)) end
end

local function safeRaise(name, ...)
  if raiseEvent then pcall(raiseEvent, name, ...) end
end

local function ensureDB()
  MyDSL = MyDSL or {}
  MyDSL.DB = MyDSL.DB or {}
  MyDSL.DB.tick = MyDSL.DB.tick or {}
end

local function now()
  if getEpoch then
    local ok, v = pcall(getEpoch)
    if ok and tonumber(v) then return tonumber(v) end
  end
  return os.time()
end

function T.publish(reason)
  ensureDB()
  local avg = tonumber(T.state.average or T.config.average) or 40
  local cur = tonumber(T.state.current or 0) or 0
  local rem = avg - cur
  if rem < 0 then rem = 0 end
  local pct = avg > 0 and (rem / avg) or 0
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end

  T.state.remaining = rem
  T.state.percent = pct

  MyDSL.DB.tick = {
    version = T.version,
    running = T.state.running == true,
    ticks = tonumber(T.state.ticks or 0) or 0,
    current = cur,
    remaining = rem,
    average = avg,
    configured = tonumber(T.config.average) or 40,
    window = tonumber(T.config.window) or 5,
    increment = tonumber(T.config.increment) or 0.25,
    percent = pct,
    source = T.state.source or "none",
    lastMeasured = T.state.lastMeasured,
    lastTickAt = T.state.lastTickAt,
    reason = reason or "update",
    updatedAt = now(),
  }

  safeRaise("MyDSL.Tick.Updated")
end

function T.onGameTick()
  local measured = tonumber(T.state.current or 0) or 0
  local avg = tonumber(T.state.average or T.config.average) or 40
  local configured = tonumber(T.config.average) or 40
  local window = tonumber(T.config.window) or 5

  -- First tick after login has no measured interval. Keep configured default.
  if (T.state.ticks or 0) > 0 and measured > 0 then
    if math.abs(avg - measured) < window then
      avg = 0.01 * math.floor((90 * avg) + (10 * measured))
    else
      avg = configured
    end
    T.state.lastMeasured = measured
  else
    avg = configured
    T.state.lastMeasured = nil
  end

  T.state.average = avg
  T.state.current = 0
  T.state.running = true
  T.state.ticks = (tonumber(T.state.ticks or 0) or 0) + 1
  T.state.lastTickAt = now()
  T.state.source = "gmcp.tick"
  T.state.lastWarnSecond = nil

  T.publish("tick")
  safeRaise("MyDSL.Tick.Pulse")
  dbg("tick #" .. tostring(T.state.ticks) .. " avg=" .. tostring(avg))
end

function T.updateTimer()
  if T.state.running then
    T.state.current = (tonumber(T.state.current or 0) or 0) + (tonumber(T.config.increment) or 0.25)
    local avg = tonumber(T.state.average or T.config.average) or 40
    if T.state.current > avg + 5 then
      T.state.running = false
      T.state.source = "expired"
    end
  end

  T.publish("timer")
  safeRaise("MyDSL.Timers.Pulse")
end

function T.loop()
  if T.looping then return end
  T.looping = true
  local function step()
    T.looping = false
    T.updateTimer()
    tempTimer(tonumber(T.config.increment) or 0.25, function() T.loop() end)
  end
  step()
end

function T.reset()
  T.state.running = false
  T.state.ticks = 0
  T.state.current = 0
  T.state.average = tonumber(T.config.average) or 40
  T.state.remaining = nil
  T.state.percent = 0
  T.state.source = "reset"
  T.state.lastMeasured = nil
  T.state.lastTickAt = nil
  T.publish("reset")
  ce("reset average=" .. tostring(T.state.average))
end

function T.setAverage(v)
  v = tonumber(v)
  if not v or v < 10 or v > 120 then ce("usage: mydsl tick average <10-120>"); return end
  T.config.average = v
  if not T.state.running then T.state.average = v end
  T.publish("average")
  ce("average set to " .. tostring(v) .. "s")
end

function T.setWindow(v)
  v = tonumber(v)
  if not v or v < 1 or v > 30 then ce("usage: mydsl tick window <1-30>"); return end
  T.config.window = v
  T.publish("window")
  ce("window set to " .. tostring(v) .. "s")
end

function T.setDebug(mode)
  mode = tostring(mode or ""):lower()
  if mode == "on" then T.debug = true
  elseif mode == "off" then T.debug = false
  else ce("usage: mydsl tick debug on|off"); return end
  ce("debug=" .. tostring(T.debug))
end

function T.status()
  local d = MyDSL and MyDSL.DB and MyDSL.DB.tick or {}
  ce("version=" .. T.version ..
     "; running=" .. tostring(d.running) ..
     "; ticks=" .. tostring(d.ticks) ..
     "; remaining=" .. string.format("%.1f", tonumber(d.remaining or 0) or 0) ..
     "; average=" .. string.format("%.1f", tonumber(d.average or T.config.average) or T.config.average) ..
     "; configured=" .. tostring(T.config.average) ..
     "; window=" .. tostring(T.config.window) ..
     "; percent=" .. string.format("%.2f", tonumber(d.percent or 0) or 0) ..
     "; source=" .. tostring(d.source or "none") ..
     "; lastMeasured=" .. tostring(d.lastMeasured))
end

function T.installHandlers()
  if T.handlersInstalled then return end
  T.handlersInstalled = true
  T.handlers = T.handlers or {}
  local events = { "gmcp.tick", "gmcp.Tick", "onTick" }
  for _, ev in ipairs(events) do
    local ok, id = pcall(function()
      return registerAnonymousEventHandler(ev, function() T.onGameTick() end)
    end)
    if ok and id then table.insert(T.handlers, id) end
  end
end

function T.installAliases()
  if T.aliasesInstalled then return end
  tempAlias([[^mydsl tick status$]], [[MyDSL.TickSource.status()]])
  tempAlias([[^mydsl tick reset$]], [[MyDSL.TickSource.reset()]])
  tempAlias([[^mydsl tick average (\d+)$]], [[MyDSL.TickSource.setAverage(matches[2])]])
  tempAlias([[^mydsl tick window (\d+)$]], [[MyDSL.TickSource.setWindow(matches[2])]])
  tempAlias([[^mydsl tick debug (on|off)$]], [[MyDSL.TickSource.setDebug(matches[2])]])
  T.aliasesInstalled = true
end

function T.boot()
  ensureDB()
  T.installAliases()
  T.installHandlers()
  T.publish("boot")
  T.loop()
  if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then ce("loaded " .. T.version .. " average=" .. tostring(T.config.average) .. " window=" .. tostring(T.config.window)) end
end

T.boot()
