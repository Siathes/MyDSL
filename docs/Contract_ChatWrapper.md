# Module Contract: MyDSL_ChatWrapper.lua
**Layer 3 — EMCO Chat Integration**
*Written from actual code. Version: v4C11 QuietWindowSetup. File: MyDSL_ChatWrapper.lua (648 lines)*

---

## What This Module Is

ChatWrapper creates `demonnic.chat` — the EMCO object — inside the `MyDSL_Chat`
UserWindow. It preserves the global name so every existing trigger that calls
`demonnic.chat:append("Tells")` keeps working without modification.

ChatWrapper owns the EMCO lifecycle (create, configure, revive). It does NOT
install chat capture triggers, route channels, or modify EMCO's internal behavior.

---

## Namespace

```lua
MyDSL.Chat             -- the module
MyDSL.Chat.config      -- configuration
MyDSL.Chat.state       -- runtime state
MyDSL.Chat.emco        -- reference to the created EMCO object
demonnic.chat          -- global alias pointing to the same EMCO object
```

---

## Tabs (Confirmed)

```lua
C.config.tabs = { "All", "Local", "City", "OOC", "Tells", "Group" }
```

- **All** — `allTab = true` — EMCO mirrors everything here automatically
- **Local** — say, whisper, yell, shout, emote, pmote, tmote, room events
- **City** — kingdom, cgossip
- **OOC** — ooc, okingdom, grats, Q/A, newbie, Quest, Bloodbath, gossip, radio, auction
- **Tells** — direct tells
- **Group** — gtell

Tab routing is handled by the Trigger editor (separate from this module).

---

## How Window Creation Works

`C.ensureWindow()` tries three approaches in order:

```
1. MyDSL.Windows.ensure("MyDSL_Chat")   ← WindowRegistry (preferred)
   └─ Uses LayoutEngine position, proper registration
2. C.window (already exists)             ← Previous call cached it
3. Geyser.UserWindow:new({...})         ← Fallback (hardcoded position)
   └─ Position: x="78%", y="0%", w="22%", h="46%" (Gap 3, fixed 2026-07-05 — matches confirmed layout)
```

The WindowRegistry path is correct. The fallback path exists in case the module
loads before WindowRegistry — it creates a window at a hardcoded position that
does NOT match the confirmed layout (should be x=0.78, w=0.22).

---

## How EMCO Creation Works

`C.createInWindow()` sequence:

```
1. Require EMCOChat library
2. C.ensureWindow() → get/create parent UserWindow
3. Store and hide any existing demonnic.chat
4. Hide EMCOPrebuiltChatContainer (EMCO's default floating window)
5. emco:new(config, parentWindow) → create EMCO inside our window
6. demonnic.chat = new EMCO object
7. Apply font, wrap, timestamp settings
```

The EMCO is created with these key settings:
```lua
{
  consoles      = { "All","Local","City","OOC","Tells","Group" },
  allTab        = true,      -- All tab mirrors everything
  allTabName    = "All",
  commandLine   = false,     -- display only, no input box
  mapTab        = false,     -- no mapper tab in EMCO
  blankLine     = false,
  blink         = false,
  bufferSize    = 10000,
  autoWrap      = true,      -- configurable
  fontSize      = 9,         -- configurable
}
```

---

## The startupSync() Timer Cascade

Because Mudlet's `loadWindowLayout()` can finish AFTER scripts load, EMCO may
be created before the UserWindow is fully positioned. `startupSync()` schedules
multiple deferred creates:

```
0.4s  → createInWindow() if EMCO not yet created
1.5s  → revive() if EMCO exists (resize/reposition)
3.5s  → revive() again
5.0s  → createInWindow() ALWAYS (final "forced" rebuild)
```

**The 5.0s forced rebuild was the critical issue** (see Gap 2, fixed 2026-07-05).
It used to call `createInWindow()` unconditionally 5 seconds after login, wiping
any chat text that appeared in the first 5 seconds when a fresh EMCO replaced
the previous one. Now guarded — only force-rebuilds when actually broken.

---

## Public API

```lua
-- Core lifecycle:
MyDSL.Chat.install()         -- load settings, set up aliases, start sync
MyDSL.Chat.createInWindow()  -- create/recreate EMCO
MyDSL.Chat.revive(reason)    -- show+resize existing EMCO (gentler than recreate)
MyDSL.Chat.rebuild()         -- alias for createInWindow()

-- Show/hide:
MyDSL.Chat.show()
MyDSL.Chat.hide()

-- Settings:
MyDSL.Chat.setFont(size)
MyDSL.Chat.setWrap(mode [, columns])
MyDSL.Chat.setTimestamp(on|off)
MyDSL.Chat.setTimestampFormat(format)
MyDSL.Chat.saveSettings()
MyDSL.Chat.loadSettings()

-- Diagnostics:
MyDSL.Chat.status()
MyDSL.Chat.clear()
MyDSL.Chat.test(tab, msg)       -- uses appendBuffer correctly
MyDSL.Chat.echoTest(tab, msg)   -- uses cecho directly
```

---

## Aliases

```
mydsl chat status
mydsl chat show / hide
mydsl chat rebuild / revive
mydsl chat font <size>
mydsl chat wrap auto|on | wrap fixed|off <cols> | wrap <cols>
mydsl chat timestamp on|off
mydsl chat timestamp format <fmt>
mydsl chat save
mydsl chat reload settings
mydsl chat clear
mydsl chat echo [tab] [msg]
mydsl chat test [tab] [msg]
```

---

## What This Module Does NOT Do

- Does not install chat capture triggers (Trigger editor's job)
- Does not route channels (triggers call `demonnic.chat:append()` directly)
- Does not modify stock EMCO triggers or aliases
- Does not use EMCO's mapTab feature
- Does not dock or move `EMCOPrebuiltChatContainer`
- Does not use `Geyser.changeContainer`

---

## Dependencies

**Requires:** EMCOChat library (installed as Mudlet package)
**Uses:** WindowRegistry (`MyDSL.Windows.ensure()`) when available
**Must load after:** WindowRegistry
**Sets:** `demonnic.chat` global — all triggers depend on this being set

---

## Gaps and Issues Found in Code

### Gap 1 — Hardcoded tab CSS, no ThemeEngine ⚠️
```lua
activeTabCSS   = "background-color: black; border-color: green; ..."
inactiveTabCSS = "background-color: black; border-color: grey; ..."
activeTabFGColor   = "green"
inactiveTabFGColor = "grey"
```
All hardcoded. Should read from ThemeEngine for at minimum background, active
color (should be `highlightColor`), and inactive color (should be `dimColor`).
No ThemeEngine refresh callback registered.

### Gap 2 — 5.0s forced rebuild wipes early chat ✅ FIXED
**2026-07-05 audit: confirmed fixed.** The 5.0s timer now guards with a
readiness check and only force-rebuilds when something is actually broken;
otherwise it calls the gentle `C.revive()` (resize/reposition, no content
wipe) — exactly the fix this gap called for, in place in the live code today.

### Gap 3 — Fallback window position wrong ✅ FIXED
**2026-07-05 audit: confirmed fixed.** The fallback `Geyser.UserWindow:new()`
now uses `x="78%", y="0%", width="22%", height="46%"` — matches the confirmed
layout exactly.

### Gap 4 — Settings not character-bound ⚠️ still open
**2026-07-05 audit: confirmed still open.** `chat_settings.lua` is still a
single shared file (path has no character name in it) — font size, wrap,
timestamp preferences are still shared across all characters.

**Fix:** Same pattern as TickView — include character name in settings path.

### Gap 5 — `getWindowEntry()` uses fragile key lookup ✅ FIXED
**2026-07-05 audit: confirmed fixed.** `getWindowEntry()` now tries exactly
two keys (`C.config.windowName` then the literal `"MyDSL_Chat"`), with a
comment noting the old 4-key version always had a dead `reg["Chat"]` lookup.
WindowRegistry uses the full name as its key consistently.

### Gap 6 — applyFont() probes undocumented EMCO internals ⚠️
```lua
for _, key in ipairs({ "mc", "consoles", "tabs" }) do
  local t = ch[key]
```
Accesses `ch.mc`, `ch.consoles`, `ch.tabs` directly. These are undocumented
internal fields of the EMCO object. If EMCOChat updates and renames these,
`applyFont()` silently fails (all wrapped in pcall).

Low priority — EMCO is unlikely to change. But worth noting for maintainability.

### Gap 7 — C.oldChat not cleaned up ℹ️
When `createInWindow()` replaces an existing EMCO, the old object is hidden
and stored in `C.oldChat`. It is never destroyed or nil'd. Over multiple
rebuilds (e.g., the 4 startup timers), `C.oldChat` accumulates references
to dead EMCO objects.

Not harmful — objects get garbage collected eventually — but the accumulation
means old objects may stay in memory during long sessions.

### Gap 8 — No character-binding for tab configuration ℹ️
Tab list (`C.config.tabs`) is hardcoded in the module. If different characters
want different tab layouts (e.g., a clan character wants a "Clan" tab, others
don't), there's no mechanism for it. Low priority for now since all characters
use the same 6-tab layout.

---

## The Correct Trigger Pattern (using appendBuffer)

The `C.test()` method shows the correct approach for color-preserving routing:

```lua
-- In a trigger (e.g., matching a tell):
selectCurrentLine()
copy()
demonnic.chat:append("Tells")   -- EMCO handles the paste with colors
deleteLine()                      -- remove from main console
```

Do NOT call `selectCurrentLine()` manually before `demonnic.chat:append()` —
EMCO's `append()` calls it internally. The correct pattern is:

```lua
demonnic.chat:append("Tells")   -- EMCO selects + copies + appends internally
deleteLine()                      -- gag from main console
```

---

## Contract Status

| Clause | Status |
|---|---|
| Preserves `demonnic.chat` global name | ✅ |
| Creates EMCO inside MyDSL_Chat window | ✅ |
| Does not install capture triggers | ✅ |
| Does not route channels | ✅ |
| allTab mirrors all channels | ✅ |
| 6 confirmed tabs | ✅ |
| commandLine = false (display only) | ✅ |
| WindowRegistry integration (primary) | ✅ |
| 5.0s forced rebuild (wipes early chat) | ✅ Fixed 2026-07-05 — Gap 2 |
| Fallback window position correct | ✅ Fixed 2026-07-05 — Gap 3 |
| ThemeEngine tab CSS | ❌ Still hardcoded — Gap 1 |
| Character-bound settings | ❌ Still shared file — Gap 4 |
| Window key lookup | ✅ Fixed 2026-07-05 — Gap 5 |
EOF