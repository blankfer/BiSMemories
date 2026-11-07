# BiS Memories — CurseForge page text (1.0.0)

Paste everything below the line into the project description
(CurseForge → BiS>Memories, project 1701857 → Edit → Description), in the Markdown editor.

Written 21 Oct 2026 for 0.9.0. The page it replaces described 0.3.0 and the old two-button album.
7 Nov 2026, 1.0.0: the quiet start and where the options live (one line under "What sets it off").
Changed since the previous text (8 Nov, 1.0.0 - Forever 1.0): the options page is a full-page dashboard under
**BiS>**; the minimap button's two clicks (left = journal, right = options window, again closes it); existing
players keep every switch; the world-map pins are a camera viewfinder and start off; "others can call one" for
group photos.
In the house voice (`_bisdev/docs/voice.md`): the opener talks; lists and tables stay flat.

---

# BiS> Memories

**Takes a screenshot when something worth remembering happens, and writes down what it was. A year from now the picture still says why.**

You killed Ragnaros for the first time. Somewhere in a folder of eleven hundred screenshots is the moment. Which one? BiS Memories wrote it down, with who was standing there.

## What sets it off

- Levelling up
- A boss: your first kill, and every kill that's your fastest yet
- Loot of epic quality or better, an achievement, going exalted
- A death worth keeping: killed by a player or one of your BiS Tools rivals, dying in a boss fight, your first death. In a battleground only a rival's kill counts.
- A duel won, a place you've never been, your first mount, learning to ride
- Your biggest win at a BiS Gamba table
- One candid shot a week, at a random moment

Every one is a switch in the options. A new install starts with the big moments only - level ups, first kills, achievements, firsts - and no sound; switch the rest on whenever you like. Already using BiS Memories? Every switch you had stays exactly as it was. The interface hides for the instant of the shot, so the picture is the game, not your bars.

## Options

- **Esc > Options > AddOns > BiS> > Memories** is a full-page dashboard: every section down the left - the camera, milestones, bosses, loot, deaths, out in the world, group photos, the journal, world-map pins, the album page - and its settings big and readable on the right. Every BiS addon you have is listed under **BiS>**.
- **The minimap button**, the same as every BiS addon: left-click opens the journal, right-click opens the options window (right-click again closes it).

## Your album

A page comes with the addon that turns your Screenshots folder into an album, each picture with its story.

1. In game, `/bism journal`. The box at the bottom holds the album's address: click it, press Ctrl+C, then **Windows key + R**, Ctrl+V and Enter.
2. Press **Choose your WoW folder** once. Your browser asks to "upload" thousands of files. Say yes: it means handing them to the page, and nothing leaves your computer.
3. That's it. From then on the album opens straight to your pictures. **Make a desktop icon** puts it a double-click away.

Search for a zone, a boss, an item or a friend's name, or click a count to see only the boss kills. It works with the internet unplugged.

## The journal, in game

`/bism journal` opens your memories night by night. Click one and you're on a postcard: you in 3D, in what you wore that moment, beside the boss you killed or whoever killed you.

- **Who was there.** Every picture keeps your group. Click a name to whisper them, invite them again, or add them as a friend or a BiS Tools pal (outside instances).
- **The map.** Every picture as a dot where it was taken. On the game's world map, each memory can be a pin: a camera viewfinder, four corners in the memory's colour with nothing in the middle, so the quest marker or road under it stays in plain sight. Pins start off - `/bism pins mine` turns them on.
- **On this day.** Once a day: what happened a year ago today.
- **The year.** Levels, first kills, new places. `/bism year`.
- **Group photo.** `/bism group` counts down on everyone's screen, and the whole group takes its picture at the same second. Someone else's call only reaches you when "others can call one" is on.

## Commands

| | |
|---|---|
| `/bism journal` | the journal |
| `/bism map` | the map of where |
| `/bism year` | the year so far |
| `/bism group` | a group photo |
| `/bism now` | a picture right now |
| `/bism pins mine` / `all` / `off` | pins on the world map |
| `/bism options` | the options window |

## Good to know

- Every character keeps their own memories and their own first times.
- Notes are written when you log out or `/reload`, so a picture from the last few minutes gets its caption after that.
- Part of the BiS family. It talks to the other BiS addons over one shared channel; `/biscomm off` silences it.
- Made for WoW Forever.
