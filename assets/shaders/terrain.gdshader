shader_type spatial;
render_mode cull_disabled;

uniform sampler2D rock_tex : source_color, repeat_enable;
uniform sampler2D snow_tex : source_color, repeat_enable;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x);
	float b = mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x);
	return mix(a, b, f.y);
}

void fragment() {
	float snow_mask = clamp(COLOR.r, 0.0, 1.0);
	float slope = clamp(COLOR.g, 0.0, 1.0);
	float altitude = clamp(COLOR.b, 0.0, 1.0);
	vec2 alternate_uv = vec2(UV.y * 0.73 + 0.19, -UV.x * 0.73 + 0.37);
	// Irregular, scale-separated fields break up repetition without the obvious
	// diagonal banding produced by the old sinusoidal strata.
	float macro = value_noise(UV * 1.7 + vec2(8.4, 2.1));
	float middle = value_noise(UV * 6.2 + vec2(23.7, 9.3));
	float grain = value_noise(UV * 28.0 + vec2(4.2, 31.8));
	float tonal = 0.82 + macro * 0.22 + middle * 0.10;
	float fissure = 1.0 - smoothstep(0.08, 0.24, abs(middle - macro * 0.82));
	float fractured_face = smoothstep(0.48, 0.76, macro * 0.58 + middle * 0.42);
	vec3 rock = mix(texture(rock_tex, UV).rgb, texture(rock_tex, alternate_uv).rgb, 0.38) * 0.84 * tonal;
	vec3 snow = mix(texture(snow_tex, UV).rgb, texture(snow_tex, alternate_uv).rgb, 0.34) * 0.91;
	// Broad ridges are rockier; flat high shelves and lee pockets retain snow.
	float accumulation = snow_mask + (macro - 0.5) * 0.22 + (middle - 0.5) * 0.10;
	float snow_coverage = smoothstep(0.05, 0.72, accumulation);
	float high_snow = smoothstep(0.28, 0.78, altitude) * (1.0 - slope * 0.54);
	float snow_detail = texture(snow_tex, UV * 2.2 + vec2(0.17, 0.31)).r;
	float frost_flecks = smoothstep(0.63, 0.91, snow_detail + grain * 0.12);
	snow_coverage = max(snow_coverage * (1.0 - slope * 0.64), high_snow * (0.60 + frost_flecks * 0.28));
	// Steep faces darken and fracture; adjacent broad benches read as shelves.
	float cliff = smoothstep(0.25, 0.82, slope);
	rock *= mix(1.0, 0.72, cliff);
	rock *= 1.0 - fissure * (0.14 + cliff * 0.24);
	rock *= 0.94 + fractured_face * 0.10;
	rock *= 0.92 + grain * 0.12;
	snow *= 0.96 + middle * 0.07;
	ALBEDO = mix(rock, snow, clamp(snow_coverage, 0.0, 1.0));
	ROUGHNESS = mix(0.88, 0.98, snow_coverage);
}
