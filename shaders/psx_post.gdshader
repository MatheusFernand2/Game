shader_type canvas_item;
// Pós-processamento estilo PS1/VHS:
// redução de cores com dithering, granulação, vinheta, aberração cromática
// e "glitch" de fita para os sustos.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

// Níveis de cor por canal (menor = mais "PS1").
uniform float color_levels : hint_range(2.0, 64.0) = 20.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;
uniform float grain_amount : hint_range(0.0, 0.5) = 0.07;
uniform float vignette_amount : hint_range(0.0, 2.0) = 0.75;
uniform float scanline_amount : hint_range(0.0, 0.3) = 0.05;
uniform float saturation : hint_range(0.0, 1.5) = 0.75;
uniform float gamma : hint_range(0.5, 2.0) = 1.0;
// Controlados por script:
uniform float fear : hint_range(0.0, 1.0) = 0.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float bayer2(vec2 a) {
	a = floor(a);
	return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// Glitch: faixas horizontais deslocadas.
	if (glitch > 0.0) {
		float band = floor(uv.y * 40.0 + floor(t * 30.0) * 7.0);
		float n = hash(vec2(band, floor(t * 24.0)));
		if (n < glitch * 0.6) {
			uv.x += (hash(vec2(band, t)) - 0.5) * 0.12 * glitch;
		}
	}

	// Aberração cromática cresce com medo e glitch.
	float ca = 0.0012 + fear * 0.004 + glitch * 0.012;
	vec2 dir = (uv - 0.5);
	vec3 col;
	col.r = texture(screen_tex, uv + dir * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * ca).b;

	// Saturação baixa = clima de morte.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = pow(max(col, vec3(0.0)), vec3(1.0 / gamma));

	// Granulação.
	float g = hash(FRAGCOORD.xy + fract(t * 13.7) * 100.0) - 0.5;
	col += g * grain_amount * (1.0 + glitch * 2.0);

	// Scanlines.
	col *= 1.0 - scanline_amount * step(0.5, fract(FRAGCOORD.y * 0.5));

	// Vinheta (aperta com o medo e "pulsa" com o coração).
	float pulse = fear * (0.5 + 0.5 * sin(t * (6.0 + fear * 6.0)));
	float d = length(dir * vec2(1.0, 0.8));
	float vig = 1.0 - smoothstep(0.2 - pulse * 0.08, 0.85, d * (vignette_amount + fear * 0.5));
	col *= vig;

	// Redução de cores com dithering ordenado.
	float threshold = (bayer4(FRAGCOORD.xy) - 0.5) * dither_strength;
	col = floor(col * color_levels + 0.5 + threshold) / color_levels;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
