// The PC-98 digital palette.  Everything on the board is drawn in the eight digital colours
// (index = G<<2 | R<<1 | B); this maps each index through the palette registers the game sets,
// so colour tricks (wall colours, flashes, the ending) work on the whole screen like the original.
//
// Presentation options on top (none changes what the game draws): the colours shown for the eight
// indices (colour schemes), smooth palette changes (fade from prev_pal), the modern font's text
// layer composited in (text_tex), and the display style: sharp, CRT (curved glass, scanlines,
// shadow mask, glow) or soft (dithering blended like on a TV).
shader_type canvas_item;

uniform int pal[8];
uniform bool graphics_visible = true;
// fades: the palette before the last change, and how far the change has gone (0..1)
uniform int prev_pal[8];
uniform float fade = 1.0;
// the colours of the eight digital indices (Screen.SCHEMES, set by Screen._update_palette)
uniform vec3 colours[8];
// 0 sharp, 1 CRT, 2 soft
uniform int style = 0;
// the modern font's text, already in its colours (transparent elsewhere)
uniform sampler2D text_tex : filter_linear;
uniform bool text_on = false;

// a board pixel (as sampled) -> its colour
vec3 board_colour(vec4 c) {
	int idx = (c.b > 0.5 ? 1 : 0) | (c.r > 0.5 ? 2 : 0) | (c.g > 0.5 ? 4 : 0);
	if (!graphics_visible) {
		return colours[0];
	}
	vec3 now = colours[pal[idx]];
	return fade >= 1.0 ? now : mix(colours[prev_pal[idx]], now, fade);
}

vec3 with_text(vec3 rgb, vec2 uv) {
	if (text_on) {
		vec4 t = texture(text_tex, uv);
		rgb = mix(rgb, t.rgb / max(t.a, 0.001), t.a);
	}
	return rgb;
}

void fragment() {
	vec2 uv = UV;
	vec2 px = TEXTURE_PIXEL_SIZE;  // one board pixel (1/640, 1/200)
	vec3 rgb;
	if (style == 1) {
		// curved glass
		vec2 cc = uv * 2.0 - 1.0;
		cc *= 1.0 + 0.035 * vec2(cc.y * cc.y, cc.x * cc.x);
		uv = cc * 0.5 + 0.5;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			rgb = with_text(board_colour(texture(TEXTURE, uv)), uv);
			// glow: a little of the neighbours bleeds in
			vec3 glow = board_colour(texture(TEXTURE, uv + vec2(px.x, 0.0))) + board_colour(texture(TEXTURE, uv - vec2(px.x, 0.0)))
					+ board_colour(texture(TEXTURE, uv + vec2(0.0, px.y))) + board_colour(texture(TEXTURE, uv - vec2(0.0, px.y)));
			rgb = rgb + glow * 0.06;
			// each board line is two display lines: the beam, then a darker gap
			float line = fract(uv.y / px.y);
			rgb *= mix(1.08, 0.5, smoothstep(0.35, 0.85, line));
			// shadow mask: red, green, blue stripes across the screen's pixels
			int m = int(mod(FRAGCOORD.x, 3.0));
			vec3 mask = m == 0 ? vec3(1.0, 0.82, 0.82) : m == 1 ? vec3(0.82, 1.0, 0.82) : vec3(0.82, 0.82, 1.0);
			rgb *= mask;
			// darker corners
			float v = 1.0 - 0.25 * dot(cc * cc, vec2(0.5));
			COLOR = vec4(clamp(rgb * v, 0.0, 1.0), 1.0);
		}
	} else if (style == 2) {
		// soft: blend each pixel with its neighbours, so dithering mixes into colours
		rgb = board_colour(texture(TEXTURE, uv)) * 0.5
				+ (board_colour(texture(TEXTURE, uv + vec2(px.x, 0.0))) + board_colour(texture(TEXTURE, uv - vec2(px.x, 0.0)))) * 0.2
				+ (board_colour(texture(TEXTURE, uv + vec2(0.0, px.y))) + board_colour(texture(TEXTURE, uv - vec2(0.0, px.y)))) * 0.05;
		COLOR = vec4(with_text(rgb, uv), 1.0);
	} else {
		COLOR = vec4(with_text(board_colour(texture(TEXTURE, uv)), uv), 1.0);
	}
}
