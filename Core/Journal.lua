--[[
  BiSMemories :: Core/Journal.lua - the album, in game.

      /bism journal             open it (also /bism album, the minimap button)

  A JETLINER'S GLASS COCKPIT (Arn, 8 Nov 2026: "lets give bis memories the cockpit theme treatment lets make it a
  cool fancy jetliner look" - the 0.9.0 window had become "too cramp": "what would a multimillion dollar plane cockpit
  do"). A quiet housing - a glareshield, a thin rim round each display - and two black glass displays side by side,
  each doing ONE job in big type with black space round it, colour only where it means something (J.GLASS):
    * the BEZEL KEYS, set into the housing outside the glass: MEMORIES, MAP, YEAR (what the left display shows; the
      lit one carries a green bar), CHARACTER (this character's memories or every character's), X.
    * the LEFT DISPLAY, a flight computer's page: "MEMORIES 1/13", SIX big lines a page (when and what kind above,
      what it was below), each night's heading a cyan separator, the chosen line in magenta brackets; PREV PAGE /
      NEXT PAGE under it, the wheel too. On MAP it is a navigation display (Map.lua): a range knob, pins that merge.
      On YEAR, what the notes add up to (Moments.lua M.Summary).
    * the RIGHT DISPLAY, the memory itself: the POSTCARD on top (you in 3D, dressed in what you wore and striking the
      moment's pose, beside its creature - a boss you killed lying DEAD, whoever killed you standing), the note in
      big white type, then cyan-label / white-value blocks: WHERE, LEVEL, WITH, FIGHT TOOK, FROM, CHARACTER, FILE.
    * the MEMO LINE at the foot: ALBUM, its path to copy, how many kept.

  WHAT IT CANNOT DO, AND NEVER WILL, ON ANY CLIENT: show the pictures. No addon can list a folder, and a
  .jpg in Screenshots cannot be drawn on a frame. The postcard is the nearest the game itself can come;
  the pictures stay with the album page (Album/), whose path is in the copy box at the bottom.
]]
local ADDON, ns = ...
local T, M = ns.T, ns.M
local J = {}
ns.J = J

-- THE GLASS COCKPIT (8 Nov 2026). 1.43:1, the BiS window standard - grown from 700 x 490 ("too cramp") to 1001 x 700,
-- drawn smaller on a screen too short for it (J.Fit). Measured from the window's top-left, in px:
J.W, J.H = 1001, 700
J.HEAD = 40                          -- the glareshield: the title, the X
J.KEY_Y, J.KEY_H = 46, 28            -- the bezel keys over the left display
J.DISP_TOP, J.DISP_H = 82, 544       -- the two displays
J.DISP_X, J.DISP_W = 16, 476
J.DISP_X2 = J.W - J.DISP_X - J.DISP_W
J.MEMO_Y = 668                       -- the memo line, the window's foot
J.LIST_TOP = 44                      -- inside the left display: the page header above, the lines below
J.LIST_W = J.DISP_W - 16
J.PER = 6                            -- SIX memories a page, as a flight computer's page has six lines
J.ENTRY_H, J.HEAD_H = 62, 20         -- a memory's line, a night's heading (6 of each fit: 492 of 496)
J.POST_H = 250                       -- the postcard, on top of the right display
J.VAL_X = 118                        -- the data blocks: the label at 14, the value here
J.VAL_W = J.DISP_W - J.VAL_X - 14
-- the right display's data blocks, top to bottom: key, label, height (26 unless said)
J.DATA = { { "where", "WHERE" }, { "lvl", "LEVEL" }, { "with", "WITH", 42 }, { "took", "FIGHT TOOK" },
           { "from", "FROM" }, { "char", "CHARACTER" }, { "file", "FILE" } }
-- THE BOSS ON THE POSTCARD: looked at again J.LOAD_WAIT s after each ask, at most J.LOAD_TRIES asks; J.DEAD is the
-- "dead" animation (a corpse lying) - UNVERIFIED on Forever, the death animation (1) where the client says it has
-- none; the camera stands back J.BOSS_CAM once the model has drawn
J.LOAD_WAIT, J.LOAD_TRIES = 0.6, 3
J.DEAD, J.BOSS_CAM = 6, 1.5
local GAP = 3 * 60 * 60             -- seconds of quiet that end a raid night (same rule as the album)

-- THE DISPLAYS' COLOURS, each with ONE meaning, the way a jetliner's glass uses them: GREEN good / lit / selected-ok,
-- CYAN information and labels, MAGENTA the chosen item (the active route), AMBER caution, WHITE data. The housing
-- around them wears BiSTheme's palette (ns.T); these belong to the glass alone.
J.GLASS = { green = "46d160", cyan = "3fc8e4", magenta = "e256e0", amber = "f2a93b", white = "f2f2f2",
            black = "000000", sky = "070b14" }
function J.Glass(name)
  local hex = J.GLASS[name] or J.GLASS.white
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
function J.Ink(name, s) return "|cff" .. (J.GLASS[name] or J.GLASS.white) .. tostring(s) .. "|r" end

local function hidden(v)
  if v == nil or not issecretvalue then return false end
  local ok, yes = pcall(issecretvalue, v)
  return (not ok) or yes == true
end

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

--- The memories on show: this character's, or every character's (J.everyone). A share card (Share.lua) is a picture
--- OF a memory, kept in the album for its page, never a memory of its own here.
function J.Entries()
  local log, out = M.Log(), {}
  local me = M.Me()
  for _, e in ipairs(log) do
    if e.reason ~= "share" and (J.everyone or e.char == nil or e.char == me) then out[#out + 1] = e end
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

--- The journal's version mark: "0.9.4", or on a copy deploy.sh stamped ("feat/x@abc1234+ 1106-1841")
--- "0.9.4  abc1234+ 1106-1841" - the branch is left out to keep it short (it is in the full stamp).
function J.Mark()
  local b, v = ns.BUILD, tostring(ns.VERSION)
  local sha = type(b) == "string" and b:match("@(%S+)")
  if not sha then return v end
  local at = b:match("@%S+%s+(%S+)%s*$")
  return v .. "  " .. sha .. (at and (" " .. at) or "")
end

--------------------------------------------------------------------- the window --

--- EVERYTHING CLICKABLE POPS UNDER THE MOUSE (Arn, 6 Nov 2026; BiS Tools' processing window is the model):
--- an accent wash, a 3 px accent bar on the left, the label at full brightness - and back again when the
--- mouse leaves (to the label's resting colour: `b.restColor` {r, g, b} when the label wears a display colour,
--- else the theme's `b.ink`, "ink2" if unset). `over`: the wash sits OVER the words (a patch on top of its parent's
--- text), so it stays a tint and the bar does the popping. Whatever the button already does on hover (its tooltip)
--- still runs. `b.popIf(b)` false: nothing to click, no light.
J.POP, J.TINT = 0.32, 0.25
function J.Pop(b, label, over)
  b.wash = b.wash or tex(b, "BORDER", "accent", 1)
  b.wash:SetAllPoints()
  b.wash:SetAlpha(0)
  b.bar = b.bar or tex(b, "ARTWORK", "accent", 1)
  b.bar:SetPoint("TOPLEFT", 0, 0)
  b.bar:SetPoint("BOTTOMLEFT", 0, 0)
  b.bar:SetWidth(3)
  b.bar:SetAlpha(0)
  local enter, leave = b:GetScript("OnEnter"), b:GetScript("OnLeave")
  b:SetScript("OnEnter", function(self, ...)
    if not (self.popIf and not self:popIf()) then
      self.wash:SetAlpha(over and J.TINT or J.POP)
      self.bar:SetAlpha(1)
      if label then label:SetTextColor(rgb("ink")) end
    end
    if enter then return enter(self, ...) end
  end)
  b:SetScript("OnLeave", function(self, ...)
    self.wash:SetAlpha(0)
    self.bar:SetAlpha(0)
    if label then
      local c = self.restColor
      if c then label:SetTextColor(c[1], c[2], c[3]) else label:SetTextColor(rgb(self.ink or "ink2")) end
    end
    if leave then return leave(self, ...) end
  end)
  return b
end

--- A BEZEL KEY (8 Nov 2026, the glass cockpit): a raised key set into the housing, OUTSIDE the glass - a light top
--- edge, a shadow under it (Turbo Vision's depth, Arn's 5 Nov taste), its word in capitals, and an annunciator bar
--- along its foot that lights GREEN when the key's page is the one on show. It pops under the mouse like everything.
local function key(parent, w, h, word, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  b.bg = tex(b, "BACKGROUND", "sunken", 1)
  b.bg:SetAllPoints()
  b.cap = tex(b, "BORDER", "line2", 1)
  b.cap:SetPoint("TOPLEFT", 0, 0)
  b.cap:SetPoint("TOPRIGHT", 0, 0)
  b.cap:SetHeight(1)
  b.shadow = b:CreateTexture(nil, "BORDER")
  b.shadow:SetColorTexture(0, 0, 0, 0.7)
  b.shadow:SetPoint("BOTTOMLEFT", 0, 0)
  b.shadow:SetPoint("BOTTOMRIGHT", 0, 0)
  b.shadow:SetHeight(2)
  b.lit = b:CreateTexture(nil, "OVERLAY")
  b.lit:SetColorTexture(J.Glass("green"))
  b.lit:SetPoint("BOTTOMLEFT", 8, 4)
  b.lit:SetPoint("BOTTOMRIGHT", -8, 4)
  b.lit:SetHeight(2)
  b.lit:SetAlpha(0)
  b.word = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.word:SetPoint("CENTER", 0, 1)
  if b.word.SetWordWrap then b.word:SetWordWrap(false) end
  b.word:SetText(word)
  b.ink = "ink2"
  b.word:SetTextColor(rgb(b.ink))
  b:SetScript("OnClick", onClick)
  return J.Pop(b, b.word)
end
J.Key = key

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

--- One glass display: black, a thin rim round it in the housing's line colour, set at (x, y) in the housing.
local function display(f, x)
  local d = CreateFrame("Frame", nil, f)
  d:SetPoint("TOPLEFT", f, "TOPLEFT", x, -J.DISP_TOP)
  d:SetSize(J.DISP_W, J.DISP_H)
  d.rim = tex(f, "BORDER", "line2", 1)                 -- on the housing, so it lies under the glass
  d.rim:SetPoint("TOPLEFT", f, "TOPLEFT", x - 2, -J.DISP_TOP + 2)
  d.rim:SetSize(J.DISP_W + 4, J.DISP_H + 4)
  d.glass = d:CreateTexture(nil, "BACKGROUND")
  d.glass:SetAllPoints()
  d.glass:SetColorTexture(J.Glass("black"))
  return d
end

--- The bracket either side of the chosen line (a flight computer marks its active line so): a magenta upright with a
--- short tick at each end. `side` 1 = left, -1 = right.
local function bracket(parent, side)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(8, J.ENTRY_H - 10)
  local edge = side == 1 and "LEFT" or "RIGHT"
  local mr, mg, mb = J.Glass("magenta")
  b.bar = b:CreateTexture(nil, "OVERLAY")
  b.bar:SetColorTexture(mr, mg, mb, 1)
  b.bar:SetPoint("TOP" .. edge, 0, 0)
  b.bar:SetPoint("BOTTOM" .. edge, 0, 0)
  b.bar:SetWidth(2)
  b.top = b:CreateTexture(nil, "OVERLAY")
  b.top:SetColorTexture(mr, mg, mb, 1)
  b.top:SetPoint("TOP" .. edge, 0, 0)
  b.top:SetSize(8, 2)
  b.bot = b:CreateTexture(nil, "OVERLAY")
  b.bot:SetColorTexture(mr, mg, mb, 1)
  b.bot:SetPoint("BOTTOM" .. edge, 0, 0)
  b.bot:SetSize(8, 2)
  b:Hide()
  return b
end

local function build()
  if J.frame then return J.frame end
  local W, H = J.W, J.H
  local f = CreateFrame("Frame", "BiSMemoriesJournal", UIParent)
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  ------------------------------------------------ the housing: quiet, BiSTheme's own ground
  f.housing = tex(f, "BACKGROUND", "bg", 0.97)
  f.housing:SetAllPoints()
  local shield = tex(f, "BORDER", "surface", 1)        -- the glareshield along the top
  shield:SetPoint("TOPLEFT", 0, 0)
  shield:SetPoint("TOPRIGHT", 0, 0)
  shield:SetHeight(J.HEAD)
  local lip = tex(f, "BORDER", "line", 1)
  lip:SetPoint("TOPLEFT", 0, -J.HEAD)
  lip:SetPoint("TOPRIGHT", 0, -J.HEAD)
  lip:SetHeight(1)

  local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  head:SetPoint("TOPLEFT", 16, -12)
  head:SetText(T.text("accent", "BiS> Memories"))

  f.close = key(f, 30, 26, "X", function() J.Hide() end)
  f.close:SetPoint("TOPLEFT", f, "TOPLEFT", W - 16 - 30, -7)
  -- THE LOUNGE (8 Nov 2026): the same memories full screen - the Clipper Lounge (Lounge.lua)
  f.lounge = key(f, 110, 26, "LOUNGE", function() if ns.Lounge then ns.Lounge.Show() end end)
  f.lounge:SetPoint("TOPLEFT", f, "TOPLEFT", W - 16 - 30 - 8 - 110, -7)
  f.lounge:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("The Clipper Lounge")
    GameTooltip:AddLine("your memories full screen - Escape or JOURNAL brings you back", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  f.lounge:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  J.Pop(f.lounge, f.lounge.word)

  ------------------------------------------------ the keys over the left display: its pages, and whose
  f.tabs = {}
  for i, p in ipairs({ { "memories", "MEMORIES" }, { "map", "MAP" }, { "this year", "YEAR" } }) do
    local b = key(f, 96, J.KEY_H, p[2], function() J.Tab(p[1]) end)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", J.DISP_X + (i - 1) * 102, -J.KEY_Y)
    b.name = p[1]
    f.tabs[i] = b
  end
  f.who = key(f, 150, J.KEY_H, "THIS CHARACTER", function()
    J.everyone = not J.everyone
    J.pageNo = 1
    J.Refresh()
  end)
  f.who:SetPoint("TOPLEFT", f, "TOPLEFT", J.DISP_X + J.DISP_W - 150, -J.KEY_Y)
  f.who:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(J.everyone and "every character's memories" or "this character's memories")
    GameTooltip:AddLine("click: " .. (J.everyone and "only this character's" or "every character's"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  f.who:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  J.Pop(f.who, f.who.word)

  -- SHARE (8 Nov 2026): the chosen memory as a share card - the boarding pass big and alone, one picture to post
  -- (Share.lua). Over the right display, which holds the memory it shares.
  f.share = key(f, 110, J.KEY_H, "SHARE", function() if ns.Share and J.sel then ns.Share.Take(J.sel) end end)
  f.share:SetPoint("TOPLEFT", f, "TOPLEFT", J.DISP_X2 + J.DISP_W - 110, -J.KEY_Y)
  f.share.popIf = function() return J.sel ~= nil end
  f.share:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("share card")
    GameTooltip:AddLine("this memory as a picture to post anywhere - the boarding pass, big and alone", 0.8, 0.8, 0.8)
    local d = ns.DB and ns.DB()
    GameTooltip:AddLine((type(d) == "table" and d.shareHidden == false) and "names shown - /bism share names off hides them"
      or "names hidden - /bism share names on shows them", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  f.share:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  J.Pop(f.share, f.share.word)

  ------------------------------------------------ the two displays
  f.left = display(f, J.DISP_X)
  f.right = display(f, J.DISP_X2)

  -- the left display's page header, and the hairline under it
  f.pageHead = f.left:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.pageHead:SetPoint("TOPLEFT", 14, -12)
  if f.pageHead.SetWordWrap then f.pageHead:SetWordWrap(false) end
  f.headLine = f.left:CreateTexture(nil, "BORDER")
  f.headLine:SetColorTexture(J.Glass("cyan"))
  f.headLine:SetAlpha(0.35)
  f.headLine:SetPoint("TOPLEFT", 8, -J.LIST_TOP + 4)
  f.headLine:SetSize(J.DISP_W - 16, 1)

  ------------------------------------------------ memories: the flight computer's page
  local list = CreateFrame("Frame", nil, f.left)
  list:SetPoint("TOPLEFT", f.left, "TOPLEFT", 8, -J.LIST_TOP)
  list:SetSize(J.LIST_W, J.DISP_H - J.LIST_TOP - 4)
  f.list = list
  f.hits, f.rows, f.subs = {}, {}, {}
  for i = 1, 2 * J.PER do
    -- a line: the patch the mouse lights and clicks; it hands the drag on to the window, so a line never pins it
    local hit = CreateFrame("Button", nil, list)
    hit:SetSize(J.LIST_W, J.ENTRY_H)
    hit:RegisterForDrag("LeftButton")
    hit:SetScript("OnDragStart", function() f:StartMoving() end)
    hit:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    hit:SetScript("OnEnter", function(self) J.Tip(self, self.entry) end)
    hit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    hit:SetScript("OnClick", function(self) if self.entry then J.Select(self.entry) end end)
    hit.sub = hit:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hit.sub:SetPoint("TOPLEFT", 14, -9)
    hit.sub:SetJustifyH("LEFT")
    if hit.sub.SetWordWrap then hit.sub:SetWordWrap(false) end
    hit.title = hit:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    hit.title:SetPoint("TOPLEFT", 14, -27)
    hit.title:SetJustifyH("LEFT")
    if hit.title.SetWordWrap then hit.title:SetWordWrap(false) end
    -- a night's heading is a cyan separator: a hairline under its words
    hit.sep = hit:CreateTexture(nil, "BORDER")
    hit.sep:SetColorTexture(J.Glass("cyan"))
    hit.sep:SetAlpha(0.5)
    hit.sep:SetPoint("BOTTOMLEFT", 6, 2)
    hit.sep:SetSize(J.LIST_W - 12, 1)
    hit.sep:Hide()
    -- the patch lies over the line's words, so its wash is a tint; a night's heading is no button
    hit.popIf = function(self) return self.entry ~= nil end
    J.Pop(hit, hit.title, true)
    hit:Hide()
    f.hits[i], f.rows[i], f.subs[i] = hit, hit.title, hit.sub
  end
  f.selL, f.selR = bracket(list, 1), bracket(list, -1)
  -- the wheel turns the page (on the map, the map's own wheel turns its range instead)
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta)
    if J.page == "memories" then J.Turn((delta or 0) > 0 and -1 or 1) end
  end)

  ------------------------------------------------ the right display: the memory
  local d = CreateFrame("Frame", nil, f.right)
  d:SetPoint("TOPLEFT", f.right, "TOPLEFT", 0, 0)
  d:SetSize(J.DISP_W, J.DISP_H)
  f.detail = d
  local post = CreateFrame("Frame", nil, d)
  post:SetPoint("TOPLEFT", 2, -2)
  post:SetSize(J.DISP_W - 4, J.POST_H)
  local pbg = post:CreateTexture(nil, "BACKGROUND")
  pbg:SetAllPoints()
  pbg:SetColorTexture(J.Glass("sky"))
  post.you = model(post, 200, J.POST_H - 6)
  post.you:SetPoint("BOTTOMLEFT", 24, 3)
  post.them = model(post, 250, J.POST_H - 6)
  post.them:SetPoint("BOTTOMRIGHT", -12, 3)
  post.note = label(post, "GameFontHighlightSmall", 10, -8)
  f.post = post
  local x, y = 14, -(J.POST_H + 12)
  f.kind = label(d, "GameFontHighlightSmall", x, y)
  f.text = label(d, "GameFontHighlightLarge", x, y - 18, J.DISP_W - 2 * x, 40)
  f.text:SetTextColor(J.Glass("white"))
  -- THE DATA BLOCKS: a cyan label, a white value, each in its own place (a jetliner never moves a readout about);
  -- one with nothing to say is not drawn at all
  f.data = {}
  local rowY = y - 68
  for _, r in ipairs(J.DATA) do
    local lab = label(d, "GameFontHighlightSmall", x, rowY - 1)
    lab:SetText(r[2])
    lab:SetTextColor(J.Glass("cyan"))
    local val = label(d, "GameFontHighlight", J.VAL_X, rowY)
    val:SetTextColor(J.Glass("white"))
    f.data[r[1]] = { lab = lab, val = val, y = rowY }
    rowY = rowY - (r[3] or 26)
  end
  f.whoWith = f.data.with.lab
  f.withX, f.withY, f.withW = J.VAL_X, f.data.with.y, J.VAL_W
  f.withBtns = {}
  f.fileBox = CreateFrame("EditBox", nil, d)
  f.fileBox:SetPoint("TOPLEFT", J.VAL_X - 4, f.data.file.y + 2)
  f.fileBox:SetSize(J.VAL_W, 18)
  f.fileBox:SetAutoFocus(false)
  f.fileBox:SetFontObject("GameFontHighlight")
  f.fileBox:SetTextColor(J.Glass("white"))
  f.fileBox:SetTextInsets(4, 4, 0, 0)
  local fbg = f.fileBox:CreateTexture(nil, "BACKGROUND")
  fbg:SetAllPoints()
  fbg:SetColorTexture(1, 1, 1, 0.07)
  f.fileBox:SetScript("OnMouseUp", function(self) self:HighlightText() self:SetFocus() end)
  f.fileBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  f.fileBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  f.fileBox:SetScript("OnEnterPressed", function(self) self:SetText(J.sel and J.sel.file or "") self:HighlightText() end)

  ------------------------------------------------ the map page: a navigation display on the left glass
  local map = CreateFrame("Frame", nil, f.left)
  map:SetPoint("TOPLEFT", f.left, "TOPLEFT", 2, -2)
  map:SetSize(J.DISP_W - 4, J.DISP_H - 4)
  f.map = map
  if ns.MapView then ns.MapView.Glass(map) end
  map.onView = function() if J.frame and J.frame:IsShown() and J.page == "map" then J.PaintMap(f) end end
  -- what it says sits on a strip of its own over the art, at the foot of the glass
  map.overlay = CreateFrame("Frame", nil, map)
  map.overlay:SetAllPoints()
  if map.overlay.SetFrameLevel and map.GetFrameLevel then map.overlay:SetFrameLevel((map:GetFrameLevel() or 0) + 20) end
  local strip = map.overlay:CreateTexture(nil, "BACKGROUND")
  strip:SetColorTexture(0, 0, 0, 0.75)
  strip:SetPoint("BOTTOMLEFT", 0, 0)
  strip:SetPoint("BOTTOMRIGHT", 0, 0)
  strip:SetHeight(24)
  map.say = label(map.overlay, "GameFontHighlightSmall", 10, -(J.DISP_H - 4 - 18))
  map.say:SetTextColor(J.Glass("cyan"))

  ------------------------------------------------ the year page
  local year = CreateFrame("Frame", nil, f.left)
  year:SetPoint("TOPLEFT", f.left, "TOPLEFT", 8, -J.LIST_TOP)
  year:SetSize(J.LIST_W, J.DISP_H - J.LIST_TOP - 4)
  year.lines = {}
  for i = 1, 10 do
    year.lines[i] = label(year, "GameFontHighlight", 8, -10 - (i - 1) * 30, J.LIST_W - 20, 24)
    year.lines[i]:SetTextColor(J.Glass(i == 1 and "cyan" or "white"))
  end
  f.year = year

  ------------------------------------------------ the soft keys under the left display (they change with its page)
  local softY = -(J.DISP_TOP + J.DISP_H + 8)
  f.prev = key(f, 130, J.KEY_H, "PREV PAGE", function() J.Turn(-1) end)
  f.prev:SetPoint("TOPLEFT", f, "TOPLEFT", J.DISP_X, softY)
  f.next = key(f, 130, J.KEY_H, "NEXT PAGE", function() J.Turn(1) end)
  f.next:SetPoint("TOPLEFT", f, "TOPLEFT", J.DISP_X + J.DISP_W - 130, softY)
  -- THE RANGE KNOB: - and + keys either side, its readout in the middle, a tick per range, the one in use lit
  local kx = J.DISP_X + math.floor((J.DISP_W - 236) / 2)
  local zoom = function(n) if ns.MapView then ns.MapView.Zoom(f.map, n) end end
  f.rangeDown = key(f, 40, J.KEY_H, "-", function() zoom(-1) end)
  f.rangeDown:SetPoint("TOPLEFT", f, "TOPLEFT", kx, softY)
  f.rangeUp = key(f, 40, J.KEY_H, "+", function() zoom(1) end)
  f.rangeUp:SetPoint("TOPLEFT", f, "TOPLEFT", kx + 196, softY)
  local knob = key(f, 140, J.KEY_H, "", function()
    local MV = ns.MapView
    if not MV then return end
    if MV.Zoomed(f.map) >= MV.ZOOMS[#MV.ZOOMS] then MV.Reset(f.map) else MV.Zoom(f.map, 1) end
  end)
  knob:SetPoint("TOPLEFT", f, "TOPLEFT", kx + 48, softY)
  knob.word:ClearAllPoints()
  knob.word:SetPoint("LEFT", knob, "LEFT", 10, 1)
  knob.word:SetText("RANGE")
  knob.word:SetTextColor(J.Glass("cyan"))
  knob.restColor = { J.Glass("cyan") }
  knob.value = knob:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  knob.value:SetPoint("RIGHT", knob, "RIGHT", -10, 1)
  knob.value:SetTextColor(J.Glass("white"))
  knob.ticks = {}
  local n = ns.MapView and #ns.MapView.ZOOMS or 5
  for i = 1, n do
    local t = knob:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(J.Glass("green"))
    t:SetSize(10, 2)
    t:SetPoint("BOTTOMLEFT", knob, "BOTTOMLEFT", 10 + (i - 1) * 14, 4)
    knob.ticks[i] = t
  end
  knob:EnableMouseWheel(true)
  knob:SetScript("OnMouseWheel", function(_, delta) zoom((delta or 0) > 0 and 1 or -1) end)
  f.knob = knob

  ------------------------------------------------ the memo line: the album page's path, ready to copy
  local memo = f:CreateTexture(nil, "BORDER")
  memo:SetColorTexture(J.Glass("black"))
  memo:SetPoint("TOPLEFT", f, "TOPLEFT", J.DISP_X, -J.MEMO_Y)
  memo:SetSize(W - 2 * J.DISP_X, 24)
  f.pathLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.pathLabel:SetPoint("TOPLEFT", f, "TOPLEFT", J.DISP_X + 10, -(J.MEMO_Y + 6))
  f.pathLabel:SetJustifyH("LEFT")
  f.pathLabel:SetText("ALBUM")
  f.pathLabel:SetTextColor(J.Glass("cyan"))
  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(J.DISP_X + 10), -(J.MEMO_Y + 6))
  f.count:SetJustifyH("RIGHT")
  f.count:SetTextColor(J.Glass("green"))
  -- THE VERSION MARK (Arn, 6 Nov 2026): which version, and on a deployed test copy which commit and when - faint, in
  -- the quiet bezel under the right display. Not in the glareshield: it has its label (one bar, one label).
  f.build = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  if STANDARD_TEXT_FONT then pcall(f.build.SetFont, f.build, STANDARD_TEXT_FONT, 8) end
  f.build:SetPoint("BOTTOMRIGHT", -J.DISP_X, H - J.DISP_TOP - J.DISP_H - 30)
  f.build:SetJustifyH("RIGHT")
  f.build:SetAlpha(0.6)
  f.pathBox = CreateFrame("EditBox", nil, f)
  f.pathBox:SetPoint("TOPLEFT", f, "TOPLEFT", J.DISP_X + 62, -(J.MEMO_Y + 3))
  f.pathBox:SetSize(W - 2 * J.DISP_X - 62 - 110, 18)
  f.pathBox:SetAutoFocus(false)
  f.pathBox:SetFontObject("GameFontHighlightSmall")
  f.pathBox:SetTextColor(J.Glass("white"))
  f.pathBox:SetTextInsets(4, 4, 0, 0)
  f.pathBox:SetScript("OnMouseUp", function(self) self:HighlightText() self:SetFocus() end)
  f.pathBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  f.pathBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  f.pathBox:SetScript("OnEnterPressed", function(self) self:SetText(J.AlbumPath()) self:HighlightText() end)
  -- how to use it lives in the tooltip, which has a whole box to itself (one bar, one label)
  f.pathBox:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("your album page")
    GameTooltip:AddLine("click, Ctrl+C, then Windows key + R, Ctrl+V, Enter", 0.8, 0.8, 0.8)
    if not J.AlbumPathWhole() then GameTooltip:AddLine("WoW somewhere else? /bism wow <folder>", 0.7, 0.7, 0.7) end
    GameTooltip:Show()
  end)
  f.pathBox:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  -- shut (Escape, X, anything): a drag in hand stops, and the postcard is asked afresh next time
  f:SetScript("OnHide", function()
    if ns.MapView then ns.MapView.StopDrag(f.map) end
    f.post.postFor = nil
  end)
  if UISpecialFrames then table.insert(UISpecialFrames, "BiSMemoriesJournal") end
  f:Hide()
  J.frame = f
  J.page = J.page or "memories"
  return f
end
J.Build = build

--- KEEP IT ON THE SCREEN: the window is drawn at its full size when the screen has room, smaller (same shape) when not.
function J.Fit()
  local f = build()
  local s = 1
  if UIParent and UIParent.GetHeight then
    local uh, uw = UIParent:GetHeight() or 0, UIParent:GetWidth() or 0
    if uh > 0 then s = math.min(s, (uh - 40) / J.H) end
    if uw > 0 then s = math.min(s, (uw - 40) / J.W) end
  end
  s = math.max(0.4, s)
  f:SetScale(s)
  return s
end

--------------------------------------------------------------------- painting --

--- THE PAGES: J.PER memories each, newest first; each night's heading goes over its first memory on a page (so a page
--- that starts inside a night says which night). A page: { {head = h} | {entry = e}, ... }.
function J.Pages()
  local pages, cur, head = {}, nil, nil
  for _, l in ipairs(J.Lines()) do
    if l.head then
      head = l.head
    else
      if not cur or cur.n == J.PER then
        cur = { n = 0 }
        pages[#pages + 1] = cur
      end
      if cur.head ~= head then
        cur[#cur + 1] = { head = head }
        cur.head = head
      end
      cur[#cur + 1] = { entry = l.entry }
      cur.n = cur.n + 1
    end
  end
  return pages
end

--- Which page holds a memory (nil when it is not on show).
function J.PageOf(e)
  if type(e) ~= "table" then return nil end
  for p, page in ipairs(J.Pages()) do
    for _, l in ipairs(page) do if l.entry == e then return p end end
  end
end

--- Turn the page by `by` (the wheel, PREV / NEXT PAGE), clamped. Answers the page it landed on.
function J.Turn(by)
  local n = math.max(1, #J.Pages())
  J.pageNo = math.max(1, math.min(n, (J.pageNo or 1) + (by or 0)))
  if J.frame and J.frame:IsShown() then J.Refresh() end
  return J.pageNo
end
J.Scroll = J.Turn

--- Which page: "memories", "map" or "this year" (the left display; the right one always holds the memory).
function J.Tab(name)
  J.page = name
  if J.frame and J.frame:IsShown() then J.Refresh() end
  return J.page
end

--- Open a memory: the right display holds it whole, the postcard shows it, and the list turns to its page.
function J.Select(e)
  J.sel = e
  local p = J.PageOf(e)
  if p then J.pageNo = p end
  if J.frame and J.frame:IsShown() then J.Refresh() end
  return e
end

--- Has the client put a model in this frame? (its file id; 0 or nothing when it has not)
function J.Drawn(m)
  if not (m and m.GetModelFileID) then return false end
  local ok, file = pcall(m.GetModelFileID, m)
  if not ok or hidden(file) then return false end
  return type(file) == "number" and file > 0
end

--- BiS Tools' Codex, when it is installed and knows the creature: its model (a display id). Never required.
function J.Codex(npc)
  local A = _G.BiSToolsAPI
  if not (npc and type(A) == "table" and A.major == 1 and type(A.CodexCreature) == "function") then return nil end
  local ok, c = pcall(A.CodexCreature, npc)
  local disp = ok and type(c) == "table" and tonumber(c.display) or nil
  return (disp and disp > 0) and disp or nil
end

--- The creature's look, once it has drawn: a boss lies dead (J.DEAD - the death animation where the client has no
--- "dead" pose), anyone else stands; and the camera, which a new model resets, so it is set only now.
function J.Look(m, e)
  local anim = 0
  if type(e) == "table" and e.reason == "boss" then
    anim = J.DEAD
    if m.HasAnimation then
      local ok, has = pcall(m.HasAnimation, m, J.DEAD)
      if ok and has == false then anim = 1 end
    end
  end
  pcall(m.SetAnimation, m, anim)
  pcall(m.SetPortraitZoom, m, 0)
  pcall(m.SetCamDistanceScale, m, J.BOSS_CAM)
  m.lookedFor = e                                        -- drawn and posed: the share card waits for this
end

--- Ask the client for the creature: its model (display id) when known, else the creature by npc id - and look again
--- J.LOAD_WAIT later: drawn, its pose and camera; nothing drawn, ask again (a creature draws nothing on its first ask
--- in a session; the second lands - BiS Shell's probe, 18 Oct), at most J.LOAD_TRIES asks. A look meant for a memory
--- no longer open does nothing.
function J.Ask(m, e, body, tries)
  if body.display then pcall(m.SetDisplayInfo, m, body.display) else pcall(m.SetCreature, m, body.npc) end
  pcall(m.SetFacing, m, -0.6)                            -- turned toward you
  tries = (tries or 0) + 1
  if not (C_Timer and C_Timer.After) then
    if J.Drawn(m) then J.Look(m, e) end
    return
  end
  local token = m.askToken                               -- the model's own: a newer postcard in it makes this one stale
  C_Timer.After(J.LOAD_WAIT, function()
    -- the memory still open: the journal's chosen one, or the one a postcard of its own holds (the share card's)
    if m.askToken ~= token or (m.forEntry or J.sel) ~= e or not m:IsShown() then return end
    if J.Drawn(m) then return J.Look(m, e) end
    if tries >= J.LOAD_TRIES then return end
    if tries == 2 and body.display and body.npc then body = { npc = body.npc } end   -- the model would not: the creature
    J.Ask(m, e, body, tries)
  end)
end

--- THE POSTCARD: you in 3D, in what you wore and the moment's pose, beside its creature - a boss you killed lying
--- dead at your feet (Arn, 8 Nov 2026: "bis memories is not showing the boss dead"), whoever killed you standing over
--- you. Only your own memories draw you: an addon can draw the character you are playing, not one who is logged out.
--- Asked once per memory opened (a page turn or a new note does not ask the client again).
--- `p`: the postcard to draw in - the journal's (the default), or any frame holding `you` and `them` (DressUpModels)
--- and a `note` label: the Clipper Lounge's window seat draws through this same function (Lounge.lua). `p.own`: the
--- postcard holds a memory of its own, not the journal's chosen one (the share card, Share.lua).
function J.Postcard(e, p)
  p = p or (J.frame and J.frame.post)
  if not p then return end
  if p.postFor == e then return end
  p.postFor = e
  local you, them = p.you, p.them
  them.askToken = (them.askToken or 0) + 1
  them.forEntry = p.own and e or nil
  them.lookedFor = nil
  -- only the character who took it: an old note nobody has claimed yet (M.ClaimOld) draws nobody
  local mine = type(e) == "table" and e.char == M.Me()
  p.note:SetText("")
  p.note:SetTextColor(J.Glass("cyan"))
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
      p.note:SetText("played by " .. tostring(e.char):match("^[^%-]+"))
    elseif type(e) == "table" then
      p.note:SetText("an older picture - its character logs in to claim it")
    end
  end
  local npc = M.Face(e)
  local display = type(e) == "table" and tonumber(e.display) or nil
  if display and display <= 0 then display = nil end
  if npc and not display then display = J.Codex(npc) end
  if npc or display then
    them:Show()                                          -- shown first: a hidden model loads nothing
    pcall(them.ClearModel, them)
    J.Ask(them, e, { npc = npc, display = display }, 0)
  else
    them:Hide()
  end
end

--- THE GAME'S OWN PLAYER MENU for a name (Arn, 21 Oct 2026: "so a year from now i can add them to bis pal
--- or invite them again"): whisper, invite, add friend - and BiS Tools' pal line, which joins this menu.
--- The FRIEND menu, as BiS Guild's terminal opens it (a guild menu opened by an addon can taint).
--- NEVER INSIDE AN INSTANCE (7 Nov 2026 sweep): the game's player menu opened from an addon's code there breaks the
--- game's own menu for the rest of the session. So it opens only when IsInInstance() answers a plain `false` - a
--- hidden answer, an error or no such call is not a "no" - and otherwise one line says how to reach them instead.
function J.Outside()
  if not IsInInstance then return false end
  local ok, inside = pcall(IsInInstance)
  if not ok then return false end
  if issecretvalue then
    local asked, hidden = pcall(issecretvalue, inside)
    if not asked or hidden then return false end
  end
  return rawequal(inside, false)
end

function J.PlayerMenu(name)
  if type(name) ~= "string" or name == "" then return false end
  if not J.Outside() then
    ns.Print("%s - inside an instance the game keeps that menu to itself: /w %s, or click again outside",
      tostring(name), tostring(name))
    return false
  end
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
  if #names == 0 then f.whoWith:Hide() return 0 end
  f.whoWith:Show()
  local colours = _G.RAID_CLASS_COLORS
  local x, row, shown = 0, 0, 0
  for i, name in ipairs(names) do
    local b = f.withBtns[i]
    if not b then
      b = CreateFrame("Button", nil, f.detail)
      b:SetHeight(18)
      b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      b.fs:SetPoint("LEFT", 3, 0)              -- clear of the hover bar
      b.fs:SetWordWrap(false)
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
      J.Pop(b)                                  -- the wash and the bar; the name keeps its class colour
      f.withBtns[i] = b
    end
    b.who = name
    b.fs:SetText(name .. (i < #names and "," or ""))
    local cls = type(e.withClass) == "table" and e.withClass[i]
    local cc = cls and colours and colours[cls]
    if cc then b.fs:SetTextColor(cc.r, cc.g, cc.b) else b.fs:SetTextColor(J.Glass("white")) end
    local w = math.ceil(b.fs:GetStringWidth() or 40) + 8
    if x > 0 and x + w > f.withW then x, row = 0, row + 1 end
    if row >= J.WITH_ROWS then break end
    b:SetWidth(w)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", f.detail, "TOPLEFT", f.withX + x - 3, f.withY - row * 18 + 2)
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

local function setRow(f, k, value)
  local row = f.data[k]
  local on = value ~= nil and value ~= ""
  row.lab:SetShown(on)
  row.val:SetShown(on)
  row.val:SetText(on and value ~= true and J.Clip(value, J.VAL_W, 12) or "")
end

local function paintDetail(f)
  local e = J.sel
  if type(e) ~= "table" then
    f.post.postFor = nil
    f.post.you:Hide()
    f.post.them:Hide()
    f.post.note:SetText("")
    local none = #M.Log() == 0
    f.kind:SetText(J.Ink("cyan", none and "NOTHING YET"
      or (J.page == "map" and "SELECT A PIN ON THE MAP" or "SELECT A MEMORY ON THE LEFT")))
    f.text:SetText(none and "It fires on levels, first kills, rare loot, achievements and more." or "")
    for _, r in ipairs(J.DATA) do setRow(f, r[1], nil) end
    for _, b in ipairs(f.withBtns) do b:Hide() end
    f.fileBox:Hide()
    return
  end
  J.Postcard(e)
  local word = J.Clip(M.Word(e.reason):upper(), 200, 10)
  f.kind:SetText(J.Ink("cyan", word) .. "     " .. J.Ink("white", (when(e.at, "%a %d %b %Y  %H:%M"):upper())))
  f.text:SetText(tostring(e.detail or ""))
  setRow(f, "where", e.zone and tostring(e.zone) or nil)
  setRow(f, "lvl", (type(e.level) == "number" and e.level > 0) and tostring(e.level) or nil)
  local n = J.PaintWith(f, e)
  f.data.with.val:SetText("")
  f.data.with.val:SetShown(false)
  f.data.with.lab:SetShown(n > 0)
  setRow(f, "took", tonumber(e.secs) and ("%d:%02d"):format(math.floor(e.secs / 60), math.floor(e.secs % 60)) or nil)
  setRow(f, "from", e.from and tostring(e.from) or nil)
  setRow(f, "char", (e.char and e.char ~= M.Me()) and tostring(e.char) or nil)
  f.data.file.val:SetShown(false)
  f.data.file.lab:SetShown(e.file ~= nil)
  if e.file then
    f.fileBox:Show()
    f.fileBox:SetText(e.file)
    f.fileBox:SetCursorPosition(0)
  else
    f.fileBox:Hide()
  end
end

--- A night's heading, as the page shows it (no colour codes: the line wears cyan).
function J.HeadPlain(h) return (J.Head(h):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

--- One memory's upper line on the page: when, and what kind ("SAT 19 SEP  20:14   BOSS").
function J.Sub(e)
  return (when(e.at, "%a %d %b  %H:%M"):upper()) .. "   " .. M.Word(e.reason):upper()
end

local function paintList(f)
  local pages = J.Pages()
  local np = math.max(1, #pages)
  J.pageNo = math.max(1, math.min(np, J.pageNo or 1))
  local page = pages[J.pageNo] or {}
  f.pageHead:SetText(J.Ink("cyan", "MEMORIES") .. " " .. J.Ink("white", J.pageNo .. "/" .. np))
  f.selL:Hide()
  f.selR:Hide()
  local px = J.LIST_W - 40                     -- clear of the brackets either side
  local cr, cg, cb = J.Glass("cyan")
  local y = 0
  for i, hit in ipairs(f.hits) do
    local l = page[i]
    hit.entry = l and l.entry or nil
    if not l then
      hit:Hide()
    else
      local h = l.head and J.HEAD_H or J.ENTRY_H
      hit:ClearAllPoints()
      hit:SetPoint("TOPLEFT", f.list, "TOPLEFT", 0, -y)
      hit:SetSize(J.LIST_W, h)
      hit:Show()
      y = y + h
      if l.head then
        hit.sep:Show()
        hit.sub:SetText("")
        hit.title:SetFontObject("GameFontHighlightSmall")
        hit.title:ClearAllPoints()
        hit.title:SetPoint("TOPLEFT", 6, -5)
        hit.title:SetText(J.Clip(J.HeadPlain(l.head), J.LIST_W - 12, 10))
        hit.title:SetTextColor(cr, cg, cb)
        hit.restColor = { cr, cg, cb }
      else
        local e = l.entry
        hit.sep:Hide()
        hit.sub:SetText(J.Clip(J.Sub(e), px, 10))
        hit.sub:SetTextColor(cr, cg, cb)
        hit.title:SetFontObject("GameFontHighlightLarge")
        hit.title:ClearAllPoints()
        hit.title:SetPoint("TOPLEFT", 14, -27)
        hit.title:SetText(J.Clip(tostring(e.detail or ""), px, 16))
        local chosen = e == J.sel
        hit.restColor = { J.Glass(chosen and "magenta" or "white") }
        hit.title:SetTextColor(unpack(hit.restColor))
        if chosen then
          f.selL:ClearAllPoints()
          f.selL:SetPoint("TOPLEFT", hit, "TOPLEFT", 2, -5)
          f.selR:ClearAllPoints()
          f.selR:SetPoint("TOPRIGHT", hit, "TOPRIGHT", -2, -5)
          f.selL:Show()
          f.selR:Show()
        end
      end
    end
  end
end

function J.PaintMap(f)
  local MV = ns.MapView
  local map = J.mapID or (MV and MV.Start())
  local n, inside, rough
  if MV and map then
    local off
    n, inside, off, rough = MV.Draw(f.map, J.Entries(), map, function(e) J.Select(e) end, J.sel)
  end
  if not n then
    f.map.say:SetText(J.Clip("NO MAP ART FROM THE GAME HERE - THE PINS ON YOUR WORLD MAP STILL SHOW", J.DISP_W - 24, 10))
    f.map.say:SetTextColor(J.Glass("amber"))
  else
    local bits = { ("%d on the map"):format(n) }
    if (rough or 0) > 0 then bits[#bits + 1] = ("%d older, placed by their zone"):format(rough) end
    if (inside or 0) > 0 then bits[#bits + 1] = ("%d inside a dungeon or battleground"):format(inside) end
    f.map.say:SetText(J.Clip(table.concat(bits, "  -  "), J.DISP_W - 24, 10))
    f.map.say:SetTextColor(J.Glass("cyan"))
  end
  local z = MV and f.map.view and f.map.view.z or 1
  f.knob.value:SetText(MV and MV.RANGES[z] or "1x")
  for i, t in ipairs(f.knob.ticks) do t:SetAlpha(i == z and 1 or 0.25) end
end

local function paintYear(f)
  f.pageHead:SetText(J.Ink("cyan", "THIS YEAR"))
  local s = M.Summary(nil, (not J.everyone) and M.Me() or nil)
  local lines = M.SummaryLines(s)
  for i, fs in ipairs(f.year.lines) do
    local t = lines[i]
    fs:SetText(t and J.Clip(t, J.LIST_W - 20, 12) or "")
  end
end

function J.Refresh()
  local f = build()
  J.page = J.page or "memories"
  for _, b in ipairs(f.tabs) do
    -- the colour on the label, not in the text, so the hover can brighten it and give it back
    local on = b.name == J.page
    b.ink = on and "ink" or "ink2"
    b.word:SetTextColor(rgb(b.ink))
    b.lit:SetAlpha(on and 1 or 0)
  end
  f.who.word:SetText(J.everyone and "ALL CHARACTERS" or "THIS CHARACTER")
  local list, mapPage, yearPage = J.page == "memories", J.page == "map", J.page == "this year"
  f.list:SetShown(list)
  f.map:SetShown(mapPage)
  f.year:SetShown(yearPage)
  f.pageHead:SetShown(not mapPage)
  f.headLine:SetShown(not mapPage)
  f.prev:SetShown(list)
  f.next:SetShown(list)
  f.knob:SetShown(mapPage)
  f.rangeDown:SetShown(mapPage)
  f.rangeUp:SetShown(mapPage)
  if not mapPage and ns.MapView then ns.MapView.StopDrag(f.map) end
  if list then paintList(f) elseif mapPage then J.PaintMap(f) else paintYear(f) end
  paintDetail(f)
  local n = #J.Entries()
  f.count:SetText(n == 0 and "" or (n .. " kept"))
  f.build:SetText(T.text("muted", J.Mark()))
  f.pathBox:SetText(J.AlbumPath())
  f.pathBox:SetCursorPosition(0)
  return true, n
end

function J.Show()
  local f = build()
  J.Fit()
  f:Show()                                     -- shown before it is painted: a hidden model loads nothing,
  f.post.postFor = nil                         -- so whatever was asked while it was shut is asked again
  J.Refresh()
  return true
end

function J.Hide()
  if J.frame then
    J.frame:Hide()
    if ns.MapView then ns.MapView.StopDrag(J.frame.map) end
    J.frame.post.postFor = nil
  end
  return true
end

function J.Toggle()
  if J.frame and J.frame:IsShown() then return J.Hide() end
  return J.Show()
end

--- Called when a memory lands, so an open window does not go stale while you play.
function J.Touch()
  if J.frame and J.frame:IsShown() then J.Refresh() end
  if ns.Lounge and ns.Lounge.Touch then ns.Lounge.Touch() end
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
    J.Pop(t)                                    -- it is a button: it says so under the mouse
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
