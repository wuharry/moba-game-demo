shader_type spatial;
render_mode specular_disabled;

uniform vec4 pine_shadow : source_color = vec4(0.24, 0.45, 0.52, 1.0);
uniform vec4 sun_rock : source_color = vec4(0.62, 0.76, 0.66, 1.0);
uniform vec4 valley_floor : source_color = vec4(0.36, 0.62, 0.36, 1.0);
uniform vec4 valley_mist : source_color = vec4(0.74, 0.89, 0.96, 1.0);
uniform float detail_strength = 0.7;
uniform float mist_height = 6.5;
uniform float mist_amount = 0.42;

varying vec3 p;
varying vec3 ground_normal;

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float hash(vec3 q) {
	return fract(sin(dot(q, vec3(127.1, 311.7, 99.2))) * 43758.5453);
}

float field(vec3 pos) {
	vec3 i = floor(pos);
	vec3 f = fract(pos);
	vec3 w = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), w.x),
		mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), w.x), w.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), w.x),
		mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), w.x), w.y), w.z);
}

void fragment() {
	vec3 n = normalize(ground_normal);
	// Crisp sunlit vs shadowed mountain facet separation (Mondstadt / Fontaine alpine look!)
	float sun_face = smoothstep(-0.02, 0.42, dot(n, normalize(vec3(0.48, 0.54, 0.69))));
	float ridge_edge = clamp(length(fwidth(n)) * 2.2, 0.0, 1.0);
	float broad = field(p * vec3(0.08, 0.10, 0.08)) * 0.72 + field(p * 0.25) * 0.28;
	float slope = 1.0 - smoothstep(0.28, 0.84, n.y);
	float strata = field(vec3((p.x + p.z * 0.52) * 0.28, p.y * 0.16, p.z * 0.04));

	float rock_mask = smoothstep(0.30, 0.72, slope * 0.58 + sun_face * 0.26 + strata * 0.28);
	vec3 lit_cliff = sun_rock.rgb * (0.96 + strata * 0.18) + vec3(0.05, 0.05, 0.03) * ridge_edge;
	vec3 cool_slope = pine_shadow.rgb * (0.86 + broad * 0.20);

	vec3 mountain = mix(cool_slope, lit_cliff, clamp(sun_face * 0.78 + rock_mask * 0.34 * detail_strength, 0.0, 1.0));
	// Snow/limestone alpine crest highlight on high peaks
	float crest_hi = smoothstep(10.0, 24.0, p.y) * sun_face * (0.45 + 0.55 * detail_strength);
	mountain = mix(mountain, vec3(0.92, 0.95, 0.94), crest_hi * 0.42);

	// Valley Height-Mist band separating foreground, tier 1, tier 2, and tier 3 peaks!
	float mist_band = (1.0 - smoothstep(-1.5, mist_height, p.y)) * smoothstep(-2.4, 0.8, p.y);
	mountain = mix(mountain, valley_mist.rgb, mist_band * mist_amount);

	float bank = smoothstep(-2.35, 1.35 + (broad - 0.5) * 0.9, p.y);
	ALBEDO = mix(valley_floor.rgb, mountain, bank);
	vec3 bottom_normal = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(bottom_normal, NORMAL, bank));
	ROUGHNESS = 0.95;
}

void light() {
	// Self-contained alpine atmospheric shading so distant peaks don't get harsh dark shadow bands
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	vec3 light_energy = LIGHT_COLOR / PI;
	vec3 col = ALBEDO * mix(vec3(0.68, 0.78, 0.92), vec3(1.04, 1.02, 0.96), smoothstep(0.32, 0.72, ndl));
	DIFFUSE_LIGHT += col * light_energy * 0.86;
}
