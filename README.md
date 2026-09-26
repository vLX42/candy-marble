# Candy Marble

Isometric marble racer in the spirit of Marble Madness, with a candy-toy look.
Godot 4.7 (Jolt physics), models built with Blender scripts.

Roll the peppermint ball to the golf hole as fast as you can. Your score is
your time: each level has a par (gold medal), silver at 1.3x and bronze at 1.7x
par. Best level times and best full runs are saved locally.

## Run

```bash
godot --path .
```

WASD / arrows / left stick to push the ball, R or Enter to restart the level.

## Levels

| # | Level | Par | What's in it |
|---|---|---|---|
| 1 | Sugar Lane | 38 s | Railed tour: waves, bumpers, a slow sweeper, a loop, candy river, booster jump |
| 2 | Gumdrop Pinball | 30 s | Downhill into a railed bumper table, bridge sweepers, loop, trench putt |
| 3 | Sprinkle Skies | 16 s | Island hopping with two kicker jumps through hoops |
| 4 | Licorice Loops | 52 s | Terraces, bumper deck, a backwards loop, ramp down to the hole |
| 5 | Candy Castle | 42 s | Loop start, east wall sweepers, kicker over the moat, castle top |
| 6 | Pinball Parlor | 22 s | Speed run: drop targets, speed banks, spinner, rollovers, cannon over the void |

## Making levels

Levels are two ASCII maps of 2x2 tiles, see the legend at the top of
`scripts/level_base.gd` (heights `0-9`, ramps `e w s n`, objects like `S G B >`,
sweepers `x---` / `z|`, checkpoints, trenches, waves, decor...). Loops, cannons,
hoops, spinners, slingshots and speed banks go in `extras`.

The shipped levels are generated from `tools/genlevels.py`:

```bash
python3 tools/genlevels.py
```

## Models (Blender)

All models are scripted, so they can be rebuilt and tweaked in code:

```bash
B=/Applications/Blender.app/Contents/MacOS/Blender
$B -b -P blender/build_assets.py      # ball, enemy, bumper, booster, flag, loop, decor, backdrop
$B -b -P blender/assets_pinball.py    # slingshot, cannon, spinner, rollover, hoop, rails, targets
$B -b -P blender/assets_candy.py      # candies used as floating decor
$B -b -P blender/assets_scenery.py    # castle, gingerbread house, ferris wheel, ...
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
godot --always-on-top -s tests/shots.gd                   # screenshots to tests/shots/
```

`playtest.gd` checks resting, input, speed cap, bumper, sweeper, loop, booster
jump, cannon landing and the hole on a purpose-built map. `levels_test.gd`
drives the ball through each level's `route` with real input (it reads the
sweepers' timing) and fails if a level can't be finished.

Art direction and prompts: [art/STYLE.md](art/STYLE.md).
