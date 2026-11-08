# BiSMemories

## Unreleased

- **The album page is a night flight now.** Open the album and you look out through a cockpit windscreen at a neon sunset over the grid, with a city on the skyline. Under it is a dash in stitched leather with a walnut and brass rail. Every picture sits in its own black glass screen, the search box is a flight computer's green scratchpad, and the counts are cockpit keys that light up pink when you pick one. Each night has its own heading, marked like a waypoint. It works the same as before; only the look is new, and it still works with the internet unplugged.

- **Share cards: a memory as one picture to post anywhere.** Press SHARE on the journal or in the lounge (or type `/bism share`, or `/bism share 3` for an older one). For a moment the whole screen becomes that memory's boarding pass, big and alone: the boss, where and when, how long it took, who was with you and the loot that dropped. One screenshot, then everything comes back.
  - **Names hidden, for everyone, from the start.** You show as your class ("A SHAMAN") and your party as "4 friends: rogue, hunter, druid, mage". No realm, no guild, no names. Want them on? The **NAMES OFF / NAMES ON** key beside SHARE in the lounge flips it with one click (orange when names are on), or `/bism share names on`, or the "share cards" row in the options.
  - **The window seat shows on the card** - you, the boss and the sky in the oval. (On the first try it came out as blank paper.)
  - **The loot that dropped.** A boss memory now remembers the items seen in the minute after the kill, and the card lists them.
  - **Save it from the album page.** A share card shows up cut down to just the ticket, with SAVE IMAGE (a .png in your Downloads) and COPY (where your browser allows it). Save it and post it anywhere.
  - Never during a fight: it won't start in one, and a fight that starts puts it away at once.
  - **For other addons:** `BiSMemoriesAPI.ShareCard(owner, card)` and `ShareMemory(owner, index)` (API version 4). The player's names switch applies.

- **The Clipper Lounge: your memories full screen.** Press LOUNGE on the journal (or type `/bism lounge`) and the whole screen becomes a 1960s jetliner lounge. It fits any monitor, laptop to ultrawide, and Escape takes you back.
  - **A departure board across the top.** Your memories are flights on split-flap letters: the time, a flight number (BOS for a boss, LVL for a level, PLC for a new place...), where it was, the zone as the gate, and a remark like FIRST KILL or FASTEST. Turn the page and the letters clatter over, then stop. Click a flight to pick it.
  - **The window seat.** The memory you picked, seen through an oval cabin window at dusk: you, and a boss you killed lying beside you.
  - **Your boarding pass.** A ticket for the memory: where you came from and where it happened, passenger, flight, seat (your level), date, and the screenshot's file name on the tear-off stub.
  - **A route map from the seat pocket.** The world map on paper, with dashed lines joining your memories in the order they happened. Zoom with + and - or the mouse wheel.
  - **Five round gauges** for bosses, level, places, deaths and memories kept. Their needles swing into place when the lounge opens.
  - **Call buttons**: EARLIER and LATER step through your memories, GROUP PHOTO starts one, JOURNAL takes you back to the window.
  - A fight closes the lounge right away, and it won't open during one.

- **Your journal is a jetliner cockpit now.** A bigger window (same shape) with two black glass screens side by side, each doing one job in big, easy type. Colour means something: green = on, cyan = labels, magenta = the memory you picked, white = the facts.
- **Keys instead of tabs.** MEMORIES, MAP, YEAR and CHARACTER (just this character, or all of them) are raised keys along the top; the one you are on has a green bar.
- **Six memories a page, big.** The left screen is a page like a flight computer's: "MEMORIES 1/13", six memories with the time and kind over each, each night's heading as a cyan line. PREV PAGE / NEXT PAGE underneath, or use the mouse wheel. The one you picked sits in magenta brackets.
- **The memory on the right screen.** The 3D postcard on top, the note in big white letters, then WHERE, LEVEL, WITH, FIGHT TOOK and FILE in their own places.
- **The boss lies dead beside you.** A boss kill's postcard now shows the boss lying at your feet, not just you.
- **Zoom the map.** The mouse wheel zooms in and out around the pointer, drag to move around, and the RANGE knob under the map (with - and + keys) shows how close you are (1x to 16x). Pins are hollow squares with an empty middle. Pins too close together become one box with a number; zoom in (or click the box) and they spread out. Click a pin to open that memory on the right.
- **The album line at the bottom** shows ALBUM, the path to copy, and how many memories you have kept. How to use the path is in its tooltip.
- **For other addons:** `BiSMemoriesAPI.TakeMemory(note, kind, from, extra)` can say which creature it was (`npc`, `display`) and ask for a picture with the interface left in (`keepUI = true`). BiS Shell's ADVENT.EXE uses this so its boss pictures show the game screen.

## 1.0.0 - Forever 1.0

- **Already using BiS Memories? Nothing changes for you.** Every switch you had stays exactly as it was - including the ones you never touched.
- **A quiet start for new players.** A fresh install takes pictures of the big moments only: level ups, a boss's first kill (and your fastest), achievements, and firsts like your first mount. Loot, deaths, duels, new places, exalted, the weekly candid, gamba wins, group photos, the camera click, the on-this-day message and the world-map pins all start off - switch on whichever you want.
- **All the options in one place.** Press Escape, then Options, then AddOns, and find **BiS>**: every BiS addon you have is listed there, with what is on, and a page for each.
- BiS> Memories in Esc > Options > AddOns is a full-page dashboard now: every section down the left, its settings big and readable on the right.
- **The minimap button, the same as every BiS addon.** Left-click opens your memories; right-click opens the options window (right-click again closes it).
- **World-map pins are a camera viewfinder now**, four corner brackets in the memory's colour with nothing in the middle, so a quest marker or a road under one stays in plain sight. They also sit under the game's quest pins, so the quest always takes the click.
- **Group photos started by others have their own switch.** "others can call one" decides whether someone else's `/bism group` can put a countdown on your screen and take your picture. Off for new players, on for everyone who had the addon.
- **Fixed: clicking a name inside a dungeon or raid.** The game's player menu opened from a memory inside an instance could break the game's own menus. Inside an instance it now stays shut and one line tells you to whisper them (`/w Name`) instead; out in the world it opens as before.

## 0.10.1

- **Which BiS versions your guild runs:** `/biscomm ver` lists every BiS addon around you, who has the newest, and which release is marked critical. Nothing is said unless an update is critical (or your copy is too old to talk to a guildmate's) - then one line, once, never in a fight.

## 0.10.0

- **Clearer windows.** In the options window (and the minimap menu) every button, box and row lights up under the mouse, the window is 20% bigger, and the bottom strip shows which version you are on until you hover a setting.
- **Short words for the long commands.** Every `/bism` command longer than 4 letters has a short one too: `snd` (sound), `clr` (clear), `zone` (zones), `stat` (status), `hear` (heard), `book` (journal), `opt` (options), `grp` (group), `otd` (onthisday), `each` (every), `cln` (clean). The long ones still work, and `/bism help` shows both.
- **The journal lights up under the mouse.** Its page tabs, the character button, each memory in the list, the names under "with" and the on-this-day card now glow with a purple wash and a bar on the left when you point at them; the dots on the journal's map and the pins on the world map get a purple edge.
- **The journal shows its version**, faintly, in the bottom-right corner - and on a test copy, which build it is.

## 0.9.4

- **A real camera shutter.** Every memory now clicks with the game's own screenshot camera sound instead of a menu click. It plays on the sound-effects channel, so muting sound effects mutes it too. `/bism` options still switch the sound off.

## 0.9.3

- **The Deeprun Tram's timetable, for the whole guild.** With the shared BiS lib's new version, riding the Deeprun Tram with any BiS addon times it for your guild, the way the zeppelins and boats already are - BiS Tools' ride card and BiS Shell's TRAM-TRAK read it.

## 0.9.2

- **Fixed: clean pictures set off an error on the live client.** Hiding the interface for the picture used the game's Alt+Z call, which the live client only lets a key press make - so every automatic picture was refused ("tried to call the protected function"). The interface now fades out for the instant of the picture instead, and comes back exactly as it was (a dimmed interface stays dimmed).
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
