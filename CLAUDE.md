Read ../_bisdev/CLAUDE.md first.

## Layout (BiSMemories only)

- `BiSMemories.toc`: the load order and the only place the version lives (`## Version`). It also carries
  `## X-Curse-Project-ID` (0 until the CurseForge project exists) and `## X-CurseForge-GameVersionType`,
  which `dev/release.ps1` reads.
- `Core/Init.lua`: the house skeleton from `_bisdev/new-addon.sh` — palette per call (`ns.T`), `ns.VERSION`
  from the TOC, `ns.Print`, `BiSMemoriesDB` defaults, the shared BiS channel booted with its off switch saved,
  and `/bism` (alias `/memories`, the old name, since 12 Oct 2026) - the real commands live in `Core/Slash.lua`.
- `Core/Memories.lua`: the camera - triggers (`M.TRIGGERS`, plain words `M.Word`), `M.Shoot` (each note
  carries the character, class/race, map spot `M.Spot`, gear ids `M.Gear`, and extras: npc, killer, secs),
  clean shots (`M.Clean`, SetUIVisibility), per-character books `M.Char()` = `d.chars["Name-Realm"]`
  {zones, bosses, firsts, gambaBest} (the pre-0.9.0 shared `d.zones` goes once to the main, `M.Inherit`),
  bosses = first kill + fastest yet (`M.BossKill`, ENCOUNTER_START timing), deaths worth keeping
  (`M.Death`: C_DeathRecap killer, BiSToolsAPI.IsRival, in a boss fight, first death), firsts (mount,
  riding), the biggest BiS Gamba win (BiSGambaAPI callback). `M.OnEvent` scrubs secrets, then `M.Decide`.
- `Core/Moments.lua`: on this day (`M.OnThisDay`, once a day), the year (`M.Summary`, `M.SummaryLines`),
  the group photo (`M.GroupPhoto` / `M.Countdown`, LibBiSComm MOD "MEM" CMD "SNAP").
- `Core/Map.lua` (`ns.MapView`): the journal's map page as a NAVIGATION DISPLAY (8 Nov 2026) - map art tiles
  (kept per map, `MV.pieces`) + `C_Map.GetMapRectOnMap` (BiS Guild's Where.lua way) on a canvas inside a
  ScrollFrame that cuts at the glass; a view per panel `{ z, cx, cy }` (`MV.ZOOMS` 1-16x, `MV.Zoom` around the
  cursor, `MV.ZoomOn`, drag = an OnUpdate only while the button is down, `MV.StopDrag`); pins are HOLLOW squares
  (four sides + a dark outline, no fill), merged within `MV.MERGE` px into one box with a count (`MV.Clusters`).
  `Core/Pins.lua` (`ns.Pins`): world-map pins via HereBeDragons-Pins (the corner-bracket viewfinder).
- `Core/Journal.lua` (`ns.J`): the GLASS COCKPIT (8 Nov 2026), 1001 x 700 (1.43:1, `J.Fit` scales it down on a
  short screen, clamped): BiSTheme housing, two black displays (`f.left`, `f.right`), the display colours in
  `J.GLASS` / `J.Glass` / `J.Ink` (green ok, cyan labels, magenta chosen, amber caution, white data). Bezel keys
  (`J.Key`: raised, pops, green `lit` bar) - `f.tabs` MEMORIES / MAP / YEAR, `f.who` CHARACTER, `f.close`, soft
  keys `f.prev`/`f.next` (memories) or `f.rangeDown`/`f.knob`/`f.rangeUp` (map). Left: `J.Pages()` (`J.PER` = 6
  memories a page, night headings repeated), `J.Turn`, `J.PageOf`, magenta brackets `f.selL/R`; or the map
  (`J.PaintMap`) or the year. Right: the postcard (`J.Postcard`, poses `J.POSE`; the creature by `display`,
  BiS Tools' `CodexCreature`, else `npc` - `J.Ask` looks again `J.LOAD_WAIT` later, asks again if nothing drew,
  `J.Look` sets the pose (a boss `J.DEAD`, UNVERIFIED, else 1) and the camera only once drawn), the note, the data
  blocks `f.data` (`J.DATA`). The memo line (ALBUM, `f.pathBox`, the count), the on-this-day card (`J.Toast`),
  the countdown (`J.Count`).
- `Core/Lounge.lua` (`ns.Lounge`, `L`): THE CLIPPER LOUNGE (8 Nov 2026), the journal full screen (`/bism lounge`, lng,
  clipper; the journal's `f.lounge` key). `BiSMemoriesLounge` = a dark backdrop on UIParent (FULLSCREEN_DIALOG, Escape)
  holding `L.room`, drawn at ONE design size `L.W` x `L.H` (16:9; every place in units `L.U` = 1% of the width, the
  mockup's cqw) and `SetScale`d to the largest 16:9 that fits UIParent each time it opens (`L.Size`); `L.Fonts` keeps
  every word at its share of the width, never under `L.MIN_FONT` (9) on the screen. Parts (`L.parts`): the departure
  board `L.board` (`L.ROWS` flights a page, `L.TILES` split-flap tiles per column, `L.Flights` codes BOS/LVL/PLC...,
  `L.Remark`; `L.Flip` = an OnUpdate only while the letters clatter, `L.FLIP_BUDGET`); the window seat `L.seat` (sky
  bands, the shade, `L.post` = J.Postcard's holder - J.Postcard(e, p) draws into any `{you, them, note}`; clips its
  children) under OUR OWN surround art `L.surround` (Media/window.tga, made by `dev/art.py` - also disc.tga, ring.tga);
  the boarding pass `L.Pass(parent, fonts)` (a frame of its own, words from `L.PassFields(e, list, {private})` - one
  place, for the coming SHARE card; branded BiS> Memories, never "Clipper", Arn 8 Nov); the note card (`L.CardFields`),
  the sign, the call pills (`L.call`); the paper route map `L.map` (Map.lua's MV with `panel.paper` / `panel.pal`, dashed
  arcs `L.Arcs` in time order, Lines); the gauges `L.gauges` (`L.Counts`, `L.Angle`, needles = Lines, `L.Swing` once
  on opening). The chosen memory is the journal's `J.sel`. Shut (Escape, X, `PLAYER_REGEN_DISABLED`): OnHide stops
  the flip, the swing and a drag; it does not open in a fight (`L.InFight`). Its SHARE pill (`L.call.share`, in
  `L.shareRow` beside the sign) and its hands for Share.lua: `L.Px`, `L.At`, `L.Fill`, `L.Word`, `L.Box`, `L.Width`.
- `Core/Share.lua` (`ns.Share`, `S`): THE SHARE CARD (8 Nov 2026) - `/bism share [n]` (shr), the journal's `f.share` key,
  the lounge's pill, `S.Take(e)`. `BiSMemoriesShare` = a frame with NO parent (the clean shot fades UIParent, never it),
  pinned over UIParent at its scale, FULLSCREEN_DIALOG, Escape; the lounge's teal + walnut trim, `S.room` at the lounge's
  design size `SetScale`d to the largest 16:9 (`S.Size`), the ticket `S.ticket` at `S.TICKET` (the mockup's 7/12 inset):
  the seat column (`S.window` clips, sky bands, `S.post` = J.Postcard's holder with `post.own`, under our `S.oval` art -
  Media/oval.tga, dev/art.py), the middle (`S.f`: brand, head, title shrunk to fit `S.TITLE_EM`, the tangerine line
  `S.Line`, route, `S.FIELDS`, CREW, CARGO), the stub (kind, `S.bars`, place, the BiS> MEMORIES stamp). Words from
  `S.Fields(e, list, hide)` (L.PassFields underneath; hidden = class only, "4 friends: ..." in `S.CLASS_INK`; cargo names
  `S.Item`, `S.QUALITY_INK`). Up: the journal / lounge step out (`S.was`), `S.Wait` every `S.STEP` until `S.Ready` (the
  models drawn, `them.lookedFor` from J.Look) or `S.WAIT_MAX`, `S.Capture` = M.Clean(true) + one Screenshot + the note
  (reason "share", `crop` = `S.Rect()` fractions, `of`, `hidden`) via `M.Keep`; down on SCREENSHOT_* (`S.Shot`) or
  `S.BACK` s, OnHide gives the interface back and reopens what stepped out. A fight: refused / closed at once.
  `shareHidden` (default hidden) is written into every save once by `ns.ADDED` (Init.lua `ns.WriteAdded`, stamp
  `share1`). Share notes are kept in the log but are not memories: `J.Entries`, the year and on-this-day skip them.
  API `ShareCard` / `ShareMemory` (version 4) through `S.Card` / `S.Take`.
- Cargo (Memories.lua, 8 Nov 2026): a boss memory keeps item links seen in the `M.CARGO_FOR` s after it (`M.WatchCargo`,
  a timer ends it; `M.AddCargo` from CHAT_MSG_LOOT, `M.LootWindow` on LOOT_OPENED), `M.CARGO_MAX` at most.
- `Album/BiSMemories-Album.html`: a "share" note with a crop (`cropOf`) is drawn as its ticket cut out with a canvas
  (`shareFigure`, `cutInto`), SAVE IMAGE (`saveCard`, toDataURL + download) and COPY (`copyCard`, ClipboardItem, shown
  only where it exists); a picture opened by relative path cannot be handed over (canvas taint) - `pickCard` asks for it.
- `UI/Options.lua` (`ns.CFG`): BiSTheme's options window in two columns, the minimap button (kit standard, Minimap
  minor 5: left = journal, right = `CFG.Toggle`, our own options window - right-click again closes it, never the
  game's options) and the BiS> Memories page in the game's options (`CFG.RegisterPage`, at PLAYER_LOGIN). Since 8 Nov
  2026 the page is the kit's dashboard (`T.Dashboard`, Settings minor 3, the family rule): `CFG.Pages()` regroups the
  window's own rows (`CFG.Sections()` makes the tables ONCE, so both hold the same ones) into eleven sections - the
  camera, milestones, bosses*, loot*, deaths*, out in the world, group photos*, the journal, world-map pins*, the
  album page, share cards (* = a switch of its own, through the row's setter = what `/bism on|off` / `/bism pins` write).
  `CFG.Model()` repaints our window when it is open. The window is never held inside the page; its buttons (journal,
  a picture now, group call) put the game's options away first.
- Forever 1.0 (7 Nov 2026): `ns.DEFAULTS` = what a NEW install gets (big moments on, extras off); `ns.WAS`
  (Memories.lua) = 0.10.1's values, written once into an EXISTING save by `ns.Forever10` (Init.lua, before `db()`;
  stamp `forever10`). A per-character mirror alone counts as existing. A setting added AFTER 1.0 goes in `ns.ADDED`
  ({ stamp, values }) and is written into every save, new and existing, once (`ns.WriteAdded`, right after Forever10).
- `Libs/`: embedded `BiSTheme/Console.lua`, `Options.lua`, `Minimap.lua`, `Settings.lua` and `LibBiSComm-1.0` — copies, see
  `../_bisdev/CLAUDE.md`. Since 0.9.0 also `LibStub`, `CallbackHandler-1.0`, `HereBeDragons` (BSD), BiS
  Tools' copies byte for byte - `Libs/THIRD-PARTY.txt`. The suites compile HereBeDragons, never run it.
- `dev/tests.lua`: headless suite on `dev/kit.lua` (Nebbinator's strict harness, verbatim). Loads the TOC's
  files in order, fails on any global not in `ALLOWED`. `dev/theme.lua`: the palette law.
- `dev/release.ps1`: zip + CurseForge upload (normally GitHub runs it on a tag — see
  `../_bisdev/docs/playbook.md`).
- `.github/workflows/check.yml` (every push/PR) and `release.yml` (tag = release, PR = dry run).
