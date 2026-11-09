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
--     killer = "Neg Crotic", secs = 250,              -- a death's killer; a boss fight's length
--     -- since version 3 (8 Nov 2026), when the asking addon said so (TakeMemory's extra):
--     display = 7970 }                                -- the creature's model (a display id)
--
-- KINDS since version 2: "first" (a mount, riding), "gamba" (your biggest BiS Gamba win), "group"
-- (a group photo) - beside levelup, boss, loot, achievement, death, duel, zone, exalted, candid.
-- A "boss" is now the first kill and the fastest yet; a "death" only one worth keeping (Memories.lua).
-- Since version 4: "share" (a share card's own note - see SHARE CARDS), and a boss's memory may carry
-- cargo = { itemLink, ... } (what dropped in the minute after the kill, 8 at most).
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
--   BiSMemoriesAPI.TakeMemory(note, kind, from, extra)
--       note: string, what it was (cut to 200 characters). Required.
--       kind: optional, one of Kinds()'s keys - the player's switch for that kind then decides
--             (a BiSGuild boss memory obeys "/bism off boss"). nil = "manual", like /bism now.
--       from: optional string, the asking addon's name, kept on the note.
--       extra: optional table, since version 3 - only these fields are read, anything else is ignored:
--             npc = number      the creature it was about (whole, above 0) - the journal's postcard draws it
--                               (a "boss" lies dead beside the player)
--             display = number  that creature's model (a display id, whole, above 0), drawn in its place
--             keepUI = true     this picture keeps the interface in (exactly true; no clean shot for it) -
--                               for a game that is played ON the interface. Not kept on the note.
--       -> the memory (a copy; its file comes a moment later, with the picture), or nil and why:
--          "not ready", "no note", "no such kind", "off" (the player switched that kind off),
--          "too soon" (inside the player's gap between shots), "failed".
--
-- SHARE CARDS (since version 4, 8 Nov 2026 - Core/Share.lua): the boarding pass big and alone on the whole screen, one
-- picture of it, then everything back - a picture made to be posted. The player's own privacy switch decides whether
-- names are on it (/bism share names on|off; hidden unless they said otherwise): hidden, the passenger is their class
-- and every name in `crew` becomes its class ("2 friends: hunter, mage"). Never in a fight. The card's note has
-- reason = "share", detail = its title, crop = { x, y, w, h } (the ticket on the picture, fractions of the screen),
-- of = the memory's own time (ShareMemory), hidden = true|false, and its file once taken (BiSMemories_Taken says when).
--   BiSMemoriesAPI.ShareCard(owner, card)
--       owner: your addon's name (a string is kept on the note as `from`) or any non-nil value. Required.
--       card: a table, COPIED - only these fields are read, each type-checked and cut to its length:
--             title   = string, what it was (60 characters). Required.
--             kind    = string, a short word for the stub ("raid", "clear" - 16)
--             line    = string, the tangerine line under the title ("ALL 40 STANDING · 12:03" - 40)
--             place   = string, where (40; default: where the player is)
--             crew    = { { name = "Name Surname", class = "HUNTER" }, ... } (40 at most; a name 40, a realm after a
--                       "-" is dropped; class a class token in capitals, else none)
--             cargo   = { itemID or itemLink, ... } (8 at most: a whole number above 0, or a string with an item link)
--             npc     = number, the creature in the window (a boss lies dead); display = number, its model instead
--       -> true, the card's note (a copy; its file comes a moment later, with the picture), or nil and why:
--          "not ready", "no owner", "no title", "in combat", "too soon" (inside the player's gap between pictures,
--          or a card is already up), "failed".
--   BiSMemoriesAPI.ShareMemory(owner, index)
--       index: which memory, 1 = the newest (share cards themselves are not counted - Memories()'s order otherwise).
--       -> true, the card's note, or nil and why: "not ready", "no owner", "no such memory", "in combat",
--          "too soon", "failed".
--
--   BiSMemoriesAPI.RegisterCallback(owner, event, fn)
--       owner: any non-nil value (your addon's name or table); event: a name below; fn(event, ...).
--       -> true, or nil, "bad owner" / "no such event" / "not a function". One fn per owner+event.
--   BiSMemoriesAPI.UnregisterCallback(owner, event)
--       -> true, or nil, "not registered".
--
-- EVENTS (since version 1)
--   "BiSMemories_Taken"  fn(event, memory) - the shutter fired, on any trigger or a TakeMemory (since version 4 a
--                        share card's too, reason "share"). memory is a copy, file included. Each callback is pcalled.
--------------------------------------------------------------------------------
local _, ns = ...

local API = { major = 1, version = 4 }
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

-- a whole number above 0 the caller may hand us (a creature or model id); a secret one is refused BEFORE anything reads it
local function id(v)
  if v == nil then return nil end
  if issecretvalue then
    local ok, yes = pcall(issecretvalue, v)
    if not ok or yes then return nil end
  end
  if type(v) ~= "number" or v <= 0 or v ~= math.floor(v) or v ~= v then return nil end
  return v
end

-- what TakeMemory takes from `extra` (since version 3): those three fields, nothing else
local function extras(t)
  if type(t) ~= "table" then return nil end
  local ok, npc, display, keep = pcall(function() return id(t.npc), id(t.display), rawequal(t.keepUI, true) end)
  if not ok then return nil end
  return { npc = npc, display = display, keepUI = keep or nil }
end

function API.TakeMemory(note, kind, from, extra)
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
  local ok, entry, refused = pcall(M.Shoot, reason, note, from and from:sub(1, 40), extras(extra))
  if not ok then return nil, "failed" end
  if not entry then return nil, refused or "failed" end
  return copy(entry)
end

-- A caller's words for a card: readable, the client's colour and link codes out (a "|" cannot draw on the card),
-- trimmed, cut to `n` bytes without halving a character. nil when nothing is left.
local function words(v, n)
  v = readable(v)
  if not v then return nil end
  v = v:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if v == "" then return nil end
  if #v > n then
    v = v:sub(1, n)
    local i = #v
    while i > 0 and v:byte(i) >= 128 and v:byte(i) < 192 do i = i - 1 end
    local lead = i > 0 and v:byte(i) or 0
    if lead >= 192 and (#v - i + 1) < ((lead >= 240 and 4) or (lead >= 224 and 3) or 2) then v = v:sub(1, i - 1) end
  end
  return v
end

-- THE CARD, COPIED (since version 4): only the fields the header names, each checked; a table that throws on reading
-- is no card. -> the copy, or nil (no title).
local function cardOf(card)
  if type(card) ~= "table" then return nil end
  local ok, c = pcall(function()
    local title = words(card.title, 60)
    if not title then return nil end
    local out = { title = title, kind = words(card.kind, 16), line = words(card.line, 40), place = words(card.place, 40),
                  npc = id(card.npc), display = id(card.display), crew = {}, cargo = {} }
    if type(card.crew) == "table" then
      for i = 1, 40 do
        local m = card.crew[i]
        local name = type(m) == "table" and words(m.name, 40) or nil
        if name then
          local cls = readable(m.class)
          cls = (cls and #cls <= 12 and cls:match("^%u+$")) and cls or nil
          out.crew[#out.crew + 1] = { name = (name:gsub("%-.*$", "")), class = cls }
        end
      end
    end
    if type(card.cargo) == "table" then
      for i = 1, 8 do
        local x = card.cargo[i]
        local item = id(x)
        if not item then
          local s = readable(x)
          item = (s and #s <= 200 and s:find("|Hitem:%d+")) and s or nil
        end
        if item then out.cargo[#out.cargo + 1] = item end
      end
    end
    return out
  end)
  return ok and c or nil
end

local function owner40(owner)
  local s = readable(owner)
  return s and s:sub(1, 40) or nil
end

function API.ShareCard(owner, card)
  local M, why = Camera()
  if not M then return nil, why end
  if owner == nil then return nil, "no owner" end
  local c = cardOf(card)
  if not c then return nil, "no title" end
  local S = ns.Share
  if not (S and S.Card) then return nil, "not ready" end
  local ok, note, refused = pcall(S.Card, c, owner40(owner))
  if not ok then return nil, "failed" end
  if not note then return nil, refused or "failed" end
  return true, copy(note)
end

function API.ShareMemory(owner, index)
  local M, why = Camera()
  if not M then return nil, why end
  if owner == nil then return nil, "no owner" end
  local S = ns.Share
  if not (S and S.Take) then return nil, "not ready" end
  local n = id(index)
  local okL, log = pcall(M.Log)
  local e
  if n and okL and type(log) == "table" then
    local k = 0
    for _, x in ipairs(log) do
      if type(x) == "table" and x.reason ~= "share" then
        k = k + 1
        if k == n then e = x break end
      end
    end
  end
  if not e then return nil, "no such memory" end
  local ok, note, refused = pcall(S.Take, e, { from = owner40(owner) })
  if not ok then return nil, "failed" end
  if not note then return nil, refused or "failed" end
  return true, copy(note)
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
