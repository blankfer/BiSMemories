--[[
  BiSMemories :: Core/Pins.lua - your memories on the game's own world map (Arn, 21 Oct 2026: "a map of
  where every screenshot was taken"). A pin per memory taken out in the world, coloured by its kind;
  hover it for the note, click it to open the journal on it.

  Through HereBeDragons-Pins, the library Questie, BiS Tools and BiS Guild draw with - so a map addon that
  shows that library's pins shows these too. On the zone map and one level up
  (HBD_PINS_WORLDMAP_SHOW_PARENT), as BiS Guild's dots: OpenMap's notes (16 Oct) say the library's
  continent and world positions come out wrong on Forever.

  ONE FRAME PER PIN (BiS Tools learned it, 6 Oct: a frame the library draws on two maps shows on
  neither). `/bism pins mine | all | off` - this character's (the default), every character's, or none.
]]
local ADDON, ns = ...
local M, T = ns.M, ns.T

local P = {}
ns.Pins = P

-- A VIEWFINDER, NOT A SQUARE (Arn, 7 Nov live: "maybe we dont make them into a square but a crosshair or something
-- that has the middle blank like a circular shutter with line not connected so the middle is always see through"):
-- a camera's four corner brackets in the memory's colour, each with a one-pixel dark outline so it reads on any
-- map, and nothing drawn in the middle - a quest "!" or a road under it stays in plain sight.
P.SIZE, P.ARM, P.THICK = 14, 5, 2
P.CORNERS = { { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }
P.pins = {}            -- memory -> its frame
P.pool = {}

local function HBD() return LibStub and LibStub("HereBeDragons-Pins-2.0", true) end

--- UNDER THE QUEST PINS (Arn, 6 Nov 2026, a memory square sitting on a quest's "!": "sometime the memeories blocks
--- quest stuff on the map"). The library puts every pin on the map's AREA_POI level, beside the quest pins, and the
--- last one drawn wins the mouse. Ours get their OWN level, just above the map's art (the explored-area layer) and
--- under every quest and point of interest - the way OpenMap and EllesmereUI layer theirs on Forever. Made once a
--- session; a map that refuses it keeps the library's level (nil). P.layer: nil = not tried, false = refused.
P.LAYER = "PIN_FRAME_LEVEL_BISMEMORIES"
function P.Layer()
  if P.layer ~= nil then return P.layer or nil end
  local wm = _G.WorldMapFrame
  if not (wm and wm.GetPinFrameLevelsManager) then return nil end      -- the map not loaded yet: try next time
  local ok, fl = pcall(wm.GetPinFrameLevelsManager, wm)
  if not (ok and type(fl) == "table" and fl.InsertFrameLevelAbove and fl.GetValidFrameLevel) then return nil end
  local made = pcall(fl.InsertFrameLevelAbove, fl, P.LAYER, "PIN_FRAME_LEVEL_MAP_EXPLORATION")
  made = made and pcall(fl.GetValidFrameLevel, fl, P.LAYER)
  P.layer = made and P.LAYER or false
  return P.layer or nil
end

--- Which memories get a pin: "mine", "all" or "off" (d.pins).
function P.Mode()
  local m = ns.DB().pins
  return (m == "all" or m == "off") and m or "mine"
end

local function NewPin()
  local b = table.remove(P.pool)
  if b then return b end
  b = CreateFrame("Button", nil, UIParent)
  b:SetSize(P.SIZE, P.SIZE)
  b.arms, b.shade = {}, {}
  for _, c in ipairs(P.CORNERS) do
    local corner, dx, dy = c[1], c[2], c[3]
    for _, horiz in ipairs({ true, false }) do
      local w, h = horiz and P.ARM or P.THICK, horiz and P.THICK or P.ARM
      local s = b:CreateTexture(nil, "BORDER")                      -- the dark outline, one pixel round the arm
      s:SetPoint(corner, b, corner, -dx, -dy)
      s:SetSize(w + 2, h + 2)
      s:SetColorTexture(0, 0, 0, 0.85)
      b.shade[#b.shade + 1] = s
      local a = b:CreateTexture(nil, "OVERLAY")
      a:SetPoint(corner, b, corner, 0, 0)
      a:SetSize(w, h)
      b.arms[#b.arms + 1] = a
    end
  end
  function b:Paint(r, g, bl)
    for _, a in ipairs(self.arms) do a:SetColorTexture(r, g, bl, 1) end
  end
  -- under the mouse the brackets go to the accent (Arn, 6 Nov: everything clickable lights up); the world map
  -- is not washed
  b:SetScript("OnEnter", function(self)
    self:Paint(T.rgb("accent"))
    if ns.J and self.entry then ns.J.Tip(self, self.entry, true) end
  end)
  b:SetScript("OnLeave", function(self)
    if self.kind then self:Paint(unpack(self.kind)) end
    if GameTooltip then GameTooltip:Hide() end
  end)
  b:SetScript("OnClick", function(self) if ns.J and self.entry then ns.J.Select(self.entry) ns.J.Show() end end)
  return b
end

function P.Clear()
  local H = HBD()
  for e, b in pairs(P.pins) do
    if H then H:RemoveWorldMapIcon(P, b) end
    b.entry = nil
    b:Hide()
    P.pool[#P.pool + 1] = b
    P.pins[e] = nil
  end
end

--- Put a pin on every memory that should have one. Answers how many are up.
function P.Update()
  local H = HBD()
  P.Clear()
  if not H or P.Mode() == "off" or not M.Log then P.count = 0 return 0 end
  local me, all, n = M.Me(), P.Mode() == "all", 0
  local colours = ns.MapView and ns.MapView.COLOUR or {}
  for _, e in ipairs(M.Log()) do
    if type(e) == "table" and e.map and e.x and e.y and (all or e.char == nil or e.char == me) then
      local b = NewPin()
      local r, g, bl = T.rgb(colours[e.reason] or "ink")
      b.kind = { r, g, bl }
      b:Paint(r, g, bl)
      b.entry = e
      local ok, placed = pcall(H.AddWorldMapIconMap, H, P, b, e.map, e.x, e.y, _G.HBD_PINS_WORLDMAP_SHOW_PARENT, P.Layer())
      if ok and placed ~= false then
        P.pins[e] = b
        n = n + 1
      else
        b.entry = nil
        P.pool[#P.pool + 1] = b
      end
    end
  end
  P.count = n
  return n
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" then return P.Update() end
  -- the map loads after login on some clients: then the layer is made and the pins moved onto it
  if name == "Blizzard_WorldMap" and P.layer == nil then P.Update() end
end)
