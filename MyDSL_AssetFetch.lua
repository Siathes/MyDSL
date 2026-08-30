-- =============================================================================
-- MyDSL_AssetFetch.lua -- optional media asset downloader
-- =============================================================================
-- Sounds/RoomPics are real, sizeable binary assets (9.9MB / 345MB) that don't
-- belong in the git repo or the base package -- this module fetches them
-- on-demand from a GitHub Release instead. Portraits are deliberately NOT
-- offered here: character portraits are personal, not shared assets.
--
-- STRICTLY OPT-IN, per the maintainer (2026-08-29): "if we add the sounds and extra
-- files for mydsl there should be an option to import not a default on."
-- Nothing in this file runs automatically -- every fetch is a player-typed
-- command. Uses downloadFile()/unzipAsync(), both confirmed against
-- Mudlet's own test suite (Networking_spec.lua, UI_spec.lua's
-- unzipAsync coverage) -- see docs/TODO.md's asset-distribution plan for
-- the full signature research.
-- =============================================================================

MyDSL = MyDSL or {}
MyDSL.AssetFetch = MyDSL.AssetFetch or {}
local AF = MyDSL.AssetFetch

for _, id in pairs(AF._handlers or {}) do pcall(killAnonymousEventHandler, id) end
AF._handlers = {}
AF._active = AF._active or nil  -- name of the asset currently downloading/unzipping, or nil

local RELEASE_BASE = "https://github.com/Siathes/MyDSL/releases/download/assets-v1/"

-- extractDir = getMudletHomeDir() (profile root) for both: each zip's own
-- entries already carry the right relative subfolder ("Sounds/...",
-- "MyDSL/roompics/...") so extracting at the profile root recreates them
-- in the right place -- confirmed by listing both zips' contents directly.
AF.assets = {
  sounds = {
    label = "Sounds",
    url = RELEASE_BASE .. "Sounds.zip",
    sizeHint = "~9.9MB, 89 files",
  },
  roompics = {
    label = "RoomPics",
    url = RELEASE_BASE .. "RoomPics.zip",
    sizeHint = "~345MB, 117 files",
  },
}

local function ce(msg) cecho("\n<cyan>[MyDSL.Assets]<reset> " .. tostring(msg) .. "\n") end

local function zipDownloadPath(name)
  return getMudletHomeDir() .. "/" .. AF.assets[name].label .. "_download.zip"
end

function AF.status()
  ce("Optional assets (never auto-fetched, run 'mydsl assets fetch <name>'):")
  for name, a in pairs(AF.assets) do
    echo("  " .. name .. " -- " .. a.label .. " (" .. a.sizeHint .. ")\n")
  end
  if AF._active then
    echo("  currently fetching: " .. AF._active .. "\n")
  end
end

function AF.fetch(name)
  name = string.lower(tostring(name or ""))
  local asset = AF.assets[name]
  if not asset then
    ce("unknown asset '" .. tostring(name) .. "' -- valid: sounds, roompics, or 'all'")
    return
  end
  if AF._active then
    ce("already fetching " .. AF._active .. " -- wait for it to finish first")
    return
  end
  if not downloadFile then
    ce("downloadFile() not available in this Mudlet build -- cannot fetch assets")
    return
  end

  AF._active = name
  local target = zipDownloadPath(name)
  ce("fetching " .. asset.label .. " (" .. asset.sizeHint .. ")...")
  local queued = downloadFile(target, asset.url)
  if not queued then
    ce(asset.label .. ": downloadFile() refused to queue the request")
    AF._active = nil
  end
end

-- "mydsl assets fetch all" -- queues sounds first; roompics starts from the
-- sysDownloadDone handler below once sounds finishes, since AF._active only
-- tracks one fetch at a time (deliberately -- avoids two downloadFile()
-- calls racing to reuse Mudlet's single download queue).
function AF.fetchAll()
  AF._queue = { "sounds", "roompics" }
  AF.fetch(table.remove(AF._queue, 1))
end

local function afterFetchDone()
  AF._active = nil
  if AF._queue and #AF._queue > 0 then
    AF.fetch(table.remove(AF._queue, 1))
  else
    AF._queue = nil
  end
end

AF._handlers.downloadDone = registerAnonymousEventHandler("sysDownloadDone", function(_, localFile, bytesWritten)
  local name = AF._active
  if not name then return end
  local asset = AF.assets[name]
  if not asset or localFile ~= zipDownloadPath(name) then return end

  ce(asset.label .. ": downloaded (" .. tostring(bytesWritten) .. " bytes), extracting...")
  if not unzipAsync then
    ce(asset.label .. ": unzipAsync() not available in this Mudlet build -- zip left at " .. localFile)
    afterFetchDone()
    return
  end
  unzipAsync(localFile, getMudletHomeDir() .. "/")
end)

AF._handlers.downloadError = registerAnonymousEventHandler("sysDownloadError", function(_, message, localFile)
  local name = AF._active
  if not name then return end
  local asset = AF.assets[name]
  if not asset or localFile ~= zipDownloadPath(name) then return end
  ce(asset.label .. ": download failed -- " .. tostring(message))
  afterFetchDone()
end)

AF._handlers.unzipDone = registerAnonymousEventHandler("sysUnzipDone", function(_, zipLocation)
  local name = AF._active
  if not name then return end
  local asset = AF.assets[name]
  if not asset or zipLocation ~= zipDownloadPath(name) then return end
  os.remove(zipLocation)
  ce(asset.label .. ": installed.")
  afterFetchDone()
end)

AF._handlers.unzipError = registerAnonymousEventHandler("sysUnzipError", function(_, zipLocation)
  local name = AF._active
  if not name then return end
  local asset = AF.assets[name]
  if not asset or zipLocation ~= zipDownloadPath(name) then return end
  ce(asset.label .. ": extraction failed -- zip left at " .. zipLocation .. " for manual inspection")
  afterFetchDone()
end)

if not AF._aliasesInstalled then
  tempAlias([[^mydsl assets status$]], [[MyDSL.AssetFetch.status()]])
  tempAlias([[^mydsl assets fetch all$]], [[MyDSL.AssetFetch.fetchAll()]])
  tempAlias([[^mydsl assets fetch (\S+)$]], [[MyDSL.AssetFetch.fetch(matches[2])]])
  AF._aliasesInstalled = true
end
