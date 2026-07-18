--[[=====================================================================
  MyDSL.PromptView v1.0
  ----------------------------------------------------------------------
  Prompt gag system for MyDSL Observer UI.

  Mudlet shows three server prompt lines in the main console.
  In UI mode (enabled=true), Mudlet triggers call deleteLine() to gag
  those lines. The PromptBar overlay (future module) replaces them
  visually with styled bars.

  This module manages only the toggle state and per-character persistence.
  All trigger scripts live in the Mudlet Trigger editor — see bottom of
  this file for the exact specs to enter manually.

  Contract:
    - MyDSL.Prompt.enabled is the single boolean controlling gag state.
    - Triggers always fire; they check enabled before calling deleteLine().
    - State is character-bound: MyDSL/prompt_<CharName>.lua, etc.
    - Default: enabled=true (UI mode on, prompt gagged).
    - Alias: mydsl prompt on|off|toggle
=====================================================================]]--

MyDSL        = MyDSL        or {}
MyDSL.Prompt = MyDSL.Prompt or {}

local P = MyDSL.Prompt
P.version = "PromptView v1.0"

-- Default to enabled (UI mode on) on first load.
-- The 'if nil' guard preserves an explicit false across script reloads.
if P.enabled == nil then P.enabled = true end

-- Handler IDs for clean deregistration on reload.
P._handlers = P._handlers or {}


------------------------------------------------------------------------
-- PERSISTENCE
------------------------------------------------------------------------

local function saveDir()
  return getMudletHomeDir() .. "/MyDSL"
end

local function saveFile(charName)
  return saveDir() .. "/prompt_" .. charName .. ".lua"
end

local function ensureSaveDir()
  pcall(function() os.execute('mkdir -p "' .. saveDir():gsub('"', '\\"') .. '"') end)
end

function P.save(charName)
  charName = charName or (MyDSL.Char and MyDSL.Char())
  if not charName then return end
  ensureSaveDir()
  table.save(saveFile(charName), { enabled = P.enabled })
end

-- REAL BUG, found live 2026-07-11: Mudlet's real table.load(file, target)
-- does not return anything -- it unpickles INTO an explicit second-
-- argument table (confirmed in Mudlet's own bundled source). This used
-- to call table.load(path) with no second argument, so `data` was always
-- nil -- the pretty-prompt toggle never actually survived a restart
-- (same bug found across ~10 call sites project-wide the same day -- see
-- MyDSL_DataLayer.lua's MyDSL.load() for the full writeup).
function P.load(charName)
  if not charName then return end
  local path = saveFile(charName)
  local f = io.open(path, "r")
  if not f then return end
  f:close()
  local data = {}
  local ok = pcall(table.load, path, data)
  if ok and data.enabled ~= nil then
    P.enabled = data.enabled == true
  end
end


------------------------------------------------------------------------
-- CHARACTER LIFECYCLE
------------------------------------------------------------------------

function P.onLogin(charName)
  P.load(charName)
end


------------------------------------------------------------------------
-- TOGGLE API
------------------------------------------------------------------------

function P.setEnabled(v)
  P.enabled = v == true
  local charName = MyDSL.Char and MyDSL.Char()
  if charName then P.save(charName) end
  cecho("\n<cyan>[MyDSL.Prompt]<reset> UI mode "
    .. (P.enabled and "ON (prompt gagged)" or "OFF (raw prompt visible)") .. "\n")
end

function P.toggle()
  P.setEnabled(not P.enabled)
end


------------------------------------------------------------------------
-- ALIAS HANDLER
------------------------------------------------------------------------

function P._cmd(arg)
  arg = ((arg or ""):match("^%s*(.-)%s*$") or ""):lower()
  if arg == "on" then
    P.setEnabled(true)
  elseif arg == "off" then
    P.setEnabled(false)
  elseif arg == "toggle" or arg == "" then
    P.toggle()
  else
    cecho("\n<cyan>[MyDSL.Prompt]<reset> Usage: mydsl prompt on|off|toggle\n")
  end
end


------------------------------------------------------------------------
-- BOOT
------------------------------------------------------------------------

function P.installAliases()
  if P.aliasesInstalled then return end
  tempAlias([[^mydsl prompt(?:\s+(.*))?$]], [[MyDSL.Prompt._cmd(matches[2])]])
  P.aliasesInstalled = true
end

function P.installHandlers()
  for _, id in ipairs(P._handlers) do
    pcall(killAnonymousEventHandler, id)
  end
  P._handlers = {}

  local ok, id = pcall(function()
    return registerAnonymousEventHandler("MyDSL.login.updated", function(_, loginData)
      local charName = loginData and loginData.name
      if not charName then charName = MyDSL.Char and MyDSL.Char() end
      if charName then P.onLogin(charName) end
    end)
  end)
  if ok and id then table.insert(P._handlers, id) end
end

function P.boot()
  P.installAliases()
  P.installHandlers()
  -- If already logged in (script reloaded mid-session), load state now.
  local charName = MyDSL.Char and MyDSL.Char()
  if charName then P.load(charName) end
  if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then
    cecho("\n<cyan>[MyDSL.Prompt]<reset> loaded " .. P.version
      .. " enabled=" .. tostring(P.enabled) .. "\n")
  end
end

P.boot()


-- =============================================================================
-- TRIGGERS REQUIRED IN MUDLET TRIGGER EDITOR (not created by this script)
-- =============================================================================
-- Trigger 1: MyDSL_PromptGag_Vitals
--   Pattern type: Perl Regex
--   Pattern:      ^\[%d+/%d+HP
--   Script:       if MyDSL and MyDSL.Prompt and MyDSL.Prompt.enabled then deleteLine() end
--
-- Trigger 2: MyDSL_PromptGag_Location
--   Pattern type: Perl Regex
--   Pattern:      ^==-
--   Script:       if MyDSL and MyDSL.Prompt and MyDSL.Prompt.enabled then deleteLine() end
-- =============================================================================
