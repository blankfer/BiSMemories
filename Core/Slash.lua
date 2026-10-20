--[[
  BiSMemories :: Core/Slash.lua - /bism (and /memories, the old name, kept as an alias).

      /bism                     the last ten, newest first
      /bism all                 everything kept
      /bism now [note]          take one right now, with an optional note
      /bism on|off <thing>      levelup, boss, loot, achievement, death, duel
      /bism loot <2-5>          the quality worth a picture: 4 is epic, 3 is rare.
                                YOUR loot only - plus anyone's legendary, whoever won it
      /bism gems                gems on or off. Off: cutting one is "You create:" to the client,
                                so a jewelcrafter photographed every gem they cut mid-raid
      /bism gap <seconds>       the least time between two shots
      /bism sound               the click on or off
      /bism clear               forget the notes (never touches the pictures)
      /bism status              what is on, and where the pictures live
      /bism journal             the album in game: what happened, newest first. No pictures -
                                an addon cannot list a folder, and cannot draw a .jpg. See
                                Core/Journal.lua for why that is not a Forever thing.
      /bism map                 the journal's map: a dot where each memory was taken
      /bism year [all]          what this year's notes add up to (all: every character)
      /bism group [secs]        a group photo: a countdown for everyone with a BiS addon
      /bism options             the options window (or right-click the minimap button)
      /bism every boss|death    every kill / every death again, not just the ones worth keeping
      /bism pins mine|all|off   the world map's pins
      /bism onthisday · clean   on this day on/off; hide the interface for the picture on/off
      /bism db                  which saved copy came back at this login

  Reading it back matters as much as taking it: the note names the file the client wrote, so a
  picture in Screenshots\ can be matched to the night it came from.
]]
local ADDON, ns = ...
local T, M = ns.T, ns.M

local function db() return ns.DB() end

local function when(at)
  if not at or at == 0 then return "?" end
  return date and date("%d %b %H:%M", at) or tostring(at)
end

local function line(e)
  local who = (e.with and #e.with > 0) and (", with " .. #e.with) or ""
  return ("%s  %s  %s%s%s"):format(
    T.text("muted", when(e.at)),
    T.text("accent", M.Word(e.reason)),
    tostring(e.detail or ""),
    T.text("muted", "  " .. tostring(e.zone or "?") .. who),
    e.file and T.text("muted", "  " .. e.file) or "")
end

local function list(n)
  local log = M.Log()
  if #log == 0 then
    ns.Print("nothing yet. It fires on: %s", T.text("muted", "levelling, bosses, rare loot, achievements, dying"))
    return
  end
  ns.Print("%d memory(s):", #log)
  for i = 1, math.min(n or 10, #log) do
    DEFAULT_CHAT_FRAME:AddMessage("   " .. line(log[i]))
  end
  if n and #log > n then ns.Print("...and %d more - %s", #log - n, T.text("muted", "/bism all")) end
end

local function status()
  local d = db()
  local on = {}
  for _, t in ipairs(M.TRIGGERS) do
    on[#on + 1] = (d[t.key] and T.text("good", t.key) or T.text("muted", t.key))
  end
  ns.Print("version %s - %s", ns.VERSION, table.concat(on, " "))
  ns.Print("loot from quality %d%s, at most one shot every %ds, %d note(s) kept",
    d.lootQuality or 4, d.gems and "" or " (no gems)", d.gap or 8, #M.Log())
  local last = tonumber(d.candidLast) or 0
  if d.candid then
    ns.Print("candid: %s", last == 0 and T.text("muted", "none yet - one is due this week")
      or T.text("muted", "last one " .. when(last)))
  end
  ns.Print("the pictures are in %s", T.text("muted", "World of Warcraft\\<client>\\Screenshots"))
end

--- WHAT THE CAMERA HAS HEARD THIS SESSION, and what it did about it.
---
--- An album with one picture has two explanations - nothing worth remembering happened, or the
--- event never arrived - and they look identical from outside. This tells them apart: counts for
--- what has come in, the verdict on the last few, and the list of events that have not arrived at
--- all. A name on that last list is either an event this client does not send or a thing that has
--- not happened yet, and only the person at the keyboard knows which.
local function heard()
  local seen = {}
  for _, e in ipairs(M.EVENTS or {}) do
    local n = (M.heard or {})[e]
    if n then seen[#seen + 1] = ("%s %d"):format(e:lower():gsub("_", " "), n) end
  end
  if #seen == 0 then
    ns.Print("nothing heard yet this session - not even a login. The camera may not be running.")
  else
    ns.Print("heard since login: %s", T.text("good", table.concat(seen, ", ")))
  end

  local recent = M.recent or {}
  for i = 1, math.min(#recent, 6) do
    local r = recent[i]
    ns.Print("  %s%s %s", T.text("muted", r.event:lower():gsub("_", " ")),
      (r.n or 1) > 1 and T.text("muted", (" x%d"):format(r.n)) or "",
      r.why == "TOOK ONE" and T.text("good", "took one") or T.text("muted", r.why))
  end

  local quiet = M.Unheard and M.Unheard() or {}
  if #quiet > 0 then
    ns.Print("not heard at all: %s", T.text("warn", table.concat(quiet, ", "):lower():gsub("_", " ")))
    ns.Print("%s", T.text("muted", "either this client does not send it, or it has not happened yet"))
  end
end

local function set(key, on)
  local d = db()
  for _, t in ipairs(M.TRIGGERS) do
    if t.key == key then
      d[key] = on and true or false
      ns.Print("%s: %s", t.label, on and T.text("good", "on") or T.text("warn", "off"))
      return true
    end
  end
  local keys = {}
  for _, t in ipairs(M.TRIGGERS) do keys[#keys + 1] = t.key end
  ns.Print("no such thing as %s - try: %s", tostring(key), table.concat(keys, ", "))
  return false
end

--- `/bism db`: which saved copy came back at this login (Init.lua ns.dbSeen).
local function dbCheck()
  local seen = ns.dbSeen or {}
  local function said(stamp)
    return stamp and T.text("good", "yes, saved " .. when(stamp)) or T.text("warn", "no")
  end
  ns.Print("the account-wide file came back: %s", said(seen.acct))
  ns.Print("the per-character copy came back: %s", said(seen.char))
  ns.Print("rescued from the per-character copy this login: %s", ns.rescued and T.text("warn", "yes") or "no")
end

--- `/bism year [all]`: what this year's notes add up to - this character's, or every character's.
local function year(all)
  local s = M.Summary(nil, (not all) and M.Me() or nil)
  for i, l in ipairs(M.SummaryLines(s)) do
    if i == 1 then ns.Print("%s", T.text("accent", l)) else DEFAULT_CHAT_FRAME:AddMessage("   " .. l) end
  end
end

function ns.Slash(input)
  -- THE COMMAND IS LOWERCASED; THE ARGUMENT IS NOT (3 Oct 2026). It used to lower() the whole
  -- line, which quietly ruined the two arguments that are a PERSON'S words rather than a keyword:
  -- `/memories now Killed Baron Silverlaine` was stored as "killed baron silverlaine", and a
  -- Windows path came back shouting in lower case. Found while adding `/memories wow`.
  --
  -- Keywords still compare in lower case, at the places that compare them - `set()` and the
  -- numbers below - so "on LevelUp" keeps working.
  local raw = tostring(input or "")
  local cmd, rest = raw:match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()

  if cmd == "" then
    list(10)

  elseif cmd == "all" then
    list(nil)

  elseif cmd == "now" then
    local e, why = M.Shoot("manual", rest ~= "" and rest or "asked for it")
    if e then ns.Print("saying cheese - %s", T.text("muted", e.zone))
    else ns.Print("not this time (%s)", tostring(why)) end

  elseif cmd == "on" or cmd == "off" then
    set(rest:lower(), cmd == "on")

  elseif cmd == "loot" then
    local q = tonumber(rest)
    if q and q >= 0 and q <= 5 then
      db().lootQuality = q
      ns.Print("loot worth a picture: quality %d and up", q)
    else
      ns.Print("a number 0-5, where 4 is epic and 3 is rare")
    end

  -- GEMS. Off by default since 4 Oct: cutting one fires the client's "You create:" line, so a
  -- jewelcrafter sitting down mid-raid photographed every epic they cut.
  elseif cmd == "gems" then
    local d = db()
    d.gems = not d.gems
    ns.Print("gems are %s", d.gems and T.text("good", "worth a picture")
      or T.text("muted", "not a memory - they go in a socket and are never seen again"))

  elseif cmd == "gap" then
    local s = tonumber(rest)
    if s and s >= 0 then
      db().gap = s
      ns.Print("at most one shot every %ds", s)
    else
      ns.Print("seconds, please - %s", T.text("muted", "/bism gap 8"))
    end

  elseif cmd == "sound" then
    local d = db()
    d.sound = not d.sound
    ns.Print("the click is %s", d.sound and T.text("good", "on") or T.text("warn", "off"))

  elseif cmd == "clear" then
    local n = #M.Log()
    db().log = {}
    M.Log()
    ns.Print("forgot %d note(s). The pictures are still where they were.", n)

  elseif cmd == "zones" or cmd == "places" then
    -- WHAT IT REMEMBERS OF WHERE YOU HAVE BEEN. "It photographs places I know" and "it has
    -- forgotten every place I know" look identical from the outside, and the second is what was
    -- really happening on 24 Sep - one zone remembered after a week of play. This says which.
    local kept = type(db().zones) == "table" and db().zones or {}
    local names, n = {}, 0            -- `names`, not `list`: `list` up there is the log printer
    for name in pairs(kept) do
      n = n + 1
      if n <= 12 then names[#names + 1] = tostring(name) end
    end
    table.sort(names)
    ns.Print("%d place(s) remembered", n)
    if n > 0 then
      ns.Print("  %s", T.text("muted", table.concat(names, ", ") .. (n > #names and ", ..." or "")))
    end
    ns.Print("  %s", T.text("muted",
      ("%d new-place picture(s) this session"):format(M.zoneShots or 0)))

  elseif cmd == "status" then
    status()

  elseif cmd == "heard" then
    heard()

  elseif cmd == "journal" or cmd == "album" or cmd == "book" then
    if ns.J then ns.J.Toggle() else ns.Print("the journal is not loaded") end

  elseif cmd == "map" then
    if ns.J then ns.J.Tab("map") ns.J.Show() end

  elseif cmd == "options" or cmd == "config" or cmd == "settings" then
    if ns.CFG then ns.CFG.Toggle() else ns.Print("the options are not loaded") end

  elseif cmd == "group" or cmd == "cheese" then
    local ok, why = M.GroupPhoto(tonumber(rest))
    if not ok then ns.Print("no group photo - %s", tostring(why)) end

  elseif cmd == "year" then
    year(rest:lower() == "all")
    if ns.J then ns.J.Tab("this year") ns.J.Show() end

  elseif cmd == "onthisday" then
    local d = db()
    d.onThisDay = d.onThisDay == false
    ns.Print("on this day: %s", d.onThisDay and T.text("good", "on") or T.text("warn", "off"))

  elseif cmd == "every" then
    -- `/bism every boss` / `/bism every death`: every one, or (again) only the ones worth keeping
    local what = rest:lower()
    local key = (what == "boss" and "bossEvery") or (what == "death" and "deathEvery") or nil
    if not key then ns.Print("every boss, or every death") else
      local d = db()
      d[key] = not d[key]
      ns.Print("%s: %s", what == "boss" and "boss kills" or "deaths",
        d[key] and T.text("good", "every one") or T.text("muted", "only the ones worth keeping"))
    end

  elseif cmd == "pins" then
    local m = rest:lower()
    if m ~= "mine" and m ~= "all" and m ~= "off" then
      ns.Print("map pins are %s - /bism pins mine, all or off", ns.Pins and ns.Pins.Mode() or "?")
    else
      db().pins = m
      local n = ns.Pins and ns.Pins.Update() or 0
      ns.Print("map pins: %s (%d on the map)", m, n)
    end

  elseif cmd == "clean" then
    local d = db()
    d.clean = not d.clean
    ns.Print("hide the interface for the picture: %s", d.clean and T.text("good", "on") or T.text("warn", "off"))

  elseif cmd == "db" then
    dbCheck()

  -- WHERE THE ALBUM PAGE IS. An addon cannot know its own full path - there is no API for the
  -- install folder and none for the version folder either - so the certain part is printed, and
  -- `/memories wow <folder>` makes it whole and keeps it.
  elseif cmd == "path" or cmd == "where" then
    if not ns.J then ns.Print("the journal is not loaded") return end
    ns.Print("the album page: " .. ns.J.AlbumPath())
    if not ns.J.AlbumPathWhole() then
      ns.Print("that is inside your WoW version folder. Paste it whole with:")
      ns.Print([[  /bism wow C:\Program Files (x86)\World of Warcraft\_classic_beta_]])
      ns.Print("(whatever yours is called - it is the folder with Interface and WTF in it)")
    end
    ns.J.Show()

  elseif cmd == "wow" then
    if not ns.J then ns.Print("the journal is not loaded") return end
    local set = ns.J.SetWow(rest)
    if set then
      ns.Print("WoW is at " .. set)
      ns.Print("the album page: " .. ns.J.AlbumPath())
    else
      ns.Print("forgotten where WoW is - /bism wow <folder> to set it again")
    end

  else
    ns.Print("%s", T.text("muted",
      "/bism · all · now [note] · journal · map · year [all] · group · options · on|off <thing> · every boss|death"
      .. " · pins mine|all|off · onthisday · clean · loot <2-5> · gap <secs> · sound · clear · zones · status · heard · db"))
  end
end
