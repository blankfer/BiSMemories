--[[
  BiSMemories :: Core/Map.lua - where every picture was taken (Arn, 21 Oct 2026: "maybe also a map of
  where every screenshot was taken").

  Two maps, one source: each memory taken out in the world carries the client's map and your spot on it
  (Memories.lua M.Spot). Inside an instance the client gives no spot, and the zone's name is the note.
    * the JOURNAL'S MAP PAGE (Journal.lua): Azeroth, a dot for every memory; hover one for its note,
      click it to open it. Drawn the way BiS Guild's WHERE page draws (its Core/Where.lua): the map's
      own art tiles, and the client's C_Map.GetMapRectOnMap to put a zone's spot on the world - not a
      library's arithmetic, which OpenMap's notes say comes out wrong on Forever.
    * THE GAME'S WORLD MAP (Pins.lua): a pin per memory, through HereBeDragons-Pins.
]]
local ADDON, ns = ...
local M, T = ns.M, ns.T

local MV = {}
ns.MapView = MV

MV.WORLD = 947
MV.TILE = 256
MV.DOT = 8
-- a dot's colour by kind (BiSTheme's names)
MV.COLOUR = { boss = "warn", levelup = "good", loot = "gold", death = "muted", first = "accent", exalted = "gold",
              achievement = "gold", zone = "ink2", group = "good", gamba = "gold" }

local function hidden(v)
  if v == nil or not issecretvalue then return false end
  local ok, yes = pcall(issecretvalue, v)
  return (not ok) or yes == true
end
local function num(v) if hidden(v) or type(v) ~= "number" then return nil end return v end

--- A map's art: width and height in the art's pixels, and its tiles { file, x, y, w, h }. Base layer only:
--- this is your album, and your own fog of war would only hide where you have been.
--- Kept once found (MV.pieces[mapID]): a map's art does not change in a session, and the navigation display repaints
--- on every turn of the range and every frame of a drag. An answer the client would not give is asked again next time.
MV.pieces = {}
function MV.Pieces(mapID)
  local kept = mapID and MV.pieces[mapID]
  if kept then return kept[1], kept[2], kept[3] end
  local lw, lh, pieces = MV.ReadPieces(mapID)
  if lw then MV.pieces[mapID] = { lw, lh, pieces } end
  return lw, lh, pieces
end

function MV.ReadPieces(mapID)
  local CM = C_Map
  if not (mapID and CM and CM.GetMapArtLayers and CM.GetMapArtLayerTextures) then return nil end
  local ok, layers = pcall(CM.GetMapArtLayers, mapID)
  local L = ok and type(layers) == "table" and layers[1] or nil
  if type(L) ~= "table" then return nil end
  local lw, lh = num(L.layerWidth), num(L.layerHeight)
  if not (lw and lh and lw > 0 and lh > 0) then return nil end
  local tw, th = num(L.tileWidth) or MV.TILE, num(L.tileHeight) or MV.TILE
  local okF, files = pcall(CM.GetMapArtLayerTextures, mapID, 1)
  if not (okF and type(files) == "table") then return nil end
  local cols = math.ceil(lw / tw)
  local pieces = {}
  for i, file in ipairs(files) do
    local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
    pieces[#pieces + 1] = { file, c * tw, r * th, tw, th }
  end
  return lw, lh, pieces
end

--- A spot on one map, placed on another (the world): the client's own rectangle of the one on the other.
MV.rects = {}
function MV.OnMap(from, x, y, to)
  if from == to then return x, y end
  local CM = C_Map
  if not (from and to and x and y and CM and CM.GetMapRectOnMap) then return nil end
  local k = from .. ">" .. to
  local r = MV.rects[k]
  if r == nil then
    local ok, a, b, c, d = pcall(CM.GetMapRectOnMap, from, to)
    if ok then
      a = num(a)
      b = num(b)
      c = num(c)
      d = num(d)
    else
      a = nil
    end
    r = (a and b and c and d and b > a and d > c) and { a, b, c, d } or false
    MV.rects[k] = r
  end
  if not r then return nil end
  return r[1] + x * (r[2] - r[1]), r[3] + y * (r[4] - r[3])
end

--- OLD NOTES BY THEIR ZONE (Arn's map, 21 Oct 2026: "0 on the map - 246 inside dungeons" - they were not
--- inside anything; notes from before 0.9.0 simply kept no spot). Such a note still has its zone's name:
--- the zone's map is found by name among Azeroth's (C_Map.GetMapChildrenInfo, read once) and the note
--- goes near the zone's middle - a smaller, dimmer dot, spread a little so a zone's notes do not stack.
function MV.ZoneID(zone)
  if type(zone) ~= "string" or zone == "" then return nil end
  if not MV.zoneIDs then
    MV.zoneIDs = {}
    local CM = C_Map
    if CM and CM.GetMapChildrenInfo then
      local ok, kids = pcall(CM.GetMapChildrenInfo, MV.WORLD, nil, true)
      if ok and type(kids) == "table" then
        for _, k in ipairs(kids) do
          local name, id = type(k) == "table" and k.name, type(k) == "table" and num(k.mapID)
          if type(name) == "string" and not hidden(name) and id and MV.zoneIDs[name] == nil then MV.zoneIDs[name] = id end
        end
      end
    end
  end
  return MV.zoneIDs[zone] or MV.zoneIDs[zone:match("^(.-)%s+%-%s+") or ""]
end

--- The memories with a spot, as dots on `mapID`: { e, x, y, rough } (0-1 across the map). Answers the dots,
--- how many have no place at all (inside an instance), how many sit off this map, and how many are rough
--- (an old note, placed by its zone).
function MV.Dots(entries, mapID)
  local out, inside, off, rough = {}, 0, 0, 0
  for _, e in ipairs(entries) do
    if type(e) == "table" and e.map and e.x and e.y then
      local x, y = MV.OnMap(e.map, e.x, e.y, mapID)
      if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then out[#out + 1] = { e = e, x = x, y = y }
      else off = off + 1 end
    elseif type(e) == "table" then
      local zid = MV.ZoneID(e.zone)
      local at = tonumber(e.at) or 0
      local jx, jy = ((at % 97) / 97 - 0.5) * 0.3, ((at % 89) / 89 - 0.5) * 0.3
      local x, y
      if zid then x, y = MV.OnMap(zid, 0.5 + jx, 0.5 + jy, mapID) end
      if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        out[#out + 1] = { e = e, x = x, y = y, rough = true }
        rough = rough + 1
      else
        inside = inside + 1
      end
    end
  end
  return out, inside, off, rough
end

--------------------------------------------------------------------- the navigation display --
-- THE MAP AS A JETLINER'S NAVIGATION DISPLAY (Arn, 8 Nov 2026: "maybe a zoom feature on the map?" and "use the new box
-- outline with center blank"). The art on black, a RANGE you turn (the wheel, around the cursor; the bezel's knob and
-- its - / + keys), a drag to pan - clamped, so the map never slides off its glass. And DECLUTTER, the way an ND does:
-- pins closer than MV.MERGE px at this range are ONE hollow box with a count; closer in, they stand apart. Clicking a
-- box zooms in on it; clicking a single pin opens its memory.
--
-- The view is the panel's: { z = range step, cx, cy = the map spot (0-1) in the middle of the glass }. The art and the
-- pins live on a canvas inside a ScrollFrame, which cuts whatever lies past the glass's edge; pins past it are not drawn.
MV.ZOOMS = { 1, 2, 4, 8, 16 }
MV.RANGES = { "1x", "2x", "4x", "8x", "16x" }
MV.MERGE = 12            -- px: nearer than this at the current range, two pins are one box
MV.BOX, MV.SEL, MV.MANY, MV.THICK = 10, 16, 14, 2

local function view(panel)
  panel.view = panel.view or { z = 1, cx = 0.5, cy = 0.5 }
  return panel.view
end

--- The scale in px per map unit (the art's own pixels) at the panel's range, and the art's size.
local function scale(panel)
  local a = panel.art
  if not a then return nil end
  local pw, ph = panel:GetWidth(), panel:GetHeight()
  local k = math.min(pw / a.lw, ph / a.lh) * MV.ZOOMS[view(panel).z]
  return k, a.lw, a.lh, pw, ph
end

--- Half of what the glass shows of the map, across and down (0.5 = all of it): the view's centre stays that far in.
function MV.Half(panel)
  local k, lw, lh, pw, ph = scale(panel)
  if not k then return 0.5, 0.5 end
  return math.min(0.5, pw / (lw * k) / 2), math.min(0.5, ph / (lh * k) / 2)
end

local function clamp(panel)
  local v = view(panel)
  v.z = math.max(1, math.min(#MV.ZOOMS, v.z))
  local hx, hy = MV.Half(panel)
  v.cx = math.max(hx, math.min(1 - hx, v.cx))
  v.cy = math.max(hy, math.min(1 - hy, v.cy))
end

--- A point on the glass (px from its top-left) as a map spot, and back.
function MV.ToMap(panel, ux, uy)
  local k, lw, lh, pw, ph = scale(panel)
  if not k then return nil end
  local v = view(panel)
  return v.cx + (ux - pw / 2) / (lw * k), v.cy + (uy - ph / 2) / (lh * k)
end

function MV.ToScreen(panel, x, y)
  local k, lw, lh, pw, ph = scale(panel)
  if not k then return nil end
  local v = view(panel)
  return pw / 2 + (x - v.cx) * lw * k, ph / 2 + (y - v.cy) * lh * k
end

--- The range as a factor (1, 2, 4 ...).
function MV.Zoomed(panel) return MV.ZOOMS[view(panel).z] end
function MV.Range(panel) return MV.RANGES[view(panel).z] end

--- Where the cursor is on the glass, in px from its top-left.
function MV.Cursor(panel)
  local x, y = 0, 0
  if GetCursorPosition then x, y = GetCursorPosition() end
  local s = panel:GetEffectiveScale() or 1
  return x / s - (panel:GetLeft() or 0), (panel:GetTop() or 0) - y / s
end

local function changed(panel)
  if panel.onView then panel.onView(panel) end
end

--- Turn the range by `steps` (+ closer), keeping the map spot under (ux, uy) where it is (the middle when nil).
--- Answers the range step it landed on.
function MV.Zoom(panel, steps, ux, uy)
  local v = view(panel)
  if not panel.art then return v.z end
  local _, _, _, pw, ph = scale(panel)
  ux, uy = ux or pw / 2, uy or ph / 2
  local mx, my = MV.ToMap(panel, ux, uy)
  local was = v.z
  v.z = math.max(1, math.min(#MV.ZOOMS, v.z + (steps or 0)))
  if v.z == was then return v.z end
  local k, lw, lh = scale(panel)
  v.cx, v.cy = mx - (ux - pw / 2) / (lw * k), my - (uy - ph / 2) / (lh * k)
  clamp(panel)
  changed(panel)
  return v.z
end

--- Back to the whole map.
function MV.Reset(panel)
  panel.view = { z = 1, cx = 0.5, cy = 0.5 }
  changed(panel)
end

--- A merged box, clicked: close in on it far enough that its memories stand apart. Already as close as the range goes
--- (or all of them on one spot): open the newest of them.
function MV.ZoomOn(panel, b)
  local list = b and b.members
  if not (list and #list > 0) then return end
  local v = view(panel)
  local k, lw, lh = scale(panel)
  local x0, x1, y0, y1, sx, sy = 1, 0, 1, 0, 0, 0
  for _, d in ipairs(list) do
    x0, x1, y0, y1 = math.min(x0, d.x), math.max(x1, d.x), math.min(y0, d.y), math.max(y1, d.y)
    sx, sy = sx + d.x, sy + d.y
  end
  local spread = math.max((x1 - x0) * lw * k, (y1 - y0) * lh * k)
  if v.z >= #MV.ZOOMS or spread < 0.5 then
    if b.onClick then b.onClick(list[1].e) end
    return v.z
  end
  local steps = math.max(1, math.ceil(math.log(2 * MV.MERGE / spread) / math.log(2)))
  v.cx, v.cy = sx / #list, sy / #list
  v.z = math.min(#MV.ZOOMS, v.z + steps)
  clamp(panel)
  changed(panel)
  return v.z
end

--- THE DRAG: only while the button is down does anything run (the ticker is set on the press and taken away on the
--- release, on a hide, and when the window shuts) - and only a cursor that moved repaints.
function MV.StopDrag(panel)
  panel.drag = nil
  panel:SetScript("OnUpdate", nil)
end

function MV.DragTick(panel)
  local g = panel.drag
  if not g then return MV.StopDrag(panel) end
  local ux, uy = MV.Cursor(panel)
  if math.abs(ux - g.lx) < 0.5 and math.abs(uy - g.ly) < 0.5 then return end
  g.lx, g.ly = ux, uy
  local k, lw, lh = scale(panel)
  if not k then return end
  local v = view(panel)
  v.cx, v.cy = g.cx - (ux - g.x) / (lw * k), g.cy - (uy - g.y) / (lh * k)
  clamp(panel)
  changed(panel)
end

local function startDrag(panel, button)
  if button and button ~= "LeftButton" then return end
  local ux, uy = MV.Cursor(panel)
  local v = view(panel)
  panel.drag = { x = ux, y = uy, lx = ux, ly = uy, cx = v.cx, cy = v.cy }
  panel:SetScript("OnUpdate", MV.DragTick)
end

--- Make `panel` a navigation display: the glass that cuts, the canvas, the wheel and the drag. Once.
function MV.Glass(panel)
  if panel.canvas then return panel.canvas end
  local clip = CreateFrame("ScrollFrame", nil, panel)
  clip:SetAllPoints()
  local canvas = CreateFrame("Frame", nil, clip)
  canvas:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
  canvas:SetSize(panel:GetWidth(), panel:GetHeight())
  clip:SetScrollChild(canvas)
  panel.clip, panel.canvas = clip, canvas
  panel:EnableMouse(true)
  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(self, delta)
    local ux, uy = MV.Cursor(self)
    MV.Zoom(self, (delta or 0) > 0 and 1 or -1, ux, uy)
  end)
  panel:SetScript("OnMouseDown", startDrag)
  panel:SetScript("OnMouseUp", function(self) MV.StopDrag(self) end)
  panel:SetScript("OnHide", function(self) MV.StopDrag(self) end)
  return canvas
end

-- the colours with a meaning (Journal.lua's glass palette, read when drawing: it loads after this file)
local function glass(name, fallback)
  local J = ns.J
  if J and J.Glass then return J.Glass(name) end
  return T.rgb(fallback)
end

--- ONE PIN: a HOLLOW SQUARE - four thin sides in the memory's colour, each with a dark outline so it reads on any art,
--- and nothing drawn in the middle (Arn, 7-8 Nov: "the new box outline with center blank"). Sides are pinned by two
--- corners each, so any size is the same four textures.
local SIDES = {
  { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
  { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
}
local function newPin(panel)
  local b = CreateFrame("Button", nil, panel.canvas)
  b.sides, b.shade = {}, {}
  for _, s in ipairs(SIDES) do
    local a, z, across = s[1], s[2], s[3]
    local sh = b:CreateTexture(nil, "BORDER")
    local ox = a:find("LEFT") and -1 or 1
    local oy = a:find("TOP") and 1 or -1
    if across then
      sh:SetPoint(a, b, a, -1, oy)
      sh:SetPoint(z, b, z, 1, oy)
      sh:SetHeight(MV.THICK + 2)
    else
      sh:SetPoint(a, b, a, ox, 1)
      sh:SetPoint(z, b, z, ox, -1)
      sh:SetWidth(MV.THICK + 2)
    end
    sh:SetColorTexture(0, 0, 0, 0.85)
    b.shade[#b.shade + 1] = sh
    local t = b:CreateTexture(nil, "OVERLAY")
    t:SetPoint(a, b, a, 0, 0)
    t:SetPoint(z, b, z, 0, 0)
    if across then t:SetHeight(MV.THICK) else t:SetWidth(MV.THICK) end
    b.sides[#b.sides + 1] = t
  end
  b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.count:SetPoint("LEFT", b, "RIGHT", 3, 0)
  if b.count.SetWordWrap then b.count:SetWordWrap(false) end
  function b:Paint(r, g, bl)
    for _, t in ipairs(self.sides) do t:SetColorTexture(r, g, bl, 1) end
  end
  -- under the mouse its sides go to the accent (Arn, 6 Nov: everything clickable lights up) - a modest light, the
  -- map itself is not washed
  b:SetScript("OnEnter", function(self)
    self:Paint(T.rgb("accent"))
    if #self.members == 1 then
      if ns.J and ns.J.Tip then ns.J.Tip(self, self.members[1].e, true) end
    elseif GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(("%d memories here"):format(#self.members))
      GameTooltip:AddLine("click to close in on them", 0.7, 0.7, 0.7)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self)
    if self.kind then self:Paint(self.kind[1], self.kind[2], self.kind[3]) end
    if GameTooltip then GameTooltip:Hide() end
  end)
  b:SetScript("OnClick", function(self)
    if #self.members == 1 then
      if self.onClick then self.onClick(self.members[1].e) end
    else
      MV.ZoomOn(panel, self)
    end
  end)
  return b
end

--- The pins on the glass at this range: { x, y (px), members = { dot... } }, nearer than MV.MERGE = one box.
--- cost: once per repaint, over the memories on the glass (250 at most) against the boxes made so far - no client call.
function MV.Clusters(panel, dots)
  local k, lw, lh, pw, ph = scale(panel)
  local out = {}
  if not k then return out end
  local v = view(panel)
  for _, d in ipairs(dots) do
    local ux, uy = pw / 2 + (d.x - v.cx) * lw * k, ph / 2 + (d.y - v.cy) * lh * k
    if ux >= 0 and ux <= pw and uy >= 0 and uy <= ph then
      local home
      for _, c in ipairs(out) do
        if math.abs(c.x - ux) < MV.MERGE and math.abs(c.y - uy) < MV.MERGE then home = c break end
      end
      if home then home.members[#home.members + 1] = d
      else out[#out + 1] = { x = ux, y = uy, members = { d } } end
    end
  end
  return out
end

--- Draw `mapID` and its pins into `panel` at its range and spot (the whole map, fitted and centred, at range 1x).
--- `sel`: the memory open on the right display - its pin magenta and bigger. Answers how many memories have a
--- place on this map (on the glass or not), how many have none, how many sit off it, how many are rough - or nil and
--- why when the client gives no art for that map.
function MV.Draw(panel, entries, mapID, onClick, sel)
  mapID = mapID or MV.WORLD
  local canvas = MV.Glass(panel)
  panel.tiles, panel.dots = panel.tiles or {}, panel.dots or {}
  for _, t in ipairs(panel.tiles) do t:Hide() end
  for _, b in ipairs(panel.dots) do b:Hide() b.members = {} end
  local lw, lh, pieces = MV.Pieces(mapID)
  if not lw then panel.art = nil return nil, "no art for this map" end
  if not (panel.art and panel.art.map == mapID) then panel.view = nil end
  panel.art = { map = mapID, lw = lw, lh = lh }
  clamp(panel)
  local k, _, _, pw, ph = scale(panel)
  local v = view(panel)
  local ox, oy = pw / 2 - v.cx * lw * k, ph / 2 - v.cy * lh * k
  for i, p in ipairs(pieces) do
    -- a tile past the art's edge is cut, not squeezed; a tile off the glass is not drawn at all
    local w, h = math.min(p[4], lw - p[2]), math.min(p[5], lh - p[3])
    local x, y = ox + p[2] * k, oy + p[3] * k
    if w > 0 and h > 0 and x < pw and y < ph and x + w * k > 0 and y + h * k > 0 then
      local t = panel.tiles[i]
      if not t then
        t = canvas:CreateTexture(nil, "BORDER")
        panel.tiles[i] = t
      end
      t:SetTexture(p[1])
      t:SetTexCoord(0, w / p[4], 0, h / p[5])
      -- `panel.paper` {r, g, b}: the art in no colours of its own, tinted like a printed map (the Clipper Lounge's
      -- seat-pocket map); the journal's glass shows the art as the game draws it
      local paper = panel.paper
      if paper then
        t:SetVertexColor(paper[1], paper[2], paper[3], 1)
        if t.SetDesaturated then t:SetDesaturated(true) end
      end
      t:SetSize(w * k, h * k)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -y)
      t:Show()
    end
  end
  local dots, inside, off, rough = MV.Dots(entries, mapID)
  local mr, mg, mb = glass("magenta", "accent")
  local wr, wg, wb = glass("white", "ink")
  -- `panel.pal` { one, many, sel = {r, g, b} }: a panel's own pin colours (the lounge's paper map: tangerine pins, the
  -- chosen one sky blue, a merged box and its count in ink); the journal's glass keeps the meanings of J.GLASS
  local pal = panel.pal
  if pal then
    mr, mg, mb = pal.sel[1], pal.sel[2], pal.sel[3]
    wr, wg, wb = pal.many[1], pal.many[2], pal.many[3]
  end
  for i, c in ipairs(MV.Clusters(panel, dots)) do
    local b = panel.dots[i] or newPin(panel)
    panel.dots[i] = b
    local one = #c.members == 1 and c.members[1] or nil
    local chosen = false
    for _, d in ipairs(c.members) do if d.e == sel then chosen = true end end
    local size = chosen and MV.SEL or (one and (one.rough and MV.BOX - 2 or MV.BOX)) or MV.MANY
    local r, g, bl
    if chosen then r, g, bl = mr, mg, mb
    elseif one and pal then r, g, bl = pal.one[1], pal.one[2], pal.one[3]
    elseif one then r, g, bl = T.rgb(MV.COLOUR[one.e.reason] or "ink")
    else r, g, bl = wr, wg, wb end
    b.kind = { r, g, bl }
    b:Paint(r, g, bl)
    b:SetSize(size, size)
    b:SetAlpha((one and one.rough and not chosen) and 0.6 or 1)
    b.members, b.onClick, b.ux, b.uy = c.members, onClick, c.x, c.y
    b.entry = one and one.e or nil
    b.count:SetText(one and "" or tostring(#c.members))
    b.count:SetShown(not one)
    b.count:SetTextColor(wr, wg, wb)
    b:ClearAllPoints()
    b:SetPoint("CENTER", canvas, "TOPLEFT", c.x, -c.y)
    b:Show()
  end
  return #dots, inside, off, rough
end

--- The map to open on: the world when it can be drawn, else where you are.
function MV.Start()
  if MV.Pieces(MV.WORLD) and C_Map and C_Map.GetMapRectOnMap then return MV.WORLD end
  local map = M.Spot()
  return map
end
