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

P.SIZE = 10
P.pins = {}            -- memory -> its frame
P.pool = {}

local function HBD() return LibStub and LibStub("HereBeDragons-Pins-2.0", true) end

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
  b.edge = b:CreateTexture(nil, "BORDER")
  b.edge:SetPoint("TOPLEFT", -1, 1)
  b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
  b.edge:SetColorTexture(0, 0, 0, 1)
  b.fill = b:CreateTexture(nil, "OVERLAY")
  b.fill:SetAllPoints()
  b:SetScript("OnEnter", function(self) if ns.J and self.entry then ns.J.Tip(self, self.entry, true) end end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
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
      b.fill:SetColorTexture(r, g, bl, 1)
      b.entry = e
      local ok, placed = pcall(H.AddWorldMapIconMap, H, P, b, e.map, e.x, e.y, _G.HBD_PINS_WORLDMAP_SHOW_PARENT)
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
f:SetScript("OnEvent", function() P.Update() end)
