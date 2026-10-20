-- BiSMemories headless suite (made by _bisdev/new-addon.sh). Run from the addon root:
--   lua5.1 dev/tests.lua        or, from the AddOns folder: _bisdev/check.sh BiSMemories
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local H = dofile(HERE .. "/kit.lua")   -- Nebbinator's strict harness (dev/harness.lua), verbatim
local ROOT = os.getenv("BISMEMORIES") or (HERE .. "/..")
local FILES = H.TOC(ROOT, "BiSMemories.toc")

-- every global this addon may create; anything else is a leak and a red test
local ALLOWED = {
    BiSMemoriesDB = true, BiSMemoriesAPI = true, SLASH_BISMEMORIES1 = true, SLASH_BISMEMORIES2 = true,
    HARNESS = true, print = true, BiSTheme = true, LibBiSComm = true, SLASH_BISCOMM1 = true,
    -- 0.9.0: the journal and the options window are named (Escape closes them), the minimap button too
    BiSMemoriesJournal = true, BiSMemoriesOptions = true, BiSMinimapBiSMemories = true,
    -- the third-party map libs (Libs/THIRD-PARTY.txt): LibStub's one global, the pins' show flags
    LibStub = true, HBD_PINS_WORLDMAP_SHOW_PARENT = true, HBD_PINS_WORLDMAP_SHOW_CONTINENT = true,
    HBD_PINS_WORLDMAP_SHOW_WORLD = true,
}
-- HEREBEDRAGONS DRIVES THE CLIENT'S OWN MAP ENGINE, which a headless mock cannot stand in for honestly
-- (BiS Tools' and BiS Guild's suites found the same). Its two files must COMPILE, and in their place a
-- stand-in registers under the same LibStub name, raises the real one's argument errors, refuses one
-- frame on two maps, and records every pin. (BiS Guild's dev/tests.lua, the same stand-in.)
local PINS = { world = {}, minimap = {} }
local function fakeHBDPins()
    local P = LibStub:NewLibrary("HereBeDragons-Pins-2.0", 999)
    local function check(ref, icon, map, x, y, what)
        if not ref then error("HereBeDragons-Pins-2.0: " .. what .. ": 'ref' must not be nil", 3) end
        if type(icon) ~= "table" or not icon.SetPoint then error("HereBeDragons-Pins-2.0: " .. what .. ": 'icon' must be a frame", 3) end
        if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
            error("HereBeDragons-Pins-2.0: " .. what .. ": 'uiMapID', 'x' and 'y' must be numbers", 3)
        end
    end
    function P:AddWorldMapIconMap(ref, icon, map, x, y, flag)
        check(ref, icon, map, x, y, "AddWorldMapIconMap")
        if PINS.minimap[icon] then error("this frame is already a pin on the other map", 2) end
        if flag ~= nil and type(flag) ~= "number" then error("showFlag must be a number (or nil)", 2) end
        PINS.world[icon] = { map = map, x = x, y = y, flag = flag }
    end
    function P:RemoveWorldMapIcon(ref, icon) PINS.world[icon] = nil end
    function P:RemoveAllWorldMapIcons() PINS.world = {} end
    _G.HBD_PINS_WORLDMAP_SHOW_PARENT, _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT, _G.HBD_PINS_WORLDMAP_SHOW_WORLD = 1, 2, 3
end
local function Load()
    local before = {}
    for k in pairs(_G) do before[k] = true end
    local NS = {}
    for _, rel in ipairs(FILES) do
        local chunk, err = loadfile(ROOT .. "/" .. rel)
        if not chunk then error("load " .. rel .. ": " .. tostring(err), 0) end
        if rel:find("HereBeDragons-2.0.lua", 1, true) then
            -- compiled; the engine is the client's
        elseif rel:find("HereBeDragons-Pins-2.0.lua", 1, true) then
            fakeHBDPins()
        else
            chunk("BiSMemories", NS)
        end
    end
    H.leaked = {}
    for k in pairs(_G) do
        if not before[k] and not ALLOWED[k] then H.leaked[#H.leaked + 1] = tostring(k) end
    end
    table.sort(H.leaked)
    return NS
end
local TOC_VERSION
do
    local fh = assert(io.open(ROOT .. "/BiSMemories.toc", "r"))
    for line in fh:lines() do TOC_VERSION = TOC_VERSION or line:match("^## Version:%s*(%S+)") end
    fh:close()
end
_G.GetAddOnMetadata = function(_, key) return key == "Version" and TOC_VERSION or nil end
local function fire(event, ...)
    for _, fr in ipairs(H.frames) do
        if fr._events[event] and fr._scripts.OnEvent then fr._scripts.OnEvent(fr, event, ...) end
    end
end
local function bytes(p) local fh = io.open(p, "rb") if not fh then return nil end local s = fh:read("*a") fh:close() return s end
local function strip(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local said = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) said[#said + 1] = strip(m) end }

--------------------------------------------------------------------
H.section("load")
local NS = Load()
H.eq(#H.leaked, 0, "no accidental globals", table.concat(H.leaked, ", "))
H.eq(NS.VERSION, TOC_VERSION, "version is the TOC's")

-- THE API BEFORE LOGIN: the files are loaded, the saved notes are not. Every call answers, none throws.
do
  local A = _G.BiSMemoriesAPI
  H.ok(type(A) == "table" and A.major == 1 and A.version == 2, "BiSMemoriesAPI is there, major 1, version 2")
  for _, call in ipairs({
    { "Ready", {} }, { "Memories", {} }, { "Latest", {} }, { "Kinds", {} }, { "TakeMemory", { "too early" } },
  }) do
    local ok, got, why = pcall(A[call[1]], unpack(call[2]))
    H.ok(ok and got == nil and why == "not ready", call[1] .. " before login: nil, \"not ready\"", tostring(why))
  end
  H.eq(_G.BiSMemoriesDB, nil, "and asking did not make the saved table before the client loaded it")
end
fire("ADDON_LOADED", "BiSMemories")
H.ok(type(_G.BiSMemoriesDB) == "table" and _G.BiSMemoriesDB.comm == true, "SavedVariables shaped with defaults on first load")

H.section("embedded libs are canon (drift fences)")
H.eq(_G.LibBiSComm.MINOR, 14, "LibBiSComm minor 14")
local function listed(rel) for _, f in ipairs(FILES) do if f == rel then return true end end return false end
H.ok(listed("Libs/BiSTheme/Console.lua"), "TOC lists the Console embed")
H.ok(listed("Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua"), "TOC lists the comm embed")
do
    local canon = bytes((os.getenv("BISTHEME") or (ROOT .. "/../BiSTheme")) .. "/Console.lua")
    if canon then H.ok(bytes(ROOT .. "/Libs/BiSTheme/Console.lua") == canon, "Console.lua byte-identical to canon")
    else H.say("  (note) no canon BiSTheme beside the checkout - bytes fence skipped") end
    local lib = bytes((os.getenv("BISDEV") or (ROOT .. "/../_bisdev")) .. "/LibBiSComm-1.0/LibBiSComm-1.0.lua")
    if lib then H.ok(bytes(ROOT .. "/Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua") == lib, "LibBiSComm byte-identical to _bisdev")
    else H.say("  (note) no _bisdev beside the checkout - lib bytes fence skipped") end
end

H.section("the shared BiS channel")
local lib = _G.LibBiSComm
H.ok(lib._booted and lib:Enabled(), "comm booted and on")
H.eq(lib.addons.BiSMemories, TOC_VERSION, "registered with the TOC version")

-- A SECRET ARRIVING ON THE WIRE (4 Oct 2026). On this client CHAT_MSG_ADDON can hand a SECRET VALUE
-- in any of its four arguments - seen in a dungeon, where the client hides chat. A secret is
-- truthy, so `not msg` never caught one: the error came out of `msg .. "|"` inside split, or out of
-- using the sender as a table key, and the lib's OnEvent does not pcall - so it reached the player
-- as a red wall in the middle of a pull.
--
-- This addon shipped 0.5.1 for exactly this shape one layer up, in CHAT_MSG_LOOT. It was still here
-- underneath, in the lib seven addons embed. Found by reading FojjiCore's dungeon journal, which
-- guards its text AND its sender - the sender being the half nobody here had thought of.
do
  local secretMeta = {
    __concat   = function() error("secret value: refused", 0) end,
    __index    = function() error("secret value: refused", 0) end,
    __tostring = function() error("secret value: refused", 0) end,
    __lt       = function() error("secret value: refused", 0) end,
  }
  local function secret() return setmetatable({}, secretMeta) end
  local realSecret = _G.issecretvalue
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end

  local function peerCount()
    local n = 0
    for _ in pairs(lib.peers or {}) do n = n + 1 end
    return n
  end
  local before = peerCount()

  -- the lib must be ON for this to prove anything: a disabled lib returns on its first line and
  -- every one of these would pass with the whole guard deleted
  H.ok(lib:Enabled(), "the lib is on, so the guard is what is being tested")

  for _, case in ipairs({
    { "a secret sender",  lib.PREFIX, "1|X|HI",  "PARTY",  secret()    },
    { "a secret message", lib.PREFIX, secret(),  "PARTY",  "Kumlance"  },
    { "a secret channel", lib.PREFIX, "1|X|HI",  secret(), "Kumlance"  },
    { "a secret prefix",  secret(),   "1|X|HI",  "PARTY",  "Kumlance"  },
  }) do
    local ok = pcall(lib.OnMessage, lib, case[2], case[3], case[4], case[5])
    H.ok(ok, case[1] .. " is dropped, not thrown at the player")
  end
  H.eq(peerCount(), before, "and no peer is made out of one")

  -- Short is the shared door: it takes UnitName() answers too, which also go secret in an instance
  H.eq(lib.Short("Kumlance-Firemaw"), "Kumlance", "a real name still shortens")
  H.eq(lib.Short(secret()), nil, "a secret one answers nil - we do not know who that is")

  _G.issecretvalue = realSecret
end

H.section("the camera")
-- The client's own screenshot call is the one thing this addon cannot fake, so the suite counts it.
local shots, kits, files = 0, 0, 0
_G.Screenshot = function() shots = shots + 1 end
_G.PlaySound = function() kits = kits + 1 return true end
_G.PlaySoundFile = function() files = files + 1 end
_G.UnitLevel = function() return 42 end
_G.GetRealZoneText = function() return "Blackrock Depths" end
_G.GetSubZoneText = function() return "The Grim Guzzler" end
_G.GetNumGroupMembers = function() return 0 end
_G.IsInRaid = function() return false end
_G.UnitExists = function() return false end
local M = NS.M
local clock = 1000
_G.GetTime = function() return clock end
local timers = {}
_G.C_Timer = { After = function(d, fn) timers[#timers + 1] = fn end }
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end

local e = M.Shoot("levelup", "level 42")
H.ok(e ~= nil, "a trigger makes an entry")
H.eq(e.zone, "Blackrock Depths - The Grim Guzzler", "the note says where")
H.eq(e.level, 42, "and at what level")
H.eq(shots, 0, "the shutter waits for the client to finish drawing the moment")
runTimers()
H.eq(shots, 1, "then it fires once")
H.ok(e.file and e.file:find("^WoWScrnShot_"), "and names the file the client will have written", tostring(e.file))

-- The click we make ourselves, because the client only clicks for the PrintScreen key. Sound KITS
-- only: a game file by path is silent on the modern engine and still reports success.
H.ok(kits > 0, "a shot clicks, so silence never means 'did it work?'")
H.eq(files, 0, "and never through a file path, which lies on the modern engine")
clock = clock + 100
kits = 0
_G.BiSMemoriesDB.sound = false
M.Shoot("manual", "quiet")
runTimers()
H.eq(kits, 0, "the click can be switched off")
_G.BiSMemoriesDB.sound = true

-- A loot burst is one memory, not forty pictures.
local blocked, why = M.Shoot("levelup", "again")
H.ok(blocked == nil and why == "too soon", "a second shot inside the gap is refused", tostring(why))
clock = clock + 100
H.ok(M.Shoot("levelup", "later") ~= nil, "and allowed once the gap has passed")
runTimers()

H.section("BiSMemoriesAPI")
do
  local A = _G.BiSMemoriesAPI
  H.eq(A.Ready(), true, "ready once the saved notes are in")

  -- Kinds: every switch, as the player set it - and a copy
  local kinds = A.Kinds()
  H.eq(#kinds, #M.TRIGGERS, "Kinds lists every kind of memory")
  H.ok(kinds[1].key == "levelup" and kinds[1].on == true, "with its key and its switch")
  kinds[1].on = false; kinds[1].key = "edited"
  local again = A.Kinds()
  H.ok(again[1].key == "levelup" and again[1].on == true and _G.BiSMemoriesDB.levelup == true,
       "editing the answer changes nothing")

  -- TakeMemory: the refusals first
  local got, why = A.TakeMemory(nil)
  H.ok(got == nil and why == "no note", "no note, no memory", tostring(why))
  got, why = A.TakeMemory("", "boss")
  H.ok(got == nil and why == "no note", "an empty note is no note", tostring(why))
  got, why = A.TakeMemory("a thing", "nope")
  H.ok(got == nil and why == "no such kind", "an unknown kind is refused", tostring(why))
  _G.BiSMemoriesDB.boss = false
  got, why = A.TakeMemory("first kill", "boss", "BiSGuild")
  H.ok(got == nil and why == "off", "the player's switch for that kind decides", tostring(why))
  H.eq(A.Kinds()[2].on, false, "and Kinds says it is off")
  _G.BiSMemoriesDB.boss = true

  -- a secret note on this client is refused before anything reads it
  local secretMeta = { __concat = function() error("secret", 0) end, __len = function() error("secret", 0) end }
  local realSecret = _G.issecretvalue
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
  local ok
  ok, got, why = pcall(A.TakeMemory, setmetatable({}, secretMeta))
  H.ok(ok and got == nil and why == "no note", "a secret note is no note, not an error", tostring(why))
  _G.issecretvalue = realSecret

  -- callbacks: register, a bad one, and one that throws
  H.ok(select(2, A.RegisterCallback(nil, "BiSMemories_Taken", print)) == "bad owner", "an owner is needed")
  H.ok(select(2, A.RegisterCallback("x", "BiSMemories_Nope", print)) == "no such event", "only real events")
  H.ok(select(2, A.RegisterCallback("x", "BiSMemories_Taken", 5)) == "not a function", "only functions")
  local heard = {}
  H.eq(A.RegisterCallback("BiSGuild", "BiSMemories_Taken", function(ev, mem)
    heard[#heard + 1] = { ev = ev, mem = mem }
    mem.detail = "edited by a listener"
  end), true, "a listener registers")
  H.eq(A.RegisterCallback("Broken", "BiSMemories_Taken", function() error("boom") end), true,
       "so does a broken one")

  -- the real thing: a picture and a note, under the player's gap
  local shotsBefore = shots
  clock = clock + 100
  local mem = A.TakeMemory("guild first: Illidan", "boss", "BiSGuild")
  H.ok(mem and mem.reason == "boss" and mem.detail == "guild first: Illidan" and mem.from == "BiSGuild",
       "TakeMemory makes the memory, kind and asker on it")
  H.eq(mem.zone, "Blackrock Depths - The Grim Guzzler", "with where, like any other")
  H.eq(M.Log()[1].detail, "guild first: Illidan", "it is in the album")
  H.eq(#heard, 0, "nobody hears before the shutter")
  local ok2 = pcall(runTimers)
  H.ok(ok2, "a listener that throws does not reach the player")
  H.eq(shots, shotsBefore + 1, "the shutter fires once")
  H.eq(#heard, 1, "and the listener hears it")
  H.ok(heard[1] and heard[1].ev == "BiSMemories_Taken" and heard[1].mem.file
       and heard[1].mem.file:find("^WoWScrnShot_"), "with the event name and the file stem")
  H.eq(M.Log()[1].detail, "guild first: Illidan", "a listener editing its copy changes nothing")
  mem.detail = "edited"
  H.eq(M.Log()[1].detail, "guild first: Illidan", "nor does editing TakeMemory's answer")

  got, why = A.TakeMemory("again at once")
  H.ok(got == nil and why == "too soon", "the player's gap holds for other addons too", tostring(why))
  clock = clock + 100
  local manual = A.TakeMemory("no kind given")
  H.ok(manual and manual.reason == "manual" and manual.from == nil, "no kind is manual, like /bism now")
  runTimers()
  H.eq(#heard, 2, "the listener hears every shutter")

  -- Latest and Memories answer copies
  local latest = A.Latest()
  H.eq(latest.detail, "no kind given", "Latest is the newest")
  latest.detail = "edited"; latest.with[1] = "Somebody"
  latest = A.Latest()
  H.ok(latest.detail == "no kind given" and latest.with[1] == nil, "editing Latest's answer changes nothing")
  local all = A.Memories()
  H.eq(#all, #M.Log(), "Memories is every memory")
  H.eq(all[2].from, "BiSGuild", "newest first")
  H.eq(#A.Memories(1), 1, "or the newest few")
  all[1].detail = "edited"; table.remove(all, 1)
  H.ok(A.Memories()[1].detail == "no kind given" and #A.Memories() == #M.Log(), "editing Memories' answer changes nothing")

  -- unregistering
  H.eq(A.UnregisterCallback("BiSGuild", "BiSMemories_Taken"), true, "a listener unregisters")
  H.eq(select(2, A.UnregisterCallback("BiSGuild", "BiSMemories_Taken")), "not registered", "only once")
  H.eq(A.UnregisterCallback("Broken", "BiSMemories_Taken"), true, "so does the broken one")
  clock = clock + 100
  A.TakeMemory("unheard")
  runTimers()
  H.eq(#heard, 2, "and hears nothing more")

  -- an empty album: Latest has nothing to say, Memories is an empty list
  local log, saved = M.Log(), {}
  for i = 1, #log do saved[i] = log[i] end
  for i = #log, 1, -1 do log[i] = nil end
  got, why = A.Latest()
  H.ok(got == nil and why == "no memories", "an empty album: nil, \"no memories\"", tostring(why))
  H.eq(#A.Memories(), 0, "and Memories is {}")
  for i = 1, #saved do log[i] = saved[i] end
  clock = clock + 100
end

H.section("what is worth a photograph")
_G.GetItemInfo = function(link)
    local q = tonumber(link:match("QUALITY(%d)")) or 1
    return "Item", link, q
end
_G.GetItemInfoInstant = function(link)
    -- classID 3 is Gem on every client; the harness marks one with GEM in the link
    return 1, "Item", "Sub", "", nil, link:match("GEM") and 3 or 4
end
H.ok(M.LootWorthy("You receive loot: |Hitem:QUALITY4|h[Thunderfury]|h") ~= nil, "epic loot is")
H.ok(M.LootWorthy("You receive loot: |Hitem:QUALITY2|h[Bent Stick]|h") == nil, "a green is not")
H.ok(M.LootWorthy("Kumlust says hello") == nil, "a line with no item is not")

-- A GEM IS A COMPONENT, NOT A KEEPSAKE (4 Oct 2026). Arn in Black Temple: "bis memories tbc doing
-- it on gems too much" - six pictures in ten minutes. They were not drops. The client's
-- LOOT_ITEM_CREATED_SELF is "You create: %s.", so CUTTING a gem loots it, and an epic cut is an
-- epic: he sat down mid-raid, cut three, cut three more, and was photographed every time.
H.ok(M.LootWorthy("You create: |Hitem:QUALITY4GEM|h[Brilliant Lioneye]|h.") == nil,
     "a gem you cut yourself is not a memory - the exact Black Temple case")
H.ok(M.LootWorthy("You receive loot: |Hitem:QUALITY4GEM|h[Shadowsong Amethyst]|h.") == nil,
     "and neither is one that drops")
H.ok(M.LootWorthy("Kingkroo receives loot: |Hitem:QUALITY5GEM|h[Orange Thing]|h.") == nil,
     "a gem is not a memory even at legendary - the switch is about gems, not about quality")

-- WHAT MUST SURVIVE. Cutting a gem is noise; crafting an epic is not, and the fix is aimed at the
-- gem rather than at "You create:" so a crafted weapon still gets its picture.
H.ok(M.LootWorthy("You create: |Hitem:QUALITY4|h[Spellcloth]|h.") ~= nil,
     "crafting an epic that is NOT a gem is still a memory")

_G.BiSMemoriesDB.gems = true
H.ok(M.LootWorthy("You receive loot: |Hitem:QUALITY4GEM|h[Shadowsong Amethyst]|h.") ~= nil,
     "unless you ask for them back")
_G.BiSMemoriesDB.gems = false

-- A CLIENT WITH NO INSTANT LOOKUP falls back to the type NAME, which is English-only and so is
-- never asked first - the same reason LootIsMine reads the client's own strings instead of "You".
do
  local realInstant = _G.GetItemInfoInstant
  local realInfo = _G.GetItemInfo
  _G.GetItemInfoInstant = nil
  _G.GetItemInfo = function(link)
    local q = tonumber(link:match("QUALITY(%d)")) or 1
    return "Item", link, q, 70, 70, link:match("GEM") and "Gem" or "Weapon"
  end
  H.ok(M.LootWorthy("You create: |Hitem:QUALITY4GEM|h[Brilliant Lioneye]|h.") == nil,
       "no instant lookup: the type name still catches the gem")
  H.ok(M.LootWorthy("You create: |Hitem:QUALITY4|h[Spellcloth]|h.") ~= nil,
       "and still lets the crafted epic through")
  _G.GetItemInfoInstant, _G.GetItemInfo = realInstant, realInfo
end

-- SOMEBODY ELSE'S PURPLE IS NOT A MEMORY. CHAT_MSG_LOOT carries the whole raid's, and Arn watched
-- it fire on every epic in a 25-man: "otherwise it takes for all purple loot". Mine at the
-- threshold, anyone's legendary - an orange dropping is the room's memory, not just the winner's.
--
-- The client's own strings decide whose it is, so this works in a language nobody here reads.
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
H.ok(M.LootIsMine("You receive loot: |Hitem:QUALITY4|h[Thunderfury]|h."), "my own loot line is mine")
H.ok(not M.LootIsMine("Kingkroo receives loot: |Hitem:QUALITY4|h[Thunderfury]|h."), "somebody else's is not")
H.ok(M.LootIsMine("You receive item: |Hitem:QUALITY4|h[Thing]|h."), "and a pushed item is mine too")
H.ok(M.LootWorthy("You receive loot: |Hitem:QUALITY4|h[Thunderfury]|h.") ~= nil, "my epic is worth one")
H.ok(M.LootWorthy("Kingkroo receives loot: |Hitem:QUALITY4|h[Thunderfury]|h.") == nil,
     "a raider's epic is not - that was one picture every few seconds")
H.ok(M.LootWorthy("Kingkroo receives loot: |Hitem:QUALITY5|h[Sulfuras]|h.") ~= nil,
     "but a legendary is, whoever won it")

-- a translated client: the word for "you" is not "You", and the pattern still has to hold
_G.LOOT_ITEM_SELF = "Du erhaeltst Beute: %s."
_G.LOOT_ITEM_SELF_MULTIPLE, _G.LOOT_ITEM_PUSHED_SELF = nil, nil
H.ok(M.LootIsMine("Du erhaeltst Beute: |Hitem:QUALITY4|h[Ding]|h."),
     "whose loot it is comes from the client's strings, not from the word 'You'")
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
_G.BiSMemoriesDB.lootQuality = 2
H.ok(M.LootWorthy("You receive loot: |Hitem:QUALITY2|h[Bent Stick]|h") ~= nil, "unless you lower the bar")
_G.BiSMemoriesDB.lootQuality = 4

-- A wipe is not a memory: ENCOUNTER_END fires either way and the fifth argument is the difference.
clock = clock + 100
H.ok(M.OnEvent("ENCOUNTER_END", 1, "Nefarian", 1, 40, 0) == nil, "a wipe takes no picture")
H.ok(M.OnEvent("ENCOUNTER_END", 1, "Nefarian", 1, 40, 1) ~= nil, "a kill does")

-- A switch that is off means no picture, however good the moment.
clock = clock + 100
_G.BiSMemoriesDB.death = false
H.ok(M.OnEvent("PLAYER_DEAD") == nil, "a trigger turned off stays off")
_G.BiSMemoriesDB.death = true

H.section("the log")
clock = clock + 100
_G.BiSMemoriesDB.keep = 3
for i = 1, 5 do
    clock = clock + 100
    M.Shoot("manual", "note " .. i)
end
H.eq(#M.Log(), 3, "the log is capped")
H.eq(M.Log()[1].detail, "note 5", "newest first")
H.ok(rawequal(M.Log(), _G.BiSMemoriesDB.log), "and lives in SavedVariables, so it survives a logout")
_G.BiSMemoriesDB.keep = 250

H.section("/bism (and /memories)")
H.ok(type(_G.SlashCmdList.BISMEMORIES) == "function", "slash registered")
-- /bism IS THE NAME (Arn, 12 Oct 2026): the family's /bis* commands - /bish, /bist, /bisg, /bism.
-- /memories stays an alias so nobody's macros or habits break.
H.eq(_G.SLASH_BISMEMORIES1, "/bism", "as /bism, first")
H.eq(_G.SLASH_BISMEMORIES2, "/memories", "and /memories still registered after it")
do
    -- The client's way of finding a handler: walk SlashCmdList, compare the typed word to every
    -- SLASH_<KEY>n, case-insensitive. Not a table lookup - so an alias registered under the wrong
    -- key, or not at all, fails here the way it would at the keyboard.
    local function typed(line)
        local word, rest = line:match("^(%S+)%s*(.-)$")
        for key, fn in pairs(_G.SlashCmdList) do
            local i = 1
            while _G["SLASH_" .. key .. i] do
                if _G["SLASH_" .. key .. i]:lower() == word:lower() then return key, fn, rest end
                i = i + 1
            end
        end
    end
    local k1, f1 = typed("/bism status")
    local k2, f2 = typed("/memories status")
    H.eq(k1, "BISMEMORIES", "/bism reaches the addon")
    H.ok(f1 ~= nil and rawequal(f1, f2), "/memories reaches the very same handler", tostring(k2))
    local _, _, rest = typed("/MEMORIES now Hello There")
    H.eq(rest, "now Hello There", "the alias passes its words through untouched")

    said = {}
    _G.SlashCmdList.BISMEMORIES("help")
    local help = table.concat(said, " ")
    H.ok(help:find("/bism", 1, true), "the help line says /bism", help)
    H.ok(not help:find("/memories", 1, true), "and not /memories", help)

    -- NO USER-FACING TEXT STILL TELLS A PLAYER TO TYPE /memories. Code comments may keep the old
    -- name (history); strings, the README, the album's README and the TOC may not. The one literal
    -- allowed is the alias itself, "/memories" with nothing after it.
    local function slurp(rel)
        local fh = io.open(ROOT .. "/" .. rel, "rb")
        if not fh then return nil end
        local s = fh:read("*a")
        fh:close()
        return s
    end
    local function code(src)
        src = src:gsub("%-%-%[(=*)%[.-%]%1%]", "")   -- block comments
        src = src:gsub("%-%-[^\n]*", "")             -- line comments
        return src
    end
    for _, rel in ipairs(FILES) do
        if rel:match("^Core") then
            local src = slurp(rel:gsub("\\", "/"))
            H.ok(src ~= nil, rel .. " readable")
            if src then
                local stray = code(src):match("[^\n]*/memories[^\"\n][^\n]*")
                H.ok(stray == nil, rel .. ": no string tells a player to type /memories", stray)
            end
        end
    end
    for _, rel in ipairs({ "README.md", "Album/README.txt", "Album/BiSMemories-Album.html", "BiSMemories.toc" }) do
        local src = slurp(rel)
        H.ok(src ~= nil, rel .. " readable")
        if src then
            H.ok(not src:find("/memories ", 1, true), rel .. ": no '/memories ...' left to type",
                src:match("[^\n]*/memories [^\n]*"))
        end
    end
end
said = {}
_G.SlashCmdList.BISMEMORIES("status")
local blob = table.concat(said, " | ")
H.ok(blob:find(TOC_VERSION, 1, true), "status carries the version", blob)
said = {}
_G.SlashCmdList.BISMEMORIES("off boss")
H.eq(_G.BiSMemoriesDB.boss, false, "a trigger can be switched off by name")
_G.SlashCmdList.BISMEMORIES("on boss")
H.eq(_G.BiSMemoriesDB.boss, true, "and back on")
_G.SlashCmdList.BISMEMORIES("clear")
H.eq(#M.Log(), 0, "clear forgets the notes")
said = {}
_G.SlashCmdList.BISMEMORIES("")
H.ok(table.concat(said, " "):find("nothing yet", 1, true), "and says so plainly")

H.section("zones, duels and exalted")
M.Char().zones = {}
M.zoneShots = 0
H.ok(M.NewZone("Elwynn Forest") == nil, "the first zone it ever sees is remembered, not shot")
H.ok(M.NewZone("Westfall") == "Westfall", "the next new one is a memory")
H.ok(M.NewZone("Westfall") == nil, "and only the first time")

-- WHERE YOU HAVE BEEN IS LEARNED EVERYWHERE, not only where the camera fires. Arn, 24 Sep:
-- "memories is taking too many screenshots of places that i have already been at". His saved file,
-- after days of play, held ONE zone - Thunder Bluff - beside a log of pictures all taken on
-- Zephras Isle. The list was only ever written at the moment ZONE_CHANGED_NEW_AREA fired, and on
-- this client that event stays quiet for whole evenings; everywhere he walked in between remained
-- unknown, ready to be "new" the next time it did speak up.
do
  local realGet = _G.GetRealZoneText
  M.Char().zones = {}
  M.zoneShots = 0
  M.SeeZone("Mulgore")                                  -- so nothing below is the free first one

  -- FIRED, not called: the camera only hears an event it actually registered for, and a test
  -- that calls OnEvent by hand passes just as happily when the name is missing from the list.
  _G.GetRealZoneText = function() return "The Barrens" end
  fire("ZONE_CHANGED")
  H.ok(M.Char().zones["The Barrens"] == true, "a quiet zone change is still written down")
  H.ok(M.NewZone("The Barrens") == nil, "so walking back in later is not worth a picture")

  _G.GetRealZoneText = function() return "Ashenvale" end
  fire("ZONE_CHANGED_INDOORS")
  H.ok(M.Char().zones["Ashenvale"] == true, "and so is stepping indoors")

  -- a picture taken anywhere is proof you were there, whatever the reason was
  _G.GetRealZoneText = function() return "Durotar" end
  local dz = NS.DB()
  dz.levelup, dz.gap = true, 0
  M.OnEvent("PLAYER_LEVEL_UP", 12)
  H.ok(M.Char().zones["Durotar"] == true,
       "a photograph of a place is proof enough that you have been there")

  -- AND A CEILING ON THE CAMERA, whatever the client does: three new places in one session is a
  -- good day's exploring, and the fortieth is a bug with a camera. Learning is not rationed.
  _G.GetRealZoneText = realGet
  M.zoneShots = 0
  local shot = 0
  for i = 1, 8 do
    if M.NewZone("Place " .. i) then shot = shot + 1 end
  end
  H.eq(shot, 3, "at most three new-place pictures in one session")
  H.ok(M.Char().zones["Place 8"] == true,
       "but all eight are written down, so none of them is new tomorrow")
  M.zoneShots = 0
end

_G.UnitName = function(u) return u == "player" and "Kumlust Surname" or "Someone" end
-- TBC writes "%s has defeated %s"; WoW Forever writes "%1$s has defeated %2$s" (seen in game,
-- 18 Sep 2026) so a translator can swap the names round. A builder that knows only %s turns %1$s
-- into %1, which Lua reads as a capture back-reference: "invalid capture index" on EVERY system
-- message the client prints, including "You feel rested."
_G.DUEL_WINNER_KNOCKOUT = "%s has defeated %s in a duel"
_G.DUEL_WINNER_RETREAT = "%s has fled from %s in a duel"
H.eq(M.DuelWon("Kumlust Surname has defeated Dps1 in a duel"), "Dps1", "a duel win is read from the client's own sentence")
H.ok(M.DuelWon("Dps1 has defeated Kumlust Surname in a duel") == nil, "losing is not a memory")
H.ok(M.DuelWon("Kumlust Surname says hello") == nil, "and neither is chatter")
H.ok(M.DuelWon("You feel rested.") == nil, "and an ordinary system line does not throw")

_G.DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel"
_G.DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel"
H.eq(M.DuelWon("Kumlust Surname has defeated Dps1 in a duel"), "Dps1", "the positional form reads the same")
H.ok(M.DuelWon("Dps1 has defeated Kumlust Surname in a duel") == nil, "and losing still is not a memory")
-- the retreat line names the LOSER first: the order table is what keeps the winner straight
H.eq(M.DuelWon("Dps1 has fled from Kumlust Surname in a duel"), "Dps1", "a fled duel names the winner by argument, not by position")
H.ok(M.DuelWon("You feel rested.") == nil, "and still nothing throws")

_G.FACTION_STANDING_LABEL8 = "Exalted"
H.ok(M.WentExalted("You are now Exalted with Argent Dawn.") ~= nil, "exalted is caught")
H.ok(M.WentExalted("You are now Revered with Argent Dawn.") == nil, "revered is not")

H.section("the candid, one a week")
local d = _G.BiSMemoriesDB
d.candidLast = nil
H.ok(M.CandidDue(1000000) == true, "never taken one: due")
d.candidLast = 1000000
H.ok(M.CandidDue(1000000 + 60) == false, "taken today: not due")
H.ok(M.CandidDue(1000000 + 8 * 24 * 60 * 60) == true, "a week later: due again")
d.candid = false
H.ok(M.CandidDue(1000000 + 8 * 24 * 60 * 60) == false, "switched off: never due")
d.candid = true

-- it must NOT fire on login: that would be the same loading screen fifty-two times a year
d.candidLast = nil
M.candidArmed = false
clock = clock + 100
shots = 0
local wait = M.ArmCandid()
H.ok(wait and wait >= 60, "the candid is booked for later in the session, not now", tostring(wait))
H.eq(shots, 0, "so nothing is taken at the loading screen")
runTimers()
H.ok(shots > 0, "and it lands when its moment comes")
H.ok((d.candidLast or 0) > 0, "the week is marked, so it happens once")

-- Ten expansions apart: an event this client has never heard of must not take the file down.
H.ok(M.OnEvent("SOME_EVENT_FROM_2036") == nil, "an unknown event is ignored, not an error")

H.section("the off switch survives a logout")
lib:SetEnabled(false)
fire("PLAYER_LOGOUT")
H.eq(_G.BiSMemoriesDB.comm, false, "off is saved")
lib:SetEnabled(true)
fire("PLAYER_LOGOUT")
H.eq(_G.BiSMemoriesDB.comm, true, "on is saved")

-- WHAT IT HEARD (19 Sep 2026). Arn: "the album in the addon folder is not updating" - and the
-- album was right, there was one memory in six hours. An album with one picture has two
-- explanations, "nothing worth remembering happened" and "the event never arrived", and they look
-- identical from outside. The saved variables held the answer by accident: no `zones` key at all,
-- so ZONE_CHANGED_NEW_AREA had never once fired. This makes that readable in game instead.
do
  M.heard, M.recent = {}, {}
  M.OnEvent("PLAYER_ENTERING_WORLD")
  M.OnEvent("SOME_EVENT_FROM_2036")
  H.eq(M.heard["PLAYER_ENTERING_WORLD"], 1, "an event it hears is counted")
  M.OnEvent("PLAYER_ENTERING_WORLD")
  H.eq(M.heard["PLAYER_ENTERING_WORLD"], 2, "and counted again the second time")
  H.eq(M.recent[1].event, "PLAYER_ENTERING_WORLD", "the newest is first")
  H.ok(M.recent[1].why ~= "TOOK ONE", "and carries the verdict, not just the name")

  -- the useful half: what has NOT arrived
  local quiet = {}
  for _, e in ipairs(M.Unheard()) do quiet[e] = true end
  H.ok(quiet["ZONE_CHANGED_NEW_AREA"], "an event that never arrived is named")
  H.ok(not quiet["PLAYER_ENTERING_WORLD"], "one that did is not")

  -- a real memory says so. The clock has to move: the camera holds an 8 second gap between
  -- shots, and an earlier check in this file has just used one.
  M.heard, M.recent = {}, {}
  clock = clock + 100
  _G.BiSMemoriesDB.levelup = true
  M.OnEvent("PLAYER_LEVEL_UP", 40)
  H.eq(M.recent[1].why, "TOOK ONE", "taking a picture is what the breadcrumb says")

  -- THE SAME THING TWICE RUNNING IS ONE LINE. Fifteen loot lines in a quiet evening printed six
  -- identical rows in game and pushed everything else off the top (Arn's screenshot, 19 Sep).
  M.heard, M.recent = {}, {}
  for _ = 1, 6 do M.OnEvent("CHAT_MSG_LOOT", "you loot something dull") end
  H.eq(#M.recent, 1, "six of the same in a row is one line")
  H.eq(M.recent[1].n, 6, "with the count on it")
  H.eq(M.heard["CHAT_MSG_LOOT"], 6, "and all six still counted")
  M.OnEvent("PLAYER_ENTERING_WORLD")
  M.OnEvent("CHAT_MSG_LOOT", "you loot something dull")
  H.eq(#M.recent, 3, "something else in between starts a new line")

  -- and the list is capped, so a long session cannot grow it without end
  M.recent = {}
  for i = 1, M.RECENT_KEEP + 10 do
    M.OnEvent(i % 2 == 0 and "SOME_EVENT_FROM_2036" or "ANOTHER_FROM_2036")
  end
  H.eq(#M.recent, M.RECENT_KEEP, "the last few, not every event since login")
end

-- THE CLIENT THAT LOSES THE ACCOUNT FILE (Forever beta, measured 19 Sep 2026). It writes
-- BiSMemoriesDB perfectly and hands back nothing at the next login - two zone memories went that
-- way between one save and the next. The per-character file is a different file in a different
-- folder and it survives; BiSHealing proved that the same afternoon. So: write both, and at login
-- take whichever came back.
do
  _G.BiSMemoriesDB = { log = { { at = 1, file = "WoWScrnShot_1", reason = "zone", detail = "Mulgore" } } }
  _G.BiSMemoriesCharDB = nil
  fire("PLAYER_LOGOUT")
  H.ok(type(_G.BiSMemoriesCharDB) == "table" and _G.BiSMemoriesCharDB.log[1].detail == "Mulgore",
       "logging out writes the per-character copy")
  H.ok(not rawequal(_G.BiSMemoriesCharDB, _G.BiSMemoriesDB),
       "and it is a SEPARATE table - an alias would be one file saved and one lost")

  local kept = _G.BiSMemoriesCharDB
  _G.BiSMemoriesDB = nil                      -- the client loses the account-wide one
  _G.BiSMemoriesCharDB = kept
  fire("ADDON_LOADED", "BiSMemories")
  H.ok(NS.rescued == true, "the next login notices")
  H.eq(M.Log()[1].detail, "Mulgore", "and the memory is still there")

  -- a client that keeps both is left alone
  _G.BiSMemoriesDB = { log = { { at = 2, file = "WoWScrnShot_2", reason = "zone", detail = "Barrens" } } }
  _G.BiSMemoriesCharDB = kept
  fire("ADDON_LOADED", "BiSMemories")
  H.ok(NS.rescued == false and M.Log()[1].detail == "Barrens",
       "a client that hands back both changes nothing")

  -- WHERE YOU HAVE BEEN COMES HOME ON ITS OWN, not as a passenger on the log. The rescue above is
  -- gated on the log, and `zones` only ever rode along with it - so a character who had taken no
  -- photograph yet started every login with an empty map, and everywhere they knew was "new"
  -- again. That is the 24 Sep complaint, in one line of saved variables.
  _G.BiSMemoriesDB = { log = { { at = 3, file = "WoWScrnShot_3", reason = "boss", detail = "Moroes" } } }
  _G.BiSMemoriesCharDB = { zones = { ["Thunder Bluff"] = true, ["Mulgore"] = true } }
  fire("ADDON_LOADED", "BiSMemories")
  H.ok(_G.BiSMemoriesDB.zones and _G.BiSMemoriesDB.zones["Thunder Bluff"],
       "the places come back even when the log did not need rescuing")

  -- and MERGED, not replaced: neither copy is more right about a place than the other
  _G.BiSMemoriesDB = { zones = { ["Durotar"] = true },
                       log = { { at = 4, file = "WoWScrnShot_4", reason = "boss", detail = "Attumen" } } }
  _G.BiSMemoriesCharDB = { zones = { ["Ashenvale"] = true } }
  fire("ADDON_LOADED", "BiSMemories")
  H.ok(_G.BiSMemoriesDB.zones["Durotar"] and _G.BiSMemoriesDB.zones["Ashenvale"],
       "two half-remembered maps make one whole one")
end

-- THE JOURNAL. Arn asked for the album in the addon, reading the Screenshots folder. The reading
-- half is impossible - no addon can list a directory, and a .jpg outside Interface\ cannot be
-- drawn - so this is the words half, and these tests hold it to that: what happened, newest
-- first, and honest when there is nothing.
do
  local J = NS.J
  H.ok(J ~= nil, "there is a journal")

  local log = M.Log()
  for i = #log, 1, -1 do log[i] = nil end

  -- EMPTY IS A STATE, not a bug. On this client the log starts empty at every login, so the
  -- window people see most often is this one, and it has to say why rather than look broken.
  J.Show()
  H.ok(J.frame:IsShown(), "it opens")
  H.ok(strip(J.frame.kind._text):find("nothing yet"), "and an empty log says so in words")
  H.eq(J.frame.rows[1]._text, "", "with no stale row left behind")

  -- forty memories, newest first (more than the 0.9.0 window's rows)
  for i = 1, 40 do
    table.insert(log, 1, { at = 1000 + i, reason = "zone", detail = "place " .. i,
                           zone = "Mulgore", with = {}, file = "WoWScrnShot_" .. i })
  end
  J.Refresh()
  -- ROW 1 IS THE NIGHT'S HEADING NOW, and the memories hang under it. These twenty were written
  -- a second apart, so they are all one "night" - which is the rule doing exactly what it says.
  H.ok(strip(J.frame.rows[1]._text):find("Mulgore"), "the night's heading is at the top",
       strip(J.frame.rows[1]._text))
  H.ok(strip(J.frame.rows[2]._text):find("place 40"), "the newest memory is under it")
  H.ok(strip(J.frame.rows[3]._text):find("place 39"), "and the one before it under that")
  H.ok(strip(J.frame.count._text):find("40 kept"), "the footer counts the memories, not the lines")

  -- the wheel walks it, and stops at the ends rather than running off
  H.eq(J.Scroll(3), 3, "the wheel moves down the list")
  H.ok(strip(J.frame.rows[1]._text):find("place 38"), "and the page follows",
       strip(J.frame.rows[1]._text))
  H.eq(J.Scroll(-99), 0, "it will not go above the newest")
  H.eq(J.Scroll(99), 41 - J.ROWS, "nor past the oldest - 40 memories plus a heading, a page of rows")

  -- A MEMORY LANDING WHILE IT IS OPEN pulls it forward. Through M.Shoot, the path the game
  -- actually takes - calling J.Touch() by hand here proved only that Touch works, and passed
  -- happily with the hook in Memories.lua deleted. The wiring is the thing being claimed.
  J.Scroll(-99)
  local d = NS.DB()
  d.levelup, d.gap = true, 0        -- M.Shoot refuses if the trigger is off or the gap is unmet
  H.ok(M.Shoot("levelup", "level 19") ~= nil, "the memory is actually taken")
  H.ok(strip(J.frame.rows[2]._text):find("level 19"),
       "a new memory appears without reopening, under the heading",
       strip(J.frame.rows[2]._text))

  J.Hide()
  H.ok(not J.frame:IsShown(), "and it closes")
end

-- THE ALBUM PAGE SHIPS. It is not Lua and the suite cannot run it, but it CAN check the two
-- things that would make it useless without anyone noticing: that the files are still there to
-- be zipped, and that the page still carries the folder picker it is built around. A shipped
-- file that quietly stops shipping looks exactly like a file that was never there.
do
  local page = bytes(HERE .. "/../Album/BiSMemories-Album.html")
  H.ok(page ~= nil, "the album page is in the addon folder, to be shipped")
  H.ok(page and page:find("webkitdirectory", 1, true) ~= nil,
       "and it still has the folder picker it is built around")
  H.ok(page and page:find("entryAround", 1, true) ~= nil,
       "and reads the notes by walking braces, not by splitting on a comma")
  H.ok(page and page:find("function sessions(", 1, true) ~= nil,
       "and groups by raid night, not by calendar day - a night that ends after midnight is one night")
  -- 0.9.0: the kinds in plain words, whose memories, the year so far
  H.ok(page and page:find("var WORDS", 1, true) and page:find('levelup: "Level up"', 1, true),
       "the album says the kinds in plain words, the same as the journal")
  H.ok(page and page:find("function people(", 1, true) and page:find('char: get(block, "char")', 1, true),
       "and can show one character's memories, from the notes' own names")
  H.ok(page and page:find("function year(", 1, true), "and adds up the year so far")
  H.ok(page and page:find("http", 1, true) == nil or not page:find("src=\"http", 1, true),
       "nothing is fetched from the internet: it must work offline")
  H.ok(bytes(HERE .. "/../Album/README.txt") ~= nil, "with the instructions beside it")
  -- ONE STEP (Arn, 21 Oct 2026: "make it easy like the google notebook thing"): hand it the WoW folder and it
  -- finds both halves; it walks only where they can be (never Data or Interface); the X closes (the side
  -- strips used to cover it). The logic itself was run in a browser on the day it was written.
  H.ok(page and page:find("function kindOf(", 1, true) and page:find("function worthWalking(", 1, true)
       and page:find("function take(", 1, true), "one step: the page finds the pictures and the notes itself")
  H.ok(page and page:find("^(Interface|Data|Cache|Logs", 1, true), "and never walks Data or Interface")
  H.ok(page and page:find("Drag your WoW folder onto this page", 1, true)
       and not page:find("Add the addon's notes (optional)", 1, true), "one instruction, not two buttons and an essay")
  H.ok(page and page:find("top: 70px", 1, true) and page:find("z-index: 2", 1, true), "the lightbox's X sits above the side strips")

  -- THE ACCOUNT FOLDER IS NOT ALWAYS ONE (4 Oct 2026). The page said `<ACCOUNT>` is "a number and
  -- a hash" and that there is "usually only one folder" - and both were wrong on the author's own
  -- machine: two folders, the populated one called ARNOLD891, the number-and-hash one nearly
  -- empty. Arn: "some people can have multiple accounts and run at the same time". Our own
  -- instructions were sending those players into the wrong folder to find a file that is not
  -- there, which reads as "the addon saved nothing".
  local readme = bytes(HERE .. "/../Album/README.txt")
  H.ok(page and page:find("only one folder", 1, true) == nil,
       "the page no longer claims there is usually only one account folder")
  H.ok(readme and readme:find("only one folder", 1, true) == nil,
       "and neither does the README")
  H.ok(readme and readme:find("more than one", 1, true) ~= nil,
       "they say to look for the folder that HAS the file instead")

  -- IT REMEMBERS THE NOTES, AND SAYS SO. The saved file is the one nobody finds twice - it is in
  -- WTF, not AddOns - so the page keeps the notes between visits and only asks for the pictures.
  -- The "forget" is not decoration: notes kept silently go stale, and a picture taken after the
  -- save has no caption, which looks exactly like the addon having stopped writing them.
  H.ok(page and page:find("localStorage", 1, true) ~= nil,
       "the album remembers the notes between visits, so only the pictures are asked for")
  H.ok(page and page:find("function forget(", 1, true) ~= nil,
       "and can be told to forget them - kept notes go stale and must not be a trap")
end

-- A MEMORY TAKEN WHILE THE CLIENT IS HIDING THINGS. Boss kills and deaths fire IN COMBAT, which
-- is exactly when this client turns answers into secret values - and a secret is not a nil, it is
-- a value that ERRORS the moment anything reads it. Unguarded, the camera would throw at the one
-- moment worth a picture, and anything that got through would be written into saved variables.
--
-- The mock cannot be a real secret (Lua has no hook for truthiness), but it can error on the
-- reads that matter - concat, compare, tostring - which is what the client does and what the
-- unguarded code would have done.
do
  local secretMeta = {
    __concat = function() error("secret value: refused", 0) end,
    __eq = function() error("secret value: refused", 0) end,
    __lt = function() error("secret value: refused", 0) end,
    __tostring = function() error("secret value: refused", 0) end,
  }
  local function secret() return setmetatable({}, secretMeta) end
  local realLevel, realName, realSecret = _G.UnitLevel, _G.UnitName, _G.issecretvalue
  local realNum, realExists = _G.GetNumGroupMembers, _G.UnitExists
  _G.UnitLevel = function() return secret() end
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
  -- A PARTY OF THREE, so the roster half is actually walked: one name the client will say, two it
  -- will not. With no group at all this test looked green while the names guard was deleted.
  _G.GetNumGroupMembers = function() return 3 end
  _G.UnitExists = function() return true end
  _G.UnitName = function(u) return u == "party1" and "Kumlance" or secret() end

  local d = NS.DB()
  d.boss, d.gap = true, 0
  local took, err = pcall(M.Shoot, "boss", "a first kill")
  H.ok(took, "a memory taken while the client is hiding things does not throw", tostring(err))

  local e = M.Log()[1]
  H.ok(e ~= nil and e.level == 0, "a level it cannot read is written down as 0, not as a secret")
  H.ok(e ~= nil and type(e.with) == "table", "and the roster is still a list")
  for _, who in ipairs((e or {}).with or {}) do
    H.ok(type(who) == "string", "every name kept is a real string, never a secret", tostring(who))
  end

  H.ok(#((M.Log()[1] or {}).with or {}) == 1,
       "the one name it would say is kept, the two it hid are dropped",
       #((M.Log()[1] or {}).with or {}))

  -- AND A HIDDEN ZONE NAME NEVER BECOMES A KEY. Every other client value in this file is
  -- scrubbed; the one place that used one as a table KEY took it raw. A secret is a new object
  -- every time it is asked for, so such a key can never match itself again: the zone would be
  -- "new" on every crossing, for ever, and a thing no test can name would be sitting in the
  -- player's saved variables.
  -- A SECRET STRING IS STILL A STRING. The metatable above errors on the reads that matter, which
  -- is faithful for concat and compare - but `type()` on it says "table", and that alone would
  -- turn away a name the real client hands over as a perfectly ordinary-looking string. The only
  -- honest stand-in is a plain string the client ADMITS is secret, which is what issecretvalue is
  -- for, and the only guard that can then reject it is the one being tested.
  local realZoneText, realSecret2 = _G.GetRealZoneText, _G.issecretvalue
  _G.issecretvalue = function(v) return v == "Hidden Hollow" or getmetatable(v) == secretMeta end
  _G.GetRealZoneText = function() return "Hidden Hollow" end
  local before = 0
  for _ in pairs(_G.BiSMemoriesDB.zones or {}) do before = before + 1 end
  local asked, verdict = pcall(M.NewZone, _G.GetRealZoneText())
  H.ok(asked and verdict == nil, "a zone the client hides is not a new place", tostring(verdict))
  -- and the same for the quiet door into the list, which has its own guard to keep
  local learnt, why2 = pcall(M.SeeZone, _G.GetRealZoneText())
  H.ok(learnt and why2 == nil, "nor is it quietly learned by the other door", tostring(why2))
  local after = 0
  for _ in pairs(_G.BiSMemoriesDB.zones or {}) do after = after + 1 end
  H.eq(after, before, "and nothing a test cannot name is written into the list")
  H.ok((_G.BiSMemoriesDB.zones or {})["Hidden Hollow"] == nil,
       "a name the client hides never becomes a key - it could never match itself again")
  _G.GetRealZoneText, _G.issecretvalue = realZoneText, realSecret2
  _G.UnitLevel, _G.UnitName, _G.issecretvalue = realLevel, realName, realSecret
  _G.GetNumGroupMembers, _G.UnitExists = realNum, realExists
end

-- AN EVENT WHOSE TEXT IS SECRET. Arn, 21 Sep, in a dungeon: "attempt to index local 'msg' (a
-- secret string value)" in DuelWon, from a CHAT_MSG_SYSTEM the client had hidden. Every parser
-- reads its argument, so a secret one is taken out before any of them sees it.
do
  local boom = function() error("attempt to index a secret string value", 0) end
  local secretMeta = { __index = boom, __concat = boom, __eq = boom, __lt = boom, __le = boom,
                       __len = boom, __tostring = boom }
  local function secret() return setmetatable({}, secretMeta) end
  local realSecret, realZone = _G.issecretvalue, _G.GetRealZoneText
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
  local d = NS.DB()
  d.boss, d.duel, d.loot, d.exalted, d.gap = true, true, true, true, 0
  M.hidden = {}
  local before = #M.Log()
  -- THE MOCK CANNOT BE A STRING: in the client a secret string still answers type() == "string",
  -- so the parsers' own `type(msg) ~= "string"` checks let it through and it blew up on the read.
  -- A table-shaped fake is turned away by those checks and would pass without the guard - so the
  -- guard is tested where it acts: no parser is ever handed anything secret.
  local realDecide, leaked = M.Decide, 0
  M.Decide = function(event, ...)
    for i = 1, select("#", ...) do
      if getmetatable((select(i, ...))) == secretMeta then leaked = leaked + 1 end
    end
    return realDecide(event, ...)
  end

  local ok1 = pcall(M.OnEvent, "CHAT_MSG_SYSTEM", secret())
  H.ok(ok1, "a secret system line does not throw - the DuelWon crash")
  local ok2 = pcall(M.OnEvent, "CHAT_MSG_LOOT", secret())
  local ok3 = pcall(M.OnEvent, "CHAT_MSG_COMBAT_FACTION_CHANGE", secret())
  H.ok(ok2 and ok3, "nor a secret loot or faction line")
  H.ok(M.hidden.CHAT_MSG_SYSTEM == 1 and M.hidden.CHAT_MSG_LOOT == 1, "and each is counted")
  H.ok((M.recent[1] or {}).why == "hidden by the client", "the breadcrumb says why nothing was taken",
       tostring((M.recent[1] or {}).why))

  -- a boss kill with a hidden name is still a memory - only the name is lost
  local ok4, entry = pcall(M.OnEvent, "BOSS_KILL", 1, secret())
  H.ok(ok4 and entry and entry.detail == "first kill: a boss", "a boss kill with a hidden name still gets its picture",
       tostring(entry and entry.detail))
  H.ok(#M.Log() == before + 1, "exactly one memory from all of that")
  H.ok(leaked == 0, "and no parser was ever handed a secret", leaked)
  M.Decide = realDecide

  -- and a hidden zone name is written as "?", not read
  _G.GetRealZoneText = function() return secret() end
  local ok5, e5 = pcall(M.Shoot, "boss", "zone test")
  H.ok(ok5 and e5 and type(e5.zone) == "string" and e5.zone:sub(1, 1) == "?",
       "a hidden zone is written as ?", tostring(e5 and e5.zone))
  _G.issecretvalue, _G.GetRealZoneText = realSecret, realZone
end

-- A RAID NIGHT IS ONE SECTION, EVEN WHEN IT ENDS AFTER MIDNIGHT. Arn: "a section could be a raid
-- night, all the raid bossed killed in one night in their own section of that raid night". The
-- calendar is the wrong unit - start at eight, kill the last boss at twenty to one, and grouping
-- by day orphans the last two bosses into tomorrow while the night they belonged to sits above.
do
  local J = NS.J
  local log = M.Log()
  for i = #log, 1, -1 do log[i] = nil end

  -- newest first, as the addon keeps them. 20:04 Sat -> 00:41 Sun, then a quiet afternoon before.
  -- BUILT, NOT GUESSED. The first version used a round epoch number and the "does this really
  -- cross midnight" check caught it: it was some hour in the afternoon, so the test would have
  -- proved the grouping works on a night that never crossed anything.
  local sat8pm = os.time({ year = 2026, month = 9, day = 19, hour = 20, min = 4, sec = 0 })
  local night = {
    { at = sat8pm + 4*3600 + 37*60, reason = "boss",    detail = "Prince",  zone = "Karazhan" },
    { at = sat8pm + 3*3600,         reason = "loot",    detail = "a sword", zone = "Karazhan" },
    { at = sat8pm + 1*3600,         reason = "boss",    detail = "Moroes",  zone = "Karazhan" },
    { at = sat8pm,                  reason = "levelup", detail = "level 70", zone = "Karazhan" },
    { at = sat8pm - 8*3600,         reason = "candid",  detail = "a walk",  zone = "The Barrens" },
  }
  for _, e in ipairs(night) do log[#log + 1] = e end

  local lines = J.Lines()
  H.eq(#lines, 7, "five memories become five lines and two headings")
  H.ok(lines[1].head ~= nil, "a heading comes first")
  H.eq(lines[1].head.bosses, 2, "the night knows how many bosses died in it")
  H.ok(strip(J.Head(lines[1].head)):find("Karazhan"),
       "and is named for where they died", strip(J.Head(lines[1].head)))
  for i = 2, 5 do H.ok(lines[i].entry ~= nil, "the night's memories hang under it") end
  H.ok(lines[6].head ~= nil, "the afternoon eight hours earlier is its own section")
  H.ok(strip(J.Head(lines[6].head)):find("Barrens"), "named for where it happened")

  -- and the proof it is not the calendar doing this: the night spans midnight and stays one
  local crossed = os.date("%d", night[1].at) ~= os.date("%d", night[4].at)
  H.ok(crossed, "this night really does cross midnight (or the fixture is wrong)")
  H.ok(lines[1].head.bosses == 2 and lines[6].head ~= nil,
       "one night, one section, both sides of midnight in it")

  for i = #log, 1, -1 do log[i] = nil end
end


H.section("the window has room for what is in it")
-- Arn's screenshot, 3 Oct: the copy box and its label printed straight through the last two
-- memories. Twelve rows of twenty, starting 34 down, end 274 below the top; the box and its label
-- want about 70 from the bottom. A suite cannot see an overlap, but it can see the arithmetic.
do
  local J = NS.J
  local f = J.Build()
  -- 0.9.0's window: the rows from J.LIST_TOP, J.ROWS of J.ROW_H, and the foot's label and box below
  local rowsEnd = J.LIST_TOP + J.ROWS * J.ROW_H
  H.ok(f:GetHeight() - rowsEnd >= J.FOOT - 6, "the rows stop above the copy box rather than behind it",
       rowsEnd .. " of " .. f:GetHeight())
  H.ok(math.abs(f:GetWidth() / f:GetHeight() - 1.43) < 0.01, "the BiS window shape, 1.43:1",
       f:GetWidth() .. "x" .. f:GetHeight())
  H.ok(J.DETAIL_X + J.DETAIL_W <= f:GetWidth() - 8 and J.LIST_W + 8 < J.DETAIL_X, "the list and the detail side by side, inside it")
end

H.section("where the album page is")
-- Arn went looking for the page on disk and nothing in game said where. An addon cannot know its
-- own full path - no API for the install folder, none for the version folder - so the certain tail
-- is shown and the player may make it absolute once.
do
  local J, d = NS.J, _G.BiSMemoriesDB
  d.wowPath = nil
  H.eq(J.AlbumPath(), [[Interface\AddOns\BiSMemories\Album\BiSMemories-Album.html]],
       "with nowhere set, the path is the part that is always true")
  H.eq(J.AlbumPathWhole(), false, "and it says it is not the whole thing")

  J.SetWow([[C:\Program Files (x86)\World of Warcraft\_classic_beta_]])
  H.eq(J.AlbumPath(),
       [[C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\BiSMemories\Album\BiSMemories-Album.html]],
       "once told, it is the whole path")
  H.eq(J.AlbumPathWhole(), true, "and it says so")

  -- A TRAILING SLASH IS WHAT A PASTE FROM EXPLORER LOOKS LIKE, and a double slash breaks the paste
  J.SetWow([[C:\Games\WoW\_classic_\]])
  -- A LONG STRING, because "\I" is not an escape Lua knows and 5.1 eats the backslash silently -
  -- this assertion spent one run searching for "_classic_Interface" and failing on code that was
  -- correct. Any path written in a short string here is a trap.
  H.eq(J.AlbumPath():find([[_classic_\Interface]], 1, true) ~= nil, true,
       "a trailing slash does not become a double one")

  -- BOTH GUARDS, SEPARATELY. SetWow trims and AlbumPath trims, so testing only through SetWow
  -- means either one alone passes - mutating the trim out of AlbumPath left this green until the
  -- saved value was set directly, the way an old saved file or a hand-edited one would hold it.
  d.wowPath = [[C:\Games\WoW\_classic_\]]
  H.eq(J.AlbumPath():find([[_classic_\Interface]], 1, true) ~= nil, true,
       "a slash already in the saved file is trimmed when the path is built")

  -- THE VERSION FOLDER IS NEVER GUESSED. "_classic_beta_" is today's name, not launch day's.
  d.wowPath = nil
  H.eq(J.AlbumPath():find("_classic") == nil, true, "no version folder is invented")

  J.SetWow(nil)
  H.eq(d.wowPath, nil, "and it can be forgotten again")
end

H.section("the argument keeps its capitals")
-- The whole line used to be lowercased, which ruined the two arguments that are a person's words:
-- a note, and a Windows path. Found while adding /memories wow.
do
  local d = _G.BiSMemoriesDB
  NS.Slash([[wow C:\Program Files (x86)\World of Warcraft\_classic_beta_]])
  H.eq(d.wowPath, [[C:\Program Files (x86)\World of Warcraft\_classic_beta_]],
       "a path typed with capitals is stored with them")
  d.wowPath = nil

  local before = #M.Log()
  NS.Slash("now Killed Baron Silverlaine")
  H.eq(#M.Log(), before + 1, "the manual shot still fires")
  H.eq(M.Log()[1].detail, "Killed Baron Silverlaine", "and the note keeps the words as typed")

  -- a keyword still matches however it is typed
  NS.Slash("off LevelUp")
  H.eq(d.levelup, false, "a switch still works in any case")
  NS.Slash("on levelup")
  H.eq(d.levelup, true, "and back on")
end

-- ---------------------------------------------------------------- does every label FIT its window
-- (6 Oct 2026, ported from BiSTools) Arn: "make a check for cut offs or overflows that happens
-- often". Every shown label inside a window is measured where it actually starts - following what
-- it is pinned to: the window's edge, a frame, an icon, another label - and must end inside the
-- window. A label pinned LEFT and RIGHT gets exactly the room between its anchors; the client cuts
-- anything longer with "...", so that room is what it is measured against. It may only wrap when
-- the code asked for word wrap AND gave it a height - nothing in this addon does, so nothing skips.
--
-- WIDTH, CALIBRATED ON THE CLIENT, NOT GUESSED: capitals and digits 0.75 px per point ("NEED MATS",
-- BiSCraft, 11 Sep), lowercase 0.55 and spaces/punctuation 0.3 (Arn's BiSTools screenshot, 6 Oct).
-- The mock's own GetStringWidth (0.6 flat) stays as it is: addon code trims by it.
-- Escapes the client never draws take no room: colour |c..|r, and item links' |H...|h ... |h
-- (only the [Name] shows). Inline |T..:w:h|t textures take their declared width.
H.section("does every label fit its window")
local function realWidth(fs)
  local t, tex = tostring(fs._text or ""), 0
  t = t:gsub("|T[^|]-:(%d+):%d+[^|]*|t", function(w) tex = tex + tonumber(w) return "" end)
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
  local size, px = fs._size or 9, 0
  for ch in t:gmatch(".") do
    if ch:match("[%u%d]") then px = px + 0.75 elseif ch:match("%l") then px = px + 0.55 else px = px + 0.3 end
  end
  return px * size + tex
end
local function plain(t) return (strip(t):gsub("|H.-|h", ""):gsub("|h", "")) end
local function isLabel(r) return r._type == nil and r._size ~= nil and r._text ~= nil end
local function insideShown(r, root)
  local p = r._parent
  while p do
    if p._shown == false then return false end
    if p == root then return true end
    p = p._parent
  end
  return false
end
-- left and right edge in px from the window's left, following the anchor chain. Third answer: the
-- region is BOUNDED (pinned on both sides). nil when a label cannot be followed; a frame that
-- cannot be followed spans the window, as BiSTools does.
local function hEdges(r, root, depth)
  if r == root then return 0, root._w end
  depth = depth or 0
  local function span() if isLabel(r) then return nil end return 0, root._w end
  if depth > 8 then return span() end
  if r._all then return hEdges(r._parent, root, depth + 1) end
  local L, R, C
  for _, p in ipairs(r._points or {}) do
    local rel = p.rel or r._parent
    local rl, rr = hEdges(rel, root, depth + 1)
    if not rl then return span() end
    local rp = p.relPoint or p.point
    local ax = rp:find("LEFT") and rl or rp:find("RIGHT") and rr or (rl + rr) / 2
    if p.point:find("LEFT") then L = ax + p.x
    elseif p.point:find("RIGHT") then R = ax + p.x
    else C = ax + p.x end
  end
  local w = isLabel(r) and realWidth(r) or (r._w or 0)
  if L and R then return L, R, true end
  if L then return L, L + w end
  if R then return R - w, R end
  if C then return C - w / 2, C + w / 2 end
  return span()
end
local function fitsIn(root, what)
  local width, bad, measured = root._w, {}, 0
  for _, fs in ipairs(H.labels) do
    if fs._shown ~= false and fs._text ~= "" and insideShown(fs, root) then
      local l, r, bounded = hEdges(fs, root)
      if l then
        measured = measured + 1
        local need = realWidth(fs)
        local wraps = bounded and fs._wrap == true and fs._h
        if l < -1 or r > width + 1 then
          bad[#bad + 1] = ("%q needs %d px from %d, the window is %d"):format(plain(fs._text), need, l, width)
        elseif bounded and not wraps and l + need > r + 1 then
          bad[#bad + 1] = ("%q needs %d px from %d, its anchors give it %d (cut with ...)")
            :format(plain(fs._text), need, l, r - l)
        end
      end
    end
  end
  H.say(("  (fit) %s: %d label(s) measured"):format(what, measured))
  H.ok(measured > 0, what .. ": the fit check measured something (a check that sees nothing proves nothing)")
  H.ok(#bad == 0, what .. ": every label fits - " .. table.concat(bad, "; "))
end

do
  local J, d = NS.J, NS.DB()
  local log = M.Log()
  for i = #log, 1, -1 do log[i] = nil end
  d.wowPath = nil
  J.offset = 0

  -- EMPTY: the window most people see on this client, with the long "tell me your folder" label
  J.Show()
  fitsIn(J.frame, "the journal, empty")

  -- POPULATED, ordinary night
  local sat8pm = os.time({ year = 2026, month = 9, day = 19, hour = 20, min = 4, sec = 0 })
  for i, e in ipairs({
    { reason = "boss", detail = "Moroes", zone = "Karazhan" },
    { reason = "levelup", detail = "level 70", zone = "Karazhan" },
  }) do
    e.at, e.with = sat8pm + i * 600, { "Kumlance" }
    table.insert(log, 1, e)
  end
  J.Refresh()
  fitsIn(J.frame, "the journal, a few memories")

  -- THE LONGEST REAL ONES. Every one of these is what the addon itself writes: a death's detail
  -- IS the zone and subzone, an exalted memory keeps the client's whole sentence, a loot memory is
  -- the item link, a duel names a Forever player with a surname. More than a page, so the footer
  -- counts and the path is the whole one.
  local zone = "Blackrock Depths - The Grim Guzzler"
  local party = { "Kumlance", "Kumlust Surname", "Dps1", "Dps2" }
  for i, e in ipairs({
    { reason = "death", detail = zone },
    { reason = "exalted", detail = "You are now Exalted with Thorium Brotherhood." },
    { reason = "loot", detail = "|cffff8000|Hitem:19019::::::::60:::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r" },
    { reason = "duel", detail = "beat Kumlance Surname" },
    { reason = "boss", detail = "Emperor Dagran Thaurissan" },
    { reason = "achievement", detail = "Molten Core and Blackwing Lair" },
    { reason = "candid", detail = "just a week going by" },
  }) do
    e.at, e.zone, e.with = sat8pm + 7200 + i * 600, zone, party
    table.insert(log, 1, e)
  end
  for i = 1, 6 do
    table.insert(log, 1, { at = sat8pm + 14400 + i * 60, reason = "levelup", detail = "level " .. (50 + i),
                           zone = zone, with = party })
  end
  J.SetWow([[C:\Program Files (x86)\World of Warcraft\_classic_beta_]])
  J.Refresh()
  fitsIn(J.frame, "the journal, the longest real memories")
  J.Scroll(99)
  fitsIn(J.frame, "the journal, scrolled to the oldest")

  -- WHERE AND WHO MOVED TO THE TOOLTIP to make those rows fit, so it must still be there - through
  -- the row's own hover, the path the mouse takes, not by calling the formatter by hand.
  local tip, realSetText, realAdd = {}, GameTooltip.SetText, GameTooltip.AddLine
  GameTooltip.SetText = function(_, t) tip[#tip + 1] = strip(t) end
  GameTooltip.AddLine = function(_, t) tip[#tip + 1] = strip(t) end
  local row
  for i = 1, #J.frame.rows do
    if strip(J.frame.rows[i]._text):find("  Death  ", 1, true) then row = i end
  end
  H.ok(row ~= nil, "the death row is on the page")
  H.ok(not strip(J.frame.rows[row or 1]._text):find("with 4", 1, true), "the row no longer carries the count")
  J.frame.hits[row or 1]:Fire("OnEnter")
  local said = table.concat(tip, " | ")
  H.ok(said:find(zone, 1, true) and said:find("with 4", 1, true), "hovering it says where and who with", said)
  -- a heading is not a memory: hovering it says nothing rather than the last row's tooltip
  tip = {}
  J.Scroll(-99)
  J.frame.hits[1]:Fire("OnEnter")
  H.eq(#tip, 0, "hovering a night's heading shows no memory's tooltip")
  GameTooltip.SetText, GameTooltip.AddLine = realSetText, realAdd

  J.SetWow(nil)
  J.Hide()
  for i = #log, 1, -1 do log[i] = nil end
end

-- ===================================================================== 0.9.0: the review
-- Arn, 21 Oct 2026, on the review of the family's first addon: "do all that stuff it all looks good and
-- needed". A function, not a block: the main chunk is near Lua's 200 locals.
;(function()
  local d = NS.DB()
  local log = M.Log()
  local function wipe() for i = #log, 1, -1 do log[i] = nil end end
  local q = {}
  _G.C_Timer = { After = function(_, fn) q[#q + 1] = fn end }
  local function run() local t = q q = {} for _, fn in ipairs(t) do fn() end end
  local now = 5000
  _G.GetTime = function() return now end
  d.gap, d.delay = 0, 0
  for _, t in ipairs(M.TRIGGERS) do d[t.key] = true end
  _G.UnitName = function(u) if u == "player" then return "Kumlust" end return "Someone" end
  _G.UnitLevel = function() return 42 end
  _G.UnitClass = function() return "Shaman", "SHAMAN" end
  _G.UnitRace = function() return "Tauren", "Tauren" end
  _G.GetInventoryItemLink = function(_, slot)
    return slot == 16 and "|cffa335ee|Hitem:17182::::::::60:::::|h[Sulfuras]|h|r" or nil
  end
  _G.C_Map = {
    GetBestMapForUnit = function() return 1413 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.51234, 0.3 end } end,
  }
  M.me = nil

  H.section("0.9.0: whose memory - every note says who, where on the map, in what")
  wipe()
  local e = M.Shoot("manual", "a test")
  H.eq(M.Me(), "Kumlust-Dreamscythe", "this character, by name and realm")
  H.ok(e.char == "Kumlust-Dreamscythe" and e.class == "SHAMAN" and e.race == "Tauren", "the note says who took it",
       tostring(e.char))
  H.ok(e.map == 1413 and e.x == 0.5123 and e.y == 0.3, "and where on the map", tostring(e.x))
  H.ok(type(e.gear) == "table" and e.gear[16] == 17182, "and what you wore (the item ids)")
  H.ok(M.Word("levelup") == "Level up" and M.Word("manual") == "By hand", "the kinds in plain words")

  -- EACH CHARACTER THEIR OWN PLACES (21 Oct review: an alt never had a first time where the main had been)
  M.Char().zones = {}
  M.zoneShots = 0
  M.NewZone("Mulgore")                                    -- the first place: remembered, not shot
  H.ok(M.NewZone("The Barrens") == "The Barrens", "the main: a new place")
  M.me = nil
  _G.UnitName = function(u) if u == "player" then return "Altie" end return "Someone" end
  _G.UnitLevel = function() return 12 end
  M.zoneShots = 0
  H.ok(M.NewZone("Mulgore") == nil and M.NewZone("The Barrens") == "The Barrens",
       "an alt's first time in the Barrens is hers, whoever went there before")
  H.ok(d.chars["Kumlust-Dreamscythe"] and d.chars["Altie-Dreamscythe"], "each under their own name")

  -- THE OLD SHARED LIST goes to the character who most likely made it - not to every alt
  d.chars, d.zones = nil, { ["Orgrimmar"] = true }
  log[1] = { reason = "levelup", level = 40, at = 1 }
  M.me = nil
  H.ok(M.Char().zones["Orgrimmar"] == nil and d.zones ~= nil, "a level 12 alt does not inherit the old list")
  M.me = nil
  _G.UnitName = function(u) if u == "player" then return "Kumlust" end return "Someone" end
  _G.UnitLevel = function() return 41 end
  H.ok(M.Char().zones["Orgrimmar"] == true and d.zones == nil, "the main does - and the shared list is gone")
  wipe()

  H.section("0.9.0: a boss's first kill, and a fastest yet")
  d.bossEvery = false
  M.Char().bosses = {}
  _G.UnitGUID = function(u) return u == "boss1" and "Creature-0-1-2-3-11502-00012ABCDE" or nil end
  M.OnEvent("ENCOUNTER_START", 672, "Ragnaros")
  now = now + 300
  local k1 = M.OnEvent("ENCOUNTER_END", 672, "Ragnaros", 9, 40, 1)
  H.ok(k1 and k1.detail == "first kill: Ragnaros" and k1.secs == 300 and k1.npc == 11502,
       "the first kill: a memory, timed, with the boss's npc id", k1 and k1.detail)
  now = now + 5
  H.eq(select(2, M.OnEvent("BOSS_KILL", 672, "Ragnaros")), "the same kill", "BOSS_KILL for the same kill: not twice")
  now = now + 7 * 86400
  M.OnEvent("ENCOUNTER_START", 672, "Ragnaros")
  now = now + 400
  local k2, why2 = M.OnEvent("ENCOUNTER_END", 672, "Ragnaros", 9, 40, 1)
  H.ok(k2 == nil and why2 == "killed before", "a slower kill next week: not a memory", tostring(why2))
  M.OnEvent("ENCOUNTER_START", 672, "Ragnaros")
  now = now + 250
  local k3 = M.OnEvent("ENCOUNTER_END", 672, "Ragnaros", 9, 40, 1)
  H.ok(k3 and k3.detail == "Ragnaros - fastest yet, 4:10", "a faster one: the fastest yet", k3 and k3.detail)
  H.eq(M.Char().bosses.Ragnaros.kills, 3, "three kills counted, the same kill heard twice counted once")
  d.bossEvery = true
  now = now + 1000
  H.ok(M.OnEvent("BOSS_KILL", 672, "Ragnaros") ~= nil, "`every boss kill`: every kill, as before 0.9.0")
  d.bossEvery = false

  H.section("0.9.0: the right level on the ding")
  local l1 = M.OnEvent("PLAYER_LEVEL_CHANGED", 9, 10)
  H.ok(l1 and l1.detail == "level 10" and l1.level == 10, "PLAYER_LEVEL_CHANGED: the NEW level (its second answer)",
       l1 and l1.detail)
  local l2 = M.OnEvent("PLAYER_LEVEL_UP", 60)
  H.ok(l2 and l2.detail == "level 60 - the top!", "the level cap says so", l2 and l2.detail)

  H.section("0.9.0: a death worth keeping")
  local recap
  _G.C_DeathRecap = { GetRecapEvents = function() return recap end }
  _G.BiSToolsAPI = { major = 1, version = 2, IsRival = function(n) return n == "Latina Fatty" end }
  M.Char().firsts = {}
  M.fighting = nil
  recap = { { sourceName = "Kobold Vermin", sourceGUID = "Creature-0-1-2-3-6-0001ABCDEF" } }
  local dd = M.OnEvent("PLAYER_DEAD")
  H.ok(dd and dd.detail == "your first death - Kobold Vermin" and dd.npc == 6, "this character's first death",
       dd and dd.detail)
  local dd2, why = M.OnEvent("PLAYER_DEAD")
  H.ok(dd2 == nil and why == "not a death worth keeping", "a kobold again: not a memory", tostring(why))
  recap = { { sourceName = "Neg Crotic", sourceGUID = "Player-1-0ABC" } }
  dd = M.OnEvent("PLAYER_DEAD")
  H.ok(dd and dd.detail == "killed by Neg Crotic" and dd.killer == "Neg Crotic", "killed by a player")
  recap = { { sourceName = "Latina Fatty", sourceGUID = "Player-1-0DEF" } }
  dd = M.OnEvent("PLAYER_DEAD")
  H.ok(dd and dd.detail == "killed by your rival Latina Fatty", "killed by a rival (BiS Tools' API)", dd and dd.detail)
  recap = { { sourceName = "Son of Flame", sourceGUID = "Creature-0-1-2-3-12143-0001ABCDEF" } }
  M.OnEvent("ENCOUNTER_START", 672, "Ragnaros")
  dd = M.OnEvent("PLAYER_DEAD")
  H.ok(dd and dd.detail == "died fighting Ragnaros", "dying in a boss fight", dd and dd.detail)
  M.OnEvent("ENCOUNTER_END", 672, "Ragnaros", 9, 40, 0)
  H.eq(M.fighting, nil, "a wipe ends the fight")
  d.deathEvery = true
  recap = nil
  H.ok(M.OnEvent("PLAYER_DEAD") ~= nil, "`every death`: every one")
  d.deathEvery = false
  -- A BATTLEGROUND (Arn, 21 Oct: seventeen Darkspear Islands deaths in one album)
  local realInst = _G.IsInInstance
  _G.IsInInstance = function() return true, "pvp" end
  M.Char().firsts = {}
  recap = { { sourceName = "Neg Crotic", sourceGUID = "Player-1-0ABC" } }
  local bg, bgWhy = M.OnEvent("PLAYER_DEAD")
  H.ok(bg == nil and bgWhy == "a battleground death - only a rival's kill is kept there",
       "a battleground: killed by a player is no memory", tostring(bgWhy))
  H.eq(M.Char().firsts.death, nil, "and it does not use up the first death")
  recap = { { sourceName = "Latina Fatty", sourceGUID = "Player-1-0DEF" } }
  bg = M.OnEvent("PLAYER_DEAD")
  H.ok(bg and bg.detail == "killed by your rival Latina Fatty", "a rival's kill still is")
  _G.IsInInstance = function() return true, "arena" end
  recap = { { sourceName = "Neg Crotic", sourceGUID = "Player-1-0ABC" } }
  H.eq((M.OnEvent("PLAYER_DEAD")), nil, "an arena the same")
  _G.IsInInstance = realInst

  H.section("0.9.0: exalted, firsts, the gamba")
  _G.FACTION_STANDING_LABEL8 = "Exalted"
  _G.FACTION_STANDING_CHANGED = "You are now %s with %s."
  local x1 = M.OnEvent("CHAT_MSG_SYSTEM", "You are now Exalted with Thunder Bluff.")
  H.ok(x1 and x1.reason == "exalted" and x1.detail == "Exalted with Thunder Bluff", "exalted, from the system line too",
       x1 and x1.detail)
  H.eq(M.OnEvent("CHAT_MSG_SYSTEM", "You are now Revered with Thunder Bluff."), nil, "revered is not")
  M.Char().firsts = {}
  local m1 = M.OnEvent("NEW_MOUNT_ADDED", 5)
  H.ok(m1 and m1.detail == "your first mount", "your first mount")
  H.ok((M.OnEvent("NEW_MOUNT_ADDED", 6) or {}).detail == "a new mount", "then a new mount")
  H.eq(M.OnEvent("COMPANION_LEARNED", "CRITTER"), nil, "a pet is not a mount")
  _G.GetSpellInfo = function(id) return id == 33388 and "Apprentice Riding" or "Fireball" end
  local r1 = M.OnEvent("LEARNED_SPELL_IN_TAB", 33388)
  H.ok(r1 and r1.detail == "learned to ride - Apprentice Riding", "learning to ride", r1 and r1.detail)
  H.eq(M.OnEvent("LEARNED_SPELL_IN_TAB", 33388), nil, "only the first time")
  H.eq(M.OnEvent("LEARNED_SPELL_IN_TAB", 133), nil, "a fireball is not a first")
  local cb
  _G.BiSGambaAPI = { major = 1, RegisterCallback = function(_, ev, fn) if ev == "BiSGamba_RoundEnded" then cb = fn end return true end }
  M.gambaHooked = nil
  H.ok(M.HookGamba() and cb, "BiS Gamba's rounds, heard through its API")
  M.Char().gambaBest = nil
  H.ok(cb("BiSGamba_RoundEnded", { winner = "Kumlust", loser = "Kumlance", amount = 100 }) == nil and log[1].reason == "gamba"
       and log[1].detail == "won 100g from Kumlance - your biggest yet", "a win: your biggest yet", log[1].detail)
  H.eq(M.GambaRound({ winner = "Kumlust", loser = "X", amount = 50 }), nil, "a smaller one: not")
  H.eq(M.GambaRound({ winner = "Kumlance", loser = "Kumlust", amount = 500 }), nil, "someone else's win: not")
  H.ok(M.GambaRound({ winner = "Kumlust Surname", loser = "X", amount = 200 }) ~= nil, "a bigger one, under the full name: yes")
  _G.BiSGambaAPI, _G.BiSToolsAPI = nil, nil

  H.section("0.9.0: clean shots - the interface hidden for the instant of the picture")
  local vis = {}
  _G.SetUIVisibility = function(v) vis[#vis + 1] = v end
  d.clean, d.delay = true, 0.6
  M.Shoot("manual", "clean")
  H.eq(#vis, 0, "nothing hidden before the shutter")
  q[1]()
  table.remove(q, 1)
  H.ok(vis[1] == false and M.uiHidden, "the shutter: hidden")
  M.OnEvent("SCREENSHOT_SUCCEEDED")
  H.ok(vis[2] == true and not M.uiHidden, "the picture written: back")
  M.Shoot("manual", "the event never comes")
  run()
  run()
  H.ok(vis[#vis] == true and not M.uiHidden, "and if the client never says, back after a moment anyway")
  d.clean = false
  local before = #vis
  M.Shoot("manual", "not clean")
  run()
  H.eq(#vis, before, "switched off: the interface stays")
  d.delay, d.clean = 0, true
  _G.SetUIVisibility = nil

  H.section("0.9.0: on this day")
  wipe()
  local t = os.time({ year = 2027, month = 11, day = 4, hour = 20 })
  table.insert(log, { reason = "zone", detail = "Durotar", at = os.time({ year = 2026, month = 11, day = 4, hour = 9 }) })
  table.insert(log, 1, { reason = "boss", detail = "first kill: Onyxia", at = os.time({ year = 2026, month = 11, day = 4, hour = 21 }) })
  table.insert(log, 1, { reason = "levelup", detail = "level 30", at = os.time({ year = 2027, month = 10, day = 4, hour = 21 }) })
  d.otdShown, d.onThisDay = nil, true
  said = {}
  local o, words = M.OnThisDay(t)
  H.ok(o and o.detail == "first kill: Onyxia" and words == "A year ago today", "a year ago today - the best of that day",
       tostring(words))
  H.ok(table.concat(said, " "):find("A year ago today", 1, true) and NS.J.toast and NS.J.toast:IsShown(),
       "a line in chat and a card on screen")
  H.eq(M.OnThisDay(t + 3600), nil, "once a day")
  wipe()
  table.insert(log, { reason = "levelup", detail = "level 30", at = os.time({ year = 2027, month = 9, day = 4, hour = 21 }) })
  d.otdShown = nil
  local o2, w2 = M.OnThisDay(t)
  H.ok(o2 and w2 == "2 months ago today", "the first year: a month (or two) ago today", tostring(w2))
  NS.J.toast:Hide()

  H.section("0.9.0: the year so far")
  wipe()
  local Y = tonumber(os.date("%Y"))
  local y0 = os.time({ year = Y, month = 1, day = 2 })
  for i, l in ipairs({ 10, 11, 12 }) do
    table.insert(log, 1, { reason = "levelup", level = l, detail = "level " .. l, at = y0 + i * 7200, char = "Kumlust-Dreamscythe" })
  end
  table.insert(log, 1, { reason = "boss", detail = "first kill: Hogger", at = y0 + 30000, char = "Kumlust-Dreamscythe" })
  table.insert(log, 1, { reason = "death", detail = "killed by X", at = y0 + 31000, char = "Altie-Dreamscythe" })
  local s = M.Summary(Y, "Kumlust-Dreamscythe")
  local lines = table.concat(M.SummaryLines(s), " | ")
  H.ok(s.total == 4 and lines:find("levels 10 to 12, about 2 h 0 min a level", 1, true) and lines:find("1 first kill: Hogger", 1, true)
       and not lines:find("death", 1, true), "this character's year: levels, how long each took, first kills", lines)
  H.eq(M.Summary(Y).total, 5, "every character's: the alt's death too")
  said = {}
  NS.Slash("year all")
  H.ok(table.concat(said, " "):find("5 memories in " .. Y, 1, true), "/bism year all", table.concat(said, " | "))

  H.section("0.9.0: the group photo")
  wipe()
  H.inRaid = false
  _G.IsInGroup = function() return H.inRaid end
  H.eq(select(2, M.GroupPhoto()), "not in a group", "alone: no group photo")
  H.inRaid, H.raid = true, { { name = "Kumlust" }, { name = "Kumlance" } }
  local wire = #H.wire
  local chat = #H.sent
  q = {}
  H.ok(M.GroupPhoto(3), "in a group: called")
  local snap = false
  for i = wire + 1, #H.wire do if tostring(H.wire[i].msg):find("MEM", 1, true) and tostring(H.wire[i].msg):find("SNAP", 1, true) then snap = true end end
  H.ok(snap, "the call goes out on the BiS channel, to the group")
  H.ok(#H.sent > chat and H.sent[#H.sent].msg:find("say cheese", 1, true), "and one line in group chat for the rest")
  H.ok(NS.J.counter and NS.J.counter:IsShown() and strip(NS.J.counter.big._text) == "3", "a countdown on screen: 3")
  run() run()
  H.eq(strip(NS.J.counter.big._text), "1", "2, 1...")
  run()
  H.ok(log[1] and log[1].reason == "group" and not NS.J.counter:IsShown() and not M.counting, "...and everyone's picture", log[1] and log[1].detail)
  -- someone else's call, heard on the channel
  local h = _G.LibBiSComm.handlers and _G.LibBiSComm.handlers.MEM and _G.LibBiSComm.handlers.MEM.SNAP
  H.ok(type(h) == "function", "the call is listened for")
  h("Kumlance", "2")
  H.ok(M.counting and strip(NS.J.counter.big._text) == "2", "someone else's call: the countdown here too")
  run() run() run()
  H.ok(log[1].detail == "a group photo - called by Kumlance", "the picture says who called it", log[1].detail)
  h("Kumlust", "2")
  H.ok(not M.counting, "your own call, echoed back, is not counted twice")
  H.inRaid = false

  H.section("0.9.0: where - the journal's map and the world map's pins")
  wipe()
  _G.C_Map.GetMapArtLayers = function() return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end
  _G.C_Map.GetMapArtLayerTextures = function() local f = {} for i = 1, 12 do f[i] = 1000 + i end return f end
  _G.C_Map.GetMapRectOnMap = function(from, to) if to == 947 then return 0.4, 0.6, 0.3, 0.5 end end
  table.insert(log, { reason = "boss", detail = "first kill: Hogger", at = 1, map = 1429, x = 0.5, y = 0.5, char = "Kumlust-Dreamscythe" })
  table.insert(log, { reason = "zone", detail = "Westfall", at = 2, map = 1436, x = 0.2, y = 0.8, char = "Kumlust-Dreamscythe" })
  table.insert(log, { reason = "death", detail = "inside", at = 3, zone = "The Deadmines", char = "Kumlust-Dreamscythe" })
  table.insert(log, { reason = "zone", detail = "the alt's", at = 4, map = 1411, x = 0.5, y = 0.5, char = "Altie-Dreamscythe" })
  local MV = NS.MapView
  H.eq(MV.Start(), 947, "the map opens on Azeroth")
  local x, y = MV.OnMap(1429, 0.5, 0.5, 947)
  H.ok(math.abs(x - 0.5) < 1e-9 and math.abs(y - 0.4) < 1e-9, "a zone's spot placed on the world by the client's own rectangle")
  local dots, inside = MV.Dots(log, 947)
  H.ok(#dots == 3 and inside == 1, "a dot for each memory out in the world; the one in a dungeon has no spot", #dots .. "/" .. inside)
  -- the world map's pins (HereBeDragons, through the stand-in above)
  M.me = nil
  d.pins = "mine"
  H.eq(NS.Pins.Update(), 2, "pins: this character's memories with a spot")
  local n = 0
  for _, p in pairs(PINS.world) do n = n + 1 H.ok(p.flag == _G.HBD_PINS_WORLDMAP_SHOW_PARENT, "on the zone map and one up") end
  H.eq(n, 2, "and the library has them")
  d.pins = "all"
  H.eq(NS.Pins.Update(), 3, "every character's, when asked")
  d.pins = "off"
  H.eq(NS.Pins.Update(), 0, "or none")
  n = 0
  for _ in pairs(PINS.world) do n = n + 1 end
  H.eq(n, 0, "taken off the map")
  d.pins = "mine"

  H.section("0.9.0: the journal - list, postcard, map, year")
  local J = NS.J
  J.everyone, J.sel, J.page = nil, nil, "memories"
  wipe()
  local mine = { reason = "boss", detail = "first kill: Ragnaros", zone = "Molten Core", level = 60, at = os.time() - 600,
                 with = { "Kumlance Wildhammer", "Neg Crotic" }, withClass = { "MAGE", false },
                 char = "Kumlust-Dreamscythe", npc = 11502, secs = 250,
                 gear = { [16] = 17182, [1] = 16900 }, file = "WoWScrnShot_102126_201500" }
  local theirs = { reason = "levelup", detail = "level 20", zone = "Mulgore", at = os.time() - 300, char = "Altie-Dreamscythe" }
  table.insert(log, 1, mine)
  table.insert(log, 1, theirs)
  J.Show()
  H.eq(#J.Entries(), 1, "this character's memories by default")
  J.frame.who:Click()
  H.eq(#J.Entries(), 2, "the header's button: every character's")
  H.ok(strip(J.frame.rows[2]._text):find("Level up  level 20", 1, true), "rows in plain words", strip(J.frame.rows[2]._text))
  local hitMine
  for i, hit in ipairs(J.frame.hits) do if hit.entry == mine then hitMine = hit end end
  hitMine:Click()
  local f = J.frame
  H.ok(J.sel == mine and strip(f.kind._text):find("^Boss") and f.text._text == "first kill: Ragnaros", "click a row: the detail")
  H.ok(strip(f.whoWith._text) == "with" and f.withBtns[1]:IsShown() and f.withBtns[1].who == "Kumlance Wildhammer"
       and f.withBtns[2].who == "Neg Crotic" and strip(f.more._text):find("the fight took 4:10", 1, true),
       "who was there - a name each - and the fight's time")
  -- a year on: click a name, the game's own player menu (whisper, invite, friend, BiS Tools' pal line)
  local menu
  _G.UnitPopup_OpenMenu = function(kind, ctx) menu = kind .. ":" .. tostring(ctx.name) end
  f.withBtns[1]:Click()
  H.eq(menu, "FRIEND:Kumlance Wildhammer", "click a name: the game's menu for them, by their whole name")
  _G.UnitPopup_OpenMenu = nil
  H.ok(f.withBtns[1].fs._color and f.withBtns[1].fs._color[1] > 0, "in their class colour")
  H.eq(f.fileBox._text, "WoWScrnShot_102126_201500", "the picture's file name, ready to copy")
  local you, them = f.post.you, f.post.them
  H.ok(you._unit == "player" and you._undressed and #you._tried == 2 and you._anim == J.POSE.boss,
       "THE POSTCARD: you, in what you wore, in the moment's pose", tostring(you._anim))
  H.ok(them:IsShown() and them._creature == 11502 and them._anim == 1, "beside the boss, where it fell")
  fitsIn(f, "the journal, a memory open")
  for i, hit in ipairs(J.frame.hits) do if hit.entry == theirs then hit:Click() end end
  H.ok(not you:IsShown() and strip(f.post.note._text) == "played by Altie" and not them:IsShown(),
       "another character's memory: no body to draw - it says who")
  J.Tab("map")
  H.ok(f.map:IsShown() and not f.list:IsShown() and strip(f.map.say._text):find("on the map", 1, true), "the map page",
       strip(f.map.say._text))
  fitsIn(f, "the journal's map")
  J.Tab("this year")
  H.ok(f.year:IsShown() and strip(f.year.lines[1]._text):find("memories in", 1, true), "the year page")
  fitsIn(f, "the journal's year")
  J.Tab("memories")
  J.Hide()
  J.everyone = nil

  H.section("0.9.0: the options window and the minimap button")
  local CFG = NS.CFG
  local w = CFG.Build()
  H.ok(w and CFG.columns == 2, "the options window, two columns")
  local rows = CFG.Rows()
  H.ok(#rows >= 20, "every setting has a row now, not just a slash command", #rows)
  for _, opt in ipairs(rows) do
    if opt.key == "boss" then opt.set(d, false) H.eq(d.boss, false, "a row's switch is the same switch /bism uses") opt.set(d, true) end
  end
  fire("PLAYER_LOGIN")
  local b = CFG.button
  H.ok(b and b.icon and b.icon._texture == "Interface\\Icons\\INV_Misc_Spyglass_03", "the minimap button, the spyglass")
  b:Fire("OnClick", "LeftButton")
  H.ok(J.frame:IsShown(), "a click opens the journal")
  b:Fire("OnClick", "LeftButton")
  b:Fire("OnClick", "RightButton")
  H.ok(w:IsShown(), "a right-click, the options")
  CFG.SetMinimap(false)
  H.ok(not b:IsShown() and d.minimap.hide == true, "and the button can be hidden")
  CFG.SetMinimap(true)

  H.section("0.9.0: which saved copy came back (/bism db)")
  said = {}
  NS.Slash("db")
  H.ok(table.concat(said, " "):find("the account-wide file came back", 1, true), "/bism db says", table.concat(said, " | "))
  fire("PLAYER_LOGOUT")
  H.ok(type(d.stamp) == "number", "logging out stamps the file")

  H.section("0.9.0: lean - a raid's loot and system lines")
  local Cost = dofile(ROOT .. "/../_bisdev/dev/cost.lua")
  _G.GetItemInfo = function() return "x", "x", 4 end
  local others = "Neg Crotic receives loot: |cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r."
  local nL, byL = Cost.Count(function() for _ = 1, 500 do M.OnEvent("CHAT_MSG_LOOT", others) end end)
  H.ok(nL <= 500, "500 of other people's epics: at most one question each - " .. nL, Cost.Top(byL))
  local nS, byS = Cost.Count(function() for _ = 1, 500 do M.OnEvent("CHAT_MSG_SYSTEM", "Kumlance has come online.") end end)
  H.ok(nS <= 1000, "500 system lines: at most two questions each - " .. nS, Cost.Top(byS))
  wipe()
end)()


;(function()
  local M, J, MV = NS.M, NS.J, NS.MapView
  local log = M.Log()
  local d = NS.DB()
  local function wipe() for k = #log, 1, -1 do log[k] = nil end end

  H.section("21 Oct: who was there, by their whole names")
  local real = { _G.GetUnitName, _G.UnitName, _G.UnitClass, _G.UnitIsUnit, _G.GetNumGroupMembers, _G.IsInRaid, _G.UnitExists }
  local P = { party1 = { "Chain Healz", "SHAMAN" }, party2 = { "Neg Crotic", "WARLOCK" } }
  -- Forever, measured: UnitName is the first name, GetUnitName(unit, false) the whole one
  _G.GetUnitName = function(u) return P[u] and P[u][1] or "Kumlust Wildhammer" end
  _G.UnitName = function(u) local p = P[u] return p and p[1]:match("^%S+") or "Kumlust" end
  _G.UnitClass = function(u) local p = P[u] return "x", p and p[2] or "MAGE" end
  _G.UnitIsUnit = function(a, b) return a == b end
  _G.GetNumGroupMembers = function() return 3 end
  _G.IsInRaid = function() return false end
  _G.UnitExists = function(u) return P[u] ~= nil end
  local names, classes = M.Party()
  H.ok(#names == 2 and names[1] == "Chain Healz" and classes[1] == "SHAMAN" and names[2] == "Neg Crotic",
       "whole names (to invite them a year on), with their classes", table.concat(names, ","))
  _G.GetUnitName, _G.UnitName, _G.UnitClass, _G.UnitIsUnit, _G.GetNumGroupMembers, _G.IsInRaid, _G.UnitExists =
    real[1], real[2], real[3], real[4], real[5], real[6], real[7]

  H.section("21 Oct: the old notes find their characters")
  wipe()
  -- before 0.9.0: no character, only a level and a time; the main at 15+, a rogue alt at 1-5 the same evening
  local main1 = { reason = "boss", detail = "Charlga Razorflank", level = 15, at = 1000 }
  local alt1 = { reason = "levelup", detail = "level 2", level = 1, at = 1100 }
  local main2 = { reason = "death", detail = "x", level = 16, at = 1200 }
  local alt2 = { reason = "levelup", detail = "level 5", level = 4, at = 1300 }
  local nolvl = { reason = "zone", detail = "y", level = 0, at = 1400 }
  for _, e in ipairs({ nolvl, alt2, main2, alt1, main1 }) do log[#log + 1] = e end
  local tracks = M.Tracks()
  H.eq(#tracks, 2, "two tracks: levels only go up")
  local realLevel, realMe = _G.UnitLevel, M.Me
  _G.UnitLevel = function() return 60 end
  M.Me = function() return "Main-Realm" end
  H.eq(M.ClaimOld(), 2, "the main (60) claims the long track")
  H.ok(main1.char == "Main-Realm" and main2.char == "Main-Realm" and alt1.char == nil, "its notes, not the alt's")
  _G.UnitLevel = function() return 9 end
  M.Me = function() return "Rogue-Realm" end
  H.eq(M.ClaimOld(), 2, "the rogue (9) claims the levels 1 to 5")
  H.ok(alt1.char == "Rogue-Realm" and alt2.char == "Rogue-Realm" and nolvl.char == nil, "and a note with no level stays nobody's")
  H.eq(M.ClaimOld(), 0, "nothing is given twice")
  -- the postcard draws only the character who took it
  M.Me = function() return "Main-Realm" end
  J.Show()
  J.Select(alt1)
  H.ok(not J.frame.post.you:IsShown(), "the main does not stand in the rogue's level-up")
  J.Select(nolvl)
  H.ok(not J.frame.post.you:IsShown() and J.frame.post.note._text:find("older picture", 1, true), "an unclaimed old note: nobody, and why")
  _G.UnitLevel, M.Me = realLevel, realMe

  H.section("21 Oct: an old boss note gets its face")
  d.faces = nil
  M.faceless = nil
  local set = M.Faceless()
  H.ok(set["Charlga Razorflank"], "an old boss note without a face is known")
  local realTarget, realGUID = _G.UnitName, _G.UnitGUID
  _G.UnitName = function(u) if u == "target" then return "Charlga Razorflank" end return "Kumlust" end
  _G.UnitGUID = function() return "Creature-0-1-2-3-4421-0001ABCDEF" end
  M.OnEvent("PLAYER_TARGET_CHANGED")
  H.eq(d.faces and d.faces["Charlga Razorflank"], 4421, "target her once: her id is kept")
  H.eq(M.Face(main1), 4421, "and the old postcard has its boss")
  local asked = 0
  _G.UnitName = function() asked = asked + 1 return "x" end
  M.faceless = nil
  M.OnEvent("PLAYER_TARGET_CHANGED")
  H.eq(asked, 0, "no old boss left without a face: a target change asks the client nothing")
  _G.UnitName, _G.UnitGUID = realTarget, realGUID
  H.eq(M.BossName({ reason = "boss", detail = "SURVIVOR.EXE: Ragnaros slain over The Barrens" }), nil, "BiS Shell's games are no creature")

  H.section("21 Oct: old notes on the map, by their zone")
  MV.zoneIDs = nil
  _G.C_Map.GetMapChildrenInfo = function() return { { mapID = 1413, name = "The Barrens" }, { mapID = 1456, name = "Thunder Bluff" } } end
  wipe()
  log[1] = { reason = "zone", detail = "a", zone = "The Barrens - The Crossroads", at = 5000, char = "Kumlust-Dreamscythe" }
  log[2] = { reason = "death", detail = "b", zone = "Darkspear Islands - Camp", at = 5001, char = "Kumlust-Dreamscythe" }
  log[3] = { reason = "boss", detail = "c", zone = "The Barrens", at = 5002, map = 1413, x = 0.3, y = 0.3, char = "Kumlust-Dreamscythe" }
  local dots, inside, off, rough = MV.Dots(log, 947)
  H.ok(#dots == 2 and rough == 1 and inside == 1, "an old note goes by its zone; a battleground stays without a place",
       #dots .. "/" .. tostring(rough) .. "/" .. tostring(inside))
  J.Tab("map")
  J.Show()
  H.ok(J.frame.map.say._text:find("placed by their zone", 1, true) and J.frame.map.say._text:find("1 inside a dungeon or battleground", 1, true)
       and not J.frame.map.say._text:find("raids, where", 1, true), "the map says which is which", J.frame.map.say._text)
  _G.C_Map.GetMapChildrenInfo = nil
  MV.zoneIDs = nil

  H.section("21 Oct: the year counts the old notes, and /bism year opens it")
  wipe()
  local y = tonumber(os.date("%Y"))
  log[1] = { reason = "zone", detail = "new", at = os.time(), char = M.Me() }
  log[2] = { reason = "zone", detail = "old", at = os.time() - 60 }
  H.eq(M.Summary(y, M.Me()).total, 2, "an unclaimed old note counts, as the journal shows it")
  J.Hide()
  NS.Slash("year")
  H.ok(J.frame:IsShown() and J.page == "this year", "/bism year opens the page")
  J.Hide()
  J.Tab("memories")
  wipe()
end)()

H.report()
