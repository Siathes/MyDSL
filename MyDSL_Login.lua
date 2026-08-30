-- =============================================================================
-- MyDSL_Login.lua  --  Secure auto-login replacement
-- =============================================================================
-- Built 2026-08-26 by Claude Desktop, per Steven's direct request, to
-- replace an existing NATIVE Mudlet trigger that had his account password
-- typed directly into its script body -- exactly the exposure
-- docs/MYDSL_1.0_PHILOSOPHY.md Principle 5 names as a standing rule against
-- ("no credentials in native trigger/alias scripts, ever, live or in any
-- tracked backup"). That native trigger was never part of this git repo (it
-- lives only in Steven's live profile / current/*.xml, outside anything
-- Claude Desktop's clone has ever had access to), so this file was written
-- without ever viewing its actual contents or Steven's real password --
-- it's a rebuild of the *behavior* Steven described ("does what the
-- original script does"), not a port of the insecure code. Deliberate
-- choice, not an oversight: seeing the real credential isn't necessary to
-- build a secure replacement mechanism.
--
-- ---- Design -----------------------------------------------------------------
-- 1. Credential VALUES never appear in this file, in git, or in any
--    exported/backup XML. They live in a plain Lua file OUTSIDE the repo
--    entirely, at getMudletHomeDir() .. "/MyDSL_login_credentials.lua" --
--    the Mudlet *profile* folder, the same place MyDSL_state.lua,
--    MyDSL_windowstate_*.lua etc. already live and that this repo has never
--    tracked. Hand-create it once, yourself, in a text editor:
--      return { character = "YourCharacterName", password = "YourPassword" }
--    Never commit that file, never paste its contents into chat/HANDOFF.
--    (Renamed from `name` to `character` 2026-08-29 -- see note 6 below;
--    an existing file using the old `name` key is still read fine, see
--    loadCredentials()'s own fallback.)
--
--    Note for whoever wires this in: this repo's own .gitignore already has
--    a bare `login` entry ("# Connection credentials (auto-login
--    password)"), but a full-tree grep found nothing that reads or writes a
--    file by that literal name anywhere in the Lua source -- looks like a
--    planned-but-never-built earlier attempt at this exact feature, not
--    live infrastructure. This module intentionally uses its own explicit
--    filename (MyDSL_login_credentials.lua) instead of building on that
--    stale entry. Worth a one-line doc note so the old entry doesn't get
--    mistaken for something this module depends on.
--
-- 2. Loaded with loadfile()+pcall, read-only, once per profile load. The
--    result is held in a LOCAL upvalue only (`credentials` below) --
--    deliberately never assigned onto MyDSL.Login or any other shared
--    table, so nothing else in the profile (another module, an alias, a
--    debug echo) can read the password back out through MyDSL's own state.
--
-- 3. Sent with send(cmd, false) -- the second argument suppresses local
--    echo, so the password is never printed to the main window.
--    (MyDSL_RawCapture.lua, the diagnostic this originally also needed
--    to stay invisible to, was removed 2026-08-27 -- confirmed unused
--    per Steven -- so this concern no longer applies at all.)
--
-- 4. Silently off if the credentials file doesn't exist or doesn't parse --
--    no error spam, no repeated nagging, just a single one-line status note
--    at load that says whether a file was *found*, never whether a
--    password is *correct*.
--
-- 5. Toggleable per Principle 2 ("Toggleable By Default") -- but as TWO
--    independent toggles as of 2026-08-29, not one: "mydsl login on|off"
--    (password autofill) and "mydsl login character on|off" (character-
--    name autofill). See note 6 for why they're split.
--
-- 6. Trigger patterns below match "Player name:" and "Password:" -- both
--    confirmed as real, current corpus strings (direct grep of log/, e.g.
--    log/2026-07-01#15-33-12.txt lines 58-95, 2026-08-29). They are NOT a
--    matched pair in one prompt sequence: "Password:" is the MASTER
--    ACCOUNT's password (asked right after "What is your Master Account's
--    name?", which this module never automates -- typed manually, low-
--    cost, once per session), while "Player name:" is a separate, later
--    prompt asking which CHARACTER to play, reached only after navigating
--    the Master Login Menu. The password is safe to auto-fill unattended
--    (one master account, same password every session); the character
--    name isn't, structurally -- Steven's own real corpus shows him
--    logging into different characters across sessions (kien, tibbins,
--    ...), so a fixed auto-sent name is right only when it happens to
--    match that session's target and silently wrong the rest of the time.
--    Design review: docs/CHANGELOG.md 2026-08-29. Fix, per Steven's own
--    choice among the options presented: split into two independent
--    toggles, character autofill OFF by default, password autofill ON by
--    default (unchanged from before this fix).
--
-- 7. Send-once-per-prompt-per-connection guard, reset on Mudlet's own
--    sysConnectionEvent: prevents a mismatched credential (or a server that
--    re-shows the prompt on a typo) from looping the password out
--    repeatedly within one connection.
--
-- 8. dofile() wiring done 2026-08-26 by Claude Code -- unlike Claude
--    Desktop's own clone, Claude Code has direct file access to DSL2's
--    Script Editor state (current/*.xml, confirmed newest-by-mtime per
--    CLAUDE.md's own gotcha note) and added the entry directly, right
--    after MyDSL_RawCapture's own entry. Still needs Steven's live
--    confirmation in-game -- a file edit here doesn't prove Mudlet
--    itself picked it up correctly.
--
-- 9. First-run setup popup, added 2026-08-30 per Steven ("add a way for
--    the user to add the login information like a pop up UI for the
--    first setup (i dont want users to have to edit code for basic
--    scripts)"). Mudlet/Geyser has no native text-entry widget (confirmed
--    -- grepped this whole codebase and the vendored PNP reference for
--    any prior use of one; there is none, it doesn't exist), so a true
--    mouse-driven form isn't achievable -- the real fix for "don't make
--    users edit code" is replacing "hand-write a .lua file in a text
--    editor" with "type one in-game command," and using a real popup
--    window (MyDSL_LoginSetup, same Geyser.UserWindow + WindowRegistry
--    pattern as every other window here) to explain it and pre-fill the
--    command line via appendCmdLine() so nothing has to be typed from
--    memory. The command itself still writes credentials.password in
--    full to the main window while being typed -- same as typing a
--    normal password at DSL's own login prompt -- so this is not a
--    downgrade from that flow's normal exposure. Auto-shown once per
--    reload when no credentials file exists yet and setup hasn't been
--    dismissed; "mydsl login setup" reopens it any time, "mydsl login
--    setup <character> <password>" is what the pre-filled command line
--    actually submits.
-- =============================================================================

MyDSL       = MyDSL or {}
-- enabled = password autofill (default ON, unchanged from before the
-- 2026-08-29 split -- always safe, one master account/password).
-- characterEnabled = character-name autofill (default OFF -- see the
-- header's note 6 for why: only sometimes correct, unlike the password).
MyDSL.Login = MyDSL.Login or { enabled = true, characterEnabled = false, _configured = false }

-- Kill any trigger/alias/handler from a previous load.
MyDSL.Login._triggers = MyDSL.Login._triggers or {}
local function deregisterTriggers()
  for k, id in pairs(MyDSL.Login._triggers) do
    pcall(killTrigger, id)
    MyDSL.Login._triggers[k] = nil
  end
end
deregisterTriggers()

if MyDSL.Login._connHandler then pcall(killAnonymousEventHandler, MyDSL.Login._connHandler) end

MyDSL.Login._aliases = MyDSL.Login._aliases or {}
for k, id in pairs(MyDSL.Login._aliases) do
  pcall(killAlias, id)
  MyDSL.Login._aliases[k] = nil
end

-- ---- credential loading (read-only, never re-exposed) ----------------------

local credentials = nil  -- local upvalue only -- see design note 2 above.

local function loadCredentials()
  local path = getMudletHomeDir() .. "/MyDSL_login_credentials.lua"
  local chunk = loadfile(path)
  if not chunk then
    credentials = nil
    return false
  end
  local ok, result = pcall(chunk)
  if not ok or type(result) ~= "table"
      or type(result.password) ~= "string" or result.password == "" then
    credentials = nil
    return false
  end
  -- Field renamed name -> character 2026-08-29 (see header note 1/6) --
  -- fall back to the old key so an existing credentials file on disk
  -- doesn't need to be hand-edited to keep working.
  local character = result.character or result.name
  if type(character) ~= "string" or character == "" then
    credentials = nil
    return false
  end
  result.character = character
  credentials = result
  return true
end

-- writeCredentials(character, password) -- the actual "form submit" behind
-- "mydsl login setup <character> <password>". Never echoes the password
-- back; overwrites any existing file (running setup again is exactly how
-- you'd want to change what's saved).
local function writeCredentials(character, password)
  local path = getMudletHomeDir() .. "/MyDSL_login_credentials.lua"
  local f, err = io.open(path, "w")
  if not f then
    cecho("<red>[MyDSL] Login setup failed -- couldn't write " .. path .. ": " .. tostring(err) .. "<reset>\n")
    return false
  end
  f:write(string.format("return { character = %q, password = %q }\n", character, password))
  f:close()
  return true
end

-- ---- setup-popup dismissal flag (own small file -- never touches the
-- credentials file itself, so it's safe to read/write even before setup
-- has ever run) --------------------------------------------------------------
local function settingsFile()
  return getMudletHomeDir() .. "/MyDSL_login_settings.lua"
end

local function loadSetupDismissed()
  local chunk = loadfile(settingsFile())
  if not chunk then return false end
  local ok, result = pcall(chunk)
  return ok and type(result) == "table" and result.setupDismissed == true
end

local function saveSetupDismissed(dismissed)
  local f = io.open(settingsFile(), "w")
  if not f then return end
  f:write("return { setupDismissed = " .. tostring(dismissed and true or false) .. " }\n")
  f:close()
end

MyDSL.Login._configured = loadCredentials()
MyDSL.Login._setupDismissed = loadSetupDismissed()
if MyDSL.Login._configured then
  cecho("<dark_green>[MyDSL] Login autofill: credentials found.<reset>\n")
else
  cecho("<light_gray>[MyDSL] Login autofill: not configured. Type 'mydsl login setup' for a guided setup, or see MyDSL_Login.lua's header for the manual file format.<reset>\n")
end

-- ---- send-once-per-prompt-per-connection guard ------------------------------

local sentCharacter, sentPassword = false, false
local function resetGuard() sentCharacter, sentPassword = false, false end

-- Mudlet's own built-in connection event (real name, fires on connect) --
-- same registerAnonymousEventHandler-with-inline-function pattern already
-- used by MyDSL_DataLayer.lua's gmcp.login_data handler.
MyDSL.Login._connHandler = registerAnonymousEventHandler("sysConnectionEvent", resetGuard)

-- ---- triggers ----------------------------------------------------------------
-- Both triggers stay registered for the module's whole lifetime -- each
-- callback independently checks its OWN enabled flag at fire time, so
-- turning one autofill on/off no longer needs to add/remove the trigger
-- itself (pre-2026-08-29 behavior, from when there was only one combined
-- toggle). Simpler, and avoids a trigger existing/not-existing race with
-- the flag it's supposed to be gated by.

local function registerLoginTriggers()
  if MyDSL.Login._triggers.character then return end

  MyDSL.Login._triggers.character = tempRegexTrigger([[^Player name:]], function()
    if not MyDSL.Login.characterEnabled or not credentials or sentCharacter then return end
    sentCharacter = true
    send(credentials.character, false)
  end, 100)

  MyDSL.Login._triggers.password = tempRegexTrigger([[^Password:]], function()
    if not MyDSL.Login.enabled or not credentials or sentPassword then return end
    sentPassword = true
    send(credentials.password, false)
  end, 100)
end

registerLoginTriggers()

-- ---- toggle + status aliases ---------------------------------------------

-- "mydsl login on|off" -- password autofill only, unchanged meaning from
-- before the 2026-08-29 split (this was always the primary/original use).
MyDSL.Login._aliases.toggle = tempAlias(
  [[^mydsl login (on|off)$]],
  [[MyDSL.Login.enabled = (matches[2] == "on")
    echo("Login password autofill " .. matches[2] .. ".\n")]]
)

-- "mydsl login character on|off" -- added 2026-08-29, the new independent
-- toggle for the "Player name:" autofill. Defaults OFF -- see header
-- note 6 for why this one specifically shouldn't default on.
MyDSL.Login._aliases.characterToggle = tempAlias(
  [[^mydsl login character (on|off)$]],
  [[MyDSL.Login.characterEnabled = (matches[2] == "on")
    echo("Login character-name autofill " .. matches[2] .. ".\n")]]
)

-- Deliberately never echoes the credential values themselves -- only
-- whether a file was found and whether each toggle is on.
MyDSL.Login._aliases.status = tempAlias(
  [[^mydsl login status$]],
  [[local pwState  = MyDSL.Login.enabled and "ON" or "OFF"
    local charState = MyDSL.Login.characterEnabled and "ON" or "OFF"
    if MyDSL.Login._configured then
      echo("Login autofill: configured. Password=" .. pwState .. ", Character=" .. charState .. ".\n")
    else
      echo("Login autofill: NOT configured (no credentials file found). Password=" .. pwState .. ", Character=" .. charState .. ".\n")
    end]]
)

-- ---- first-run setup popup -------------------------------------------------
-- See header note 9 for why this is a guided command instead of a real
-- form: Mudlet/Geyser has no text-entry widget, so the popup's job is to
-- explain the command and pre-fill the command line, not collect input
-- itself.

local SETUP_WIN = "MyDSL_LoginSetup"
local SETUP_MC  = "MyDSL_LoginSetup_MC"
MyDSL.Login._mc = MyDSL.Login._mc or {}

local function ensureSetupWindow()
  if not (MyDSL.Windows and Geyser and Geyser.MiniConsole) then return nil end
  local win = MyDSL.Windows.ensure(SETUP_WIN)
  if not win then return nil end
  if win.setTitle then pcall(function() win:setTitle("Login Setup") end) end
  if not MyDSL.Login._mc.console then
    MyDSL.Login._mc.console = Geyser.MiniConsole:new({
      name = SETUP_MC, x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 300, scrollBar = true,
    }, win)
  end
  if MyDSL.Theme and MyDSL.Theme.styleConsole then
    MyDSL.Theme.styleConsole(MyDSL.Login._mc.console, SETUP_WIN, MyDSL.Windows.getFontSize(SETUP_WIN, 9))
  end
  return MyDSL.Login._mc.console
end

-- Pre-fills the command line rather than sending anything -- "automate to
-- assist, not to play": the player still types their own name/password
-- and presses Enter themselves, same as this module never auto-submits
-- anything the player didn't ask for.
function MyDSL.Login.prefillSetupCommand()
  if clearCmdLine then pcall(clearCmdLine) end
  if appendCmdLine then pcall(appendCmdLine, "mydsl login setup YourCharacterName YourPassword") end
  echo("Command line filled in below -- replace YourCharacterName/YourPassword with your own, then press Enter.\n")
end

function MyDSL.Login.dismissSetup()
  MyDSL.Login._setupDismissed = true
  saveSetupDismissed(true)
  if MyDSL.Windows then pcall(MyDSL.Windows.hide, SETUP_WIN) end
end

function MyDSL.Login.renderSetup()
  local mc = ensureSetupWindow()
  if not mc then return end
  clearWindow(SETUP_MC)
  mc:decho("<255,255,153>DSL login autofill isn't set up yet.<r>\n\n")
  mc:decho("<204,204,204>Saves your master account password (and, if you turn it on separately, which character to play) so you don't have to type them in every time you connect.<r>\n\n")
  mc:dechoLink(
    "<136,204,255>Click here to fill in the setup command<r>",
    "MyDSL.Login.prefillSetupCommand()",
    "Pre-fills the command line -- you still type your name/password and press Enter yourself",
    true
  )
  mc:decho("\n\n<204,204,204>...or just type it yourself:<r>\n")
  mc:decho("<255,204,68>mydsl login setup <character-name> <password><r>\n\n")
  mc:decho("<136,136,136>Saved locally in this profile's own folder only -- never in git, never sent anywhere but DSL's own login prompt, same as typing it in by hand.<r>\n\n")
  mc:dechoLink(
    "<136,136,136>Don't ask again<r>",
    "MyDSL.Login.dismissSetup()",
    "Hides this popup for future sessions; 'mydsl login setup' still opens it any time",
    true
  )
  mc:decho("\n")
end

function MyDSL.Login.showSetup()
  MyDSL.Login.renderSetup()
  if MyDSL.Windows then pcall(MyDSL.Windows.show, SETUP_WIN) end
end

-- setup(character, password) -- the actual "form submit."
function MyDSL.Login.setup(character, password)
  character = tostring(character or ""):gsub("^%s+", ""):gsub("%s+$", "")
  password  = tostring(password  or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if character == "" or password == "" then
    echo("usage: mydsl login setup <character-name> <password>\n")
    return false
  end
  if not writeCredentials(character, password) then return false end
  MyDSL.Login._configured = loadCredentials()
  MyDSL.Login._setupDismissed = true
  saveSetupDismissed(true)
  if MyDSL.Windows then pcall(MyDSL.Windows.hide, SETUP_WIN) end
  cecho("<dark_green>[MyDSL] Login credentials saved for '" .. character .. "'. Password autofill is ON.<reset>\n")
  return true
end

-- "mydsl login setup" (no args) -- (re)open the guided popup.
MyDSL.Login._aliases.setupOpen = tempAlias(
  [[^mydsl login setup$]],
  [[if MyDSL and MyDSL.Login then MyDSL.Login.showSetup() end]]
)

-- "mydsl login setup <character> <password>" -- password can itself
-- contain spaces, so it greedily takes the rest of the line, not just
-- one word.
MyDSL.Login._aliases.setupSubmit = tempAlias(
  [[^mydsl login setup (\S+) (.+)$]],
  [[if MyDSL and MyDSL.Login then MyDSL.Login.setup(matches[2], matches[3]) end]]
)

-- Auto-show once per reload -- deferred slightly so WindowRegistry/Theme
-- (loaded earlier in the dofile order, but this keeps the same safety
-- margin other modules' own deferred-init calls already use rather than
-- assuming load order never changes) are definitely ready.
if not MyDSL.Login._configured and not MyDSL.Login._setupDismissed then
  tempTimer(0.3, function()
    if MyDSL and MyDSL.Login and not MyDSL.Login._configured and not MyDSL.Login._setupDismissed then
      MyDSL.Login.showSetup()
    end
  end)
end
