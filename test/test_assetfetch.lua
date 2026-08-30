-- MyDSL_AssetFetch.lua: opt-in Sounds/RoomPics downloader.
-- Run: luajit test/test_assetfetch.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local registeredHandlers = {}
_G.registerAnonymousEventHandler = function(eventName, fn)
  registeredHandlers[eventName] = registeredHandlers[eventName] or {}
  table.insert(registeredHandlers[eventName], fn)
  return #registeredHandlers[eventName]
end

local downloadCalls = {}
_G.downloadFile = function(target, url)
  table.insert(downloadCalls, { target = target, url = url })
  return true
end

local unzipCalls = {}
_G.unzipAsync = function(zipPath, extractDir)
  table.insert(unzipCalls, { zip = zipPath, dir = extractDir })
  return true
end

local removedFiles = {}
local realRemove = os.remove
os.remove = function(path) removedFiles[#removedFiles + 1] = path; return true end

_G.getMudletHomeDir = function() return "/tmp/mydsl-test-home" end

dofile("MyDSL_AssetFetch.lua")

local AF = MyDSL.AssetFetch

check("only sounds and roompics are offered (no portraits)", AF.assets.portraits == nil and AF.assets.sounds ~= nil and AF.assets.roompics ~= nil)
check("sounds URL points at the assets-v1 release", AF.assets.sounds.url == "https://github.com/Siathes/MyDSL/releases/download/assets-v1/Sounds.zip")
check("roompics URL points at the assets-v1 release", AF.assets.roompics.url == "https://github.com/Siathes/MyDSL/releases/download/assets-v1/RoomPics.zip")

-- Alias parity check.
check("'mydsl assets fetch <name>' alias registered", _G.__aliases ~= nil)

AF.fetch("bogus")
check("an unknown asset name doesn't queue a download", #downloadCalls == 0)
check("an unknown asset name doesn't set _active", AF._active == nil)

AF.fetch("sounds")
check("fetch('sounds') queues exactly one download", #downloadCalls == 1)
check("downloads to the expected local path", downloadCalls[1].target == "/tmp/mydsl-test-home/Sounds_download.zip")
check("_active is set while a fetch is in progress", AF._active == "sounds")

AF.fetch("roompics")
check("fetching while already active is refused (still only 1 download queued)", #downloadCalls == 1)

-- Simulate the download completing -> should trigger unzipAsync.
for _, fn in ipairs(registeredHandlers["sysDownloadDone"]) do
  fn("sysDownloadDone", "/tmp/mydsl-test-home/Sounds_download.zip", 12345)
end
check("download completion triggers exactly one unzip call", #unzipCalls == 1)
check("unzips the downloaded sounds zip", unzipCalls[1].zip == "/tmp/mydsl-test-home/Sounds_download.zip")
check("extracts to the profile root (zip entries already carry Sounds/... prefix)", unzipCalls[1].dir == "/tmp/mydsl-test-home/")

-- Simulate the unzip completing -> should clear _active and remove the zip.
for _, fn in ipairs(registeredHandlers["sysUnzipDone"]) do
  fn("sysUnzipDone", "/tmp/mydsl-test-home/Sounds_download.zip", "/tmp/mydsl-test-home/")
end
check("_active is cleared after a successful fetch", AF._active == nil)
check("the downloaded zip is removed after extraction", removedFiles[1] == "/tmp/mydsl-test-home/Sounds_download.zip")

-- fetch all: sounds first, then roompics once sounds' whole chain finishes.
downloadCalls = {}
unzipCalls = {}
removedFiles = {}
AF.fetchAll()
check("fetchAll() starts with sounds", #downloadCalls == 1 and downloadCalls[1].url == AF.assets.sounds.url)

for _, fn in ipairs(registeredHandlers["sysDownloadDone"]) do
  fn("sysDownloadDone", "/tmp/mydsl-test-home/Sounds_download.zip", 12345)
end
for _, fn in ipairs(registeredHandlers["sysUnzipDone"]) do
  fn("sysUnzipDone", "/tmp/mydsl-test-home/Sounds_download.zip", "/tmp/mydsl-test-home/")
end
check("fetchAll() moves on to roompics once sounds' full chain completes", #downloadCalls == 2 and downloadCalls[2].url == AF.assets.roompics.url)

-- Finish roompics' own chain too, so the module is idle before the next section.
for _, fn in ipairs(registeredHandlers["sysDownloadDone"]) do
  fn("sysDownloadDone", "/tmp/mydsl-test-home/RoomPics_download.zip", 67890)
end
for _, fn in ipairs(registeredHandlers["sysUnzipDone"]) do
  fn("sysUnzipDone", "/tmp/mydsl-test-home/RoomPics_download.zip", "/tmp/mydsl-test-home/")
end
check("_active is idle again after fetchAll's full chain finishes", AF._active == nil)

-- A download error should clear _active without ever calling unzipAsync.
downloadCalls = {}
unzipCalls = {}
AF.fetch("sounds")
for _, fn in ipairs(registeredHandlers["sysDownloadError"]) do
  fn("sysDownloadError", "network error", "/tmp/mydsl-test-home/Sounds_download.zip")
end
check("a download error clears _active", AF._active == nil)
check("a download error never triggers unzipAsync", #unzipCalls == 0)

os.remove = realRemove

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " failure(s)")
  os.exit(1)
end
