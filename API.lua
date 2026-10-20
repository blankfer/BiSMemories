--------------------------------------------------------------------------------
-- BiSMemoriesAPI: for other addons (16 Oct 2026, playbook 5a - shaped like BiSToolsAPI).
--
-- What BiS Memories is best at: a screenshot when something worth remembering happens, and a note
-- of what it was. So another addon may ASK what was remembered, and ASK for a memory of its own -
-- the same picture and note the addon takes on its own triggers, under the player's own switches.
-- A caller never reaches into ns.M or BiSMemoriesDB: it asks here, and here stays the same.
--
--   * BiSMemoriesAPI.major = 1. A caller checks api.major == 1 before using it.
--   * BiSMemoriesAPI.version goes up when something is added; nothing is changed or taken away
--     without a new major.
--   * Nothing here changes BiS Memories' settings. Every call is safe at any time: before the
--     addon has loaded its saved notes it answers nil, "not ready". It never errors.
--   * Every answer is a COPY - editing one changes nothing in the album.
--
-- A memory (a table, copied):
--   { reason = "boss" | "levelup" | ... | "manual",   -- the kind; "manual" = asked for by hand
--     detail = "Illidan Stormrage",                   -- what it was
--     zone   = "Black Temple - ...",                  -- where (zone - subzone)
--     level  = 70,                                    -- the player's level then
--     at     = 1790000000,                            -- time() seconds when it happened
--     with   = { "Name Surname", ... },               -- who was in the group
--     file   = "WoWScrnShot_101626_204431",           -- the screenshot's file stem (once taken)
--     shot   = true | false | nil,                    -- the client said the picture saved / failed
--     from   = "BiSGuild" | nil,                      -- the addon that asked, for API memories
--     -- since version 2 (0.9.0), each when known:
--     char   = "Kumlust-Dreamscythe",                 -- whose memory it is (name-realm)
--     class  = "SHAMAN", race = "Tauren",             -- UnitClass / UnitRace tokens
--     map = 1413, x = 0.51, y = 0.30,                 -- the client's map and the spot on it (none inside an instance)
--     gear   = { [16] = 17182, ... },                 -- the item id in each slot a model shows
--     npc    = 11502,                                 -- the creature it was about (a boss, a killer)
--     killer = "Neg Crotic", secs = 250 }             -- a death's killer; a boss fight's length
--
-- KINDS since version 2: "first" (a mount, riding), "gamba" (your biggest BiS Gamba win), "group"
-- (a group photo) - beside levelup, boss, loot, achievement, death, duel, zone, exalted, candid.
-- A "boss" is now the first kill and the fastest yet; a "death" only one worth keeping (Memories.lua).
--
-- FUNCTIONS (all since version 1)
--   BiSMemoriesAPI.Ready()
--       -> true, or nil, "not ready".
--   BiSMemoriesAPI.Memories(count)
--       count: optional number, the newest that many (default all).
--       -> a list of memories, newest first ({} when there are none), or nil, "not ready".
--   BiSMemoriesAPI.Latest()
--       -> the newest memory, or nil, "not ready" / "no memories".
--   BiSMemoriesAPI.Kinds()
--       -> a list of { key = "boss", label = "a boss dying", on = true|false } - every kind of
--          memory and whether the player has it switched on - or nil, "not ready".
--   BiSMemoriesAPI.TakeMemory(note, kind, from)
--       note: string, what it was (cut to 200 characters). Required.
--       kind: optional, one of Kinds()'s keys - the player's switch for that kind then decides
--             (a BiSGuild boss memory obeys "/bism off boss"). nil = "manual", like /bism now.
--       from: optional string, the asking addon's name, kept on the note.
--       -> the memory (a copy; its file comes a moment later, with the picture), or nil and why:
--          "not ready", "no note", "no such kind", "off" (the player switched that kind off),
--          "too soon" (inside the player's gap between shots), "failed".
--   BiSMemoriesAPI.RegisterCallback(owner, event, fn)
--       owner: any non-nil value (your addon's name or table); event: a name below; fn(event, ...).
--       -> true, or nil, "bad owner" / "no such event" / "not a function". One fn per owner+event.
--   BiSMemoriesAPI.UnregisterCallback(owner, event)
--       -> true, or nil, "not registered".
--
-- EVENTS (since version 1)
--   "BiSMemories_Taken"  fn(event, memory) - the shutter fired, on any trigger or a TakeMemory.
--                        memory is a copy, file included. Each callback is pcalled.
--------------------------------------------------------------------------------
local _, ns = ...

local API = { major = 1, version = 2 }
BiSMemoriesAPI = API

local EVENTS = { BiSMemories_Taken = true }
local owners = {}    -- event -> { [owner] = fn }

local function copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = copy(x) end
  return out
end

-- the camera, once the addon has its saved notes (M.Start runs on ADDON_LOADED)
local function Camera()
  local M = ns.M
  if not (M and M.frame and type(_G.BiSMemoriesDB) == "table") then return nil, "not ready" end
  return M
end

-- a string the caller may hand us; a secret one is refused BEFORE anything reads it
local function readable(v)
  if v == nil then return nil end
  if issecretvalue then
    local ok, yes = pcall(issecretvalue, v)
    if not ok or yes then return nil end
  end
  if type(v) ~= "string" or v == "" then return nil end
  return v
end

function API.Ready()
  local M, why = Camera()
  if not M then return nil, why end
  return true
end

function API.Memories(count)
  local M, why = Camera()
  if not M then return nil, why end
  local ok, log = pcall(M.Log)
  if not ok or type(log) ~= "table" then return nil, "not ready" end
  local n = #log
  if type(count) == "number" and count >= 0 and count < n then n = math.floor(count) end
  local out = {}
  for i = 1, n do out[i] = copy(log[i]) end
  return out
end

function API.Latest()
  local M, why = Camera()
  if not M then return nil, why end
  local ok, log = pcall(M.Log)
  if not ok or type(log) ~= "table" then return nil, "not ready" end
  if not log[1] then return nil, "no memories" end
  return copy(log[1])
end

function API.Kinds()
  local M, why = Camera()
  if not M then return nil, why end
  local d = _G.BiSMemoriesDB
  local out = {}
  for _, t in ipairs(M.TRIGGERS or {}) do
    out[#out + 1] = { key = t.key, label = t.label, on = d[t.key] ~= false }
  end
  return out
end

function API.TakeMemory(note, kind, from)
  local M, why = Camera()
  if not M then return nil, why end
  note = readable(note)
  if not note then return nil, "no note" end
  if #note > 200 then note = note:sub(1, 200) end
  local reason = "manual"
  if kind ~= nil then
    reason = nil
    for _, t in ipairs(M.TRIGGERS or {}) do
      if t.key == kind then reason = kind end
    end
    if not reason then return nil, "no such kind" end
  end
  from = readable(from)
  local ok, entry, refused = pcall(M.Shoot, reason, note, from and from:sub(1, 40))
  if not ok then return nil, "failed" end
  if not entry then return nil, refused or "failed" end
  return copy(entry)
end

function API.RegisterCallback(owner, event, fn)
  if owner == nil then return nil, "bad owner" end
  if not EVENTS[event] then return nil, "no such event" end
  if type(fn) ~= "function" then return nil, "not a function" end
  owners[event] = owners[event] or {}
  owners[event][owner] = fn
  return true
end

function API.UnregisterCallback(owner, event)
  local list = event and owners[event]
  if owner == nil or not (list and list[owner]) then return nil, "not registered" end
  list[owner] = nil
  return true
end

-- Memories.lua calls this at the shutter. A fresh copy per callback, so one listener editing its
-- memory cannot change what the next one hears; a listener's error stays its own.
function ns.Announce(event, entry)
  local list = owners[event]
  if not list then return end
  for _, fn in pairs(list) do
    pcall(fn, event, copy(entry))
  end
end
