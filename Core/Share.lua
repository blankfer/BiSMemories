--[[
  BiSMemories :: Core/Share.lua - THE SHARE CARD: one picture of one memory, made to be posted.

      /bism share [n]            the newest memory's card (n: the n-th newest); the journal's and the lounge's SHARE keys
      /bism share names on|off   names on the card, or hidden (hidden from the start, for everyone)

  Arn, 8 Nov 2026: "maybe a way to save to social media? ... save to a file on their computer of only the ticket stub
  thing ... they go on twitter and they can upload their dungeon clear or boss taken down maybe all the loot that
  dropped all the party they were in option for privacy if they don't want to share in game name. Something shareable
  and to show accomplishments" - and, on the mockup, "Just say post it anywhere, sure keep name hidden".

  The game can only photograph the whole screen. So for the instant of the picture the whole screen IS the card: the
  lounge's boarding pass drawn big and alone on the lounge's teal with walnut trim, on a frame of its own that is NOT
  inside UIParent - the clean shot (M.Clean) fades the interface out and leaves the card. Its oval window holds the
  postcard (Journal.lua's J.Postcard: you, and a boss lying dead). A few frames for the models to draw (S.Ready, looked
  at every S.STEP s, S.WAIT_MAX at most), ONE Screenshot(), and the card goes - when the client says the picture is
  written, or S.BACK s later whatever happens - and the interface, the journal or the lounge come back. Its note (kind
  "share") keeps the ticket's rectangle as fractions of the screen (S.Rect), so the album page cuts the ticket out of
  the picture and saves it (Album/BiSMemories-Album.html).

  PRIVACY, ON FROM THE START (`shareHidden`, written into every save once - Init.lua ns.ADDED): the passenger is the
  class ("A SHAMAN"), the crew "4 friends: rogue, hunter, druid, mage" in class colours; never a realm, a guild or a
  character's name anywhere on it. Branded BiS> Memories on the ticket and on the stamp, so whoever sees the picture
  can find the addon (Arn: "they will look up bis clipper and nothing pops up").
  Never in a fight (it would cover the screen): refused, and a fight that starts closes it at once.
  Nothing of it runs while it is put away: no OnUpdate, and a timer left waiting finds its card gone and does nothing.
]]
local ADDON, ns = ...
local M, J, L = ns.M, ns.J, ns.Lounge
local S = {}
ns.Share = S

-- THE PRIVACY SWITCH, a setting added after 1.0: a new install starts hidden (ns.DEFAULTS), and an existing save gets
-- it WRITTEN in once (ns.ADDED, Init.lua) - never read off nil
ns.DEFAULTS.shareHidden = true
ns.SHARE_STAMP = "share1"
ns.ADDED[#ns.ADDED + 1] = { stamp = ns.SHARE_STAMP, values = { shareHidden = true } }

S.W, S.H = L.W, L.H                   -- the lounge's design size, 16:9, in its units (1% of the width)
S.TICKET = { 7, 12, 86, 32.25 }       -- the mockup's .ticket: 7 in from each side, 12 down from the top and up from the foot
S.SEAT_W, S.STUB_W = 22, 17           -- the oval's column and the stub
S.OVAL = { 3.5, 5.125, 15, 22 }       -- the window's box in the ticket, centred in the seat (dev/art.py OVAL_W x OVAL_H)
S.RIM = 1.2                           -- the oval art reaches this far past it (dev/art.py OVAL_RING + OVAL_EDGE)
S.TRIM = 1.2                          -- the walnut trim along the top and the foot of the screen
S.MAIN_X, S.MAIN_W = 24.4, 42.2       -- the middle column's words
S.STUB_X, S.STUB_IN = 70.8, 13.4      -- the stub's words
S.TITLE_EM = { 3.6, 2.4 }             -- the title's size, and the least it shrinks to before it is cut
S.FIELDS = { { "passenger", "PASSENGER", 0, 14 }, { "seat", "SEAT", 14.6, 7.2 }, { "date", "DATE", 22.4, 12 },
             { "time", "TIME", 35, 7.2 } }
S.BARS = 48
S.STEP, S.WAIT_MAX = 0.1, 2.0         -- the models are looked at every 0.1 s, 2 s at most, before the picture
S.BACK = 2                            -- the card goes this long after its picture, whatever the client says
S.BUDGET = 8                          -- client calls to put a card up (dev/tests.lua holds it: measured 4)
S.STRATA = "FULLSCREEN_DIALOG"

-- THE CARD'S COLOURS (the mockup's), each by name
S.COLOUR = {
  teal = "1f4f57", walnut = "4a2e1c", walnutDark = "2e1c11", night = "0d1418",
  paper = "ece2c9", seat = "e2d6bb", seatEdge = "cbbd9b", stub = "e7dcc1", stubEdge = "a99c7e",
  ink = "1d2a2e", muted = "7a6f58", sky = "2f6fd0", tangerine = "ff8a3d", shade = "e8e1cf", shadeEdge = "a9a08b",
}
-- the classes in colours that read on paper (the game's are made for a dark screen: a rogue's yellow vanishes on cream)
S.CLASS_INK = { WARRIOR = "8a5a2b", PALADIN = "c0507f", HUNTER = "4f8a1a", ROGUE = "9a8a00", PRIEST = "6e6e6e",
  SHAMAN = "0f63d6", MAGE = "1f8fb3", WARLOCK = "6b5bb0", DRUID = "c55a00", DEATHKNIGHT = "a3142f", MONK = "00a36c",
  DEMONHUNTER = "8e2fb0", EVOKER = "2e8a7a" }
-- the loot qualities on paper: poor, common, uncommon, rare, epic, legendary, artifact, heirloom
S.QUALITY_INK = { [0] = "6e6e6e", [1] = "1d2a2e", [2] = "2a7a12", [3] = "0f63d6", [4] = "7b2fbf", [5] = "c55a00",
                  [6] = "b08d57", [7] = "0f8fb3" }
-- a link's own colour -> its quality
S.LINK_QUALITY = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5, e6cc80 = 6,
                   ["00ccff"] = 7 }

local px, at, fill, word, box, width = L.Px, L.At, L.Fill, L.Word, L.Box, L.Width

local function hidden(v)
  if v == nil or not issecretvalue then return false end
  local ok, yes = pcall(issecretvalue, v)
  return (not ok) or yes == true
end
local function plain(v) if hidden(v) then return nil end return v end

local function paper(parent, layer, name, a) return fill(parent, layer, S.COLOUR[name] or name, a) end
local function ink(hex, s) return "|cff" .. tostring(hex or S.COLOUR.ink) .. tostring(s) .. "|r" end

function S.FontPx(em) return px(em) end

local function className(token)
  if type(token) ~= "string" or token == "" then return nil end
  local names = _G.LOCALIZED_CLASS_NAMES_MALE
  if type(names) == "table" and type(names[token]) == "string" then return names[token] end
  return token:sub(1, 1):upper() .. token:sub(2):lower()
end

local function screen()
  local sw = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1024
  local sh = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
  if sw <= 0 or sh <= 0 then sw, sh = 1024, 768 end
  return sw, sh
end

--- How big the card's room is drawn: the largest 16:9 that fits the screen, edge to edge.
function S.Size()
  local sw, sh = screen()
  return math.min(sw / S.W, sh / S.H)
end

--- WHERE THE TICKET IS ON THE PICTURE, as fractions of the screen (0-1 from the top-left): the album page cuts it out.
function S.Rect()
  local sw, sh = screen()
  local k = S.Size()
  local ox, oy = (sw - S.W * k) / 2, (sh - S.H * k) / 2
  local function r4(n) return math.floor(n * 10000 + 0.5) / 10000 end
  return { x = r4((ox + px(S.TICKET[1]) * k) / sw), y = r4((oy + px(S.TICKET[2]) * k) / sh),
           w = r4(px(S.TICKET[3]) * k / sw), h = r4(px(S.TICKET[4]) * k / sh) }
end

--- Every word at its size for this screen: its share of the card, never under the lounge's least once scaled by `k`.
function S.Fonts(k)
  local least = L.MIN_FONT / k
  for _, fs in ipairs(S.fonts) do
    local s = math.max(px(fs.em or 1), least)
    if fs.face then fs:SetFont(fs.face, s, "") end
    fs.pt = s
  end
end

--------------------------------------------------------------------- the words of a card --

--- An item for the CARGO line: its name and quality, from a link (no client call) or an id (the client's item info).
function S.Item(c)
  if type(c) == "string" then
    local hex, name = c:match("|c%x%x(%x%x%x%x%x%x)|Hitem:.-|h%[(.-)%]|h")
    if not name then name = c:match("|Hitem:.-|h%[(.-)%]|h") end
    if name and name ~= "" then return name, hex and S.LINK_QUALITY[hex:lower()] or nil end
    c = tonumber(c:match("item:(%d+)"))
  end
  if type(c) ~= "number" then return nil end
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if getInfo then
    local ok, name, _, q = pcall(getInfo, c)
    if not ok then name, q = nil, nil end
    name = plain(name)
    q = plain(q)
    if type(name) == "string" and name ~= "" then return name, type(q) == "number" and q or nil end
  end
  return "item " .. c, nil
end

--- The tangerine line under the title: what kind of moment, and how long it took.
function S.Line(e)
  local d = tostring(e.detail or "")
  local w
  if L.Game(e) then
    w = "CLEARED"                                          -- a BiS Shell game's chapter, not a boss (8 Nov)
  elseif e.reason == "boss" then
    w = (d:find("^first kill") and "FIRST KILL") or (d:find("fastest yet", 1, true) and "FASTEST YET") or "BOSS DOWN"
  else
    w = L.KIND[e.reason] or M.Word(e.reason):upper()
  end
  local secs = tonumber(e.secs)
  if secs then w = w .. (" · %d:%02d"):format(math.floor(secs / 60), math.floor(secs % 60)) end
  return w
end

--- THE CARD'S WORDS. The route, the seat, the time and the flight from the lounge's own ticket (L.PassFields, one
--- place); the rest here. `hidden`: no names - the passenger is the class, the crew a count and their classes.
--- An entry not in `list` (a card another addon asked for): its route starts at the newest memory.
function S.Fields(e, list, hide)
  list = list or J.Entries()
  local p = L.PassFields(e, list)
  local inList = false
  for _, x in ipairs(list) do if x == e then inList = true break end end
  if not inList and list[1] then
    p.fromCode, p.fromName = L.Code(list[1].zone), L.ZoneMain(list[1].zone):upper()
  end
  local card = type(e.card) == "table" and e.card or nil
  local v = { brand = "BiS> MEMORIES", head = "BOARDING PASS · FIRST CLASS", stamp = "BiS> MEMORIES",
              stampSmall = "a WoW addon · CurseForge", seed = p.seed, fromCode = p.fromCode, fromName = p.fromName,
              toCode = p.toCode, toName = p.toName, seat = p.seat, time = p.time }
  v.date = (tonumber(e.at) and date) and date("%d %b %Y", e.at):upper() or "--"
  v.title = card and card.title or (L.Name(e):gsub("^%l", string.upper))
  v.line = card and card.line or S.Line(e)
  v.kind = card and card.kind or p.kind
  -- the stub: the place, the spot in it, the flight
  local lines = { L.ZoneMain(e.zone):upper() }
  local sub = L.ZoneSub(e.zone)
  if sub then lines[#lines + 1] = sub:upper() end
  lines[#lines + 1] = "FLIGHT " .. tostring(p.flight)
  v.place = table.concat(lines, "\n")
  -- WHO: a name never goes on a hidden card - not the character's, not the party's, not a realm
  if hide then
    v.passenger = ("A " .. (className(e.class) or "traveller")):upper()
    v.passengerInk = S.CLASS_INK[e.class]
  else
    v.passenger = (tostring(e.char or M.Me() or "?"):match("^[^%-]*")):upper()
  end
  local names = type(e.with) == "table" and e.with or {}
  if #names > 0 then
    local items = {}
    for i = 1, #names do
      local cls = type(e.withClass) == "table" and e.withClass[i] or nil
      cls = type(cls) == "string" and cls or nil
      if hide then
        if className(cls) then items[#items + 1] = { className(cls):lower(), S.CLASS_INK[cls] } end
      else
        items[#items + 1] = { (tostring(names[i]):gsub("%-.*$", "")), cls and S.CLASS_INK[cls] or nil }
      end
    end
    if hide then
      v.crewLead = #names .. (#names == 1 and " friend" or " friends") .. (#items > 0 and ": " or "")
      v.crewSep = ", "
    else
      v.crewLead, v.crewSep = "", " · "
    end
    v.crew = items
  end
  local cargo = {}
  for _, c in ipairs(type(e.cargo) == "table" and e.cargo or {}) do
    local name, q = S.Item(c)
    if name then cargo[#cargo + 1] = { name, q and S.QUALITY_INK[q] or nil } end
  end
  if #cargo > 0 then v.cargo = cargo end
  return v
end

--- A line of coloured items after a lead, as many as fit `room` px at `size` (then "+N more").
function S.Join(lead, items, sep, room, size)
  for k = #items, 0, -1 do
    local parts = {}
    for i = 1, k do parts[i] = ink(items[i][2], items[i][1]) end
    local s = (lead or "") .. table.concat(parts, sep) .. (k < #items and (" +" .. (#items - k) .. " more") or "")
    if width(s, size) <= room or k == 0 then return s end
  end
end

--------------------------------------------------------------------- the card --

local function mixHex(a, b, t)
  local ar, ag, ab = L.Rgb(a)
  local br, bg, bb = L.Rgb(b)
  return ar + (br - ar) * t, ag + (bg - ag) * t, ab + (bb - ab) * t
end

local function skyAt(y)
  for i = 1, #L.SKY - 1 do
    local a, b = L.SKY[i], L.SKY[i + 1]
    if y <= b[1] then return mixHex(a[2], b[2], (y - a[1]) / (b[1] - a[1])) end
  end
  return L.Rgb(L.SKY[#L.SKY][2])
end

local function buildSeat(t)
  at(paper(t, "BORDER", "seat"), t, 0, 0, S.SEAT_W, S.TICKET[4])
  at(paper(t, "ARTWORK", "seatEdge"), t, S.SEAT_W - 0.2, 0, 0.2, S.TICKET[4])
  -- the window's box: the dusk sky in bands, the ground, the shade pulled down a little - and the postcard; it cuts
  -- whatever reaches past it
  local o = S.OVAL
  -- LEVELS COUNT FROM THE TICKET'S OWN (Arn's first card, 8 Nov: a blank seat). The ticket sits at 22; a window set to a
  -- flat 5 (the lounge's numbers, where the room is at 2) drew UNDER the ticket's seat paper - sky, you and the oval all
  -- hidden behind it. Every frame here is the ticket's level plus a step.
  local base = t:GetFrameLevel()
  local w = CreateFrame("Frame", nil, t)
  at(w, t, o[1], o[2], o[3], o[4])
  w:SetFrameLevel(base + 1)
  if w.SetClipsChildren then w:SetClipsChildren(true) end
  S.window = w
  local skyH = o[4] * L.GROUND
  for i = 1, L.SKY_BANDS do
    local band = w:CreateTexture(nil, "BACKGROUND")
    band:SetColorTexture(skyAt((i - 0.5) / L.SKY_BANDS * L.GROUND))
    at(band, w, 0, (i - 1) * skyH / L.SKY_BANDS, o[3], skyH / L.SKY_BANDS + 0.02)
  end
  for i = 1, L.EARTH_BANDS do
    local band = w:CreateTexture(nil, "BACKGROUND")
    band:SetColorTexture(mixHex(L.EARTH[1], L.EARTH[2], (i - 1) / (L.EARTH_BANDS - 1)))
    local gh = (o[4] - skyH) / L.EARTH_BANDS
    at(band, w, 0, skyH + (i - 1) * gh, o[3], gh + 0.02)
  end
  at(paper(w, "ARTWORK", "shade"), w, 0, 0, o[3], o[4] * 0.12)
  at(paper(w, "ARTWORK", "shadeEdge"), w, 0, o[4] * 0.12, o[3], 0.15)
  local post = CreateFrame("Frame", nil, w)
  at(post, w, 0, 0, o[3], o[4])
  post:SetFrameLevel(base + 2)
  post.own = true                                         -- a memory of its own, not the journal's chosen one
  post.you = CreateFrame("DressUpModel", nil, post)
  at(post.you, post, 0.5, 4.0, 8.0, 17.5)
  post.you:SetFrameLevel(base + 3)
  post.them = CreateFrame("DressUpModel", nil, post)
  at(post.them, post, 4.5, 9.5, 10.5, 12)
  post.them:SetFrameLevel(base + 3)
  post.note = word(S.fonts, post, L.FONT.body, 0.7, S.COLOUR.paper, "CENTER")   -- J.Postcard writes it; a card never
  post.note:SetPoint("TOP", post, "TOP", 0, -px(3))
  S.post = post
  -- OUR OWN OVAL (Media/oval.tga, dev/art.py): the cream and grey rings, and the seat's paper over the box's corners -
  -- over the models, so nothing of them shows past the oval
  local ov = CreateFrame("Frame", nil, t)
  at(ov, t, o[1] - S.RIM, o[2] - S.RIM, o[3] + 2 * S.RIM, o[4] + 2 * S.RIM)
  ov:SetFrameLevel(base + 8)
  ov.art = ov:CreateTexture(nil, "ARTWORK")
  ov.art:SetTexture(L.MEDIA .. "oval")
  ov.art:SetAllPoints()
  S.oval = ov
end

local function buildMain(t)
  local f = S.f
  local x, w, C, FT = S.MAIN_X, S.MAIN_W, S.COLOUR, L.FONT
  -- words on the ticket's own frame sit under the oval's (the ticket's level + 8): the stub and the middle never meet it
  f.brand = box(word(S.fonts, t, FT.display, 2.0, C.sky), t, x, 2.2, 20)
  f.head = box(word(S.fonts, t, FT.body, 0.95, C.muted, "RIGHT"), t, x + 20, 2.9, w - 20)
  f.title = box(word(S.fonts, t, FT.display, S.TITLE_EM[1], C.ink), t, x, 4.7, w)
  f.line = box(word(S.fonts, t, FT.body, 1.25, C.tangerine), t, x, 8.8, w)
  -- the route: FROM, a dashed line and the arrow, TO
  f.fromCode = box(word(S.fonts, t, FT.display, 2.6, C.ink), t, x, 11.0, 13)
  f.fromName = box(word(S.fonts, t, FT.body, 0.85, C.muted), t, x, 14.0, 13)
  for i = 0, 3 do at(paper(t, "ARTWORK", "tangerine"), t, x + 13.2 + i * 0.8, 12.5, 0.5, 0.22) end
  f.arrow = word(S.fonts, t, FT.display, 2.2, C.tangerine)
  at(f.arrow, t, x + 16.6, 11.2)
  f.arrow:SetText(">")
  f.toCode = box(word(S.fonts, t, FT.display, 2.6, C.ink), t, x + 19.2, 11.0, w - 19.2)
  f.toName = box(word(S.fonts, t, FT.body, 0.85, C.muted), t, x + 19.2, 14.0, w - 19.2)
  f.lab, f.val = {}, {}
  for _, g in ipairs(S.FIELDS) do
    local lab = box(word(S.fonts, t, FT.body, 0.8, C.muted), t, x + g[3], 16.0, g[4])
    lab:SetText(g[2])
    f.lab[g[1]] = lab
    f.val[g[1]] = box(word(S.fonts, t, FT.display, 1.35, C.ink), t, x + g[3], 17.1, g[4])
  end
  -- CREW and CARGO: a label, then a line that may take two lines (placed when painted: CARGO moves up when no CREW)
  f.crewLab = word(S.fonts, t, FT.body, 0.8, C.muted)
  f.crewLab:SetText("CREW")
  f.crew = word(S.fonts, t, FT.body, 1.25, C.ink)
  f.cargoLab = word(S.fonts, t, FT.body, 0.8, C.muted)
  f.cargoLab:SetText("CARGO")
  f.cargo = word(S.fonts, t, FT.body, 1.25, C.ink)
  for _, fs in ipairs({ f.crew, f.cargo }) do
    if fs.SetWordWrap then fs:SetWordWrap(true) end
  end
end

local function buildStub(t)
  local f, C, FT = S.f, S.COLOUR, L.FONT
  local x0 = S.TICKET[3] - S.STUB_W
  at(paper(t, "BORDER", "stub"), t, x0, 0, S.STUB_W, S.TICKET[4])
  -- the tear-off line
  for i = 0, 15 do at(paper(t, "ARTWORK", "stubEdge"), t, x0, 0.5 + i * 2.0, 0.25, 1.1) end
  f.kind = box(word(S.fonts, t, FT.display, 2.0, C.sky), t, S.STUB_X, 2.2, S.STUB_IN)
  S.bars = {}
  for i = 1, S.BARS do
    local b = paper(t, "ARTWORK", "ink")
    b:Hide()
    S.bars[i] = b
  end
  f.place = box(word(S.fonts, t, FT.body, 1.0, C.ink), t, S.STUB_X, 13.4, S.STUB_IN)
  if f.place.SetWordWrap then f.place:SetWordWrap(true) end
  f.place:SetHeight(px(5.4))
  -- THE STAMP: BiS> MEMORIES in a tangerine box, and where to find it under that
  local sx, sy, sw, sh, e = S.STUB_X, 23.6, S.STUB_IN, 5.0, 0.2
  at(paper(t, "ARTWORK", "tangerine"), t, sx, sy, sw, e)
  at(paper(t, "ARTWORK", "tangerine"), t, sx, sy + sh - e, sw, e)
  at(paper(t, "ARTWORK", "tangerine"), t, sx, sy, e, sh)
  at(paper(t, "ARTWORK", "tangerine"), t, sx + sw - e, sy, e, sh)
  f.stamp = box(word(S.fonts, t, FT.display, 1.05, C.tangerine, "CENTER"), t, sx + 0.3, sy + 0.9, sw - 0.6)
  f.stampSmall = box(word(S.fonts, t, FT.body, 0.7, C.tangerine, "CENTER"), t, sx + 0.3, sy + 2.9, sw - 0.6)
end

function S.Build()
  if S.back then return S.back end
  S.fonts, S.f = {}, {}
  -- NO PARENT: the clean shot fades UIParent, and everything inside it with it - never this. Pinned over UIParent's
  -- rectangle and drawn at its scale, so its sizes are the interface's.
  local back = CreateFrame("Frame", "BiSMemoriesShare")
  S.back = back
  back:SetFrameStrata(S.STRATA)
  back:SetFrameLevel(20)
  back:EnableMouse(true)                -- the world behind is not clicked through the card
  back:SetAllPoints(UIParent)
  paper(back, "BACKGROUND", "teal"):SetAllPoints()
  S.trim = {}
  for i, side in ipairs({ "TOP", "BOTTOM" }) do
    local tr = paper(back, "BORDER", "walnut")
    tr:SetPoint(side .. "LEFT", back, side .. "LEFT", 0, 0)
    tr:SetPoint(side .. "RIGHT", back, side .. "RIGHT", 0, 0)
    S.trim[i] = tr
  end
  local room = CreateFrame("Frame", nil, back)
  S.room = room
  room:SetSize(S.W, S.H)
  room:SetPoint("CENTER", back, "CENTER", 0, 0)
  room:SetFrameLevel(21)
  -- the ticket's shadow, then the ticket
  at(paper(room, "BORDER", "night", 0.45), room, S.TICKET[1] + 0.4, S.TICKET[2] + 1.0, S.TICKET[3], S.TICKET[4])
  local t = CreateFrame("Frame", nil, room)
  at(t, room, S.TICKET[1], S.TICKET[2], S.TICKET[3], S.TICKET[4])
  t:SetFrameLevel(22)
  paper(t, "BACKGROUND", "paper"):SetAllPoints()
  S.ticket = t
  buildSeat(t)
  buildMain(t)
  buildStub(t)
  -- ESCAPE PUTS IT AWAY (the family's rule); A FIGHT does, at once
  if UISpecialFrames then table.insert(UISpecialFrames, "BiSMemoriesShare") end
  back:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then S.Close("fight") end
  end)
  back:Hide()
  back:SetScript("OnHide", function(self) S.OnHide(self) end)   -- set after that first Hide (a frame is made shown)
  return back
end

--- The title as big as it fits (S.TITLE_EM, down to the least), then cut. (L.Put keeps room for "..." - so does this.)
local function fitTitle(fs, s)
  local room, least = fs.room, L.MIN_FONT / (S.k or 1)
  local em = S.TITLE_EM[1]
  local function size() return math.max(px(em), least) end
  while em > S.TITLE_EM[2] and width(s, size()) > room - 0.9 * size() do em = em - 0.2 end
  fs.em = em
  fs.pt = math.max(px(em), least)
  fs:SetFont(fs.face, fs.pt, "")
  L.Put(fs, s)
end

--- Paint the card from its words (S.Fields).
function S.Paint(v)
  local f, x, w = S.f, S.MAIN_X, S.MAIN_W
  L.Put(f.brand, v.brand)
  L.Put(f.head, v.head)
  fitTitle(f.title, v.title)
  L.Put(f.line, v.line)
  L.Put(f.fromCode, v.fromCode)
  L.Put(f.fromName, v.fromName)
  L.Put(f.toCode, v.toCode)
  L.Put(f.toName, v.toName)
  for _, g in ipairs(S.FIELDS) do L.Put(f.val[g[1]], v[g[1]]) end
  f.val.passenger:SetTextColor(L.Rgb(v.passengerInk or S.COLOUR.ink))
  -- CREW, then CARGO under it (or in its place): each two lines' room, less what a wrap between words can waste
  local y = 20.4
  for _, row in ipairs({ { f.crewLab, f.crew, v.crew, v.crewLead, v.crewSep }, { f.cargoLab, f.cargo, v.cargo, "", " · " } }) do
    local lab, line, items = row[1], row[2], row[3]
    if items then
      box(lab, S.ticket, x, y + 0.35, 6)
      box(line, S.ticket, x + 6, y, w - 6)
      line:SetHeight(px(3.9))
      line:SetText(S.Join(row[4], items, row[5], line.room * 2 * 0.88, line.pt))
      lab:Show()
      line:Show()
      y = y + 4.3
    else
      lab:Hide()
      line:Hide()
    end
  end
  L.Put(f.kind, v.kind)
  f.place:SetText(v.place or "")                       -- already in lines; it wraps in its own box
  L.Put(f.stamp, v.stamp)
  L.Put(f.stampSmall, v.stampSmall)
  -- THE BARCODE: stripes of one to three widths from the memory's own time - the same memory, the same code
  local seed, bx, i = math.floor(math.abs(v.seed or 1)) % 2147483647, 0, 0
  if seed == 0 then seed = 1 end
  local function nxt() seed = (seed * 16807) % 2147483647 return seed end
  while i < #S.bars do
    local bw = 0.12 * (1 + nxt() % 3)
    if bx + bw > S.STUB_IN then break end
    i = i + 1
    at(S.bars[i], S.ticket, S.STUB_X + bx, 6.0, bw, 6.2)
    S.bars[i]:Show()
    bx = bx + bw + 0.12 * (1 + nxt() % 2)
  end
  for k = i + 1, #S.bars do S.bars[k]:Hide() end
end

--------------------------------------------------------------------- the picture --

function S.Up() return S.back ~= nil and S.back:IsShown() end

--- The models have drawn: you (when you are on it), and the creature posed (J.Look marks it).
function S.Ready()
  local p = S.post
  local you = not p.you:IsShown() or J.Drawn(p.you)
  local them = not p.them:IsShown() or p.them.lookedFor == S.entry
  return you and them
end

--- The memory `n` newest on show (1 = the newest; share cards are not memories).
function S.Newest(n) return J.Entries()[tonumber(n) or 1] end

--- PUT THE CARD UP for memory `e` and take its picture a moment later. `opts.from`: the asking addon (API.lua).
--- -> the card's note (in the album once the picture is taken, its file named then), or nil and why.
function S.Take(e, opts)
  opts = opts or {}
  if type(e) ~= "table" then return nil, "no memory" end
  if L.InFight() then
    ns.Print("no share card in a fight - it would cover your screen. After it: /bism share")
    return nil, "in combat"
  end
  if S.Up() or M.TooSoon() then return nil, "too soon" end
  M.Mark()
  local d = ns.DB()
  local hide = d.shareHidden ~= false                    -- anything but a plain "names on" keeps them off the card
  local back = S.Build()
  -- the journal and the lounge step out of the picture; they come back after it
  S.was = { journal = J.frame ~= nil and J.frame:IsShown(), lounge = L.back ~= nil and L.back:IsShown() }
  if S.was.lounge then L.Hide() end
  if S.was.journal then J.Hide() end
  local ok, scale = pcall(function() return UIParent:GetEffectiveScale() end)
  back:SetScale((ok and type(scale) == "number" and scale > 0) and scale or 1)
  local k = S.Size()
  S.k = k
  S.room:SetScale(k)
  for _, tr in ipairs(S.trim) do tr:SetHeight(px(S.TRIM) * k) end
  S.Fonts(k)
  back:Show()                                            -- shown before the postcard: a hidden model loads nothing
  back:RegisterEvent("PLAYER_REGEN_DISABLED")
  S.entry = e
  local v = S.Fields(e, J.Entries(), hide)
  S.Paint(v)
  S.post.postFor = nil
  J.Postcard(e, S.post)
  S.post.note:SetText("")                                -- the postcard can say "played by <name>": never on a card
  S.note = { reason = "share", detail = v.title, kind = v.kind, zone = e.zone,
             level = type(e.level) == "number" and e.level or 0, at = (time and time()) or 0, of = tonumber(e.at),
             char = M.Me(), class = e.class, hidden = hide, crop = S.Rect(),
             from = type(opts.from) == "string" and opts.from or nil }
  S.token = (S.token or 0) + 1
  S.shotFor = nil
  S.Wait(S.token, 0)
  return S.note
end

--- A frame or two for the models (S.Ready), S.WAIT_MAX at most; a card put away meanwhile makes this do nothing.
function S.Wait(token, waited)
  if not (C_Timer and C_Timer.After) then return S.Capture(token) end
  C_Timer.After(S.STEP, function()
    if token ~= S.token or not S.Up() then return end
    waited = waited + S.STEP
    if S.Ready() or waited >= S.WAIT_MAX - 1e-9 then return S.Capture(token) end
    S.Wait(token, waited)
  end)
end

--- THE SHUTTER: the interface faded (the clean shot - always, the card is the picture), one Screenshot(), the note in
--- the album with its file's name; the card goes when the client says the picture is written, or S.BACK s later.
function S.Capture(token)
  if token ~= S.token or not S.Up() then return nil end
  local note = S.note
  note.file = M.Stem()
  M.Clean(true)
  if Screenshot then pcall(Screenshot) end
  if M.Click then pcall(M.Click) end
  S.shotFor = token
  M.Keep(note)
  if ns.Announce then pcall(ns.Announce, "BiSMemories_Taken", note) end
  if C_Timer and C_Timer.After then
    C_Timer.After(S.BACK, function() if S.token == token then S.Close("done") end end)
  end
  return note
end

--- The client says a picture was written (Memories.lua, SCREENSHOT_SUCCEEDED / _FAILED): ours, the card goes.
function S.Shot()
  if S.Up() and S.shotFor == S.token then S.Close("done") end
end

--- Put it away (Escape, a fight, the picture taken - anything).
function S.Close(why)
  S.why = why
  if S.back and S.back:IsShown() then S.back:Hide() else S.why = nil end
  return true
end

function S.OnHide(self)
  self:UnregisterEvent("PLAYER_REGEN_DISABLED")
  S.token = (S.token or 0) + 1                           -- whatever was waiting finds its card gone
  S.post.postFor = nil
  local why, was = S.why, S.was
  S.why, S.was = nil, nil
  M.Clean(false)                                         -- the interface back, at the player's own alpha
  if why == "fight" or L.InFight() then
    ns.Print("the share card closed for the fight")
    return
  end
  if was and was.lounge then L.Show() elseif was and was.journal then J.Show() end
end

--- A CARD ANOTHER ADDON ASKED FOR (API.lua's ShareCard; its fields already copied, checked and cut there): the player
--- as the passenger, the caller's title, line, kind, place, crew, cargo and creature.
function S.Card(c, from)
  local class, race
  if UnitClass then class = plain(select(2, UnitClass("player"))) end
  if UnitRace then race = plain(select(2, UnitRace("player"))) end
  local level = UnitLevel and plain(UnitLevel("player"))
  local with, withClass = {}, {}
  for i, m in ipairs(c.crew or {}) do with[i], withClass[i] = m.name, m.class or false end
  local kind = (c.kind or "memory"):upper()
  local e = { reason = "api", detail = c.title, zone = c.place or (M.RealZone and M.RealZone()) or "?",
              level = type(level) == "number" and level or 0, at = (time and time()) or 0, char = M.Me(),
              class = type(class) == "string" and class or nil, race = type(race) == "string" and race or nil,
              gear = M.Gear(), with = with, withClass = withClass, cargo = c.cargo, npc = c.npc, display = c.display,
              card = { title = c.title, kind = kind, line = c.line or kind } }
  return S.Take(e, { from = from })
end
