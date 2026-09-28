# Candy Marble: game elements handover

Everything a level designer (human or bot) has to work with, in one place.
The code is the source of truth: `scripts/level_base.gd` (tiles, objects),
`scripts/custom_level.gd` (extras, ranges, themes, the JSON format),
`tools/make_campaign.py` (the campaign), `tools/make_madness_quest.py` (the
quest packs). Run the bot after every change: nothing ships untested.

## 1. How a level is described

A level is two ASCII maps of 2x2 world-unit tiles plus a list of extras.
Column = x, row = z. Tile (i, j) covers world x in [2i, 2i+2], z in [2j, 2j+2];
its centre is (2i+1, 2j+1). Extras and route points use *tile units* where an
integer is a tile centre (`tile = [3, 1]` is the centre of tile 3,1; 3.5 is
the edge between tiles 3 and 4).

Level settings (LevelBase fields / quest JSON keys):

| Setting | Meaning |
|---|---|
| `title`, `description` | The intro shows at most 90 characters of the description |
| `time_limit` / `par` | Seconds. Gold at par, silver at 1.3x, bronze at 1.7x |
| `step` | Height of one tier in world units. 0.5 default (campaign levels 1, 3 to 10), 1.0 for tall Marble Madness cliffs (2, 11, quest packs) |
| `break_drop` | The marble breaks on a drop of more than this many tiers (0 = never). Launches never count |
| `race` | The licorice rival races you along the route. `rival_speed`, `rival_tint` |
| `silly` | Silly Race: slopes push the marble UP, monsters are harmless and squishable |
| `monster_speed`, `monster_tint` | Multiplies every monster's speed; tints every monster without its own tint |
| `tier_colors[5]`, `ramp_color`, `wall_color` | Theme. Tier colour = colours[tier % 5], so a descent shows stripes |
| `hole` | Automatically false when a `goalpad` extra exists (checkered GOAL pad instead of the golf hole) |
| `route` | Waypoints in tile units, in order: the bot, the rival and the follow camera use them |

## 2. Height map characters

| Char | Tile |
|---|---|
| `.` | Void. Roll off and you fall |
| `0`..`9` | Flat at that tier (tier x step). A higher neighbour is a wall (even one tier at step 1.0), a lower one a drop |
| `e` `w` `s` `n` | Ramp rising towards +x / -x / +z / -z. A run of ramp tiles is one slope between the flat tiles at its ends: 1 tile for 2 tiers (step 0.5) is 27 degrees, 6 tiles for 1 tier is gentle. If the high end is void it's a kicker rising 0.35 per unit (a jump) |
| `a` `b` `c` `d` | Diagonal ramp rising towards -x-z / +x-z / -x+z / +x+z (the corner of that 2x2 letter grid). `a` slopes straight down the screen with the default camera. A band of them between two plateaus with diagonal edges is one incline; it is flat over the half tile at both ends so it meets the plateaus exactly. Use two or more tiles across; see `tests/diagonal_test.gd` |

Rails are just higher tiles next to lower ones. Marble Madness style means
no rails: open edges everywhere except where a turn follows a fast descent.

## 3. Object map characters

| Char | Object | Notes |
|---|---|---|
| `S` | Start | One per level |
| `G` | Golf hole | The finish, cut into the ground with a funnel |
| `B` | Pop bumper | Bounces, fills the Sugar Rush meter |
| `H` | Hill | Round bump, height 1.1, radius 0.9 |
| `P` | Cone | Tall narrow spike (2.6 high, radius 0.7) the marble can't climb. Marble Madness pyramids |
| `W` | Waves | Small ripples, fade out at the edges of the wave area |
| `T` | Trench | A dip; neighbouring trenches join into a channel. On top of a raised block it makes a sunken top |
| `>` `<` `v` `^` | Booster | Sets speed towards +x / -x / +z / -z |
| `x` `X` | Sweeper along x | Moves over the following `-` tiles (`X` fast). Sweeper sits at the low end of its run |
| `z` `Z` | Sweeper along z | Over the `\|` tiles below it |
| `C` | Checkpoint across x | For travel along z; spans the whole track |
| `K` | Checkpoint across z | For travel along x |
| `@` | Rollover star | Pinball rollover |
| `#` | Drop target | A bank of targets opens the `targets` gate channel |
| `A` | Sour goo | Pool that pops the marble |
| `M` | Humps | A strip of M tiles makes big smooth humps along its long side (Marble Madness bridges) |
| `I` | Ice | Friction 0.04, hardly any grip or steering |
| `l` `t` `b` `g` `%` `h` `r` `$` | Decor | Lollipop, candy tree, gummy bear, gumdrop, golden cupcake, heart, wrapped candy, gem |

## 4. Extras (things with parameters)

Every extra has `type`, `tile [x, z]` and optional `yaw` (degrees) and `tint`
("#rrggbb", monsters only). Ranges are what the editor allows; the campaign
generator is not clamped but stays inside them.

### Monsters (killed by touch unless the level is silly)

| Type | Parameters | Behaviour |
|---|---|---|
| `enemy` | `travel [x, y, z]` world units, `period` 0.4..20 (there and back), `phase` 0..1 | Sweeper block sliding back and forth. Sweepers in the object map become these |
| `stomper` | `period` 0.8..12, `lift` 1..5, `phase` | Marshmallow press. Pass while it's up. `reach` 1.45 |
| `hopper` | `travel`, `period`, `hops` 1..8, `hop_height` 0.4..4, `phase` | Gumdrop that hops along its travel; go under it mid-hop |
| `ghost` | `speed` 0.5..8, `leash` 1..16, `sense` 2..20, `chase_time`, `rest_time` | Chases when it sees you, gets tired, drifts home |
| `windmill` | `spin` -4..4, `arm_length` 1.5..6 | Swats the marble away, doesn't pop it |
| `steelie` | `speed` 1.5..9, `sense` 3..20, `leash` 3..30 | The black marble: rolls at you when you're in range, shoves you, returns home. Keep it off two-tile ledges unless you mean it |
| `slime` | `travel`, `period` 1..20, `phase` | Acid blob patrolling; melts the marble |

### Launchers and rides

| Type | Parameters | Behaviour |
|---|---|---|
| `catapult` | `target_tile` | The spoon: roll into the cup, get flung in a high arc to the target |
| `cannon` | `target_tile`, `hang` | Fires you to the target; `hang` adds flight time |
| `pipe` | `target_tile`, `speed` 2..14 | Candy pipe: sucks you in, spits you out at the spout towards the target |
| `chute` | `y` | S-curve slide. The model drops exactly 2 units over 8 world units (4 tiles): place it over a void with the top ledge 2 units above the landing (4 tiers at step 0.5, 2 at step 1.0) |
| `loop` | | A vertical loop; needs booster speed |
| `hoop` | `height` 0.8..9 | Decorative ring to fly through |
| `slingshot` | `strength` 4..20 | Pinball slingshot |
| `flipper` | `strength` 6..20 | Pinball flipper batting the way it points |
| `spinner` | | Pinball spinner |
| `redirect` | `strength` 4..20 | Speed bank: turns and launches the marble the way it points (banked turns) |

### Puzzles and finish

| Type | Parameters | Behaviour |
|---|---|---|
| `switch` | `channel`, `open_time` 0..60 | Floor button. Opens every gate on its channel, for good or for `open_time` seconds |
| `gate` | `channel`, `open_time`, `height`, `y`, `size [w, h]` tiles, `bridge`, `yaw` | A candy gate. With `bridge = true` it is a plank that rises when the channel opens: `y` is the plank's world height (tier x step), and it needs a landing tile on the far side |
| `secret` | | Easter egg star: a cheer when found (`tests/campaign_test.gd` rolls backwards off level 5's start to find one) |
| `goalpad` | | The checkered GOAL pad. Finishing without a hole |

## 5. Themes

Campaign themes live in `tools/make_campaign.py` (meadow, sky, caramel,
licorice, space, bakery, swamp, pinball, bubblegum, summit, beginner,
lemonade); the editor's are in `CustomLevel.THEMES` (Candy, Mint choc,
Bubblegum, Lemonade, Blueberry, Caramel). Raspberry is reserved for danger.

## 6. Building the campaign

`python3 tools/make_campaign.py [n ...]` writes `scripts/levels/level_N.gd`.
Levels are stitched by the course stitcher (`tools/course.py`): pieces are
authored travelling +x in a 6-row strip (rows 0 and 5 rails, rows 1 to 4 the
lane) and rotated on turns; wider pieces set `zoff` so the 4-tile lane lines
up. Height digits inside a piece are relative to its `entry` tier; the
stitcher tracks the tier and asserts it stays in 0..9 (mind that rails are
tier + 1: a start at tier 9 is impossible).

Basic pieces (`tools/genlevels.py`): start, finish, straight, waves, hills,
bumpers, sweepers, bridge, ramp_up, ramp_down, drop, kicker, loop, river,
table, cannon_hop, spinners, checkpoint, slope_down, slalom, stairs, funnel,
leap, split, hopper_lane, stomper_gate, ghost_garden, windmill_plaza,
catapult_launch.

Set pieces (`tools/make_campaign.py`, each used in one level):

| Level | Pieces |
|---|---|
| 1 Practice Slopes | hillside (striped rolling descent), pyramid_pinch, diag_finish (diagonal ramp band to the hole) |
| 2 Steelie Steps | pillar_field, steep (long ramp), pipe_hop, wave_slide, step_down, ledge |
| 3 Muncher Walkways | walkway_maze (walls are the drop, key in the far dead end), hump_bridge, slime_ledge |
| 4 Catwalk Derby | halfpipe (banked corridor), chute_drop, boost_strip |
| 5 Starlight Islands | island, leaps, cannon_hop, the secret behind the start |
| 6 Stomper Works | big_press (timed gate), switch_gap (button bridge) |
| 7 Sour Gorge | goo_planks, slime_flats, goo_beams |
| 8 Pinball Pyramids | pyramid_field, pinball_machine (locked exit), table |
| 9 Silly Sundae | cross_bridges, loop |
| 10 Ultimate Candy | checker_dips, ice_lane, steelie_run, press_run |
| 11 Beginner Race | block_plateau, cone_plateau, steelie_ledge, hourglass, pillar_walkways, wave_floor, goal_pad |
| 12 Silly Race | cone_walk, cone_cross, bonus_field |

Turns: `T(d, bank, w, rails)`. `w = 2` is a narrow ledge corner, `rails =
False` leaves it open, `bank = True` adds a speed bank. Two right turns make
a U-turn 6 tiles over; wide pieces on parallel legs overlap, so add straights
(the stitcher raises on overlap).

Adding a level: a `level_N()` in `make_campaign.py`, the preload in
`MainGame.LEVELS` (`scripts/main.gd`), a row in README's table. Tests that
depend on specific levels: `race_test.gd` (level 4 is a race),
`campaign_test.gd` (level 5 has the secret and cannon behind the start, level
8 has flippers), `editor_test.gd` (remixes level 6, which has sweepers).

## 7. Quest packs

`quests/*.json` (format "candy-quest") are built by
`tools/make_madness_quest.py` and `tools/make_madness2_quest.py` with the
`Map` helper: `fill`, `put`, `flood_pit`, `extra`, `way`, `level`. Bump the
pack's `updated` number when levels change or installed copies won't refresh.
Register a pack in `Quest.SAMPLES` (`scripts/quest.gd`), the Level bots step
of `.github/workflows/build.yml` and the README. Quest levels are capped at
160x160 tiles, 400 extras, 400 route points.

## 8. Checking a level

```bash
godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --level=N [--verbose] [--trace] [--rival] [--cam]
godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --quest=res://quests/x.json
godot --headless --fixed-fps 120 -s tests/levels_test.gd -- --remix   # built-ins after the quest format round trip
godot --headless -s tools/check_seams.gd -- --level=N                 # ramp tiles that don't meet their neighbours
godot -s tests/shots.gd -- --windowed                                 # screenshots to tests/shots/
godot --always-on-top -s tools/preview_quest.gd -- res://quests/x.json
```

The bot steers along the route at cruise speed 6, never brakes, waits for
sweepers and stompers, and gives up after 180 s ("stuck at tile (x, z),
waypoint k/n" tells you where). It reports the time against par: keep the bot
well under par, players are slower. `--cam` adds how far the marble drifts
off the follow camera's centre (aim for under 3).

Things the bot taught us: a gate bridge needs a landing tile and route
points on both sides; respawn checkpoints next to goo pools cost dozens of
falls; a steelie parked at the foot of a ramp blocks it; a diagonal band that
touches a stray rail at one corner must not read that rail as its plateau
(fixed: the most common edge height wins); open corners after a fast descent
throw the marble off, so rail those turns.
