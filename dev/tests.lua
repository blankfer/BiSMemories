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
}
local function Load()
    local before = {}
    for k in pairs(_G) do before[k] = true end
    local NS = {}
    for _, rel in ipairs(FILES) do
        local chunk, err = loadfile(ROOT .. "/" .. rel)
        if not chunk then error("load " .. rel .. ": " .. tostring(err), 0) end
        chunk("BiSMemories", NS)
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
  H.ok(type(A) == "table" and A.major == 1 and A.version == 1, "BiSMemoriesAPI is there, major 1, version 1")
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
H.eq(_G.LibBiSComm.MINOR, 13, "LibBiSComm minor 13")
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
_G.BiSMemoriesDB.zones = nil
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
  _G.BiSMemoriesDB.zones = nil
  M.zoneShots = 0
  M.SeeZone("Mulgore")                                  -- so nothing below is the free first one

  -- FIRED, not called: the camera only hears an event it actually registered for, and a test
  -- that calls OnEvent by hand passes just as happily when the name is missing from the list.
  _G.GetRealZoneText = function() return "The Barrens" end
  fire("ZONE_CHANGED")
  H.ok(_G.BiSMemoriesDB.zones["The Barrens"] == true, "a quiet zone change is still written down")
  H.ok(M.NewZone("The Barrens") == nil, "so walking back in later is not worth a picture")

  _G.GetRealZoneText = function() return "Ashenvale" end
  fire("ZONE_CHANGED_INDOORS")
  H.ok(_G.BiSMemoriesDB.zones["Ashenvale"] == true, "and so is stepping indoors")

  -- a picture taken anywhere is proof you were there, whatever the reason was
  _G.GetRealZoneText = function() return "Durotar" end
  local dz = NS.DB()
  dz.levelup, dz.gap = true, 0
  M.OnEvent("PLAYER_LEVEL_UP", 12)
  H.ok(_G.BiSMemoriesDB.zones["Durotar"] == true,
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
  H.ok(_G.BiSMemoriesDB.zones["Place 8"] == true,
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
  H.ok(strip(J.frame.foot._text):find("nothing yet"), "and an empty log says so in words")
  H.eq(J.frame.rows[1]._text, "", "with no stale row left behind")

  -- twenty memories, newest first
  for i = 1, 20 do
    table.insert(log, 1, { at = 1000 + i, reason = "zone", detail = "place " .. i,
                           zone = "Mulgore", with = {}, file = "WoWScrnShot_" .. i })
  end
  J.Refresh()
  -- ROW 1 IS THE NIGHT'S HEADING NOW, and the memories hang under it. These twenty were written
  -- a second apart, so they are all one "night" - which is the rule doing exactly what it says.
  H.ok(strip(J.frame.rows[1]._text):find("Mulgore"), "the night's heading is at the top",
       strip(J.frame.rows[1]._text))
  H.ok(strip(J.frame.rows[2]._text):find("place 20"), "the newest memory is under it")
  H.ok(strip(J.frame.rows[3]._text):find("place 19"), "and the one before it under that")
  H.ok(strip(J.frame.foot._text):find("of 20"), "the footer counts the memories, not the lines")

  -- the wheel walks it, and stops at the ends rather than running off
  H.eq(J.Scroll(3), 3, "the wheel moves down the list")
  H.ok(strip(J.frame.rows[1]._text):find("place 18"), "and the page follows",
       strip(J.frame.rows[1]._text))
  H.eq(J.Scroll(-99), 0, "it will not go above the newest")
  H.eq(J.Scroll(99), 9, "nor past the oldest - 20 memories plus a heading, 12 rows")

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
  H.ok(page and page:find("http", 1, true) == nil or not page:find("src=\"http", 1, true),
       "nothing is fetched from the internet: it must work offline")
  H.ok(bytes(HERE .. "/../Album/README.txt") ~= nil, "with the instructions beside it")

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
  H.ok(ok4 and entry and entry.detail == "a boss", "a boss kill with a hidden name still gets its picture",
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
  local f = NS.J.Build and NS.J.Build() or NS.J.frame
  if f and f.GetHeight then
    local rowsEnd = 34 + 12 * 20           -- where the last row's bottom lands
    H.eq(f:GetHeight() - rowsEnd >= 66, true,
         "the rows stop above the copy box rather than behind it")
  end
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
    if strip(J.frame.rows[i]._text):find("  death  ", 1, true) then row = i end
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

H.report()
