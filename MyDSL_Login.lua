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
--      return { name = "YourCharacterName", password = "YourPassword" }
--    Never commit that file, never paste its contents into chat/HANDOFF.
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
--    echo, so the password is never printed to the main window. It's also
--    never captured by MyDSL_RawCapture.lua, which only ever logs
--    *incoming* `line` text (confirmed by reading that file) -- outgoing
--    send() calls aren't visible to it at all.
--
-- 4. Silently off if the credentials file doesn't exist or doesn't parse --
--    no error spam, no repeated nagging, just a single one-line status note
--    at load that says whether a file was *found*, never whether a
--    password is *correct*.
--
-- 5. Toggleable per Principle 2 ("Toggleable By Default"), independent of
--    whether credentials are configured: "mydsl login on|off".
--
-- 6. Trigger patterns below match "Player name:" and "Password:" -- both
--    confirmed as real, current corpus strings by Claude Code's
--    check_text_coverage.py run (HANDOFF.md 2026-08-25: 298x and 6,073x
--    respectively, part of the "entire login flow uncaptured" finding).
--    Claude Desktop has no log/ access (standing disclosed limitation) and
--    has NOT independently confirmed exact anchoring/whitespace against a
--    raw captured line -- Claude Code: please corpus-check these two
--    literal patterns before this goes live, same "extraction not
--    paraphrase" discipline as everything else in this project.
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
-- =============================================================================

MyDSL       = MyDSL or {}
MyDSL.Login = MyDSL.Login or { enabled = true, _configured = false }

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
      or type(result.name) ~= "string" or result.name == ""
      or type(result.password) ~= "string" or result.password == "" then
    credentials = nil
    return false
  end
  credentials = result
  return true
end

MyDSL.Login._configured = loadCredentials()
if MyDSL.Login._configured then
  cecho("<dark_green>[MyDSL] Login autofill: credentials found.<reset>\n")
else
  cecho("<light_gray>[MyDSL] Login autofill: not configured (see MyDSL_Login.lua header).<reset>\n")
end

-- ---- send-once-per-prompt-per-connection guard ------------------------------

local sentName, sentPassword = false, false
local function resetGuard() sentName, sentPassword = false, false end

-- Mudlet's own built-in connection event (real name, fires on connect) --
-- same registerAnonymousEventHandler-with-inline-function pattern already
-- used by MyDSL_DataLayer.lua's gmcp.login_data handler.
MyDSL.Login._connHandler = registerAnonymousEventHandler("sysConnectionEvent", resetGuard)

-- ---- triggers ----------------------------------------------------------------

local function registerLoginTriggers()
  if MyDSL.Login._triggers.name then return end

  MyDSL.Login._triggers.name = tempRegexTrigger([[^Player name:]], function()
    if not MyDSL.Login.enabled or not credentials or sentName then return end
    sentName = true
    send(credentials.name, false)
  end, 100)

  MyDSL.Login._triggers.password = tempRegexTrigger([[^Password:]], function()
    if not MyDSL.Login.enabled or not credentials or sentPassword then return end
    sentPassword = true
    send(credentials.password, false)
  end, 100)
end

local function unregisterLoginTriggers()
  for k, id in pairs(MyDSL.Login._triggers) do
    pcall(killTrigger, id)
    MyDSL.Login._triggers[k] = nil
  end
end

registerLoginTriggers()

-- ---- toggle + status aliases ---------------------------------------------

MyDSL.Login._aliases.toggle = tempAlias(
  [[^mydsl login (on|off)$]],
  [[MyDSL.Login.enabled = (matches[2] == "on")
    if MyDSL.Login.enabled then MyDSL._loginRegister() else MyDSL._loginUnregister() end
    echo("Login autofill " .. matches[2] .. ".\n")]]
)

-- Deliberately never echoes the credential values themselves -- only
-- whether a file was found and whether the toggle is on.
MyDSL.Login._aliases.status = tempAlias(
  [[^mydsl login status$]],
  [[local state = MyDSL.Login.enabled and "ON" or "OFF"
    if MyDSL.Login._configured then
      echo("Login autofill: configured, " .. state .. ".\n")
    else
      echo("Login autofill: NOT configured (no credentials file found), " .. state .. ".\n")
    end]]
)

-- Exposed on MyDSL so the alias script strings (separate Lua chunks, no
-- closure access to this file's locals) can reach these -- same pattern as
-- MyDSL_RawCapture.lua's MyDSL._rawCaptureRegister/Unregister.
MyDSL._loginRegister   = registerLoginTriggers
MyDSL._loginUnregister = unregisterLoginTriggers
