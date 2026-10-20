--[[
  BiSMemories :: Core/Journal.lua - the album, in game.

      /bism journal             open it (also /bism album, the minimap button)

  THE FAMILY'S WINDOW (0.9.0, Arn on the review, 21 Oct 2026: "do all that stuff"). 1.43:1 like every
  BiS window, and the list-and-detail shape Arn likes in Blizzard's classics:
    * MEMORIES: the nights on the left, newest first, one line each (when, what kind, what); click one and
      the right side holds it whole - where, who with, the picture's file name to copy - over a POSTCARD:
      you in 3D, dressed in what you wore that moment and striking the pose of it, beside the creature
      it was about (the boss you killed, whoever killed you).
    * MAP: Azeroth with a dot for every memory taken out in the world (Map.lua).
    * THIS YEAR: what the notes add up to (Moments.lua M.Summary).
  A button in the header shows this character's memories or every character's.

  WHAT IT CANNOT DO, AND NEVER WILL, ON ANY CLIENT: show the pictures. No addon can list a folder, and a
  .jpg in Screenshots cannot be drawn on a frame. The postcard is the nearest the game itself can come;
  the pictures stay with the album page (Album/), whose path is in the copy box at the bottom.
]]
local ADDON, ns = ...
local T, M = ns.T, ns.M
local J = {}
ns.J = J

J.W, J.H = 700, 490                 -- 1.43:1, the BiS window standard
J.HEAD, J.FOOT = 30, 50
J.LIST_W = 300
J.ROW_H = 18
J.LIST_TOP = J.HEAD + 6             -- the first row's top, below the header
J.ROWS = math.floor((J.H - J.LIST_TOP - J.FOOT - 6) / J.ROW_H)
J.DETAIL_X = 8 + J.LIST_W + 10
J.DETAIL_W = J.W - J.DETAIL_X - 8
J.POST_H = 210
local GAP = 3 * 60 * 60             -- seconds of quiet that end a raid night (same rule as the album)

-- THE POSE OF THE MOMENT: the client's animation ids (BiS Gamba's and ADVENT's, seen in game)
J.POSE = { levelup = 68, boss = 82, loot = 64, achievement = 80, death = 1, duel = 82, zone = 84, exalted = 113,
           candid = 0, manual = 67, first = 68, gamba = 70, group = 67 }

local function rgb(name) return T.rgb(name) end
local function tex(parent, layer, name, a)
  local t = parent:CreateTexture(nil, layer)
  local r, g, b = rgb(name)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

local function when(at, fmt)
  if not at or at == 0 then return "?" end
  return date and date(fmt or "%d %b %H:%M", at) or tostring(at)
end

--- Text cut to fit `px` at `size` pt, with "..." - measured the way the suite's fit check measures the
--- client (capitals and digits 0.75 px a point, lower case 0.55, the rest 0.3); colour and link codes
--- take no room, and a link keeps only its [Name].
function J.Clip(s, px, size)
  s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", "")
  size = size or 10
  local w, out = 0, {}
  local dots = 3 * 0.3 * size
  for ch in s:gmatch(".") do
    local cw = (ch:match("[%u%d]") and 0.75 or ch:match("%l") and 0.55 or 0.3) * size
    if w + cw > px - dots then return table.concat(out) .. "..." end
    w = w + cw
    out[#out + 1] = ch
  end
  return s
end

--------------------------------------------------------------------- the words --

-- Where the album page is. The tail is certain; the head is whatever the player told us with `/bism wow` -
-- or, untold, A GUESS (Arn, 21 Oct 2026: "from in game how close can we get them to the album html with the
-- copy and paste"): where the launcher installs WoW, and the version folder by what the client says it is -
-- Forever's beta answers IsBetaBuild() true and plays from _classic_beta_ (measured that day); the live
-- client from _forever_ (the folder Battle.net made beside it). A guess is said to be one, and /bism wow
-- corrects it. Pasted into Windows key + R (or File Explorer's address bar) it opens the album.
local TAIL = [[Interface\AddOns\BiSMemories\Album\BiSMemories-Album.html]]
J.INSTALL = [[C:\Program Files (x86)\World of Warcraft]]

function J.VersionFolder()
  local ok, beta = pcall(function() return IsBetaBuild and IsBetaBuild() end)
  return (ok and beta == true) and "_classic_beta_" or "_forever_"
end

function J.AlbumPath()
  local d = ns.DB and ns.DB()
  local root = type(d) == "table" and d.wowPath or nil
  if type(root) ~= "string" or root == "" then root = J.INSTALL .. "\\" .. J.VersionFolder() end
  return (root:gsub("[\\/]+$", "")) .. "\\" .. TAIL
end

function J.AlbumPathWhole()
  local d = ns.DB and ns.DB()
  local root = type(d) == "table" and d.wowPath or nil
  return type(root) == "string" and root ~= ""
end

--- Remember where WoW is (trimmed, never validated - the player knows it better than an addon can).
function J.SetWow(path)
  local d = ns.DB and ns.DB()
  if type(d) ~= "table" then return nil end
  if type(path) ~= "string" or path:gsub("%s", "") == "" then
    d.wowPath = nil
  else
    d.wowPath = (path:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[\\/]+$", ""))
  end
  if J.frame and J.frame:IsShown() then J.Refresh() end
  return d.wowPath
end

--- The memories on show: this character's, or every character's (J.everyone).
function J.Entries()
  local log, out = M.Log(), {}
  local me = M.Me()
  for _, e in ipairs(log) do
    if J.everyone or e.char == nil or e.char == me then out[#out + 1] = e end
  end
  return out
end

--- One entry as a list row: the time, the kind in words, what it was. Where and who are in the
--- tooltip and the detail pane; the night's heading has the day.
function J.Line(e)
  if type(e) ~= "table" then return "" end
  return ("%s  %s  %s"):format(when(e.at, "%H:%M"), M.Word(e.reason), tostring(e.detail or ""))
end

--- What hovering a row (or a map dot) says: where, who with, which picture on disk.
function J.TipLines(e)
  if type(e) ~= "table" then return {} end
  local out = { tostring(e.zone or "?") }
  if type(e.with) == "table" and #e.with > 0 then out[#out + 1] = "with " .. #e.with end
  if e.file then out[#out + 1] = tostring(e.file) end
  return out
end

--- `full`: a map dot's tooltip, which also says what it was.
function J.Tip(owner, e, full)
  if not (GameTooltip and type(e) == "table") then return end
  local lines = J.TipLines(e)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if full then
    GameTooltip:SetText(M.Word(e.reason) .. "  " .. tostring(e.detail or ""))
    GameTooltip:AddLine(T.text("muted", when(e.at, "%d %b %Y %H:%M")))
    for i = 1, #lines do GameTooltip:AddLine(T.text("muted", lines[i])) end
  else
    GameTooltip:SetText(lines[1])
    for i = 2, #lines do GameTooltip:AddLine(T.text("muted", lines[i])) end
  end
  GameTooltip:Show()
end

--- The memories as LINES: a heading for each night, its memories under it. A night is a run with no
--- three-hour gap in it, titled by the zone its bosses died in (else where it began), dated by its start.
function J.Lines()
  local log = J.Entries()
  local out, cur = {}, nil
  for i = 1, #log do
    local e = log[i]
    local at = tonumber(e.at) or 0
    if not cur or (cur.oldest - at) > GAP then
      cur = { newest = at, oldest = at, bosses = 0, bossZone = nil, anyZone = e.zone }
      out[#out + 1] = { head = cur }
    end
    cur.oldest = at
    cur.anyZone = cur.anyZone or e.zone
    if e.reason == "boss" then
      cur.bosses = cur.bosses + 1
      cur.bossZone = cur.bossZone or e.zone
    end
    out[#out + 1] = { entry = e }
  end
  return out
end

--- A night's heading: where, the day, from-to, how many bosses.
function J.Head(h)
  if type(h) ~= "table" then return "" end
  local where = h.bossZone or h.anyZone or "somewhere"
  local day = (date and h.oldest > 0) and date("%a %d %b", h.oldest) or "?"
  local from = (date and h.oldest > 0) and date("%H:%M", h.oldest) or "?"
  local to = (date and h.newest > 0) and date("%H:%M", h.newest) or "?"
  local span = (from == to) and from or (from .. "-" .. to)
  local kills = h.bosses > 0 and ("  " .. h.bosses .. (h.bosses == 1 and " boss" or " bosses")) or ""
  return T.text("accent", where) .. T.text("muted", ("  %s  %s%s"):format(day, span, kills))
end

--------------------------------------------------------------------- the window --

local function button(parent, w, h, word, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  b.bg = tex(b, "BACKGROUND", "sunken", 0.95)
  b.bg:SetAllPoints()
  b.word = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.word:SetPoint("CENTER", 0, 0)
  b.word:SetText(word)
  b:SetScript("OnClick", onClick)
  return b
end

local function label(parent, template, x, y, w, h)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", x or 0, y or 0)
  -- a label with a width is pinned on both sides, so it wraps inside them (and the fit check knows it)
  if w then fs:SetWidth(w) fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", (x or 0) + w, y or 0) end
  if h then fs:SetHeight(h) fs:SetWordWrap(true) else fs:SetWordWrap(false) end
  fs:SetJustifyH("LEFT")
  return fs
end

local function model(parent, w, h)
  local m = CreateFrame("DressUpModel", nil, parent)
  m:SetSize(w, h)
  return m
end

local function build()
  if J.frame then return J.frame end
  local W, H = J.W, J.H
  local f = CreateFrame("Frame", "BiSMemoriesJournal", UIParent)
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  local bg = tex(f, "BACKGROUND", "bg", 0.96)
  bg:SetAllPoints()
  local bar = tex(f, "BORDER", "surface", 1)
  bar:SetPoint("TOPLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", 0, 0)
  bar:SetHeight(J.HEAD - 4)

  local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  head:SetPoint("TOPLEFT", 10, -7)
  head:SetText(T.text("accent", "BiS> Memories"))

  -- THE PAGES: three words in the bar, the chosen one in the accent colour
  f.tabs = {}
  for i, name in ipairs({ "memories", "map", "this year" }) do
    local b = button(f, 76, 18, name, function() J.Tab(name) end)
    b:SetPoint("TOPLEFT", 120 + (i - 1) * 80, -4)
    b.name = name
    f.tabs[i] = b
  end
  f.who = button(f, 120, 18, "this character", function()
    J.everyone = not J.everyone
    J.offset = 0
    J.Refresh()
  end)
  f.who:SetPoint("TOPRIGHT", -34, -4)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -1)
  close:SetScript("OnClick", function() J.Hide() end)

  ------------------------------------------------ memories: the list
  local list = CreateFrame("Frame", nil, f)
  list:SetPoint("TOPLEFT", 8, -(J.HEAD + 2))
  list:SetSize(J.LIST_W, J.ROWS * J.ROW_H + 8)
  local lbg = tex(list, "BACKGROUND", "sunken", 0.9)
  lbg:SetAllPoints()
  f.list = list
  f.sel = tex(list, "BORDER", "line2", 0.9)
  f.sel:SetHeight(J.ROW_H)
  f.sel:Hide()
  f.rows, f.hits = {}, {}
  for i = 1, J.ROWS do
    local fs = list:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 6, -4 - (i - 1) * J.ROW_H)
    fs:SetPoint("RIGHT", list, "RIGHT", -6, 0)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    f.rows[i] = fs
    -- the hover and click patch: hands the drag on to the window, so a row never pins it in place
    local hit = CreateFrame("Button", nil, list)
    hit:SetPoint("TOPLEFT", 0, -2 - (i - 1) * J.ROW_H)
    hit:SetPoint("RIGHT", list, "RIGHT", 0, 0)
    hit:SetHeight(J.ROW_H)
    hit:RegisterForDrag("LeftButton")
    hit:SetScript("OnDragStart", function() f:StartMoving() end)
    hit:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    hit:SetScript("OnEnter", function(self) J.Tip(self, self.entry) end)
    hit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    hit:SetScript("OnClick", function(self) if self.entry then J.Select(self.entry) end end)
    f.hits[i] = hit
  end
  -- the wheel walks the list, a few rows a notch
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta) J.Scroll(-delta * 3) end)

  ------------------------------------------------ memories: the detail and its postcard
  local d = CreateFrame("Frame", nil, f)
  d:SetPoint("TOPLEFT", J.DETAIL_X, -(J.HEAD + 2))
  d:SetSize(J.DETAIL_W, J.H - J.HEAD - J.FOOT - 4)
  f.detail = d
  local post = CreateFrame("Frame", nil, d)
  post:SetPoint("TOPLEFT", 0, 0)
  post:SetSize(J.DETAIL_W, J.POST_H)
  local pbg = tex(post, "BACKGROUND", "sunken", 0.9)
  pbg:SetAllPoints()
  post.you = model(post, 190, J.POST_H - 6)
  post.you:SetPoint("BOTTOMLEFT", 6, 3)
  post.them = model(post, 180, J.POST_H - 16)
  post.them:SetPoint("BOTTOMRIGHT", -6, 3)
  post.note = label(post, "GameFontDisableSmall", 10, -8)
  f.post = post
  local DW, x, y = J.DETAIL_W - 8, 4, -(J.POST_H + 8)
  f.kind = label(d, "GameFontNormal", x, y)
  f.text = label(d, "GameFontHighlight", x, y - 18, DW, 30)
  f.where = label(d, "GameFontDisableSmall", x, y - 52)
  f.whoWith = label(d, "GameFontDisableSmall", x, y - 68)
  f.withX, f.withY, f.withW = x + 30, y - 68, DW - 30
  f.withBtns = {}
  f.more = label(d, "GameFontDisableSmall", x, y - 104)
  f.fileBox = CreateFrame("EditBox", nil, d)
  f.fileBox:SetPoint("TOPLEFT", x, y - 122)
  f.fileBox:SetSize(220, 16)
  f.fileBox:SetAutoFocus(false)
  f.fileBox:SetFontObject("GameFontHighlightSmall")
  f.fileBox:SetTextInsets(4, 4, 0, 0)
  local fbg = f.fileBox:CreateTexture(nil, "BACKGROUND")
  fbg:SetAllPoints()
  fbg:SetColorTexture(1, 1, 1, 0.07)
  f.fileBox:SetScript("OnMouseUp", function(self) self:HighlightText() self:SetFocus() end)
  f.fileBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  f.fileBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  f.fileBox:SetScript("OnEnterPressed", function(self) self:SetText(J.sel and J.sel.file or "") self:HighlightText() end)

  ------------------------------------------------ the map page
  local map = CreateFrame("Frame", nil, f)
  map:SetPoint("TOPLEFT", 8, -(J.HEAD + 2))
  map:SetSize(J.W - 16, J.H - J.HEAD - J.FOOT - 4)
  local mbg = tex(map, "BACKGROUND", "sunken", 0.9)
  mbg:SetAllPoints()
  map.say = label(map, "GameFontDisableSmall", 8, -6)
  f.map = map

  ------------------------------------------------ the year page
  local year = CreateFrame("Frame", nil, f)
  year:SetPoint("TOPLEFT", 8, -(J.HEAD + 2))
  year:SetSize(J.W - 16, J.H - J.HEAD - J.FOOT - 4)
  local ybg = tex(year, "BACKGROUND", "sunken", 0.9)
  ybg:SetAllPoints()
  year.lines = {}
  for i = 1, 10 do
    year.lines[i] = label(year, i == 1 and "GameFontNormal" or "GameFontHighlightSmall", 14, -14 - (i - 1) * 22,
      J.W - 50, 20)
  end
  f.year = year

  ------------------------------------------------ the foot: the album page's path, ready to copy
  f.pathLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.pathLabel:SetPoint("BOTTOMLEFT", 10, 28)
  f.pathLabel:SetJustifyH("LEFT")
  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.count:SetPoint("BOTTOMRIGHT", -10, 28)
  f.pathBox = CreateFrame("EditBox", nil, f)
  f.pathBox:SetPoint("BOTTOMLEFT", 10, 8)
  f.pathBox:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  f.pathBox:SetHeight(16)
  f.pathBox:SetAutoFocus(false)
  f.pathBox:SetFontObject("GameFontHighlightSmall")
  f.pathBox:SetTextInsets(4, 4, 0, 0)
  local boxBG = f.pathBox:CreateTexture(nil, "BACKGROUND")
  boxBG:SetAllPoints()
  boxBG:SetColorTexture(1, 1, 1, 0.07)
  f.pathBox:SetScript("OnMouseUp", function(self) self:HighlightText() self:SetFocus() end)
  f.pathBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  f.pathBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  f.pathBox:SetScript("OnEnterPressed", function(self) self:SetText(J.AlbumPath()) self:HighlightText() end)

  if UISpecialFrames then table.insert(UISpecialFrames, "BiSMemoriesJournal") end
  f:Hide()
  J.frame = f
  J.page = J.page or "memories"
  return f
end
J.Build = build

--------------------------------------------------------------------- painting --

--- Move the list by `by` rows, clamped. Answers where it landed.
function J.Scroll(by)
  local most = math.max(0, #J.Lines() - J.ROWS)
  J.offset = math.max(0, math.min(most, (J.offset or 0) + (by or 0)))
  if J.frame and J.frame:IsShown() then J.Refresh() end
  return J.offset
end

--- Which page: "memories", "map" or "this year".
function J.Tab(name)
  J.page = name
  if J.frame and J.frame:IsShown() then J.Refresh() end
  return J.page
end

--- Open a memory: the right side holds it whole, the postcard shows it.
function J.Select(e)
  J.sel = e
  J.page = "memories"
  if J.frame and J.frame:IsShown() then J.Refresh() end
  return e
end

--- THE POSTCARD: you in 3D, in what you wore and the moment's pose, beside its creature. Asked twice -
--- the client does not draw a body on the first ask (BiS Shell measured it for SURVIVOR) - and only for
--- your own memories: an addon can draw the character you are playing, not one who is logged out.
function J.Postcard(e)
  local p = J.frame and J.frame.post
  if not p then return end
  local you, them = p.you, p.them
  -- only the character who took it: an old note nobody has claimed yet (M.ClaimOld) draws nobody
  local mine = type(e) == "table" and e.char == M.Me()
  p.note:SetText("")
  if mine then
    you:Show()
    pcall(you.ClearModel, you)
    pcall(you.SetUnit, you, "player")
    if type(e.gear) == "table" and you.Undress and you.TryOn then
      pcall(you.Undress, you)
      for _, id in pairs(e.gear) do pcall(you.TryOn, you, "item:" .. tostring(id)) end
    end
    pcall(you.SetFacing, you, 0.5)
    pcall(you.SetAnimation, you, J.POSE[e.reason] or 0)
  else
    you:Hide()
    if type(e) == "table" and e.char then
      p.note:SetText(T.text("muted", "played by " .. tostring(e.char):match("^[^%-]+")))
    elseif type(e) == "table" then
      p.note:SetText(T.text("muted", "an older picture - its character logs in to claim it"))
    end
  end
  local npc = M.Face(e)
  if npc then
    them:Show()
    local function ask()
      pcall(them.SetCreature, them, npc)
      pcall(them.SetFacing, them, -0.5)
      -- a boss you killed lies where it fell; whoever killed you stands over you
      pcall(them.SetAnimation, them, (e.reason == "boss") and 1 or 0)
    end
    ask()
    if C_Timer and C_Timer.After then
      C_Timer.After(0.3, function() if J.sel == e and them:IsShown() then ask() end end)
    end
  else
    them:Hide()
  end
end

--- THE GAME'S OWN PLAYER MENU for a name (Arn, 21 Oct 2026: "so a year from now i can add them to bis pal
--- or invite them again"): whisper, invite, add friend - and BiS Tools' pal line, which joins this menu.
--- The FRIEND menu, as BiS Guild's terminal opens it (a guild menu opened by an addon can taint).
function J.PlayerMenu(name)
  if type(name) ~= "string" or name == "" then return false end
  if UnitPopup_OpenMenu then
    local ok = pcall(UnitPopup_OpenMenu, "FRIEND", { name = name, chatTarget = name })
    if ok then return true end
  end
  if FriendsFrame_ShowDropdown then return (pcall(FriendsFrame_ShowDropdown, name, false)) end
  return false
end

J.WITH_ROWS = 2
--- Who was there: a name each, in its class colour, laid in rows; a click opens the game's menu for them.
function J.PaintWith(f, e)
  for _, b in ipairs(f.withBtns) do b:Hide() end
  local names = type(e) == "table" and type(e.with) == "table" and e.with or {}
  if #names == 0 then f.whoWith:SetText("") return 0 end
  f.whoWith:SetText("with")
  local colours = _G.RAID_CLASS_COLORS
  local x, row, shown = 0, 0, 0
  for i, name in ipairs(names) do
    local b = f.withBtns[i]
    if not b then
      b = CreateFrame("Button", nil, f.detail)
      b:SetHeight(16)
      b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      b.fs:SetPoint("LEFT", 0, 0)
      b.fs:SetWordWrap(false)
      local hi = b:CreateTexture(nil, "HIGHLIGHT")
      hi:SetAllPoints()
      hi:SetColorTexture(1, 1, 1, 0.08)
      if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
      b:SetScript("OnClick", function(self) J.PlayerMenu(self.who) end)
      b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.who or "")
        GameTooltip:AddLine("click: whisper, invite, add as a friend or a pal", 0.7, 0.7, 0.7)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
      f.withBtns[i] = b
    end
    b.who = name
    b.fs:SetText(name .. (i < #names and "," or ""))
    local cls = type(e.withClass) == "table" and e.withClass[i]
    local cc = cls and colours and colours[cls]
    if cc then b.fs:SetTextColor(cc.r, cc.g, cc.b) else b.fs:SetTextColor(rgb("ink2")) end
    local w = math.ceil(b.fs:GetStringWidth() or 40) + 6
    if x > 0 and x + w > f.withW then x, row = 0, row + 1 end
    if row >= J.WITH_ROWS then break end
    b:SetWidth(w)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f.detail, "TOPLEFT", f.withX + x, f.withY - row * 16 + 2)
    b:Show()
    shown = shown + 1
    x = x + w
  end
  if shown < #names then
    local last = f.withBtns[shown]
    if last then last.fs:SetText(last.who .. ("  +%d more"):format(#names - shown)) end
  end
  return shown
end

local function paintDetail(f)
  local e = J.sel
  if type(e) ~= "table" then
    f.post.you:Hide()
    f.post.them:Hide()
    f.kind:SetText(T.text("muted", #M.Log() == 0 and "nothing yet" or "pick a memory on the left"))
    f.text:SetText(#M.Log() == 0 and "It fires on levels, first kills, rare loot, achievements and more." or "")
    f.where:SetText("") f.whoWith:SetText("") f.more:SetText("")
    for _, b in ipairs(f.withBtns) do b:Hide() end
    f.fileBox:Hide()
    return
  end
  J.Postcard(e)
  local DW = J.DETAIL_W - 8
  f.kind:SetText(T.text("accent", M.Word(e.reason)) .. T.text("muted", "  " .. when(e.at, "%a %d %b %Y  %H:%M")))
  f.text:SetText(tostring(e.detail or ""))
  local lvl = (type(e.level) == "number" and e.level > 0) and ("  -  level " .. e.level) or ""
  f.where:SetText(J.Clip(tostring(e.zone or "?") .. lvl, DW, 10))
  J.PaintWith(f, e)
  local more = {}
  if e.secs then more[#more + 1] = ("the fight took %d:%02d"):format(math.floor(e.secs / 60), math.floor(e.secs % 60)) end
  if e.from then more[#more + 1] = "asked for by " .. tostring(e.from) end
  if e.char and e.char ~= M.Me() then more[#more + 1] = "on " .. tostring(e.char) end
  f.more:SetText(J.Clip(table.concat(more, "  -  "), DW, 10))
  if e.file then
    f.fileBox:Show()
    f.fileBox:SetText(e.file)
    f.fileBox:SetCursorPosition(0)
  else
    f.fileBox:Hide()
  end
end

local function paintList(f)
  local lines = J.Lines()
  J.offset = math.max(0, math.min(math.max(0, #lines - J.ROWS), J.offset or 0))
  f.sel:Hide()
  local px = J.LIST_W - 12
  for i = 1, J.ROWS do
    local l = lines[i + J.offset]
    f.hits[i].entry = l and l.entry or nil
    if not l then
      f.rows[i]:SetText("")
    elseif l.head then
      f.rows[i]:SetText(T.text("accent", J.Clip((J.Head(l.head):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), px, 10)))
    else
      local e = l.entry
      local text = J.Clip(J.Line(e), px - 8, 10)
      f.rows[i]:SetText("  " .. text)
      if e == J.sel then
        f.sel:ClearAllPoints()
        f.sel:SetPoint("TOPLEFT", f.list, "TOPLEFT", 2, -2 - (i - 1) * J.ROW_H)
        f.sel:SetPoint("RIGHT", f.list, "RIGHT", -2, 0)
        f.sel:Show()
      end
    end
  end
end

local function paintMap(f)
  local entries = J.Entries()
  local map = J.mapID or (ns.MapView and ns.MapView.Start())
  local n, inside, off, rough
  if ns.MapView and map then
    n, inside, off, rough = ns.MapView.Draw(f.map, entries, map, function(e) J.Select(e) end)
  end
  if not n then
    f.map.say:SetText(T.text("muted", "the game gave no map to draw here - the pins on your world map still show"))
  else
    local bits = { ("%d on the map"):format(n) }
    if (rough or 0) > 0 then bits[#bits + 1] = ("%d of them older, placed by their zone (the small dots)"):format(rough) end
    if (inside or 0) > 0 then bits[#bits + 1] = ("%d inside a dungeon or battleground"):format(inside) end
    f.map.say:SetText(T.text("muted", table.concat(bits, "  -  ")))
  end
end

local function paintYear(f)
  local s = M.Summary(nil, (not J.everyone) and M.Me() or nil)
  local lines = M.SummaryLines(s)
  for i, fs in ipairs(f.year.lines) do
    local t = lines[i]
    if i == 1 and t then t = T.text("accent", t) end
    fs:SetText(t and J.Clip(t, J.W - 50, i == 1 and 12 or 10) or "")
  end
end

function J.Refresh()
  local f = build()
  J.page = J.page or "memories"
  for _, b in ipairs(f.tabs) do
    b.word:SetText(b.name == J.page and T.text("accent", b.name) or T.text("ink2", b.name))
  end
  f.who.word:SetText(J.everyone and "every character" or "this character")
  local list = J.page == "memories"
  f.list:SetShown(list)
  f.detail:SetShown(list)
  f.map:SetShown(J.page == "map")
  f.year:SetShown(J.page == "this year")
  if list then
    paintList(f)
    paintDetail(f)
  elseif J.page == "map" then
    paintMap(f)
  else
    paintYear(f)
  end
  local n = #J.Entries()
  f.count:SetText(T.text("muted", n == 0 and "" or (n .. " kept")))
  f.pathBox:SetText(J.AlbumPath())
  f.pathBox:SetCursorPosition(0)
  f.pathLabel:SetText(T.text("muted", J.AlbumPathWhole()
    and "your album: click, Ctrl+C, then Windows key + R, Ctrl+V, Enter"
    or "your album: click, Ctrl+C, then Windows key + R, Ctrl+V, Enter  -  WoW somewhere else? /bism wow <folder>"))
  return true, n
end

function J.Show()
  local f = build()
  J.Refresh()
  f:Show()
  return true
end

function J.Hide()
  if J.frame then J.frame:Hide() end
  return true
end

function J.Toggle()
  if J.frame and J.frame:IsShown() then return J.Hide() end
  return J.Show()
end

--- Called when a memory lands, so an open window does not go stale while you play.
function J.Touch()
  if J.frame and J.frame:IsShown() then J.Refresh() end
end

--------------------------------------------------------------------- on screen --

--- ON THIS DAY's card: top of the screen for J.TOAST_FOR seconds; a click opens the journal on it.
J.TOAST_FOR = 10
function J.Toast(e, words)
  local t = J.toast
  if not t then
    t = CreateFrame("Button", nil, UIParent)
    t:SetSize(360, 44)
    t:SetPoint("TOP", UIParent, "TOP", 0, -120)
    t:SetFrameStrata("DIALOG")
    local b = tex(t, "BACKGROUND", "bg", 0.92)
    b:SetAllPoints()
    t.title = label(t, "GameFontNormal", 10, -6)
    t.line = label(t, "GameFontHighlightSmall", 10, -24)
    t:SetScript("OnClick", function(self) self:Hide() J.Select(self.entry) J.Show() end)
    J.toast = t
  end
  t.entry = e
  t.title:SetText(T.text("gold", J.Clip(words or "", 340, 12)))
  t.line:SetText(J.Clip(M.Word(e.reason) .. "  " .. tostring(e.detail or ""), 340, 10))
  t:Show()
  if C_Timer and C_Timer.After then C_Timer.After(J.TOAST_FOR, function() if t.entry == e then t:Hide() end end) end
  return t
end

--- THE GROUP PHOTO's countdown: a big number in the middle of the screen; nil takes it away.
function J.Count(n)
  local c = J.counter
  if not c then
    c = CreateFrame("Frame", nil, UIParent)
    c:SetSize(240, 120)
    c:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
    c:SetFrameStrata("FULLSCREEN_DIALOG")
    c.big = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    c.big:SetPoint("CENTER", 0, 10)
    c.small = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.small:SetPoint("TOP", c.big, "BOTTOM", 0, -8)
    J.counter = c
  end
  if not n then c:Hide() return nil end
  if c.big.SetFont and STANDARD_TEXT_FONT then pcall(c.big.SetFont, c.big, STANDARD_TEXT_FONT, 64, "THICKOUTLINE") end
  c.big:SetText(T.text("gold", tostring(n)))
  c.small:SetText("group photo - say cheese!")
  c:Show()
  return c
end
