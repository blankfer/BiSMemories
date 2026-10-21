# BiSMemories

## Unreleased

- **You show up in FojjiCore's windows.** A party member running FojjiCore now sees your level and experience in its Experience window and your campfire in its Campfires window, instead of "No Addon" (the shared BiS lib, version 16 - quiet if you run FojjiCore's Dungeon Journal yourself, which says the same).

## 0.9.1

- **Carries the shared ride clock** (the BiS lib, version 15): ride a zeppelin or a boat with any BiS addon on and its timetable goes to your guild and group - for BiS Tools' ride card and Power Word: Shell's ZEPPELIN.EXE and HARBOR.EXE.

## 0.9.0

**A new journal, a map of where, and fewer pictures you didn't want.**

- **The journal is new:** your memories on the left, night by night; click one and the right side holds it whole - where, who was with you, how long the fight took, the picture's file name to copy - over a **postcard: you in 3D, in what you were wearing that moment and striking its pose, beside the boss you killed or whoever killed you.** Pages for **the map** and **this year**, and a button for this character's memories or every character's.
- **A map of where every picture was taken:** Azeroth in the journal with a dot for each memory, and **pins on the game's world map** (`/bism pins mine`, `all` or `off`). Hover one for what it was, click it to open it.
- **On this day:** once a day at login, what happened on this day a year ago - or, this first year, a month ago. A line in chat and a card on screen; click the card to open it.
- **The year so far:** levels and how long each took, first kills, new places, firsts. `/bism year` (`/bism year all` for every character), and the journal's "this year" page.
- **Group photo:** `/bism group` counts down on everyone's screen in your group who has a BiS addon, and everyone takes their picture at the same second.
- **Clean pictures:** the interface hides for the instant of the shot, like Alt+Z, and comes straight back. `/bism clean` turns it off.
- **A minimap button** (the spyglass) and **an options window** for every setting - `/bism options`, or right-click the button.
- **Bosses: the first kill, and your fastest.** Every kill every week filled the album with the same boss. A boss is a memory the first time this character kills it, and again when a kill is your fastest yet. `/bism every boss` brings every kill back.
- **Deaths worth keeping:** killed by a player or one of your BiS Tools rivals, dying in a boss fight, and your first death ever. In a battleground or arena only a rival's kill counts. `/bism every death` keeps them all.
- **The album, made easy:** open the album page (the journal's box at the bottom holds its whole path: click, Ctrl+C, Windows key + R, Ctrl+V, Enter), press **Choose your WoW folder** once, and it finds your pictures and the notes by itself. After that it opens straight to your album every time, and **Make a desktop icon** puts it a double-click away. The page shows your game folder with a Copy button, and a bar while it works.
- **Who was there:** each picture keeps your group by their whole names. Click a name on the postcard to whisper them, invite them, or add them as a friend or a BiS Tools pal.
- **Your older pictures sort themselves out:** pictures from before this version are given to the character who took them (worked out from the levels), boss kills get their boss once you target that boss again, and the map places them by their zone.
- **Firsts:** your first mount, a new mount, learning to ride. **Gamba:** your biggest win yet at a BiS Gamba table.
- **Each character their own:** every memory says who took it, and each character has their own list of places - an alt now gets their own first time in the Barrens even if your main was there first.
- **Fixed:** a ding could be written down as the level before; going exalted could be missed when the game said it as a system line.
- `/bism db` says which saved copy came back at login.

## 0.8.1

- **BiS addons can talk to other players on Forever again.** The game wrongly says addon messages are restricted, and the shared BiS code believed it, so nothing this addon sends to other players went out. It does now - and your guild's BiS Guild map shows where you are (outside instances; `/biscomm share off` turns that off).
- **Names with surnames work.** The shared code now uses your whole "Name Surname": you no longer show up twice on your own guild map, and party members with surnames are recognised.

## 0.8.0

- **BiSMemoriesAPI** - other BiS addons can read your album and ask for a memory to be taken (a screenshot and a note). Your switches still decide: a kind you've turned off stays off, and the gap between screenshots still applies.
- The addon list shows **BiS>Memories**, like its category.

## 0.7.0

- **Your guild can see you on BiS Tools' map.** Every BiS addon now shares your spot with guildmates while you move - every 15 seconds in a small guild, slower as it grows, never from inside an instance. On by default; `/biscomm share off` (or `on`) switches it for every BiS addon at once.
- The shared BiS channel no longer hooks the summon popup on Forever, where hooking Blizzard's code can break it until a restart.
- An icon in the addon list: a spyglass.

## 0.6.0

- **The command is `/bism` now**, like the rest of the BiS family (`/bish`, `/bist`, `/bisg`). `/memories` still works.

- Shared messaging library updated (LibBiSComm minor 10): after a boss, when the game lifts its chat lockdown, BiS addons say hello again so group lists stay current; it respects a realm that blocks addon messages, picks the raid channel only when the game confirms you are in a raid, and ignores anyone flooding it.

- **Fixed: we sent you to the wrong folder.** The album said your account folder is "a number and
  a hash" and that there is "usually only one" of them. Both can be false: it may be a name like
  `ARNOLD891`, and anyone with more than one WoW account has more than one folder - often with the
  nearly-empty one listed first. Following our own instructions, those players opened a folder with
  no `BiSMemories.lua` in it, which looks exactly like the addon having saved nothing. The page and
  the README now say to open each folder until you find the one that **has** the file, and to take
  the most recently changed if several do.
- **Fixed: journal rows ran off the window.** A long memory - a death in "Blackrock Depths - The
  Grim Guzzler", an exalted line, a legendary's full name - was cut with "..." mid-row. A row is now
  when, why and what; hover it for where, how many were with you, and the picture's file name. The
  empty-journal footer was 5 px too long and is one word shorter.

## 0.5.5

- **Fixed: a jewelcrafter photographed every gem they cut.** Six pictures in ten minutes in Black
  Temple, all gems — and they were not drops. Cutting a gem makes the client say *"You create:"*,
  which this addon could not tell apart from *"You receive loot:"*, so every epic cut was an epic
  looted. A gem goes in a socket and is never looked at again; it is not a memory now, however it
  arrives. `/memories gems` puts them back if you disagree.

  Crafting an epic that is **not** a gem — a weapon, a bolt of Spellcloth — is still a memory. The
  fix is aimed at the gem, not at the word "create".

## 0.5.4

- **The album remembers your captions.** Load the addon's saved file once and the next time you
  open the page they are already in it &mdash; you only point it at your Screenshots folder. That
  is the trip worth saving, because the saved file is the one nobody finds twice: it is in `WTF`,
  not in your AddOns folder. The page says how many it kept and when, with a **forget them**
  beside it, and loading the file again replaces them &mdash; pictures taken since the last load
  have no caption until you do.

  **The folders themselves cannot be remembered, only the notes.** When you pick a folder your
  browser hands the page the files and the folder's name, never where it is on your disk, so
  there is nothing to go back to. A browser with storage switched off simply asks for both, the
  way it always did.

## 0.5.3

- **Find one picture among hundreds.** The album page has a search box — type a zone, a boss, an
  item, a level, and it shows only those. Beside it is a row of counts (`12 boss`, `12 death`,
  `18 zone`); click one to see just those, click it again to stop. With a search or a filter on, the
  arrow keys move between the pictures you can **see**, so filtering to boss kills and holding right
  walks you through the boss kills.
- **Drag your Screenshots folder onto the page** if you would rather not browse for it.
- **The album page's address, in game and ready to copy.** `/memories path`, or the box at the
  bottom of `/memories journal` — click it and the whole line selects, then Ctrl+C and paste it into
  your browser. Tell it where WoW lives once with `/memories wow <folder>` and it shows the complete
  path from the drive down, whatever your version folder happens to be called.
- **Both folders are spelled out now**, on the page and in the album's README — including the one
  that catches everybody: the addon's saved file is **not** in your AddOns folder, it is in `WTF`.
  The account folder is a number and a hash, not your email.
- **Fixed: a note you typed came out in lower case.** `/memories now Killed Baron Silverlaine` was
  stored as "killed baron silverlaine" — the whole command line was being flattened, including the
  part that is your own words.
- **Fixed: the window wrote over its own last two memories** after the copy box was added.
- The album's instructions no longer claim your captions are wiped at every login. That was true
  once and was fixed in 0.5.2; the page had not been told.

## 0.5.2

- **Fixed: pictures of places you have been a hundred times.** The addon only wrote a zone down at
  the moment it decided to photograph it, and the event that decides is quiet for whole evenings on
  this client - so everywhere you walked in between stayed unknown, ready to be "new" the next
  time. It now learns where you are from every event that knows, and from every picture taken for
  any reason at all: a photograph of a place is proof you have been there.
- **Fixed: the places you know were forgotten at every login.** This client does not hand back the
  account-wide settings file, and the rescue that saves your notes only ran when there were notes
  to save - so a character who had not taken a photograph yet started each session with an empty
  map. The two copies of the list are now merged on their own.
- **A zone name the game hides is no longer treated as a place.** It could never match itself
  again, so that zone was "new" on every single crossing.
- **At most three new-place pictures in a session**, whatever the client does. Learning where you
  have been is not limited - only the camera.
- **`/memories zones`** says how many places it remembers, and how many new-place pictures it has
  taken this session.

## 0.5.1

- **Fixed: an error in dungeons from messages the game hides.** On WoW Forever the game can hide
  the text of a chat or system message from addons - seen in a dungeon, where a system line broke
  the duel check. Anything hidden is now left out before it is read. A hidden duel line is simply
  not a duel, and a boss kill with a hidden name still gets its picture, as "a boss". A hidden
  zone name is written down as "?".

## 0.5.0

- **Loot reads like loot.** The addon writes down the item link the client handed it, and in the
  game that draws as a purple item name - in a browser it was printing the machinery,
  `|cffa335ee|Hitem:32577...`. The album shows the item's name now, in its own quality colour.

- **The in-game journal is grouped by raid night too.** `/memories journal` now has a heading for
  each night - *Karazhan, Sat 19 Sep, 20:04-00:41, 2 bosses* - with that night's memories under
  it, the same rule the album page uses. One log, one idea of what a night is.

## 0.4.0

- **The album is grouped by raid night, not by calendar day.** A night that starts at eight and
  ends at twenty to one used to be cut in half, with the last two bosses orphaned into "tomorrow"
  while the night they belonged to sat above them. Now a section is a run of memories with no
  three-hour gap in it, so the whole night is one section - *Karazhan, Sat 20 Sep, 20:04-00:41,
  8 bosses* - and everything that happened inside it is there: the kills, the drops, the ding, the
  daft photo of everyone standing on the roof.

  A break for dinner keeps the night together. This afternoon and this evening stay apart.

## 0.3.1

- **Loot pictures are yours again.** `CHAT_MSG_LOOT` carries the whole raid's loot, and the only
  test was the item's quality - so in a 25-man every epic anybody won was a photograph, every few
  seconds, all night. Now it takes **your** loot at the quality you set, plus **anyone's
  legendary**, because an orange dropping is the room's memory and not just the winner's.

  Whose line it is comes from the client's own strings, so it works the same in any language.

  If it was driving you mad before this update: `/memories off loot` stops it at once, no reload.

## 0.3.0

- **Make your own album, from your own screenshots.** The addon folder now carries
  `Album\BiSMemories-Album.html`. Double-click it, point it at your Screenshots folder, and it
  becomes an album you click through - full size on click, arrow keys to move, grouped by day.

  Hand it the addon's saved file as well and every picture it took carries its story: the zone,
  your level, and why it was worth a picture.

  **Nothing is uploaded and nothing is installed.** There is no server and no internet connection
  involved - your browser reads the files off your own disk. Unplug the network and it works the
  same. It asks you to pick the folder because a web page is not allowed to go wandering through
  your drive, which is a good thing.

  `Album\README.txt` has the same in longer words, including where the folders usually live.

## 0.2.0

- **The album, in game.** `/memories journal` opens what happened: newest first, the wheel to walk
  back through it, Escape to close. A memory taken while it is open appears in front of you.

  **No pictures, and that will not change.** An addon cannot list a folder - the only reason this
  one knows a screenshot exists is that it took it and wrote the name down from the clock - and a
  `.jpg` outside `Interface\` cannot be drawn on a frame at all. That is on every client, not just
  this one, and it is why the HTML album exists: a browser can open those files and the game
  cannot. The journal keeps each filename beside its entry so a picture on disk still matches the
  night it came from.

- **`/memories heard`** - what the camera was told, and what never arrived. An album with one
  picture has two explanations that look the same from outside: nothing happened, or the event
  never came. This prints the counts since login, the verdict on the last few, and every event it
  registered for that has not fired at all. It answered that question in one reload.

- On the Forever beta the log starts empty at every login, because that client hands back no saved
  variables to any addon. The journal says so in words rather than looking broken.

## 0.1.0

Takes a screenshot when something worth remembering happens - and writes down what it was, so a
year later the picture still means something.

- **What sets it off:** levelling up, a boss dying (a wipe is not a memory), loot of epic quality or
  better, an achievement, your own death, winning a duel, walking into a zone you have never seen,
  and going exalted. Each one is a switch: `/memories off boss`.
- **One candid a week.** An unposed picture at a random moment while you play - never on login,
  which would just be the same loading screen fifty-two times a year.
- **The note is the point.** Every shot records the reason, the zone, your level, who was in the
  group, and the filename the client wrote, so a picture in Screenshots\ can be matched to its
  moment. `/memories` reads the last ten back; `/memories all` reads the lot.
- **A click of its own**, because the client only plays its camera sound for the PrintScreen key -
  silence would be indistinguishable from "it did not work". `/memories sound` turns it off.
- Runs on WoW Forever and on 2.5.6 from one TOC. Nothing it reads is hidden by Forever's lockdown.

## 0.0.1

- Created from the BiS house skeleton (`_bisdev/new-addon.sh`): shared BiS channel, palette, tests, CI and
  release from GitHub already wired.
