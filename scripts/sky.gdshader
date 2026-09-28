shader_type sky;
// Soft candy gradient: baby blue at the top of the screen, pink at the bottom.

uniform vec4 top_color : source_color = vec4(0.72, 0.87, 0.96, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.98, 0.80, 0.88, 1.0);

void sky() {
	float t = clamp(SCREEN_UV.y, 0.0, 1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// The web renderer gives one SCREEN_UV for the whole sky (a flat colour,
	// and a flat reflection on every glossy tile). Blue above the horizon,
	// pink below, like Forward+ ends up with. The sky you see there is a
	// gradient card in front of this (Settings.match_renderer).
	t = clamp(0.5 - EYEDIR.y * 0.5, 0.0, 1.0);
#endif
	COLOR = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, t));
}
