--[[
  BiSMemories :: Core/Moments.lua - the notes coming back to you: "on this day", the year so far, and
  the group photo (Arn, 21 Oct 2026, on the review: "do all that stuff, it all looks good and needed").

  * ON THIS DAY: once a day, at login, the oldest memory from this calendar day in an earlier year -
    or, in the first year, from this day of an earlier month. A line in chat and a card on screen
    (Journal.lua's J.Toast); clicking the card opens the journal on it. `/bism onthisday` turns it off.
  * THE YEAR SO FAR: M.Summary(year, char) counts what the notes hold - kinds, first kills, deaths, the
    levels and how long each took, places, firsts, the biggest gamba win. `/bism year`, and the
    journal's "this year" page.
  * THE GROUP PHOTO: `/bism group` - everyone in the group with a BiS addon gets a countdown on screen
    from the shared BiS channel, and every one of them takes a picture at the same second, each from
    their own eyes. One line in group chat ("say cheese") for the people without one.
]]
local ADDON, ns = ...
local M, T = ns.M, ns.T

local function db() return ns.DB() end
local function now() return (time and time()) or 0 end

---------------------------------------------------------------- on this day --

-- which memory a day is best remembered by, when it has several
M.RANK = { boss = 1, levelup = 2, first = 3, exalted = 4, achievement = 5, loot = 6, gamba = 7, group = 8,
           zone = 9, duel = 10, death = 11, manual = 12, candid = 13 }

--- How long ago, in words, when `at` falls on the same calendar day as `t` (same day and month in an
--- earlier year, or the same day of an earlier month) - else nil.
function M.Ago(at, t)
  if not (date and at and t) or at >= t then return nil end
  local a, b = date("*t", at), date("*t", t)
  if a.day ~= b.day then return nil end
  if a.month == b.month and a.year < b.year then
    local n = b.year - a.year
    return n == 1 and "A year ago today" or (n .. " years ago today")
  end
  local months = (b.year - a.year) * 12 + (b.month - a.month)
  if months >= 1 and a.month ~= b.month then
    return months == 1 and "A month ago today" or (months .. " months ago today")
  end
  return nil
end

--- The memory for today, and its words - a year's first, then a month's; the best kind, then the oldest.
function M.OnThisDayPick(t)
  t = t or now()
  local best, words, bestYear
  for _, e in ipairs(M.Log()) do
    local w = type(e) == "table" and M.Ago(tonumber(e.at), t)
    if w then
      local yearly = w:find("year", 1, true) ~= nil
      local better = not best
        or (yearly and not bestYear)
        or (yearly == bestYear and ((M.RANK[e.reason] or 99) < (M.RANK[best.reason] or 99)
          or ((M.RANK[e.reason] or 99) == (M.RANK[best.reason] or 99) and (e.at or 0) < (best.at or 0))))
      if better then best, words, bestYear = e, w, yearly end
    end
  end
  return best, words
end

--- Once a calendar day: the line and the card. Answers the memory shown, or nil.
function M.OnThisDay(t)
  local d = db()
  if d.onThisDay == false or not date then return nil end
  t = t or now()
  local key = date("%Y-%m-%d", t)
  if d.otdShown == key then return nil end
  d.otdShown = key
  local e, words = M.OnThisDayPick(t)
  if not e then return nil end
  local who = (e.char and e.char ~= M.Me()) and (" (" .. tostring(e.char):match("^[^%-]+") .. ")") or ""
  ns.Print("%s%s: %s %s", T.text("gold", words), who, T.text("accent", M.Word(e.reason)), tostring(e.detail or ""))
  if ns.J and ns.J.Toast then pcall(ns.J.Toast, e, words) end
  return e, words
end

---------------------------------------------------------------- the year --

--- What a year's notes hold. `char`: one character's key, or nil for the whole account.
--- { year, total, kinds = { [kind] = n }, bosses = { names of first kills }, deaths, levels = { from, to },
---   perLevel (seconds, between dings), places, firsts = { details }, gamba (the biggest win's note) }
function M.Summary(year, char)
  year = year or tonumber(date and date("%Y") or 0)
  local s = { year = year, total = 0, kinds = {}, bosses = {}, deaths = 0, places = 0, firsts = {} }
  local dings = {}
  for _, e in ipairs(M.Log()) do
    local at = tonumber(e.at) or 0
    local y = date and tonumber(date("%Y", at)) or 0
    if y == year and (not char or e.char == nil or e.char == char) then   -- an unclaimed old note: the journal shows it too
      s.total = s.total + 1
      s.kinds[e.reason or "?"] = (s.kinds[e.reason or "?"] or 0) + 1
      if e.reason == "boss" and tostring(e.detail or ""):find("^first kill: ") then
        s.bosses[#s.bosses + 1] = tostring(e.detail):gsub("^first kill: ", "")
      elseif e.reason == "death" then s.deaths = s.deaths + 1
      elseif e.reason == "zone" then s.places = s.places + 1
      elseif e.reason == "first" then s.firsts[#s.firsts + 1] = tostring(e.detail or "")
      elseif e.reason == "gamba" and not s.gamba then s.gamba = tostring(e.detail or "")    -- newest = biggest
      elseif e.reason == "levelup" and type(e.level) == "number" then dings[#dings + 1] = { e.level, at }
      end
    end
  end
  table.sort(dings, function(a, b) return a[2] < b[2] end)
  if #dings > 0 then
    s.levels = { from = dings[1][1], to = dings[#dings][1] }
    if #dings > 1 then s.perLevel = (dings[#dings][2] - dings[1][2]) / (#dings - 1) end
  end
  return s
end

--- A duration in words: "2 h 10 min", "40 min", "3 days".
function M.Span(secs)
  secs = tonumber(secs) or 0
  if secs >= 2 * 86400 then return ("%d days"):format(math.floor(secs / 86400 + 0.5)) end
  if secs >= 3600 then return ("%d h %d min"):format(math.floor(secs / 3600), math.floor(secs % 3600 / 60)) end
  return ("%d min"):format(math.max(1, math.floor(secs / 60 + 0.5)))
end

--- The year as lines of text (the chat command and the journal's page share them).
function M.SummaryLines(s)
  local out = {}
  out[#out + 1] = ("%d memories in %d"):format(s.total, s.year)
  if s.levels then
    out[#out + 1] = s.levels.from == s.levels.to and ("level %d"):format(s.levels.to)
      or ("levels %d to %d%s"):format(s.levels.from, s.levels.to,
        s.perLevel and (", about " .. M.Span(s.perLevel) .. " a level") or "")
  end
  if #s.bosses > 0 then
    out[#out + 1] = ("%d first kill%s: %s"):format(#s.bosses, #s.bosses == 1 and "" or "s", table.concat(s.bosses, ", "))
  end
  if s.places > 0 then out[#out + 1] = ("%d new place%s"):format(s.places, s.places == 1 and "" or "s") end
  if #s.firsts > 0 then out[#out + 1] = "firsts: " .. table.concat(s.firsts, ", ") end
  if s.deaths > 0 then out[#out + 1] = ("%d death%s worth keeping"):format(s.deaths, s.deaths == 1 and "" or "s") end
  if s.gamba then out[#out + 1] = "at the gamba table: " .. s.gamba end
  return out
end

---------------------------------------------------------------- the group photo --

M.GROUP_MOD, M.GROUP_SECS = "MEM", 3

--- `/bism group`: the countdown for everyone, then the picture. Answers true, or nil and why not.
function M.GroupPhoto(secs)
  secs = math.max(2, math.min(10, math.floor(tonumber(secs) or M.GROUP_SECS)))
  if not (IsInGroup and IsInGroup()) then return nil, "not in a group" end
  if M.counting then return nil, "already counting" end
  local lib = rawget(_G, "LibBiSComm")
  if lib and lib.Send then pcall(lib.Send, lib, M.GROUP_MOD, "SNAP", tostring(secs)) end
  -- the people without a BiS addon hear it in chat; not while the game holds addon chat back
  local lock = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
  local locked = lock and select(2, pcall(lock))
  if SendChatMessage and not locked then
    pcall(SendChatMessage, ("Group photo in %d - say cheese!"):format(secs), (IsInRaid and IsInRaid()) and "RAID" or "PARTY")
  end
  return M.Countdown(secs)
end

--- The countdown on this screen, a number a second, then the shutter. `by`: who called it (nil: you).
function M.Countdown(secs, by)
  if M.counting then return nil, "already counting" end
  M.counting = true
  local n = math.max(1, math.floor(tonumber(secs) or M.GROUP_SECS))
  local function tick()
    if n <= 0 then
      M.counting = nil
      if ns.J and ns.J.Count then pcall(ns.J.Count, nil) end
      local who = (type(by) == "string" and by ~= "") and (" - called by " .. by) or ""
      return M.Shoot("group", "a group photo" .. who)
    end
    if ns.J and ns.J.Count then pcall(ns.J.Count, n) end
    n = n - 1
    if C_Timer and C_Timer.After then C_Timer.After(1, tick) else tick() end
  end
  tick()
  return true
end

-- the call from someone else's /bism group, on the shared BiS channel (a group channel only)
do
  local lib = rawget(_G, "LibBiSComm")
  if lib and lib.RegisterHandler then
    lib:RegisterHandler(M.GROUP_MOD, "SNAP", function(sender, secs)
      local me = UnitName and UnitName("player")
      if type(sender) == "string" and me and (sender == me or sender:find("^" .. tostring(me) .. "%-")) then return end
      M.Countdown(tonumber(secs) or M.GROUP_SECS, sender)
    end)
  end
end
