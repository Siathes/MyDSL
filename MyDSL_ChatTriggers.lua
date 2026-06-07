-- =============================================================================
-- MyDSL_ChatTriggers.lua  --  Layer 3: Chat channel routing
-- =============================================================================
-- Intercepts chat channel lines and routes them to EMCO tabs via
-- demonnic.chat:append(). Lines are removed from the main console.
-- Must load LAST — demonnic.chat is created by ChatWrapper (position 8).
-- =============================================================================

MyDSL              = MyDSL              or {}
MyDSL.ChatTriggers = MyDSL.ChatTriggers or {}

-- Kill any triggers from a previous load.
MyDSL.ChatTriggers._triggers = MyDSL.ChatTriggers._triggers or {}
local function deregisterTriggers()
  for _, id in pairs(MyDSL.ChatTriggers._triggers) do
    pcall(killAnonymousEventHandler, id)
    pcall(killTrigger, id)
  end
  MyDSL.ChatTriggers._triggers = {}
end
deregisterTriggers()


------------------------------------------------------------------------
-- HELPER  — register one regex trigger that routes to a named tab
------------------------------------------------------------------------

local function route(tabName, pattern)
  local id = tempRegexTrigger(pattern, function()
    if demonnic and demonnic.chat then
      demonnic.chat:append(tabName)
    end
    -- deleteLine() removed for testing — add back once routing confirmed
  end)
  MyDSL.ChatTriggers._triggers[#MyDSL.ChatTriggers._triggers + 1] = id
end


------------------------------------------------------------------------
-- TELLS
-- "Kien tells you: ..."  /  "You tell Kien: ..."
------------------------------------------------------------------------
route("Tells", [[\w+ tells you:]])
route("Tells", [[You tell \w+:]])

------------------------------------------------------------------------
-- GROUP CHAT
-- "Kien group-says: ..."  /  "Kien group-tells you: ..."
------------------------------------------------------------------------
route("Group", [[\w+ group-says:]])
route("Group", [[\w+ group-tells you:]])

------------------------------------------------------------------------
-- OOC
-- "[OOC] ..."  /  "[OCLAN] ..."  /  "[OKING] ..."
------------------------------------------------------------------------
route("OOC", [=[\[OOC\]]=])
route("OOC", [=[\[OCLAN\]]=])
route("OOC", [=[\[OKING\]]=])

------------------------------------------------------------------------
-- CITY  (broad public channels)
-- gossip / kingdom / clan / auction / shout / yell /
-- NEWBIE / congratulates / QUEST / pray / broadcast
------------------------------------------------------------------------
route("City", [[\w+ gossips:]])
route("City", [[\w+ kingdom-says:]])
route("City", [[\w+ clan-says:]])
route("City", [[\w+ auctions:]])
route("City", [[\w+ shouts:]])
route("City", [[\w+ yells:]])
route("City", [[NEWBIE:]])
route("City", [[\w+ congratulates]])
route("City", [[QUEST:]])
route("City", [[\w+ prays:]])
route("City", [[\w+ broadcasts:]])

------------------------------------------------------------------------
-- LOCAL  (room-level speech)
-- "Kien says: ..."  /  "Kien whispers: ..."
------------------------------------------------------------------------
route("Local", [[\w+ says:]])
route("Local", [[\w+ whispers:]])

debugc("[MyDSL] ChatTriggers loaded.")
