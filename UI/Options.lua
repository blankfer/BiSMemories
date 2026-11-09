--[[
  BiSMemories :: UI/Options.lua - the options window and the minimap button (0.9.0: every setting used to
  be a slash command only; the family has had both since September).

  The window is BiSTheme's shared kit (Libs\BiSTheme\Options.lua), in two columns the way BiS Healing
  builds them (its UI/options.lua): each column built as the kit builds it, then each row pinned into its
  column. 25% bigger, as Healing's - the kit's 8 pt is hard to read. The button is BiSTheme's shared
  minimap button (Libs\BiSTheme\Minimap.lua): left-click the journal, right-click this window (again: closes it).
  Since 1.0 the game's own options also have a BiS> Memories page (Libs\BiSTheme\Settings.lua): since 8 Nov 2026 the
  kit's dashboard (CFG.Pages), drawn from this window's very same rows - the window itself is never held inside it.
]]
local ADDON, ns = ...
local M = ns.M

local CFG = {}
ns.CFG = CFG
CFG.SCALE = 1.25

local function toggle(key, label, help)
  return { key = key, kind = "toggle", label = label, help = help,
           get = function(db) return db[key] ~= false end,
           set = function(db, on) db[key] = on and true or false end }
end

--- Put the game's options panel away first (a no-op when it is not up): a button on the BiS> page that opens the
--- journal or takes a picture must not leave the journal behind the panel, or photograph the panel.
local function away()
  local T = BiSTheme
  if T and T.CloseSettingsPanel then pcall(T.CloseSettingsPanel) end
end

--- The rows: made ONCE, so the options window and the BiS> page hold the very same tables (no second copy of a
--- setting). `get` is still asked every time either one paints.
function CFG.Sections()
  if CFG.sections then return CFG.sections end
  local QUALITY = { [2] = "uncommon", [3] = "rare", [4] = "epic", [5] = "legendary" }
  CFG.sections = {
    { title = "worth a picture", column = 1, options = {
      toggle("levelup", "level ups", "Every level you gain - level 60 is called the top."),
      toggle("boss", "first kills, fastest", "A boss the first time this character kills it, and again when a kill is your fastest yet."),
      toggle("loot", "rare loot", "Loot of the quality you pick under 'the camera' - and anyone's legendary."),
      toggle("achievement", "achievements", "Every achievement the game gives you."),
      toggle("death", "deaths worth it", "Killed by a player or a rival, dying in a boss fight, and your very first death."),
      toggle("duel", "duels won", "Winning a duel."),
      toggle("zone", "new places", "A zone this character has never been to - three a session at most."),
      toggle("exalted", "exalted", "Going exalted with anyone."),
      toggle("candid", "a candid a week", "One picture a week at a random moment - the half of a year nobody photographs."),
      toggle("first", "firsts", "Your first mount, a new mount, learning to ride."),
      toggle("gamba", "gamba wins", "Your biggest win yet at a BiS Gamba table."),
      toggle("group", "group photos", "Your picture in a group photo - the one you call with /bism group, and others' when the next switch lets them."),
      { key = "groupOthers", kind = "toggle", label = "others can call one",
        help = "Someone else in your group may start the countdown on your screen and take your picture (/bism group).",
        get = function(db) return db.groupOthers == true end, set = function(db, on) db.groupOthers = on and true or false end },
    } },
    -- SHARE CARDS (8 Nov 2026, Share.lua): names hidden unless the player says otherwise (anything but a plain false
    -- reads hidden - the safe side; the setting is written into every save anyway, Init.lua ns.ADDED)
    { title = "share cards", column = 1, options = {
      { key = "shareHidden", kind = "toggle", label = "names hidden",
        help = "On a share card your name becomes your class and your party their classes - no realm, no guild, no names anywhere on it.",
        get = function(db) return db.shareHidden ~= false end, set = function(db, on) db.shareHidden = on and true or false end },
      { key = "sharecard", kind = "button", label = "share card", button = "take",
        help = "Your newest memory as a picture to post anywhere: the boarding pass, big and alone (/bism share).",
        action = function()
          away()
          local e = ns.Share and ns.Share.Newest(1)
          if e then ns.Share.Take(e) else ns.Print("no memory to share yet") end
        end },
    } },
    { title = "the camera", column = 2, options = {
      toggle("clean", "hide the interface", "The interface hidden for the instant of the picture, like Alt+Z, then back."),
      toggle("sound", "camera click", "A click when a picture is taken (the game only clicks for the Print Screen key)."),
      { key = "lootQuality", kind = "step", label = "loot from", min = 2, max = 5, step = 1,
        help = "The least quality of your own loot that is worth a picture.",
        get = function(db) return db.lootQuality or 4 end, set = function(db, v) db.lootQuality = v end,
        show = function(db) return QUALITY[db.lootQuality or 4] or "?" end },
      { key = "gap", kind = "step", label = "seconds between", min = 0, max = 60, step = 2,
        help = "The least time between two pictures, so one loot burst is not forty.",
        get = function(db) return db.gap or 8 end, set = function(db, v) db.gap = v end,
        show = function(db) return tostring(db.gap or 8) end },
      { key = "gems", kind = "toggle", label = "gems count", help = "Cut or looted gems are worth a picture too. Off: they go in a socket and are never seen again.",
        get = function(db) return db.gems == true end, set = function(db, on) db.gems = on and true or false end },
      { key = "bossEvery", kind = "toggle", label = "every boss kill", help = "Every kill, every week - not just the first and the fastest.",
        get = function(db) return db.bossEvery == true end, set = function(db, on) db.bossEvery = on and true or false end },
      { key = "deathEvery", kind = "toggle", label = "every death", help = "Every death - not just the ones worth keeping.",
        get = function(db) return db.deathEvery == true end, set = function(db, on) db.deathEvery = on and true or false end },
    } },
    { title = "the album", column = 2, options = {
      toggle("onThisDay", "on this day", "Once a day at login: what happened on this day a year (or a month) ago."),
      { key = "pins", kind = "seg", label = "map pins", values = { "mine", "all", "off" },
        help = "Your memories on the world map: this character's, every character's, or none.",
        get = function(db) return (db.pins == "all" or db.pins == "off") and db.pins or "mine" end,
        set = function(db, v) db.pins = v if ns.Pins then ns.Pins.Update() end end },
      { key = "minimapShown", kind = "toggle", label = "minimap button", help = "The BiS Memories button on the minimap. /bism still opens everything.",
        get = function(db) return not (type(db.minimap) == "table" and db.minimap.hide) end,
        set = function(_, on) CFG.SetMinimap(on) end },
      { key = "journal", kind = "button", label = "the journal", button = "open", help = "Your memories, the map of where, and the year so far.",
        action = function() away() if ns.J then ns.J.Show() end end },
      { key = "now", kind = "button", label = "a picture now", button = "take", help = "Take one right now (the same as /bism now).",
        action = function() away() M.Shoot("manual", "asked for it") end },
      { key = "groupcall", kind = "button", label = "group photo", button = "call", help = "A countdown for everyone in your group with a BiS addon, then everyone's picture at once (/bism group).",
        action = function() away() local ok, why = M.GroupPhoto() if not ok then ns.Print("no group photo - %s", tostring(why)) end end },
    } },
  }
  return CFG.sections
end

function CFG.Build()
  if CFG.built then return CFG.frame end
  local T = BiSTheme
  if not (T and T.Options) then
    ns.Print("Libs\\BiSTheme\\Options.lua did not load - reinstall the addon")
    return nil
  end
  CFG.built = true
  local W = T.OPTIONS.W
  local f = T.Options("BiSMemoriesOptions", W, "Memories")
  CFG.frame = f
  f:SetScale(CFG.SCALE)
  if f.Recenter then f:Recenter(60) end
  local columns = f.rows and f.body and type(f._y) == "number"
  local col, heights = {}, {}
  for c = 1, 2 do
    if columns then f._y = 0 end
    for _, section in ipairs(CFG.Sections()) do
      if (section.column or 1) == c then
        local first = #f.rows + 1
        f:Section(section.title)
        for _, opt in ipairs(section.options) do f:Row(opt, ns.DB()) end
        for i = first, #f.rows do col[f.rows[i]] = c end
      end
    end
    heights[c] = f._y
  end
  if columns then
    local ROW = T.OPTIONS.ROW
    local y = { 0, 0 }
    for _, r in ipairs(f.rows) do
      local c = col[r] or 1
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", f.body, "TOPLEFT", (c - 1) * W, -y[c])
      r:SetWidth(W)
      y[c] = y[c] + ROW
    end
    f:SetWidth(2 * W)
    f._y = math.max(heights[1] or 0, heights[2] or 0)
    CFG.columns = 2
  end
  f:Fit()
  return f
end

function CFG.Toggle()
  local f = CFG.Build()
  if not f then return nil end
  f:Toggle()
  if f:IsShown() then f:Paint() end
  return f:IsShown()
end

function CFG.Open()
  local f = CFG.Build()
  if f then f:Toggle(true) f:Paint() end
  return f
end

--- Every row, flat - what a suite reads back.
function CFG.Rows()
  local out = {}
  for _, sec in ipairs(CFG.Sections()) do
    for _, opt in ipairs(sec.options) do out[#out + 1] = opt end
  end
  return out
end

--------------------------------------------------------------- the minimap button --

function CFG.MinimapDB()
  local db = ns.DB()
  db.minimap = type(db.minimap) == "table" and db.minimap or {}
  return db.minimap
end

--- THE FAMILY STANDARD (Forever 1.0 - Minimap.lua minor 5, 8 Nov 2026): left-click = the journal, right-click = our
--- own options window as a toggle (right-click again closes it; never the game's options - Arn, 7 Nov live: "i liked
--- these old option windows that opened without opening the game option window"), drag = move.
--- The kit's own click and tooltip, so every BiS button says and does the same.
function CFG.BuildMinimap()
  if CFG.button then return CFG.button end
  if not (BiSTheme and BiSTheme.Minimap) then return nil end
  CFG.button = BiSTheme.Minimap("BiSMemories", {
    icon      = "Interface\\Icons\\INV_Misc_Spyglass_03",
    label     = "Memories",
    db        = CFG.MinimapDB(),
    onLeft    = function() if ns.J then ns.J.Toggle() end end,
    leftLabel = "your memories",
    onRight   = function() CFG.Toggle() end,
  })
  return CFG.button
end

--------------------------------------------------------------- the BiS> page --

--- What is on, in a few words, for the BiS> front page: "4 of 12 moments - sound off".
function CFG.Status()
  local d = ns.DB()
  local on = 0
  for _, t in ipairs(M.TRIGGERS) do if d[t.key] ~= false then on = on + 1 end end
  return ("%d of %d moments - sound %s"):format(on, #M.TRIGGERS, d.sound and "on" or "off")
end

--- THE BiS> PAGE'S SECTIONS (Settings minor 3, the family rule: every BiS> page is the kit's T.Dashboard). Built
--- from the options window's own rows - the very same tables (CFG.Sections makes them once) - regrouped by what they
--- are about. A moment with an on/off of its own (bosses, loot, deaths, group photos, the pins) is a section with a
--- switch, through the row's own setter, the same saved value `/bism on|off <thing>` and `/bism pins` write.
--- `switch.key` / `open.key` name the window row they stand for (the suite checks every row is on the page once).
function CFG.Pages()
  local by = {}
  for _, r in ipairs(CFG.Rows()) do by[r.key] = r end
  local function rows(...)
    local out = {}
    for _, k in ipairs({ ... }) do out[#out + 1] = by[k] end
    return out
  end
  local function switch(key)
    local r = by[key]
    return { key = key, get = function() return r.get(ns.DB()) and true or false end,
             set = function(on) r.set(ns.DB(), on) end }
  end
  local pins = by.pins
  local journal = function() if ns.J then ns.J.Tab("memories") ns.J.Show() end end
  local pages = {
    { key = "camera", title = "the camera", options = rows("clean", "sound", "gap", "now"),
      desc = "How every picture is taken: the interface out of the way for the instant of it, a click so you know, "
        .. "and a pause between two so one loot burst is not forty.",
      usage = "/bism now [note]   /bism clean   /bism sound   /bism gap <seconds>" },
    { key = "milestones", title = "milestones", options = rows("levelup", "achievement", "first", "exalted"),
      desc = "The big steps of a character: every level, every achievement, your first mount and learning to ride, "
        .. "going exalted.",
      usage = "/bism on|off levelup   achievement   first   exalted" },
    { key = "bosses", title = "bosses", switch = switch("boss"), options = rows("bossEvery"),
      desc = "A boss the first time this character kills it, and again when a kill is your fastest yet.",
      usage = "/bism on|off boss   /bism every boss" },
    { key = "loot", title = "loot", switch = switch("loot"), options = rows("lootQuality", "gems"),
      desc = "Loot of the quality you pick here, and anyone's legendary.",
      usage = "/bism on|off loot   /bism loot <2-5>   /bism gems" },
    { key = "deaths", title = "deaths", switch = switch("death"), options = rows("deathEvery"),
      desc = "The deaths worth keeping: killed by a player or a rival, dying in a boss fight, and your very first.",
      usage = "/bism on|off death   /bism every death" },
    { key = "world", title = "out in the world", options = rows("zone", "duel", "candid", "gamba"),
      desc = "The smaller moments: a place this character has never been, a duel won, one candid picture a week, "
        .. "your biggest win at a BiS Gamba table.",
      usage = "/bism on|off zone   duel   candid   gamba" },
    { key = "group", title = "group photos", switch = switch("group"), options = rows("groupOthers", "groupcall"),
      desc = "Everyone in your group with a BiS addon, in one picture: a countdown on every screen, then everyone's "
        .. "picture at once.",
      usage = "/bism group [seconds]" },
    { key = "journal", title = "the journal", options = rows("onThisDay", "minimapShown"),
      open = { key = "journal", label = "the journal", func = journal },
      desc = "Your memories in the game: what happened, where and who with, on a postcard - the map of where, and "
        .. "the year so far. On this day reminds you of one, once a day at login.",
      usage = "/bism journal   /bism year [all]   /bism onthisday" },
    { key = "pins", title = "world-map pins", options = rows("pins"),
      -- the switch is the "off" end of the row's own setter; on again comes back to the last choice (mine or all)
      switch = {
        get = function() return pins.get(ns.DB()) ~= "off" end,
        set = function(on)
          local d = ns.DB()
          local now = pins.get(d)
          if now ~= "off" then CFG.lastPins = now end
          pins.set(d, on and (CFG.lastPins or "mine") or "off")
        end },
      open = { label = "the map", func = function() if ns.J then ns.J.Tab("map") ns.J.Show() end end },
      desc = "A camera viewfinder on the world map where each memory was taken: this character's, or every "
        .. "character's.",
      usage = "/bism pins mine|all|off   /bism map" },
    { key = "album", title = "the album page", options = {},
      open = { label = "the journal", func = journal },
      desc = "The pictures live in the game's Screenshots folder; the album page shows them with their notes in your "
        .. "web browser. The journal's foot holds the page's address: click it, copy it (Ctrl+C), paste it into "
        .. "Windows key + R.",
      usage = "/bism path   /bism wow <your WoW folder, if the address is a guess>" },
    { key = "share", title = "share cards", options = rows("shareHidden", "sharecard"),
      desc = "A memory as one picture to post anywhere: its boarding pass big and alone - the boss, the place, the time, "
        .. "the loot that dropped. Names hidden: you are your class, your party their classes. The album page cuts the "
        .. "ticket out and saves it.",
      usage = "/bism share [n]   /bism share names on|off" },
  }
  local db = ns.DB()     -- the table the rows take, the same one the options window hands them
  for _, e in ipairs(pages) do e.db = db end
  return pages
end

--- The model the kit draws: the sections, and a change repaints our own options window when it is open.
function CFG.Model()
  return {
    entries = CFG.Pages(),
    list = "SECTIONS",
    idle = "Point at anything on this page to read what it does. Right-click a section in the list to switch it on or off.",
    onChange = function()
      local f = CFG.frame
      if f and f.IsShown and f:IsShown() and f.Paint then f:Paint() end
    end,
  }
end

--- BiS> Memories under the game's Esc > Options > AddOns: the kit's dashboard (Settings minor 3) - every section
--- down the left, the picked one's settings big on the right. Our options window stays as it always was (the
--- minimap's right-click); the page never holds it. Nil on a client without that panel.
function CFG.RegisterPage()
  local T = BiSTheme
  if not (T and T.SettingsPage) then return nil end
  return T.SettingsPage("BiSMemories", {
    title  = "Memories",
    about  = "A screenshot when something worth remembering happens, and a note of what it was. A new install "
      .. "takes the big moments only - level ups, first kills, achievements, firsts. Switch on the rest here.",
    status = CFG.Status,
    build  = function(body) CFG.dash = T.Dashboard(body, CFG.Model()) end,
    refresh = function() if CFG.dash then CFG.dash:Paint() end end,
    open   = { label = "your memories", func = function() if ns.J then ns.J.Show() end end },
    api    = rawget(_G, "BiSMemoriesAPI") and { name = "BiSMemoriesAPI",
      about = "read the album's memories, ask for one of your own, hear when a picture is taken" } or nil,
  })
end

function CFG.SetMinimap(on)
  CFG.MinimapDB().hide = not on
  local b = CFG.BuildMinimap()
  if b then b:SetHidden(not on) end
  return on
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  CFG.RegisterPage()     -- first, so the button's right-click and tooltip know the page is there
  CFG.BuildMinimap()
end)
