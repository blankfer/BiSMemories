--[[
  BiSMemories :: Core/Lounge.lua - THE CLIPPER LOUNGE, the journal full screen.

      /bism lounge   (lng, clipper)   open it, or shut it; the journal's LOUNGE key; Escape shuts it

  Arn, 8 Nov 2026: "I'll give you free reign on the full screen version of bis memories ... works on any monitor size
  you have all the space and freedom ... think what fact people in the 50-70s would luxury in jetliners think outside
  the box" - and, on the mockup, "Go on the clipper lounge". A 1960s jet's upper-deck lounge laid over the game:
    * the DEPARTURE BOARD across the top: your memories as flights - TIME, FLIGHT (a kind's code and its number, BOS 14),
      DESTINATION (what it was), GATE (the zone), REMARKS (FIRST KILL, FASTEST, BOARDING for the chosen one). Split-flap
      tiles: turning a page makes the letters clatter over once (L.Flip - an OnUpdate only while it runs), then sit still.
    * the WINDOW SEAT: the chosen memory's postcard (Journal.lua's J.Postcard - you, and a boss lying dead beside you)
      seen through an oval cabin window at dusk, the shade pulled down a little.
    * the BOARDING PASS (L.Pass, a ticket of its own that can be drawn anywhere): from where you were to where it
      happened, passenger, flight, seat (your level), date - and on the stub the kind, the barcode and the picture's
      file. Branded BiS> Memories, the addon's real name (Arn: "they will look up bis clipper and nothing pops up").
    * the NOTE CARD under it: the title, and where, how long, who with (in their class colours).
    * the SEAT-POCKET ROUTE MAP: Map.lua's map on paper, zoom and hollow pins, dashed arcs joining the memories in the
      order they happened.
    * the FLIGHT ENGINEER'S GAUGES: bosses, level, places, deaths, kept - needles that swing to their value once.
    * the CALL BUTTONS: EARLIER / LATER (the memory before or after), GROUP PHOTO, JOURNAL (back to the window), and a
      lit FASTEN SEATBELT sign with the memory's date.

  ANY SCREEN: the lounge is drawn at one design size (L.W x L.H, 16:9 - every place and font in it is a share of its
  width, L.U = 1% of it) and SCALED to the largest 16:9 that fits UIParent, worked out each time it opens; a font is
  never drawn smaller than L.MIN_FONT on the screen. A dark backdrop covers the rest. Nothing of it stands between the
  player and a fight: a fight shuts it at once, and it does not open in one. Nothing of it runs while it is shut.
  "The Clipper Lounge" is the room's name in the addon; on anything a picture could show, it says BiS> Memories.
]]
local ADDON, ns = ...
local T, M, J = ns.T, ns.M, ns.J
local L = {}
ns.Lounge = L

L.W, L.H = 1600, 900                 -- the design size, 16:9
L.U = L.W / 100                      -- one unit = 1% of the lounge's width (the mockup's cqw)
L.FILL = 0.98                        -- of the screen it may take
L.MIN_FONT = 9                       -- the least a word is drawn on the screen, any monitor
L.STRATA = "FULLSCREEN_DIALOG"       -- over everything (BiS Shell's ADVENT screen does the same)
L.ROWS = 5                           -- flights a page
L.TILES = { 5, 6, 30, 11, 10 }       -- TIME, FLIGHT, DESTINATION, GATE, REMARKS - tiles each
L.TILE_W, L.TILE_H, L.TILE_GAP = 1.32, 2.05, 0.12
L.COL_GAP, L.ROW_Y, L.ROW_PITCH = 0.9, 4.5, 2.4
-- THE FLIP: each tile shows L.FLIP_STEPS random letters, one every L.FLIP_STEP s, starting a little after the tile to
-- its left and the row above; then its own letter, and the ticker removes itself
L.FLIP_STEP, L.FLIP_STEPS = 0.045, { 4, 8 }
L.FLIP_COL, L.FLIP_ROW = 0.005, 0.015
L.FLAPS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:"
L.FLIP_BUDGET = 2500                 -- letters set by one flip, at most (dev/tests.lua holds it)
L.SWING = 0.9                        -- the needles' swing on opening, seconds
L.ARCS, L.DASHES, L.BULGE = 60, 5, 0.18   -- the route map: the newest 60 legs, 5 dashes each, how far an arc bows
L.OPEN_BUDGET = 10                   -- client calls to open it (dev/tests.lua: measured 2)
L.FONT = { display = "Fonts\\ARIALN.TTF", body = "Fonts\\FRIZQT__.TTF", flap = "Fonts\\ARIALN.TTF" }
L.MEDIA = "Interface\\AddOns\\" .. tostring(ADDON) .. "\\Media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
-- where each part sits, in units (1% of the width) from the lounge's top-left; the room is 100 x 56.25
L.BOARD = { 2, 2.2, 96, 17 }
L.WIN = { 3, 21.3, 24, 29.2 }        -- the window's hole (dev/art.py WIN_W x WIN_H)
L.RIM = 2.7                          -- the surround art reaches this far past the hole (dev/art.py: 1.1 + 0.4 + 1.2)
L.PASS = { 30.5, 20.5, 37, 17 }
L.CARD = { 31, 39.4, 36, 6.0 }
L.SIGN = { 31, 46.4, 26, 2.4 }
L.CALL = { 31, 50.9, 37.2, 2.9 }
L.MAP = { 69, 20.2, 29, 21.5 }
L.FE = { 69, 43, 29, 9.6 }

-- THE CABIN'S COLOURS (the mockup's), each by name
L.COLOUR = {
  night = "0d1418", teal = "1f4f57", walnut = "4a2e1c", walnutDark = "2e1c11", alu = "b9c0c4", bulk = "e7dcc4",
  white = "ffffff", flapBot = "1a1a1a", flapTop = "232323", seam = "0b0b0b", flapink = "f4f1e8", tangerine = "ff8a3d",
  sun = "ffd25a", sky = "3a7bd5", board = "1b1b1b", boardEdge = "333333", ink = "1d2a2e", paperMuted = "9c927b",
  paperText = "6a6150", paper = "e9e0c8", feTop = "2a3437", feBot = "1c2427", feEdge = "3a4649", face = "0e1416",
  arc = "3a4649", creamTop = "f0ead9", creamBot = "cfc5ab", creamShadow = "8f866e", colLabel = "8d8d8d",
  pageInk = "9a9a9a", shadeTop = "e8e1cf", shadeBot = "cfc6b1", shadeEdge = "a9a08b",
}
-- the sky at dusk, top to bottom (0-1 down the window), then the ground from L.GROUND
L.SKY = { { 0, "1b3c7a" }, { 0.48, "4d86c9" }, { 0.72, "f2b36b" } }
L.GROUND, L.EARTH = 0.73, { "6b3b2b", "3d241a" }
L.SKY_BANDS, L.EARTH_BANDS = 18, 5

local function hex3(h) return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 end
function L.Rgb(name) return hex3(L.COLOUR[name] or name) end

-- a flight's code by the memory's kind, its remark, the kind on the ticket's stub
L.CODE = { boss = "BOS", levelup = "LVL", zone = "PLC", loot = "LOT", death = "DTH", achievement = "ACH", exalted = "REP",
           first = "FST", gamba = "GMB", group = "GRP", duel = "DUL", candid = "CND", manual = "MAN" }
L.REMARK = { levelup = "ON TIME", zone = "ARRIVED", loot = "CARGO", death = "CANCELLED", achievement = "LANDED",
             exalted = "VIP", first = "MAIDEN", gamba = "JACKPOT", group = "ALL ABOARD", duel = "VICTORY",
             candid = "SCENIC", manual = "CHARTER" }
L.KIND = { boss = "BOSS", levelup = "LEVEL UP", zone = "NEW PLACE", loot = "LOOT", death = "DEATH", achievement = "ACHIEVED",
           exalted = "EXALTED", first = "FIRST", gamba = "GAMBA", group = "GROUP", duel = "DUEL", candid = "CANDID",
           manual = "BY HAND" }

local function px(n) return n * L.U end

local function hidden(v)
  if v == nil or not issecretvalue then return false end
  local ok, yes = pcall(issecretvalue, v)
  return (not ok) or yes == true
end

local function when(at, fmt)
  if not at or at == 0 or not date then return "--" end
  return date(fmt, at)
end

--- Pin `r` by its top-left at (x, y) units inside `parent`, and size it (w, h units) when given.
local function at(r, parent, x, y, w, h)
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", parent, "TOPLEFT", px(x), -px(y))
  if w then r:SetSize(px(w), px(h)) end
  return r
end

local function fill(parent, layer, colour, a)
  local t = parent:CreateTexture(nil, layer)
  local r, g, b = L.Rgb(colour)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

--- Our own art (Media/), tinted.
local function art(parent, layer, file, colour, a)
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture(L.MEDIA .. file)
  local r, g, b = L.Rgb(colour)
  t:SetVertexColor(r, g, b, a or 1)
  return t
end

--- A word, in one of the client's own fonts, its size in units (a share of the lounge's width - L.Fonts draws it no
--- smaller than L.MIN_FONT on the screen). Kept in `list` so L.Fonts can size it again when the screen changes.
local function word(list, parent, face, em, colour, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs.face, fs.em, fs.pt = face, em, px(em)
  fs:SetFont(face, fs.pt, "")
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  fs:SetJustifyH(justify or "LEFT")
  local r, g, b = L.Rgb(colour)
  fs:SetTextColor(r, g, b)
  list[#list + 1] = fs
  return fs
end

--- A word with room of its own: pinned on both sides (w units wide), so it is cut to fit (L.Put) - and the suite's fit
--- check knows its width.
local function box(fs, parent, x, y, w)
  fs:ClearAllPoints()
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", px(x), -px(y))
  fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", px(x + w), -px(y))
  fs.room = px(w)
  return fs
end

--- Text into a word, cut with "..." to its room at its drawn size.
function L.Put(fs, s)
  s = tostring(s or "")
  if fs.room then s = J.Clip(s, fs.room, fs.pt or px(fs.em or 1)) end
  fs:SetText(s)
end

--- How wide `s` is at `size` - the same measure as J.Clip (colour codes take no room).
local function width(s, size)
  s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local w = 0
  for ch in s:gmatch(".") do w = w + (ch:match("[%u%d]") and 0.75 or ch:match("%l") and 0.55 or 0.3) end
  return w * size
end

--- UTF-8 characters, one a tile (an accented name is one tile, not two).
local function chars(s)
  local out = {}
  for ch in tostring(s or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = ch end
  return out
end

--------------------------------------------------------------------- the words of a memory --

--- What it was, as a name: no link codes, no brackets, a boss without "first kill:" or its time.
function L.Name(e)
  if type(e) ~= "table" then return "" end
  local s = tostring(e.detail or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("[%[%]]", "")
  if e.reason == "boss" then s = s:gsub("^first kill: ", ""):gsub(" %- fastest yet.*$", "") end
  return s
end

function L.ZoneMain(z) z = tostring(z or "") return z:match("^(.-)%s+%-%s+") or z end
function L.ZoneSub(z) return tostring(z or ""):match("%s+%-%s+(.+)$") end

--- A zone's airport code: the first letters of its words ("Wailing Caverns" WC), one word's first three (Orgrimmar ORG).
function L.Code(z)
  local words = {}
  for w in L.ZoneMain(z):gmatch("[%a']+") do
    local lw = w:lower()
    if lw ~= "the" and lw ~= "of" then words[#words + 1] = w end
  end
  if #words == 0 then return "---" end
  if #words == 1 then return words[1]:sub(1, 3):upper() end
  local s = ""
  for i = 1, math.min(3, #words) do s = s .. words[i]:sub(1, 1) end
  return s:upper()
end

--- Every memory's flight number: its kind's code and how many of that kind came before it, counting from the first.
--- cost: once per paint, over the memories on show (250 at most) - no client call.
function L.Flights(list)
  local n, out = {}, {}
  for i = #list, 1, -1 do
    local e = list[i]
    local code = L.CODE[e.reason] or "MEM"
    n[code] = (n[code] or 0) + 1
    out[e] = code .. " " .. n[code]
  end
  return out
end

--- REMARKS: BOARDING for the chosen one; a BiS Shell game says which; a boss its first kill or fastest; else by kind.
function L.Remark(e, chosen)
  if chosen then return "BOARDING" end
  local d = tostring(e.detail or "")
  if e.from then
    local game = d:match("^(%u+)%.EXE")
    if game then return game end
  end
  if e.reason == "boss" then
    if d:find("^first kill") then return "FIRST KILL" end
    if d:find("fastest yet", 1, true) then return "FASTEST" end
    return "LANDED"
  end
  return L.REMARK[e.reason] or "ON TIME"
end

--- A flight's five cells on the board.
function L.Cells(e, chosen, flights)
  return { when(e.at, "%H:%M"), (flights and flights[e]) or (L.CODE[e.reason] or "MEM"), L.Name(e):upper(),
           L.ZoneMain(e.zone):upper(), L.Remark(e, chosen) }
end

--- The pages: L.ROWS memories each, newest first.
function L.Pages(list)
  list = list or J.Entries()
  local pages = {}
  for i, e in ipairs(list) do
    local p = math.floor((i - 1) / L.ROWS) + 1
    pages[p] = pages[p] or {}
    pages[p][#pages[p] + 1] = e
  end
  return pages
end

function L.PageOf(e, list)
  list = list or J.Entries()
  for i, x in ipairs(list) do if x == e then return math.floor((i - 1) / L.ROWS) + 1 end end
end

local function className(token)
  local names = _G.LOCALIZED_CLASS_NAMES_MALE
  if token and type(names) == "table" and names[token] then return names[token] end
  return token and (token:sub(1, 1):upper() .. token:sub(2):lower()) or nil
end

--- THE TICKET'S WORDS, from one place (Arn's next feature: a SHARE card draws the ticket alone, and its privacy switch
--- swaps every name here). `opts.private`: no names - the passenger "A TAUREN SHAMAN", the party a number.
function L.PassFields(e, list, opts)
  opts = opts or {}
  local f = { brand = "BiS> MEMORIES", title = "BOARDING PASS", stamp = "BiS> Memories", class = "FIRST" }
  if type(e) ~= "table" then
    f.fromCode, f.fromName, f.toCode, f.toName = "---", "", "---", ""
    f.passenger, f.flight, f.seat, f.date, f.gate, f.time, f.party = "--", "--", "--", "--", "--", "--", "--"
    f.kind, f.file, f.seed = "", "", 1
    return f
  end
  list = list or J.Entries()
  local prev
  for i, x in ipairs(list) do if x == e then prev = list[i + 1] end end
  f.fromCode = prev and L.Code(prev.zone) or "NEW"
  f.fromName = prev and L.ZoneMain(prev.zone):upper() or "FIRST FLIGHT"
  f.toCode, f.toName = L.Code(e.zone), L.ZoneMain(e.zone):upper()
  if opts.private then
    local race, cls = e.race, className(e.class)
    f.passenger = (race and cls) and ("A " .. race .. " " .. cls):upper() or "A TRAVELLER"
  else
    f.passenger = tostring(e.char or M.Me() or "?"):match("^[^%-]+"):upper()
  end
  f.flight = L.Flights(list)[e] or (L.CODE[e.reason] or "MEM")
  f.seat = (type(e.level) == "number" and e.level > 0) and ("LVL " .. e.level) or "--"
  f.date = when(e.at, "%d %b"):upper()
  f.time = when(e.at, "%H:%M")
  f.gate = L.ZoneMain(e.zone):upper()
  local n = type(e.with) == "table" and #e.with or 0
  f.party = n > 0 and tostring(n) or "SOLO"
  f.kind = L.KIND[e.reason] or M.Word(e.reason):upper()
  f.file = e.file and tostring(e.file):gsub("_", "\n") or "NO PICTURE"
  f.seed = tonumber(e.at) or 1
  return f
end

--- THE NOTE CARD'S WORDS, from one place too: the title, and one line - where, how long, who with in their class
--- colours (as many names as fit `opts.room` px at `opts.size`, then "+N more"). `opts.private`: "with 4 friends".
function L.CardFields(e, opts)
  opts = opts or {}
  if type(e) ~= "table" then return { title = "No memories yet", line = "It fires on levels, first kills, rare loot and more." } end
  local d = tostring(e.detail or "")
  local title = L.Name(e)
  if e.reason == "boss" and d:find("^first kill") then title = title .. " · first kill"
  elseif e.reason == "boss" and d:find("fastest yet", 1, true) then title = title .. " · fastest yet" end
  local sub, main = L.ZoneSub(e.zone), L.ZoneMain(e.zone)
  local base = e.zone and ("In " .. (sub and (sub .. ", " .. main) or main)) or ""
  if tonumber(e.secs) then
    base = base .. (base ~= "" and ", in " or "In ") .. ("%d:%02d"):format(math.floor(e.secs / 60), math.floor(e.secs % 60))
  end
  local names = type(e.with) == "table" and e.with or {}
  if #names == 0 then return { title = title, line = base } end
  local lead = base ~= "" and (base .. ", with ") or "With "
  if opts.private then
    return { title = title, line = lead .. #names .. (#names == 1 and " friend" or " friends") }
  end
  local colours = _G.RAID_CLASS_COLORS
  local function paint(i)
    local cls = type(e.withClass) == "table" and e.withClass[i]
    local cc = cls and type(colours) == "table" and colours[cls]
    local name = tostring(names[i])
    if type(cc) ~= "table" then return name end
    if type(cc.colorStr) == "string" then return "|c" .. cc.colorStr .. name .. "|r" end
    return ("|cff%02x%02x%02x"):format(math.floor(cc.r * 255), math.floor(cc.g * 255), math.floor(cc.b * 255)) .. name .. "|r"
  end
  local room, size = opts.room or math.huge, opts.size or 12
  for k = #names, 1, -1 do
    local parts = {}
    for i = 1, k do parts[i] = paint(i) end
    local list = k == 1 and parts[1] or (table.concat(parts, ", ", 1, k - 1) .. " and " .. parts[k])
    local line = lead .. list .. (k < #names and (" +" .. (#names - k) .. " more") or "")
    if width(line, size) <= room then return { title = title, line = line } end
  end
  return { title = title, line = J.Clip(lead .. #names .. " others", room, size) }
end

--- THE GAUGES' COUNTS: bosses (each once), the level, places (each zone once), deaths, memories kept.
function L.Counts(list)
  list = list or J.Entries()
  local c = { bosses = 0, level = 0, places = 0, deaths = 0, kept = #list }
  local bosses, places = {}, {}
  for _, e in ipairs(list) do
    if e.reason == "boss" then
      local name = M.BossName(e) or L.Name(e)
      if not bosses[name] then bosses[name] = true c.bosses = c.bosses + 1 end
    elseif e.reason == "death" then
      c.deaths = c.deaths + 1
    end
    local z = e.zone and L.ZoneMain(e.zone)
    if z and z ~= "" and not places[z] then places[z] = true c.places = c.places + 1 end
    if type(e.level) == "number" and e.level > c.level then c.level = e.level end
  end
  if not J.everyone and UnitLevel then
    local ok, lv = pcall(UnitLevel, "player")
    if ok and not hidden(lv) and type(lv) == "number" and lv > c.level then c.level = lv end
  end
  return c
end

--- A dial's full scale: the next round number at or above n.
function L.Scale(n)
  for _, s in ipairs({ 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000 }) do if n <= s then return s end end
  return n
end

--- A needle's angle for a share of its scale (0 at lower left, through the top, 1 at lower right), radians (-pi, pi].
function L.Angle(f)
  f = math.max(0, math.min(1, f or 0))
  local th = math.rad(225 - 270 * f)
  if th > math.pi then th = th - 2 * math.pi end
  return th
end

--------------------------------------------------------------------- the boarding pass --

L.PASS_W, L.PASS_H = 37, 17
L.PASS_GRID = {                       -- key, label, x, width (units); two rows
  { "passenger", "PASSENGER", 1.4, 10 }, { "flight", "FLIGHT", 11.867, 4.6 }, { "seat", "SEAT", 16.933, 4.6 },
  { "date", "DATE", 22.0, 4.6 },
  { "gate", "GATE", 1.4, 10 }, { "time", "TIME", 11.867, 4.6 }, { "party", "PARTY", 16.933, 4.6 },
  { "class", "CLASS", 22.0, 4.6 },
}

--- THE TICKET, a frame of its own (L.PASS_W x L.PASS_H units) on `parent`: draw it here, or alone and big on a share
--- card (SetScale it). `fonts`: the list its words join, so their size can follow the screen (L.Fonts). Its words come
--- from L.PassFields, painted by p:Paint(fields).
function L.Pass(parent, fonts)
  fonts = fonts or {}
  local p = { fonts = fonts, grid = {}, bars = {} }
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(px(L.PASS_W), px(L.PASS_H))
  p.frame = f
  fill(f, "BACKGROUND", "bulk"):SetAllPoints()
  -- the tear-off line
  for i = 0, 13 do at(fill(f, "BORDER", "paperMuted"), f, 27.9, 0.6 + i * 1.15, 0.2, 0.6) end
  p.brand = box(word(fonts, f, L.FONT.display, 1.5, "sky"), f, 1.4, 1.0, 15)
  p.title = box(word(fonts, f, L.FONT.body, 0.9, "paperMuted", "RIGHT"), f, 16.6, 1.4, 10)
  -- the route: FROM -> TO
  p.fromCode = box(word(fonts, f, L.FONT.display, 2.4, "ink"), f, 1.4, 3.6, 9)
  p.fromName = box(word(fonts, f, L.FONT.body, 0.85, "paperText"), f, 1.4, 6.6, 10)
  for i = 0, 4 do at(fill(f, "ARTWORK", "tangerine"), f, 11.6 + i * 0.75, 5.2, 0.45, 0.22) end
  p.arrow = word(fonts, f, L.FONT.display, 2.0, "tangerine")
  at(p.arrow, f, 15.4, 4.1)
  p.arrow:SetText(">")
  p.toCode = box(word(fonts, f, L.FONT.display, 2.4, "ink", "RIGHT"), f, 17, 3.6, 9.6)
  p.toName = box(word(fonts, f, L.FONT.body, 0.85, "paperText", "RIGHT"), f, 16.6, 6.6, 10)
  for i, g in ipairs(L.PASS_GRID) do
    local y = i <= 4 and 9.0 or 12.7
    local lab = box(word(fonts, f, L.FONT.body, 0.7, "paperMuted"), f, g[3], y, g[4])
    lab:SetText(g[2])
    local val = box(word(fonts, f, L.FONT.body, 0.85, "ink"), f, g[3], y + 1.15, g[4])
    p.grid[g[1]] = { lab = lab, val = val }
  end
  -- the stub
  p.kind = box(word(fonts, f, L.FONT.display, 1.1, "sky"), f, 28.9, 1.0, 7.2)
  for i = 1, 30 do
    local b = fill(f, "ARTWORK", "ink")
    b:Hide()
    p.bars[i] = b
  end
  p.file = box(word(fonts, f, L.FONT.body, 0.75, "paperText"), f, 28.9, 8.8, 7.2)
  if p.file.SetWordWrap then p.file:SetWordWrap(true) end
  p.file:SetHeight(px(4.2))
  p.stamp = box(word(fonts, f, L.FONT.display, 0.8, "sky"), f, 28.9, 14.9, 7.2)

  function p:Paint(v)
    L.Put(self.brand, v.brand)
    L.Put(self.title, v.title)
    L.Put(self.fromCode, v.fromCode)
    L.Put(self.fromName, v.fromName)
    L.Put(self.toCode, v.toCode)
    L.Put(self.toName, v.toName)
    for _, g in ipairs(L.PASS_GRID) do L.Put(self.grid[g[1]].val, v[g[1]]) end
    L.Put(self.kind, v.kind)
    self.file:SetText(v.file or "")              -- already in lines; it wraps in its own box
    L.Put(self.stamp, v.stamp)
    -- THE BARCODE: stripes of one to three widths, from the memory's own time - the same memory, the same code
    local seed, x, i = math.floor(math.abs(v.seed or 1)) % 2147483647, 0, 0
    local function nxt() seed = (seed * 16807) % 2147483647 return seed end
    while i < #self.bars do
      local w = 0.09 * (1 + nxt() % 3)
      if x + w > 7.2 then break end
      i = i + 1
      local b = self.bars[i]
      at(b, self.frame, 28.9 + x, 3.4, w, 4.6)
      b:Show()
      x = x + w + 0.09 * (1 + nxt() % 2)
    end
    for k = i + 1, #self.bars do self.bars[k]:Hide() end
  end
  return p
end

--------------------------------------------------------------------- the room --

local function keyFont(b, em)
  b.word.face, b.word.em, b.word.pt = L.FONT.display, em, px(em)
  L.fonts[#L.fonts + 1] = b.word
end

--- A tooltip for a key, then the pop again (J.Pop wraps whatever OnEnter it finds).
local function tip(b, text, more)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(text)
    if more then GameTooltip:AddLine(more, 0.75, 0.75, 0.75) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  J.Pop(b, b.word)
end

--- A CREAM CALL BUTTON: a pill (our disc's halves for its round ends), a lighter top, a shadow under it; it pops.
local function pill(parent, text, x, w, onClick)
  local h = 2.6
  local b = CreateFrame("Button", nil, parent)
  at(b, parent, x, 0, w, h)
  local function shape(colour, dy, hh, top)
    local lc = art(b, "BACKGROUND", "disc", colour)
    lc:SetTexCoord(0, 0.5, 0, 1)
    at(lc, b, 0, dy, h / 2, hh)
    local rc = art(b, "BACKGROUND", "disc", colour)
    rc:SetTexCoord(0.5, 1, 0, 1)
    at(rc, b, w - h / 2, dy, h / 2, hh)
    local mid = fill(b, "BACKGROUND", colour)
    at(mid, b, h / 2, dy + (top or 0), w - h, hh - (top or 0))
    return { lc, rc, mid }
  end
  b.shadow = shape("creamShadow", 0.25, h)
  b.body = shape("creamBot", 0, h)
  b.hi = at(fill(b, "BORDER", "creamTop", 0.9), b, h / 2, 0.2, w - h, h * 0.4)
  b.word = word(L.fonts, b, L.FONT.body, 1.0, "ink", "CENTER")
  b.word:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.word:SetText(text)
  b:SetScript("OnClick", onClick)
  J.Pop(b)
  -- the light inside the pill's straight part, the bar where its round end meets it
  b.wash:ClearAllPoints()
  b.wash:SetPoint("TOPLEFT", b, "TOPLEFT", px(h / 4), 0)
  b.wash:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -px(h / 4), 0)
  b.bar:ClearAllPoints()
  b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", px(h / 4), -px(0.3))
  b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", px(h / 4), px(0.3))
  return b
end

--- A ROUND KEY on the map (sky blue, white sign).
local function roundKey(parent, sign, x, y, onClick)
  local b = CreateFrame("Button", nil, parent)
  at(b, parent, x, y, 1.8, 1.8)
  b.disc = art(b, "BACKGROUND", "disc", "sky")
  b.disc:SetAllPoints()
  b.word = word(L.fonts, b, L.FONT.display, 1.3, "white", "CENTER")
  b.word:SetPoint("CENTER", b, "CENTER", 0, px(0.05))
  b.word:SetText(sign)
  b:SetScript("OnClick", onClick)
  return J.Pop(b)
end

local function newTile(row, x)
  local t = {}
  t.bg = at(fill(row, "BACKGROUND", "flapBot"), row, x, 0, L.TILE_W, L.TILE_H)
  t.top = at(fill(row, "BORDER", "flapTop"), row, x, 0, L.TILE_W, L.TILE_H * 0.49)
  t.seam = at(fill(row, "ARTWORK", "seam"), row, x, L.TILE_H * 0.49, L.TILE_W, 0.1)
  t.fs = word(L.fonts, row, L.FONT.flap, 1.35, "flapink", "CENTER")
  t.fs:SetPoint("CENTER", t.bg, "CENTER", 0, 0)
  t.fs:SetText(" ")
  t.want, t.showing = " ", " "
  return t
end

local function buildBoard(room)
  local B = CreateFrame("Frame", nil, room)
  at(B, room, L.BOARD[1], L.BOARD[2], L.BOARD[3], L.BOARD[4])
  B:SetFrameLevel(40)
  fill(B, "BACKGROUND", "board"):SetAllPoints()
  local e = 0.25
  at(fill(B, "BORDER", "boardEdge"), B, 0, 0, L.BOARD[3], e)
  at(fill(B, "BORDER", "boardEdge"), B, 0, L.BOARD[4] - e, L.BOARD[3], e)
  at(fill(B, "BORDER", "boardEdge"), B, 0, 0, e, L.BOARD[4])
  at(fill(B, "BORDER", "boardEdge"), B, L.BOARD[3] - e, 0, e, L.BOARD[4])
  local head = word(L.fonts, B, L.FONT.display, 1.5, "sun")
  at(head, B, 1.2, 0.8)
  head:SetText("DEPARTURES")
  L.pageLabel = box(word(L.fonts, B, L.FONT.body, 1.0, "pageInk", "RIGHT"), B, 46, 1.0, 39.6)
  L.keys = {}
  L.keys.later = J.Key(B, px(2.4), px(1.9), "<", function() L.Turn(-1) end)
  at(L.keys.later, B, 86.4, 0.6)
  keyFont(L.keys.later, 1.1)
  tip(L.keys.later, "later memories", "the newer page")
  L.keys.earlier = J.Key(B, px(2.4), px(1.9), ">", function() L.Turn(1) end)
  at(L.keys.earlier, B, 89.4, 0.6)
  keyFont(L.keys.earlier, 1.1)
  tip(L.keys.earlier, "earlier memories", "the older page")
  L.keys.close = J.Key(B, px(2.4), px(1.9), "X", function() L.Hide() end)
  at(L.keys.close, B, 92.4, 0.6)
  keyFont(L.keys.close, 1.1)
  -- the columns
  local x = 1.2
  L.colX = {}
  for i, name in ipairs({ "TIME", "FLIGHT", "DESTINATION", "GATE", "REMARKS" }) do
    L.colX[i] = x
    local c = word(L.fonts, B, L.FONT.body, 0.85, "colLabel")
    at(c, B, x, 3.1)
    c:SetText(name)
    x = x + L.TILES[i] * (L.TILE_W + L.TILE_GAP) - L.TILE_GAP + L.COL_GAP
  end
  B.rows = {}
  for r = 1, L.ROWS do
    local row = CreateFrame("Button", nil, B)
    at(row, B, 0.6, L.ROW_Y + (r - 1) * L.ROW_PITCH, L.BOARD[3] - 1.2, L.TILE_H)
    row.tiles = {}
    local n = 0
    for c = 1, #L.TILES do
      row.tiles[c] = {}
      for j = 1, L.TILES[c] do
        n = n + 1
        local t = newTile(row, L.colX[c] - 0.6 + (j - 1) * (L.TILE_W + L.TILE_GAP))
        t.order, t.col, t.row = n, c, r
        row.tiles[c][j] = t
      end
    end
    -- the light lies over the tiles (under their letters), so it is a tint; the bar does the popping
    row.wash = row:CreateTexture(nil, "ARTWORK")
    local ar, ag, ab = T.rgb("accent")
    row.wash:SetColorTexture(ar, ag, ab, 1)
    row.popIf = function(self) return self.entry ~= nil end
    row:SetScript("OnClick", function(self) if self.entry then L.Select(self.entry) end end)
    row:SetScript("OnEnter", function(self) if self.entry then J.Tip(self, self.entry, true) end end)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    J.Pop(row, nil, true)
    B.rows[r] = row
  end
  B:EnableMouseWheel(true)
  B:SetScript("OnMouseWheel", function(_, delta) L.Turn((delta or 0) > 0 and -1 or 1) end)
  return B
end

local function mixHex(a, b, t)
  local ar, ag, ab = hex3(a)
  local br, bg, bb = hex3(b)
  return ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t
end

--- The sky's colour at a share of the way down (L.SKY's stops).
local function skyAt(y)
  for i = 1, #L.SKY - 1 do
    local a, b = L.SKY[i], L.SKY[i + 1]
    if y <= b[1] then return mixHex(a[2], b[2], (y - a[1]) / (b[1] - a[1])) end
  end
  return hex3(L.SKY[#L.SKY][2])
end

local function buildWindow(room)
  local w, h = L.WIN[3], L.WIN[4]
  local S = CreateFrame("Frame", nil, room)
  at(S, room, L.WIN[1], L.WIN[2], w, h)
  S:SetFrameLevel(5)
  if S.SetClipsChildren then S:SetClipsChildren(true) end   -- the models' box stops at the window's
  -- the sky at dusk, in bands, and the ground
  L.sky = {}
  local skyH = h * L.GROUND
  for i = 1, L.SKY_BANDS do
    local t = S:CreateTexture(nil, "BACKGROUND")
    local r, g, b = skyAt((i - 0.5) / L.SKY_BANDS * L.GROUND)
    t:SetColorTexture(r, g, b, 1)
    at(t, S, 0, (i - 1) * skyH / L.SKY_BANDS, w, skyH / L.SKY_BANDS + 0.02)
    L.sky[#L.sky + 1] = t
  end
  for i = 1, L.EARTH_BANDS do
    local t = S:CreateTexture(nil, "BACKGROUND")
    local r, g, b = mixHex(L.EARTH[1], L.EARTH[2], (i - 1) / (L.EARTH_BANDS - 1))
    t:SetColorTexture(r, g, b, 1)
    local gh = (h - skyH) / L.EARTH_BANDS
    at(t, S, 0, skyH + (i - 1) * gh, w, gh + 0.02)
    t.ground = true
    L.sky[#L.sky + 1] = t
  end
  -- the shade, pulled down a little
  L.shade = at(fill(S, "ARTWORK", "shadeBot"), S, 0, 0, w, h * 0.09)
  at(fill(S, "ARTWORK", "shadeTop"), S, 0, 0, w, h * 0.045)
  at(fill(S, "ARTWORK", "shadeEdge"), S, 0, h * 0.09, w, 0.2)
  -- the postcard: Journal.lua's, drawn into this window (J.Postcard(e, L.post))
  local post = CreateFrame("Frame", nil, S)
  at(post, S, 0, 0, w, h)
  post:SetFrameLevel(6)
  post.you = CreateFrame("DressUpModel", nil, post)
  at(post.you, post, 1.0, 7.8, 10.5, 19)
  post.you:SetFrameLevel(7)
  post.them = CreateFrame("DressUpModel", nil, post)
  at(post.them, post, 8.5, 11.2, 15, 15.6)
  post.them:SetFrameLevel(7)
  post.note = box(word(L.fonts, post, L.FONT.body, 0.85, "bulk", "CENTER"), post, 1, h - 2.6, w - 2)
  if post.note.SetWordWrap then post.note:SetWordWrap(true) end
  post.note:SetHeight(px(2.4))
  L.post = post
  -- OUR OWN SURROUND (Media/window.tga): the cream frame, its lip, the cabin's teal over the box's corners - over the
  -- models, so nothing of them shows past the oval
  local sur = CreateFrame("Frame", nil, room)
  at(sur, room, L.WIN[1] - L.RIM, L.WIN[2] - L.RIM, w + 2 * L.RIM, h + 2 * L.RIM)
  sur:SetFrameLevel(30)
  sur.art = sur:CreateTexture(nil, "ARTWORK")
  sur.art:SetTexture(L.MEDIA .. "window")
  sur.art:SetAllPoints()
  L.surround = sur
  L.winLabel = box(word(L.fonts, room, L.FONT.body, 1.05, "alu", "CENTER"), room, L.WIN[1], 53.3, w)
  return S
end

local function buildCard(room)
  local c = CreateFrame("Frame", nil, room)
  at(c, room, L.CARD[1], L.CARD[2], L.CARD[3], L.CARD[4])
  L.card = {
    frame = c,
    title = box(word(L.fonts, c, L.FONT.display, 2.1, "white"), c, 0, 0, L.CARD[3]),
    line = box(word(L.fonts, c, L.FONT.body, 1.15, "bulk"), c, 0, 2.9, L.CARD[3]),
  }
  -- the line may take two lines (who was there is worth the room)
  if L.card.line.SetWordWrap then L.card.line:SetWordWrap(true) end
  L.card.line:SetHeight(px(3.0))
  -- the lit sign
  local s = CreateFrame("Frame", nil, room)
  at(s, room, L.SIGN[1], L.SIGN[2], L.SIGN[3], L.SIGN[4])
  fill(s, "BACKGROUND", "sun", 0.08):SetAllPoints()
  local e = 0.15
  at(fill(s, "BORDER", "sun"), s, 0, 0, L.SIGN[3], e)
  at(fill(s, "BORDER", "sun"), s, 0, L.SIGN[4] - e, L.SIGN[3], e)
  at(fill(s, "BORDER", "sun"), s, 0, 0, e, L.SIGN[4])
  at(fill(s, "BORDER", "sun"), s, L.SIGN[3] - e, 0, e, L.SIGN[4])
  L.sign = { frame = s, text = box(word(L.fonts, s, L.FONT.body, 0.95, "sun", "CENTER"), s, 0.8, 0.65, L.SIGN[3] - 1.6) }
end

local function buildCall(room)
  local c = CreateFrame("Frame", nil, room)
  at(c, room, L.CALL[1], L.CALL[2], L.CALL[3], L.CALL[4])
  L.call = { frame = c }
  L.call.earlier = pill(c, "< EARLIER", 0, 8.2, function() L.Step(1) end)
  L.call.earlier.popIf = function() return L.Neighbour(1) ~= nil end
  L.call.later = pill(c, "LATER >", 9.0, 7.6, function() L.Step(-1) end)
  L.call.later.popIf = function() return L.Neighbour(-1) ~= nil end
  L.call.photo = pill(c, "GROUP PHOTO", 17.4, 10.6, function()
    local ok, why = M.GroupPhoto()
    if not ok then ns.Print("no group photo - %s", tostring(why)) end
  end)
  L.call.journal = pill(c, "JOURNAL", 28.8, 8.4, function() L.ToJournal() end)
end

local function buildMap(room)
  local P = CreateFrame("Frame", nil, room)
  at(P, room, L.MAP[1], L.MAP[2], L.MAP[3], L.MAP[4])
  fill(P, "BACKGROUND", "paper"):SetAllPoints()
  local head = box(word(L.fonts, P, L.FONT.display, 0.95, "sky"), P, 1, 0.75, 21.8)
  head:SetText("ROUTE MAP · YOUR JOURNEY")
  local map = CreateFrame("Frame", nil, P)
  at(map, P, 0.7, 2.6, L.MAP[3] - 1.4, L.MAP[4] - 3.3)
  local e = 0.1
  at(fill(P, "BORDER", "paperMuted"), P, 0.7 - e, 2.6 - e, L.MAP[3] - 1.4 + 2 * e, L.MAP[4] - 3.3 + 2 * e)
  fill(map, "BACKGROUND", "paper"):SetAllPoints()
  -- the map on paper: the art without its colours, tinted; tangerine pins, the chosen one sky blue, a merged box in ink
  map.paper = { 0.93, 0.87, 0.73 }
  map.pal = { one = { L.Rgb("tangerine") }, many = { L.Rgb("ink") }, sel = { L.Rgb("sky") } }
  ns.MapView.Glass(map)
  map.onView = function() if L.back and L.back:IsShown() then L.PaintMap() end end
  L.map, L.paper, L.lines = map, P, {}
  L.zoomIn = roundKey(P, "+", 24.4, 0.4, function() ns.MapView.Zoom(map, 1) end)
  L.zoomOut = roundKey(P, "-", 26.5, 0.4, function() ns.MapView.Zoom(map, -1) end)
  L.noArt = box(word(L.fonts, P, L.FONT.body, 0.9, "paperText", "CENTER"), P, 1, 10.5, L.MAP[3] - 2)
  L.noArt:SetText("NO MAP ART FROM THE GAME HERE")
  L.noArt:Hide()
  return P
end

local function line(parent, layer, colour, thick)
  local ln = parent:CreateLine(nil, layer)
  ln:SetTexture(WHITE)
  local r, g, b = L.Rgb(colour)
  ln:SetVertexColor(r, g, b, 1)
  ln:SetThickness(px(thick))
  return ln
end

local function buildGauges(room)
  local F = CreateFrame("Frame", nil, room)
  at(F, room, L.FE[1], L.FE[2], L.FE[3], L.FE[4])
  at(fill(F, "BACKGROUND", "feTop"), F, 0, 0, L.FE[3], L.FE[4] / 2)
  at(fill(F, "BACKGROUND", "feBot"), F, 0, L.FE[4] / 2, L.FE[3], L.FE[4] / 2)
  local e = 0.15
  at(fill(F, "BORDER", "feEdge"), F, 0, 0, L.FE[3], e)
  at(fill(F, "BORDER", "feEdge"), F, 0, L.FE[4] - e, L.FE[3], e)
  at(fill(F, "BORDER", "feEdge"), F, 0, 0, e, L.FE[4])
  at(fill(F, "BORDER", "feEdge"), F, L.FE[3] - e, 0, e, L.FE[4])
  L.gauges = {}
  local cell, gap, D = (L.FE[3] - 1.6 - 1.2) / 5, 0.3, 5.0
  local R = px(D / 2)
  for i, g in ipairs({ { "bosses", "BOSSES" }, { "level", "LEVEL" }, { "places", "PLACES" }, { "deaths", "DEATHS" },
                       { "kept", "KEPT" } }) do
    local x = 0.8 + (i - 1) * (cell + gap)
    local G = { key = g[1], value = 0, max = 5, shown = 0, len = 0.64 * R }
    G.face = at(art(F, "ARTWORK", "disc", "face"), F, x + (cell - D) / 2, 1.0, D, D)
    G.bezel = at(art(F, "OVERLAY", "ring", "alu"), F, x + (cell - D) / 2, 1.0, D, D)
    -- the scale: an arc of short Lines through the top, ticks at every quarter
    G.arc = {}
    local ra, steps = 0.74 * R, 12
    for s = 0, steps - 1 do
      local a0, a1 = L.Angle(s / steps), L.Angle((s + 1) / steps)
      local ln = line(F, "ARTWORK", "arc", 0.22)
      ln:SetStartPoint("CENTER", G.face, math.cos(a0) * ra, math.sin(a0) * ra)
      ln:SetEndPoint("CENTER", G.face, math.cos(a1) * ra, math.sin(a1) * ra)
      G.arc[#G.arc + 1] = ln
    end
    for s = 0, 4 do
      local a = L.Angle(s / 4)
      local ln = line(F, "ARTWORK", "alu", 0.12)
      ln:SetStartPoint("CENTER", G.face, math.cos(a) * 0.6 * R, math.sin(a) * 0.6 * R)
      ln:SetEndPoint("CENTER", G.face, math.cos(a) * 0.82 * R, math.sin(a) * 0.82 * R)
    end
    G.needle = line(F, "OVERLAY", g[1] == "deaths" and "tangerine" or "sun", 0.16)
    G.needle:SetStartPoint("CENTER", G.face, 0, 0)
    G.hub = art(F, "OVERLAY", "disc", "alu")
    G.hub:SetSize(px(0.55), px(0.55))
    G.hub:SetPoint("CENTER", G.face, "CENTER", 0, 0)
    G.num = word(L.fonts, F, L.FONT.body, 0.85, "flapink", "CENTER")
    G.num:SetPoint("CENTER", G.face, "CENTER", 0, -0.48 * R)
    G.label = box(word(L.fonts, F, L.FONT.body, 0.72, "alu", "CENTER"), F, x, 1.0 + D + 0.55, cell)
    G.label:SetText(g[2])
    L.gauges[i] = G
  end
  return F
end

function L.Build()
  if L.back then return L.back end
  L.fonts = {}
  local back = CreateFrame("Frame", "BiSMemoriesLounge", UIParent)
  L.back = back
  back:SetAllPoints(UIParent)
  back:SetFrameStrata(L.STRATA)
  back:SetFrameLevel(1)
  back:EnableMouse(true)                -- the world behind is not clicked through the lounge
  fill(back, "BACKGROUND", "night", 0.92):SetAllPoints()
  local room = CreateFrame("Frame", nil, back)
  L.room = room
  room:SetSize(L.W, L.H)
  room:SetPoint("CENTER", back, "CENTER", 0, 0)
  room:SetFrameLevel(2)
  fill(room, "BACKGROUND", "teal"):SetAllPoints()
  -- walnut trim, top and bottom
  local hU = L.H / L.U
  at(fill(room, "BORDER", "walnut"), room, 0, 0, 100, 1.1)
  at(fill(room, "BORDER", "walnutDark"), room, 0, 0.6, 100, 0.5)
  at(fill(room, "BORDER", "walnut"), room, 0, hU - 1.1, 100, 1.1)
  at(fill(room, "BORDER", "walnutDark"), room, 0, hU - 0.5, 100, 0.5)
  -- shadows under the board and the ticket
  at(fill(room, "BORDER", "night", 0.45), room, L.BOARD[1] + 0.3, L.BOARD[2] + L.BOARD[4], L.BOARD[3] - 0.6, 0.5)
  at(fill(room, "BORDER", "night", 0.4), room, L.PASS[1] + 0.35, L.PASS[2] + 0.6, L.PASS[3], L.PASS[4])
  L.board = buildBoard(room)
  L.seat = buildWindow(room)
  L.pass = L.Pass(room, L.fonts)
  at(L.pass.frame, room, L.PASS[1], L.PASS[2])
  buildCard(room)
  buildCall(room)
  buildMap(room)
  L.fe = buildGauges(room)
  L.parts = { board = L.board, seat = L.seat, surround = L.surround, pass = L.pass.frame, card = L.card.frame,
              sign = L.sign.frame, call = L.call.frame, map = L.paper, gauges = L.fe }
  -- ESCAPE CLOSES IT (the family's rule); a FIGHT closes it at once
  if UISpecialFrames then table.insert(UISpecialFrames, "BiSMemoriesLounge") end
  back:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
      L.Hide()
      ns.Print("the lounge closed for the fight")
    end
  end)
  back:Hide()
  -- shut (Escape, X, a fight, anything): nothing of it runs on, and the window is asked afresh next time - set AFTER
  -- that first Hide (a frame is made shown)
  back:SetScript("OnHide", function(self)
    L.StopFlip()
    L.StopSwing()
    if ns.MapView and L.map then ns.MapView.StopDrag(L.map) end
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    L.post.postFor = nil
  end)
  return back
end

--- How big it is drawn: the largest 16:9 that fits the screen (UIParent's size, asked each time it opens).
function L.Size()
  local sw = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1024
  local sh = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
  if sw <= 0 or sh <= 0 then sw, sh = 1024, 768 end
  return math.min(sw * L.FILL / L.W, sh * L.FILL / L.H)
end

--- Every word at its size for this screen: its share of the lounge, never under L.MIN_FONT once scaled by `k`.
function L.Fonts(k)
  local least = L.MIN_FONT / k
  for _, fs in ipairs(L.fonts) do
    local s = math.max(px(fs.em or 1), least)
    if fs.face then fs:SetFont(fs.face, s, "") end
    fs.pt = s
  end
end

--------------------------------------------------------------------- the flip --

function L.FlipLongest()
  local tiles = 0
  for _, n in ipairs(L.TILES) do tiles = tiles + n end
  return (tiles - 1) * L.FLIP_COL + (L.ROWS - 1) * L.FLIP_ROW + L.FLIP_STEPS[2] * L.FLIP_STEP
end

local function flapChar()
  local i = math.random(2, #L.FLAPS)
  return L.FLAPS:sub(i, i)
end

local function setTile(t, ch)
  t.showing = ch
  t.fs:SetText(ch)
end

--- THE LETTERS CLATTER OVER, ONCE: every tile with something to show (or to clear) cycles a few random letters, a
--- little after its neighbour, and lands. An OnUpdate only while it runs; it removes itself.
function L.Flip()
  if L.flip then for _, t in ipairs(L.flip.tiles) do t.flipping = false end end
  local act = {}
  for _, row in ipairs(L.board.rows) do
    for _, col in ipairs(row.tiles) do
      for _, t in ipairs(col) do
        if t.want ~= " " or t.showing ~= " " then
          t.start = (t.order - 1) * L.FLIP_COL + (t.row - 1) * L.FLIP_ROW
          t.steps = math.random(L.FLIP_STEPS[1], L.FLIP_STEPS[2])
          t.k, t.done, t.flipping = -1, false, true
          setTile(t, flapChar())
          act[#act + 1] = t
        end
      end
    end
  end
  L.flip = { t = 0, tiles = act }
  L.board:SetScript("OnUpdate", #act > 0 and L.FlipTick or nil)
end

function L.FlipTick(self, elapsed)
  local fl = L.flip
  if not fl then return self:SetScript("OnUpdate", nil) end
  fl.t = fl.t + (elapsed or 0)
  local left = 0
  for _, t in ipairs(fl.tiles) do
    if not t.done then
      local k = math.floor((fl.t - t.start) / L.FLIP_STEP)
      if k >= t.steps then
        setTile(t, t.want)
        t.done, t.flipping = true, false
      else
        left = left + 1
        if k >= 0 and k ~= t.k then
          t.k = k
          setTile(t, flapChar())
        end
      end
    end
  end
  if left == 0 then L.StopFlip() end
end

--- Stop the flip where it is: every tile shows its own letter.
function L.StopFlip()
  local fl = L.flip
  L.flip = nil
  if L.board then L.board:SetScript("OnUpdate", nil) end
  if not fl then return end
  for _, t in ipairs(fl.tiles) do
    if not t.done then setTile(t, t.want) end
    t.flipping = false
  end
end

--------------------------------------------------------------------- the needles --

local function needle(G, v)
  local th = L.Angle(v / G.max)
  G.needle:SetEndPoint("CENTER", G.face, math.cos(th) * G.len, math.sin(th) * G.len)
end

function L.Swing()
  L.swing = { t = 0 }
  for _, G in ipairs(L.gauges) do needle(G, 0) end
  L.fe:SetScript("OnUpdate", L.SwingTick)
end

function L.SwingTick(self, elapsed)
  local s = L.swing
  if not s then return self:SetScript("OnUpdate", nil) end
  s.t = s.t + (elapsed or 0)
  local f = math.min(1, s.t / L.SWING)
  local ease = 1 - (1 - f) ^ 3
  for _, G in ipairs(L.gauges) do needle(G, G.value * ease) end
  if f >= 1 then L.StopSwing() end
end

--- Stop the swing: every needle at its value.
function L.StopSwing()
  L.swing = nil
  if L.fe then L.fe:SetScript("OnUpdate", nil) end
  for _, G in ipairs(L.gauges or {}) do needle(G, G.value) end
end

--------------------------------------------------------------------- painting --

function L.PaintBoard(flip)
  local B, list = L.board, L.list
  local pages = L.Pages(list)
  local np = math.max(1, #pages)
  L.pageNo = math.max(1, math.min(np, L.pageNo or 1))
  L.Put(L.pageLabel, ("BiS> MEMORIES · PAGE %d OF %d"):format(L.pageNo, np))
  local page = pages[L.pageNo] or {}
  local sun, cream, tang = { L.Rgb("sun") }, { L.Rgb("flapink") }, { L.Rgb("tangerine") }
  for r, row in ipairs(B.rows) do
    local e = page[r]
    row.entry = e
    local chosen = e ~= nil and e == J.sel
    local cells = e and L.Cells(e, chosen, L.flights) or {}
    for c, col in ipairs(row.tiles) do
      local ch = chars((cells[c] or ""):upper())
      local ink = c == 5 and tang or (chosen and sun or cream)
      for j, t in ipairs(col) do
        t.want = ch[j] or " "
        t.fs:SetTextColor(ink[1], ink[2], ink[3])
        if not flip and not t.flipping then setTile(t, t.want) end
      end
    end
  end
  if flip then L.Flip() end
end

function L.PaintSeat()
  local e = J.sel
  J.Postcard(e, L.post)
  L.post.note:SetTextColor(L.Rgb("bulk"))
  if type(e) ~= "table" then
    L.post.you:Hide()
    L.post.them:Hide()
    L.post.note:SetText("no memories yet")
  end
  L.Put(L.winLabel, "WINDOW SEAT · " .. (e and when(e.at, "%H:%M") or "--:--"))
end

function L.PaintCard()
  local e = J.sel
  local c = L.card
  -- two lines' room, less what a wrap between words can waste
  local v = L.CardFields(e, { room = c.line.room * 2 * 0.88, size = c.line.pt })
  L.Put(c.title, v.title)
  c.line:SetText(v.line)                       -- fitted name by name in CardFields, colours kept
  L.Put(L.sign.text, "FASTEN SEATBELT · " .. (e and when(e.at, "%a %d %b"):upper() or "--"))
end

--- The memory `by` steps older (+1) or newer (-1) than the chosen one, or nil.
function L.Neighbour(by)
  local list = L.list or J.Entries()
  for i, x in ipairs(list) do if x == J.sel then return list[i + by] end end
end

function L.PaintCall()
  L.call.earlier:SetAlpha(L.Neighbour(1) and 1 or 0.45)
  L.call.later:SetAlpha(L.Neighbour(-1) and 1 or 0.45)
end

--- THE ROUTE: dashed arcs joining the memories on the map in the order they happened (the newest L.ARCS legs). Each
--- leg bows a little to its left; a leg with both ends off the paper, or no length, draws nothing but still counts.
--- cost: once per map repaint, over the memories on the map (250 at most) - no client call.
function L.Arcs(list, mapID, drawn)
  for _, ln in ipairs(L.lines) do ln:Hide() end
  L.arcs = {}
  if not drawn then return end
  local MV, map = ns.MapView, L.map
  local dots = MV.Dots(list, mapID)
  table.sort(dots, function(a, b) return (tonumber(a.e.at) or 0) < (tonumber(b.e.at) or 0) end)
  local pw, ph = map:GetWidth(), map:GetHeight()
  local used = 0
  local sr, sg, sb = L.Rgb("sky")
  for i = math.max(1, #dots - L.ARCS), #dots - 1 do
    local a, b = dots[i], dots[i + 1]
    local arc = { from = a.e, to = b.e, lines = {} }
    L.arcs[#L.arcs + 1] = arc
    local ax, ay = MV.ToScreen(map, a.x, a.y)
    local bx, by = MV.ToScreen(map, b.x, b.y)
    local dx, dy = bx - ax, by - ay
    local dist = math.sqrt(dx * dx + dy * dy)
    local off = (ax < 0 and bx < 0) or (ax > pw and bx > pw) or (ay < 0 and by < 0) or (ay > ph and by > ph)
    if dist >= 2 and not off then
      local cx, cy = (ax + bx) / 2 + dy * L.BULGE, (ay + by) / 2 - dx * L.BULGE
      local function on(t)
        local u = 1 - t
        return u * u * ax + 2 * u * t * cx + t * t * bx, u * u * ay + 2 * u * t * cy + t * t * by
      end
      local parts = 2 * L.DASHES - 1
      for k = 0, L.DASHES - 1 do
        local x0, y0 = on((2 * k) / parts)
        local x1, y1 = on((2 * k + 1) / parts)
        used = used + 1
        local ln = L.lines[used]
        if not ln then
          ln = map.canvas:CreateLine(nil, "ARTWORK")
          ln:SetTexture(WHITE)
          ln:SetThickness(px(0.16))
          L.lines[used] = ln
        end
        ln:SetVertexColor(sr, sg, sb, 1)
        ln:SetStartPoint("TOPLEFT", map.canvas, x0, -y0)
        ln:SetEndPoint("TOPLEFT", map.canvas, x1, -y1)
        ln:Show()
        arc.lines[#arc.lines + 1] = ln
      end
    end
  end
end

function L.PaintMap()
  local MV = ns.MapView
  local list = L.list or J.Entries()
  local mapID = MV.Start()
  local n
  if mapID then n = MV.Draw(L.map, list, mapID, function(e) L.Select(e) end, J.sel) end
  L.noArt:SetShown(not n)
  -- a merged box's count: in the lounge's face, at its size for this screen (Map.lua makes pins as it needs them)
  for _, b in ipairs(L.map.dots or {}) do
    local fs = b.count
    if fs and not fs.face then
      fs.face, fs.em = L.FONT.display, 0.9
      L.fonts[#L.fonts + 1] = fs
      local s = math.max(px(fs.em), L.MIN_FONT / (L.k or 1))
      fs:SetFont(fs.face, s, "")
      fs.pt = s
    end
  end
  L.Arcs(list, mapID, n ~= nil)
end

function L.PaintGauges()
  local c = L.Counts(L.list)
  for _, G in ipairs(L.gauges) do
    G.value = c[G.key] or 0
    G.max = G.key == "level" and (G.value <= 60 and 60 or L.Scale(G.value)) or L.Scale(G.value)
    G.value = math.min(G.value, G.max)
    G.num:SetText(tostring(c[G.key] or 0))
    if not L.swing then needle(G, G.value) end
  end
end

--- Paint it all. `flip`: the board's letters clatter over (a page turn, the lounge opening).
function L.Paint(flip)
  L.list = J.Entries()
  L.flights = L.Flights(L.list)
  L.PaintBoard(flip)
  L.PaintSeat()
  L.pass:Paint(L.PassFields(J.sel, L.list))
  L.PaintCard()
  L.PaintCall()
  L.PaintMap()
  L.PaintGauges()
end

--------------------------------------------------------------------- using it --

local function shown() return L.back ~= nil and L.back:IsShown() end

--- Choose a memory: the window, the ticket, the card follow; the board turns to its page (clattering only then).
function L.Select(e)
  J.sel = e
  local p = L.PageOf(e, L.list)
  local turned = p ~= nil and p ~= L.pageNo
  if p then L.pageNo = p end
  if shown() then L.Paint(turned) end
  return e
end

--- EARLIER (+1) / LATER (-1): the memory before or after the chosen one.
function L.Step(by)
  local e = L.Neighbour(by)
  if e then L.Select(e) end
  return J.sel
end

--- Turn the board's page by `by` (+ older), clamped; the letters clatter when it moved.
function L.Turn(by)
  local n = math.max(1, #L.Pages(L.list))
  local was = L.pageNo or 1
  L.pageNo = math.max(1, math.min(n, was + (by or 0)))
  if shown() and L.pageNo ~= was then L.Paint(true) end
  return L.pageNo
end

--- In a fight? (the client's own answer; anything but a plain false is a yes)
function L.InFight()
  if not InCombatLockdown then return false end
  local ok, yes = pcall(InCombatLockdown)
  if not ok or hidden(yes) then return true end
  return yes == true
end

function L.Show()
  if L.InFight() then
    ns.Print("the lounge opens once the fight is over")
    return false
  end
  local back = L.Build()
  if J.frame and J.frame:IsShown() then J.Hide() end
  local k = L.Size()
  L.k = k
  L.room:SetScale(k)
  L.Fonts(k)
  back:Show()                                  -- shown before it is painted: a hidden model loads nothing
  back:RegisterEvent("PLAYER_REGEN_DISABLED")
  L.post.postFor = nil
  L.list = J.Entries()
  local found = false
  for _, x in ipairs(L.list) do if x == J.sel then found = true end end
  if not found then J.sel = L.list[1] end
  L.pageNo = L.PageOf(J.sel, L.list) or 1
  L.swing = { t = 0 }                          -- the needles start from nothing
  L.Paint(true)
  L.Swing()
  return true
end

function L.Hide()
  if L.back then L.back:Hide() end
  return true
end

function L.Toggle()
  if shown() then return L.Hide() end
  return L.Show()
end

--- Back to the windowed journal, on the same memory.
function L.ToJournal()
  L.Hide()
  J.Show()
end

--- A memory landed: an open lounge is painted again (no clatter).
function L.Touch()
  if shown() then L.Paint(false) end
end
