-- Real bug found live 2026-08-26 (visual pass v2, 4th round): History's
-- and PlayersNear's real short titles ("History", "Players Near") never
-- got set at all this whole session, because getOrCreateConsole() (the
-- only place that calls setTitle()) only ever ran lazily, the first
-- time MyDSL.Route.to()/getConsole() actually routed real text there --
-- both windows sat empty ("no data") for Steven's whole test session,
-- so both showed Mudlet's raw default title ("User window - MyDSL -
-- MyDSL_History") the entire time, never the real short name from this
-- pass. Every other View file sets its title unconditionally at
-- load/ensureUI() time; these two were the only ones that didn't.
--
-- Run: luajit test/test_routehelper_eager_title.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local titleSetCalls = {}
_G.Geyser.UserWindow.setTitle = function(self, text)
  titleSetCalls[self.name] = text
  return true
end

MyDSL = MyDSL or {}
MyDSL.Layout = { get = function() return nil end }
dofile("MyDSL_ThemeEngine.lua")
dofile("MyDSL_WindowRegistry.lua")
dofile("MyDSL_RouteHelper.lua")

-- No MyDSL.Route.to()/getConsole() call happened above -- exactly the
-- "window sits empty all session" scenario that exposed the bug live.
check("History's real title is already set at load time, with no content ever routed",
  titleSetCalls["MyDSL_History"] == "History")
check("Players Near's real title is already set at load time, with no content ever routed",
  titleSetCalls["MyDSL_PlayersNear"] == "Players Near")

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
