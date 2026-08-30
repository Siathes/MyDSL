-- Structural test coverage for MyDSL_ThemeEngine.lua's custom-preset
-- commands (theme new/edit/delete/preview), added 2026-08-25 per
-- Steven ("i wan to be able to customize the theme in the ui not the
-- website"). Closes both a real feature gap (Section 6's own header
-- comment has said "Themes are user-creatable named presets" since
-- 2026-07-11, but no mechanism to actually create one ever existed)
-- and zero prior test coverage for MyDSL_ThemeEngine.lua at all.
--
-- Run: luajit test/test_theme_customization.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_ThemeEngine.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local function resetTheme()
  MyDSL.Theme.presets["my_custom"] = nil
  MyDSL.Theme.customPresets = {}
  for i = #MyDSL.Theme.presetOrder, 1, -1 do
    if not table.contains({ "refined_convergence", "terminal_purist", "zoned_hud", "obsidian_ember", "arcane_midnight", "tron_blue", "muted_scroll_nature" }, MyDSL.Theme.presetOrder[i]) then
      table.remove(MyDSL.Theme.presetOrder, i)
    end
  end
  MyDSL.Theme.active = "refined_convergence"
end

------------------------------------------------------------------------
-- theme new / newCustom()
------------------------------------------------------------------------
resetTheme()
local ok1, err1 = MyDSL.Theme.newCustom("my_custom")
check("newCustom() succeeds with a fresh name", ok1 == true)
check("newCustom() switches active to the new theme", MyDSL.Theme.active == "my_custom")
check("newCustom() registers the theme in presets", MyDSL.Theme.presets["my_custom"] ~= nil)
check("newCustom() registers the theme in customPresets", MyDSL.Theme.customPresets["my_custom"] ~= nil)
check("newCustom() adds the name to presetOrder", table.contains(MyDSL.Theme.presetOrder, "my_custom"))
check("newCustom() clone has every real preset key (not a half-empty table)",
  MyDSL.Theme.presets["my_custom"].bgColor ~= nil and MyDSL.Theme.presets["my_custom"].titleColor ~= nil
    and MyDSL.Theme.presets["my_custom"].font ~= nil)
-- Cloned from refined_convergence (the active theme before newCustom() ran) -- confirm real values carried over, not defaults.
check("newCustom() clone matches the base theme's real titleColor, not a guess",
  MyDSL.Theme.presets["my_custom"].titleColor.r == 255 and MyDSL.Theme.presets["my_custom"].titleColor.g == 209)

local ok2, err2 = MyDSL.Theme.newCustom("my_custom")
check("newCustom() refuses a colliding name", ok2 == false)
check("newCustom() collision error mentions the name", err2 and err2:find("my_custom", 1, true) ~= nil)

local ok3, err3 = MyDSL.Theme.newCustom("refined_convergence")
check("newCustom() refuses to collide with a built-in name", ok3 == false)

local ok4, err4 = MyDSL.Theme.newCustom("")
check("newCustom() refuses an empty name", ok4 == false)

------------------------------------------------------------------------
-- theme edit / setCustomKey()
------------------------------------------------------------------------
resetTheme()
MyDSL.Theme.newCustom("my_custom")
local okEdit1, errEdit1 = MyDSL.Theme.setCustomKey("titleColor", { r = 10, g = 20, b = 30, a = 255 })
check("setCustomKey() succeeds on the active custom theme", okEdit1 == true)
check("setCustomKey() actually changes the value",
  MyDSL.Theme.presets["my_custom"].titleColor.r == 10 and MyDSL.Theme.presets["my_custom"].titleColor.g == 20)
check("setCustomKey()'s change is visible through get()",
  MyDSL.Theme.get("SomeWindow", "titleColor").r == 10)

resetTheme() -- active is back to the built-in refined_convergence
local okEdit2, errEdit2 = MyDSL.Theme.setCustomKey("titleColor", { r = 1, g = 2, b = 3, a = 255 })
check("setCustomKey() refuses to edit a built-in theme", okEdit2 == false)
check("setCustomKey() built-in-refusal error suggests 'theme new'", errEdit2 and errEdit2:find("theme new", 1, true) ~= nil)
check("setCustomKey() refusing a built-in leaves its real value untouched",
  MyDSL.Theme.presets["refined_convergence"].titleColor.r == 255)

resetTheme()
MyDSL.Theme.newCustom("my_custom")
local okEdit3, errEdit3 = MyDSL.Theme.setCustomKey("not_a_real_key", "whatever")
check("setCustomKey() refuses an unknown key", okEdit3 == false)

------------------------------------------------------------------------
-- theme delete / deleteCustom()
------------------------------------------------------------------------
resetTheme()
local okDel1, errDel1 = MyDSL.Theme.deleteCustom("refined_convergence")
check("deleteCustom() refuses to delete a built-in", okDel1 == false)
check("deleteCustom() built-in still exists after a refused delete", MyDSL.Theme.presets["refined_convergence"] ~= nil)

resetTheme()
MyDSL.Theme.newCustom("my_custom")
local okDel2 = MyDSL.Theme.deleteCustom("my_custom")
check("deleteCustom() succeeds on a real custom theme", okDel2 == true)
check("deleteCustom() removes it from presets", MyDSL.Theme.presets["my_custom"] == nil)
check("deleteCustom() removes it from customPresets", MyDSL.Theme.customPresets["my_custom"] == nil)
check("deleteCustom() removes it from presetOrder", not table.contains(MyDSL.Theme.presetOrder, "my_custom"))
check("deleteCustom() falls back to refined_convergence when the deleted theme was active",
  MyDSL.Theme.active == "refined_convergence")

resetTheme()
MyDSL.Theme.newCustom("my_custom")
MyDSL.Theme.setTheme("refined_convergence")  -- switch away before deleting, confirm active is untouched
local okDel3 = MyDSL.Theme.deleteCustom("my_custom")
check("deleteCustom() on a non-active custom theme leaves the real active theme alone",
  okDel3 == true and MyDSL.Theme.active == "refined_convergence")

------------------------------------------------------------------------
-- theme preview / previewText()
------------------------------------------------------------------------
resetTheme()
local previewDefault = MyDSL.Theme.previewText()
check("previewText() with no args returns real swatch lines for the active theme",
  previewDefault ~= nil and previewDefault:find("titleColor", 1, true) ~= nil)
check("previewText() embeds the real RGB numbers, not placeholders",
  previewDefault:find("255,209,102", 1, true) ~= nil)

local previewNamed, previewErr = MyDSL.Theme.previewText("terminal_purist")
check("previewText() works for an explicitly named built-in theme", previewNamed ~= nil)

local previewBad, previewBadErr = MyDSL.Theme.previewText("not_a_real_theme")
check("previewText() errors on an unknown theme name instead of crashing", previewBad == nil and previewBadErr ~= nil)

------------------------------------------------------------------------
-- Real regression: loadActive()'s custom-presets-before-active-check
-- ordering fix. Before this fix, a saved `active` pointing at a custom
-- theme would fail the MyDSL.Theme.presets[loaded.active] check (custom
-- presets hadn't been merged in yet) and silently revert to the
-- hardcoded default on every reload -- exactly the kind of load-order
-- bug this project has hit before (see MyDSL_Leveling.lua's own
-- load-order race, docs/CHANGELOG.md 2026-07-21).
------------------------------------------------------------------------
resetTheme()
local savedCustomPreset = {
  font = "Consolas", fontSize = 9, titleFont = "Consolas", titleFontSize = 9,
  bgColor = { r = 1, g = 2, b = 3, a = 255 }, textColor = { r = 4, g = 5, b = 6, a = 255 },
  borderColor = { r = 7, g = 8, b = 9, a = 255 }, borderSize = 1, radius = 0,
  titleColor = { r = 10, g = 11, b = 12, a = 255 }, titleBgColor = { r = 0, g = 0, b = 0, a = 0 },
  highlightColor = { r = 13, g = 14, b = 15, a = 255 }, dimColor = { r = 16, g = 17, b = 18, a = 255 },
  warnColor = { r = 19, g = 20, b = 21, a = 255 }, goodColor = { r = 22, g = 23, b = 24, a = 255 },
}
-- loadActive() checks io.open() first (real file-existence guard) before
-- ever calling table.load() -- no settings file exists on disk in this
-- test environment, so io.open must be stubbed too or the function
-- returns before table.load() is ever reached.
local realOpen, realLoad = io.open, table.load
io.open = function(path, mode) return { close = function() end } end
table.load = function(path, target)
  target.active = "reloaded_custom"
  target.overrides = {}
  target.customPresets = { reloaded_custom = savedCustomPreset }
  return nil -- real Mudlet table.load() has no return value -- confirmed project-wide convention
end
MyDSL.Theme.loadActive()
io.open, table.load = realOpen, realLoad

check("loadActive() merges a saved custom preset into presets", MyDSL.Theme.presets["reloaded_custom"] ~= nil)
check("loadActive() restores a saved active theme that is itself a custom one (the real ordering bug)",
  MyDSL.Theme.active == "reloaded_custom")
check("loadActive() adds the restored custom theme to presetOrder", table.contains(MyDSL.Theme.presetOrder, "reloaded_custom"))

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
