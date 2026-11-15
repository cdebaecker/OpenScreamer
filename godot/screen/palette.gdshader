// The PC-98 digital palette.  Everything on the board is drawn in the eight digital colours
// (index = G<<2 | R<<1 | B); this maps each index through the palette registers the game sets,
// so colour tricks (wall colours, flashes, the ending) work on the whole screen like the original.
//
// Presentation options on top (none changes what the game draws): the colours shown for the eight
// indices (colour schemes), smooth palette changes (fade from prev_pal), the modern font's text
// layer composited in (text_tex), and the display style: sharp, CRT (curved glass, scanlines,
// shadow mask, glow), soft (dithering blended like on a TV) or smooth (upscaled: diagonal edges
// between flat areas drawn as slopes, xBR-style, and dithering shown as the colour it mixes).
shader_type canvas_item;

uniform int pal[8];
uniform bool graphics_visible = true;
// fades: the palette before the last change, and how far the change has gone (0..1)
uniform int prev_pal[8];
uniform float fade = 1.0;
// the colours of the eight digital indices (Screen.SCHEMES, set by Screen._update_palette)
uniform vec3 colours[8];
// 0 sharp, 1 CRT, 2 soft, 3 smooth
uniform int style = 0;
// the modern font's text, already in its colours (transparent elsewhere)
uniform sampler2D text_tex : filter_linear;
uniform bool text_on = false;
// the cells of the original font's text (TextLayer.mask), left alone by the smooth style
uniform sampler2D text_mask : filter_nearest;

// a board pixel (as sampled) -> its colour
vec3 board_colour(vec4 c) {
	int idx = (c.b > 0.5 ? 1 : 0) | (c.r > 0.5 ? 2 : 0) | (c.g > 0.5 ? 4 : 0);
	if (!graphics_visible) {
		return colours[0];
	}
	vec3 now = colours[pal[idx]];
	return fade >= 1.0 ? now : mix(colours[prev_pal[idx]], now, fade);
}

// the colour of the board pixel at `cell` (in board pixels)
vec3 cell_colour(sampler2D tex, vec2 cell, vec2 px) {
	return board_colour(texture(tex, (cell + 0.5) * px));
}

bool same(vec3 a, vec3 b) {
	return distance(a, b) < 0.02;
}

// the pixel `e` at `cell` blended with the colour it alternates with along `dir`, if it's in a run
// of four alternating pixels
vec3 undither(sampler2D tex, vec2 cell, vec2 dir, vec2 px, vec3 e, vec3 rgb) {
	vec3 c[7];
	for (int i = 0; i < 7; i++) {
		c[i] = i == 3 ? e : cell_colour(tex, cell + dir * float(i - 3), px);
	}
	for (int j = 0; j < 4; j++) {
		if (!same(c[j], c[j + 1]) && same(c[j], c[j + 2]) && same(c[j + 1], c[j + 3])) {
			return mix(rgb, same(e, c[j]) ? c[j + 1] : c[j], 0.5);
		}
	}
	return rgb;
}

// smooth: each board pixel E is cut at a corner where its two neighbours on that side (B above and
// D left, for the top left) are one colour that also meets E's other neighbours only at that
// corner: an edge going across the corner, drawn as a slope over E's corner instead of a step.
// Lone pixels, lines one pixel wide and dithering (where the neighbours alternate) have no such
// corner, so they keep their shape.  The slope is anti-aliased over one screen pixel.
vec3 smooth_colour(sampler2D tex, vec2 uv, vec2 px) {
	vec2 p = uv / px;
	vec2 cell = floor(p);
	vec2 f = p - cell;
	vec3 e = cell_colour(tex, cell, px);
	if (texture(text_mask, (cell + 0.5) * px).r > 0.5) {
		return e;  // text: the font's own pixels
	}
	vec3 b = cell_colour(tex, cell + vec2(0.0, -1.0), px);
	vec3 d = cell_colour(tex, cell + vec2(-1.0, 0.0), px);
	vec3 fr = cell_colour(tex, cell + vec2(1.0, 0.0), px);
	vec3 h = cell_colour(tex, cell + vec2(0.0, 1.0), px);
	vec3 rgb = e;
	// distance past each corner's cut, and one screen pixel of it (for the anti-aliasing)
	vec2 w = fwidth(p);
	float aa = max(w.x + w.y, 0.0001);
	if (!same(e, b) && !same(e, d) && same(b, d) && !same(b, fr) && !same(d, h)) {
		rgb = mix(rgb, b, smoothstep(aa * 0.5, -aa * 0.5, f.x + f.y - 0.5));
	}
	if (!same(e, b) && !same(e, fr) && same(b, fr) && !same(b, d) && !same(fr, h)) {
		rgb = mix(rgb, b, smoothstep(aa * 0.5, -aa * 0.5, (1.0 - f.x) + f.y - 0.5));
	}
	if (!same(e, h) && !same(e, d) && same(h, d) && !same(h, fr) && !same(d, b)) {
		rgb = mix(rgb, h, smoothstep(aa * 0.5, -aa * 0.5, f.x + (1.0 - f.y) - 0.5));
	}
	if (!same(e, h) && !same(e, fr) && same(h, fr) && !same(h, d) && !same(fr, b)) {
		rgb = mix(rgb, h, smoothstep(aa * 0.5, -aa * 0.5, (1.0 - f.x) + (1.0 - f.y) - 0.5));
	}
	// dithering (two colours alternating pixel by pixel, four pixels in a row at least: stripes and
	// checks) shown as the colour it mixes; a line one pixel wide makes only three.  Not along the
	// columns: lines alternating with gaps are drawings there (letters, hatching), not dithering.
	rgb = undither(tex, cell, vec2(1.0, 0.0), px, e, rgb);
	return rgb;
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
	} else if (style == 3) {
		COLOR = vec4(with_text(smooth_colour(TEXTURE, uv, px), uv), 1.0);
	} else {
		COLOR = vec4(with_text(board_colour(texture(TEXTURE, uv)), uv), 1.0);
	}
}
