shader_type sky;
// Soft candy gradient: baby blue at the top of the screen, pink at the bottom.

uniform vec4 top_color : source_color = vec4(0.72, 0.87, 0.96, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.98, 0.80, 0.88, 1.0);

void sky() {
	float t = clamp(SCREEN_UV.y, 0.0, 1.0);
	COLOR = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, t));
}
