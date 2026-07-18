-- =============================================================================
-- MyDSL_Help.lua  --  Layer 3: In-UI help system
-- =============================================================================
-- Per Steven's ask (2026-07-15): a 3-level help system for DSL2 itself (the
-- observer UI, not DSL's own game helpfiles -- those are separate, already
-- vendored in DSL_Helpfiles/).
--   1. Main console (MyDSL.help(), "mydsl help"): title + one-liner per
--      module, terse, each a clickable link.
--   2. Clicking opens the MyDSL_Help UserWindow to that module's own detail
--      page directly (skips the overview) -- matches "clickable links to
--      the actual help." A "Browse all modules" link at the top instead
--      opens the window to the overview/breadth page.
--   3. Overview page: every module, grouped by category, one-liner each,
--      still clickable -- the "breadth" Steven asked for.
--   4. Module detail page: full command list + examples, the most verbose
--      level -- reached by clicking a module from either the main console
--      or the overview page.
-- Replaces the old MyDSL.help() (a flat, hand-maintained echo() dump that
-- used to live in MyDSL_DataLayer.lua -- removed from there, no duplicate).
--
-- Navigation uses dechoLink(text, luaCode, hint, useCurrentFormat) --
-- confirmed via MyDSL_PromptSetup.lua/MyDSL_GroupView.lua that the 2nd arg
-- is a Lua expression executed directly on click, NOT a typed game/alias
-- command -- so no per-module alias is needed for navigation, just direct
-- calls into MyDSL.Help.open()/render()/renderOverview(). The 4th arg is
-- useCurrentFormat, not "underline" -- always pass true or the decho color
-- codes get discarded (same bug already found/fixed in GroupView/TargetView).
--
-- Colors: light-yellow body text (Steven's ask, no existing tag for this --
-- introduced here), reusing the link-blue and gold-accent tags already
-- established in MyDSL_PromptSetup.lua rather than inventing new meanings.
-- =============================================================================

MyDSL      = MyDSL      or {}
MyDSL.Help = MyDSL.Help or {}

-- Safe-reload: kill old handlers/aliases before re-registering.
for _, id in pairs(MyDSL.Help._handlers or {}) do pcall(killAnonymousEventHandler, id) end
MyDSL.Help._handlers = {}
MyDSL.Help._mc       = MyDSL.Help._mc or {}   -- persists to avoid duplicate MiniConsole creation

local HELP_WIN = "MyDSL_Help"
local HELP_MC  = "MyDSL_Help_MC"

------------------------------------------------------------------------
-- Colors
------------------------------------------------------------------------
local COLOR_BODY   = "255,255,153"  -- light yellow -- summaries/descriptions
local COLOR_LINK   = "136,204,255"  -- clickable links (established in MyDSL_PromptSetup.lua)
local COLOR_ACCENT = "255,204,68"   -- gold -- category headers + command syntax (established in MyDSL_PromptSetup.lua)


------------------------------------------------------------------------
-- Content table -- one entry per user-facing module. Hand-maintained,
-- same as the FLAG_COLOR table in MyDSL_DataLayer.lua or the old flat
-- help dump this replaces -- not derived at runtime from the live alias
-- tree, so keep this in sync by hand when a module gains/loses a command.
------------------------------------------------------------------------

MyDSL.Help.modules = {

  -- ---- Vitals & Combat ----
  { key = "combat", title = "Combat", category = "Vitals & Combat", window = "MyDSL_Combat",
    summary = "Live per-swing damage feed plus a fight summary on death/flee/rescue.",
    commands = {
      { cmd = "toggle battle", desc = "Show/hide the Combat window.", example = "toggle battle" },
      { cmd = "mydsl combat mode <raw|condensed|gag>", desc = "Switch main-console combat verbosity in one step.", example = "mydsl combat mode condensed" },
      { cmd = "mydsl combat gag / mydsl combat ungag", desc = "Suppress/restore combat text on the main console.", example = "mydsl combat gag" },
      { cmd = "mydsl combat show <flag> / mydsl combat hide <flag>", desc = "Toggle one display flag (e.g. damage, miss).", example = "mydsl combat hide miss" },
      { cmd = "mydsl combat clear", desc = "Wipe current combat state/history.", example = "mydsl combat clear" },
      { cmd = "mydsl combat history", desc = "Reprint stored fight-summary snapshots.", example = "mydsl combat history" },
      { cmd = "mydsl combat font <n>", desc = "Set the window's font size.", example = "mydsl combat font 9" },
    },
  },
  { key = "live", title = "Live", category = "Vitals & Combat", window = "MyDSL_Live",
    summary = "Always-visible low-profile bar: vitals, room, score, XP, timers.",
    commands = {
      { cmd = "mydsl live show / mydsl live hide", desc = "Show/hide the bar.", example = "mydsl live show" },
      { cmd = "mydsl live status", desc = "Report current config/state.", example = "mydsl live status" },
      { cmd = "mydsl live rebuild", desc = "Recreate the window from scratch.", example = "mydsl live rebuild" },
      { cmd = "mydsl live refresh", desc = "Force a redraw.", example = "mydsl live refresh" },
      { cmd = "mydsl live save / mydsl live reload settings", desc = "Persist or reload settings from disk.", example = "mydsl live save" },
      { cmd = "mydsl live font|titlefont|barfont|infofont|terrainfont <n>", desc = "Resize a specific text element.", example = "mydsl live barfont 9" },
      { cmd = "mydsl live title <text>", desc = "Set the window's title text.", example = "mydsl live title MyCharacter" },
      { cmd = "mydsl live layout", desc = "Cycle/report the bar's layout mode.", example = "mydsl live layout" },
    },
  },
  { key = "tick", title = "Tick", category = "Vitals & Combat", window = "MyDSL_Tick",
    summary = "Countdown window for the game's tick timer, animated and smoothed.",
    commands = {
      { cmd = "toggle ticktimer", desc = "Show/hide the Tick window.", example = "toggle ticktimer" },
      { cmd = "mydsl tickview status / save / reload settings / show / hide / rebuild", desc = "Standard window controls.", example = "mydsl tickview show" },
      { cmd = "mydsl tickview font <n>", desc = "Set the window's font size.", example = "mydsl tickview font 9" },
      { cmd = "mydsl tickview mode <compact|full>", desc = "Switch the window's layout.", example = "mydsl tickview mode compact" },
      { cmd = "mydsl tickview title <text>", desc = "Set the window's title text.", example = "mydsl tickview title Tick" },
      { cmd = "mydsl tick status", desc = "Report the tick-averaging engine's current state.", example = "mydsl tick status" },
      { cmd = "mydsl tick reset", desc = "Reset the tick-length average.", example = "mydsl tick reset" },
      { cmd = "mydsl tick average <n>", desc = "Force the tick-length average to a specific value.", example = "mydsl tick average 40" },
      { cmd = "mydsl tick window <n>", desc = "Set how many recent ticks feed the smoothed average.", example = "mydsl tick window 5" },
      { cmd = "mydsl tick debug <on|off>", desc = "Toggle tick-timing diagnostic output.", example = "mydsl tick debug on" },
    },
  },
  { key = "alterform", title = "Alterform", category = "Vitals & Combat", window = "MyDSL_Alterform",
    summary = "Countdown timer for the alterform (shapeshift) affect, paired with Tick.",
    commands = {
      { cmd = "toggle alterform", desc = "Show/hide the Alterform window.", example = "toggle alterform" },
      { cmd = "mydsl alterform status / save / reload settings / show / hide / rebuild", desc = "Standard window controls.", example = "mydsl alterform show" },
      { cmd = "mydsl alterform font <n>", desc = "Set the window's font size.", example = "mydsl alterform font 9" },
      { cmd = "mydsl alterform title <text>", desc = "Set the window's title text.", example = "mydsl alterform title Alterform" },
    },
  },
  { key = "affects", title = "Affects", category = "Vitals & Combat", window = "MyDSL_Affects",
    summary = "Tracks your active spells/songs (GMCP-first) with recast helpers; never auto-recasts.",
    commands = {
      { cmd = "toggle affects", desc = "Show/hide the Affects window.", example = "toggle affects" },
      { cmd = "mydsl affects status / show / hide / clear", desc = "Standard window controls.", example = "mydsl affects show" },
      { cmd = "mydsl affects profile / reload profile", desc = "Show or reload this character's saved affects profile.", example = "mydsl affects reload profile" },
      { cmd = "mydsl affects save / sync / refresh", desc = "Persist settings, resync from GMCP, or force a redraw.", example = "mydsl affects sync" },
      { cmd = "mydsl affects title <text> / font <n> / wrap <n> / columns <n> / width <n>", desc = "Display tuning.", example = "mydsl affects font 8" },
      { cmd = "mydsl affects cast <name> / mydsl affects recast <name>", desc = "Manually (re)cast a tracked spell's configured command.", example = "mydsl affects recast bless" },
      { cmd = "respell [name]", desc = "Recast everything on your tracked list that's missing or expired (also: mydsl affects respell).", example = "respell" },
      { cmd = "spellup [args]", desc = "Start the automated spellup loop for your tracked items (also: mydsl affects spellup).", example = "spellup" },
      { cmd = "mydsl affects command <name> <cast-cmd> / command clear <name>", desc = "Set/clear a custom cast command for one spell.", example = "mydsl affects command bless \"cast 'bless' %t\"" },
      { cmd = "mydsl affects timer mode / mode <cycles|time|both>", desc = "Switch how remaining duration is displayed.", example = "mydsl affects mode time" },
      { cmd = "mydsl affects track <name> / untrack <name> / tracked / reset tracked / clear tracked / seed tracked", desc = "Manage the tracked-spells list.", example = "mydsl affects track bless" },
      { cmd = "affdebug / affsync / affrefresh", desc = "Shorthand diagnostic aliases.", example = "affrefresh" },
    },
  },
  { key = "charassist", title = "Character Assist", category = "Vitals & Combat", window = nil,
    summary = "Interactive assist: auto-rearm on disarm, auto-standup on knockdown, spellup automation.",
    commands = {
      { cmd = "rearm", desc = "Manually re-equip your weapon after a disarm.", example = "rearm" },
      { cmd = "setspell <ability> <verb> [args]", desc = "Configure a spell's cast command/target syntax.", example = "setspell bless cast bless" },
      { cmd = "bless <target> / fireproof <target>", desc = "Start the automated spellup loop for that item.", example = "bless all" },
      { cmd = "stop spellup", desc = "Abort the running spellup loop.", example = "stop spellup" },
      { cmd = "resume spellup", desc = "Resume a paused spellup loop.", example = "resume spellup" },
      { cmd = "ignore <bless|fireproof> <item>", desc = "Skip one item during spellup.", example = "ignore bless shield" },
    },
  },
  { key = "roller", title = "Roller", category = "Vitals & Combat", window = nil,
    summary = "Character-creation helper: watches stat rolls, auto-rejects rolls below a goal.",
    commands = {
      { cmd = "set goal <n>", desc = "Set the target stat total (default 241).", example = "set goal 250" },
      { cmd = "roll stats", desc = "Print min/max/avg/stdev across every roll seen this session.", example = "roll stats" },
      { cmd = "reset roll", desc = "Clear roll statistics.", example = "reset roll" },
    },
  },

  -- ---- Targeting & Group ----
  { key = "focus", title = "Focus", category = "Targeting & Group", window = "MyDSL_Focus",
    summary = "Shows your current target with 6 configurable one-click action buttons; buttons only fire on click.",
    commands = {
      { cmd = "focus <name>", desc = "Set the current target.", example = "focus a goblin" },
      { cmd = "focus clear", desc = "Clear the current target.", example = "focus clear" },
      { cmd = "focus mobset <a1> <a2> <a3> <a4> <a5> <a6>", desc = "Reassign the 6 mob quick-action buttons.", example = "focus mobset murder consider creaturelore rescue flee getitem" },
      { cmd = "focus playerset <a1> <a2> <a3> <a4> <a5> <a6>", desc = "Reassign the 6 player quick-action buttons.", example = "focus playerset group tell consider rescue follow examine" },
      { cmd = "focus mobset reset / focus playerset reset", desc = "Reset buttons to defaults.", example = "focus mobset reset" },
      { cmd = "focus action <name> \"<label>\" <r,g,b> <command>", desc = "Define a custom action (%t substitutes the target's name).", example = "focus action getitem \"Get Item\" 204,204,204 get %t" },
      { cmd = "focus status", desc = "Report the window's current size.", example = "focus status" },
      { cmd = "focus font <n>", desc = "Set the window's font size.", example = "focus font 9" },
    },
  },
  { key = "group", title = "Group", category = "Targeting & Group", window = "MyDSL_Group",
    summary = "Passive display of current group members (class, name, HP/mana/mv); never sends commands.",
    commands = {
      { cmd = "group gag / group ungag", desc = "Suppress/restore raw group-report text on the main console.", example = "group gag" },
      { cmd = "group quickset <a1> <a2>", desc = "Set the 2 group-panel quick-action buttons.", example = "group quickset heal rescue" },
      { cmd = "group quickset reset", desc = "Reset quick buttons to defaults (heal, rescue).", example = "group quickset reset" },
      { cmd = "group status / group show / group hide / group rebuild", desc = "Standard window controls.", example = "group show" },
      { cmd = "group font <n>", desc = "Set the window's font size.", example = "group font 8" },
    },
  },
  { key = "scan", title = "Scan", category = "Targeting & Group", window = "MyDSL_Scan",
    summary = "Passive display of nearby entities from the `scan` command; never sends commands.",
    commands = {
      { cmd = "scan gag / scan ungag", desc = "Suppress/restore raw scan text on the main console.", example = "scan gag" },
      { cmd = "mydsl scan status / show / hide / rebuild", desc = "Standard window controls.", example = "mydsl scan show" },
      { cmd = "mydsl scan font <n>", desc = "Set the window's font size.", example = "mydsl scan font 9" },
    },
  },
  { key = "righthere", title = "Right Here", category = "Targeting & Group", window = "MyDSL_RightHere",
    summary = "Passive display of entities in your current room (from `look`/`scan`), clickable to set target.",
    commands = {
      { cmd = "mydsl righthere dump", desc = "Diagnostic: dump the raw RightHere state table to the main console.", example = "mydsl righthere dump" },
      { cmd = "mydsl righthere status / show / hide / rebuild", desc = "Standard window controls.", example = "mydsl righthere show" },
      { cmd = "mydsl righthere font <n>", desc = "Set the window's font size.", example = "mydsl righthere font 9" },
    },
  },
  { key = "bestiary", title = "Bestiary", category = "Targeting & Group", window = "MyDSL_CreatureReference",
    summary = "Displays a stored creature-lore record; shared across characters, auto-shows on new lore.",
    commands = {
      { cmd = "bestiary <name>", desc = "Look up a creature (sends `creaturelore <name>`) and show the window.", example = "bestiary orc" },
      { cmd = "bestiary show / bestiary hide / bestiary status / bestiary rebuild", desc = "Standard window controls.", example = "bestiary show" },
      { cmd = "bestiary font <n>", desc = "Set the window's font size.", example = "bestiary font 9" },
      { cmd = "mydsl creaturelore import", desc = "One-time bulk import of the shatteredarchive.com bestiary scrape into the lore database.", example = "mydsl creaturelore import" },
    },
  },
  { key = "itemreference", title = "Item Reference", category = "Targeting & Group", window = "MyDSL_ItemReference",
    summary = "Displays a stored item-stats record from identify/lore captures; shared across characters, auto-shows on new data.",
    commands = {
      { cmd = "item <name>", desc = "Look up an item (sends `identify <name>`) and show the window.", example = "item mace" },
      { cmd = "item show / item hide / item status / item rebuild", desc = "Standard window controls.", example = "item show" },
      { cmd = "item font <n>", desc = "Set the window's font size.", example = "item font 9" },
      { cmd = "mydsl itemlore import", desc = "One-time bulk import of the shatteredarchive.com item-database scrape into the item DB.", example = "mydsl itemlore import" },
      { cmd = "(hover on equipped items)", desc = "Equipped items in the main console's `eq` output show a hover tooltip with quick stats and a click to open Item Reference -- the original text is never altered.", example = "eq" },
      { cmd = "(hover on ground items)", desc = "Ground items seen via `look` get the same hover treatment whenever they can be resolved to a known equipped/carried/identified item -- best-effort only, some items have no reliable connection to their ground description and get no hover.", example = "look" },
      { cmd = "item map <ground item text> = <inventory/equipment item name>", desc = "Manually link a ground item's text to a known item, for the real fraction the automatic match can't connect on its own.", example = "item map a mallet used to shape metal = a shaping mallet" },
    },
  },

  -- ---- Display & Reference ----
  { key = "chat", title = "Chat", category = "Display & Reference", window = "MyDSL_Chat",
    summary = "Tabbed chat window; channels (says/tells/shouts/etc.) route in automatically, no command needed for that part.",
    commands = {
      { cmd = "mydsl chat status / save / reload settings / show / hide / clear", desc = "Standard window controls.", example = "mydsl chat show" },
      { cmd = "mydsl chat font <n>", desc = "Set chat text size.", example = "mydsl chat font 10" },
      { cmd = "mydsl chat wrap <auto|on> / wrap <fixed|manual|off> <n> / wrap <n>", desc = "Control word-wrap width.", example = "mydsl chat wrap auto" },
      { cmd = "mydsl chat timestamp <on|off> / timestamp format <text>", desc = "Toggle/format timestamps.", example = "mydsl chat timestamp on" },
      { cmd = "mydsl chat rebuild / revive", desc = "Recreate the chat window, or recover it if the underlying EMCO object died.", example = "mydsl chat revive" },
      { cmd = "mydsl chat echo [tab] <text> / test [tab] <text>", desc = "Diagnostic: echo a test line into a tab.", example = "mydsl chat test OOC hello" },
    },
  },
  { key = "history", title = "History", category = "Display & Reference", window = "MyDSL_History",
    summary = "Scrolling capture of routed game text with adaptive word-wrap.",
    commands = {
      { cmd = "mydsl history font <n>", desc = "Set the window's font size.", example = "mydsl history font 8" },
      { cmd = "mydsl history status", desc = "Diagnostic: shows font size as stored on disk, in memory, and live.", example = "mydsl history status" },
    },
  },
  { key = "playersnear", title = "Players Near", category = "Targeting & Group", window = "MyDSL_PlayersNear",
    summary = "Passive display of the \"Players near you:\" list. Never sends commands.",
    commands = {
      { cmd = "mydsl playersnear show / hide", desc = "Standard window controls.", example = "mydsl playersnear show" },
      { cmd = "mydsl playersnear font <n>", desc = "Set the window's font size.", example = "mydsl playersnear font 9" },
      { cmd = "mydsl playersnear status", desc = "Diagnostic: shows font size as stored on disk, in memory, and live.", example = "mydsl playersnear status" },
    },
  },
  { key = "portrait", title = "Portrait", category = "Display & Reference", window = "MyDSL_Portrait",
    summary = "Displays a character portrait image, auto-looked-up by character name.",
    commands = {
      { cmd = "mydsl portrait status / show / hide / refresh / rebuild", desc = "Standard window controls.", example = "mydsl portrait show" },
      { cmd = "mydsl portrait set <path> / clear", desc = "Force an explicit image, or clear the override.", example = "mydsl portrait set portraits/kien.png" },
      { cmd = "mydsl portrait font <n> / frame <on|off> / fit <stretch|contain|cover|fill>", desc = "Display tuning.", example = "mydsl portrait fit stretch" },
      { cmd = "mydsl portrait dir [path]", desc = "Show or set the portrait image directory.", example = "mydsl portrait dir" },
      { cmd = "mydsl portrait name <charname>", desc = "Load a specific character's portrait.", example = "mydsl portrait name MyCharacter" },
      { cmd = "mydsl portrait probe [name]", desc = "Diagnose why a lookup isn't finding an image.", example = "mydsl portrait probe" },
      { cmd = "mydsl portrait missing <caption|blank>", desc = "Choose the fallback display when no image is found.", example = "mydsl portrait missing caption" },
      { cmd = "mydsl portrait title <text> / dump", desc = "Set title text, or dump current state.", example = "mydsl portrait dump" },
    },
  },
  { key = "location", title = "Location", category = "Display & Reference", window = "MyDSL_Location",
    summary = "Displays a room/location image driven by your current room.",
    commands = {
      { cmd = "mydsl location / mydsl loc / roompic / locpic", desc = "Any of these four names work identically; bare form shows status/help.", example = "roompic show" },
      { cmd = "status / dump", desc = "Show current status.", example = "mydsl location status" },
      { cmd = "show / hide / refresh / rebuild / reset", desc = "Standard window controls.", example = "mydsl location show" },
      { cmd = "dir [path]", desc = "Show or set the room-picture directory.", example = "mydsl location dir" },
      { cmd = "probe [name]", desc = "Diagnose why a lookup isn't finding an image.", example = "mydsl location probe" },
      { cmd = "name <name>", desc = "Load a specific room's picture by name.", example = "mydsl location name Arkane Square" },
      { cmd = "set <path>", desc = "Force an explicit image for the current room.", example = "mydsl location set roompics/arkane_square.png" },
      { cmd = "map <room> = <path> / unmap <room> / maps", desc = "Manually override, remove, or list room→image mappings.", example = "mydsl location maps" },
      { cmd = "fit <mode> / missing <mode> / title <text> / debug <mode>", desc = "Display tuning and diagnostics.", example = "mydsl location fit stretch" },
    },
  },
  { key = "moonweather", title = "Moon & Weather", category = "Display & Reference", window = "MyDSL_MoonWeather",
    summary = "Moon phases, weather, and game clock/date; can gag raw `lunar` command spam.",
    commands = {
      { cmd = "toggle moons", desc = "Show/hide the widget.", example = "toggle moons" },
      { cmd = "mydsl moon toggle / on / off", desc = "Alternate show/hide controls.", example = "mydsl moon on" },
      { cmd = "mydsl moon font <n>", desc = "Set text size.", example = "mydsl moon font 9" },
      { cmd = "mydsl moon gag / ungag", desc = "Suppress/restore raw `lunar` command output on the main console (default off).", example = "mydsl moon gag" },
    },
  },
  { key = "themes", title = "Themes", category = "Display & Reference", window = nil,
    summary = "Named color/font presets applied across every window.",
    commands = {
      { cmd = "theme", desc = "Show the active theme's name.", example = "theme" },
      { cmd = "theme list", desc = "List available presets, marking the active one.", example = "theme list" },
      { cmd = "theme set <name>", desc = "Switch the active theme.", example = "theme set dark" },
    },
  },

  -- ---- Setup & Diagnostics ----
  { key = "prompt", title = "Prompt", category = "Setup & Diagnostics", window = nil,
    summary = "Toggles whether the server's raw 3-line prompt is gagged from the main console (default: gagged).",
    commands = {
      { cmd = "mydsl prompt on", desc = "Gag the raw prompt lines (UI mode).", example = "mydsl prompt on" },
      { cmd = "mydsl prompt off", desc = "Show the raw prompt lines again.", example = "mydsl prompt off" },
      { cmd = "mydsl prompt toggle", desc = "Flip the current setting.", example = "mydsl prompt toggle" },
    },
  },
  { key = "promptsetup", title = "Prompt Setup", category = "Setup & Diagnostics", window = nil,
    summary = "One-click DSL prompt setup for a brand-new character (also offered automatically on new-character detection).",
    commands = {
      { cmd = "mydsl setprompt", desc = "Apply the standard DSL prompt format to the current character.", example = "mydsl setprompt" },
    },
  },
  { key = "general", title = "General", category = "Setup & Diagnostics", window = nil,
    summary = "Logging, diagnostics, and window-layout commands that aren't tied to one specific window.",
    commands = {
      { cmd = "mydsl help", desc = "This help system.", example = "mydsl help" },
      { cmd = "mydsl log <on|off>", desc = "Window-logging master switch.", example = "mydsl log on" },
      { cmd = "mydsl log <category> <on|off>", desc = "Per-category logging. Categories: combat, chat, history (on by default); group, righthere, target, scan, bloodbath, playersnear (debug-only, off by default).", example = "mydsl log combat off" },
      { cmd = "mydsl rawlog <on|off>", desc = "Diagnostic raw-line capture.", example = "mydsl rawlog on" },
      { cmd = "mydsl who <name>", desc = "DslColors' known-person info (passthrough to `dslcolor show`).", example = "mydsl who kien" },
      { cmd = "mydsl test", desc = "Smoke test: module load / window / character-binding status.", example = "mydsl test" },
      { cmd = "toggle <module>", desc = "PNP's universal on/off switch (combat, affects, moons, ...).", example = "toggle affects" },
      { cmd = "mydsl layout save", desc = "Save current window positions/visibility (per profile).", example = "mydsl layout save" },
      { cmd = "mydsl layout reset", desc = "Reset in-memory layout to defaults -- run `mydsl layout save` after to persist.", example = "mydsl layout reset" },
      { cmd = "autowhere <on|off|status>", desc = "Periodic `where` polling every 20s -- skips a tick while sleeping/fighting/blind instead of sending it blindly.", example = "autowhere on" },
    },
  },
}

-- Category display order (main console + overview page both follow this).
local CATEGORY_ORDER = { "Vitals & Combat", "Targeting & Group", "Display & Reference", "Setup & Diagnostics" }


------------------------------------------------------------------------
-- Local helpers
------------------------------------------------------------------------

local function findModule(key)
  for _, m in ipairs(MyDSL.Help.modules) do
    if m.key == key then return m end
  end
  return nil
end

-- Groups MyDSL.Help.modules by category, preserving each module's
-- position within its category.
local function modulesByCategory()
  local grouped = {}
  for _, m in ipairs(MyDSL.Help.modules) do
    grouped[m.category] = grouped[m.category] or {}
    table.insert(grouped[m.category], m)
  end
  return grouped
end


------------------------------------------------------------------------
-- init()  --  safe to re-call on reload
------------------------------------------------------------------------

function MyDSL.Help.init()
  local helpWin = MyDSL.Windows.ensure(HELP_WIN)
  if helpWin and helpWin.setTitle then pcall(function() helpWin:setTitle("-= Help =-") end) end
  if not MyDSL.Help._mc.console then
    MyDSL.Help._mc.console = Geyser.MiniConsole:new({
      name      = HELP_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 300,
      scrollBar = true,
    }, helpWin)
  end

  if MyDSL.Theme and MyDSL.Theme.styleConsole then
    MyDSL.Theme.styleConsole(MyDSL.Help._mc.console, HELP_WIN, MyDSL.Windows.getFontSize(HELP_WIN, 9))
  end

  MyDSL.Help._handlers.themeChanged = registerAnonymousEventHandler(
    "MyDSL.theme.changed",
    function()
      if MyDSL.Theme and MyDSL.Theme.styleConsole then
        MyDSL.Theme.styleConsole(MyDSL.Help._mc.console, HELP_WIN, MyDSL.Windows.getFontSize(HELP_WIN, 9))
      end
    end
  )

  MyDSL.Help.renderOverview()

  debugc("[MyDSL] Help loaded.")
end


------------------------------------------------------------------------
-- Rendering
------------------------------------------------------------------------

function MyDSL.Help.renderOverview()
  local mc = MyDSL.Help._mc.console
  if not mc then return end
  clearWindow(HELP_MC)

  mc:decho("<" .. COLOR_ACCENT .. ">MyDSL Help<r>\n\n")

  local grouped = modulesByCategory()
  for _, category in ipairs(CATEGORY_ORDER) do
    local mods = grouped[category]
    if mods then
      mc:decho("<" .. COLOR_ACCENT .. ">" .. category .. "<r>\n")
      for _, m in ipairs(mods) do
        mc:dechoLink(
          "  <" .. COLOR_BODY .. ">" .. m.title .. "<r> -- " .. m.summary,
          "MyDSL.Help.render('" .. m.key .. "')",
          "Click for " .. m.title .. "'s full command list",
          true
        )
        mc:decho("\n")
      end
      mc:decho("\n")
    end
  end
end

function MyDSL.Help.render(key)
  local mc = MyDSL.Help._mc.console
  if not mc then return end
  local m = findModule(key)
  if not m then MyDSL.Help.renderOverview(); return end

  clearWindow(HELP_MC)

  mc:dechoLink(
    "<" .. COLOR_LINK .. ">← Back to overview<r>",
    "MyDSL.Help.renderOverview()",
    "Back to all modules",
    true
  )
  mc:decho("\n\n")

  mc:decho("<" .. COLOR_ACCENT .. ">" .. m.title .. "<r>\n")
  mc:decho("<" .. COLOR_BODY .. ">" .. m.summary .. "<r>\n")
  if m.window then
    mc:decho("<" .. COLOR_BODY .. ">Window: " .. m.window .. "<r>\n")
  end
  mc:decho("\n")

  for _, c in ipairs(m.commands or {}) do
    mc:decho("<" .. COLOR_ACCENT .. ">" .. c.cmd .. "<r>\n")
    mc:decho("  <" .. COLOR_BODY .. ">" .. c.desc .. "<r>\n")
    if c.example then
      mc:decho("  <" .. COLOR_BODY .. ">Example: " .. c.example .. "<r>\n")
    end
    mc:decho("\n")
  end
end

-- open(key)  --  shows the window, then renders the overview (no key) or
-- a specific module's detail page. Called by both main-console links and
-- the "mydsl help overview" alias.
function MyDSL.Help.open(key)
  MyDSL.Windows.show(HELP_WIN)
  if key then MyDSL.Help.render(key) else MyDSL.Help.renderOverview() end
end

function MyDSL.Help.setFont(size)
  size = tonumber(size)
  if not size then echo("usage: mydsl help font <size>\n"); return end
  if size < 6 then size = 6 end
  if size > 18 then size = 18 end
  if MyDSL.Help._mc.console then MyDSL.Help._mc.console:setFontSize(size) end
  MyDSL.Windows.setFontSize(HELP_WIN, size)
  echo("MyDSL_Help font=" .. tostring(size) .. "\n")
end


------------------------------------------------------------------------
-- Main-console top-tier printer -- "mydsl help"
------------------------------------------------------------------------
-- Replaces the old flat MyDSL.help() (used to live in MyDSL_DataLayer.lua,
-- removed from there). Terse: title + one-liner only, no commands -- those
-- live in the window, one click away.

function MyDSL.help()
  echo("\n")
  decho("<" .. COLOR_ACCENT .. ">MyDSL commands<r>\n")
  dechoLink(
    "<" .. COLOR_LINK .. ">[Browse all modules in a window]<r>\n",
    "MyDSL.Help.open()",
    "Open the full Help window",
    true
  )
  echo("\n")

  local grouped = modulesByCategory()
  for _, category in ipairs(CATEGORY_ORDER) do
    local mods = grouped[category]
    if mods then
      decho("<" .. COLOR_ACCENT .. ">" .. category .. "<r>\n")
      for _, m in ipairs(mods) do
        dechoLink(
          "  <" .. COLOR_BODY .. ">" .. m.title .. "<r> -- " .. m.summary .. "\n",
          "MyDSL.Help.open('" .. m.key .. "')",
          "Click for " .. m.title .. "'s full command list",
          true
        )
      end
    end
  end
end


------------------------------------------------------------------------
-- Aliases
------------------------------------------------------------------------

MyDSL._aliases = MyDSL._aliases or {}

if MyDSL._aliases.help then pcall(killAlias, MyDSL._aliases.help) end
MyDSL._aliases.help = tempAlias(
  "^mydsl help$",
  [[if MyDSL and MyDSL.help then MyDSL.help() end]]
)

if MyDSL._aliases.helpOverview then pcall(killAlias, MyDSL._aliases.helpOverview) end
MyDSL._aliases.helpOverview = tempAlias(
  "^mydsl help overview$",
  [[if MyDSL and MyDSL.Help then MyDSL.Help.open() end]]
)

if MyDSL._aliases.helpShow then pcall(killAlias, MyDSL._aliases.helpShow) end
MyDSL._aliases.helpShow = tempAlias(
  "^mydsl help show$",
  [[if MyDSL and MyDSL.Windows then MyDSL.Windows.show("MyDSL_Help") end]]
)

if MyDSL._aliases.helpHide then pcall(killAlias, MyDSL._aliases.helpHide) end
MyDSL._aliases.helpHide = tempAlias(
  "^mydsl help hide$",
  [[if MyDSL and MyDSL.Windows then MyDSL.Windows.hide("MyDSL_Help") end]]
)

if MyDSL._aliases.helpFont then pcall(killAlias, MyDSL._aliases.helpFont) end
MyDSL._aliases.helpFont = tempAlias(
  "^mydsl help font (\\d+)$",
  [[if MyDSL and MyDSL.Help then MyDSL.Help.setFont(matches[2]) end]]
)


------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

MyDSL.Help.init()
