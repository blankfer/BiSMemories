--[[
  BiSMemories :: UI/Options.lua - the options window and the minimap button (0.9.0: every setting used to
  be a slash command only; the family has had both since September).

  The window is BiSTheme's shared kit (Libs\BiSTheme\Options.lua), in two columns the way BiS Healing
  builds them (its UI/options.lua): each column built as the kit builds it, then each row pinned into its
  column. 25% bigger, as Healing's - the kit's 8 pt is hard to read. The button is BiSTheme's shared
  minimap button (Libs\BiSTheme\Minimap.lua): any click opens the journal; the options are a row in it
  and `/bism options`.
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

--- The rows. A function, so `get` is asked every time the window paints.
function CFG.Sections()
  local QUALITY = { [2] = "uncommon", [3] = "rare", [4] = "epic", [5] = "legendary" }
  return {
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
      toggle("group", "group photos", "When someone in your group calls /bism group."),
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
        action = function() if ns.J then ns.J.Show() end end },
      { key = "now", kind = "button", label = "a picture now", button = "take", help = "Take one right now (the same as /bism now).",
        action = function() M.Shoot("manual", "asked for it") end },
      { key = "groupcall", kind = "button", label = "group photo", button = "call", help = "A countdown for everyone in your group with a BiS addon, then everyone's picture at once (/bism group).",
        action = function() local ok, why = M.GroupPhoto() if not ok then ns.Print("no group photo - %s", tostring(why)) end end },
    } },
  }
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

local function tip(self)
  if self.edge then self.edge:set("accent", 1) end
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("BiS> Memories")
  GameTooltip:AddLine("click  your memories, the map, the year", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("right-click  options", 0.6, 0.6, 0.6)
  GameTooltip:AddLine("drag  move me round the edge", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

function CFG.Click(_, which)
  local b = CFG.button
  if b and b.Unbury then b:Unbury() end
  if b and b.CloseMenu then b:CloseMenu() end
  if b and b.dragging then return end
  if which == "RightButton" then return CFG.Toggle() end
  if ns.J then ns.J.Toggle() end
end

function CFG.BuildMinimap()
  if CFG.button then return CFG.button end
  if not (BiSTheme and BiSTheme.Minimap) then return nil end
  CFG.button = BiSTheme.Minimap("BiSMemories", {
    icon  = "Interface\\Icons\\INV_Misc_Spyglass_03",
    label = "Memories",
    db    = CFG.MinimapDB(),
    menu  = function() return {} end,
  })
  if CFG.button and CFG.button.SetScript then
    CFG.button:SetScript("OnClick", CFG.Click)
    CFG.button:SetScript("OnEnter", tip)
  end
  return CFG.button
end

function CFG.SetMinimap(on)
  CFG.MinimapDB().hide = not on
  local b = CFG.BuildMinimap()
  if b then b:SetHidden(not on) end
  return on
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() CFG.BuildMinimap() end)
