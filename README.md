# Candy Marble

Isometric marble racer in the spirit of Marble Madness, with a candy-toy look.
Godot 4.7 (Jolt physics), models built with Blender scripts.

Roll the peppermint ball to the golf hole as fast as you can. Your score is
your time: each level has a par (gold medal), silver at 1.3x and bronze at 1.7x
par. Best level times and best full runs are saved locally.

- **Title screen** with Play / Continue, level select (best times, medals)
  and settings. Levels unlock one by one as you finish them.
- **Settings**: camera follows the track (default, the playfield turns so the
  way ahead points up the screen) or fixed isometric, zoom, music and effects
  volume, graphics high/fast, fullscreen, reset progress.
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

WASD / arrows / left stick to push the ball, R to restart the level, Esc for
the menu, F11 or Alt+Enter for fullscreen.

## Levels

| # | Level | Par | What's in it |
|---|---|---|---|
| 1 | Sugar Lane | 105 s | A descent from the top of the candy hills: slope, slalom, stairs, the candy chute, a leap, a loop, a river |
| 2 | Gumdrop Pinball | 80 s | RACE. Pinball park: tables, windmills, a loop, stairs, a catapult |
| 3 | Sprinkle Skies | 75 s | Island hopping: kickers, hoppers, a cannon, a leap, a ghost garden, a catapult |
| 4 | Licorice Loops | 90 s | Stompers, the candy chute, windmills and haunted hills on the way down |
| 5 | Candy Castle | 110 s | RACE up the castle: hoppers, stompers, cannons, windmills, ghosts, a catapult |
| 6 | Pinball Parlor | 125 s | Speed run through every toy in the park |

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
  comes back). F1 lists every shortcut.

A **quest** is a pack of levels with a name, an author and a description. The
Quest tab adds, copies, orders and deletes levels, and can remix a built-in
level. Quests are saved as JSON in `user://quests/<id>.candyquest`.

Sharing and installing:

- **Copy share code:** one line of text (`CANDYQUEST1:...`, gzipped JSON). Your
  friend uses Quests > Paste code.
- **Save as file:** a `.candyquest` file. Your friend drops it on the game
  window, picks it with Quests > Open file, or copies it into the quest folder.

Shared files are data only: every field is checked and clamped
(`CustomLevel.sanitize`) and no code is ever loaded. The sample quest
`quests/sweet_starter.json` (built by `tools/make_sample_quest.py`) is installed
on first launch.

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

## Tests

```bash
godot --headless --fixed-fps 120 -s tests/playtest.gd      # mechanics
godot --headless --fixed-fps 120 -s tests/levels_test.gd   # bot plays every level
godot --headless --fixed-fps 120 -s tests/race_test.gd     # race win / 2nd place outcomes
godot --headless --fixed-fps 120 -s tests/hazards_test.gd  # stomper, hopper, ghost, windmill, catapult
godot --headless --fixed-fps 120 -s tests/editor_test.gd   # editor tools, undo, quests, share codes, sanitising
godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --remix   # built-in levels after a trip through the quest format
godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --quest=res://quests/sweet_starter.json
godot --always-on-top -s tests/shots.gd                   # screenshots to tests/shots/
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
