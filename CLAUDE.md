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
- `Core/Map.lua` (`ns.MapView`): the journal's map page - map art tiles + `C_Map.GetMapRectOnMap` (BiS
  Guild's Where.lua way). `Core/Pins.lua` (`ns.Pins`): world-map pins via HereBeDragons-Pins.
- `Core/Journal.lua` (`ns.J`): the 1.43:1 window - list + detail with the 3D postcard (`J.Postcard`,
  poses `J.POSE`), map and year pages, the on-this-day card (`J.Toast`), the countdown (`J.Count`).
- `UI/Options.lua` (`ns.CFG`): BiSTheme's options window in two columns, and the minimap button.
- `Libs/`: embedded `BiSTheme/Console.lua`, `Options.lua`, `Minimap.lua` and `LibBiSComm-1.0` — copies, see
  `../_bisdev/CLAUDE.md`. Since 0.9.0 also `LibStub`, `CallbackHandler-1.0`, `HereBeDragons` (BSD), BiS
  Tools' copies byte for byte - `Libs/THIRD-PARTY.txt`. The suites compile HereBeDragons, never run it.
- `dev/tests.lua`: headless suite on `dev/kit.lua` (Nebbinator's strict harness, verbatim). Loads the TOC's
  files in order, fails on any global not in `ALLOWED`. `dev/theme.lua`: the palette law.
- `dev/release.ps1`: zip + CurseForge upload (normally GitHub runs it on a tag — see
  `../_bisdev/docs/playbook.md`).
- `.github/workflows/check.yml` (every push/PR) and `release.yml` (tag = release, PR = dry run).
