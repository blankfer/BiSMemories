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
function MV.Pieces(mapID)
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

--- Draw `mapID` and its dots into `panel` (a frame), fitted and centred. Answers the dots drawn, or nil
--- and why when the client gives no art for that map.
function MV.Draw(panel, entries, mapID, onClick)
  mapID = mapID or MV.WORLD
  panel.tiles, panel.dots = panel.tiles or {}, panel.dots or {}
  for _, t in ipairs(panel.tiles) do t:Hide() end
  for _, b in ipairs(panel.dots) do b:Hide() b.entry = nil end
  local lw, lh, pieces = MV.Pieces(mapID)
  if not lw then return nil, "no art for this map" end
  local pw, ph = panel:GetWidth(), panel:GetHeight()
  local k = math.min(pw / lw, ph / lh)
  local ox, oy = (pw - lw * k) / 2, (ph - lh * k) / 2
  for i, p in ipairs(pieces) do
    local t = panel.tiles[i]
    if not t then
      t = panel:CreateTexture(nil, "BORDER")
      panel.tiles[i] = t
    end
    -- a tile past the art's edge is cut, not squeezed
    local w, h = math.min(p[4], lw - p[2]), math.min(p[5], lh - p[3])
    t:SetTexture(p[1])
    t:SetTexCoord(0, w / p[4], 0, h / p[5])
    t:SetSize(w * k, h * k)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", panel, "TOPLEFT", ox + p[2] * k, -(oy + p[3] * k))
    t:Show()
  end
  local dots, inside, off, rough = MV.Dots(entries, mapID)
  for i, d in ipairs(dots) do
    local b = panel.dots[i]
    if not b then
      b = CreateFrame("Button", nil, panel)
      b:SetSize(MV.DOT, MV.DOT)
      b.edge = b:CreateTexture(nil, "BORDER")
      b.edge:SetPoint("TOPLEFT", -1, 1)
      b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
      b.edge:SetColorTexture(0, 0, 0, 1)
      b.fill = b:CreateTexture(nil, "OVERLAY")
      b.fill:SetAllPoints()
      b:SetScript("OnEnter", function(self) if ns.J and ns.J.Tip then ns.J.Tip(self, self.entry, true) end end)
      b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
      b:SetScript("OnClick", function(self) if self.onClick and self.entry then self.onClick(self.entry) end end)
      panel.dots[i] = b
    end
    local r, g, bl = T.rgb(MV.COLOUR[d.e.reason] or "ink")
    b.fill:SetColorTexture(r, g, bl, 1)
    b:SetSize(d.rough and MV.DOT - 3 or MV.DOT, d.rough and MV.DOT - 3 or MV.DOT)
    b:SetAlpha(d.rough and 0.6 or 1)
    b.entry, b.onClick = d.e, onClick
    b:ClearAllPoints()
    b:SetPoint("CENTER", panel, "TOPLEFT", ox + d.x * lw * k, -(oy + d.y * lh * k))
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
