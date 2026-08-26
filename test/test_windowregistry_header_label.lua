-- MyDSL 1.0 visual pass v2 -- "Direction A+, Quiet Chrome, Cross-
-- Platform" -- locked spec confirmed by Steven 2026-08-26 (HANDOFF.md).
-- Confirms MyDSL.Windows.ensureHeader()/applyHeaderTheme() -- the
-- shared mechanism centralizing header-Label creation for every
-- UserWindow, instead of hand-building it 15 separate times per View
-- file, per Claude Desktop's own research on the honest cost of this
-- direction.
--
-- Run: luajit test/test_windowregistry_header_label.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local setStyleSheetCalls = {}
local echoCalls = {}
local titleSetCalls = {}
_G.Geyser.Label.setStyleSheet = function(self, css) setStyleSheetCalls[self.name] = css; return true end
_G.Geyser.Label.echo = function(self, text) echoCalls[self.name] = text; return true end
_G.Geyser.UserWindow.setTitle = function(self, text) titleSetCalls[self.name] = text; return true end

MyDSL = MyDSL or {}
MyDSL.Layout = { get = function() return nil end }
dofile("MyDSL_ThemeEngine.lua")
dofile("MyDSL_WindowRegistry.lua")

local winObj = MyDSL.Windows.ensure("MyDSL_Chat")
check("ensure() created the window first", winObj ~= nil)

local header = MyDSL.Windows.ensureHeader("MyDSL_Chat", "Chat")
check("ensureHeader() returns a real Label object", header ~= nil)
check("ensureHeader() styled the header via MyDSL.Theme.headerLabelCSS()",
  setStyleSheetCalls["MyDSL_Chat_Header"] ~= nil
  and setStyleSheetCalls["MyDSL_Chat_Header"]:find("font%-size: 10%.5px") ~= nil)
check("ensureHeader() echoed exactly the window-name text, no prefix",
  echoCalls["MyDSL_Chat_Header"] == "Chat")
check("ensureHeader() blanks the native title text (redundant once the header exists)",
  titleSetCalls["MyDSL_Chat"] == "")

-- ---- Idempotent: calling again updates text/style, doesn't rebuild -------

local header2 = MyDSL.Windows.ensureHeader("MyDSL_Chat", "Chat (renamed)")
check("calling ensureHeader() again returns the SAME Label object",
  header2 == header)
check("calling ensureHeader() again updates the echoed text",
  echoCalls["MyDSL_Chat_Header"] == "Chat (renamed)")

-- ---- Theme switch re-styles the header, same lifecycle as applyTheme ------

setStyleSheetCalls["MyDSL_Chat_Header"] = nil
MyDSL.Theme.setTheme("obsidian_ember")
MyDSL.Windows.ensure("MyDSL_Chat") -- already created -- exercises the early-return path, not a rebuild
-- setTheme() itself doesn't re-apply CSS (matches the existing panelCSS
-- lifecycle, which relies on something calling applyTheme() again) --
-- confirm the mechanism is wired to the SAME call site panelCSS uses by
-- invoking ensureHeader() again, the real re-style trigger a "theme
-- changed" handler would use.
MyDSL.Windows.ensureHeader("MyDSL_Chat", "Chat")
check("re-styling after a theme switch picks up the new preset's colors",
  setStyleSheetCalls["MyDSL_Chat_Header"] ~= nil
  and setStyleSheetCalls["MyDSL_Chat_Header"]:find("rgba%(230,126,60", 1, false) ~= nil)

-- ---- A window with no header never gets one, no error either -------------

local noHeader = MyDSL.Windows.ensureHeader("MyDSL_NoSuchWindow", "Nope")
check("ensureHeader() on an unknown window name is a safe no-op",
  noHeader == nil)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
