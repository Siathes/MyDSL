-- =============================================================================
-- MyDSL_Login.lua  --  Secure auto-login, real navigation + first-run capture
-- =============================================================================
-- Rebuilt 2026-08-30 per Steven, after the 2026-08-30 popup-based setup flow
-- was rejected ("lose the autologin, it makes it more combesom. unless you
-- can pitch an actual functioning one from logs"). He also asked for two
-- concrete things: (1) automate the WHOLE login sequence, not just fill a
-- credentials file someone has to set up by hand or via a popup; (2) capture
-- the master account name/password from what he actually types the first
-- time, no separate setup command at all.
--
-- Found the real reference for what "the whole sequence" means: an old
-- native Mudlet Trigger, still sitting in a 2026-07-17 profile snapshot from
-- before the 2026-08-26 security cleanup removed it. It fired on the color
-- prompt and chained straight through: color -> continue -> master login
-- menu -> account name -> password -> view characters, all in one command.
-- Never viewed its actual credential values or copied its literal
-- mCommand -- same rebuild-the-behavior-not-the-code approach the original
-- 2026-08-26 replacement used -- but the STAGE SEQUENCE itself (which
-- prompt comes after which) is copied from it, cross-checked against this
-- session's own real corpus logs (docs/DSL_CommandRef.md now has these
-- patterns too).
--
-- ---- Design -----------------------------------------------------------------
-- 1. Credential VALUES never appear in this file, in git, or in any
--    exported/backup XML. They live in a plain Lua file OUTSIDE the repo
--    entirely, at getMudletHomeDir() .. "/MyDSL_login_credentials.lua" --
--    same location/format the 2026-08-26 version used, extended with one
--    new field:
--      return { account = "MasterAccountName", character = "CharacterName",
--                password = "MasterAccountPassword" }
--    `account` is new (2026-08-30) -- the master account NAME prompt was
--    never automated before this rebuild. `character`/`password` are
--    unchanged. All three are optional independently -- e.g. a file with
--    only `account`+`password` still auto-fills those two and leaves
--    character selection to the player, same as before.
--
-- 2. Written automatically now, not by a setup command or popup -- see
--    "first-run capture" below. A hand-edited file (or one carried over
--    from the previous version, missing `account`) still loads fine.
--
-- 3. Loaded with loadfile()+pcall, read-only, held only in a LOCAL upvalue
--    (`credentials`) -- never assigned onto MyDSL.Login or any other shared
--    table, so nothing else in the profile can read it back out.
--
-- 4. All auto-sent values use send(cmd, false) -- suppressed local echo,
--    never printed to the main window or any log.
--
-- 5. First-run CAPTURE (new, this rebuild): when `account` or `password`
--    isn't in the credentials file yet, this module doesn't send anything
--    at those two prompts -- it lets Steven type normally, but watches the
--    very next non-blank line after "What is your Master Account's name?"
--    / "Password:" (confirmed via real corpus: the player's own typed-line
--    echo is always the immediate next line, nothing else can arrive in
--    between) and treats that as the captured value. The captured PASSWORD
--    line is deleted from the console the instant it's captured
--    (deleteLine(), the same mechanism MyDSL_DataLayer_Combat.lua already
--    uses to remove a line) -- it existed on screen only as long as it
--    takes Mudlet to echo it back, same as normal typing, but doesn't
--    linger in scrollback or get written to any session log past that
--    point. The account name isn't masked -- same sensitivity level as a
--    username, and matches how the old trigger treated it too. Once both
--    are captured (or were already on file), they're written to the
--    credentials file together and used automatically on every future
--    connection.
--
-- 6. Toggleable per Principle 2 -- "mydsl login on|off" is now the master
--    switch for the WHOLE sequence (navigation + autofill + capture), not
--    just password autofill like before. Off means don't touch the login
--    flow at all -- every prompt handled entirely manually, same as before
--    this module ever existed. "mydsl login character on|off" is still the
--    separate, independent toggle for the "Player name:" (which character
--    to play) autofill -- unchanged reasoning from the 2026-08-26 version:
--    the master account/password are the same every session, but which
--    character to play often isn't, so it defaults OFF while the rest
--    defaults ON.
--
-- 7. Confirmed real corpus patterns this pass (now also in
--    docs/DSL_CommandRef.md):
--      "Do you want color? (Y/N) -> "
--      "[DSL] (Push Enter to Continue)"
--      "    Your selection? ->"                (appears at 2 different
--                                                 menus -- disambiguated by
--                                                 this module's own stage
--                                                 tracking, not by text)
--      "What is your Master Account's name? "
--      "Password: "
--      "    (M)aster Account Login"  / "    (V)iew Characters and Personal
--       information" -- selection letters "m" and "v", read directly off
--      this session's own real menu text, not guessed.
--
-- 8. Send-once-per-stage-per-connection: MyDSL.Login._stage tracks exactly
--    where in the sequence a fresh connection is; each trigger only acts
--    when the stage matches what it expects, and advances the stage after
--    firing. Reset to "color" on Mudlet's own sysConnectionEvent. A prompt
--    appearing out of expected order (stage already moved on, or the
--    module is disabled) is simply left alone -- this module only ever
--    acts on an exact stage+text match, never guesses.
--
-- 9. "mydsl login forget" -- new safety valve: first-run capture has no way
--    to know if what was typed was correct until the server accepts it: if
--    a typo gets captured and saved, this clears the credentials file so
--    the next connection re-captures cleanly.
-- =============================================================================

MyDSL       = MyDSL or {}
-- enabled = whole login-sequence automation (navigation + autofill +
-- first-run capture), default ON.
-- characterEnabled = "Player name:" (which character to play) autofill,
-- default OFF -- see design note 6.
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

local credentials = nil  -- local upvalue only -- see design note 3 above.
local credentialsPath = getMudletHomeDir() .. "/MyDSL_login_credentials.lua"

local function loadCredentials()
  local chunk = loadfile(credentialsPath)
  if not chunk then
    credentials = nil
    return false
  end
  local ok, result = pcall(chunk)
  if not ok or type(result) ~= "table" then
    credentials = nil
    return false
  end
  -- Field renamed name -> character 2026-08-29 -- fall back to the old key
  -- so an existing credentials file doesn't need hand-editing.
  local character = result.character or result.name
  credentials = {
    account   = (type(result.account) == "string" and result.account ~= "") and result.account or nil,
    character = (type(character) == "string" and character ~= "") and character or nil,
    password  = (type(result.password) == "string" and result.password ~= "") and result.password or nil,
  }
  -- "configured" means SOMETHING is saved -- account+password is the
  -- meaningful threshold (character alone with no password would still
  -- need the player to log in manually every time, not really "autofill").
  return credentials.account ~= nil and credentials.password ~= nil
end

-- writeCredentials(fields) -- merges into whatever's already on file rather
-- than overwriting wholesale, so capturing the password doesn't erase an
-- account/character that was already saved (or vice versa). Never echoes
-- any value.
local function writeCredentials(fields)
  local existing = {}
  local chunk = loadfile(credentialsPath)
  if chunk then
    local ok, result = pcall(chunk)
    if ok and type(result) == "table" then existing = result end
  end
  for k, v in pairs(fields) do existing[k] = v end
  local f, err = io.open(credentialsPath, "w")
  if not f then
    cecho("<red>[MyDSL] Login: couldn't write credentials file: " .. tostring(err) .. "<reset>\n")
    return false
  end
  f:write(string.format(
    "return { account = %q, character = %q, password = %q }\n",
    existing.account or "", existing.character or "", existing.password or ""
  ))
  f:close()
  return true
end

local function forgetCredentials()
  os.remove(credentialsPath)
  credentials = nil
  MyDSL.Login._configured = false
end

MyDSL.Login._configured = loadCredentials()
if MyDSL.Login._configured and credentials then
  local hasCharacter = credentials.character and "+character" or ""
  cecho("<dark_green>[MyDSL] Login autofill: credentials found (account" .. hasCharacter .. "+password).<reset>\n")
else
  cecho("<light_gray>[MyDSL] Login autofill: not configured yet -- log in normally once and it'll be captured automatically. 'mydsl login forget' clears a bad capture.<reset>\n")
end

-- ---- stage tracking ----------------------------------------------------------
-- One connection's worth of "where are we in the login sequence" state.
-- See design note 8. Values: "color", "banner", "mainmenu", "acctname",
-- "password", "mastermenu", "done".
MyDSL.Login._stage = "color"

-- capture state -- only meaningful while _stage is "acctname" or "password"
-- AND the relevant credential isn't on file yet. Cleared once captured.
local capturingField = nil  -- "account" | "password" | nil
local capturedAccount = nil

local function resetLoginState()
  MyDSL.Login._stage = "color"
  capturingField = nil
  capturedAccount = nil
end

-- Mudlet's own built-in connection event (real name, fires on connect).
MyDSL.Login._connHandler = registerAnonymousEventHandler("sysConnectionEvent", resetLoginState)

-- ---- navigation + autofill + capture triggers -------------------------------
-- Every trigger below checks MyDSL.Login.enabled AND its own expected stage
-- before doing anything -- see design note 8's "never guesses" note.

local function registerLoginTriggers()
  if MyDSL.Login._triggers.color then return end

  MyDSL.Login._triggers.color = tempRegexTrigger([[^Do you want color\? \(Y/N\) ->]], function()
    if not MyDSL.Login.enabled or MyDSL.Login._stage ~= "color" then return end
    send("y", false)
    MyDSL.Login._stage = "banner"
  end, 100)

  MyDSL.Login._triggers.banner = tempRegexTrigger([[^\[DSL\] \(Push Enter to Continue\)]], function()
    if not MyDSL.Login.enabled or MyDSL.Login._stage ~= "banner" then return end
    send("", false)
    MyDSL.Login._stage = "mainmenu"
  end, 100)

  -- "Your selection? ->" appears at both the main login menu (send "m" for
  -- Master Account Login) and the master account menu after password
  -- (send "v" for View Characters) -- same text, disambiguated by stage.
  MyDSL.Login._triggers.selection = tempRegexTrigger([[Your selection\? ->\s*$]], function()
    if not MyDSL.Login.enabled then return end
    if MyDSL.Login._stage == "mainmenu" then
      send("m", false)
      MyDSL.Login._stage = "acctname"
    elseif MyDSL.Login._stage == "mastermenu" then
      send("v", false)
      MyDSL.Login._stage = "done"
    end
  end, 100)

  MyDSL.Login._triggers.acctname_prompt = tempRegexTrigger([[^What is your Master Account.s name\?]], function()
    if not MyDSL.Login.enabled or MyDSL.Login._stage ~= "acctname" then return end
    if credentials and credentials.account then
      send(credentials.account, false)
      MyDSL.Login._stage = "password"
    else
      capturingField = "account"
      -- stage advances once the capture trigger below actually catches
      -- the typed line, not here -- if the player is still mid-typing
      -- we don't want a stray unrelated line advancing the stage early.
    end
  end, 100)

  -- Catches the very next non-blank line while capturingField=="account" --
  -- see design note 5 for why this is safe (confirmed real corpus: the
  -- player's own typed-line echo is always the immediate next line here,
  -- nothing else arrives in between).
  MyDSL.Login._triggers.acctname_capture = tempRegexTrigger([[^(.+)$]], function()
    if capturingField ~= "account" then return end
    capturedAccount = matches[2]
    capturingField = nil
    MyDSL.Login._stage = "password"
  end, 99)  -- lower priority than the other stage triggers, matches last

  MyDSL.Login._triggers.password = tempRegexTrigger([[^Password:\s*$]], function()
    if not MyDSL.Login.enabled or MyDSL.Login._stage ~= "password" then return end
    if credentials and credentials.password then
      send(credentials.password, false)
      MyDSL.Login._stage = "mastermenu"
    else
      capturingField = "password"
    end
  end, 100)

  -- Catches the next non-blank line while capturingField=="password" --
  -- same mechanism as the account capture, but also deletes the line
  -- (design note 5) since this one's an actual secret, not just a
  -- username-level value.
  MyDSL.Login._triggers.password_capture = tempRegexTrigger([[^(.+)$]], function()
    if capturingField ~= "password" then return end
    local capturedPassword = matches[2]
    capturingField = nil
    deleteLine()
    local fields = { password = capturedPassword }
    if capturedAccount then fields.account = capturedAccount end
    if writeCredentials(fields) then
      MyDSL.Login._configured = loadCredentials()
      cecho("<dark_green>[MyDSL] Login: captured and saved. Auto-login is ready for next time.<reset>\n")
    end
    MyDSL.Login._stage = "mastermenu"
  end, 99)

  MyDSL.Login._triggers.character = tempRegexTrigger([[^Player name:]], function()
    if not MyDSL.Login.characterEnabled or not credentials or not credentials.character then return end
    send(credentials.character, false)
  end, 100)
end

registerLoginTriggers()

-- ---- toggle + status aliases ---------------------------------------------

-- "mydsl login on|off" -- now the whole sequence's master switch (design
-- note 6), not just password autofill.
MyDSL.Login._aliases.toggle = tempAlias(
  [[^mydsl login (on|off)$]],
  [[MyDSL.Login.enabled = (matches[2] == "on")
    echo("Login autofill " .. matches[2] .. ".\n")]]
)

-- "mydsl login character on|off" -- independent toggle for "Player name:"
-- autofill. Defaults OFF -- see design note 6 for why.
MyDSL.Login._aliases.characterToggle = tempAlias(
  [[^mydsl login character (on|off)$]],
  [[MyDSL.Login.characterEnabled = (matches[2] == "on")
    echo("Login character-name autofill " .. matches[2] .. ".\n")]]
)

-- Deliberately never echoes the credential values themselves -- only
-- whether a file was found, what fields it has, and whether each toggle
-- is on.
MyDSL.Login._aliases.status = tempAlias(
  [[^mydsl login status$]],
  [[local mainState = MyDSL.Login.enabled and "ON" or "OFF"
    local charState = MyDSL.Login.characterEnabled and "ON" or "OFF"
    if MyDSL.Login._configured then
      echo("Login autofill: configured. Autofill=" .. mainState .. ", Character=" .. charState .. ".\n")
    else
      echo("Login autofill: NOT configured yet -- log in normally once, it captures automatically. Autofill=" .. mainState .. ", Character=" .. charState .. ".\n")
    end]]
)

-- "mydsl login forget" -- design note 9's safety valve.
MyDSL.Login._aliases.forget = tempAlias(
  [[^mydsl login forget$]],
  [[if MyDSL and MyDSL.Login then
      MyDSL.Login._forget()
    end]]
)

function MyDSL.Login._forget()
  forgetCredentials()
  echo("Login credentials cleared. Next login will be captured fresh.\n")
end
