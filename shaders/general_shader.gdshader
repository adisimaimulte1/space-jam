shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 resolution = vec2(1280.0, 720.0);

uniform float jitter_strength : hint_range(0.0, 0.01) = 0.0007;
uniform float noise_strength : hint_range(0.0, 0.02) = 0.002;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.008;
uniform float chroma_strength : hint_range(0.0, 2.0) = 0.0001;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 sample_screen(vec2 uv) {
	return texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// tiny horizontal VHS wobble
	float jitter = sin(uv.y * 18.0 + t * 6.0) * jitter_strength;
	uv.x += jitter;

	float chroma = chroma_strength / resolution.x;

	vec3 col;
	col.r = sample_screen(uv + vec2(chroma, 0.0)).r;
	col.g = sample_screen(uv).g;
	col.b = sample_screen(uv - vec2(chroma, 0.0)).b;

	// light scanlines
	float scan = sin(uv.y * resolution.y * 3.14159);
	col += scan * scanline_strength * 0.12;

	// tiny analog noise
	float noise = hash21(uv * resolution + floor(t * 24.0));
	col *= 1.0 + (noise - 0.5) * noise_strength;

	COLOR = vec4(col, 1.0);
}