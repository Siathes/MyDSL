-- =============================================================================
-- MyDSL_ItemReference.lua  --  Layer 4: Item lore/stats display
-- =============================================================================
-- Listens for "MyDSL.itemlore.updated" and renders the item record in the
-- MyDSL_ItemReference window. Hidden by default, auto-shows on fresh
-- identify/lore data. Never sends commands or modifies the DB. Directly
-- modeled on MyDSL_CreatureReference.lua (Bestiary) -- same window-
-- lifecycle pattern, same status/show/hide/rebuild/font command family
-- from day one (matching the standard set 2026-07-15 for Scan/Group/
-- Bestiary), same "DB first, live state as fallback" render logic.
-- =============================================================================

MyDSL                = MyDSL                or {}
MyDSL.ItemReference  = MyDSL.ItemReference  or {}
local IR = MyDSL.ItemReference

for _, id in pairs(IR._handlers or {}) do pcall(killAnonymousEventHandler, id) end
for _, id in pairs(IR._aliases  or {}) do pcall(killAlias, id) end

IR._handlers = {}
IR._aliases  = {}
IR._mc       = IR._mc or {}

local IR_WIN = "MyDSL_ItemReference"
local IR_MC  = "MyDSL_ItemReference_MC"

-- getFontSize(IR_WIN, 8) fallback below: updated 2026-08-23 from 9 to 8
-- to match the maintainer's real long-tuned live size (MyDSL_windowfonts.lua),
-- confirmed via a full settings-vs-defaults audit -- this fallback only
-- ever applies to a brand-new window with nothing saved yet, but a
-- genuine fresh install was shipping the wrong size until re-tuned.


------------------------------------------------------------------------
-- Local helpers
------------------------------------------------------------------------

-- No trim() here on purpose -- confirmed MyDSL_CreatureReference.lua's
-- own equivalent normalization doesn't trim either (its render(name)
-- just does name:lower():gsub(...) directly); every real caller already
-- passes an already-clean string (an alias's matches[2], or rec.name
-- from a merge event). Real bug found live 2026-07-16: this used to call
-- a bare trim() assuming it was a shared global -- it isn't; every file
-- in this profile that needs it defines its own local copy, and this
-- file never did.
local function itemKey(name)
  return tostring(name or ""):lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
end


------------------------------------------------------------------------
-- render(name)  —  draws the item record for `name`
------------------------------------------------------------------------
-- DB first (MyDSL_ItemLore.lua), falls back to whichever live capture
-- (MyDSL.State.itemlore) is most recent if the DB somehow has no entry
-- yet (e.g. mid-capture, or DB failed to load) -- same fallback shape as
-- CreatureReference.render().

function IR.render(name)
  clearWindow(IR_MC)
  if not name or name == "" then
    decho(IR_MC, "<68,68,68>No item selected.\n<r>")
    return
  end

  local rec = nil
  if MyDSL.ItemLore and MyDSL.ItemLore.get then
    rec = MyDSL.ItemLore.get(itemKey(name))
  end
  -- Bug found live 2026-08-29 (the maintainer: "after a cast ident item, then if i
  -- click an item it only updates the name, not the info"): this fallback
  -- used to apply unconditionally, so clicking any item with no DB record
  -- yet redrew the PREVIOUS identify's stats under the newly-clicked
  -- item's name -- wrong data, not just stale data. Only use the live
  -- capture as a fallback when it's actually a record for this same item.
  if not rec and MyDSL.State.itemlore and MyDSL.State.itemlore.key == itemKey(name) then
    rec = MyDSL.State.itemlore
  end

  -- Rule lines removed 2026-07-16, per the maintainer ("remove some vertical
  -- spacing... to reduce the amount that need to scroll"), same treatment
  -- as Bestiary/Focus the same day.
  decho(IR_MC, string.format("<255,255,153>%s<r>\n", name))

  if not rec then
    decho(IR_MC, "<136,136,136>No item data yet.\n<r>")
    decho(IR_MC, "<102,102,102>Try `identify <name>` or `lore <name>` in-game.\n<r>")
    return
  end

  -- Type / Level / Material
  decho(IR_MC, string.format(
    "<136,136,136>Type: <204,204,204>%-12s <136,136,136>Lvl: <204,204,204>%-4s <136,136,136>Material: <204,204,204>%s<r>\n",
    rec.itemType or "?", rec.level and tostring(rec.level) or "?", rec.material or "?"))

  -- Weight / Value
  decho(IR_MC, string.format(
    "<136,136,136>Weight: <204,204,204>%-8s <136,136,136>Value: <204,204,204>%s<r>\n",
    rec.weight and tostring(rec.weight) or "?", rec.value and tostring(rec.value) or "?"))

  -- Extra flags
  if rec.extraFlags then
    decho(IR_MC, string.format("<136,136,136>Flags: <170,170,255>%s<r>\n", rec.extraFlags))
  end

  -- Weapon block
  -- "or rec.damageAvg" added 2026-07-18 -- same real gap as the hover
  -- tooltip fix (MyDSL.buildItemStatsSuffix()): scrape-imported weapons
  -- only ever have damageAvg (a precomputed average), never damageDice
  -- (exact dice notation only comes from a real in-game `identify`) --
  -- the damage line was gated strictly on damageDice, so a scrape-only
  -- weapon's real average damage was silently never shown at all.
  if rec.weaponType or rec.damageDice or rec.damageAvg then
    decho(IR_MC, "<255,204,68>Weapon<r>\n")
    if rec.weaponType then decho(IR_MC, string.format("  <136,136,136>Type: <204,204,204>%s<r>\n", rec.weaponType)) end
    if rec.damageDice then
      decho(IR_MC, string.format("  <136,136,136>Damage: <204,204,204>%s (avg %s)<r>\n",
        rec.damageDice, rec.damageAvg and tostring(rec.damageAvg) or "?"))
    elseif rec.damageAvg then
      decho(IR_MC, string.format("  <136,136,136>Damage: <204,204,204>avg %s<r>\n", tostring(rec.damageAvg)))
    end
    if rec.weaponFlags then decho(IR_MC, string.format("  <136,136,136>Flags: <255,215,65>%s<r>\n", rec.weaponFlags)) end
  end

  -- Armor block
  if rec.armorClass then
    local ac = rec.armorClass
    decho(IR_MC, "<255,204,68>Armor<r>\n")
    decho(IR_MC, string.format(
      "  <136,136,136>AC: <204,204,204>%s pierce, %s bash, %s slash, %s magic<r>\n",
      tostring(ac.pierce), tostring(ac.bash), tostring(ac.slash), tostring(ac.magic)))
  end

  if rec.size or rec.condition then
    decho(IR_MC, string.format(
      "<136,136,136>Size: <204,204,204>%-8s <136,136,136>Condition: <204,204,204>%s<r>\n",
      rec.size or "?", rec.condition or "?"))
  end

  -- Container block
  if rec.capacity then
    decho(IR_MC, "<255,204,68>Container<r>\n")
    decho(IR_MC, string.format("  <136,136,136>Capacity: <204,204,204>%s#  Max weight: %s#<r>\n",
      tostring(rec.capacity), rec.maxWeight and tostring(rec.maxWeight) or "?"))
    if rec.weightMultiplier then
      decho(IR_MC, string.format("  <136,136,136>Weight multiplier: <204,204,204>%s%%<r>\n", tostring(rec.weightMultiplier)))
    end
  end

  -- Spell charges (wand) / spell list (potion/pill/scroll)
  -- Fixed 2026-07-18, real bug found live (the maintainer's screenshot: "Charges:
  -- nil of level nil 'color spray'"). This line assumed spellCharges
  -- always has all three fields, true only for a real in-game `identify`
  -- capture -- since scrape-imported records can now populate spellCharges
  -- with just the spell name (see MyDSL_ItemLore.lua's importScraped()),
  -- charges/level being genuinely unknown printed literal "nil" instead of
  -- this file's own established "?" placeholder convention (already used
  -- just above for rec.material/rec.maxWeight/rec.size).
  if rec.spellCharges then
    local sc = rec.spellCharges
    decho(IR_MC, string.format(
      "<136,136,136>Charges: <204,204,204>%s of level %s '%s'<r>\n",
      sc.charges and tostring(sc.charges) or "?",
      sc.level and tostring(sc.level) or "?",
      tostring(sc.spell)))
  end
  if rec.spellList then
    decho(IR_MC, string.format("<136,136,136>Spells (level %s):<r>\n", tostring(rec.spellList.level)))
    decho(IR_MC, string.format("  <170,170,255>%s<r>\n", table.concat(rec.spellList.spells, ", ")))
  end

  -- Drink
  if rec.drinkLiquid then
    decho(IR_MC, string.format("<136,136,136>Holds: <204,204,204>%s<r>\n", rec.drinkLiquid))
  end

  -- Affects (the real bonuses/enchants -- identify-only, never from lore).
  -- Two per line, 2026-07-16, per the maintainer ("make 2 columns... reduce the
  -- amount that need to scroll") -- a full side-by-side column redesign
  -- of the whole window risks looking worse without live iteration, but
  -- pairing affects (usually the longest repeating list in a record) cuts
  -- this specific block's line count roughly in half at no design risk.
  if rec.affects and #rec.affects > 0 then
    decho(IR_MC, "<255,204,68>Affects<r>\n")
    for i = 1, #rec.affects, 2 do
      local a = rec.affects[i]
      local cell = string.format("<170,170,255>%s <136,136,136>by <204,204,204>%s<r>",
        a.stat, tostring(a.amount))
      local b = rec.affects[i + 1]
      if b then
        cell = cell .. "   " .. string.format("<170,170,255>%s <136,136,136>by <204,204,204>%s<r>",
          b.stat, tostring(b.amount))
      end
      decho(IR_MC, "  " .. cell .. "\n")
    end
  end

  -- Completeness + source/date
  local state = "unknown"
  if MyDSL.ItemLore and MyDSL.ItemLore.knownState then
    state = MyDSL.ItemLore.knownState(itemKey(name))
  end
  local stateColor = (state == "known" and "68,221,68") or (state == "seen" and "68,204,221") or "221,204,68"
  decho(IR_MC, string.format("<136,136,136>Status: <%s>%s<r>", stateColor, state))
  if rec.source then decho(IR_MC, string.format("  <136,136,136>(source: <204,204,204>%s<r><136,136,136>)<r>", rec.source)) end
  decho(IR_MC, "\n")
  if rec.lastIdentified then
    decho(IR_MC, string.format("<136,136,136>Last identified: <204,204,204>%s<r>\n",
      os.date("%Y-%m-%d", rec.lastIdentified)))
  end
end


------------------------------------------------------------------------
-- onItemUpdate()  —  handler for MyDSL.itemlore.updated
------------------------------------------------------------------------

function IR.onItemUpdate()
  local rec = MyDSL.State.itemlore
  if not rec or not rec.name then return end
  IR.render(rec.name)
  if MyDSL.Windows then MyDSL.Windows.show(IR_WIN) end
end


------------------------------------------------------------------------
-- show() / hide() / status() / rebuild() / setFont()
------------------------------------------------------------------------

function IR.show()
  if MyDSL.Windows then MyDSL.Windows.show(IR_WIN) end
end

function IR.hide()
  if MyDSL.Windows then MyDSL.Windows.hide(IR_WIN) end
end

-- setTitle(title) -- real gap fix, 2026-08-26 (command-parity sweep).
function IR.setTitle(title)
  title = tostring(title or ""):match("^%s*(.-)%s*$")
  if title == "" then title = "Item Reference" end
  MyDSL.Windows.setTitle(IR_WIN, title)
  local win = MyDSL.Windows.get and MyDSL.Windows.get(IR_WIN)
  if win and win.setTitle then pcall(function() win:setTitle(title) end) end
  echo("Item Reference title=" .. title .. "\n")
end

function IR.status()
  decho(string.format(
    "<136,204,255>[MyDSL] Item Reference: font=%d<r>\n",
    MyDSL.Windows.getFontSize(IR_WIN, 8)
  ))
end


function IR.setFont(size)
  size = tonumber(size)
  if not size then echo("usage: item font <size>\n"); return end
  if size < 6 then size = 6 end
  if size > 18 then size = 18 end
  if IR._mc.item then IR._mc.item:setFontSize(size) end
  MyDSL.Windows.setFontSize(IR_WIN, size)
  echo("MyDSL_ItemReference font=" .. tostring(size) .. "\n")
end


------------------------------------------------------------------------
-- init()  —  safe to re-call on reload
------------------------------------------------------------------------

function IR.ensureUI()
  local irWin = MyDSL.Windows.ensure(IR_WIN)
  -- Visual pass v2 "One Bar, Renamed and Colored" (locked spec, 2026-08-26).
  if irWin and irWin.setTitle then
    pcall(function() irWin:setTitle(MyDSL.Windows.getTitle(IR_WIN, "Item Reference")) end)
  end
  if not IR._mc.item then
    IR._mc.item = Geyser.MiniConsole:new({
      name      = IR_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      scrollBar = true,
    }, irWin)
  end

  local itemFont = MyDSL.Windows.getFontSize(IR_WIN, 8)
  if IR._mc.item then IR._mc.item:setFontSize(itemFont) end

  -- Adaptive word wrap -- same fix applied to Bestiary/Focus 2026-07-16
  -- (same "reduce scrolling" ask); static wrapWidth=300 didn't track
  -- this window's actual docked width. Shared helper (MyDSL_WindowRegistry.lua)
  -- handles the "must run after setFontSize()" ordering and the per-console
  -- once-only guard -- see its own comment for why the guard lives on the
  -- console object itself, not a module-level flag.
  MyDSL.Windows.enableAdaptiveWrap(IR._mc.item, itemFont)

  if MyDSL.Theme and MyDSL.Theme.styleConsole then
    MyDSL.Theme.styleConsole(IR._mc.item, IR_WIN, itemFont)
  end
end

function IR.init()
  IR.ensureUI()

  IR._handlers.itemUpdated = registerAnonymousEventHandler(
    "MyDSL.itemlore.updated",
    function() IR.onItemUpdate() end
  )

  IR._handlers.themeChanged = registerAnonymousEventHandler(
    "MyDSL.theme.changed",
    function()
      if MyDSL.Theme and MyDSL.Theme.styleConsole then
        MyDSL.Theme.styleConsole(IR._mc.item, IR_WIN, MyDSL.Windows.getFontSize(IR_WIN, 8))
      end
    end
  )

  -- "item <name>" -- confirmed not real DSL vocabulary (checked
  -- DSL_Helpfiles/, no collision), same naming pattern as "bestiary".
  -- Sends `identify <name>` (the fuller of the two capture commands, same
  -- choice bestiary made sending `creaturelore <name>` over `lore <name>`)
  -- and shows the window with whatever's in the DB already (partial or full).
  IR._aliases.itemLookup = tempAlias(
    "^item (.+)$",
    [[
      local name = matches[2]
      local fontSize = name:match("^font%s+(%d+)$")
      local titleText = name:match("^title%s+(.+)$")
      local mapGround, mapTarget = name:match("^map%s+(.-)%s*=%s*(.+)$")
      if name == "hide" then
        if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.hide() end
      elseif name == "show" then
        if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.show() end
      elseif name == "status" then
        if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.status() end
      elseif fontSize then
        if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.setFont(fontSize) end
      elseif titleText then
        if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.setTitle(titleText) end
      elseif mapGround then
        -- "item map <ground item text> = <inventory/equipment item name>"
        -- added 2026-07-16, the manual override for the real fraction of
        -- items the automatic fuzzy ground-to-inventory match correctly
        -- declines (no shared substring). Added as a branch here, not a
        -- separate alias, because a standalone "^item map (.+)$"-shaped
        -- alias would also match this dispatcher's own catch-all below
        -- and send "identify map ... = ..." to the server as a real game
        -- command -- confirmed by re-reading this exact alias before
        -- adding the feature.
        if MyDSL and MyDSL.setGroundItemOverride then
          MyDSL.setGroundItemOverride(mapGround, mapTarget)
        end
      else
        send("identify " .. name, false)
        if MyDSL and MyDSL.ItemReference then
          MyDSL.ItemReference.render(name)
          MyDSL.ItemReference.show()
        end
      end
    ]]
  )

  IR.render(nil)

  debugc("[MyDSL] ItemReference loaded.")
end


------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

IR.init()
