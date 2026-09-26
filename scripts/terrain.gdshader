shader_type spatial;
// Candy terrain: every 2x2 tile reads as a separate pillowy block (sunken seams
// and rounded edges), ramps are glossy icing, walls are chocolate.
// COLOR.rgb = linear albedo, COLOR.a = pillow amount (0 on icing),
// UV.x = 1 on top surfaces / 0 on walls, UV.y = per-tile random.

render_mode cull_back;

uniform float tile_size = 2.0;
uniform float bevel = 0.3;
uniform float seam_depth = 0.12;

varying vec3 world_pos;
varying float pillow;
varying float is_top;
varying float tile_rand;

float edge_distance(vec2 xz) {
	vec2 local = mod(xz, tile_size);
	vec2 e = min(local, tile_size - local);
	return min(e.x, e.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pillow = COLOR.a;
	is_top = UV.x;
	tile_rand = UV.y;
	// Sink vertices on tile borders to open a seam between tiles.
	float sink = (1.0 - smoothstep(0.0, 0.2, edge_distance(world_pos.xz))) * seam_depth * pillow;
	VERTEX.y -= sink;
}

void fragment() {
	vec3 col = COLOR.rgb * (0.96 + 0.08 * tile_rand);
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float rough = 0.3;
	if (is_top > 0.5) {
		vec2 d = mod(world_pos.xz, tile_size) / tile_size * 2.0 - 1.0;  // -1..1 inside tile
		vec2 edge = (1.0 - abs(d)) * tile_size * 0.5;                   // world units to edge
		vec2 bend = sign(d) * (1.0 - smoothstep(0.0, bevel, edge));
		n_world = normalize(n_world + vec3(bend.x, 0.0, bend.y) * 1.4 * pillow);
		float seam = 1.0 - smoothstep(0.0, 0.06, min(edge.x, edge.y));
		col *= 1.0 - 0.35 * seam * pillow;
		if (pillow < 0.5) {
			// Icing: glossy with a soft wobble.
			float w = sin(world_pos.x * 3.1 + sin(world_pos.z * 2.3) * 1.7) * sin(world_pos.z * 2.7);
			n_world = normalize(n_world + vec3(w * 0.12, 0.0, -w * 0.1));
			rough = 0.12;
		}
	} else {
		// Chocolate walls: faint vertical ripples.
		float r = sin((world_pos.x + world_pos.z) * 6.0) * 0.08;
		n_world = normalize(n_world + vec3(r, 0.0, -r));
		rough = 0.25;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.55;
	CLEARCOAT = 0.8;
	CLEARCOAT_ROUGHNESS = 0.12;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
