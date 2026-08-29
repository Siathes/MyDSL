-- =============================================================================
-- MyDSL_MapperMenu.lua -- MyDSL suite quick-launch shortcuts on the map's
-- right-click menu, added 2026-08-29 (standalone-mapper design pass -- see
-- docs/MAPPER_REDESIGN.md).
-- =============================================================================
-- Deliberately its own file, never added to DSL_Generic_Mapper.xml: that
-- file is meant to be distributable as a standalone DSL mapper to players
-- who don't run the rest of MyDSL, so nothing MyDSL-specific belongs in it.
-- This file only exists when MyDSL itself is loaded, so every menu item it
-- adds is naturally MyDSL-only -- no runtime "if MyDSL then" guard is
-- needed for that reason, but each item still soft-checks the specific
-- target module before calling it, so a missing/renamed module degrades to
-- "menu item does nothing" rather than a hard error.
--
-- Uses Mudlet's own native addMapEvent()/mapAddOnEvent right-click-menu
-- mechanism (confirmed real via direct C++ source read, not a workaround --
-- see docs/MAPPER_REDESIGN.md), grouped under one "MyDSL" submenu via
-- addMapEvent's parent-key argument so they're visually separate from
-- DSL_Generic_Mapper.xml's own native/safe-delete entries.
--
-- Scope note: these are quick-launch shortcuts to windows that already
-- exist (CR.show()/IR.show()/M.show(), the same functions "bestiary show"/
-- "itemref show"/"mydsl location show" already call) -- NOT room-specific
-- lookups. A "mobs/items known in THIS room" feature would need a real
-- room-to-mob/item association data model that doesn't exist anywhere in
-- CreatureLore/ItemLore today (confirmed by grep) -- that's future design
-- work, not something this file fakes a shallow version of.
-- =============================================================================

MyDSL = MyDSL or {}
MyDSL.MapperMenu = MyDSL.MapperMenu or {}
local MM = MyDSL.MapperMenu

MM.MENU_PARENT_KEY = "mydslSuite"

local ITEMS = {
  { key = "mydslShowLocation", label = "Show Room Picture (MyDSL)" },
  { key = "mydslShowBestiary", label = "Open Bestiary (MyDSL)" },
  { key = "mydslShowItemRef",  label = "Open Item Reference (MyDSL)" },
}

function MM.eventHandler(event, mapEvent, ...)
  if event == "mapAddOnEvent" then
    if mapEvent == "mydslShowLocation" then
      if MyDSL.Location and MyDSL.Location.show then MyDSL.Location.show() end
    elseif mapEvent == "mydslShowBestiary" then
      if MyDSL.CreatureReference and MyDSL.CreatureReference.show then MyDSL.CreatureReference.show() end
    elseif mapEvent == "mydslShowItemRef" then
      if MyDSL.ItemReference and MyDSL.ItemReference.show then MyDSL.ItemReference.show() end
    end
  elseif event == "mapOpenEvent" then
    if not (getMapEvents and addMapEvent) then return end
    local mapEvents = getMapEvents()
    if not mapEvents[MM.MENU_PARENT_KEY] then
      addMapEvent(MM.MENU_PARENT_KEY, "mapAddOnEvent", "", "MyDSL")
    end
    for _, item in ipairs(ITEMS) do
      if not mapEvents[item.key] then
        addMapEvent(item.key, "mapAddOnEvent", MM.MENU_PARENT_KEY, item.label)
      end
    end
  end
end

registerAnonymousEventHandler("mapAddOnEvent", "MyDSL.MapperMenu.eventHandler")
registerAnonymousEventHandler("mapOpenEvent", "MyDSL.MapperMenu.eventHandler")
