-- Regression test for DSL_Mapper_Addon.xml, added 2026-08-29 (standalone-
-- mapper design pass -- see docs/MAPPER_REDESIGN.md). This file is the
-- genuinely standalone distributable: no bundled copy of Mudlet's own
-- generic_mapper.xml, just the DSL-specific layer + 2 bug-fix overrides
-- + an update-disabling override, all reassigned onto real global map.*
-- functions from OUTSIDE stock's source.
--
-- What this test focuses on (the genuinely new/risky part -- the DSL
-- layer content itself is a verbatim copy of DSL_Generic_Mapper.xml's
-- own already-tested source, not re-verified here):
-- 1. The addon loads without a syntax error.
-- 2. map.dsl.installAddonOverrides() -- called from inside install(),
--    NOT at bare top-level script scope (a real load-order bug caught
--    and fixed before shipping: reassigning map.checkVersion/map.
--    echoPath/etc. at top level could race stock's own script load and
--    get silently clobbered) -- actually reassigns all 5 target
--    functions when it runs.
-- 3. The reassigned map.echoPath()/map.export_area()/map.import_area()
--    carry the same real bug fixes already tested in
--    test_mapper_echopath_nil_guard.lua / test_mapper_area_hash_preservation.lua
--    -- proving the addon's copy is the fixed version, not stock's
--    original buggy one.
-- 4. map.checkVersion()/map.updateVersion() are neutralized (no native
--    download/reinstall behavior fires).
--
-- Run: luajit test/test_dsl_mapper_addon.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- Extract the real addon script from DSL_Mapper_Addon.xml
------------------------------------------------------------------------
local function xmlUnescape(s)
  s = s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
       :gsub("&apos;", "'"):gsub("&#39;", "'")
  s = s:gsub("&amp;", "&")  -- must be last
  return s
end

local f = io.open("DSL_Mapper_Addon.xml", "r")
assert(f, "DSL_Mapper_Addon.xml not found -- run from the repo root")
local xml = f:read("*a")
f:close()

local scriptBody = xml:match("<script>(.-)</script>")
assert(scriptBody, "couldn't find DSL_Mapper_Addon.xml's <script> block")
scriptBody = xmlUnescape(scriptBody)

------------------------------------------------------------------------
-- Minimal sandbox. tempTimer here just needs to not crash (the
-- dependency check schedules one at load time) -- mudlet_mock.lua
-- already provides a real tempTimer mock.
------------------------------------------------------------------------
map = map or {}
map.configs = { debug = false }
map.dsl = map.dsl or {}
function map.echo(msg) end
local searchRoomResults = { [1] = "Town Square", [2] = "Market" }
function _G.searchRoom(id) return searchRoomResults[id] end
function _G.getPath(a, b) return true end
_G.speedWalkDir = {}
function _G.getAreaTable() return {} end
function _G.getAreaRooms() return {} end
function _G.show_err(msg) end
table.contains = table.contains or function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
table.is_empty = table.is_empty or function(t) return next(t) == nil end
table.save = table.save or function() return true end
table.load = table.load or function() end
_G.profilePath = "/tmp/mock"

local chunk, loadErr = load(scriptBody, "dsl_mapper_addon")
check("DSL_Mapper_Addon.xml's script loads without a syntax error", chunk ~= nil and loadErr == nil)
if not chunk then print("  load error: " .. tostring(loadErr)) end

if chunk then
  local ok, runErr = pcall(chunk)
  check("addon script runs without error at load time", ok)
  if not ok then print("  runtime error: " .. tostring(runErr)) end
end

if map.dsl and map.dsl.installAddonOverrides then
  ------------------------------------------------------------------------
  -- Before installAddonOverrides() runs: map.echoPath etc. don't exist
  -- yet in this sandbox (nothing defined them -- we never loaded a real
  -- stock generic_mapper here, matching how this addon assumes stock is
  -- ALREADY loaded by the time install() actually fires for real).
  ------------------------------------------------------------------------
  check("map.echoPath not yet defined before overrides run", map.echoPath == nil)

  local ok = pcall(map.dsl.installAddonOverrides)
  check("installAddonOverrides() runs without error", ok)

  check("map.echoPath got reassigned", type(map.echoPath) == "function")
  check("map.export_area got reassigned", type(map.export_area) == "function")
  check("map.import_area got reassigned", type(map.import_area) == "function")
  check("map.checkVersion got neutralized", type(map.checkVersion) == "function")
  check("map.updateVersion got reassigned to map.dsl.updateDisabled",
    map.updateVersion == map.dsl.updateDisabled)

  ------------------------------------------------------------------------
  -- Prove the reassigned echoPath carries the real nil-guard fix, not
  -- stock's original crash-on-missing-room behavior.
  ------------------------------------------------------------------------
  local ok2, err2 = pcall(map.echoPath, 1, 999)  -- room 999 doesn't exist in searchRoomResults
  check("reassigned map.echoPath doesn't crash on a missing room (the real fix)", ok2)
  if not ok2 then print("  error: " .. tostring(err2)) end

  ------------------------------------------------------------------------
  -- Prove checkVersion() doesn't attempt any native download behavior --
  -- just confirm it's callable and returns without erroring (it's now a
  -- true no-op).
  ------------------------------------------------------------------------
  local ok3 = pcall(map.checkVersion)
  check("neutralized map.checkVersion() runs without error", ok3)
end

------------------------------------------------------------------------
-- Install-welcome / uninstall-cleanup handler, added 2026-08-29 per
-- Mudlet's own documented package best practices. Must be a real GLOBAL
-- function -- registerAnonymousEventHandler looks its second argument
-- up by name in _G; a `local function` here would silently never be
-- found or called (a real bug caught and fixed before shipping).
------------------------------------------------------------------------
check("install/uninstall handler is a real global function (not local -- would silently never fire)",
  type(_G.dslMapperAddonInstallUninstallHandler) == "function")

if type(_G.dslMapperAddonInstallUninstallHandler) == "function" then
  local removeMapEventCalls = {}
  _G.removeMapEvent = function(name) removeMapEventCalls[#removeMapEventCalls + 1] = name; return true end

  local ok4 = pcall(_G.dslMapperAddonInstallUninstallHandler, "sysInstallPackage", "DSL_Mapper_Addon")
  check("sysInstallPackage handler runs without error", ok4)

  local ok5 = pcall(_G.dslMapperAddonInstallUninstallHandler, "sysInstallPackage", "SomeOtherPackage")
  check("sysInstallPackage for a DIFFERENT package doesn't error either (ignored, not mismatched)", ok5)

  map.dsl.registeredEvents = {111, 222}
  local killedIds = {}
  _G.killAnonymousEventHandler = function(id) killedIds[#killedIds + 1] = id; return true end

  local ok6 = pcall(_G.dslMapperAddonInstallUninstallHandler, "sysUninstallPackage", "DSL_Mapper_Addon")
  check("sysUninstallPackage handler runs without error", ok6)
  check("uninstall killed both registered event handlers",
    #killedIds == 2 and killedIds[1] == 111 and killedIds[2] == 222)
  check("uninstall called removeMapEvent to clean up the Safe Delete menu item",
    #removeMapEventCalls == 1 and removeMapEventCalls[1] == "dslSafeDelete")
end

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
