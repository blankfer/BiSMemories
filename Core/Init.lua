--[[
  BiSMemories :: Core/Init.lua - made by _bisdev/new-addon.sh (the house skeleton).

  What every BiS addon starts with, already wired and tested:
    * ns.T      the palette, resolved PER CALL (BiSTheme loads after us, alphabetically)
    * ns.VERSION the TOC's ## Version and nothing else's
    * ns.Print  one chat line with the addon's name in the accent colour
    * BiSMemoriesDB SavedVariables with defaults filled on ADDON_LOADED
    * the shared BiS channel (LibBiSComm): registered, booted, its off switch remembered
    * /bism (and /memories) - says hello: version, comm on/off, peers. Replace it with the real addon.
]]
local ADDON, ns = ...

local HEX = {
  ink = "ece8f6", muted = "968ead", accent = "b980ff", good = "4fd0cf", warn = "f08cb0", gold = "e5c04a",
  -- the ground colours, for the journal (0.9.0): BiSTheme's own names and values
  bg = "121020", surface = "1a1730", sunken = "221d3c", line = "2a2446", line2 = "3a3260", ink2 = "c6bedd",
}
local T = {}
ns.T = T
T.hex = HEX
function T.rgb(name)
  local real = _G.BiSTheme
  if real and real.hex and real.hex[name] and real.rgb then return real.rgb(name) end
  local hex = HEX[name] or HEX.ink
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
function T.text(name, s)
  local real = _G.BiSTheme
  if real and real.hex and real.hex[name] and real.text then return real.text(name, s) end
  return "|cff" .. (HEX[name] or HEX.ink) .. tostring(s) .. "|r"
end

ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
  or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "dev"

function ns.Print(fmt, ...)
  local msg = select("#", ...) > 0 and fmt:format(...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage(T.text("accent", ADDON) .. " " .. msg)
end

ns.DEFAULTS = { comm = true }
local function db()
  BiSMemoriesDB = type(BiSMemoriesDB) == "table" and BiSMemoriesDB or {}
  for k, v in pairs(ns.DEFAULTS) do
    if BiSMemoriesDB[k] == nil then BiSMemoriesDB[k] = v end
  end
  return BiSMemoriesDB
end
ns.DB = db

-- THE SECOND COPY, because this client loses the first one. Measured on the Forever beta on
-- 19 Sep 2026: it WRITES `BiSMemoriesDB` perfectly - valid Lua, every note in it - and hands back
-- nothing at the next login. Two zone memories went that way between one save and the next, and
-- BugGrabber's session counter sat at 1 through a dozen reloads, so it is the client. The
-- per-character file is a different file in a different folder and it survives: BiSHealing proved
-- it the same afternoon (`## SavedVariablesPerCharacter`, a bind still there after a reload).
--
-- So: write both, and at login take whichever came back. They stay SEPARATE tables - two globals
-- pointing at one table is one file saved and one lost, which looks exactly like the bug.
local function copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = copy(x) end
  return out
end

local function has(t) return type(t) == "table" and next(t) ~= nil end

--- On the way out: everything, since this addon's table is small and all of it matters.
function ns.MirrorOut()
  BiSMemoriesCharDB = type(BiSMemoriesCharDB) == "table" and BiSMemoriesCharDB or {}
  if type(BiSMemoriesDB) ~= "table" then return end
  for k in pairs(BiSMemoriesCharDB) do BiSMemoriesCharDB[k] = nil end
  for k, v in pairs(BiSMemoriesDB) do BiSMemoriesCharDB[k] = copy(v) end
end

--- At login: only when the account-wide table came back without a log and the per-character one
--- has one. A client that keeps both never reaches this.
function ns.MirrorIn()
  local acct, char = BiSMemoriesDB, BiSMemoriesCharDB
  -- WHERE YOU HAVE BEEN COMES HOME EITHER WAY. The rescue below is gated on the LOG - fair enough,
  -- the log is what a player would miss - and `zones` only ever came back as a passenger on it. A
  -- character who has not taken a photograph yet has no log to ride on, so their map was forgotten
  -- at every login and every place they knew was "new" again (Arn, 24 Sep: "too many screenshots
  -- of places that i have already been at"). The two lists are merged on their own, first, and
  -- merged rather than replaced: neither copy is more right about a place than the other.
  -- (only before 0.9.0's per-character books: after them, an old mirror's shared list must not come back
  -- and be handed out a second time - Memories.lua M.Inherit)
  if type(char) == "table" and type(char.zones) == "table" and not (type(acct) == "table" and type(acct.chars) == "table") then
    BiSMemoriesDB = type(acct) == "table" and acct or {}
    acct = BiSMemoriesDB
    acct.zones = type(acct.zones) == "table" and acct.zones or {}
    for name in pairs(char.zones) do acct.zones[name] = true end
  end
  if has(acct) and has(acct.log) then return false end
  if not (has(char) and has(char.log)) then return false end
  BiSMemoriesDB = type(acct) == "table" and acct or {}
  for k, v in pairs(char) do BiSMemoriesDB[k] = copy(v) end
  return true
end

-- the shared BiS channel: no setting of this addon may gate it; only /biscomm off does,
-- and that choice survives a logout here
ns.Comm = {}
function ns.Comm.Boot()
  local lib = _G.LibBiSComm
  if not lib then return end
  lib:RegisterAddon(ADDON, ns.VERSION)
  if db().comm == false then lib:SetEnabled(false) end
  if db().commShare == false and lib.SetSharing then lib:SetSharing(false) end   -- /biscomm share off (minor 12)
  lib:Boot()
end
function ns.Comm.Save()
  local lib = _G.LibBiSComm
  if lib then db().comm = lib:Enabled() end
  if lib and lib.Sharing then db().commShare = lib:Sharing() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    -- WHICH COPY CAME BACK (0.9.0, `/bism db`): the stamp each file was saved with, read before anything
    -- touches them. Two answers tell "the client never read it" from "our write never landed" - and
    -- once the account-wide one comes back on Forever every time, the second copy can go.
    ns.dbSeen = {
      acct = type(BiSMemoriesDB) == "table" and BiSMemoriesDB.stamp or nil,
      char = type(BiSMemoriesCharDB) == "table" and BiSMemoriesCharDB.stamp or nil,
    }
    ns.rescued = ns.MirrorIn()                       -- before db(), so the log is there to find
    db()
    ns.Comm.Boot()
    if ns.M and ns.M.Start then ns.M.Start() end     -- the camera, once the DB exists
  elseif event == "PLAYER_LOGOUT" then
    ns.Comm.Save()
    db().stamp = time and time() or 0                -- read back at the next login (`/bism db`)
    ns.MirrorOut()                                   -- the copy this client will actually give back
  end
end)

-- /bism FIRST (Arn, 12 Oct 2026: "we rename all the old ones to keep it consistent") - the family's
-- /bis* commands: /bish, /bist, /bisg, /bism. /memories stays as an alias so no macro or habit breaks.
SLASH_BISMEMORIES1 = "/bism"
SLASH_BISMEMORIES2 = "/memories"
SlashCmdList.BISMEMORIES = function(input)
  -- Core/Slash.lua loads after this file and owns the real commands; if it ever fails to load,
  -- the addon still answers rather than throwing a nil call at whoever typed it.
  if ns.Slash then return ns.Slash(input) end
  ns.Print("loaded, but the commands did not - version %s", ns.VERSION)
end
