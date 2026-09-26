# Art bible

Reference images live in `art/reference/`. Attach `01-style-island.webp` and
`02-tile-kit.png` to every Nano Banana Pro prompt.

## Style block (paste at the top of every prompt)

```
STYLE: Match the reference images exactly. Opaque soft-touch vinyl / candy clay
material, like designer toys or Animal Crossing furniture. Smooth satin gloss
with one soft highlight, NOT glass, NOT transparent, NOT jelly, NO chrome,
NO metal, NO neon, NO emissive glow. Chunky rounded bevels on every edge,
simple primitive shapes, no fine detail. Pastel palette from the reference.
Soft studio light, soft contact shadow, plain off-white background.
Orthographic isometric view. No text, no labels.
```

## Color roles

| Role | Asset | Color |
|---|---|---|
| Player | Peppermint ball, two swirls | White + raspberry stripe |
| Danger | Wind-up spiky block | Raspberry `#C8204F` |
| Interactive | Pop bumper, booster pad | Lemon `#F6E27A`, coral `#F6845E` |
| World | Tile kit, hills, trenches | Mint `#A8E6C8`, pink `#F7B2C0`, lilac `#C9B8EC`, sky `#A9D6F5` |
| Goal | Sunken cup with flag | Pink + cream + lemon flag |
| Decoration | Gummy bear, lollipops, cotton-candy trees | Pastels, never on the track |

Raspberry is reserved for danger. Nothing friendly may use it.

## Modeling notes

- Bevel modifier on everything, flat colors, no textures.
- Booster is flush with the floor. Goal cup is sunken into a floor tile.
- Keep colliders simple: bumper = cylinder as wide as the cap.

## In-game look (current target)

Peter's Nano Banana restyle of the greybox set the direction:

- Every 2x2 tile is its own pillowy block with deep seams (terrain shader).
- Island sides are chocolate cake, ramps are glossy lemon icing that drips
  over the edges.
- Blue to pink gradient sky, clouds under the islands, floating candy scenery
  (rainbow, islets, balloons, castle...) far below the play area.
- Marble Madness references: wavy ground tiles (`W`), long rail-less
  walkways, stacked platforms with drops.
