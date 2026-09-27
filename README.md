# Candy Marble

**Play it in the browser or download it: https://vlx42.github.io/candy-marble/**

Isometric marble racer in the spirit of Marble Madness, with a candy-toy look.
Godot 4.7 (Jolt physics), models built with Blender scripts.

Roll the peppermint ball to the golf hole as fast as you can. Your score is
your time: each level has a par (gold medal), silver at 1.3x and bronze at 1.7x
par. Best level times and best full runs are saved locally.

- **Title screen** with Play / Continue, level select (best times, medals)
  and settings. Levels unlock one by one as you finish them.
- **Settings**: camera follows the track (default: it snaps between the four
  isometric views and only turns when the track runs back down the screen) or
  fixed isometric, zoom, music and effects volume, graphics high/fast,
  fullscreen, **Arcade timer**, reset progress.
- **Arcade timer** (off by default): like the 1984 cabinet, every level adds
  time to one clock and leftover seconds carry over. Run out and it's
  "Time's up!", R starts over from level 1.
- **Races**: on some levels the evil licorice ball races you to the hole. It
  uses boosters, loops and cannons too, and you can bump each other around.
  Win the race to clear the level.
- **Sugar Rush**: pinball hits (bumpers, slingshots, spinners, rollovers,
  hoops, targets, loops, cannons) fill the sugar meter. Full meter = 7 seconds
  of rush: faster, grippier, and you phase straight through sweepers.

## Run

```bash
godot --path .
```

On a phone (the web version), tilt the phone to roll; it calibrates to how
you hold it when the level starts. Or switch to "drag to roll" in Settings.
On a computer: WASD / arrows / left stick to push the ball, R (or pad Back) to restart the
level, Esc / P (or pad Start) to pause, F11 or Alt+Enter for fullscreen.

Each level starts with a 3-2-1-GO countdown; the clock starts on GO. Your best
run on every level (built-in and quests) is saved as a **ghost**: a see-through
blue marble that replays it next time. Turn it off in Settings or the pause
menu.

## Levels

| # | Level | Par | What's in it |
|---|---|---|---|
| 1 | Sugar Hill | 78 s | Wide slopes, a hedge maze with a key switch, a hidden bridge, a locked pinball table |
| 2 | Gumdrop Fork | 60 s | The road splits twice: the gate key is in the fast sweeper lane. A maze in between |
| 3 | Waffle Falls | 68 s | Tall waffle cliffs (falls break you), a waffle maze, beams and a hump bridge |
| 4 | Licorice Derby | 38 s | RACE: boost lanes, banked U-turns, a jump |
| 5 | Sprinkle Islands | 55 s | Island hopping by kicker, cannon and catapult, a maze island. Easter eggs! |
| 6 | Clockwork Bakery | 68 s | A timed gate at the end of the big stomper press, a maze, fast sweepers |
| 7 | Sour Swamp | 78 s | Planks over goo, a goo maze with a key, humps and ghosts. Goo melts you |
| 8 | Pinball Wizard | 66 s | Two real pinball tables: flippers, jets, orbit, plunger. Clear the targets to get out |
| 9 | Rollercoaster Ridge | 72 s | Speed: loops, the chute, a bridge puzzle, leaps, a cannon, a pinball table |
| 10 | Candy Summit | 60 s | Final RACE, uphill to the summit flag |

**Puzzles**: floor switches open candy gates (some only for a few seconds) or
raise hidden bridges; pinball exits open when their drop target bank is down.
**Pinball tables** are laid out like the real thing: plunger lane (skill
shot), rollover lanes, jet bumpers, drop targets, spinner orbit, slingshots,
flippers, and drains you can fall into.
The levels are built by `tools/make_campaign.py` (`python3 tools/make_campaign.py`).

**Hazards**: sweepers (wind-up blocks), gumdrop hoppers (go under mid-hop),
marshmallow stompers (pass while they're up), sour ghosts (they chase you,
then get tired), licorice windmills (they swat, they don't pop).
**Launchers**: boosters, loops, cannons, the spoon catapult, the candy chute.

## Making levels

Levels are two ASCII maps of 2x2 tiles, see the legend at the top of
`scripts/level_base.gd` (heights `0-9`, ramps `e w s n`, objects like `S G B >`,
sweepers `x---` / `z|`, checkpoints, trenches, waves, decor...). Loops, cannons,
hoops, spinners, slingshots and speed banks go in `extras`.

The shipped levels are stitched together from track pieces (straights, waves,
bumper fields, sweeper gates, bridges, ramps, drops, kicker jumps, loops,
rivers, pinball tables, cannon hops, corners) by `tools/course.py`; each level
is a list of pieces in `tools/genlevels.py`:

```bash
python3 tools/genlevels.py
```

## Level editor and quests

Title screen > **Level editor** (or Quests > Edit). Build levels in a live 3D
preview that uses the same code as the game:

- **Sections (easiest):** the Pieces tab has ready-made track pieces (start
  pad, straights, turns, ramps, jumps, loop, bumper field, pinball table,
  sweepers, stompers, finish and more, 29 in all). Clicking one adds it at the
  green arrow at the open end of your track, at the right height, with its
  path for the rival and camera. Clicking the map places the picked piece
  there instead (R turns it).
- **Road:** drag a railed lane from anywhere. It keeps the height where you
  start, opens walls it runs into and adds a ramp when the ground it reaches
  is higher or lower. Sections continue where a road ends.
- **Guide:** a "next step" card says what to do and has a button for it. The
  Reach overlay shades ground the marble can't get to and puts an orange ring
  where the track needs connecting to the hole. New levels can start as a
  guided track, an open island or empty sky.
- **Ground:** paint heights 0-9 (painting past the edge grows the map), box
  with optional walls, raise, lower, ramps (auto slope, or a jump when a ramp
  runs into void), flood fill, erase, eyedropper.
- **Surface:** waves, hills, trenches.
- **Objects:** start, hole, checkpoint gates, bumpers, boosters, pinball stars
  and targets, 8 kinds of candy decor.
- **Monsters:** sweeper, stomper, hopper, ghost, windmill. Each one has its own
  speed, timing and colour. The Level tab sets a speed and colour for all of
  them at once.
- **Toys:** slingshot, cannon and catapult (click to set the landing spot),
  loop, chute, hoop, spinner, turner.
- **Edit:** select, drag, turn, duplicate and delete. The Path tool draws the
  rival's and the camera's route; without it the game finds one itself.
- **Level tab:** name, description, par time (with a guess button), race mode,
  rival speed and colour, colour themes, map size and crop.
- Undo and redo, flat or 3D view, animated preview, test play with F5 (Esc
  comes back), or **From here** / Shift+F5 to start the test on any tile.
  F1 lists every shortcut.

A **quest** is a pack of levels with a name, an author and a description. The
Quest tab adds, copies, orders and deletes levels, and can remix a built-in
level. Quests are saved as JSON in `user://quests/<id>.candyquest`.

Sharing and installing:

- **Copy share code:** one line of text (`CANDYQUEST1:...`, gzipped JSON). Your
  friend uses Quests > Paste code.
- **Save as file:** a `.candyquest` file. Your friend drops it on the game
  window, picks it with Quests > Open file, or copies it into the quest folder.

Marble Madness touches in the Level tab: **Step height** (taller cliffs) and
**Hard landings** (the marble breaks on drops over N steps). Surface tools
include **Goo** (sour pools that melt the marble), **Humps** (big smooth humps
across a lane) and **Ice** (almost no grip, hard to steer).

Pieces from the original arcade game:
- **Steelie** (Monsters): a heavy black marble that chases you near its home
  and shoves you off ledges.
- **Acid slime** (Monsters): a green blob sliding back and forth that melts
  the marble.
- **Pipe** (Toys): swallows the marble and spits it out at its target.
- **GOAL pad** (Objects): a raised checkered finish with flags instead of the
  hole.
- **Silly level** (Level tab): everything you know is wrong. Slopes roll you
  *up* and you squish the munchers instead of popping.

The shipped **Marble Madness** quest (`quests/marble_madness.json`, built by
`tools/make_madness_quest.py`) has six races, each ending on a GOAL pad:
Spiral Summit, Terrace Falls (steelie, slime, pipe), Goo Gorge (acid alley),
Sky Catwalks (ice), Silly Race and Ultimate Madness (a race over ice and slime).
The **Madness Returns** quest (`quests/madness_returns.json`, built by
`tools/make_madness2_quest.py`) adds five more after the arcade races:
Checker Slope (practice), Muncher Mill (munchers, a button bridge, a pipe),
Hammer Heights (hammers and timed bridges that sink again), Upside Hill (Silly)
and Wave Machine (a race over waves, ice and a booster chute).
`tools/preview_quest.gd` renders a 3D overview of every level in a quest.

Shared files are data only: every field is checked and clamped
(`CustomLevel.sanitize`) and no code is ever loaded. The sample quest
`quests/sweet_starter.json` (built by `tools/make_sample_quest.py`) is installed
on first launch.

Tool icons and piece thumbnails are rendered from the real models:
`godot --always-on-top -s tools/make_icons.gd && godot --headless --import`.

## Models (Blender)

All models are scripted, so they can be rebuilt and tweaked in code:

```bash
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b -P blender/build_assets.py      # ball, enemy, bumper, booster, flag, loop, decor, backdrop
$B -b -P blender/assets_pinball.py    # slingshot, cannon, spinner, rollover, hoop, rails, targets
$B -b -P blender/assets_candy.py      # candies used as floating decor
$B -b -P blender/assets_scenery.py    # castle, gingerbread house, ferris wheel, ...
$B -b -P blender/assets_enemies.py    # hopper, stomper, ghost, windmill, catapult
```

Every entity loads `models/<name>.glb` and falls back to a primitive
placeholder if the model is missing. The terrain is generated from the level
maps and shaded by `scripts/terrain.gdshader` (pillow tiles, icing, chocolate).

## Music

`audio/*.mp3` loop per level (crossfaded), "Gold Star Finish" plays after the
last level.

## Builds and releases

`.github/workflows/build.yml` runs on every push: all tests and level bots, then
Windows, macOS (universal, ad-hoc signed), Linux and Web exports
(`export_presets.cfg`). On `main` it also:

- works out the version from the commit messages since the last release
  (`tools/next_version.py`): `feat:` = minor, `fix:` and anything else = patch,
  `feat!:` or a `BREAKING CHANGE:` footer line = major; commits that are only `docs:`,
  `ci:`, `test:` or `chore:` don't make a release,
- stamps it into the builds (shown on the title screen) and the site,
- deploys `site/` plus the web build (under `/play`) to GitHub Pages,
- publishes a GitHub release `vX.Y.Z` with `CandyMarble-windows.zip`,
  `CandyMarble-macos.zip`, `CandyMarble-linux.zip` and notes grouped into
  New / Fixes / Other. The site links to `releases/latest`.

Preview what the next push would release: `python3 tools/next_version.py notes.md`.

Sounds are made by `tools/make_sfx.py`, the app icon by
`tools/make_app_icon.gd`.

## Tests

```bash
godot --headless --fixed-fps 120 -s tests/playtest.gd      # mechanics
godot --headless --fixed-fps 120 -s tests/levels_test.gd   # bot plays every level
godot --headless --fixed-fps 120 -s tests/race_test.gd     # race win / 2nd place outcomes
godot --headless --fixed-fps 120 -s tests/hazards_test.gd  # stomper, hopper, ghost, windmill, catapult
godot --headless --fixed-fps 120 -s tests/editor_test.gd   # editor tools, undo, quests, share codes, sanitising
godot --headless --fixed-fps 120 -s tests/sections_test.gd # sections, Road join-ups, guide steps
godot --headless --fixed-fps 120 -s tests/madness_test.gd  # hard landings, goo, humps, tall steps
godot --headless --fixed-fps 120 -s tests/flow_test.gd     # countdown, pause, ghost replay, test from here
godot --headless --fixed-fps 120 -s tests/original_test.gd # pipe, ice, slime, steelie, GOAL pad, silly, arcade clock
godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --quest=res://quests/marble_madness.json
godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --quest=res://quests/madness_returns.json
godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --cam     # how much the follow camera turns
godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --remix   # built-in levels after a trip through the quest format
godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --quest=res://quests/sweet_starter.json
godot --always-on-top -s tests/shots.gd                   # screenshots to tests/shots/ (-- --quest=... too)
godot --always-on-top -s tests/editor_shots.gd            # editor and quest page screenshots
godot --always-on-top -s tests/perf.gd -- --level=4       # fps, triangles, draw calls
```

`playtest.gd` checks resting, input, speed cap, bumper, sweeper, loop, booster
jump, cannon landing and the hole on a purpose-built map. `levels_test.gd`
drives the ball through each level's `route` with real input (it reads the
sweepers' timing) and fails if a level can't be finished.

Art direction and prompts: [art/STYLE.md](art/STYLE.md).

## Credits

- Font: [Fredoka](https://github.com/hafontia/Fredoka-One) by the Fredoka
  Project Authors, SIL Open Font License 1.1 (`fonts/OFL.txt`).
- Logo: `art/ui/logo.png`, cut out of `art/reference/08-logo-source.jpg` with
  `tools/cut_logo.py` (run with Blender's Python, which ships numpy).
