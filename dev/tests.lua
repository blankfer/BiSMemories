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
    -- 8 Nov 2026: the Clipper Lounge, the full screen (named: Escape closes it)
    BiSMemoriesLounge = true,
    -- 8 Nov 2026: the share card (named: Escape puts it away)
    BiSMemoriesShare = true,
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
    function P:AddWorldMapIconMap(ref, icon, map, x, y, flag, level)
        check(ref, icon, map, x, y, "AddWorldMapIconMap")
        if PINS.minimap[icon] then error("this frame is already a pin on the other map", 2) end
        if flag ~= nil and type(flag) ~= "number" then error("showFlag must be a number (or nil)", 2) end
        -- the frame level TYPE the map's pin manager knows by name (the library defaults to AREA_POI)
        if level ~= nil and type(level) ~= "string" then error("frameLevel must be a level type name (or nil)", 2) end
        PINS.world[icon] = { map = map, x = x, y = y, flag = flag, level = level }
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
  H.ok(type(A) == "table" and A.major == 1 and A.version == 4, "BiSMemoriesAPI is there, major 1, version 4")
  for _, call in ipairs({
    { "Ready", {} }, { "Memories", {} }, { "Latest", {} }, { "Kinds", {} }, { "TakeMemory", { "too early" } },
    { "ShareCard", { "BiSGuild", { title = "too early" } } }, { "ShareMemory", { "BiSGuild", 1 } },
  }) do
    local ok, got, why = pcall(A[call[1]], unpack(call[2]))
    H.ok(ok and got == nil and why == "not ready", call[1] .. " before login: nil, \"not ready\"", tostring(why))
  end
  H.eq(_G.BiSMemoriesDB, nil, "and asking did not make the saved table before the client loaded it")
end
fire("ADDON_LOADED", "BiSMemories")
H.ok(type(_G.BiSMemoriesDB) == "table" and _G.BiSMemoriesDB.comm == true, "SavedVariables shaped with defaults on first load")
-- A NEW INSTALL STARTS QUIET since 1.0 (the "7 Nov: Forever 1.0" sections at the end prove it). The feature tests
-- below are about what each switch DOES, so the suite's player switches everything on first - every extra at the
-- value an existing player keeps (NS.WAS).
H.ok(NS.firstRun == "new" and _G.BiSMemoriesDB.sound == false, "the suite's first login is a new install, quiet")
for k, v in pairs(NS.WAS) do _G.BiSMemoriesDB[k] = v end

H.section("embedded libs are canon (drift fences)")
H.eq(_G.LibBiSComm.MINOR, 18, "LibBiSComm minor 18")
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
local heard = {}                -- every kit asked for, with its channel
local REFUSE = {}               -- kit ids this client will not play (PlaySound answers false)
_G.Screenshot = function() shots = shots + 1 end
_G.PlaySound = function(id, channel)
  if type(id) ~= "number" then error("PlaySound wants a kit id", 2) end
  heard[#heard + 1] = { id = id, channel = channel }
  if REFUSE[id] then return false end
  kits = kits + 1
  return true
end
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
-- THE CAMERA'S OWN SHUTTER (Arn, 5 Nov, from the sound explorer: REPORT_SCREENSHOT_CAMERA 230810), on SFX
H.eq(heard[1] and heard[1].id, 230810, "the shutter is the camera sound, REPORT_SCREENSHOT_CAMERA")
H.eq(heard[1] and heard[1].channel, "SFX", "on the effects channel - muting effects mutes it")
H.eq(M.CLICK[2], 1115, "the old click stays behind it, for a client that will not play it")
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
  local back = NS.Deserialize(_G.BiSMemoriesCharDB)
  H.ok(type(_G.BiSMemoriesCharDB) == "string" and back and back.log[1].detail == "Mulgore",
       "logging out writes the per-character copy - as one line of text, read back whole")
  H.ok(not _G.BiSMemoriesCharDB:find("[\n\r]"), "and never a newline in it: the album page loads it as a script")
  -- the page's reader on it: a note it can find, the same keys as the account file
  H.ok(_G.BiSMemoriesCharDB:find('["file"]="WoWScrnShot_1"', 1, true), "with the notes as the page reads them")
  -- the awkward strings survive the trip: quotes, backslashes, a newline in a note
  local odd = { log = { { detail = 'He said "hi"\nC:\\WoW', at = 7, n = 0.5, yes = true } } }
  local again = NS.Deserialize(NS.Serialize(odd))
  H.ok(again and again.log[1].detail == odd.log[1].detail and again.log[1].n == 0.5 and again.log[1].yes == true,
       "quotes, backslashes and newlines go there and back")
  H.eq(NS.Deserialize('os.exit()'), nil, "and the copy is read as data, never run as code")

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
  H.ok(strip(J.frame.kind._text):find("NOTHING YET"), "and an empty log says so in words")
  H.ok(not J.frame.hits[1]:IsShown(), "with no stale line left behind")

  -- forty memories, newest first (more than a page)
  for i = 1, 40 do
    table.insert(log, 1, { at = 1000 + i, reason = "zone", detail = "place " .. i,
                           zone = "Mulgore", with = {}, file = "WoWScrnShot_" .. i })
  end
  J.Refresh()
  -- LINE 1 IS THE NIGHT'S HEADING, and the memories hang under it. These were written a second
  -- apart, so they are all one "night" - which is the rule doing exactly what it says.
  H.ok(strip(J.frame.rows[1]._text):find("Mulgore"), "the night's heading is at the top",
       strip(J.frame.rows[1]._text))
  H.ok(strip(J.frame.rows[2]._text):find("place 40"), "the newest memory is under it")
  H.ok(strip(J.frame.rows[3]._text):find("place 39"), "and the one before it under that")
  H.ok(strip(J.frame.count._text):find("40 kept"), "the footer counts the memories, not the lines")

  -- the wheel turns the pages, and stops at the ends rather than running off
  H.eq(J.Scroll(1), 2, "the wheel turns to the next page")
  H.ok(strip(J.frame.rows[2]._text):find("place 34"), "and the page follows",
       strip(J.frame.rows[2]._text))
  H.eq(J.Scroll(-99), 1, "it will not go before the newest")
  H.eq(J.Scroll(99), 7, "nor past the oldest - 40 memories, six a page")

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
  -- THE NIGHT FLIGHT (Arn, 8 Nov 2026: the album "also needed that new and improved cockpit ... reimagined in a luxurious
  -- cockpit"): the windscreen over the dash, drawn by the page itself - no font or picture is fetched, it stays offline
  H.ok(page and page:find('class="sky"', 1, true) and page:find('class="dash"', 1, true) and page:find('class="trim"', 1, true),
       "the album is the night flight: a windscreen, the leather dash, the walnut rail")
  H.ok(page and not page:find("fonts.googleapis", 1, true) and not page:find("@import", 1, true) and not page:find("url(http", 1, true),
       "and its look fetches nothing")
  -- ONE STEP (Arn, 21 Oct 2026: "make it easy like the google notebook thing"): hand it the WoW folder and it
  -- finds both halves; it walks only where they can be (never Data or Interface); the X closes (the side
  -- strips used to cover it). The logic itself was run in a browser on the day it was written.
  H.ok(page and page:find("function kindOf(", 1, true) and page:find("function worthWalking(", 1, true)
       and page:find("function take(", 1, true), "one step: the page finds the pictures and the notes itself")
  H.ok(page and page:find("^(Interface|Data|Cache|Logs", 1, true), "and never walks Data or Interface")
  -- the picker leads (21 Oct 2026: a dragged folder stopped working on this page in Chrome and Edge alike)
  H.ok(page and page:find("Choose your WoW folder", 1, true) and page:find("You do this once.", 1, true)
       and not page:find("Add the addon's notes (optional)", 1, true), "one button, used once, and the upload box explained")
  H.ok(page and page:find("top: 70px", 1, true) and page:find("z-index: 2", 1, true), "the lightbox's X sits above the side strips")
  -- "i thought that it froze" / "click this button to make a icon on your desktop" (Arn, 21 Oct 2026)
  H.ok(page and page:find("function counting(", 1, true) and page:find('id="busy"', 1, true),
       "a bar that moves while the folder is read, with what it has found so far")
  -- Chrome refused a dropped Program Files folder's handle ("contains system files") AND emptied the drop
  -- (Arn's screenshot, 21 Oct): no handles; the page opens what lies beside it, by relative path
  H.ok(page and not page:find("getAsFileSystemHandle", 1, true) and page:find("function openKept(", 1, true)
       and page:find('"../../../../"', 1, true), "after one drag the page opens the album by itself, from beside it")
  H.ok(page and page:find("function whereAmI(", 1, true) and page:find("where-copy", 1, true),
       "and it says where the game folder is, with a Copy button")
  -- a .url was held back by Chrome as possibly harmful ("BiS Memories album.download", 21 Oct): a page instead
  H.ok(page and not page:find("[InternetShortcut]", 1, true) and page:find("function launcher(", 1, true)
       and page:find('http-equiv="refresh"', 1, true) and page:find("Make a desktop icon", 1, true),
       "and a desktop icon that opens the album")

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
  -- the cockpit (8 Nov 2026): the displays end above the soft keys, the soft keys above the memo line (the copy box)
  local dispEnd = J.DISP_TOP + J.DISP_H
  H.ok(dispEnd + 8 + J.KEY_H <= J.MEMO_Y and J.MEMO_Y + 24 <= f:GetHeight(),
       "the displays stop above their keys, the keys above the copy box rather than behind it",
       dispEnd .. " / " .. J.MEMO_Y .. " of " .. f:GetHeight())
  -- six lines a page, and a heading over each in the worst case, inside the list
  H.ok(J.PER * (J.ENTRY_H + J.HEAD_H) <= J.DISP_H - J.LIST_TOP - 4, "six lines and six headings fit the left display")
  H.ok(math.abs(f:GetWidth() / f:GetHeight() - 1.43) < 0.01, "the BiS window shape, 1.43:1",
       f:GetWidth() .. "x" .. f:GetHeight())
  H.ok(J.DISP_X2 + J.DISP_W <= f:GetWidth() - 8 and J.DISP_X + J.DISP_W + 8 < J.DISP_X2,
       "the list and the detail side by side, inside it")
end

H.section("where the album page is")
-- Arn went looking for the page on disk and nothing in game said where. An addon cannot know its
-- own full path - no API for the install folder, none for the version folder - so the certain tail
-- is shown and the player may make it absolute once.
do
  local J, d = NS.J, _G.BiSMemoriesDB
  d.wowPath = nil
  -- untold, a guess (Arn, 21 Oct 2026: "how close can we get them to the album html"): the launcher's folder,
  -- and the version by the client - Forever's beta says IsBetaBuild() true (measured) and plays from
  -- _classic_beta_; the live client from _forever_
  local keepBeta = _G.IsBetaBuild
  _G.IsBetaBuild = function() return true end
  H.eq(J.AlbumPath(), [[C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns\BiSMemories\Album\BiSMemories-Album.html]],
       "with nowhere set: the beta client's folder, whole, to paste")
  _G.IsBetaBuild = function() return false end
  H.eq(J.AlbumPath():find([[\_forever_\Interface]], 1, true) ~= nil, true, "the live client's: _forever_")
  _G.IsBetaBuild = nil
  H.eq(J.AlbumPath():find([[\_forever_\Interface]], 1, true) ~= nil, true, "a client without the question: the live one")
  _G.IsBetaBuild = keepBeta
  H.eq(J.AlbumPathWhole(), false, "and it says it is a guess")

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

  -- a told folder always beats the guess
  d.wowPath = [[D:\Games\WoW\_forever_]]
  H.eq(J.AlbumPath():find([[D:\Games\WoW\_forever_\Interface]], 1, true) ~= nil, true, "a told folder beats the guess")
  d.wowPath = nil

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
  for i = 1, #J.frame.subs do
    if J.frame.hits[i]:IsShown() and strip(J.frame.subs[i]._text):find("DEATH", 1, true) then row = i end
  end
  H.ok(row ~= nil, "the death row is on the page")
  H.ok(not (strip(J.frame.rows[row or 1]._text) .. strip(J.frame.subs[row or 1]._text)):find("with 4", 1, true),
       "the row no longer carries the count")
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
  -- THE LIVE CLIENT'S RULE (Arn's BugGrabber, the stress test, 21 Oct: "AddOn 'BiSMemories' tried to call the
  -- protected function 'UNKNOWN()'" at Memories.lua:362): SetUIVisibility - Alt+Z's own call - is PROTECTED. An
  -- addon's shot is never a key press, so the client refuses it: nothing hides, no Lua error (pcall says fine),
  -- an ADDON_ACTION_BLOCKED instead. This mock does exactly that, and the test asks what the picture SHOWS.
  local blocked = 0
  _G.SetUIVisibility = function() blocked = blocked + 1 end
  local ui = _G.UIParent
  run()                                                -- earlier shots' "back in a moment" timers, run out
  M.Clean(false)
  ui:SetAlpha(1)                                       -- the client's UIParent starts fully shown
  local function shown() return (ui:GetAlpha() or 1) > 0 end
  d.clean, d.delay = true, 0.6
  M.Shoot("manual", "clean")
  H.ok(shown(), "nothing hidden before the shutter")
  q[1]()
  table.remove(q, 1)
  H.ok(not shown() and M.uiHidden, "the shutter: the interface is really out of the picture")
  M.OnEvent("SCREENSHOT_SUCCEEDED")
  H.ok(shown() and ui:GetAlpha() == 1 and not M.uiHidden, "the picture written: back, as it was")
  M.Shoot("manual", "the event never comes")
  run()
  run()
  H.ok(shown() and not M.uiHidden, "and if the client never says, back after a moment anyway")
  H.eq(blocked, 0, "and never the protected call: nothing for BugGrabber")
  ui:SetAlpha(0.8)                                     -- someone dimmed their interface: it comes back dimmed
  M.Shoot("manual", "dimmed")
  run()
  M.OnEvent("SCREENSHOT_SUCCEEDED")
  H.eq(ui:GetAlpha(), 0.8, "back to the player's own alpha, not to 1")
  ui:SetAlpha(1)
  d.clean = false
  M.Shoot("manual", "not clean")
  q[1]()
  table.remove(q, 1)
  H.ok(shown(), "switched off: the interface stays")
  run()
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
  -- UNDER THE QUEST PINS (Arn, 6 Nov, a map with a memory square on a quest's "!": "sometime the memeories blocks
  -- quest stuff on the map"). The library puts every pin on AREA_POI, beside the quest pins; ours get their own
  -- layer just above the map's art. The client's pin manager, as it behaves: a level type it does not know is an
  -- error, and a new one goes in above one it knows.
  do
    local order = { "PIN_FRAME_LEVEL_MAP_EXPLORATION", "PIN_FRAME_LEVEL_AREA_POI", "PIN_FRAME_LEVEL_ACTIVE_QUEST" }
    local fl = {}
    function fl:GetValidFrameLevel(kind)
      for i, k in ipairs(order) do if k == kind then return 100 + i * 10 end end
      error("unknown pin frame level type " .. tostring(kind), 2)
    end
    function fl:InsertFrameLevelAbove(kind, above)
      for i, k in ipairs(order) do
        if k == above then table.insert(order, i + 1, kind) return end
      end
      error("no such level to insert above: " .. tostring(above), 2)
    end
    local keepWM = _G.WorldMapFrame
    _G.WorldMapFrame = { GetPinFrameLevelsManager = function() return fl end }
    NS.Pins.layer = nil
    NS.Pins.Update()
    local lv
    for _, p in pairs(PINS.world) do lv = p.level end
    H.eq(lv, "PIN_FRAME_LEVEL_BISMEMORIES", "pins go on their own layer")
    H.ok(fl:GetValidFrameLevel(lv) > fl:GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_EXPLORATION")
         and fl:GetValidFrameLevel(lv) < fl:GetValidFrameLevel("PIN_FRAME_LEVEL_AREA_POI"),
         "above the map's art, under every quest and point of interest")
    NS.Pins.Update()
    local n2 = 0
    for _, k in ipairs(order) do if k == lv then n2 = n2 + 1 end end
    H.eq(n2, 1, "the layer is made once a session, not once per update")
    -- a client whose manager refuses: the library's own level, the pins still there
    function fl:InsertFrameLevelAbove() error("refused") end
    order = { "PIN_FRAME_LEVEL_AREA_POI" }
    NS.Pins.layer = nil
    H.eq(NS.Pins.Update(), 2, "a map that will not take a new layer: the pins still go up")
    for _, p in pairs(PINS.world) do lv = p.level end
    H.eq(lv, nil, "on the library's default level")
    _G.WorldMapFrame = keepWM
    NS.Pins.layer = nil
  end
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
  H.ok(J.frame.rows[2]._text == "level 20" and strip(J.frame.subs[2]._text):find("LEVEL UP", 1, true), "rows in plain words",
       strip(J.frame.subs[2]._text) .. " / " .. strip(J.frame.rows[2]._text))
  local hitMine
  for i, hit in ipairs(J.frame.hits) do if hit.entry == mine then hitMine = hit end end
  hitMine:Click()
  run() run()                                          -- the boss: asked, asked again, looked at (the client's rule)
  local f = J.frame
  H.ok(J.sel == mine and strip(f.kind._text):find("^BOSS") and f.text._text == "first kill: Ragnaros", "click a row: the detail")
  H.ok(strip(f.whoWith._text) == "WITH" and f.whoWith:IsShown() and f.withBtns[1]:IsShown() and f.withBtns[1].who == "Kumlance Wildhammer"
       and f.withBtns[2].who == "Neg Crotic" and strip(f.data.took.val._text) == "4:10",
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
  H.ok(them:IsShown() and them._creature == 11502 and them._anim == J.DEAD, "beside the boss, lying where it fell")
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

-- ===================================================================== 6 Nov: the five UI rules
-- Arn, 6 Nov 2026, with BiS Tools' processing window as the model: short words for every long command,
-- everything clickable POPS under the mouse, Escape closes every window, small text gets bigger, and the
-- main window shows which version (and which deployed copy) it is.
;(function()
  local J, M, T = NS.J, NS.M, NS.T
  local log = M.Log()
  local d = NS.DB()
  local function wipe() for k = #log, 1, -1 do log[k] = nil end end
  local function near(c, name)
    local r, g, b = T.rgb(name)
    return type(c) == "table" and math.abs(c[1] - r) < 0.01 and math.abs(c[2] - g) < 0.01 and math.abs(c[3] - b) < 0.01
  end
  local function run(line) said = {} NS.Slash(line) return table.concat(said, " | ") end

  H.section("6 Nov: short words - every command longer than 4 letters answers to 4 or fewer")
  local SHORT = NS.SHORT or {}
  -- the words the slash code compares against, read off the file itself: a new long command without a
  -- short word goes red here the day it is added
  local src = bytes(ROOT .. "/Core/Slash.lua") or ""
  local words, seen = {}, {}
  for w in src:gmatch('cmd == "(%a+)"') do if not seen[w] then seen[w] = true words[#words + 1] = w end end
  for w in pairs(NS.SLASH_WORD or {}) do if not seen[w] then seen[w] = true words[#words + 1] = w end end
  table.sort(words)
  H.ok(#words >= 20, "the slash words were found", #words)
  for _, w in ipairs(words) do
    local long = NS.SlashWord and NS.SlashWord(w) or w
    if #w > 4 and #long <= 4 then
      H.ok(true, ("/bism %s is /bism %s"):format(w, long))          -- "where" is "path": short already
    elseif #w > 4 then
      local s = SHORT[long]
      H.ok(type(s) == "string" and #s <= 4 and s ~= long, ("/bism %s has a short word"):format(w), tostring(s))
      H.eq(NS.SlashWord and s and NS.SlashWord(s), long, ("/bism %s means /bism %s"):format(tostring(s), w))
    end
  end
  -- THE SAME THING HAPPENS, not just the same name: each pair from the same start, the second run of each
  -- puts a switch back where it was
  for _, p in ipairs({ { "sound" }, { "clear" }, { "zones" }, { "status" }, { "heard" }, { "onthisday" },
                       { "every", " boss" }, { "clean" }, { "group" } }) do
    local long, arg = p[1], p[2] or ""
    local short = SHORT[long] or long
    local want = run(long .. arg) run(long .. arg)
    local got = run(short .. arg) run(short .. arg)
    H.ok(short ~= long and want ~= "" and got == want, ("/bism %s does what /bism %s does"):format(short, long), got)
  end
  local w = NS.CFG.Build()
  local was = w:IsShown()
  NS.Slash((SHORT.options or "options"))
  H.ok(SHORT.options and w:IsShown() ~= was, "/bism " .. tostring(SHORT.options) .. " opens the options, as /bism options does")
  NS.Slash((SHORT.options or "options"))
  J.Hide()
  NS.Slash(SHORT.journal or "journal")
  H.ok(SHORT.journal and J.frame:IsShown(), "/bism " .. tostring(SHORT.journal) .. " opens the journal")
  J.Hide()
  local help = run("help")
  for long, s in pairs(SHORT) do
    H.ok(help:find(long .. " (" .. s .. ")", 1, true), ("the help shows %s (%s)"):format(long, s), help)
  end

  H.section("6 Nov: every button and row lights up under the mouse")
  log = M.Log()                      -- `/bism clear` above put a new table in the saved log
  wipe()
  _G.C_Map.GetMapRectOnMap = function(_, to) if to == 947 then return 0.4, 0.6, 0.3, 0.5 end end
  local e = { reason = "boss", detail = "Hogger", zone = "Elwynn Forest", at = os.time() - 60, char = M.Me(),
              with = { "Kumlance Wildhammer" }, map = 1429, x = 0.5, y = 0.5 }
  log[1] = e
  J.everyone, J.page = nil, "memories"
  J.Show()
  J.Select(e)
  local f = J.frame
  -- `overText`: the wash is drawn over the label (a HIGHLIGHT texture, or a patch above its parent's text),
  -- so it stays a tint and the bar does the popping
  local function pops(b, what, overText)
    local enter = b and b:GetScript("OnEnter")
    H.ok(enter ~= nil, what .. ": answers the mouse")
    if not enter then return end
    b:Fire("OnEnter")
    local wash, bar = b.wash, b.bar
    local a = wash and wash:GetAlpha() or 0
    local over = overText or (wash and (wash._layer == "HIGHLIGHT" or wash._layer == "OVERLAY"))
    H.ok(a >= (over and 0.2 or 0.3) and a <= (over and 0.28 or 0.35), what .. ": a clear wash under the mouse", a)
    H.ok(wash and near(wash._color, "accent"), what .. ": the wash is the accent")
    H.ok(bar and bar:GetAlpha() == 1 and (bar._w or 0) >= 2 and (bar._w or 0) <= 3, what .. ": a 2-3 px bar lit on the left",
         bar and bar._w)
    H.ok(bar and near(bar._color, "accent"), what .. ": the bar is the accent")
    b:Fire("OnLeave")
    H.ok(wash and wash:GetAlpha() == 0 and bar and bar:GetAlpha() == 0, what .. ": and dark again when the mouse leaves")
  end
  for i, b in ipairs(f.tabs) do pops(b, "the " .. b.name .. " tab") end
  pops(f.who, "the this-character button")
  -- the label to full brightness, and back to what it was
  local other = f.tabs[2]
  other:Fire("OnEnter")
  H.ok(near(other.word._color, "ink"), "a tab's word goes bright under the mouse")
  other:Fire("OnLeave")
  H.ok(near(other.word._color, "ink2"), "and back to its resting colour")
  -- the cockpit (8 Nov): the chosen key's word is bright and its green bar lit - and a hover gives both back
  H.ok(near(f.tabs[1].word._color, "ink") and f.tabs[1].lit:GetAlpha() == 1, "the chosen key is bright, its bar lit")
  f.tabs[1]:Fire("OnEnter") f.tabs[1]:Fire("OnLeave")
  H.ok(near(f.tabs[1].word._color, "ink") and f.tabs[1].lit:GetAlpha() == 1, "and stays so after a hover")
  local hit, row
  for i, h in ipairs(f.hits) do if h.entry == e then hit, row = h, i end end
  pops(hit, "a memory's row", true)
  if hit then
    hit:Fire("OnEnter")
    H.ok(near(f.rows[row]._color, "ink"), "the row's words go bright under the mouse")
    hit:Fire("OnLeave")
    local mr, mg, mb = J.Glass("magenta")
    local c = f.rows[row]._color
    H.ok(c and math.abs(c[1] - mr) < 0.01 and math.abs(c[2] - mg) < 0.01 and math.abs(c[3] - mb) < 0.01,
         "and rest in their own colour (the chosen line's magenta)")
  end
  local headHit = f.hits[1].entry == nil and f.hits[1] or nil
  if headHit then
    headHit:Fire("OnEnter")
    H.ok(not headHit.wash or headHit.wash:GetAlpha() == 0, "a night's heading is no button: it does not light up")
    headHit:Fire("OnLeave")
  end
  pops(f.withBtns[1], "a name under 'with'")
  pops(J.Toast(e, "A year ago today"), "the on-this-day card")
  J.toast:Hide()
  -- the map's pins and the world map's pins: a modest light - the outline goes to the accent, the map is not washed
  J.Tab("map")
  local dot = f.map.dots and f.map.dots[1]
  H.ok(dot ~= nil and dot:IsShown(), "the map has a pin to hover")
  if dot then
    local was = dot.sides[1]._color
    dot:Fire("OnEnter")
    H.ok(near(dot.sides[1]._color, "accent") and near(dot.sides[4]._color, "accent"), "a map pin's outline lights under the mouse")
    dot:Fire("OnLeave")
    H.ok(dot.sides[1]._color[1] == was[1] and dot.sides[1]._color[2] == was[2], "and goes back to its colour")
  end
  J.Tab("memories")
  d.pins = "mine"
  NS.Pins.Update()
  local pin = NS.Pins.pins[e]
  H.ok(pin ~= nil, "the world map has a pin to hover")
  if pin then
    -- A VIEWFINDER, NOT A SQUARE (Arn, 7 Nov live: "maybe we dont make them into a square but a crosshair or
    -- something that has the middle blank ... so the middle is always see through"): four corner brackets, nothing
    -- drawn in the middle
    local P = NS.Pins
    H.ok(pin.fill == nil and pin.arms and #pin.arms == 8 and pin.shade and #pin.shade == 8,
         "a pin is four corner brackets (and their dark outline), no filled square")
    H.ok(2 * P.ARM + 2 <= P.SIZE, "each bracket stops short of the middle: the middle is see-through", P.ARM .. "/" .. P.SIZE)
    local kind = pin.arms[1]._color
    H.ok(kind and not near(kind, "accent"), "the brackets wear the memory's colour")
    pin:Fire("OnEnter")
    H.ok(near(pin.arms[1]._color, "accent") and near(pin.arms[8]._color, "accent"), "a world-map pin lights under the mouse")
    pin:Fire("OnLeave")
    H.ok(pin.arms[1]._color[1] == kind[1] and pin.arms[1]._color[2] == kind[2], "and goes back to its colour")
  end

  H.section("6 Nov: Escape closes every window, and small text is bigger")
  local listed = {}
  for _, n in ipairs(_G.UISpecialFrames) do listed[n] = true end
  H.ok(listed.BiSMemoriesJournal, "Escape closes the journal")
  H.ok(listed.BiSMemoriesOptions, "Escape closes the options")
  H.ok((NS.CFG.SCALE or 1) >= 1.2, "the options window (9 pt text) is drawn at least 20% bigger", NS.CFG.SCALE)

  H.section("6 Nov: the journal shows its version - faint, in the foot, with the deploy stamp")
  local keep = NS.BUILD
  NS.BUILD = "feat/ui-rules@abc1234 1106-1841"
  J.Refresh()
  H.eq(f.build and strip(f.build._text), TOC_VERSION .. "  abc1234 1106-1841", "a deployed copy: the version, its commit and when")
  fitsIn(f, "the journal, with its deploy stamp")
  NS.BUILD = "main@1234567+ 1106-0900"
  J.Refresh()
  H.eq(f.build and strip(f.build._text), TOC_VERSION .. "  1234567+ 1106-0900", "an uncommitted copy keeps its +")
  NS.BUILD = nil
  J.Refresh()
  H.eq(f.build and strip(f.build._text), TOC_VERSION, "a released copy: the version alone")
  H.ok(f.build and f.build:GetAlpha() < 1, "and faint")
  local p = f.build and f.build._points and f.build._points[1]
  H.ok(p and p.point:find("BOTTOM") ~= nil, "in the foot, not the header bar")
  -- ONE BAR, ONE LABEL: the header keeps "BiS> Memories" as its only label
  local inBar = 0
  for _, r in ipairs(f._regions or {}) do
    local q = r._size and r._points and r._points[1]
    if q and q.point:find("TOP") and q.y > -J.HEAD then inBar = inBar + 1 end
  end
  H.eq(inBar, 1, "the header bar has one label")
  -- read from the TOC copy deploy.sh stamped
  local realMeta = _G.GetAddOnMetadata
  _G.GetAddOnMetadata = function(a, key) if key == "X-BiS-Build" then return "main@1234567+ 1106-0900" end return realMeta(a, key) end
  H.eq(NS.ReadBuild and NS.ReadBuild(), "main@1234567+ 1106-0900", "the stamp is read from the TOC copy")
  _G.GetAddOnMetadata = function(a, key) if key == "X-BiS-Build" then return "" end return realMeta(a, key) end
  H.eq(NS.ReadBuild and NS.ReadBuild(), nil, "an empty stamp is no stamp")
  _G.GetAddOnMetadata = realMeta
  H.eq(NS.ReadBuild and NS.ReadBuild(), nil, "and a released copy has none")
  NS.BUILD = keep
  J.Hide()
  wipe()
end)()

-- ===================================================================== 7 Nov: Forever 1.0
-- Arn, 7 Nov 2026: "the core functionality when you install this add-on is you expected to take some screenshots,
-- but we can get into the nitty gritty in that big option menu". A NEW install takes the big moments' pictures and
-- nothing else; a player who already has the addon keeps every switch exactly as it was.
;(function()
  local M, CFG, J, T = NS.M, NS.CFG, NS.J, _G.BiSTheme
  local CORE = { "levelup", "boss", "achievement", "first" }
  local QUIET = { "loot", "death", "duel", "zone", "exalted", "candid", "gamba", "group" }
  local keepDB, keepChar = _G.BiSMemoriesDB, _G.BiSMemoriesCharDB
  -- a login: the client hands back these two (nil = nothing came back), then ADDON_LOADED
  local function login(acct, char)
    _G.BiSMemoriesDB, _G.BiSMemoriesCharDB = acct, char
    fire("ADDON_LOADED", "BiSMemories")
    return _G.BiSMemoriesDB
  end
  local function scalars(t)
    local out = {}
    for k, v in pairs(t) do if type(v) ~= "table" then out[k] = v end end
    return out
  end
  local function same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false, k end end
    for k, v in pairs(b) do if a[k] ~= v then return false, k end end
    return true
  end

  H.section("7 Nov: Forever 1.0 - a new install starts quiet, the big moments on")
  local d = login(nil, nil)
  for _, k in ipairs(CORE) do H.eq(d[k], true, "new install: " .. k .. " on - the addon's main job") end
  H.eq(d.clean, true, "new install: the interface still steps out of the picture")
  for _, k in ipairs(QUIET) do H.eq(d[k], false, "new install: " .. k .. " off until switched on") end
  H.eq(d.sound, false, "new install: no camera click")
  H.eq(d.onThisDay, false, "new install: no on-this-day line or card at login")
  H.eq(d.pins, "off", "new install: nothing on the world map")
  H.eq(d.groupOthers, false, "new install: nobody else can start your countdown")
  H.eq(d.forever10, true, "and the stamp, so this never runs again")
  -- quiet in practice, not just in the table
  H.eq(select(2, M.Shoot("loot", "[Thunderfury]")), "off", "a loot line takes no picture")
  H.eq(M.OnThisDay(), nil, "the login says nothing")
  M.counting = nil
  local h = _G.LibBiSComm.handlers and _G.LibBiSComm.handlers.MEM and _G.LibBiSComm.handlers.MEM.SNAP
  H.ok(type(h) == "function", "the group call is still listened for")
  if h then h("Stranger", "2") end
  H.ok(not M.counting, "someone else's /bism group starts nothing on a new install's screen")
  local realGroup, wire = _G.IsInGroup, #H.wire
  _G.IsInGroup = function() return true end
  local ok, why = M.GroupPhoto(3)
  _G.IsInGroup = realGroup
  H.ok(not ok and tostring(why):find("off", 1, true) and #H.wire == wire and not M.counting,
       "your own call with group photos off: says so, sends nothing", tostring(why))

  H.section("7 Nov: Forever 1.0 - an existing save keeps every feature as it was")
  -- a 0.10.1 save the way that version wrote it, minus keys an older one never stored (nil there meant ON),
  -- and one switch the player chose
  d = login({ comm = true, levelup = true, boss = true, loot = false, death = true,
              log = { { at = 5, reason = "zone", detail = "Durotar" } } }, nil)
  H.eq(d.loot, false, "the player's own 'off' stays off")
  for _, k in ipairs(QUIET) do
    if k ~= "loot" then H.eq(d[k], true, "existing: " .. k .. " still on, written down now") end
  end
  H.eq(d.sound, true, "existing: the click still clicks")
  H.eq(d.onThisDay, true, "existing: on this day still comes")
  H.eq(d.pins, "mine", "existing: your pins still on the map")
  H.eq(d.groupOthers, true, "existing: the group's call still starts your countdown")
  H.eq(d.forever10, true, "stamped")
  M.counting = nil
  if h then h("Stranger", "2") end
  H.ok(M.counting, "and someone else's call counts down here, as it did")
  for _ = 1, 3 do runTimers() end
  M.counting = nil
  -- a player who had the extras off keeps them off
  d = login({ comm = true, sound = false, onThisDay = false, pins = "all", log = { { at = 6, reason = "boss" } } }, nil)
  H.ok(d.sound == false and d.onThisDay == false and d.pins == "all", "an existing 'off' or 'all' is never touched")
  -- THE FOREVER LOSS: the account-wide file came back empty, the per-character copy did not. A player, not new.
  d = login(nil, NS.Serialize({ comm = true, log = { { at = 7, reason = "boss", detail = "Hogger" } } }))
  H.ok(d.zone == true and d.sound == true and d.pins == "mine" and d.groupOthers == true,
       "only the per-character copy came back: still an existing player, nothing turned off")
  d = login(nil, NS.Serialize({ zones = { Mulgore = true } }))
  H.ok(d.zone == true and d.groupOthers == true, "a copy with places and no pictures yet: an existing player too")

  H.section("7 Nov: Forever 1.0 - a second login changes nothing")
  d = login({ comm = true, log = { { at = 8, reason = "boss" } } }, nil)
  local once = scalars(d)
  d = login(d, nil)
  local okSame, diff = same(once, scalars(d))
  H.ok(okSame, "an existing save: the second 1.0 login writes nothing new", diff)
  -- a new install, then the player switches things: the next login keeps their choice
  d = login(nil, nil)
  d.loot, d.sound, d.levelup = true, true, false
  once = scalars(d)
  d = login(d, NS.Serialize(d))
  okSame, diff = same(once, scalars(d))
  H.ok(okSame, "a new install's own choices survive the next login", diff)
  -- a stamped save where a switch went missing is NOT frozen back on (the stamp means: done)
  d = login({ comm = true, forever10 = true, log = { { at = 9, reason = "boss" } } }, nil)
  H.ok(d.zone == false and d.sound == false and d.groupOthers == false, "after the stamp, a missing switch takes today's default")

  H.section("7 Nov: one options home - BiS> Memories in the game's own options")
  d = login(nil, nil)
  local keepS, keepRoot, keepPage = rawget(_G, "Settings"), T.settingsRoot, T.settingsPages.BiSMemories
  local reg, opened, nextId = {}, {}, 0
  local function Category(name)
    nextId = nextId + 1
    local c = { name = name, id = nextId }
    function c:GetID() return self.id end
    reg[c.id] = c
    return c
  end
  _G.Settings = {
    RegisterCanvasLayoutCategory = function(frame, name) local c = Category(name) c.frame = frame return c, {} end,
    RegisterAddOnCategory = function(c) c.addon = true end,
    RegisterCanvasLayoutSubcategory = function(parent, frame, name)
      if not (parent and parent.addon) then error("parent category is not registered") end
      local c = Category(name) c.frame, c.parentCat = frame, parent
      return c, {}
    end,
    OpenToCategory = function(id) if not reg[id] then return false end opened[#opened + 1] = reg[id].name return true end,
  }
  T.settingsRoot, T.settingsPages.BiSMemories = nil, nil
  fire("PLAYER_LOGIN")
  local page = T.settingsPages.BiSMemories
  H.ok(page and page.category and page.spec and page.spec.title == "Memories", "registered at login: BiS> Memories")
  local spec = page and page.spec or {}
  H.eq(spec.api and spec.api.name, "BiSMemoriesAPI", "its API named for other addon authors")
  H.ok(type(spec.about) == "string" and #spec.about > 20, "a line saying what it is for")
  local okSt, st = pcall(spec.status or error)
  H.eq(okSt and st, "4 of 12 moments - sound off", "the front page: what is on, in a few words")
  -- 8 Nov (Settings minor 3, the family rule - Arn of BiS> Tools: "it looks way way better do it for the other
  -- ones"): the page is the kit's DASHBOARD. Every section down the left, the picked one's settings big on the
  -- right, the help strip along the bottom - and the options window is left exactly as it is.
  H.ok(type(spec.build) == "function" and type(spec.refresh) == "function", "the page draws a dashboard: build and refresh")
  H.eq(spec.window, nil, "no stand-in button to the options window: the page holds every setting itself")
  -- the window an earlier section built holds an earlier login's save; in the game both are built after the one
  -- ADDON_LOADED, on the same table - so build it again on this login's
  CFG.built, CFG.frame = nil, nil
  local ow = CFG.Build()
  ow:Hide()
  local owParent, owScale = ow:GetParent(), ow:GetScale()
  if page and page.frame then page.frame:Fire("OnShow") end
  local dash = page and page.frame and page.frame.body and page.frame.body.dash
  H.ok(dash ~= nil, "showing the page builds the dashboard")
  dash = dash or { rows = {}, pages = {}, entries = {} }
  H.ok(ow:GetParent() == owParent and ow:GetScale() == owScale, "showing the page: the window keeps its parent and its scale")
  H.ok(not ow:IsShown(), "showing the page: the window stays hidden")
  H.ok(not (page.frame.optBtn and page.frame.optBtn:IsShown()), "and no stand-in button on the page")
  local WANT = { "camera", "milestones", "bosses", "loot", "deaths", "world", "group", "journal", "pins", "album", "share" }
  H.eq(#dash.rows, #WANT, "a row per section down the left")
  for i, k in ipairs(WANT) do H.eq(dash.rows[i] and dash.rows[i].entry.key, k, "section " .. i .. ": " .. k) end
  H.eq(dash.list and dash.list.head:GetText(), "SECTIONS", "the list's title")
  H.eq(dash.count and dash.count:GetText(), "1 of 5 on", "a new install: bosses on; loot, deaths, group photos, pins off")
  H.eq(dash.selected, "camera", "the camera is picked first")
  -- every row of the options window is on the dashboard exactly once: a row, a section's switch, or its button
  local seen = {}
  local function saw(k) if k then seen[k] = (seen[k] or 0) + 1 end end
  for _, e in ipairs(dash.entries) do
    for _, o in ipairs(e.options or {}) do saw(o.key) end
    saw(e.switch and e.switch.key)
    saw(e.open and e.open.key)
    H.ok(type(e.desc) == "string" and #e.desc > 20, "words for a player: " .. tostring(e.key))
  end
  for _, r in ipairs(CFG.Rows()) do H.eq(seen[r.key], 1, "on the dashboard once: " .. tostring(r.key)) end
  -- the SAME tables: no second copy of a setting
  local winOpt, winRow = {}, {}
  for _, r in ipairs(ow.rows or {}) do if r.opt then winOpt[r.opt.key], winRow[r.opt.key] = r.opt, r end end
  local sameT, n = true, 0
  for _, e in ipairs(dash.entries) do
    for _, o in ipairs(e.options or {}) do n = n + 1 if winOpt[o.key] ~= o then sameT = false end end
  end
  H.ok(n > 0 and sameT, "every dashboard row is the options window's own option table", n)

  local function rowOf(key) for _, r in ipairs(dash.rows) do if r.entry.key == key then return r end end end
  local function pick(key)
    local r = rowOf(key)
    if r then r:Fire("OnClick", "LeftButton") end
    return dash.pages[key] or {}
  end
  local function find(rows, key) for _, r in ipairs(rows) do if r.opt.key == key then return r end end end
  local loot = pick("loot")
  H.eq(dash.selected, "loot", "a click on a section picks it")
  H.ok(#loot == 2 and loot[1]:IsShown() and loot[1].opt.key == "lootQuality" and loot[2].opt.key == "gems",
       "its own rows on the right: the quality, the gems")
  H.eq(dash.detail.name:GetText(), "loot", "under its name")
  H.ok(dash.detail.usage:IsShown() and dash.detail.usage:GetText():find("/bism loot", 1, true), "its command at the foot",
       dash.detail.usage:GetText())
  local cam = pick("camera")
  H.ok(not loot[1]:IsShown(), "picking another: the last one's rows go")
  -- a setting flipped on the dashboard: the saved value, and the options window's row agrees after its paint
  local snd = find(cam, "sound")
  local before = d.sound
  if snd then snd.sw:Fire("OnClick", "LeftButton") end
  H.eq(d.sound, not before, "the camera click flipped on the dashboard: the saved value")
  ow:Paint()
  H.eq(winRow.sound and winRow.sound.ctl.on, d.sound, "the options window's row agrees after its paint")
  H.eq(snd and snd.sw.on, d.sound, "and the dashboard's switch says it")
  local gap = find(cam, "gap")
  local g0 = d.gap or 8
  if gap then gap.plus:Fire("OnClick", "LeftButton") end
  H.eq(d.gap, g0 + 2, "the stepper: seconds between, up by two")
  ow:Show()
  if gap then gap.minus:Fire("OnClick", "LeftButton") end
  H.eq(winRow.gap and winRow.gap.ctl.val:GetText(), tostring(g0), "the options window, open, is repainted at once")
  ow:Hide()

  -- a section's own switch goes through the same setter as /bism on|off
  NS.Slash("on boss")
  spec.refresh(page.frame.body)
  pick("bosses")
  H.ok(dash.detail.switch:IsShown() and dash.detail.switch.on == true and rowOf("bosses").state:GetText() == "ON",
       "bosses: the big switch and the list say ON")
  dash.detail.switch:Fire("OnClick", "LeftButton")
  H.eq(d.boss, false, "the big switch off: the same saved value /bism off boss writes")
  H.ok(rowOf("bosses").state:GetText() == "off" and dash.pages.bosses[1].label:GetAlpha() < 1,
       "the list follows, and its settings grey")
  NS.Slash("on boss")
  spec.refresh(page.frame.body)
  H.ok(dash.detail.switch.on == true and rowOf("bosses").state:GetText() == "ON", "/bism on boss: the page says so at its next paint")
  rowOf("loot"):Fire("OnClick", "RightButton")
  H.eq(d.loot, true, "a right-click in the list switches loot on")
  NS.Slash("off loot")
  spec.refresh(page.frame.body)
  H.eq(rowOf("loot").state:GetText(), "off", "/bism off loot: the list says off")
  -- the pins: switched off keeps "off", switched on comes back to the last choice
  NS.Slash("pins all")
  spec.refresh(page.frame.body)
  pick("pins")
  H.ok(dash.detail.switch.on == true, "pins all: the pins switch is on")
  dash.detail.switch:Fire("OnClick", "LeftButton")
  H.eq(d.pins, "off", "the pins switched off")
  dash.detail.switch:Fire("OnClick", "LeftButton")
  H.eq(d.pins, "all", "and on again: back to every character's")

  -- the buttons put the game's options away first, so the journal and the picture are not behind them
  local up = true
  local keepPanel, keepHide = rawget(_G, "SettingsPanel"), rawget(_G, "HideUIPanel")
  _G.SettingsPanel = { IsShown = function() return up end, Hide = function() up = false end }
  _G.HideUIPanel = function(x) x:Hide() end
  pick("journal")
  J.Hide()
  H.eq(dash.detail.open.label:GetText(), "the journal", "the journal's section: a button to it")
  dash.detail.open:Fire("OnClick", "LeftButton")
  H.ok(not up and J.frame:IsShown(), "which puts the game's options away and opens the journal")
  J.Hide()
  up = true
  pick("pins")
  dash.detail.open:Fire("OnClick", "LeftButton")
  H.ok(not up and J.frame:IsShown() and J.page == "map", "the pins' button: the journal's map")
  J.Hide()
  J.Tab("memories")
  up = true
  local shotWithPanel = "not shot"
  local realShoot = M.Shoot
  M.Shoot = function() shotWithPanel = up return nil, "test" end
  local now = find(pick("camera"), "now")
  if now then now.btn:Fire("OnClick", "LeftButton") end
  M.Shoot = realShoot
  H.eq(shotWithPanel, false, "a picture now from the page: the game's options go first, the picture is of the game")
  _G.SettingsPanel, _G.HideUIPanel = keepPanel, keepHide
  pick("album")
  H.ok(dash.detail.none:IsShown() and dash.detail.usage:GetText():find("/bism path", 1, true)
       and dash.detail.open:IsShown(), "the album page: words, its commands, the journal (the address to copy is there)")

  H.eq(spec.open and spec.open.label, "your memories", "its big button: your memories")
  J.Hide()
  if spec.open then spec.open.func() end
  H.ok(J.frame:IsShown(), "which opens the journal")
  J.Hide()
  -- every switch a new install starts off has a row a player can find
  local rows = {}
  for _, r in ipairs(CFG.Rows()) do rows[r.key] = r end
  for _, k in ipairs(QUIET) do H.ok(rows[k] and rows[k].kind == "toggle", "a row for " .. k) end
  for _, k in ipairs({ "sound", "onThisDay", "pins", "groupOthers" }) do H.ok(rows[k] ~= nil, "a row for " .. k) end
  local r = rows.groupOthers
  H.ok(r and r.get(d) == false, "the group row reads off on a new install")
  if r then r.set(d, true) end
  H.eq(d.groupOthers, true, "and switches it on")
  if r then r.set(d, false) end

  H.section("7 Nov: the minimap - left your memories, right the options")
  local b = CFG.button
  J.Hide()
  b:Fire("OnClick", "LeftButton")
  H.ok(J.frame:IsShown(), "left-click: your memories")
  J.Hide()
  -- 8 Nov (Minimap minor 5): right-click = our own options window, a toggle; never the game's options
  local ow2 = CFG.Build()
  ow2:Hide()
  local openedBefore = #opened
  b:Fire("OnClick", "RightButton")
  H.ok(ow2:IsShown(), "right-click: our own options window")
  H.ok(not J.frame:IsShown(), "and not the journal")
  b:Fire("OnClick", "RightButton")
  H.ok(not ow2:IsShown(), "a second right-click closes it")
  H.eq(#opened, openedBefore, "the right-click never opens the game's options")
  local tip, realAdd = {}, GameTooltip.AddLine
  GameTooltip.AddLine = function(_, t) tip[#tip + 1] = strip(t) end
  b:Fire("OnEnter")
  GameTooltip.AddLine = realAdd
  local said3 = table.concat(tip, " | ")
  H.ok(said3:find("left-click  your memories", 1, true) and said3:find("right-click  options", 1, true)
       and said3:find("drag  move", 1, true), "the tooltip says exactly that", said3)
  -- no game options panel (an older client): the right-click falls back to our own window
  _G.Settings = nil
  local w = CFG.Build()
  w:Hide()
  b:Fire("OnClick", "RightButton")
  H.ok(w:IsShown(), "no options panel: the right-click opens our own window")
  w:Hide()
  _G.Settings, T.settingsRoot = keepS, keepRoot
  T.settingsPages.BiSMemories = keepPage or T.settingsPages.BiSMemories

  H.section("7 Nov sweep: a name's menu, never opened by us inside an instance")
  local menu
  local realInst, realSecret = _G.IsInInstance, _G.issecretvalue
  _G.UnitPopup_OpenMenu = function(kind, ctx) menu = kind .. ":" .. tostring(ctx.name) end
  _G.FriendsFrame_ShowDropdown = function(name) menu = "dropdown:" .. tostring(name) end
  _G.IsInInstance = function() return false, "none" end
  H.ok(J.PlayerMenu("Kumlance Wildhammer") and menu == "FRIEND:Kumlance Wildhammer", "out in the world: the game's menu")
  menu = nil
  said = {}
  _G.IsInInstance = function() return true, "party" end
  H.ok(not J.PlayerMenu("Kumlance Wildhammer") and menu == nil, "in a dungeon: no menu (ours would break the game's own)")
  H.ok(#said == 1 and said[1]:find("Kumlance", 1, true), "and one line saying why", said[1])
  local secret = setmetatable({}, { __eq = function() error("secret value: refused", 0) end,
                                    __tostring = function() error("secret value: refused", 0) end })
  _G.issecretvalue = function(v) return v == nil and false or rawequal(v, secret) end
  _G.IsInInstance = function() return secret, "party" end
  said = {}
  local okP, got = pcall(J.PlayerMenu, "Kumlance Wildhammer")
  H.ok(okP and not got and menu == nil, "a hidden answer is not a 'no': no menu", tostring(got))
  _G.IsInInstance = function() error("no such call", 0) end
  okP, got = pcall(J.PlayerMenu, "Kumlance Wildhammer")
  H.ok(okP and not got and menu == nil, "a refusing client: no menu, no error")
  _G.IsInInstance, _G.issecretvalue = realInst, realSecret
  _G.UnitPopup_OpenMenu, _G.FriendsFrame_ShowDropdown = nil, nil

  _G.BiSMemoriesDB, _G.BiSMemoriesCharDB = keepDB, keepChar
end)()

-- ===================================================================== 8 Nov: the glass cockpit
-- Arn, 8 Nov 2026: "lets give bis memories the cockpit theme treatment lets make it a cool fancy jetliner look" -
-- and on the old window: "these are becoming too cramp find a better solution what would a multimillion dollar plane
-- cockpit do it ... use the new box outline with center blank, and maybe a zoom feature on the map?" - and "bis
-- memories is not showing the boss dead". Two glass displays in a quiet housing, each with one job: the left a flight
-- computer's page (six big lines, paged), a navigation display for the map; the right the memory itself.
;(function()
  local J, M, MV = NS.J, NS.M, NS.MapView
  local d = NS.DB()
  local log = M.Log()
  local function wipe() for k = #log, 1, -1 do log[k] = nil end end
  local function near(c, r, g, b)
    return type(c) == "table" and math.abs(c[1] - r) < 0.01 and math.abs(c[2] - g) < 0.01 and math.abs(c[3] - b) < 0.01
  end
  local function glass(c, name) return near(c, J.Glass(name)) end
  local function theme(c, name) return near(c, NS.T.rgb(name)) end
  local q = {}
  local keepTimer = _G.C_Timer
  _G.C_Timer = { After = function(t, fn) q[#q + 1] = { t = t, fn = fn } end }
  local function run() local t = q q = {} for _, x in ipairs(t) do x.fn() end return #t end
  for _, t in ipairs(M.TRIGGERS) do d[t.key] = true end
  d.gap, d.delay = 0, 0
  M.me = nil
  wipe()
  J.everyone, J.sel, J.page = nil, nil, "memories"
  local f = J.Build()
  local keys = { f.tabs[1], f.tabs[2], f.tabs[3], f.who, f.close, f.prev, f.next, f.rangeDown, f.rangeUp }
  local function shownEntries()
    local n = 0
    for _, h in ipairs(f.hits) do if h:IsShown() and h.entry then n = n + 1 end end
    return n
  end
  local function slotOf(e) for i, h in ipairs(f.hits) do if h:IsShown() and h.entry == e then return i end end end

  H.section("8 Nov: the cockpit - a quiet housing, two glass displays")
  H.ok(math.abs(f:GetWidth() / f:GetHeight() - 1.43) < 0.01, "still the BiS window shape, 1.43:1", f:GetWidth() .. "x" .. f:GetHeight())
  H.ok(f:GetWidth() >= 950 and f:GetHeight() >= 660, "and much bigger than the cramped 700 x 490 it was",
       f:GetWidth() .. "x" .. f:GetHeight())
  H.ok(f.left and f.right and f.left:GetWidth() == f.right:GetWidth() and f.left:GetHeight() == f.right:GetHeight(),
       "two displays, the same size")
  local lx, rx = f.left:OffsetFor("TOPLEFT"), f.right:OffsetFor("TOPLEFT")
  H.ok(lx and rx and lx >= 8 and lx + f.left:GetWidth() + 8 <= rx and rx + f.right:GetWidth() <= f:GetWidth() - 8,
       "side by side, apart, inside the housing", tostring(lx) .. "/" .. tostring(rx))
  H.ok(f.left.glass and f.left.glass._color and f.left.glass._color[1] == 0 and f.left.glass._color[2] == 0
       and f.left.glass._color[3] == 0 and f.right.glass._color[1] == 0, "the glass is black")
  H.ok(f.left.rim and theme(f.left.rim._color, "line2") and f.housing and theme(f.housing._color, "bg"),
       "a thin rim round each display, the housing in BiSTheme's own ground colour")
  -- the colours with a meaning, as a jetliner uses them
  for _, name in ipairs({ "green", "cyan", "magenta", "amber", "white" }) do
    local r, g, b = J.Glass(name)
    H.ok(type(r) == "number" and type(g) == "number" and type(b) == "number", "the display colour " .. name)
  end
  H.ok(f:IsClampedToScreen(), "the window cannot be dragged off the screen")
  local keepUI = UIParent._h
  UIParent._h = 600
  J.Show()
  H.ok(f:GetScale() < 1 and f:GetHeight() * f:GetScale() <= 600 - 20, "a short screen: the window is drawn smaller, ratio kept",
       f:GetScale())
  UIParent._h = keepUI
  J.Show()
  H.eq(f:GetScale(), 1, "a full-size screen: full size")
  J.Hide()

  H.section("8 Nov: the cockpit - bezel keys, not a tab row")
  H.ok(f.tabs[1].word._text == "MEMORIES" and f.tabs[2].word._text == "MAP" and f.tabs[3].word._text == "YEAR",
       "MEMORIES, MAP, YEAR keys")
  H.ok(f.who.word._text == "THIS CHARACTER" and f.close.word._text == "X", "the CHARACTER key and the close X are keys too")
  for _, k in ipairs(keys) do
    H.ok(k and k.word and realWidth(k.word) <= k:GetWidth() - 8, "the key's word fits its key: " .. tostring(k and k.word._text),
         k and (realWidth(k.word) .. " of " .. k:GetWidth()))
    H.ok(k and k.cap and k.shadow, "a raised key (a light top edge, a shadow under): " .. tostring(k and k.word._text))
  end
  -- set INTO THE BEZEL, outside the glass: above the displays or below them, never on them
  for _, k in ipairs(keys) do
    local _, y = k:OffsetFor("TOPLEFT")
    if not y then _, y = k:OffsetFor("TOPRIGHT") end
    local top = y and -y
    H.ok(top and (top + k:GetHeight() <= J.DISP_TOP or top >= J.DISP_TOP + J.DISP_H), "off the glass: " .. k.word._text,
         tostring(top))
  end
  J.Show()
  f.tabs[2]:Click()
  H.ok(J.page == "map" and f.map:IsShown() and not f.list:IsShown(), "MAP: the left display is the map")
  H.ok(f.tabs[2].lit:GetAlpha() == 1 and glass(f.tabs[2].lit._color, "green") and f.tabs[1].lit:GetAlpha() == 0,
       "the lit key has its green bar, the others none")
  H.ok(f.right:IsShown() and f.detail:IsShown(), "the right display still holds the memory")
  f.tabs[3]:Click()
  H.ok(J.page == "this year" and f.year:IsShown() and not f.map:IsShown(), "YEAR")
  f.tabs[1]:Click()
  H.ok(J.page == "memories" and f.list:IsShown() and not f.year:IsShown(), "MEMORIES")
  f.who:Click()
  H.ok(J.everyone and f.who.word._text == "ALL CHARACTERS", "CHARACTER: every character's")
  f.who:Click()
  H.ok(not J.everyone and f.who.word._text == "THIS CHARACTER", "and back")
  -- every key pops under the mouse: the wash, the bar on the left - and gives its light back
  for _, k in ipairs(keys) do
    k:Fire("OnEnter")
    H.ok(k.wash:GetAlpha() >= 0.3 and theme(k.wash._color, "accent") and k.bar:GetAlpha() == 1, "pops: " .. k.word._text)
    k:Fire("OnLeave")
    H.ok(k.wash:GetAlpha() == 0 and k.bar:GetAlpha() == 0, "and rests: " .. k.word._text)
  end
  f.tabs[1]:Fire("OnEnter") f.tabs[1]:Fire("OnLeave")
  H.ok(f.tabs[1].lit:GetAlpha() == 1, "a hover does not put out the lit key's bar")
  f.close:Click()
  H.ok(not f:IsShown(), "X closes it")

  H.section("8 Nov: the cockpit - the flight computer's page, six big lines")
  wipe()
  for i = 1, 40 do
    table.insert(log, 1, { at = 1000 + i, reason = "zone", detail = "place " .. i, zone = "Mulgore", char = M.Me() })
  end
  J.Show()
  J.Turn(-99)
  H.eq(J.PER, 6, "six memories a page")
  H.eq(shownEntries(), 6, "six on the first page")
  H.eq(strip(f.pageHead._text), "MEMORIES 1/7", "the page header: which page of how many")
  H.ok(strip(f.rows[1]._text):find("Mulgore", 1, true) and f.hits[1].entry == nil, "a night's heading first",
       strip(f.rows[1]._text))
  H.ok(glass(f.rows[1]._color, "cyan") and f.hits[1].sep and f.hits[1].sep:IsShown(), "a cyan separator")
  H.ok(f.rows[2]._text == "place 40" and strip(f.subs[2]._text):find("NEW PLACE", 1, true), "the newest under it: the title "
       .. "big, the time and the kind above it", strip(f.subs[2]._text))
  H.ok((f.rows[2]._size or 0) >= 14 and f.hits[2]:GetHeight() >= 50, "big type, generous lines", f.hits[2]:GetHeight())
  H.ok(glass(f.rows[2]._color, "white") and glass(f.subs[2]._color, "cyan"), "white data, cyan labels")
  H.eq(J.Turn(1), 2, "the next page")
  H.eq(strip(f.pageHead._text), "MEMORIES 2/7", "the header follows")
  H.ok(strip(f.rows[1]._text):find("Mulgore", 1, true) and f.rows[2]._text == "place 34",
       "a page that starts inside a night repeats its heading")
  f.next:Click()
  H.eq(J.pageNo, 3, "NEXT PAGE")
  f.prev:Click()
  H.eq(J.pageNo, 2, "PREV PAGE")
  f:Fire("OnMouseWheel", -1)
  H.eq(J.pageNo, 3, "the wheel down: the next page")
  f:Fire("OnMouseWheel", 1)
  H.eq(J.pageNo, 2, "the wheel up: the page before")
  H.eq(J.Turn(99), 7, "not past the last page")
  H.eq(shownEntries(), 4, "the last page holds what is left")
  H.eq(J.Turn(-99), 1, "nor before the first")
  f.hits[2]:Click()
  H.ok(J.sel == log[1] and f.selL:IsShown() and f.selR:IsShown() and glass(f.rows[2]._color, "magenta")
       and glass(f.selL.bar._color, "magenta"), "the chosen line: magenta brackets, its title magenta")
  H.ok(f.text._text == "place 40", "and the right display holds it")
  J.Select(log[40])
  H.ok(J.pageNo == 7 and slotOf(log[40]), "choosing a memory elsewhere turns to its page", J.pageNo)
  f.hits[2]:Fire("OnEnter")
  H.ok(f.hits[2].wash:GetAlpha() > 0 and f.hits[2].bar:GetAlpha() == 1, "a line pops under the mouse")
  f.hits[2]:Fire("OnLeave")
  fitsIn(f, "the cockpit, the last page")
  J.Turn(-99)
  fitsIn(f, "the cockpit, the first page")
  -- the worst page: every memory a night of its own, a heading over each
  wipe()
  for i = 1, 8 do
    table.insert(log, 1, { at = 100000 * i, reason = "boss", detail = "a very long boss name that goes on and on " .. i,
                           zone = "Blackrock Depths - The Grim Guzzler", char = M.Me() })
  end
  J.Turn(-99)
  J.Refresh()
  local last = 0
  for _, h in ipairs(f.hits) do
    if h:IsShown() then
      local _, y = h:OffsetFor("TOPLEFT")
      last = math.max(last, -y + h:GetHeight())
    end
  end
  H.ok(shownEntries() == 6 and last <= f.list:GetHeight(), "six nights, six headings: still inside the display",
       last .. " of " .. f.list:GetHeight())
  fitsIn(f, "the cockpit, a heading over every line")
  J.Hide()

  H.section("8 Nov: the cockpit - the boss lies dead beside you")
  wipe()
  HARNESS.knownCreature[11502] = nil
  local boss = { reason = "boss", detail = "first kill: Ragnaros", zone = "Molten Core", level = 60, at = os.time() - 60,
                 char = M.Me(), npc = 11502, secs = 250, file = "WoWScrnShot_110826_201500", with = { "Kumlance Wildhammer" } }
  log[1] = boss
  q = {}
  J.Show()
  J.Select(boss)
  local them, you = f.post.them, f.post.you
  H.ok(you:IsShown() and you._unit == "player", "you, on the left")
  H.ok(them:IsShown() and them._creature == 11502, "the boss is asked for, beside you")
  H.eq(them:GetModelFileID(), 0, "the client's first ask for a creature draws nothing (the rule, as measured)")
  H.ok(them._cam == nil and them._zoom == nil, "no camera yet - nothing to point it at")
  H.ok(#q >= 1 and math.abs(q[#q].t - J.LOAD_WAIT) < 1e-9 and J.LOAD_WAIT >= 0.5 and J.LOAD_WAIT <= 0.8,
       "it looks again a moment later", q[1] and q[1].t)
  run()
  H.eq(them._asks, 2, "nothing drew: asked a second time")
  H.ok(them:GetModelFileID() > 0, "and the second ask lands")
  H.ok(them._cam == nil, "the camera waits for the next look (a new model resets it)")
  run()
  H.eq(them._anim, J.DEAD, "the boss lies dead (anim " .. tostring(J.DEAD) .. ", UNVERIFIED)")
  H.ok(them._zoom == 0 and them._cam and math.abs(them._cam - J.BOSS_CAM) < 1e-9, "the camera, set AFTER it drew")
  H.ok(type(them._facing) == "number" and them._facing < 0 and type(you._facing) == "number" and you._facing > 0,
       "facing each other")
  run()
  H.eq(them._asks, 2, "drawn: no more asks")
  -- the right display: the note in big white type, then the data blocks
  H.ok(f.text._text == "first kill: Ragnaros" and (f.text._size or 0) >= 14 and glass(f.text._color, "white"), "the note, big and white")
  H.ok(strip(f.kind._text):find("BOSS", 1, true), "the kind above it", strip(f.kind._text))
  local want = { where = "Molten Core", lvl = "60", took = "4:10", file = nil }
  for k, v in pairs(want) do
    local row = f.data[k]
    H.ok(row and row.lab:IsShown() and glass(row.lab._color, "cyan") and strip(row.val._text):find(v, 1, true)
         and glass(row.val._color, "white"), "data block " .. k .. ": cyan label, white value", row and strip(row.val._text))
  end
  H.ok(f.data.with.lab:IsShown() and f.withBtns[1]:IsShown() and f.withBtns[1].who == "Kumlance Wildhammer", "WITH: the names")
  H.ok(f.data.file.lab:IsShown() and f.fileBox:IsShown() and f.fileBox._text == "WoWScrnShot_110826_201500", "FILE: ready to copy")
  H.ok(not f.data.from.lab:IsShown(), "a block with nothing to say is not drawn")
  fitsIn(f, "the cockpit, a boss open")
  -- a creature the client has drawn once this session: the first ask lands, the camera follows the check
  J.Select(nil)
  J.Select(boss)
  H.ok(them:GetModelFileID() > 0 and them._cam == nil, "known now: drawn at once - the camera still waits for the check")
  run()
  H.ok(them._asks == 1 and them._cam and them._anim == J.DEAD, "one ask, then the camera and the pose")
  -- no "dead" pose on this client: the death animation
  HARNESS.noAnim[J.DEAD] = true
  J.Select(nil) J.Select(boss) run()
  H.eq(them._anim, 1, "a client without the dead pose: the death animation instead")
  HARNESS.noAnim[J.DEAD] = nil
  -- the model by display id, when the note has one (ADVENT.EXE's creatures, TakeMemory's extra)
  boss.display = 7970
  J.Select(nil) J.Select(boss) run()
  H.ok(them._display == 7970 and them._creature == nil and them:GetModelFileID() > 0 and them._cam, "a note's display id: that model")
  boss.display = nil
  -- BiS Tools' Codex knows the model: used when the note has none; never required
  HARNESS.knownCreature[11502] = nil
  _G.BiSToolsAPI = { major = 1, version = 4, CodexCreature = function(id) return id == 11502 and { id = id, display = 555 } or nil end }
  J.Select(nil) J.Select(boss) run()
  H.ok(them._display == 555, "BiS Tools' Codex: its display for the creature", them._display)
  _G.BiSToolsAPI = { major = 1, CodexCreature = function() error("boom") end }
  J.Select(nil) J.Select(boss) run() run()
  H.ok(them._creature == 11502 and them:GetModelFileID() > 0, "a Codex that errors: the creature by its id")
  _G.BiSToolsAPI = nil
  -- a stale look: another memory chosen before the moment came does not touch the model
  -- painted while shut (a memory landing, /bism wow): the hidden model drew nothing - opening asks again
  J.Hide()
  J.sel = boss
  J.Refresh()
  HARNESS.knownCreature[11502] = true
  J.Show()
  H.ok(them:GetModelFileID() > 0, "painted while shut, then opened: the boss is asked again, on the screen")
  local other = { reason = "levelup", detail = "level 61", at = os.time() - 30, char = M.Me() }
  log[2] = other
  HARNESS.knownCreature[11502] = nil
  J.Select(boss)
  J.Select(other)
  local asks = them._asks
  run()
  H.ok(them._asks == asks and not them:IsShown(), "chosen something else meanwhile: the old look does nothing")
  -- whoever killed you stands over you - alive
  local death = { reason = "death", detail = "killed by Hogger", at = os.time() - 20, char = M.Me(), npc = 448 }
  log[3] = death
  J.Select(death) run() run()
  H.ok(them._creature == 448 and them._anim == 0 and them:GetModelFileID() > 0, "a killer stands")
  J.Hide()
  J.sel = nil

  H.section("8 Nov: the cockpit - the navigation display (the map, with a range knob)")
  wipe()
  _G.C_Map.GetMapArtLayers = function() return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end
  _G.C_Map.GetMapArtLayerTextures = function() local t = {} for i = 1, 12 do t[i] = 1000 + i end return t end
  _G.C_Map.GetMapRectOnMap = function(_, to) if to == 947 then return 0.4, 0.6, 0.3, 0.5 end end
  MV.rects = {}
  -- three memories a step apart in one zone (one box at the world's range), one across the map
  local near1 = { reason = "boss", detail = "a", at = 10, map = 1429, x = 0.50, y = 0.50, char = M.Me() }
  local near2 = { reason = "zone", detail = "b", at = 11, map = 1429, x = 0.52, y = 0.50, char = M.Me() }
  local near3 = { reason = "loot", detail = "c", at = 12, map = 1429, x = 0.54, y = 0.50, char = M.Me() }
  local far = { reason = "levelup", detail = "far away", at = 13, map = 1436, x = 0.5, y = 0.5, char = M.Me() }
  local realRect = _G.C_Map.GetMapRectOnMap
  _G.C_Map.GetMapRectOnMap = function(from, to)
    if to == 947 and from == 1429 then return 0.4, 0.6, 0.3, 0.5 end
    if to == 947 and from == 1436 then return 0.1, 0.2, 0.1, 0.2 end
  end
  log[1], log[2], log[3], log[4] = near1, near2, near3, far
  MV.rects = {}
  J.Show()
  f.tabs[2]:Click()
  local map = f.map
  local function pins()
    local out = {}
    for _, b in ipairs(map.dots or {}) do if b:IsShown() then out[#out + 1] = b end end
    return out
  end
  local function clusterPin() for _, b in ipairs(pins()) do if #b.members > 1 then return b end end end
  local function pinOf(e) for _, b in ipairs(pins()) do if #b.members == 1 and b.members[1].e == e then return b end end end
  H.eq(strip(f.knob.value._text), "1x", "it opens at the whole map: range 1x")
  H.ok(f.knob:IsShown() and f.rangeDown:IsShown() and f.rangeUp:IsShown() and not f.prev:IsShown(),
       "the soft keys under the display change with the page: the range knob, not PREV/NEXT")
  H.eq(#pins(), 2, "near pins merge: one box for the three, one for the far one")
  local c = clusterPin()
  H.ok(c and #c.members == 3 and strip(c.count._text) == "3" and c.count:IsShown(), "the merged box says how many")
  -- HOLLOW: four thin sides and a dark outline round them, nothing drawn in the middle
  local p = pinOf(far)
  H.ok(p and p.fill == nil and #p.sides == 4 and #p.shade == 4, "a pin is a hollow square: four sides, a dark outline")
  local thin = true
  for _, s in ipairs(p and p.sides or {}) do
    if math.min(s._w or 99, s._h or 99) > MV.THICK or s._all then thin = false end
  end
  H.ok(thin and p and p:GetWidth() >= 2 * MV.THICK + 4, "the sides are thin: the middle stays see-through")
  local rr, gg, bb = NS.T.rgb(MV.COLOUR.levelup)
  H.ok(p and near(p.sides[1]._color, rr, gg, bb), "in the memory's colour")
  -- the wheel zooms, around the cursor (put on the merged box), and stops at both ends
  local ux, uy = c.ux, c.uy
  local cx, cy = map:GetLeft() + ux, map:GetTop() - uy
  _G.GetCursorPosition = function() return cx, cy end
  local mx, my = MV.ToMap(map, ux, uy)
  map:Fire("OnMouseWheel", 1)
  H.eq(strip(f.knob.value._text), "2x", "the wheel up: closer, range 2x")
  local mx2, my2 = MV.ToMap(map, ux, uy)
  H.ok(math.abs(mx - mx2) < 1e-6 and math.abs(my - my2) < 1e-6, "the spot under the cursor stays under it",
       ("%.4f,%.4f -> %.4f,%.4f"):format(mx, my, mx2, my2))
  for _ = 1, 10 do map:Fire("OnMouseWheel", 1) end
  H.eq(strip(f.knob.value._text), MV.RANGES[#MV.ZOOMS], "no closer than the last range")
  H.ok(clusterPin() == nil and pinOf(near1) and pinOf(near2) and pinOf(near3),
       "close in: the merged box has split into its three memories")
  for _ = 1, 10 do map:Fire("OnMouseWheel", -1) end
  H.eq(strip(f.knob.value._text), "1x", "the wheel down: back out, no further than the whole map")
  H.eq(#pins(), 2, "and they merge again")
  f.rangeUp:Click()
  H.eq(strip(f.knob.value._text), "2x", "the + key")
  f.rangeDown:Click()
  H.eq(strip(f.knob.value._text), "1x", "the - key")
  f.knob:Fire("OnMouseWheel", 1)
  H.eq(strip(f.knob.value._text), "2x", "the wheel on the knob turns it")
  f.rangeDown:Click()
  -- the knob's ticks show where on its range it is
  local lit = 0
  for _, t in ipairs(f.knob.ticks) do if t:GetAlpha() == 1 then lit = lit + 1 end end
  H.ok(#f.knob.ticks == #MV.ZOOMS and lit == 1, "the knob's ticks: one lit at 1x", lit)
  -- a merged box, clicked: zoom in on it until it splits
  c = clusterPin()
  local tries = 0
  while c and tries < 6 do c:Click() tries = tries + 1 c = clusterPin() end
  H.ok(c == nil and MV.Zoomed(map) > 1, "clicking the merged box zooms in on it until its memories stand apart", tries)
  local p1 = pinOf(near1)
  H.ok(p1 and p1:IsShown(), "the memory it held is on the screen")
  -- a single pin, clicked: that memory opens on the right display; the map stays
  p1:Click()
  H.ok(J.sel == near1 and J.page == "map" and f.text._text == "a", "clicking a pin opens its memory on the right display")
  p1 = pinOf(near1)
  H.ok(p1 and glass(p1.sides[1]._color, "magenta") and p1:GetWidth() > pinOf(near2):GetWidth(),
       "the chosen pin: magenta, and bigger")
  p1:Fire("OnEnter")
  H.ok(theme(p1.sides[1]._color, "accent"), "a pin lights under the mouse")
  p1:Fire("OnLeave")
  H.ok(glass(p1.sides[1]._color, "magenta"), "and gives its colour back")
  -- drag pans; nothing runs once the button is up, or once the window is shut
  local v0x = map.view.cx
  map:Fire("OnMouseDown", "LeftButton")
  H.ok(map:GetScript("OnUpdate") ~= nil, "a drag follows the mouse while the button is down")
  cx = cx + 60
  map:Fire("OnUpdate", 0.016)
  H.ok(map.view.cx < v0x, "dragged right: the map moves with the hand", map.view.cx .. " < " .. v0x)
  cx = cx + 100000
  map:Fire("OnUpdate", 0.016)
  local half = MV.Half(map)
  H.ok(map.view.cx >= half - 1e-9, "never past the map's edge", map.view.cx .. " / " .. half)
  map:Fire("OnMouseUp", "LeftButton")
  H.eq(map:GetScript("OnUpdate"), nil, "the button up: nothing runs")
  map:Fire("OnMouseDown", "LeftButton")
  J.Hide()
  H.eq(map:GetScript("OnUpdate"), nil, "shut mid-drag: nothing runs")
  J.Show()
  fitsIn(f, "the cockpit, the navigation display")
  _G.GetCursorPosition = function() return 300, 400 end
  _G.C_Map.GetMapRectOnMap = realRect
  f.tabs[1]:Click()
  J.Hide()

  H.section("8 Nov: the cockpit - the memo line")
  wipe()
  for i = 1, 3 do log[i] = { reason = "zone", detail = "x" .. i, at = 50 + i, char = M.Me() } end
  J.Show()
  H.ok(strip(f.pathLabel._text) == "ALBUM" and glass(f.pathLabel._color, "cyan"), "a cyan ALBUM label")
  H.ok(f.pathBox._text:find("BiSMemories-Album.html", 1, true) and f.pathBox._color and glass(f.pathBox._color, "white"),
       "the path in white")
  H.ok(strip(f.count._text) == "3 kept" and glass(f.count._color, "green"), "the count in green")
  local tip = {}
  local realSetText, realAdd = GameTooltip.SetText, GameTooltip.AddLine
  GameTooltip.SetText = function(_, t) tip[#tip + 1] = strip(t) end
  GameTooltip.AddLine = function(_, t) tip[#tip + 1] = strip(t) end
  f.pathBox:Fire("OnEnter")
  GameTooltip.SetText, GameTooltip.AddLine = realSetText, realAdd
  H.ok(table.concat(tip, " "):find("Windows key + R", 1, true), "how to use it, in the tooltip (one bar, one label)")
  J.Hide()

  H.section("8 Nov: TakeMemory says which creature it was (API version 3)")
  local A = _G.BiSMemoriesAPI
  H.ok(A.version >= 3, "BiSMemoriesAPI version 3 or later", A.version)
  wipe()
  local got = A.TakeMemory("ADVENT.EXE: SKUM slain", "boss", "BiSShell",
                           { npc = 3674, display = 1234, detail = "hacked", reason = "loot", evil = true })
  H.ok(got and got.npc == 3674 and got.display == 1234, "the creature and its model are kept on the note")
  H.ok(got and got.detail == "ADVENT.EXE: SKUM slain" and got.reason == "boss" and got.evil == nil,
       "nothing else from the extra is taken")
  H.ok(log[1] and log[1].npc == 3674 and log[1].display == 1234, "in the album too")
  got.npc = 1
  H.eq(log[1].npc, 3674, "the answer is a copy")
  got = A.TakeMemory("odd numbers", "boss", "BiSShell", { npc = "3674", display = -5 })
  H.ok(got and got.npc == nil and got.display == nil, "a string or a negative number is not a creature")
  got = A.TakeMemory("half", "boss", nil, { npc = 2.5, display = 77 })
  H.ok(got and got.npc == nil and got.display == 77, "only whole numbers")
  got = A.TakeMemory("no extra", "boss", nil, "not a table")
  H.ok(got and got.npc == nil, "an extra that is no table: ignored")
  local secret = setmetatable({}, {})
  local keepSecret = _G.issecretvalue
  _G.issecretvalue = function(v) return rawequal(v, secret) end
  got = A.TakeMemory("hidden", "boss", nil, { npc = secret })
  _G.issecretvalue = keepSecret
  H.ok(got and got.npc == nil, "a hidden value is never read")
  -- KEEP THE INTERFACE IN (Arn, 8 Nov: ADVENT.EXE's boss picture "hid ui took a screenshot and brought everything
  -- back" - the game is ON the interface, so a clean shot photographs the world instead)
  local ui = _G.UIParent
  M.Clean(false)
  ui:SetAlpha(1)
  d.clean = true
  got = A.TakeMemory("ADVENT.EXE: the terminal in the picture", "boss", "BiSShell", { npc = 3674, keepUI = true })
  H.ok(got and ui:GetAlpha() == 1 and not M.uiHidden, "keepUI: the interface stays in the picture")
  H.ok(got and got.keepUI == nil and log[1].keepUI == nil and got.npc == 3674, "it is not kept on the note; the creature is")
  got = A.TakeMemory("a clean one", "boss", "BiSShell", { keepUI = "yes" })
  H.ok(got and ui:GetAlpha() == 0 and M.uiHidden, "without it (or anything but exactly true): a clean shot still hides it")
  M.Clean(false)
  run()
  H.eq(ui:GetAlpha(), 1, "and gives it back")
  local hdr = bytes(ROOT .. "/API.lua") or ""
  H.ok(hdr:find("TakeMemory(note, kind, from, extra)", 1, true) and hdr:find("since version 3", 1, true)
       and hdr:find("keepUI", 1, true), "the header documents it")

  H.section("8 Nov: the cockpit - lean")
  local Cost = dofile(ROOT .. "/../_bisdev/dev/cost.lua")
  wipe()
  for i = 1, 250 do
    log[i] = { reason = (i % 3 == 0) and "boss" or "zone", detail = "memory " .. i, at = 1000000 - i * 5000, zone = "Mulgore",
               char = M.Me(), map = 1429, x = (i % 17) / 17, y = (i % 13) / 13 }
  end
  MV.rects = {}
  J.Show()
  f.tabs[1]:Click()
  local n, by = Cost.Count(function() J.Turn(1) end)
  H.say(("   cost: the cockpit, turning a page of 250 memories = %d calls"):format(n))
  -- budgets a little above what was measured (8 Nov 2026): a page turn 0 (the frames are made once, M.Me is kept), a
  -- map repaint 0 (the art and the zone rectangles are kept after the first paint), a drag one cursor read a frame
  H.ok(n <= 5, "turning a page asks the client at most 5 things (measured " .. n .. ")", Cost.Top(by, 5))
  f.tabs[2]:Click()
  n, by = Cost.Count(function() MV.Zoom(f.map, 1) end)
  H.say(("   cost: the cockpit, a map repaint of 250 pins = %d calls"):format(n))
  H.ok(n <= 5, "a map repaint asks the client at most 5 things (measured " .. n .. ")", Cost.Top(by, 5))
  local hand = 300
  _G.GetCursorPosition = function() return hand, 400 end
  n, by = Cost.Count(function()
    f.map:Fire("OnMouseDown", "LeftButton")
    for i = 1, 60 do hand = 300 + i f.map:Fire("OnUpdate", 0.016) end
    f.map:Fire("OnMouseUp", "LeftButton")
  end)
  H.say(("   cost: the cockpit, a second of dragging the map = %d calls"):format(n))
  H.ok(n <= 70, "a second's drag (60 frames) stays in its budget (measured " .. n .. ")", Cost.Top(by, 5))
  -- a held button and a still hand: nothing repaints
  local paints = 0
  local realDraw = MV.Draw
  MV.Draw = function(...) paints = paints + 1 return realDraw(...) end
  f.map:Fire("OnMouseDown", "LeftButton")
  for _ = 1, 30 do f.map:Fire("OnUpdate", 0.016) end
  f.map:Fire("OnMouseUp", "LeftButton")
  MV.Draw = realDraw
  H.eq(paints, 0, "a still hand on the map repaints nothing")
  _G.GetCursorPosition = function() return 300, 400 end
  J.Hide()
  H.ok(f:GetScript("OnUpdate") == nil and f.map:GetScript("OnUpdate") == nil, "shut: nothing of the journal ticks")
  f.tabs[1]:Click()
  wipe()
  J.sel, J.page = nil, "memories"
  _G.C_Timer = keepTimer
end)()

-- ===================================================================== 8 Nov: the Clipper Lounge
-- Arn, 8 Nov 2026: "I'll give you free reign on the full screen version of bis memories ... works on any monitor size
-- ... think what fact people in the 50-70s would luxury in jetliners think outside the box" - and, on the mockup, "Go on
-- the clipper lounge". A 1960s jet's upper-deck lounge over the whole screen: a split-flap departure board of memories,
-- the chosen one through an oval cabin window, its boarding pass and note card, the seat-pocket route map, the flight
-- engineer's gauges, the call buttons. And (Arn, the same day): branded "BiS> Memories" wherever a picture could see it
-- - "they will look up bis clipper and nothing pops up".
;(function()
  local J, M, MV, L = NS.J, NS.M, NS.MapView, NS.Lounge
  H.section("8 Nov: the Clipper Lounge - it is there")
  H.ok(type(L) == "table" and type(L.Show) == "function", "the lounge is loaded (Core/Lounge.lua, ns.Lounge)")
  if type(L) ~= "table" then return end
  local Cost = dofile(ROOT .. "/../_bisdev/dev/cost.lua")
  local d = NS.DB()
  local log = M.Log()
  local function wipe() for k = #log, 1, -1 do log[k] = nil end end
  local function near(c, r, g, b)
    return type(c) == "table" and math.abs(c[1] - r) < 0.01 and math.abs(c[2] - g) < 0.01 and math.abs(c[3] - b) < 0.01
  end
  local function hue(c, name) return near(c, L.Rgb(name)) end
  local q = {}
  local keepTimer = _G.C_Timer
  _G.C_Timer = { After = function(t, fn) q[#q + 1] = { t = t, fn = fn } end }
  local function run() local t = q q = {} for _, x in ipairs(t) do x.fn() end return #t end
  local keepW, keepH = UIParent._w, UIParent._h
  local keepMap, keepColours, keepPhoto = _G.C_Map, _G.RAID_CLASS_COLORS, M.GroupPhoto
  math.randomseed(8)
  d.gap, d.delay = 0, 0
  M.me = nil
  J.everyone, J.sel, J.page = nil, nil, "memories"
  J.Hide()
  _G.RAID_CLASS_COLORS = { SHAMAN = { r = 0, g = 0.44, b = 0.87 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 },
                           PRIEST = { r = 1, g = 1, b = 1 }, DRUID = { r = 1, g = 0.49, b = 0.04 } }
  -- a world map with art, and four zones on it
  local rects = { [1456] = { 0.30, 0.40, 0.30, 0.40 }, [1429] = { 0.45, 0.55, 0.60, 0.70 },
                  [1413] = { 0.50, 0.60, 0.40, 0.50 }, [1412] = { 0.30, 0.40, 0.45, 0.55 } }
  _G.C_Map = {
    GetBestMapForUnit = function() return 1412 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
    GetMapArtLayers = function() return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end,
    GetMapArtLayerTextures = function() local t = {} for i = 1, 12 do t[i] = 1000 + i end return t end,
    GetMapRectOnMap = function(from, to) local r = to == 947 and rects[from] if r then return r[1], r[2], r[3], r[4] end end,
  }
  MV.rects, MV.pieces, MV.zoneIDs = {}, {}, nil
  -- TWELVE MEMORIES, newest first, the way the camera writes them
  local me = M.Me()
  local T0 = os.time({ year = 2026, month = 11, day = 7, hour = 23, min = 40, sec = 0 })
  local function at(i) return T0 - i * 600 end
  wipe()
  local E = {
    { reason = "levelup", detail = "level 23", zone = "Thunder Bluff", level = 23, map = 1456, x = 0.5, y = 0.5 },
    { reason = "boss", detail = "first kill: Lady Anacondra", zone = "Wailing Caverns - Screaming Gully", level = 22,
      npc = 3671, secs = 27, file = "WoWScrnShot_110726_233212", class = "SHAMAN", race = "Tauren",
      with = { "Acido Wildhammer", "Macready", "Bologna", "Qazo" }, withClass = { "SHAMAN", "MAGE", "PRIEST", "DRUID" } },
    { reason = "boss", detail = "Mutanus the Devourer - fastest yet, 1:02", zone = "Wailing Caverns", level = 22, npc = 3654 },
    { reason = "death", detail = "killed by Hogger", zone = "Elwynn Forest", level = 21, npc = 448, map = 1429, x = 0.5, y = 0.5 },
    { reason = "zone", detail = "The Barrens", zone = "The Barrens", level = 20, map = 1413, x = 0.5, y = 0.5 },
    { reason = "loot", detail = "|cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r",
      zone = "Ragefire Chasm", level = 20 },
    { reason = "boss", detail = "ADVENT.EXE: Taragaman slain", zone = "Ragefire Chasm", level = 19, from = "BiSShell" },
  }
  for i = 1, 5 do
    E[#E + 1] = { reason = "levelup", detail = "level " .. (19 - i), zone = "Mulgore", level = 19 - i, map = 1412,
                  x = 0.15 * i, y = 0.2 + 0.1 * i }
  end
  for i, e in ipairs(E) do e.at, e.char = at(i), me log[i] = e end
  local boss = E[2]

  H.section("8 Nov: the Clipper Lounge - full screen, 16:9, any monitor")
  local SIZES = { { 1024, 768 }, { 1920, 1080 }, { 3440, 1440 }, { 1280, 1024 }, { 1188, 668 } }
  for _, sz in ipairs(SIZES) do
    local w, h = sz[1], sz[2]
    UIParent._w, UIParent._h = w, h
    H.ok(L.Show() == true, ("%dx%d: it opens"):format(w, h))
    local back, room = L.back, L.room
    local k = room:GetScale()
    H.ok(back:IsShown() and back._all and back._parent == UIParent, ("%dx%d: a backdrop over the whole screen"):format(w, h))
    H.eq(back:GetFrameStrata(), "FULLSCREEN_DIALOG", "on top of everything")
    H.ok(math.abs(room:GetWidth() / room:GetHeight() - 16 / 9) < 0.005, "the lounge is 16:9",
         room:GetWidth() .. "x" .. room:GetHeight())
    local sw, sh = room:GetWidth() * k, room:GetHeight() * k
    H.ok(sw <= w + 0.01 and sh <= h + 0.01, ("%dx%d: the whole lounge is on the screen"):format(w, h), ("%.0fx%.0f"):format(sw, sh))
    H.ok(sw >= w * 0.95 or sh >= h * 0.95, ("%dx%d: as large as fits"):format(w, h), ("%.0fx%.0f"):format(sw, sh))
    -- every part inside the lounge
    local outside = {}
    for name, p in pairs(L.parts) do
      local x, y = p:OffsetFor("TOPLEFT")
      if not x or x < -0.01 or -y < -0.01 or x + p:GetWidth() > room:GetWidth() + 0.01 or -y + p:GetHeight() > room:GetHeight() + 0.01 then
        outside[#outside + 1] = name
      end
    end
    H.ok(#outside == 0, ("%dx%d: every part of it inside the lounge"):format(w, h), table.concat(outside, ", "))
    -- no word smaller than the least a person can read
    local small, n = {}, 0
    for _, fs in ipairs(H.labels) do
      if fs._shown ~= false and fs._text ~= "" and insideShown(fs, room) then
        n = n + 1
        if (fs._size or 0) * k < L.MIN_FONT - 0.01 then small[#small + 1] = ("%q %.1f"):format(strip(fs._text), fs._size * k) end
      end
    end
    H.ok(n > 300 and #small == 0, ("%dx%d: no word smaller than %d on the screen (%d measured)"):format(w, h, L.MIN_FONT, n),
         table.concat(small, ", "))
    fitsIn(room, ("the lounge at %dx%d"):format(w, h))
    L.Hide()
  end
  UIParent._w, UIParent._h = keepW, keepH
  H.ok(L.MIN_FONT >= 9, "the least font is 9", L.MIN_FONT)

  H.section("8 Nov: the Clipper Lounge - the departure board")
  J.sel = nil
  L.Show()
  local B = L.board
  local function cell(r, col)
    local t = {}
    for _, tile in ipairs(B.rows[r].tiles[col]) do t[#t + 1] = tile.want end
    return (table.concat(t):gsub("%s+$", ""))
  end
  local function shown(r, col)
    local t = {}
    for _, tile in ipairs(B.rows[r].tiles[col]) do t[#t + 1] = tile.fs._text end
    return (table.concat(t):gsub("%s+$", ""))
  end
  local function settle() for _ = 1, 200 do if not B:GetScript("OnUpdate") then return end B:Fire("OnUpdate", 0.02) end end
  settle()
  H.eq(J.sel, E[1], "it opens on the newest memory, chosen")
  H.eq(#B.rows, L.ROWS, "a page is " .. L.ROWS .. " flights")
  H.ok(L.ROWS >= 5, "at least five a page")
  H.eq(cell(1, 1), os.date("%H:%M", E[1].at), "TIME: when")
  H.eq(cell(1, 2), "LVL 6", "FLIGHT: the kind's code and its number, counted from the first (the 6th level up)")
  H.eq(cell(2, 2), "BOS 3", "a boss is BOS (the 3rd)")
  H.eq(cell(3, 2), "BOS 2", "and the one before it BOS 2")
  H.eq(cell(4, 2), "DTH 1", "a death DTH")
  H.eq(cell(5, 2), "PLC 1", "a new place PLC")
  H.eq(cell(2, 3), "LADY ANACONDRA", "DESTINATION: what it was, in capitals, without 'first kill:'")
  H.eq(cell(2, 4), "WAILING CAV", "GATE: the zone, short")
  H.eq(cell(1, 4), "THUNDER BLU", "cut to the gate's tiles")
  H.eq(cell(1, 5), "BOARDING", "REMARKS: the chosen one is BOARDING")
  H.eq(cell(2, 5), "FIRST KILL", "a first kill")
  H.eq(cell(3, 5), "FASTEST", "the fastest yet")
  H.eq(cell(3, 3), "MUTANUS THE DEVOURER", "and its name without the time")
  H.ok(cell(4, 5) ~= "" and cell(5, 5) ~= "", "every flight has a remark", cell(4, 5) .. "/" .. cell(5, 5))
  H.ok(shown(2, 3) == cell(2, 3), "settled: the tiles show the words")
  -- split-flap tiles: one dark tile per character with a seam across the middle
  local tile = B.rows[2].tiles[3][1]
  H.ok(tile.bg and tile.top and tile.seam and tile.fs and hue(tile.bg._color, "flapBot") and hue(tile.seam._color, "seam"),
       "a tile: dark, with its seam")
  H.ok((tile.seam._h or 9) <= 3 and tile.top._h and tile.bg._h and math.abs(tile.top._h / tile.bg._h - 0.49) < 0.02,
       "the seam thin, across the middle")
  H.ok(strip(tile.fs._text) == "L" and tile.fs._font == L.FONT.flap, "one letter a tile, in the board's face")
  -- colours: the chosen row sun-yellow, the remarks tangerine, the rest the tiles' ink
  H.ok(hue(B.rows[1].tiles[3][1].fs._color, "sun"), "the chosen row in sun-yellow")
  H.ok(hue(B.rows[2].tiles[3][1].fs._color, "flapink"), "the others in the tiles' cream")
  H.ok(hue(B.rows[2].tiles[5][1].fs._color, "tangerine"), "remarks in tangerine")
  H.ok(strip(L.pageLabel._text):find("PAGE 1 OF 3", 1, true), "the page, and how many", strip(L.pageLabel._text))
  H.ok(strip(L.pageLabel._text):find("BiS> MEMORIES", 1, true), "the board says whose it is: BiS> Memories")
  -- turn the page: the letters clatter once, then sit still
  local spy = 0
  for _, row in ipairs(B.rows) do
    for _, col in ipairs(row.tiles) do
      for _, t in ipairs(col) do
        local real = t.fs.SetText
        t.fs.SetText = function(self, v) spy = spy + 1 return real(self, v) end
      end
    end
  end
  H.eq(B:GetScript("OnUpdate"), nil, "nothing runs while the board stands still")
  L.keys.earlier:Click()
  H.eq(L.pageNo, 2, "the earlier key: the page of older memories")
  H.ok(B:GetScript("OnUpdate") ~= nil, "a page turn starts the flip")
  local moving = 0
  for r = 1, L.ROWS do if shown(r, 3) ~= cell(r, 3) then moving = moving + 1 end end
  H.ok(moving > 0, "the letters are flapping", moving)
  local frames, n, by = 0, nil, nil
  n, by = Cost.Count(function()
    while B:GetScript("OnUpdate") and frames < 300 do B:Fire("OnUpdate", 1 / 60) frames = frames + 1 end
  end)
  H.ok(frames > 5 and frames / 60 <= L.FlipLongest() + 0.05 and L.FlipLongest() <= 1.0,
       "the flip is over within a second, and removes itself", frames .. " frames, " .. L.FlipLongest())
  H.eq(B:GetScript("OnUpdate"), nil, "then nothing runs")
  local still = true
  for r = 1, L.ROWS do for c = 1, #L.TILES do if shown(r, c) ~= cell(r, c) then still = false end end end
  H.ok(still, "and every tile shows its letter")
  H.eq(cell(2, 2), "BOS 1", "page 2: the oldest boss is BOS 1 (the ADVENT one, 7th newest)")
  H.eq(cell(2, 5), "ADVENT", "a BiS Shell game's memory: its game in the remarks")
  H.eq(cell(1, 3), ("THUNDERFURY, BLESSED BLADE OF THE WINDSEEKER"):sub(1, L.TILES[3]):gsub("%s+$", ""), "an item: its name, no link codes, cut to the tiles")
  H.say(("   cost: a page turn's flip = %d client calls, %d tile letters set"):format(n, spy))
  -- budgets (8 Nov 2026): measured 0 calls (the flip asks the client nothing - it counts its own elapsed time) and
  -- about 1,900 letters set for two pages of flapping tiles; a flip is once per page turn and lasts under a second
  H.ok(n <= 2, "a flip asks the client at most 2 things (measured " .. n .. ")", Cost.Top(by, 5))
  H.ok(spy <= L.FLIP_BUDGET and L.FLIP_BUDGET <= 2500, "a flip sets at most " .. L.FLIP_BUDGET .. " letters (measured " .. spy .. ")")
  -- the wheel turns the board too; the later key turns back; the ends stop
  B:Fire("OnMouseWheel", -1)
  H.eq(L.pageNo, 3, "the wheel down: older")
  settle()
  L.keys.earlier:Click()
  H.eq(L.pageNo, 3, "no page past the oldest")
  settle()
  L.keys.later:Click() settle() L.keys.later:Click() settle() L.keys.later:Click() settle()
  H.eq(L.pageNo, 1, "the later key back to the newest, and no further")
  -- a hidden board stops mid-flip with every letter in place
  L.keys.earlier:Click()
  L.Hide()
  H.eq(B:GetScript("OnUpdate"), nil, "shut mid-flip: nothing runs")
  still = true
  for r = 1, L.ROWS do for c = 1, #L.TILES do if shown(r, c) ~= cell(r, c) then still = false end end end
  H.ok(still, "and the board shows its words for next time")
  L.Show()
  settle()
  -- click a flight: it is chosen
  L.Turn(-9)
  settle()
  B.rows[2]:Click()
  H.eq(J.sel, boss, "clicking a flight chooses it")
  H.eq(B:GetScript("OnUpdate"), nil, "choosing on the same page flips nothing")
  H.eq(cell(2, 5), "BOARDING", "it is BOARDING now")
  H.eq(cell(1, 5), "ON TIME", "and the one before is back to its own remark")
  H.ok(hue(B.rows[2].tiles[3][1].fs._color, "sun") and hue(B.rows[1].tiles[3][1].fs._color, "flapink"), "sun-yellow moved with it")

  H.section("8 Nov: the Clipper Lounge - the window seat")
  local S, P = L.seat, L.post
  H.ok(S:DoesClipChildren(), "the window's box cuts whatever reaches past it")
  H.ok(P.you._parent and P.you:IsVisible() and P.you._unit == "player", "you, in the window")
  H.ok(P.them:IsShown() and P.them._creature == 3671, "the boss, beside you")
  for _, m in ipairs({ P.you, P.them }) do
    local inside = true
    for _, p in ipairs(m._points or {}) do
      if math.abs(p.x) + (m._w or 0) > S:GetWidth() + 0.01 or math.abs(p.y) + (m._h or 0) > S:GetHeight() + 0.01 then inside = false end
    end
    H.ok(inside and (m._w or 0) <= S:GetWidth() and (m._h or 0) <= S:GetHeight(), "a model sized inside the window")
  end
  run() run()
  H.eq(P.them._anim, J.DEAD, "the boss lies dead (the journal's own look, J.Look)")
  H.ok(P.them._cam and P.them:GetModelFileID() > 0, "drawn, its camera set after")
  H.ok(L.surround:GetFrameLevel() > S:GetFrameLevel() + 2 and tostring(L.surround.art._texture):find("Media\\window", 1, true),
       "our own window surround over the models, covering the corners")
  local sky = L.sky
  H.ok(#sky >= 12, "a sky in bands", #sky)
  local top, low = sky[1]._color, nil
  for _, band in ipairs(sky) do if not band.ground then low = band._color end end
  H.ok(top and top[3] > top[1] and low and low[1] > low[3], "dusk: blue above, tangerine at the horizon")
  H.ok(sky[#sky].ground and sky[#sky]._color[1] < 0.5, "and the ground below it")
  H.ok(L.shade and L.shade:IsShown() and (L.shade._h or 0) > 0 and (L.shade._h or 0) < S:GetHeight() * 0.2,
       "the shade pulled down a little at the top")
  H.ok(strip(L.winLabel._text):find("WINDOW SEAT", 1, true) and strip(L.winLabel._text):find(os.date("%H:%M", boss.at), 1, true),
       "WINDOW SEAT and the time under it")
  -- the journal's postcard and the lounge's are the same function: each its own models, one asking once
  local asks = P.them._asks
  L.Select(boss)
  H.eq(P.them._asks, asks, "the same memory again: not asked again")

  H.section("8 Nov: the Clipper Lounge - the boarding pass")
  local pass = L.pass
  local function txt(fs) return strip(fs._text or "") end
  H.eq(txt(pass.brand), "BiS> MEMORIES", "the pass says BiS> Memories - the addon's own name, findable")
  H.ok(txt(pass.title):find("BOARDING PASS", 1, true), "BOARDING PASS")
  H.eq(txt(pass.toCode), "WC", "TO: the zone's code")
  H.ok(txt(pass.toName):find("WAILING CAVERNS", 1, true), "and its name")
  H.eq(txt(pass.fromCode), "WC", "FROM: where the memory before it was (Mutanus, the same cave)")
  H.eq(txt(pass.grid.passenger.val), "KUMLUST", "PASSENGER: the character")
  H.eq(txt(pass.grid.flight.val), "BOS 3", "FLIGHT")
  H.eq(txt(pass.grid.seat.val), "LVL 22", "SEAT: the level")
  H.eq(txt(pass.grid.date.val), os.date("%d %b", boss.at):upper(), "DATE")
  H.eq(txt(pass.grid.party.val), "4", "PARTY: how many with you")
  H.ok(txt(pass.kind) == "BOSS" and txt(pass.stamp) == "BiS> Memories", "the stub: the kind, and BiS> Memories stamped on it")
  H.ok(txt(pass.file):find("WoWScrnShot", 1, true) and txt(pass.file):find("233212", 1, true), "the picture's file name on the stub")
  local bars = 0
  for _, b in ipairs(pass.bars) do if b:IsShown() then bars = bars + 1 end end
  H.ok(bars >= 15, "drawn barcode stripes", bars)
  H.ok(pass.frame._parent == L.room and pass.frame:GetWidth() > 0, "the ticket is its own frame (Lounge.Pass) - a share card can draw it alone")
  -- the fields come from ONE place, so a share card can swap the names
  local plain = L.PassFields(boss, J.Entries())
  local private = L.PassFields(boss, J.Entries(), { private = true })
  H.eq(plain.passenger, "KUMLUST", "PassFields: the passenger")
  H.ok(private.passenger == "A TAUREN SHAMAN" and private.party == "4", "private: a Tauren Shaman, no name", private.passenger)
  local cardP = L.CardFields(boss, { private = true })
  H.ok(not strip(cardP.line):find("Acido", 1, true) and strip(cardP.line):find("4 friends", 1, true), "private: '4 friends'", cardP.line)
  local fresh = L.Pass(UIParent)
  fresh:Paint(private)
  H.eq(txt(fresh.grid.passenger.val), "A TAUREN SHAMAN", "a second ticket, drawn alone, from the same fields")
  fresh.frame:Hide()

  H.section("8 Nov: the Clipper Lounge - the note card, the sign")
  H.eq(txt(L.card.title), "Lady Anacondra · first kill", "the title, big")
  local line = L.card.line._text
  H.ok(strip(line):find("Screaming Gully", 1, true) and strip(line):find("0:27", 1, true), "where, and how long it took", strip(line))
  H.ok(line:find("|cff0070dd", 1, true) and strip(line):find("Acido Wildhammer", 1, true), "who with, in their class colours", line)
  H.ok((L.card.title._size or 0) > (L.card.line._size or 0) * 1.4, "the title much bigger than the line")
  H.ok(txt(L.sign.text):find("FASTEN SEATBELT", 1, true) and txt(L.sign.text):find(os.date("%d %b", boss.at):upper(), 1, true),
       "the lit sign: FASTEN SEATBELT and the memory's date")

  H.section("8 Nov: the Clipper Lounge - the call buttons")
  L.call.earlier:Click()
  H.eq(J.sel, E[3], "EARLIER: the memory before")
  L.call.later:Click()
  H.eq(J.sel, boss, "LATER: back")
  L.Select(E[5]) settle()
  L.call.earlier:Click() settle()
  H.ok(J.sel == E[6] and L.pageNo == 2, "EARLIER past the page's foot turns the page", L.pageNo)
  L.Select(E[#E]) settle()
  L.call.earlier:Click()
  H.eq(J.sel, E[#E], "EARLIER at the oldest: stays")
  H.ok(L.call.earlier.popIf and not L.call.earlier:popIf(), "and does not light up (nothing to go to)")
  local photo = 0
  M.GroupPhoto = function() photo = photo + 1 return true end
  L.call.photo:Click()
  H.eq(photo, 1, "GROUP PHOTO calls one")
  M.GroupPhoto = keepPhoto
  L.Select(boss) settle()
  L.call.journal:Click()
  H.ok(not L.back:IsShown() and J.frame:IsShown() and J.sel == boss, "JOURNAL: back to the windowed journal, on the same memory")
  J.Hide()

  H.section("8 Nov: the Clipper Lounge - the seat-pocket route map")
  L.Show() settle()
  local map = L.map
  local tiles = 0
  for _, t in ipairs(map.tiles or {}) do
    if t:IsShown() then
      tiles = tiles + 1
      H.ok(t._desat == true and t._vertex and t._vertex[1] > t._vertex[3], "a map tile on paper colours") break
    end
  end
  H.ok(tiles > 0, "the map's own art")
  local A = L.arcs
  H.ok(#A >= 5, "arcs join the memories on the map", #A)
  local ordered = true
  for i, a in ipairs(A) do
    if not (a.from.at < a.to.at) then ordered = false end
    if i > 1 and A[i - 1].to ~= a.from then ordered = false end
  end
  H.ok(ordered, "in time order, each from where the last one ended")
  local a1 = A[1]
  local dashes, painted = 0, true
  for _, ln in ipairs(a1 and a1.lines or {}) do
    dashes = dashes + 1
    if not (ln._line and ln._vertex and ln._from and ln._to and not ln._drawsNothing and hue(ln._vertex, "sky")) then painted = false end
  end
  H.ok(dashes >= 3 and dashes == L.DASHES and painted, "an arc is short sky-blue dashes (Lines)", dashes)
  local sx, sy = MV.ToScreen(map, MV.Dots({ a1.from }, 947)[1].x, MV.Dots({ a1.from }, 947)[1].y)
  local f1 = a1.lines[1]._from
  H.ok(math.abs(f1.x - sx) < 0.5 and math.abs(-f1.y - sy) < 0.5 and f1.rel == map.canvas, "it starts on the earlier memory's pin")
  local chosenPin
  for _, b in ipairs(map.dots or {}) do
    if b:IsShown() and #b.members == 1 and b.members[1].e == J.sel then chosenPin = b end
  end
  L.Select(E[1]) settle()
  for _, b in ipairs(map.dots or {}) do
    if b:IsShown() and #b.members == 1 and b.members[1].e == E[1] then chosenPin = b end
  end
  H.ok(chosenPin and hue(chosenPin.sides[1]._color, "sky") and chosenPin:GetWidth() >= MV.SEL, "the chosen memory's pin: sky blue, bigger")
  local other
  for _, b in ipairs(map.dots or {}) do if b:IsShown() and b ~= chosenPin and #b.members == 1 then other = b end end
  H.ok(other and hue(other.sides[1]._color, "tangerine"), "the others tangerine")
  L.zoomIn:Click()
  H.eq(map.view.z, 2, "the + key zooms in")
  map:Fire("OnMouseWheel", 1)
  H.eq(map.view.z, 3, "the wheel too")
  L.zoomOut:Click() L.zoomOut:Click()
  H.eq(map.view.z, 1, "the - key out")
  other:Click()
  H.ok(J.sel == other.members[1].e and txt(L.card.title) ~= "", "clicking a pin chooses that memory")

  H.section("8 Nov: the Clipper Lounge - the flight engineer's gauges")
  L.Hide()
  local counts = L.Counts(J.Entries())
  H.ok(counts.bosses == 3 and counts.deaths == 1 and counts.kept == #E and counts.places >= 6, "the counts",
       ("%d %d %d %d"):format(counts.bosses, counts.deaths, counts.kept, counts.places))
  L.Show()
  local G = L.gauges
  H.eq(#G, 5, "five gauges")
  local names = {}
  for _, g in ipairs(G) do names[#names + 1] = txt(g.label) end
  H.eq(table.concat(names, " "), "BOSSES LEVEL PLACES DEATHS KEPT", "BOSSES, LEVEL, PLACES, DEATHS, KEPT")
  H.ok(txt(G[1].num) == "3" and txt(G[4].num) == "1" and txt(G[5].num) == tostring(#E), "the number under each needle")
  H.ok(tostring(G[1].face._texture):find("Media\\disc", 1, true) and tostring(G[1].bezel._texture):find("Media\\ring", 1, true),
       "a round face and bezel, our own art")
  H.ok(#G[1].arc >= 8, "a scale arc", #G[1].arc)
  local fe = L.fe
  H.ok(fe:GetScript("OnUpdate") ~= nil, "opening swings the needles")
  local n0 = G[1].needle._to
  local swing = 0
  n, by = Cost.Count(function()
    while fe:GetScript("OnUpdate") and swing < 200 do fe:Fire("OnUpdate", 1 / 60) swing = swing + 1 end
  end)
  H.ok(swing / 60 <= L.SWING + 0.05 and swing > 10, "the swing lasts " .. L.SWING .. " s, then removes itself", swing)
  H.eq(fe:GetScript("OnUpdate"), nil, "then nothing runs")
  H.ok(n <= 2, "the swing asks the client at most 2 things (measured " .. n .. ")", Cost.Top(by, 5))
  local function angleOf(g) local t = g.needle._to return math.atan2(t.y, t.x) end
  for _, g in ipairs(G) do
    H.ok(math.abs(angleOf(g) - L.Angle(g.value / g.max)) < 1e-6, g.key .. ": the needle at its value",
         ("%.3f vs %.3f"):format(angleOf(g), L.Angle(g.value / g.max)))
    H.ok(g.needle._line and not g.needle._drawsNothing and g.needle._vertex, g.key .. ": a needle drawn as a Line")
  end
  H.ok(n0 ~= nil, "the needle had a start")

  H.section("8 Nov: the Clipper Lounge - everything clickable pops")
  local function pops(b, what, overText)
    local enter = b and b:GetScript("OnEnter")
    H.ok(enter ~= nil, what .. ": answers the mouse")
    if not enter then return end
    b:Fire("OnEnter")
    local wash, bar = b.wash, b.bar
    local a = wash and wash:GetAlpha() or 0
    H.ok(a >= (overText and 0.2 or 0.3) and a <= (overText and 0.28 or 0.35), what .. ": a clear wash under the mouse", a)
    H.ok(wash and near(wash._color, NS.T.rgb("accent")), what .. ": the wash is the accent")
    H.ok(bar and bar:GetAlpha() == 1 and (bar._w or 0) >= 2 and (bar._w or 0) <= 3, what .. ": a 2-3 px bar lit", bar and bar._w)
    b:Fire("OnLeave")
    H.ok(wash and wash:GetAlpha() == 0 and bar and bar:GetAlpha() == 0, what .. ": and dark again when the mouse leaves")
  end
  pops(B.rows[1], "a flight on the board", true)
  pops(L.keys.earlier, "the board's earlier key")
  pops(L.keys.later, "the board's later key")
  pops(L.keys.close, "the X")
  L.Select(boss)
  pops(L.call.earlier, "EARLIER")
  pops(L.call.later, "LATER")
  pops(L.call.photo, "GROUP PHOTO")
  pops(L.call.journal, "JOURNAL")
  pops(L.zoomIn, "the map's +")
  pops(L.zoomOut, "the map's -")
  local f = J.Build()
  pops(f.lounge, "the journal's LOUNGE key")
  H.eq(strip(f.lounge.word._text), "LOUNGE", "the journal has a LOUNGE key")

  H.section("8 Nov: the Clipper Lounge - in and out")
  L.Hide()
  J.Show()
  f.lounge:Click()
  H.ok(L.back:IsShown() and not J.frame:IsShown(), "the journal's LOUNGE key: full screen, the window put away")
  L.keys.close:Click()
  H.ok(not L.back:IsShown(), "X shuts it")
  NS.Slash("lounge")
  H.ok(L.back:IsShown(), "/bism lounge opens it")
  NS.Slash("lounge")
  H.ok(not L.back:IsShown(), "and again shuts it")
  NS.Slash(NS.SHORT.lounge or "lounge")
  H.ok(NS.SHORT.lounge and #NS.SHORT.lounge <= 4 and L.back:IsShown(), "/bism " .. tostring(NS.SHORT.lounge) .. " too")
  local said0 = #said
  NS.Slash("help")
  H.ok(table.concat(said, " ", said0 + 1):find("lounge (" .. tostring(NS.SHORT.lounge) .. ")", 1, true), "the help lists it")
  -- ESCAPE: the client hides each shown UISpecialFrames frame with a bare :Hide() - only OnHide runs
  local listed = false
  for _, nm in ipairs(_G.UISpecialFrames) do if nm == "BiSMemoriesLounge" then listed = true end end
  H.ok(listed and _G.BiSMemoriesLounge == L.back, "Escape knows the lounge")
  L.Turn(1)                                       -- a flip running
  map:Fire("OnMouseDown", "LeftButton")           -- a drag in hand
  H.ok(B:GetScript("OnUpdate") and fe:GetScript("OnUpdate") and map:GetScript("OnUpdate"), "flip, needles and a drag all running")
  for _, nm in ipairs(_G.UISpecialFrames) do local fr = _G[nm] if fr and fr:IsShown() then fr:Hide() end end
  H.ok(not L.back:IsShown(), "Escape shuts it")
  -- NOTHING TICKS WHILE HIDDEN: every frame of the lounge
  local ticking = {}
  for _, fr in ipairs(H.frames) do
    local p, mine = fr, false
    while p do if p == L.back then mine = true break end p = p._parent end
    if mine and fr:GetScript("OnUpdate") then ticking[#ticking + 1] = tostring(fr._type) end
  end
  H.ok(#ticking == 0, "shut: nothing of the lounge ticks", table.concat(ticking, ", "))
  H.ok(L.post.postFor == nil, "and the window is asked afresh next time (a hidden model loads nothing)")
  -- A FIGHT: shut at once, and not opened in one
  L.Show()
  H.ok(L.back._events.PLAYER_REGEN_DISABLED, "while open it listens for a fight")
  said0 = #said
  fire("PLAYER_REGEN_DISABLED")
  H.ok(not L.back:IsShown(), "a fight shuts it at once")
  H.ok(not L.back._events.PLAYER_REGEN_DISABLED, "shut: it listens for nothing")
  _G.InCombatLockdown = function() return true end
  H.ok(L.Show() == false and not L.back:IsShown(), "in a fight it does not open")
  H.ok(#said > said0, "and says why")
  _G.InCombatLockdown = nil

  H.section("8 Nov: the Clipper Lounge - lean")
  local nO, byO = Cost.Count(function() L.Show() end)
  H.say(("   cost: opening the lounge on 12 memories = %d client calls"):format(nO))
  -- budget (8 Nov 2026): measured on opening - the map's art and rectangles (kept after), the player's level, the
  -- date; opened by hand, once
  H.ok(nO <= L.OPEN_BUDGET, "opening asks the client at most " .. L.OPEN_BUDGET .. " things (measured " .. nO .. ")", Cost.Top(byO, 6))
  local nM, byM = Cost.Count(function() MV.Zoom(map, 1) end)
  H.ok(nM <= 5, "a map repaint with its arcs asks at most 5 things (measured " .. nM .. ")", Cost.Top(byM, 5))
  local nT, byT = Cost.Count(function() L.Select(E[3]) end)
  H.ok(nT <= 10, "choosing a flight asks at most 10 things (measured " .. nT .. ")", Cost.Top(byT, 5))
  L.Hide()
  local nH = Cost.Count(function() for _ = 1, 60 do M.OnEvent("CHAT_MSG_SYSTEM", "Kumlance has come online.") end end)
  H.ok(nH <= 120, "shut, the lounge adds nothing to the game's events", nH)

  wipe()
  J.sel, J.page, J.everyone = nil, "memories", nil
  _G.C_Map, _G.RAID_CLASS_COLORS = keepMap, keepColours
  MV.rects, MV.pieces = {}, {}
  _G.C_Timer = keepTimer
end)()

-- ===================================================================== 8 Nov: the share card
-- Arn, 8 Nov 2026: "maybe a way to save to social media? ... save to a file on their computer of only the ticket stub
-- thing ... they go on twitter and they can upload their dungeon clear or boss taken down maybe all the loot that
-- dropped all the party they were in option for privacy if they don't want to share in game name" - "API it too for
-- other addons" - and on the mockup: "Just say post it anywhere, sure keep name hidden". The boarding pass BIG and ALONE
-- on the lounge's teal, the rest of the interface out of the way, one picture - and the album page cuts the ticket out.
;(function()
  local J, M, L, S, A = NS.J, NS.M, NS.Lounge, NS.Share, _G.BiSMemoriesAPI
  H.section("8 Nov: the share card - it is there")
  H.ok(type(S) == "table" and type(S.Take) == "function", "the share card is loaded (Core/Share.lua, ns.Share)")
  if type(S) ~= "table" then return end
  local Cost = dofile(ROOT .. "/../_bisdev/dev/cost.lua")
  local d = NS.DB()
  local log = M.Log()
  local function wipe() for k = #log, 1, -1 do log[k] = nil end end
  local q = {}
  local keepTimer, keepShot, keepClass, keepRace = _G.C_Timer, _G.Screenshot, _G.UnitClass, _G.UnitRace
  local keepW, keepH, keepTime = UIParent._w, UIParent._h, _G.GetTime
  _G.C_Timer = { After = function(t, fn) q[#q + 1] = { t = t, fn = fn } end }
  local function run() local t = q q = {} for _, x in ipairs(t) do x.fn() end return #t end
  local function settle(n) for _ = 1, n or 40 do if run() == 0 then return end end end
  local snaps = {}
  -- the timers, batch by batch, until the shutter fires (a batch's own new timers wait for the next)
  local function untilShot() local n0 = #snaps for _ = 1, 40 do if #snaps > n0 then return true end if run() == 0 then return #snaps > n0 end end return #snaps > n0 end
  -- the shutter: what was on the screen at the instant of each picture
  -- (seen = shown AND not faded: the client multiplies a frame's alpha by every parent's)
  local function seen(fr)
    local a, p = 1, fr
    while p do
      if p._shown == false then return false end
      a = a * (p.GetAlpha and p:GetAlpha() or 1)
      p = p._parent
    end
    return a > 0
  end
  _G.Screenshot = function()
    snaps[#snaps + 1] = { ui = UIParent:GetAlpha(), card = S.back and seen(S.back) or false,
                          them = S.post and S.post.them._anim, you = S.post and S.post.you:IsShown() }
  end
  _G.UnitClass = function() return "Shaman", "SHAMAN" end
  _G.UnitRace = function() return "Tauren", "Tauren" end
  local now = 1e8                -- past every clock an earlier section ran
  _G.GetTime = function() return now end
  UIParent._w, UIParent._h = 1920, 1080
  d.gap, d.delay = 0, 0
  M.me = nil
  J.everyone, J.sel = nil, nil
  J.Hide()
  if L.back then L.Hide() end
  local me = M.Me()
  local T0 = os.time({ year = 2026, month = 11, day = 7, hour = 23, min = 43, sec = 0 })
  wipe()
  local CREW = { "Acido Wildhammer", "Macready", "Bologna", "Qazo" }
  local boss = { reason = "boss", detail = "first kill: Mutanus the Devourer", zone = "Wailing Caverns - Dreamer's Rock",
    level = 22, npc = 93654, secs = 41, at = T0, char = me, class = "SHAMAN", race = "Tauren",
    with = { CREW[1], CREW[2], CREW[3], CREW[4] }, withClass = { "ROGUE", "HUNTER", "DRUID", "MAGE" },
    cargo = { "|cff0070dd|Hitem:6627::::::::22:::::|h[Mutant Scale Breastplate]|h|r",
              "|cff1eff00|Hitem:6629::::::::22:::::|h[Glowing Lizardscale Cloak]|h|r" } }
  local before = { reason = "zone", detail = "The Barrens", zone = "The Barrens", level = 21, at = T0 - 3600, char = me }
  log[1], log[2] = boss, before
  local function texts()
    local out = {}
    for _, fs in ipairs(H.labels) do
      if fs._shown ~= false and fs._text ~= "" and S.back and insideShown(fs, S.back) then out[#out + 1] = strip(fs._text) end
    end
    return out
  end
  local function onCard(s)
    for _, t in ipairs(texts()) do if t:find(s, 1, true) then return true end end
    return false
  end
  local function txt(fs) return strip(fs and fs._text or "") end

  H.section("8 Nov: the share card - names hidden by default, for new installs and old saves")
  do
    local keepDB, keepChar = _G.BiSMemoriesDB, _G.BiSMemoriesCharDB
    local function login(acct, char)
      _G.BiSMemoriesDB, _G.BiSMemoriesCharDB = acct, char
      fire("ADDON_LOADED", "BiSMemories")
      return _G.BiSMemoriesDB
    end
    local n = login(nil, nil)
    H.eq(rawget(n, "shareHidden"), true, "a new install: names hidden on a share card")
    local old = login({ comm = true, forever10 = true, log = { { at = 5, reason = "boss", detail = "Hogger" } } }, nil)
    H.eq(rawget(old, "shareHidden"), true, "an existing save (1.0, stamped): the new setting WRITTEN in, hidden")
    H.eq(old[NS.SHARE_STAMP or "?"], true, "and stamped, so it is written once")
    old.shareHidden = false
    old = login(old, nil)
    H.eq(old.shareHidden, false, "a player who showed names keeps them shown at the next login")
    local pre = login({ comm = true, log = { { at = 6, reason = "levelup", detail = "level 2" } } }, nil)
    H.eq(rawget(pre, "shareHidden"), true, "a 0.10 save (not even 1.0-stamped): hidden too")
    _G.BiSMemoriesDB, _G.BiSMemoriesCharDB = keepDB, keepChar
    d = NS.DB()
    log = M.Log()
    wipe()
    log[1], log[2] = boss, before
    local rows = {}
    for _, r in ipairs(NS.CFG.Rows()) do rows[r.key] = r end
    local r = rows.shareHidden
    H.ok(r and r.kind == "toggle", "a row in the options window: names hidden")
    d.shareHidden = true
    H.ok(r and r.get(d) == true, "it reads hidden")
    if r then r.set(d, false) end
    H.eq(d.shareHidden, false, "and switches names on")
    if r then r.set(d, true) end
    local found
    for _, p in ipairs(NS.CFG.Pages()) do
      for _, o in ipairs(p.options or {}) do if o.key == "shareHidden" then found = p end end
    end
    H.ok(found and found.key == "share" and type(found.desc) == "string" and found.usage:find("/bism share", 1, true),
         "and a section of its own on the BiS> page, its command at the foot")
  end

  H.section("8 Nov: the share card - the card, names shown")
  d.shareHidden = false
  local e, why = S.Take(boss)
  H.ok(e and e.reason == "share", "a share card is taken for the memory", tostring(why))
  local back = S.back
  H.ok(back and back:IsShown(), "on its own frame")
  H.eq(back and back:GetFrameStrata(), "FULLSCREEN_DIALOG", "over everything")
  local up, under = back and back._parent, false
  while up do if up == UIParent then under = true end up = up._parent end
  H.ok(back and not under, "NOT inside UIParent: the clean shot fades the interface, never the card")
  H.ok(back and back._all, "the whole screen")
  local F = S.f
  H.eq(txt(F.brand), "BiS> MEMORIES", "the brand: BiS> Memories")
  H.eq(txt(F.head), "BOARDING PASS · FIRST CLASS", "BOARDING PASS · FIRST CLASS")
  H.eq(txt(F.title), "Mutanus the Devourer", "the title, big")
  H.eq(txt(F.line), "FIRST KILL · 0:41", "the tangerine line: first kill, and how long")
  H.ok((F.title._size or 0) > (F.line._size or 0) * 2, "the title much bigger than the line")
  H.eq(txt(F.fromCode), "BAR", "the route: from the memory before (The Barrens)")
  H.eq(txt(F.fromName), "THE BARRENS", "its name")
  H.eq(txt(F.toCode), "WC", "to this one (Wailing Caverns)")
  H.eq(txt(F.toName), "WAILING CAVERNS", "its name")
  H.eq(txt(F.val.passenger), "KUMLUST", "PASSENGER: the character, no realm")
  H.eq(txt(F.val.seat), "LVL 22", "SEAT: the level")
  H.eq(txt(F.val.date), os.date("%d %b %Y", T0):upper(), "DATE, with the year")
  H.eq(txt(F.val.time), "23:43", "TIME")
  H.eq(txt(F.crewLab), "CREW", "CREW")
  for _, name in ipairs(CREW) do H.ok(txt(F.crew):find(name, 1, true), "the crew by name: " .. name, txt(F.crew)) end
  H.ok(F.crew._text:find("|cff9a8a00Acido", 1, true), "in their class colours (a rogue, on paper)", F.crew._text)
  H.eq(txt(F.cargoLab), "CARGO", "CARGO")
  H.ok(txt(F.cargo):find("Mutant Scale Breastplate", 1, true) and txt(F.cargo):find("Glowing Lizardscale Cloak", 1, true),
       "the loot that dropped, by name", txt(F.cargo))
  H.ok(not txt(F.cargo):find("item:", 1, true) and F.cargo._text:find("|cff0f63d6Mutant", 1, true),
       "no link codes; a rare in a blue that reads on paper", F.cargo._text)
  H.eq(txt(F.kind), "BOSS", "the stub: the kind")
  local place = txt(F.place)
  H.ok(place:find("WAILING CAVERNS", 1, true) and place:find("DREAMER'S ROCK", 1, true) and place:find("FLIGHT BOS", 1, true),
       "the stub: the place, the spot, the flight", place)
  H.eq(txt(F.stamp), "BiS> MEMORIES", "the stamp: BiS> Memories")
  H.eq(txt(F.stampSmall), "a WoW addon · CurseForge", "a WoW addon · CurseForge - so a reader can find it")
  local bars = 0
  for _, b in ipairs(S.bars) do if b:IsShown() then bars = bars + 1 end end
  H.ok(bars >= 15, "barcode stripes on the stub", bars)
  H.ok(not onCard("Clipper") and not onCard("CLIPPER"), "never 'Clipper' on anything a picture shows")
  H.ok(not onCard("Dreamscythe") and not onCard("DREAMSCYTHE"), "no realm, even with names on")
  H.ok(not onCard("Heathens"), "no guild")
  -- the oval window: the postcard (you, and the boss lying dead) under our own oval art
  local P = S.post
  H.ok(P and P.you:IsShown() and P.you._unit == "player", "you, in the oval window")
  H.ok(P and P.them:IsShown() and P.them._creature == 93654, "the boss beside you (a creature new this session: the first ask draws nothing)")
  H.ok(S.window and S.window:DoesClipChildren(), "the window's box cuts the models at its edge")
  H.ok(S.oval and S.oval:GetFrameLevel() > S.window:GetFrameLevel() + 1 and tostring(S.oval.art._texture):find("Media\\oval", 1, true),
       "our own oval art over the models")
  H.eq(#snaps, 0, "no picture before the models have drawn")
  untilShot()
  H.eq(#snaps, 1, "then ONE picture")
  local snap = snaps[1] or {}
  H.ok(snap.card == true and snap.ui == 0, "at the shutter: the card on the screen, the interface faded out (M.Clean)")
  H.eq(snap.them, NS.J.DEAD, "and the boss lying dead in the window")
  H.ok(log[1] == e and e.file and e.file:find("^WoWScrnShot_"), "the share card's note: first in the album, its file named")
  H.ok(e.of == T0 and e.detail == "Mutanus the Devourer" and e.hidden == false, "which memory, its title, names shown")
  H.ok(e.with == nil and e.withClass == nil, "no party names on the share card's own note")
  local c = e.crop or {}
  H.ok(math.abs((c.x or 0) - 0.07) < 0.001 and math.abs((c.w or 0) - 0.86) < 0.001
       and math.abs((c.y or 0) - 12 / 56.25) < 0.001 and math.abs((c.h or 0) - 32.25 / 56.25) < 0.001,
       "the ticket's rectangle as fractions of the screen", ("%s %s %s %s"):format(tostring(c.x), tostring(c.y), tostring(c.w), tostring(c.h)))
  M.OnEvent("SCREENSHOT_SUCCEEDED")
  H.ok(not back:IsShown(), "the picture written: the card is put away")
  H.eq(UIParent:GetAlpha(), 1, "and the interface is back")
  H.eq(e.shot, true, "the note says the picture saved")
  settle()
  H.eq(#snaps, 1, "and only one: what was left waiting does nothing")
  -- the UI comes back to the PLAYER'S alpha, and comes back even when the client says nothing
  UIParent:SetAlpha(0.8)
  S.Take(boss)
  untilShot()
  H.eq(#snaps, 2, "a second card, a second picture")
  H.ok(back:IsShown() and UIParent:GetAlpha() == 0, "up, the interface out")
  settle()
  H.ok(not back:IsShown() and math.abs(UIParent:GetAlpha() - 0.8) < 1e-9,
       "no word from the client: put away anyway, the interface back at the player's own alpha", UIParent:GetAlpha())
  UIParent:SetAlpha(1)
  -- a 16:10 screen: the card stays 16:9, the crop follows
  UIParent._w, UIParent._h = 1920, 1200
  local e2 = S.Take(boss)
  local c2 = e2 and e2.crop or {}
  H.ok(math.abs((c2.y or 0) - (60 + 192 * 1.2) / 1200) < 0.001 and math.abs((c2.h or 0) - 516 * 1.2 / 1200) < 0.001
       and math.abs((c2.x or 0) - 0.07) < 0.001, "a 16:10 screen: the crop where the ticket really is",
       ("%s %s"):format(tostring(c2.y), tostring(c2.h)))
  S.Close()
  settle()
  UIParent._w, UIParent._h = 1920, 1080

  H.section("8 Nov: the share card - names hidden (Arn: \"sure keep name hidden\")")
  d.shareHidden = true
  local hid = S.Take(boss)
  H.ok(hid and hid.hidden == true, "a card with names hidden")
  H.eq(txt(F.val.passenger), "A SHAMAN", "the passenger is the class, no race guessed")
  H.ok(F.val.passenger._color and math.abs(F.val.passenger._color[3] - 0xd6 / 255) < 0.01, "in the shaman's colour")
  H.eq(txt(F.crew), "4 friends: rogue, hunter, druid, mage", "the crew: how many, and their classes")
  H.ok(F.crew._text:find("|cff9a8a00rogue", 1, true), "in class colours", F.crew._text)
  local leaked = {}
  for _, t in ipairs(texts()) do
    local low = t:lower()
    for _, name in ipairs({ "kumlust", "dreamscythe", "heathens", "acido", "wildhammer", "macready", "bologna", "qazo" }) do
      if low:find(name, 1, true) then leaked[#leaked + 1] = ("%q"):format(t) end
    end
  end
  H.ok(#texts() > 20 and #leaked == 0, "NO character, party, realm or guild name anywhere on the hidden card ("
       .. #texts() .. " words checked)", table.concat(leaked, ", "))
  H.ok(txt(F.cargo):find("Mutant Scale Breastplate", 1, true) and txt(F.title) == "Mutanus the Devourer",
       "the boss, the place, the time and the loot stay")
  H.eq(txt(S.post.note), "", "the window's note says nothing (it can say 'played by <name>')")
  settle()
  M.OnEvent("SCREENSHOT_SUCCEEDED")
  -- someone else's old memory: no "played by" on the card either
  local alt = { reason = "levelup", detail = "level 10", zone = "Mulgore", level = 10, at = T0 - 7200, char = "Altly-Dreamscythe" }
  S.Take(alt)
  H.ok(not onCard("Altly") and not onCard("ALTLY"), "an alt's memory: no name on it either")
  S.Close()
  settle()
  -- solo, no loot: the lines are left out
  local solo = { reason = "levelup", detail = "level 23", zone = "Thunder Bluff", level = 23, at = T0 + 60, char = me }
  S.Take(solo)
  H.ok(not F.crew:IsShown() and not F.crewLab:IsShown() and not F.cargo:IsShown() and not F.cargoLab:IsShown(),
       "solo and no loot: no CREW, no CARGO line")
  H.eq(txt(F.title), "Level 23", "a level up's title")
  H.eq(txt(F.line), "LEVEL UP", "and its line")
  S.Close()
  settle()

  H.section("8 Nov: the share card - never in a fight")
  _G.InCombatLockdown = function() return true end
  local said0, n0 = #said, #snaps
  local got, no = S.Take(boss)
  H.ok(got == nil and no == "in combat", "in a fight: nil, \"in combat\"", tostring(no))
  H.ok(#said > said0 and said[#said]:lower():find("fight", 1, true), "and a line says why", said[#said])
  H.ok(not back:IsShown(), "no card covers the screen")
  _G.InCombatLockdown = nil
  S.Take(boss)
  H.ok(back:IsShown() and back._events.PLAYER_REGEN_DISABLED, "up, it listens for a fight")
  UIParent:SetAlpha(1)
  fire("PLAYER_REGEN_DISABLED")
  H.ok(not back:IsShown(), "a fight starts: the card goes at once")
  settle()
  H.eq(#snaps, n0, "and no picture is taken after it")
  H.eq(UIParent:GetAlpha(), 1, "the interface is there for the fight")
  H.ok(not back._events.PLAYER_REGEN_DISABLED, "shut, it listens for nothing")
  -- a fight that starts after the shutter, before the client answers: the interface comes back at once
  S.Take(boss)
  untilShot()
  fire("PLAYER_REGEN_DISABLED")
  H.ok(not back:IsShown() and UIParent:GetAlpha() == 1, "a fight after the shutter: card gone, interface back")
  settle()

  H.section("8 Nov: the share card - the SHARE keys and /bism share")
  local f = J.Build()
  H.ok(f.share and strip(f.share.word._text) == "SHARE", "the journal has a SHARE key")
  J.sel = boss
  J.Show()
  f.share:Click()
  H.ok(back:IsShown() and S.entry == boss, "SHARE on the journal: the chosen memory's card")
  H.ok(not J.frame:IsShown(), "the journal steps out of the picture")
  S.Close() settle()
  H.ok(J.frame:IsShown(), "and is back after it")
  J.Hide()
  L.Show()
  H.ok(L.call.share and strip(L.call.share.word._text) == "SHARE", "the lounge has a SHARE key")
  L.Select(boss)
  L.call.share:Click()
  H.ok(back:IsShown() and S.entry == boss and not L.back:IsShown(), "SHARE in the lounge: the chosen memory, the lounge put away")
  S.Close() settle()
  H.ok(L.back:IsShown(), "and the lounge is back after it")
  L.Hide()
  NS.Slash("share")
  H.ok(back:IsShown() and S.entry == boss, "/bism share: the newest memory (the share cards themselves are not memories)")
  S.Close() settle()
  NS.Slash("share 2")
  H.ok(back:IsShown() and S.entry == before, "/bism share 2: the one before")
  S.Close() settle()
  NS.Slash((NS.SHORT.share or "share") .. " 1")
  H.ok(NS.SHORT.share and #NS.SHORT.share <= 4 and back:IsShown() and S.entry == boss, "/bism " .. tostring(NS.SHORT.share) .. " too")
  S.Close() settle()
  NS.Slash("share names on")
  H.eq(d.shareHidden, false, "/bism share names on: names shown")
  NS.Slash("share names off")
  H.eq(d.shareHidden, true, "/bism share names off: hidden again")
  said0 = #said
  NS.Slash("share 99")
  H.ok(not back:IsShown() and #said > said0, "no such memory: says so")
  local entries = J.Entries()
  local any = false
  for _, x in ipairs(entries) do if x.reason == "share" then any = true end end
  H.ok(not any and #log > #entries, "share cards are kept in the album, not listed as memories in the journal")

  H.section("8 Nov: the share card - BiSMemoriesAPI.ShareCard (version 4)")
  H.eq(A.version, 4, "BiSMemoriesAPI version 4")
  local card = { title = "Onyxia", kind = "raid", line = "ALL 40 STANDING · 12:03", place = "Onyxia's Lair",
                 crew = { { name = "Macready-Firemaw", class = "HUNTER" }, { name = "Qazo", class = "MAGE" } },
                 cargo = { 17067, "|cffa335ee|Hitem:16914::::::::60:::::|h[Netherwind Crown]|h|r" }, npc = 10184 }
  d.shareHidden = false
  local ok1, got1 = A.ShareCard("BiSGuild", card)
  H.ok(ok1 == true and type(got1) == "table" and got1.reason == "share" and got1.from == "BiSGuild", "true, and the entry",
       tostring(got1))
  H.eq(txt(F.title), "Onyxia", "the caller's title")
  H.eq(txt(F.line), "ALL 40 STANDING · 12:03", "its line")
  H.eq(txt(F.kind), "RAID", "its kind on the stub")
  H.ok(txt(F.crew):find("Macready", 1, true) and not txt(F.crew):find("Firemaw", 1, true), "its crew - no realm", txt(F.crew))
  H.ok(txt(F.cargo):find("Netherwind Crown", 1, true), "its cargo", txt(F.cargo))
  H.ok(S.post.them._creature == 10184 or S.post.them._display ~= nil, "its creature in the window")
  H.eq(txt(F.toName), "ONYXIA'S LAIR", "its place")
  card.title = "changed after"
  H.eq(txt(F.title), "Onyxia", "the card is copied: changing the caller's table changes nothing")
  settle()
  got1.detail = "edited"
  H.eq(log[1].detail, "Onyxia", "the answer is a copy")
  M.OnEvent("SCREENSHOT_SUCCEEDED")
  d.shareHidden = true
  A.ShareCard("BiSGuild", { title = "Onyxia", crew = { { name = "Macready", class = "HUNTER" } } })
  H.ok(not onCard("Macready") and txt(F.crew):find("1 friend: hunter", 1, true), "names hidden: the caller's crew too", txt(F.crew))
  H.ok(txt(F.val.passenger) == "A SHAMAN", "and the passenger")
  S.Close() settle()
  for _, case in ipairs({
    { { nil, { title = "x" } }, "no owner" },
    { { "X", nil }, "no title" }, { { "X", "Onyxia" }, "no title" }, { { "X", {} }, "no title" },
    { { "X", { title = 5 } }, "no title" }, { { "X", { title = "" } }, "no title" },
    { { "X", setmetatable({}, { __index = function() error("boom") end }) }, "no title" },
  }) do
    local okC, a1, a2 = pcall(A.ShareCard, case[1][1], case[1][2])
    H.ok(okC and a1 == nil and a2 == case[2], "ShareCard refuses: " .. case[2], tostring(a2))
  end
  local long = A.ShareCard and select(2, A.ShareCard("X", { title = ("W"):rep(500), kind = ("k"):rep(99), line = ("L"):rep(300),
    place = ("P"):rep(300), crew = { 7, { name = 9 }, { name = ("N"):rep(300), class = "lower" } }, cargo = { -1, 2.5, "nope", {} },
    npc = "11502", display = -3 }))
  H.ok(long and #long.detail <= 60, "a title is cut to 60", long and #long.detail)
  H.ok(#txt(F.kind) <= 16 and #txt(F.line) <= 40 + 3, "the kind and the line cut short", txt(F.kind))
  H.ok(not F.cargo:IsShown(), "no cargo out of nonsense")
  H.ok(not S.post.them:IsShown(), "and no creature out of a string or a negative number")
  S.Close() settle()
  _G.InCombatLockdown = function() return true end
  local okF, whyF = A.ShareCard("X", { title = "Onyxia" })
  _G.InCombatLockdown = nil
  H.ok(okF == nil and whyF == "in combat", "in a fight: nil, \"in combat\"", tostring(whyF))
  d.gap = 8
  S.Take(boss)
  S.Close() settle()
  local okG, whyG = A.ShareCard("X", { title = "Onyxia" })
  H.ok(okG == nil and whyG == "too soon", "inside the gap between pictures: nil, \"too soon\"", tostring(whyG))
  now = now + 30
  d.gap = 0
  local okM, gotM = A.ShareMemory("X", 1)
  H.ok(okM == true and gotM and gotM.of == boss.at, "ShareMemory: an existing memory's card (1 = the newest)")
  S.Close() settle()
  local okN, whyN = A.ShareMemory("X", 999)
  H.ok(okN == nil and whyN == "no such memory", "ShareMemory: one that is not there", tostring(whyN))
  okN, whyN = A.ShareMemory(nil, 1)
  H.ok(okN == nil and whyN == "no owner", "ShareMemory: no owner", tostring(whyN))
  local hdr = bytes(ROOT .. "/API.lua") or ""
  H.ok(hdr:find("ShareCard(owner, card)", 1, true) and hdr:find("ShareMemory(owner, index)", 1, true)
       and hdr:find("since version 4", 1, true), "the header documents both")

  H.section("8 Nov: the share card - the loot that dropped, kept on a boss's memory")
  wipe()
  local keepInfo = _G.GetItemInfo
  _G.GetItemInfo = function(x) if x == 17067 or tostring(x):find("17067") then return "Ancient Cornerstone Grimoire", nil, 4 end end
  local kill = M.BossKill("Lady Sharecondra", 585, "Creature-0-1-2-3-4-3671-0000")
  H.ok(kill and kill.reason == "boss", "a boss's first kill")
  M.OnEvent("CHAT_MSG_LOOT", "Macready receives loot: |cff0070dd|Hitem:6446::::::::22:::::|h[Snakeskin Bag]|h|r.")
  M.OnEvent("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:5404::::::::22:::::|h[Serpent's Shoulders]|h|r.")
  M.OnEvent("CHAT_MSG_LOOT", "Macready receives loot: |cff0070dd|Hitem:6446::::::::22:::::|h[Snakeskin Bag]|h|r.")
  M.OnEvent("CHAT_MSG_LOOT", "Macready has selected Greed for: [Snakeskin Bag]")
  local cg = kill and kill.cargo or {}
  H.eq(#cg, 2, "every item seen in the next minute, each once (anyone's - what dropped)")
  H.ok(tostring(cg[1]):find("Snakeskin Bag", 1, true) and tostring(cg[2]):find("Serpent", 1, true), "as their links")
  local keepNum, keepSlot = _G.GetNumLootItems, _G.GetLootSlotLink
  _G.GetNumLootItems = function() return 3 end
  _G.GetLootSlotLink = function(i)
    return ({ "|cffa335ee|Hitem:17067::::::::60:::::|h[Ancient Cornerstone Grimoire]|h|r", nil,
              "|cff0070dd|Hitem:6446::::::::22:::::|h[Snakeskin Bag]|h|r" })[i]
  end
  M.OnEvent("LOOT_OPENED")
  H.eq(#cg, 3, "and what the loot window shows")
  run()                          -- the minute is up (its timer)
  M.OnEvent("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:4306::::::::22:::::|h[Silk Cloth]|h|r.")
  M.OnEvent("LOOT_OPENED")
  H.eq(#cg, 3, "after a minute: nothing more")
  -- a hidden line is never read; a secret link from the loot window neither
  local secret = setmetatable({}, {})
  local keepSecret = _G.issecretvalue
  _G.issecretvalue = function(v) return rawequal(v, secret) end
  M.fights[999] = now - 30
  local kill2 = M.BossKill("Lord Sharebrahn", 999, nil)
  M.OnEvent("CHAT_MSG_LOOT", secret)
  _G.GetLootSlotLink = function() return secret end
  local okL = pcall(M.OnEvent, "LOOT_OPENED")
  _G.GetLootSlotLink = function() error("the loot window closed") end
  local okE = pcall(M.OnEvent, "LOOT_OPENED")
  _G.issecretvalue = keepSecret
  H.ok(okL and okE and kill2 and kill2.cargo == nil, "a hidden line, a hidden link, an error: nothing kept, nothing thrown")
  _G.GetNumLootItems, _G.GetLootSlotLink = keepNum, keepSlot
  -- the card names an item by its id too
  local byId = { reason = "boss", detail = "first kill: Onyxia", zone = "Onyxia's Lair", level = 60, at = T0, char = me,
                 cargo = { 17067 } }
  S.Take(byId)
  H.ok(txt(F.cargo):find("Ancient Cornerstone Grimoire", 1, true) and F.cargo._text:find("|cff7b2fbf", 1, true),
       "an item id: its name from the client, an epic in purple", F.cargo._text)
  S.Close() settle()
  _G.GetItemInfo = keepInfo

  H.section("8 Nov: the share card - fits, pops, any screen")
  log[1], log[2] = boss, before
  for _, sz in ipairs({ { 1024, 768 }, { 1920, 1080 }, { 3440, 1440 } }) do
    UIParent._w, UIParent._h = sz[1], sz[2]
    d.shareHidden = false
    S.Take(boss)
    local k = S.room:GetScale()
    H.ok(math.abs(S.W * k - math.min(sz[1], sz[2] * 16 / 9)) < 0.5, ("%dx%d: the card's room as big as 16:9 fits"):format(sz[1], sz[2]))
    local small, n = {}, 0
    for _, fs in ipairs(H.labels) do
      if fs._shown ~= false and fs._text ~= "" and insideShown(fs, S.back) then
        n = n + 1
        if (fs._size or 0) * k < L.MIN_FONT - 0.01 then small[#small + 1] = ("%q %.1f"):format(strip(fs._text), fs._size * k) end
      end
    end
    H.ok(n > 20 and #small == 0, ("%dx%d: no word smaller than %d on the screen"):format(sz[1], sz[2], L.MIN_FONT), table.concat(small, ", "))
    fitsIn(S.ticket, ("the share card at %dx%d"):format(sz[1], sz[2]))
    S.Close() settle()
  end
  UIParent._w, UIParent._h = 1920, 1080
  local long2 = { reason = "boss", detail = "first kill: " .. ("Archbishop Benedictus the Long-Named "):rep(3), zone = "Wailing Caverns",
    level = 22, at = T0, char = me, with = { "Aaaaaaaaaaaa", "Bbbbbbbbbbbbbb", "Cccccccccccccc", "Dddddddddddddd" },
    withClass = { "ROGUE", "MAGE", "DRUID", "PRIEST" }, cargo = {} }
  for i = 1, 8 do long2.cargo[i] = ("|cffa335ee|Hitem:%d::::::::60:::::|h[A Very Long Epic Item Name Number %d]|h|r"):format(19000 + i, i) end
  S.Take(long2)
  fitsIn(S.ticket, "the share card with a long title, crew and cargo")
  H.ok((F.title._size or 99) < S.FontPx(3.6) + 0.01, "a long title is drawn smaller to fit")
  S.Close() settle()
  local function pops(b, what)
    local enter = b and b:GetScript("OnEnter")
    H.ok(enter ~= nil, what .. ": answers the mouse")
    if not enter then return end
    b:Fire("OnEnter")
    H.ok(b.wash and b.wash:GetAlpha() >= 0.2 and b.bar and b.bar:GetAlpha() == 1, what .. ": pops under the mouse")
    b:Fire("OnLeave")
    H.ok(b.wash:GetAlpha() == 0 and b.bar:GetAlpha() == 0, what .. ": and dark again")
  end
  J.sel = boss
  pops(f.share, "the journal's SHARE key")
  L.Show()
  pops(L.call.share, "the lounge's SHARE key")
  L.Hide()
  local ow = NS.CFG.Build()
  local shareRow
  for _, r in ipairs(ow.rows or {}) do if r.opt and r.opt.key == "sharecard" then shareRow = r end end
  H.ok(shareRow ~= nil, "the options window has a share card button")

  H.section("8 Nov: the share card - lean, and nothing runs while it is put away")
  local nT, byT = Cost.Count(function() S.Take(boss) end)
  H.say(("   cost: putting a share card up = %d client calls"):format(nT))
  -- budget (8 Nov 2026): measured on a boss card with crew and cargo - the time, the date, the level, the postcard's
  -- player and creature, the screen's size; once per card, by hand
  H.ok(nT <= S.BUDGET, "a card asks the client at most " .. S.BUDGET .. " things (measured " .. nT .. ")", Cost.Top(byT, 6))
  local nW, byW = Cost.Count(function() settle() end)
  H.say(("   cost: the wait and the shutter = %d client calls"):format(nW))
  -- budget (8 Nov 2026): measured 4 - the time and the date for the note, the file stamp; once per card
  H.ok(nW <= 8, "the wait and the shutter ask at most 8 (measured " .. nW .. ")", Cost.Top(byW, 6))
  M.OnEvent("SCREENSHOT_SUCCEEDED")
  local ticking = {}
  for _, fr in ipairs(H.frames) do
    local p, mine = fr, false
    while p do if p == S.back then mine = true break end p = p._parent end
    if mine and fr:GetScript("OnUpdate") then ticking[#ticking + 1] = tostring(fr._type) end
  end
  H.ok(#ticking == 0, "nothing of the card has an OnUpdate", table.concat(ticking, ", "))
  S.Take(boss)
  S.Close()
  local n1 = #snaps
  local nH = Cost.Count(function() settle() end)
  H.ok(#snaps == n1 and nH <= 6, "put away before its picture: its timers do nothing (" .. nH .. " calls)")
  -- a raid's loot storm in the minute after a kill: string work only
  wipe()
  M.fights[777] = now - 60
  M.BossKill("Majordomo Sharestadt", 777, nil)
  local nL, byL = Cost.Count(function()
    for i = 1, 200 do
      M.OnEvent("CHAT_MSG_LOOT", ("Raider%d receives loot: |cffa335ee|Hitem:%d::::::::60:::::|h[Thing %d]|h|r."):format(i, 17000 + i % 30, i))
    end
  end)
  -- budget (8 Nov 2026): 200 loot lines in a boss's minute; the camera's own "is it worthy" asks one item question a
  -- line (0.9.0's lean section) - the cargo itself asks the client nothing
  H.say(("   cost: 200 loot lines in a boss's minute = %d client calls"):format(nL))
  H.ok(nL <= 210, "200 loot lines after a kill ask the client at most 210 things (measured " .. nL .. ")", Cost.Top(byL, 5))
  H.ok(#(log[1].cargo or {}) == M.CARGO_MAX, "and the cargo stops at " .. tostring(M.CARGO_MAX) .. " items", #(log[1].cargo or {}))

  H.section("8 Nov: the share card - the album page cuts the ticket out")
  local page = bytes(ROOT .. "/Album/BiSMemories-Album.html") or ""
  H.ok(page:find("Save it and post it anywhere.", 1, true), "Save it and post it anywhere.")
  H.ok(page:find("SAVE IMAGE", 1, true) and page:find("toDataURL", 1, true) and page:find(".download =", 1, true),
       "a SAVE IMAGE button: the canvas into a link that downloads")
  H.ok(page:find("BiS-Memories-", 1, true), "the file named BiS-Memories-<what>-<date>.png")
  H.ok(page:find("ClipboardItem", 1, true) and page:find("navigator.clipboard.write", 1, true), "a COPY button where the browser allows it")
  H.ok(page:find('["crop"]', 1, true) or page:find('\\["crop"\\]', 1, true), "it reads the card's crop from the notes")
  H.ok(page:find("function cropOf(", 1, true) and page:find("drawImage", 1, true), "and cuts the picture down with a canvas")
  H.ok(page:find('share: "Share card"', 1, true), "a share card in plain words")
  H.ok(not page:find('src="http', 1, true) and not page:find("fetch(", 1, true), "still nothing from the internet")
  H.ok(page:find('rel("Screenshots/"', 1, true), "pictures still loaded from beside the page, by relative path")

  wipe()
  if S.back then S.Close() end
  settle()
  d.gap, d.shareHidden = 0, true
  J.sel = nil
  J.Hide()
  _G.C_Timer, _G.Screenshot, _G.UnitClass, _G.UnitRace, _G.GetTime = keepTimer, keepShot, keepClass, keepRace, keepTime
  UIParent._w, UIParent._h = keepW, keepH
end)()

H.report()
