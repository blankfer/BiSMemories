--[[
  BiSMemories :: Core/Memories.lua - the camera, and the note of why it fired.

  A screenshot on its own is a file called WoWScrnShot_091826_204431.jpg. A year later nobody knows
  what it was. So every shot this addon takes is written down beside it: what happened, where, at
  what level, who was in the group -- and the filename stem the client will have used, so a picture
  can be matched to its moment without guessing.

  WHY IT WORKS ON WOW FOREVER. Nothing here reads a number the client hides. Forever makes health,
  auras, cooldowns and stats secret while the secure lockdown is on, and never fires the combat log
  (measured 17 Sep 2026, _bisdev/docs/forever-secret-values.md) -- but zone, level, loot lines,
  roster and `Screenshot()` are all plainly readable, in combat and out. That is why this addon was
  Forever-first: it asks the client only for things the client still tells anyone.

  Every event is registered through pcall. A client that has never heard of ACHIEVEMENT_EARNED must
  not take the file down with it -- the two clients this TOC claims are ten expansions apart.
]]
local ADDON, ns = ...

local M = {}
ns.M = M

-- What is worth a photograph. Each is a switch in the DB, and `/bism off boss` turns one off. `word` is
-- the kind in plain words (Arn, 21 Oct review: the journal and the album printed "levelup").
local TRIGGERS = {
  { key = "levelup",     label = "levelling up",          on = true, word = "Level up" },
  { key = "boss",        label = "a boss's first kill, or your fastest", on = true, word = "Boss" },
  { key = "loot",        label = "rare loot",             on = true, word = "Loot" },
  { key = "achievement", label = "an achievement",        on = true, word = "Achievement" },
  { key = "death",       label = "a death worth keeping", on = true, word = "Death" },
  { key = "duel",        label = "winning a duel",        on = true, word = "Duel" },
  { key = "zone",        label = "a zone you have never seen", on = true, word = "New place" },
  { key = "exalted",     label = "going exalted",         on = true, word = "Exalted" },
  { key = "candid",      label = "one candid a week",     on = true, word = "Candid" },
  { key = "first",       label = "firsts: a mount, riding", on = true, word = "First" },
  { key = "gamba",       label = "your biggest gamba win", on = true, word = "Gamba" },
  { key = "group",       label = "group photos",          on = true, word = "Group photo" },
}
M.TRIGGERS = TRIGGERS
M.WORDS = { manual = "By hand" }
for _, t in ipairs(TRIGGERS) do M.WORDS[t.key] = t.word end
--- A kind as people read it ("Level up"), whatever key the note carries.
function M.Word(reason) return M.WORDS[reason or ""] or tostring(reason or "?") end

local DEFAULTS = {
  sound = true,       -- a click, so you know it fired (the client only clicks for PrintScreen)
  gap = 8,            -- seconds between shots, so one loot burst is not forty pictures
  delay = 0.6,        -- let the client finish drawing the moment (the ding, the corpse, the loot)
  keep = 250,         -- entries in the log; the pictures themselves are never touched
  candidEvery = 7 * 24 * 60 * 60,   -- a week, in seconds
  candidWindow = 45 * 60,           -- taken at a random moment inside this much play, not on login
  lootQuality = 4,    -- 4 = epic. 3 = rare, if you want more of them
  gems = false,       -- a gem is a component, not a keepsake (4 Oct 2026, Black Temple)
  clean = true,       -- the interface hidden for the instant of the shot (M.Clean)
  bossEvery = false,  -- true: every kill, as before 0.9.0; false: the first, and a fastest yet
  deathEvery = false, -- true: every death; false: the ones worth keeping (M.DeathWorthy)
  onThisDay = true,   -- at login: "a year ago today..." (M.OnThisDay)
  pins = "mine",      -- the world map's pins: "mine" (this character's), "all", "off"
}
for _, t in ipairs(TRIGGERS) do DEFAULTS[t.key] = t.on end
for k, v in pairs(DEFAULTS) do ns.DEFAULTS[k] = v end

local function db() return ns.DB() end
local plain     -- below (a value the client may hide, made safe); declared here, used from here on
local realZone  -- below too

--------------------------------------------------------------- whose memory --
-- EACH CHARACTER HAS THEIR OWN (Arn, 21 Oct review). The log is the account's - one album, every
-- character in it - but a note never said WHO, so a year on the main's Ragnaros and the alt's looked the
-- same; and "a zone you have never seen" asked the whole account, so an alt never had a first time
-- anywhere the main had been. Now every note carries the character, and what a character has seen,
-- killed and done first is kept under their own name (d.chars[key]).

--- This character's key, "Name-Realm", or nil while the client still calls them "Unknown". Kept once
--- known: a name does not change mid-session.
function M.Me()
  if M.me then return M.me end
  local name = plain(UnitName and UnitName("player"))
  local realm = plain(GetRealmName and GetRealmName())
  if type(name) ~= "string" or name == "" or name == (UNKNOWNOBJECT or "Unknown") then return nil end
  M.me = name .. "-" .. (type(realm) == "string" and realm ~= "" and realm or "?")
  return M.me
end

--- This character's own book: { zones = {}, bosses = { [name] = { kills, best } }, firsts = {}, gambaBest }.
--- A nameless moment gets a throwaway one, so nothing is filed under the wrong person.
function M.Char()
  local key = M.Me()
  if not key then
    M.nobody = M.nobody or { zones = {}, bosses = {}, firsts = {} }
    return M.nobody
  end
  local d = db()
  d.chars = type(d.chars) == "table" and d.chars or {}
  local c = d.chars[key]
  if type(c) ~= "table" then
    c = { zones = {}, bosses = {}, firsts = {} }
    d.chars[key] = c
    M.Inherit(c)
  end
  c.zones = type(c.zones) == "table" and c.zones or {}
  c.bosses = type(c.bosses) == "table" and c.bosses or {}
  c.firsts = type(c.firsts) == "table" and c.firsts or {}
  return c
end

--- THE OLD MEMORIES' OWNERS (Arn, 21 Oct 2026: "this level up is my rogue alt but it showed my main").
--- Before 0.9.0 a note kept no character - only its level and its time. But a character's level only
--- goes up: read in time order, a level-2 note between two level-15 notes is somebody else. So the
--- unclaimed notes fall into TRACKS (each joins the track whose level it can follow most closely, else
--- starts one), and a character, when it logs in, claims the track whose last level is the highest at or
--- below its own - the main takes the long one, the rogue the run of levels 1 to 5. The note then carries
--- that character for good. A note with no level (0) is left alone; nothing is ever given away twice.
function M.Tracks()
  local old = {}
  for _, e in ipairs(M.Log()) do
    if type(e) == "table" and e.char == nil and type(e.level) == "number" and e.level > 0 then old[#old + 1] = e end
  end
  table.sort(old, function(a, b) return (tonumber(a.at) or 0) < (tonumber(b.at) or 0) end)
  local tracks = {}
  for _, e in ipairs(old) do
    local best
    for _, t in ipairs(tracks) do
      if t.top <= e.level and (not best or t.top > best.top) then best = t end
    end
    if not best then best = { top = 0, notes = {} } tracks[#tracks + 1] = best end
    best.top = e.level
    best.notes[#best.notes + 1] = e
  end
  return tracks
end

function M.ClaimOld()
  local me = M.Me()
  local lvl = plain(UnitLevel and UnitLevel("player"))
  if not me or type(lvl) ~= "number" then return 0 end
  local pick
  for _, t in ipairs(M.Tracks()) do
    if t.top <= lvl and (not pick or t.top > pick.top) then pick = t end
  end
  if not pick then return 0 end
  for _, e in ipairs(pick.notes) do e.char = me end
  M.faceless = nil
  return #pick.notes
end

--- BOSS FACES FOR OLD NOTES (Arn, 21 Oct: "this one did not show the boss dying"). A kill noted from 0.9.0
--- on keeps the boss's npc id (from your target at the kill); an older one kept only the name. The first
--- time you target a creature of that name, its id is kept (db.faces) and the old postcard has its boss.
function M.BossName(e)
  if type(e) ~= "table" or e.reason ~= "boss" then return nil end
  local s = tostring(e.detail or "")
  if s:find("^SURVIVOR") or s:find("^ADVENT") then return nil end      -- BiS Shell's games: no creature
  s = s:gsub("^first kill: ", ""):gsub(" %- fastest yet.*$", "")
  return s ~= "" and s or nil
end

function M.Face(e)
  if type(e) ~= "table" then return nil end
  if tonumber(e.npc) then return tonumber(e.npc) end
  local name = M.BossName(e)
  local faces = db().faces
  return name and type(faces) == "table" and tonumber(faces[name]) or nil
end

--- The names of old bosses with no face yet (cached; nil'd when a note or a face arrives).
function M.Faceless()
  if M.faceless then return M.faceless end
  local set, faces = {}, type(db().faces) == "table" and db().faces or {}
  for _, e in ipairs(M.Log()) do
    local name = (type(e) == "table" and not e.npc) and M.BossName(e) or nil
    if name and not faces[name] then set[name] = true end
  end
  M.faceless = set
  return set
end

function M.LearnFace()
  local set = M.Faceless()
  if next(set) == nil then return nil, "no old boss without a face" end      -- the usual case: no client call
  local name = UnitName and plain(UnitName("target"))
  if type(name) ~= "string" or not set[name] then return nil, "not an old boss" end
  local npc = M.NpcOf(UnitGUID and UnitGUID("target"))
  if not npc then return nil, "not a creature" end
  local d = db()
  d.faces = type(d.faces) == "table" and d.faces or {}
  d.faces[name] = npc
  set[name] = nil
  ns.Print("%s - the old postcard has its boss now", ns.T.text("gold", name))
  return nil, "learnt " .. name .. "'s face"
end

--- THE OLD SHARED LIST OF PLACES goes to one character only: the one who most likely made it. Before
--- 0.9.0 every place went on one list for the whole account; given to everyone, an alt would never have a
--- first time anywhere the main had been, and given to nobody, the main would photograph home again.
--- The notes say which levels the account played at: a character at (or near) the highest of them is
--- the main, and takes the list. Everyone else starts their own map from nothing.
function M.Inherit(c)
  local d = db()
  if type(d.zones) ~= "table" or not next(d.zones) then return false end
  local top = 0
  for _, e in ipairs(type(d.log) == "table" and d.log or {}) do
    if type(e.level) == "number" and e.level > top then top = e.level end
  end
  local lvl = plain(UnitLevel and UnitLevel("player")) or 0
  if type(lvl) ~= "number" or lvl < top - 2 then return false end
  for name in pairs(d.zones) do c.zones[name] = true end
  d.zones = nil                                    -- claimed: one owner, and the shared list is gone
  return true
end

-- The client plays its camera click for the PrintScreen key, not for Screenshot() -- so a shot
-- taken by an addon is silent, and silence is indistinguishable from "it did not work". We make
-- our own, from SOUND KIT IDS ONLY: on the modern engine (WoW Forever) PlaySoundFile with a game
-- file path plays nothing AND reports success, which cost an evening in BiSGamba on 17 Sep 2026.
-- PlaySound(id) answers true or false there and is the honest way to ask.
local CLICK = { 1115, 8959, 850, 839 }     -- first one this client admits to, then remembered
local clickId

local function click()
  if not db().sound or not PlaySound then return false end
  local channel = "Master"
  if clickId then
    local ok, willPlay = pcall(PlaySound, clickId, channel)
    return ok and willPlay ~= false
  end
  for _, id in ipairs(CLICK) do
    local ok, willPlay = pcall(PlaySound, id, channel)
    if ok and willPlay ~= false then
      clickId = id
      return true
    end
  end
  clickId = false
  return false
end

--- The name the client will give the file it is about to write: WoWScrnShot_MMDDYY_HHMMSS.
--- Worked out at the moment of capture, not when the trigger fired, or it names the wrong second.
local function shotStem()
  local stamp = date and date("%m%d%y_%H%M%S") or tostring(time and time() or 0)
  return "WoWScrnShot_" .. stamp
end

local function where()
  local zone = plain((GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText())) or "?"
  local sub = plain(GetSubZoneText and GetSubZoneText()) or ""
  if sub ~= "" and sub ~= zone then return zone .. " - " .. sub end
  return zone
end

--- A value you may actually USE, or nil when the client is hiding it.
---
--- SOME ANSWERS ON THIS CLIENT ARE SECRET: they can be handed to a FontString and the client will
--- paint them, but READING one - arithmetic, comparison, `..`, tostring - is refused, and the
--- refusal is an error, not a nil. (This used to add "even asking whether it is truthy". Never
--- measured, and corrected 21 Sep 2026: EllesmereUI tests secret text for truth on purpose. This
--- guard never makes that test, so nothing below changes.) `ShouldUnitIdentityBeSecret` and
--- `ShouldUnitStatsBeSecret` are both in this client's API list, so a NAME and a LEVEL are both
--- things it can decide to hide.
---
--- It matters more here than anywhere else in this addon, because memories are taken WHILE
--- FIGHTING - a boss dying, dying yourself - which is exactly when the client hides the most. An
--- unguarded read throws inside the camera at the one moment worth a picture, and a secret that
--- got through would be written into the log and on into saved variables.
---
--- NOT YET MEASURED on this client: whether names and levels actually do go secret. The guard
--- costs nothing when they do not, and ForeverAuras 0.1.114 checks unit names exactly this way.
function plain(v)
  if v == nil then return nil end
  if issecretvalue then
    local asked, yes = pcall(issecretvalue, v)
    if asked and yes then return nil end
  end
  return v
end

--- Everyone who was there. A memory of a first kill is worth more with the names on it - and the
--- roster is NOT simply plain on this client, whatever the old comment here claimed.
--- WHOLE NAMES (Arn, 21 Oct 2026: "it should also show who was in the party so a year from now i can add
--- them to bis pal or invite them again"): Forever's UnitName is the first name only ("Chain" of "Chain
--- Healz") - an invite a year on needs the whole one, which GetUnitName(unit, false) gives. And the class,
--- for the colour. -> names, classes (the same order)
local function party()
  local names, classes = {}, {}
  local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
  local raid = IsInRaid and IsInRaid()
  for i = 1, n do
    local unit = (raid and "raid" or "party") .. i
    if UnitExists and UnitExists(unit) and not (UnitIsUnit and UnitIsUnit(unit, "player")) then
      local who
      if GetUnitName then
        local ok, whole = pcall(GetUnitName, unit, false)
        who = ok and plain(whole) or nil
      end
      if type(who) ~= "string" or who == "" then who = UnitName and plain(UnitName(unit)) end
      if type(who) == "string" and who ~= "" then
        names[#names + 1] = (who:gsub("%-.*$", ""))
        local cls = UnitClass and plain(select(2, UnitClass(unit)))
        classes[#names] = type(cls) == "string" and cls or false
      end
    end
  end
  return names, classes
end
M.Party = party

M.log = nil            -- set from the DB on login; kept here so tests can read it directly

local lastShot = 0

--- WHAT YOU WORE: the item ids in each slot, for the journal's postcard (Journal.lua dresses you in
--- them again). Ids only - a link is long, and the id is all a model needs.
M.SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 18, 19 }   -- the slots a model shows (no neck, rings, trinkets)
function M.Gear()
  if not GetInventoryItemLink then return nil end
  local out, n = {}, 0
  for _, slot in ipairs(M.SLOTS) do
    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    link = ok and plain(link)
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id then out[slot] = id n = n + 1 end
  end
  return n > 0 and out or nil
end

--- WHERE ON THE MAP: the client's map and your spot on it, out in the world (inside an instance the
--- client gives none, and the zone's name is the note).
function M.Spot()
  local CM = C_Map
  if not (CM and CM.GetBestMapForUnit and CM.GetPlayerMapPosition) then return nil end
  local okM, map = pcall(CM.GetBestMapForUnit, "player")
  map = okM and plain(map)
  if type(map) ~= "number" then return nil end
  local okP, pos = pcall(CM.GetPlayerMapPosition, map, "player")
  if not (okP and pos and pos.GetXY) then return nil end
  local okX, x, y = pcall(pos.GetXY, pos)
  if not okX then return nil end
  x = plain(x)
  y = plain(y)
  if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return nil end
  return map, math.floor(x * 10000 + 0.5) / 10000, math.floor(y * 10000 + 0.5) / 10000
end

--- A creature's npc id from its GUID ("Creature-0-...-npcID-spawn"), or nil.
function M.NpcOf(guid)
  guid = plain(guid)
  if type(guid) ~= "string" then return nil end
  local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
  return nil
end

--- CLEAN SHOTS (Arn's yes, 21 Oct review): the interface hidden for the instant of the shot, the way
--- Alt+Z hides it (SetUIVisibility - the client's own, allowed in a fight), and back the moment the
--- client says the picture is written - or after M.CLEAN_BACK seconds, whatever happens.
M.CLEAN_BACK = 2
function M.Clean(on)
  if not SetUIVisibility then return false end
  if on then
    if M.uiHidden then return true end
    if not pcall(SetUIVisibility, false) then return false end
    M.uiHidden = true
    if C_Timer and C_Timer.After then C_Timer.After(M.CLEAN_BACK, function() M.Clean(false) end) end
    return true
  end
  if not M.uiHidden then return false end
  M.uiHidden = nil
  pcall(SetUIVisibility, true)
  return true
end

--- Take one, and write down why. Returns the entry, or nil and the reason it did not.
--- `from` is the asking addon's name, for a memory asked for through API.lua (else nil).
--- `extra`: fields for the note beyond the usual (a level that has just changed, a boss's npc id...).
function M.Shoot(reason, detail, from, extra)
  local d = db()
  if d[reason] == false then return nil, "off" end
  local now = (GetTime and GetTime()) or 0
  if lastShot > 0 and (now - lastShot) < (d.gap or 8) then return nil, "too soon" end
  lastShot = now

  -- A PICTURE OF A PLACE IS PROOF YOU HAVE BEEN THERE. Whatever the reason - a level, a boss, a
  -- candid - the zone goes on the list, so it is never later mistaken for somewhere new.
  M.SeeZone(realZone())

  -- (each asked on its own line: `UnitClass and UnitClass(...)` keeps one answer, and the token is the second)
  local class, race
  if UnitClass then class = select(2, UnitClass("player")) end
  if UnitRace then race = select(2, UnitRace("player")) end
  local with, withClass = party()
  local entry = {
    with = with,
    withClass = withClass,
    reason = reason,
    detail = detail,
    zone = where(),
    level = plain(UnitLevel and UnitLevel("player")) or 0,
    at = (time and time()) or 0,
    from = from,
    char = M.Me(),
    class = plain(class),
    race = plain(race),
    gear = M.Gear(),
  }
  entry.map, entry.x, entry.y = M.Spot()
  for k, v in pairs(type(extra) == "table" and extra or {}) do entry[k] = v end

  local function capture()
    entry.file = shotStem()
    if d.clean then M.Clean(true) end
    if Screenshot then pcall(Screenshot) end
    click()
    -- other addons hear it here, at the shutter, so the file name is on the note they get (API.lua)
    if ns.Announce then pcall(ns.Announce, "BiSMemories_Taken", entry) end
  end
  if C_Timer and C_Timer.After and (d.delay or 0) > 0 then
    C_Timer.After(d.delay, capture)
  else
    capture()
  end

  local log = M.Log()
  table.insert(log, 1, entry)
  for i = #log, (d.keep or 250) + 1, -1 do log[i] = nil end
  -- an open journal follows along rather than going stale behind you; the map's pins too
  if ns.J and ns.J.Touch then ns.J.Touch() end
  if ns.Pins and ns.Pins.Update then pcall(ns.Pins.Update) end
  return entry
end

--- The log, created on first use. Kept in the DB so it survives a logout: the point of the addon
--- is the note beside the picture, and a note that dies with the session is no note at all.
function M.Log()
  local d = db()
  d.log = type(d.log) == "table" and d.log or {}
  M.log = d.log
  return d.log
end

---------------------------------------------------------------------- triggers --

--- IS THIS LOOT LINE MINE? CHAT_MSG_LOOT carries everyone's, and in a 25-man raid everyone's
--- epics is a picture every few seconds - Arn, mid-raid: "otherwise it takes for all purple loot".
---
--- Told apart by the client's own strings rather than by looking for "You", because those strings
--- are translated and the word for "you" is not: LOOT_ITEM_SELF is "You receive loot: %s." in
--- English and something else everywhere else. The %s and %d are turned back into captures, the
--- rest is escaped. If the client offers none of them - a harness, an odd build - the English
--- forms are the floor, so this degrades to "probably mine" rather than to "nothing is ever mine".
local NAMES = { "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
                "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }
local SELF, SELFKEY
local function selfPatterns()
  -- KEYED ON THE STRINGS THEMSELVES, not just "have we done this once". A plain cache is right
  -- for a client, where these never change - and wrong for anything that swaps them underneath,
  -- which is exactly what a test for a translated client does. Cheap, and it means the cache can
  -- never be the reason an answer is stale.
  local key = ""
  for _, n in ipairs(NAMES) do key = key .. "|" .. tostring(_G[n]) end
  if SELF and SELFKEY == key then return SELF end
  SELFKEY = key
  SELF = {}
  for _, name in ipairs(NAMES) do
    local fmt = _G[name]
    if type(fmt) == "string" then
      -- ONLY THE PART BEFORE THE ITEM. Matching the whole format meant matching its trailing full
      -- stop too, and a loot line without one stopped being mine - which is brittle for no gain:
      -- what makes a line mine is the words in front of the item ("You receive loot: "), and
      -- those are exactly what the translation changes.
      local prefix = fmt:match("^(.-)%%[sd]")
      if prefix and prefix ~= "" then
        SELF[#SELF + 1] = "^" .. prefix:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
      end
    end
  end
  if #SELF == 0 then
    SELF = { "^You receive loot:", "^You receive item:", "^You create:" }
  end
  return SELF
end

function M.LootIsMine(msg)
  if type(msg) ~= "string" then return false end
  for _, p in ipairs(selfPatterns()) do
    if msg:match(p) then return true end
  end
  return false
end

--- A GEM IS A COMPONENT, NOT A KEEPSAKE (4 Oct 2026).
---
--- Arn, in Black Temple: "bis memories tbc doing it on gems too much" - six pictures in ten
--- minutes, every one of them a gem. They were not drops. `LOOT_ITEM_CREATED_SELF` is "You create:
--- %s.", so a jewelcrafter CUTTING a gem loots it as far as this addon is concerned, and an epic
--- cut is an epic. He sat down mid-raid, cut three, cut three more, and got photographed each time.
---
--- A gem goes in a socket and is never looked at again. Nobody opens an album a year later to see
--- the Shadowsong Amethyst they put in a helm. So a gem is not a memory however it arrives - cut,
--- dropped, or bought - and the switch is there for the one person who disagrees.
---
--- Asked by CLASS ID and not by the word "Gem", for the same reason `LootIsMine` reads the client's
--- own strings: the type NAME is translated and the number is not. GetItemInfoInstant answers from
--- the id without a server round trip, so a gem cut in a raid is judged the moment it is made,
--- which is exactly when the cache would otherwise be empty.
local function isGem(link)
  local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if instant then
    local ok, _, _, _, _, _, classID = pcall(instant, link)
    if ok and type(classID) == "number" then
      return classID == ((Enum and Enum.ItemClass and Enum.ItemClass.Gem) or 3)
    end
  end
  -- the English type name is the floor, not the answer: better than nothing on a client with no
  -- instant lookup, and wrong on a French one, which is why it is never asked first
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if getInfo then
    local ok, _, _, _, _, _, itemType = pcall(getInfo, link)
    if ok and itemType == "Gem" then return true end
  end
  return false
end
M.IsGem = isGem

--- Is this loot line worth a picture? MINE, at the quality you set - plus ANYONE'S legendary,
--- because an orange dropping is the room's memory and not just the winner's.
function M.LootWorthy(msg)
  if type(msg) ~= "string" then return nil end
  local link = msg:match("|c%x+|Hitem:.-|h%[.-%]|h|r") or msg:match("|Hitem:.-|h%[.-%]|h")
  if not link then return nil end
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not getInfo then return nil end
  -- MINE FIRST, a string match that asks the client nothing: in a 40-man most loot lines are other
  -- people's, and for those only a legendary matters - one question, then done (the cost budget holds it)
  local mine = M.LootIsMine(msg)
  local ok, _, _, quality = pcall(getInfo, link)
  if not ok or type(quality) ~= "number" then return nil end
  if not mine and quality < 5 then return nil end
  -- BEFORE the legendary line, deliberately: a legendary gem would still be a gem, and the point
  -- of the switch is that gems are not what anyone opens an album for
  if not db().gems and isGem(link) then return nil end
  if quality >= 5 then return link, quality end      -- a legendary is everyone's news
  if quality < (db().lootQuality or 4) then return nil end
  return link, quality
end

---------------------------------------------------------------- the candid --
--
-- One unposed picture a week. Everything else in this addon fires on a moment you already know is
-- worth keeping -- the ding, the kill, the drop. This one fires when nothing in particular is
-- happening, which is the half of a year in a game that nobody ever photographs: standing in a
-- bank, halfway across a zone, waiting on a summon.
--
-- Deliberately NOT on login: that would be the same loading screen fifty-two times. It picks a
-- random moment inside the next stretch of play instead.

--- Is a week up? Split out so the suite can drive a year in a millisecond.
function M.CandidDue(now)
  local d = db()
  if not d.candid then return false end
  now = now or (time and time()) or 0
  local last = tonumber(d.candidLast) or 0
  if last == 0 then return true end
  return (now - last) >= (d.candidEvery or (7 * 24 * 60 * 60))
end

--- Book this session's candid, if one is owed. Returns the delay it chose, or nil.
function M.ArmCandid()
  local d = db()
  if M.candidArmed or not M.CandidDue() then return nil end
  local window = d.candidWindow or (45 * 60)
  local wait = math.random(60, math.max(120, window))
  M.candidArmed = true
  local function fire()
    local e = M.Shoot("candid", "just a week going by")
    if e then
      d.candidLast = (time and time()) or 0
      M.candidArmed = false
    elseif C_Timer and C_Timer.After then
      C_Timer.After(30, fire)          -- refused by the gap: the moment can wait half a minute
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(wait, fire)
  else
    fire()
  end
  return wait
end

--------------------------------------------------------------------- the rest --

--- WHERE YOU HAVE BEEN, written down whether or not a picture is taken. Arn, 24 Sep: "memories is
--- taking too many screenshots of places that i have already been at".
---
--- His saved file said why, after days of play: `zones = { ["Thunder Bluff"] = true }` - ONE - and
--- a log whose entries were all taken on Zephras Isle. The list was only ever written at the
--- moment the camera decided to fire, so every zone he entered while ZONE_CHANGED_NEW_AREA was
--- quiet (and on this client it is quiet a lot) went unrecorded. The next time that event did
--- speak up there, the place was "new" - and he got a photograph of somewhere he had been all week.
---
--- So the list is fed from every event that knows where you are, and from every picture taken
--- anywhere. Learning is free; only the camera is rationed.
function M.SeeZone(name)
  name = plain(name)
  if type(name) ~= "string" or name == "" or name == "?" then return nil end
  local zones = M.Char().zones                      -- this character's map, not the account's (0.9.0)
  if zones[name] then return nil end
  zones[name] = true
  return name
end

--- The real zone, as a name that can be compared. Everywhere else in this file a client value is
--- scrubbed; the one place that used one as a TABLE KEY took it raw, and a secret key is a new
--- object every time it is asked for - so a zone whose name came back hidden could never match
--- itself again, and was "new" on every single crossing.
function realZone()
  return plain((GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()))
end
M.RealZone = realZone

-- AND A CEILING, because a client that hides a name or forgets to fire is not something this
-- addon can fix from the inside. Three zone pictures in one session is a good day's exploring;
-- the fortieth is a bug with a camera. Learning still has no limit - only the shutter.
M.zoneShots = 0
local ZONE_MAX = 3

--- A zone this character has never been photographed in. The very first zone the addon ever sees
--- is only remembered, not shot: otherwise installing it somewhere you have lived for a year
--- produces a picture of your own bank.
function M.NewZone(name)
  name = plain(name)
  if type(name) ~= "string" or name == "" then return nil end
  local known = next(M.Char().zones) ~= nil
  if not M.SeeZone(name) then return nil, "been here" end
  if not known then return nil, "the first place it ever saw" end
  if M.zoneShots >= ZONE_MAX then return nil, "enough new places for one session" end
  M.zoneShots = M.zoneShots + 1
  return name
end

--- The client's own sentence, turned into a Lua pattern.
---
--- Two shapes exist and BOTH are real: "%s has defeated %s in a duel" on TBC, and
--- "%1$s has defeated %2$s in a duel" on WoW Forever (seen in game 18 Sep 2026). The positional
--- form is not decoration -- it lets a translator swap the order of the names -- and a builder
--- that only knows %s turns %1$s into %1, which Lua reads as a capture back-reference and throws
--- "invalid capture index" on every system message the client prints.
---
--- Returns the pattern and, for each capture in reading order, which ARGUMENT it is: so
--- "%2$s has fled from %1$s" still tells us the winner is the second name in the sentence.
local patternCache = {}
function M.Pattern(fmt)
  if type(fmt) ~= "string" then return nil end
  if patternCache[fmt] then return patternCache[fmt][1], patternCache[fmt][2] end
  local order, n = {}, 0
  local body = fmt:gsub("%%(%d)%$s", function(idx)
    n = n + 1
    order[n] = tonumber(idx)
    return "\1"
  end)
  if n == 0 then
    body = body:gsub("%%s", function()
      n = n + 1
      order[n] = n
      return "\1"
    end)
  end
  body = body:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")   -- escape the magic, % included
  body = body:gsub("\1", "(.+)")
  local pat = "^" .. body .. "$"
  patternCache[fmt] = { pat, order }
  return pat, order
end

--- Did the player just win a duel? The client's own sentence decides, so it stays right in any
--- language and in either placeholder style.
function M.DuelWon(msg)
  if type(msg) ~= "string" then return nil end
  local me = UnitName and UnitName("player")
  if not me then return nil end
  for _, fmt in ipairs({ _G.DUEL_WINNER_KNOCKOUT, _G.DUEL_WINNER_RETREAT }) do
    local pat, order = M.Pattern(fmt)
    if pat then
      local caps = { msg:match(pat) }
      if #caps > 0 then
        local args = {}
        for i, cap in ipairs(caps) do args[order[i] or i] = cap end
        if args[1] == me then return args[2] or "a duel" end
      end
    end
  end
  return nil
end

--- Exalted. The standing's own name comes from the client (FACTION_STANDING_LABEL8), so this does
--- not hard-code the English word.
---
--- TWO PLACES IT CAN SAY SO (21 Oct review): the reputation line on CHAT_MSG_COMBAT_FACTION_CHANGE,
--- and the standing line - "You are now %s with %s." (FACTION_STANDING_CHANGED) - which the client may
--- print as a SYSTEM line instead. Which one Forever uses is UNVERIFIED: both are heard (`/bism heard`).
--- Answers the line to keep: "Exalted with Thunder Bluff" from the standing line, else the line itself.
function M.WentExalted(msg)
  if type(msg) ~= "string" then return nil end
  local exalted = _G.FACTION_STANDING_LABEL8
  if type(exalted) ~= "string" then return nil end
  local pat, order = M.Pattern(_G.FACTION_STANDING_CHANGED)
  if pat then
    local caps = { msg:match(pat) }
    if #caps > 0 then
      local args = {}
      for i, cap in ipairs(caps) do args[order[i] or i] = cap end
      if args[1] == exalted then return ("%s with %s"):format(exalted, tostring(args[2] or "?")) end
      return nil                                       -- the standing line, and not exalted
    end
  end
  if not msg:find(exalted, 1, true) then return nil end
  return msg
end

---------------------------------------------------------------- the bosses --
-- THE FIRST KILL, AND A FASTEST YET (Arn, 21 Oct review: every kill photographed every week fills the
-- album with the same boss). A boss is a memory the first time THIS character kills it - and again
-- only when the kill is the fastest yet, timed from the client's ENCOUNTER_START. `/bism every boss`
-- (d.bossEvery) puts every kill back.
M.fights = {}            -- encounter id -> when it started (GetTime), while it lasts
M.fighting = nil         -- the name of the fight in progress, for a death inside it

function M.BossStart(id, name)
  id, name = plain(id), plain(name)
  if id then M.fights[id] = (GetTime and GetTime()) or 0 end
  M.fighting = type(name) == "string" and name or "a boss"
end

--- A kill heard (ENCOUNTER_END with success, or BOSS_KILL): the memory to take, or nil and why not.
--- The two events can both come for one kill: the second, inside M.TWICE seconds, only adds its time.
M.TWICE = 30
function M.BossKill(name, id, guid)
  name = type(name) == "string" and name or "a boss"
  local now = (GetTime and GetTime()) or 0
  local started = id and M.fights[id]
  if id then M.fights[id] = nil end
  M.fighting = nil
  local secs = started and math.max(0, now - started) or nil
  local b = M.Char().bosses
  local rec = type(b[name]) == "table" and b[name] or nil
  local npc = M.NpcOf(guid)
  if rec and rec.at and now - rec.at < M.TWICE and now >= rec.at then
    if secs and not rec.best then rec.best = secs end          -- the same kill, its time arriving late
    return nil, "the same kill"
  end
  local extra = { npc = npc, secs = secs }
  if not rec then
    b[name] = { kills = 1, best = secs, at = now, first = (time and time()) or 0 }
    return M.Shoot("boss", "first kill: " .. name, nil, extra)
  end
  rec.kills, rec.at = (rec.kills or 0) + 1, now
  if secs and rec.best and secs < rec.best - 1 then
    rec.best = secs
    return M.Shoot("boss", ("%s - fastest yet, %d:%02d"):format(name, math.floor(secs / 60), math.floor(secs % 60)), nil, extra)
  end
  if secs and not rec.best then rec.best = secs end
  if db().bossEvery then return M.Shoot("boss", name, nil, extra) end
  return nil, "killed before"
end

---------------------------------------------------------------- the deaths --
-- A DEATH WORTH KEEPING (21 Oct review: one bad night of wipes was a dozen pictures). Kept: a player
-- killed you, or one of your BiS Tools rivals, or you died in a boss fight, or it is this character's
-- first death ever. Who killed you comes from the client's death recap (C_DeathRecap - BiS Tools reads
-- the same, and measured it plain on Forever, 12 Oct). `/bism every death` (d.deathEvery) keeps them all.

--- The killer: name, whether a player, and the npc id - from the recap's newest hit, every field asked.
function M.Killer()
  local D = C_DeathRecap
  if not (D and D.GetRecapEvents) then return nil end
  local ok, events = pcall(D.GetRecapEvents)
  if not ok or type(events) ~= "table" or plain(events) == nil then return nil end
  local hit = events[1]
  if type(hit) ~= "table" or plain(hit) == nil then return nil end
  local okN, name = pcall(function() return plain(hit.sourceName) end)
  local okG, guid = pcall(function() return plain(hit.sourceGUID) end)
  name = okN and type(name) == "string" and name or nil
  guid = okG and type(guid) == "string" and guid or nil
  if not name then return nil end
  return name, guid and guid:find("^Player%-") ~= nil or false, M.NpcOf(guid)
end

--- Is this name one of your rivals in BiS Tools? Asked through its API (version 2), never its insides.
function M.Rival(name)
  local api = rawget(_G, "BiSToolsAPI")
  if type(api) ~= "table" or api.major ~= 1 or type(api.IsRival) ~= "function" then return false end
  local ok, yes = pcall(api.IsRival, name)
  return ok and yes == true
end

--- The death's memory, or nil and why not.
--- A battleground or an arena: where dying to a player is the whole evening (Arn, 21 Oct 2026, looking at
--- seventeen Darkspear Islands deaths in one album: "these are a lot of screenshots for a battleground").
function M.PvP()
  if not IsInInstance then return false end
  local ok, _, kind = pcall(IsInInstance)
  kind = ok and plain(kind)
  return kind == "pvp" or kind == "arena"
end

function M.Death()
  local c = M.Char()
  local killer, isPlayer, npc = M.Killer()
  local extra = { killer = killer, npc = npc }
  if killer and M.Rival(killer) then return M.Shoot("death", "killed by your rival " .. killer, nil, extra) end
  -- in a battleground only a rival's kill is a memory - not the first death, not "killed by a player"
  if M.PvP() then return nil, "a battleground death - only a rival's kill is kept there" end
  local first = not c.firsts.death
  c.firsts.death = c.firsts.death or ((time and time()) or 0)
  if killer and isPlayer then return M.Shoot("death", "killed by " .. killer, nil, extra) end
  if M.fighting then return M.Shoot("death", "died fighting " .. M.fighting, nil, extra) end
  if first then return M.Shoot("death", "your first death" .. (killer and (" - " .. killer) or ""), nil, extra) end
  if db().deathEvery then return M.Shoot("death", killer and ("killed by " .. killer) or where(), nil, extra) end
  return nil, "not a death worth keeping"
end

---------------------------------------------------------------- the firsts --
-- FIRSTS (21 Oct review): a new mount, and learning to ride. Which event this client sends for a mount
-- is UNVERIFIED (NEW_MOUNT_ADDED on a client with a mount journal, COMPANION_LEARNED on one with
-- companions): both are heard, and `/bism heard` says which came. Riding by its spells' ids (TBC's:
-- Apprentice 33388, Journeyman 33391, Expert 34090, Artisan 34091 - UNVERIFIED on Forever), or a learnt
-- spell whose name says Riding.
M.RIDING = { [33388] = true, [33391] = true, [34090] = true, [34091] = true }
M.LEVEL_CAP = 60

function M.Mount()
  local c = M.Char()
  local first = not c.firsts.mount
  c.firsts.mount = c.firsts.mount or ((time and time()) or 0)
  return M.Shoot("first", first and "your first mount" or "a new mount")
end

function M.Learnt(spellID)
  spellID = plain(spellID)
  if type(spellID) ~= "number" then return nil, "no spell" end
  local name
  local getName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
  if getName then
    local ok, n = pcall(getName, spellID)
    name = ok and plain(n)
  end
  local riding = M.RIDING[spellID] or (type(name) == "string" and name:find("Riding", 1, true))
  if not riding then return nil, "not riding" end
  local c = M.Char()
  local key = "riding" .. spellID
  if c.firsts[key] then return nil, "learnt before" end
  c.firsts[key] = (time and time()) or 0
  return M.Shoot("first", "learned to ride" .. (type(name) == "string" and (" - " .. name) or ""))
end

---------------------------------------------------------------- the gamba --
-- YOUR BIGGEST WIN (21 Oct review): BiS Gamba tells every listener when a round is settled
-- (BiSGambaAPI, "BiSGamba_RoundEnded"); a win bigger than any this character had before is a memory.
function M.GambaRound(p)
  if type(p) ~= "table" then return nil, "no round" end
  local me = plain(UnitName and UnitName("player"))
  local winner, amount = p.winner, tonumber(p.amount)
  if type(winner) ~= "string" or type(me) ~= "string" or not amount or amount <= 0 then return nil, "no win" end
  if winner ~= me and not winner:find("^" .. me:gsub("(%W)", "%%%1") .. "[%- ]") then return nil, "not yours" end
  local c = M.Char()
  if amount <= (tonumber(c.gambaBest) or 0) then return nil, "won bigger before" end
  c.gambaBest = amount
  return M.Shoot("gamba", ("won %dg from %s - your biggest yet"):format(amount, tostring(p.loser or "?")))
end

function M.HookGamba()
  local api = rawget(_G, "BiSGambaAPI")
  if M.gambaHooked or type(api) ~= "table" or api.major ~= 1 or type(api.RegisterCallback) ~= "function" then return false end
  M.gambaHooked = pcall(api.RegisterCallback, ADDON, "BiSGamba_RoundEnded", function(_, p) M.GambaRound(p) end) and true
  return M.gambaHooked
end

local EVENTS = {
  "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED",     -- the old name and the modern one
  "BOSS_KILL", "ENCOUNTER_START", "ENCOUNTER_END",
  "NEW_MOUNT_ADDED", "COMPANION_LEARNED", "LEARNED_SPELL_IN_TAB",
  "CHAT_MSG_LOOT", "ACHIEVEMENT_EARNED", "PLAYER_DEAD",
  "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
  "CHAT_MSG_SYSTEM", "CHAT_MSG_COMBAT_FACTION_CHANGE",
  "PLAYER_ENTERING_WORLD",
  "SCREENSHOT_SUCCEEDED", "SCREENSHOT_FAILED",
  "PLAYER_TARGET_CHANGED",                       -- an old boss note's face (M.LearnFace)
}
M.EVENTS = EVENTS

------------------------------------------------------------------- breadcrumbs --

-- WHAT IT HEARD, AND WHAT IT DECIDED. 19 Sep 2026: an album with one picture in it, and no way to
-- tell the two explanations apart - "nothing worth remembering happened" and "the event never
-- arrived". The saved variables held the answer by accident (no `zones` key at all, so
-- ZONE_CHANGED_NEW_AREA had never once fired), but reading that needs a file and a person who
-- knows what is missing.
--
-- So the camera keeps a note of every event it hears and the verdict it returned. Session only,
-- deliberately: this answers "is it working NOW", and a persisted list would just be one more
-- thing to migrate. Same trick as BiSProbe's phase breadcrumbs, which found the forbidden action
-- in one reload.
M.heard = {}          -- event name -> how many times this session
M.recent = {}         -- newest first: { event, why, at }
M.RECENT_KEEP = 20

local function breadcrumb(event, entry, why)
  M.heard[event] = (M.heard[event] or 0) + 1
  local verdict = entry and "TOOK ONE" or (why or "ignored")
  -- The same thing twice running is one line with a count. Fifteen loot lines in a quiet evening
  -- printed six identical rows and pushed everything else off the top, which is how a diagnostic
  -- stops being read.
  local top = M.recent[1]
  if top and top.event == event and top.why == verdict then
    top.n = (top.n or 1) + 1
    top.at = (time and time()) or top.at
    return
  end
  table.insert(M.recent, 1, {
    event = event,
    why = verdict,
    n = 1,
    at = (time and time()) or 0,
  })
  for i = #M.recent, M.RECENT_KEEP + 1, -1 do M.recent[i] = nil end
end

--- Every event the camera registered for that has NOT arrived once this session. The useful half:
--- a name on this list is either an event this client does not send, or a thing that simply has
--- not happened yet - and knowing which is which is a question for the person, not the addon.
function M.Unheard()
  local out = {}
  for _, e in ipairs(EVENTS) do
    if not M.heard[e] then out[#out + 1] = e end
  end
  return out
end

--- One event, turned into a memory or ignored. Split out from the frame so the suite can drive it
--- with no client at all.
---
--- WHAT THE CLIENT HIDES IS TAKEN OUT FIRST. On Forever an event's text can arrive SECRET - a
--- system line, a loot line, a boss's name - and reading one is an error, not a nil. Arn, 21 Sep,
--- in a dungeon: "attempt to index local 'msg' (a secret string value)" in DuelWon, from a
--- CHAT_MSG_SYSTEM that happened to be secret. Every parser below reads its argument, so each
--- secret argument becomes nil before any of them sees it: the duel check then answers "not a
--- duel", and a boss kill with a hidden name still gets its picture, as "a boss". Only what could
--- not be read is lost. M.hidden counts it, per event, for /memories heard.
M.hidden = {}
local function hiddenValue(v)
  if v == nil or not issecretvalue then return false end
  local ok, yes = pcall(issecretvalue, v)
  return (ok and yes) and true or false
end
function M.OnEvent(event, ...)
  local n, args, scrubbed = select("#", ...), { ... }, false
  for i = 1, n do
    if hiddenValue(args[i]) then args[i] = nil; scrubbed = true end
  end
  if scrubbed then M.hidden[event] = (M.hidden[event] or 0) + 1 end
  local entry, why = M.Decide(event, unpack(args, 1, n))
  if scrubbed and not entry then why = "hidden by the client" end
  breadcrumb(event, entry, why)
  return entry, why
end

--- The decision itself, with no note-keeping in it.
function M.Decide(event, ...)
  if event == "PLAYER_LEVEL_UP" or event == "PLAYER_LEVEL_CHANGED" then
    -- THE NEW LEVEL (21 Oct review): PLAYER_LEVEL_UP says it first; PLAYER_LEVEL_CHANGED says the OLD
    -- level first and the new one second - reading its first answer wrote "level 9" on the ding to 10
    local lvl = event == "PLAYER_LEVEL_CHANGED" and select(2, ...) or select(1, ...)
    lvl = tonumber(lvl) or plain(UnitLevel and UnitLevel("player"))
    local detail = "level " .. tostring(lvl or "?")
    if lvl == M.LEVEL_CAP then detail = ("level %d - the top!"):format(lvl) end
    return M.Shoot("levelup", detail, nil, { level = tonumber(lvl) })

  elseif event == "ENCOUNTER_START" then
    local id, name = ...
    M.BossStart(id, name)
    return nil, "a fight begins"

  elseif event == "BOSS_KILL" then
    local id, name = ...
    return M.BossKill(name, id, UnitGUID and UnitGUID("target"))

  elseif event == "ENCOUNTER_END" then
    local id, name, _, _, success = ...
    if success ~= 1 and success ~= true then                          -- a wipe is not a memory
      if id then M.fights[id] = nil end
      M.fighting = nil
      return nil, "wipe"
    end
    local guid = (UnitGUID and (UnitGUID("boss1") or UnitGUID("target"))) or nil
    return M.BossKill(name, id, guid)

  elseif event == "CHAT_MSG_LOOT" then
    local msg = select(1, ...)
    local link = M.LootWorthy(msg)
    if not link then return nil, "not worthy" end
    return M.Shoot("loot", link)

  elseif event == "ACHIEVEMENT_EARNED" then
    local id = select(1, ...)
    local name
    if GetAchievementInfo then
      local ok, _, title = pcall(GetAchievementInfo, id)
      if ok then name = title end
    end
    return M.Shoot("achievement", tostring(name or id or "?"))

  elseif event == "PLAYER_DEAD" then
    return M.Death()

  elseif event == "NEW_MOUNT_ADDED" or event == "COMPANION_LEARNED" then
    if event == "COMPANION_LEARNED" and select(1, ...) ~= nil and select(1, ...) ~= "MOUNT" then
      return nil, "a companion, not a mount"
    end
    return M.Mount()

  elseif event == "LEARNED_SPELL_IN_TAB" then
    return M.Learnt(select(1, ...))

  elseif event == "ZONE_CHANGED_NEW_AREA" then
    local zone, why = M.NewZone(realZone())
    if not zone then return nil, why or "been here" end
    return M.Shoot("zone", zone)

  -- THE QUIET ONES, which only ever teach it where you are. They fire on crossings the big one
  -- misses - and every zone written down here is a picture NOT taken later for somewhere you
  -- already know.
  elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
    local learnt = M.SeeZone(realZone())
    return nil, learnt and ("noted " .. learnt) or "already known"

  elseif event == "CHAT_MSG_SYSTEM" then
    local msg = select(1, ...)
    local loser = M.DuelWon(msg)
    if loser then return M.Shoot("duel", "beat " .. tostring(loser)) end
    local exalted = M.WentExalted(msg)                -- the standing line can come as a system line
    if exalted and msg:find(_G.FACTION_STANDING_LABEL8 or "\0", 1, true) and exalted ~= msg then
      return M.Shoot("exalted", exalted)
    end
    return nil, "not a duel win"

  elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
    local line = M.WentExalted(select(1, ...))
    if not line then return nil, "not exalted" end
    return M.Shoot("exalted", line)

  elseif event == "PLAYER_TARGET_CHANGED" then
    return M.LearnFace()

  elseif event == "PLAYER_ENTERING_WORLD" then
    if not M.claimTried then M.claimTried = true M.ClaimOld() end   -- the old notes that are this character's
    M.SeeZone(realZone())             -- wherever you logged in or zoned to, known from now on
    M.ArmCandid()                     -- a week up? book a moment somewhere in this session
    M.HookGamba()                     -- BiS Gamba's rounds, when it is installed
    if M.OnThisDay then M.OnThisDay() end    -- once a day: "a year ago today..."
    return nil, "candid considered"

  elseif event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
    local entry = M.Log()[1]
    if entry then entry.shot = (event == "SCREENSHOT_SUCCEEDED") end
    M.Clean(false)                    -- the picture is written: the interface comes back
    return nil, "noted"
  end
  return nil, "ignored"
end

function M.Start()
  if M.frame then return M.frame end
  local f = CreateFrame("Frame")
  for _, e in ipairs(EVENTS) do
    pcall(f.RegisterEvent, f, e)     -- ten expansions apart: an unknown event must not abort
  end
  f:SetScript("OnEvent", function(_, event, ...) M.OnEvent(event, ...) end)
  M.frame = f
  M.Log()
  return f
end
