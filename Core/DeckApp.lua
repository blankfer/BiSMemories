--[[ BiSMemories :: Core/DeckApp.lua - MEMORIES ON THE PHONE (22 Nov 2026).

  Arn, 22 Nov: "start memories" - the mock's plan (https://claude.ai/artifact/HZHvD2uqp3iG6bpPQTwREu). The phone is BiSTheme's deck
  (it comes with BiS Tools): an app hands in DATA, never a frame. Without it nothing here runs. Everything is read from the album's
  own notes (M.Log through J.Entries - this character's, share cards left out), the character's book (M.Char) and the year
  (M.Summary); the presses are the journal's own: a picture now (M.Shoot "manual"), the group photo (M.GroupPhoto), a share card
  (ns.Share.Take), the journal at a memory (J.Select + J.Show). The game cannot show its own screenshots: the picture itself stays
  in the album page.

   LATEST    the newest first, the creature of the latest in 3D on top; a memory opens to its page (where, with whom, what you
             wore, what dropped) with SHARE CARD
   BESTS     every boss of this character: its fastest kill, how many, when first
   YEAR      this year in numbers and lines
   SETTINGS  the options window's own switches, and the doors to the journal and the lounge

  THE CARD: NEW MEMORY for two minutes after one is taken (LOOK, SHARE CARD).
]]
local ADDON, ns = ...
local A = {}
ns.DeckApp = A
local ID = ADDON .. ":memories"
A.NEW_FOR = 120                         -- seconds a fresh memory has its card
A.GEAR_SLOTS = { 1, 3, 5, 7, 10, 16, 17, 18 }   -- head, shoulders, chest, legs, hands, the weapons: what a model shows most

local function plain(v)
    if v == nil then return nil end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return nil end
    end
    return v
end
local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return plain(a), plain(b), plain(c), plain(d), plain(e) end
end
local function Deck()
    local T = _G.BiSTheme
    return type(T) == "table" and T.Deck or nil
end
local function now() return ask(time) or 0 end
local function day(t) local d = _G.date return t and d and d("%d %b", t) or "-" end
local function clock(t) local d = _G.date return t and d and d("%H:%M", t) or "" end
local function mmss(s) s = tonumber(s) if not s then return nil end return ("%d:%02d"):format(math.floor(s / 60), math.floor(s % 60)) end
local function cap(s) s = tostring(s or "") return s:sub(1, 1):upper() .. s:sub(2) end

-- what each kind wears on its row: the game's own pictures (a class's circle for the ones about you)
A.PIC = { boss = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", death = "Interface\\Icons\\Ability_Rogue_FeignDeath",
    zone = "Interface\\Icons\\INV_Misc_Map_01", gamba = "Interface\\Icons\\INV_Misc_Coin_01", first = "Interface\\Icons\\Ability_Mount_RidingHorse",
    duel = "Interface\\Icons\\Ability_DualWield", loot = "Interface\\Icons\\INV_Misc_Bag_10", achievement = "Interface\\Icons\\INV_Misc_Note_01",
    exalted = "Interface\\Icons\\INV_Misc_Note_01" }
A.TINT = { boss = "gold", death = "warn", levelup = "good", loot = "epic", first = "accent", gamba = "gold", group = "accent", achievement = "gold", exalted = "good" }

local function entries()
    local J = ns.J
    local ok, list = pcall(function() return J and J.Entries() or {} end)
    return ok and type(list) == "table" and list or {}
end
local function picOf(e)
    local D = Deck()
    local p = A.PIC[e.reason or ""]
    if p then return p end
    if D and D.ClassPic then return D.ClassPic(e.class) end
    return nil
end
local function M_Word(e) local M = ns.M return M and M.Word(e.reason) or tostring(e.reason or "") end
local function title(e)
    local d = tostring(e.detail or ""):gsub("^first kill: ", "")
    if e.reason == "levelup" and type(e.level) == "number" then return "Level " .. e.level end
    return d ~= "" and cap(d) or M_Word(e)
end
local function where(e)
    local z = tostring(e.zone or "")
    return z ~= "" and z or nil
end

-- one memory's page
local pick                                   -- the memory (the note itself; the log never edits it from here)
local function open(e) pick = e end

local function itemOf(id)
    id = tonumber(id) or (type(id) == "string" and tonumber(id:match("item:(%d+)")))
    if not id then return nil end
    local _, _, _, _, icon = ask((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant, id)
    local name = ask(C_Item and C_Item.GetItemNameByID, id)
    local q = ask(C_Item and C_Item.GetItemQualityByID, id)
    return icon, type(name) == "string" and name ~= "" and name or nil, q
end
local QUALITY = { [2] = "uncommon", [3] = "rare", [4] = "epic", [5] = "gold" }

local function memoryRows(e)
    local out = { { mark = "<", text = "Back", act = { word = "back", peek = true, fn = function() pick = nil end } } }
    out[#out + 1] = { head = true, text = "WHERE", right = day(e.at) .. " " .. clock(e.at) }
    out[#out + 1] = { mark = "-", text = where(e) or "somewhere", sub = M_Word(e) }
    local with = type(e.with) == "table" and e.with or {}
    out[#out + 1] = { head = true, text = "WITH", right = #with > 0 and tostring(#with) or "" }
    if #with == 0 then out[#out + 1] = { mark = "-", text = "alone", done = true } end
    for i = 1, math.min(8, #with) do out[#out + 1] = { mark = "-", text = tostring(with[i]) } end
    if e.killer then out[#out + 1] = { mark = "x", text = tostring(e.killer), tint = "warn", sub = "the one who killed you" } end
    local gear = type(e.gear) == "table" and e.gear or nil
    if gear then
        local any = false
        for _, slot in ipairs(A.GEAR_SLOTS) do
            local id = gear[slot]
            if id then
                if not any then out[#out + 1] = { head = true, text = "YOU WORE", right = "" } any = true end
                local icon, name, q = itemOf(id)
                out[#out + 1] = { pic = icon, mark = not icon and "-" or nil, text = name or ("item " .. tostring(id)), tint = QUALITY[q or 1] }
            end
        end
    end
    local cargo = type(e.cargo) == "table" and e.cargo or {}
    if #cargo > 0 then
        out[#out + 1] = { head = true, text = "WHAT DROPPED", right = tostring(#cargo) }
        for _, link in ipairs(cargo) do
            local icon, name, q = itemOf(link)
            local shown = type(link) == "string" and link:match("%[(.-)%]") or name or "an item"
            out[#out + 1] = { pic = icon, mark = not icon and "*" or nil, text = shown, tint = QUALITY[q or 1] }
        end
    end
    return out
end
local function memoryBoxes(e)
    local with = type(e.with) == "table" and #e.with or 0
    local out = { { "LEVEL", e.level or "-", "ink" }, { "WITH", with, with > 0 and "accent" or "dim" }, { "WHEN", day(e.at), "ink2" } }
    if e.secs then table.insert(out, 1, { "TOOK", mmss(e.secs), "gold" }) end
    return out
end

-- the tabs
local function latestRows()
    local out = {}
    for i, e in ipairs(entries()) do
        if i > 40 then break end
        local pic, co = picOf(e)
        local bits = {}
        if where(e) then bits[#bits + 1] = where(e) end
        bits[#bits + 1] = day(e.at)
        out[#out + 1] = { pic = pic, coords = co, text = title(e), tint = A.TINT[e.reason or ""], sub = table.concat(bits, ", "),
            right = M_Word(e), ink = A.TINT[e.reason or ""] or "ink2", act = { word = "open", peek = true, fn = function() open(e) end } }
    end
    return out
end
local function year()
    local M = ns.M
    local ok, s = pcall(function() return M.Summary(nil, M.Me()) end)
    return ok and type(s) == "table" and s or nil
end
local function latestBoxes()
    local s = year()
    if not s then return {} end
    return { { "THIS YEAR", s.total, "gold" }, { "LEVEL", ask(UnitLevel, "player") or "-", "ink" }, { "FIRST KILLS", #s.bosses, #s.bosses > 0 and "good" or "dim" },
        { "DEATHS", s.deaths, s.deaths > 0 and "warn" or "dim" } }
end
local function bosses()
    local M = ns.M
    local ok, c = pcall(M.Char)
    local out = {}
    for name, r in pairs(ok and type(c) == "table" and c.bosses or {}) do
        if type(r) == "table" then out[#out + 1] = { name = name, best = tonumber(r.best), kills = tonumber(r.kills) or 0, first = tonumber(r.first) } end
    end
    table.sort(out, function(a, b) if (a.best ~= nil) ~= (b.best ~= nil) then return a.best ~= nil end return (a.best or 0) < (b.best or 0) end)
    return out
end
local function bestRows()
    local out = {}
    for i, b in ipairs(bosses()) do
        out[#out + 1] = { pic = A.PIC.boss, text = b.name, tint = i == 1 and b.best and "gold" or nil,
            sub = b.kills .. (b.kills == 1 and " kill" or " kills") .. (b.first and b.first > 0 and (", first " .. day(b.first)) or ""),
            right = b.best and mmss(b.best) or "-", ink = b.best and "gold" or "dim" }
    end
    return out
end
local function bestBoxes()
    local list = bosses()
    if #list == 0 then return {} end
    local M = ns.M
    local ok, c = pcall(M.Char)
    local g = ok and type(c) == "table" and tonumber(c.gambaBest) or nil
    return { { "BOSSES", #list, "accent" }, { "FASTEST", list[1].best and mmss(list[1].best) or "-", "gold" }, { "GAMBA", g and ("+" .. g) or "-", g and "gold" or "dim" } }
end
local function yearRows()
    local M, s = ns.M, year()
    if not s then return {} end
    local out = {}
    for i, line in ipairs(M.SummaryLines(s)) do
        if i > 1 then out[#out + 1] = { mark = "-", text = cap(line) } end
    end
    return out
end
local function yearBoxes()
    local s = year()
    if not s then return {} end
    return { { tostring(s.year), s.total, "gold" }, { "FIRST KILLS", #s.bosses, "good" }, { "NEW PLACES", s.places, "accent" }, { "DEATHS", s.deaths, s.deaths > 0 and "warn" or "dim" } }
end
local function settingRows()
    local out = {}
    local CFG, d = ns.CFG, _G.BiSMemoriesDB or {}
    for _, sec in ipairs(CFG and CFG.Sections() or {}) do
        for _, opt in ipairs(sec.options or {}) do
            if opt.kind == "toggle" then
                local is = opt.get(d) and true or false
                out[#out + 1] = { text = cap(opt.label), right = is and "ON" or "OFF", ink = is and "good" or "dim", tip = opt.help,
                    act = { word = "switch", chip = true, fn = function()
                        opt.set(d, not opt.get(d))
                        if CFG.frame and CFG.frame:IsShown() and CFG.frame.Paint then CFG.frame:Paint() end
                    end } }
            end
        end
    end
    local function door(text, fn) out[#out + 1] = { text = text, verb = "OPEN", act = { word = "OPEN", peek = true, fn = fn } } end
    out[#out + 1] = { head = true, text = "THE WINDOWS", right = "" }
    door("The journal", function() if ns.J then ns.J.Show() end end)
    door("The lounge, full screen", function() if ns.Lounge and ns.Lounge.Toggle then ns.Lounge.Toggle() end end)
    door("Every setting", function() if CFG and CFG.Toggle then CFG.Toggle() end end)
    return out
end

--- The journal on the screen (at this memory), and the phone steps back home: free for another app.
local function popOut(e)
    return { word = "POP OUT", peek = true, tip = "The journal on your screen", fn = function()
        local J = ns.J
        if J then if e then J.Select(e) end J.Show() end
        local D = Deck()
        if D then D.page = "home" if D.Dirty then D.Dirty(true) end end
    end }
end

-- THE CARD ----------------------------------------------------------------------------------------------------------------------

function A.Fresh()
    local e = entries()[1]
    if e and tonumber(e.at) and now() - e.at >= 0 and now() - e.at < A.NEW_FOR then return e end
end
function A.CardPrio(out)
    if A.Fresh() then return 4 end
    return out and entries()[1] and 1 or nil
end
function A.CardLines()
    local e = A.Fresh() or entries()[1]
    if not e then return nil end
    local with = type(e.with) == "table" and #e.with or 0
    return { A.Fresh() and "NEW MEMORY" or "MEMORIES", "", title(e), A.Fresh() and "now" or day(e.at), "gold", hot = A.Fresh() ~= nil,
        list = { { "Where", where(e) or "-" }, { "With", with > 0 and (with .. "") or "alone" } } }
end
function A.CardButtons()
    local e = A.Fresh() or entries()[1]
    if not e then return {} end
    return { { word = "LOOK", peek = true, fn = function() open(e) local D = Deck() if D then D.Open(ID) end end },
        { word = "SHARE CARD", fn = function() if ns.Share and ns.Share.Take then ns.Share.Take(e) end end } }
end

-- REGISTER ----------------------------------------------------------------------------------------------------------------------

local TABS = { "LATEST", "BESTS", "YEAR" }
function A.Register()
    local D = Deck()
    if A.handle or not (D and D.Register) or not ns.M then return false end
    A.handle = D.Register{
        owner = ADDON, key = "memories", name = "Memories", icon = "Me", order = 50,
        about = "A picture when something worth remembering happens, and a note of what it was.",
        card = { tick = true, prio = A.CardPrio, lines = A.CardLines, buttons = A.CardButtons },
        page = {
            tour = { { text = "Your memories, the newest first. Press one: where, with whom, what you wore, what dropped.", note = "The picture itself is in the album page." },
                { text = "TAKE ONE NOW is a picture this second. SHARE CARD makes one to post." } },
            title = function() return pick and title(pick) or "Memories" end,
            kicker = function()
                if pick then return M_Word(pick) end
                local s = year()
                return s and (s.total .. " this year") or "memories"
            end,
            tabs = function() return { TABS[1], TABS[2], TABS[3], "SETTINGS" } end,
            hero = function(tab)
                local e = pick or (tab == 1 and entries()[1]) or nil
                if not (e and (e.npc or e.display)) then return nil end
                return { art = "model", creature = e.npc, display = e.display, big = title(e), small = (M_Word(e) .. ", " .. day(e.at)):upper() }
            end,
            boxes = function(tab)
                if pick then return memoryBoxes(pick) end
                if tab == 1 then return latestBoxes() elseif tab == 2 then return bestBoxes() elseif tab == 3 then return yearBoxes() end
                return {}
            end,
            rows = function(tab)
                if pick then return memoryRows(pick) end
                if tab == 1 then return latestRows() elseif tab == 2 then return bestRows() elseif tab == 3 then return yearRows() end
                return settingRows()
            end,
            text = function(tab)
                if pick then return nil end
                if tab == 1 and #entries() == 0 then return "No memories yet. Level up, kill a boss for the first time, or press TAKE ONE NOW." end
                if tab == 2 and #bosses() == 0 then return "No boss killed yet on this character." end
                return nil
            end,
            say = function(tab) if not pick and tab == 2 and #bosses() > 0 then return "Your fastest kill of each boss" end end,
            big = function(tab)
                if pick then
                    local e = pick
                    return { word = "SHARE CARD", tip = "A picture of its boarding pass, made to be posted", fn = function() if ns.Share and ns.Share.Take then ns.Share.Take(e) end end }
                end
                if tab == 1 then
                    return { word = "TAKE ONE NOW", tip = "A picture this second, with a note of where", fn = function()
                        local M = ns.M
                        if M then M.Shoot("manual", "asked for it") end
                    end }
                end
                if tab == 3 then return { word = "THE YEAR PAGE", peek = true, fn = function() local J = ns.J if J then J.Show() if J.Tab then pcall(J.Tab, "year") end end end } end
                return nil
            end,
            keys = function(tab)
                if pick then return { popOut(pick) } end
                local out = {}
                if tab == 1 and ask(IsInGroup) then out[#out + 1] = { word = "GROUP PHOTO", tip = "A countdown for everyone, then the picture", fn = function() if ns.M then ns.M.GroupPhoto() end end } end
                if tab ~= 4 then out[#out + 1] = popOut(nil) end
                return out
            end,
        },
    }
    -- a memory taken: the phone repaints with the journal (M.Keep calls J.Touch)
    local J = ns.J
    if J and type(J.Touch) == "function" and not J.bisDeckHooked then
        local old = J.Touch
        J.Touch = function(...)
            local r = old(...)
            if A.handle and A.handle.Dirty then pcall(A.handle.Dirty, A.handle) end
            return r
        end
        J.bisDeckHooked = true
    end
    return true
end
A.ID = ID
A.Open = function(e) pick = e end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() A.Register() end)
A.boot = ev
