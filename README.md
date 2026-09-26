# Candy Marble

Isometric marble game in the spirit of Marble Madness, with a candy-toy look.
Godot 4.7, Jolt physics.

## Run

Open the folder in Godot 4.7 and press F5, or:

```bash
godot --path .
```

Controls: WASD / arrows / left stick to push the ball, R or Enter to restart.

## Greybox level

Start, trench, hill field with two pop bumpers, two patrolling enemies, a
booster pad into a ramp jump over a gap, goal cup on the plateau.
Layout lives in `scripts/terrain.gd` (height function + areas) and entity
placement in `scripts/main.gd`.

## Tuning

| Where | What |
|---|---|
| `scripts/ball.gd` | `push_force`, `max_speed` (only caps player input, bumpers/boosters can exceed it), `air_control` |
| `scripts/enemy.gd` | `travel`, `period`, `phase` |
| `scripts/bumper.gd` | `strength` |
| `scripts/booster.gd` | `speed` (direction = the pad's local +z) |

## Swapping in Blender models

Every entity scene (`scenes/ball.tscn`, `enemy.tscn`, `bumper.tscn`,
`booster.tscn`, `goal.tscn`) builds a placeholder in code unless it has a child
node named `Model`. Export from Blender as `.glb` into `models/`, open the
scene, add the model as a child and rename it `Model`. Collision stays in code.

For terrain pieces, name meshes with a `-col` suffix in Blender and Godot
creates trimesh collision on import.

## Playtest

```bash
godot --headless -s tests/playtest.gd
```

Drives the ball through each mechanic and checks: resting on floor, input
direction, speed cap, bumper knock-back, enemy pop, booster jump into the goal.
Add `-- --shots` (without `--headless`) to save screenshots to `tests/shots/`.

Art direction and prompts: [art/STYLE.md](art/STYLE.md).
