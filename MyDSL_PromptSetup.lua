-- =============================================================================
-- MyDSL_PromptSetup.lua  --  One-click DSL prompt setup for brand-new characters
-- =============================================================================
-- Added 2026-07-09 per the maintainer: wants the maintainer's chosen `prompt <format>` string
-- applied to every freshly-rolled character, instead of typing it by hand
-- each time. CLAUDE.md's philosophy is explicit and non-negotiable here:
-- "Any game command sent by a module must be user-initiated (alias or
-- click)" -- a hook that fires the moment character creation finishes and
-- sends the command with zero action from the maintainer would violate that
-- directly, so this detects the moment and offers a one-click link instead
-- of sending anything on its own. Confirmed via AskUserQuestion 2026-07-09:
-- the maintainer picked "detect + clickable link" over a fully-automatic send.
--
-- Anchor: "The Gray Mist of Nothingness" -- the character-birth cutscene
-- room ("You are born now, to the World of Algoron..."). NOT the "WELCOME
-- TO DARK & SHATTERED LANDS (DSL)" banner that was the first idea -- PNP's
-- own DSL_PNP_Character.lua names that trigger "Login Trigger" and confirms
-- it fires on every login, existing characters included, which would nag
-- the maintainer every session instead of just once at creation. Corpus-checked:
-- "Gray Mist of Nothingness" appears in the one fresh-character-creation
-- log from 2026-07-09 and in zero other logs across the whole recent
-- history (established characters never see it) --
-- reasonably confident this is creation-exclusive, though if DSL ever
-- reuses this exact room+cutscene for some other mechanic (a recall-to-
-- the-void spell, e.g.) this would need re-scoping.
-- =============================================================================

MyDSL              = MyDSL              or {}
MyDSL.PromptSetup  = MyDSL.PromptSetup  or {}

local PS = MyDSL.PromptSetup

-- the maintainer's exact chosen format string (2026-07-09) -- verbatim, not
-- reconstructed, since a single wrong {code/%code would silently break it.
PS.promptString = [[prompt {B[{R%h{G/%H{GHP{x {B| {C%m{c/%M{CM{x {B| {G%v{y/%V{yMV{x {B]{x {B[{x {Y%S{x {B|{x %a {B| {G%l{x {B|{x {p%f{x {B]{x%c{B==-{x%d {g- %t{x {B:: [{W%r{x{B] :: [{x%e{x{B]-=={x%c]]

PS._triggers = PS._triggers or {}
PS._aliases  = PS._aliases  or {}
local function deregister()
  for _, id in pairs(PS._triggers) do pcall(killTrigger, id) end
  for _, id in pairs(PS._aliases) do pcall(killAlias, id) end
  PS._triggers = {}
  PS._aliases = {}
end
deregister()

function PS.apply()
  send(PS.promptString)
  cecho("\n<cyan>[MyDSL.PromptSetup]<reset> Prompt command sent.\n")
end

-- Manual path -- always available, not just at creation (e.g. to reapply
-- on an existing character, or if the auto-detected link gets missed).
PS._aliases.setPrompt = tempAlias(
  "^mydsl setprompt$",
  [[if MyDSL and MyDSL.PromptSetup then MyDSL.PromptSetup.apply() end]]
)

-- Detected path -- one-shot nudge right after a brand-new character is born.
PS._triggers.birth = tempRegexTrigger(
  "^The Gray Mist of Nothingness$",
  function()
    dechoLink(
      "\n<255,204,68>[MyDSL] New character detected!<r> <136,204,255>[Click here to set your DSL prompt]<r>\n",
      "if MyDSL and MyDSL.PromptSetup then MyDSL.PromptSetup.apply() end",
      "Send the prompt command",
      true)
  end
)

debugc("[MyDSL] PromptSetup loaded.")
