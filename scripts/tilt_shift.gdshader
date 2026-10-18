shader_type canvas_item;
// Tilt-shift (the miniature look): a sharp band across the screen, more and
// more blur above and below it, plus a little extra colour, contrast and a
// soft vignette. Like a photo of a tiny model taken up close.
// Blur: a golden-angle disc of taps that grows with the distance from the band,
// read from blurrier mip levels where there are any (Forward+), so it stays
// smooth with few taps. Works on the Compatibility renderer too.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float focus = 0.5;        // screen height (0 top, 1 bottom) of the sharp band's centre
uniform float band = 0.09;        // half the height of the sharp band
uniform float ramp = 0.30;        // how far past the band the blur takes to reach full
uniform float max_blur = 14.0;    // blur radius in pixels at 1080 lines
uniform int taps = 20;
uniform float saturation = 1.08;
uniform float contrast = 1.05;
uniform float vignette = 0.16;

vec3 grade(vec3 c, vec2 uv) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	vec2 d = uv - 0.5;
	c *= 1.0 - vignette * smoothstep(0.25, 0.75, dot(d, d) * 2.0);
	return clamp(c, 0.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float away = max(abs(uv.y - focus) - band, 0.0);
	float k = smoothstep(0.0, ramp, away);
	float lines = 1.0 / SCREEN_PIXEL_SIZE.y;
	float px = k * max_blur * lines / 1080.0;   // radius in screen pixels
	vec3 col;
	if (px < 0.35) {
		col = textureLod(screen_tex, uv, 0.0).rgb;
	} else {
		float lod = log2(max(px * 0.35, 1.0));
		vec2 r = px * SCREEN_PIXEL_SIZE;
		// A small blur needs few taps; the full count only far from the band.
		int n = clamp(int(px * 1.5) + 4, 4, taps);
		vec3 sum = vec3(0.0);
		for (int i = 0; i < n; i++) {
			float a = float(i) * 2.39996;
			float d = sqrt((float(i) + 0.5) / float(n));
			sum += textureLod(screen_tex, uv + vec2(cos(a), sin(a)) * d * r, lod).rgb;
		}
		col = sum / float(n);
	}
	COLOR = vec4(grade(col, uv), 1.0);
}
