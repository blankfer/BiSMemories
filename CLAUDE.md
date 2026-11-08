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
- `UI/Options.lua` (`ns.CFG`): BiSTheme's options window in two columns, the minimap button (kit standard, Minimap
  minor 5: left = journal, right = `CFG.Toggle`, our own options window - right-click again closes it, never the
  game's options) and the BiS> Memories page in the game's options (`CFG.RegisterPage`, at PLAYER_LOGIN). Since 8 Nov
  2026 the page is the kit's dashboard (`T.Dashboard`, Settings minor 3, the family rule): `CFG.Pages()` regroups the
  window's own rows (`CFG.Sections()` makes the tables ONCE, so both hold the same ones) into ten sections - the
  camera, milestones, bosses*, loot*, deaths*, out in the world, group photos*, the journal, world-map pins*, the
  album page (* = a switch of its own, through the row's setter = what `/bism on|off` / `/bism pins` write).
  `CFG.Model()` repaints our window when it is open. The window is never held inside the page; its buttons (journal,
  a picture now, group call) put the game's options away first.
- Forever 1.0 (7 Nov 2026): `ns.DEFAULTS` = what a NEW install gets (big moments on, extras off); `ns.WAS`
  (Memories.lua) = 0.10.1's values, written once into an EXISTING save by `ns.Forever10` (Init.lua, before `db()`;
  stamp `forever10`). A per-character mirror alone counts as existing.
- `Libs/`: embedded `BiSTheme/Console.lua`, `Options.lua`, `Minimap.lua`, `Settings.lua` and `LibBiSComm-1.0` — copies, see
  `../_bisdev/CLAUDE.md`. Since 0.9.0 also `LibStub`, `CallbackHandler-1.0`, `HereBeDragons` (BSD), BiS
  Tools' copies byte for byte - `Libs/THIRD-PARTY.txt`. The suites compile HereBeDragons, never run it.
- `dev/tests.lua`: headless suite on `dev/kit.lua` (Nebbinator's strict harness, verbatim). Loads the TOC's
  files in order, fails on any global not in `ALLOWED`. `dev/theme.lua`: the palette law.
- `dev/release.ps1`: zip + CurseForge upload (normally GitHub runs it on a tag — see
  `../_bisdev/docs/playbook.md`).
- `.github/workflows/check.yml` (every push/PR) and `release.yml` (tag = release, PR = dry run).
