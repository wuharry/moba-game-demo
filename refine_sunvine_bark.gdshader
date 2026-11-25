shader_type spatial;
render_mode specular_disabled;

uniform vec4 bark_dark : source_color = vec4(0.24, 0.19, 0.17, 1.0);
uniform vec4 bark_warm : source_color = vec4(0.45, 0.34, 0.25, 1.0);
uniform vec4 root_moss : source_color = vec4(0.28, 0.52, 0.27, 1.0);

varying vec3 p_world;
varying vec3 n_world;
varying float v_height;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	v_height = COLOR.g;
}

void fragment() {
	// Painterly vertical bark striations
	float angle = atan(n_world.z, n_world.x);
	float furrow = noise(vec2(angle * 4.5 + p_world.y * 0.6, p_world.y * 2.2));
	vec3 bark = mix(bark_dark.rgb, bark_warm.rgb, smoothstep(0.25, 0.78, furrow));
	// Subtle moss & ground-tint blend at root base (v_height = 0 at root -> 1 up trunk)
	float root_blend = (1.0 - smoothstep(0.0, 0.24, v_height)) * smoothstep(0.2, 0.85, n_world.y + 0.45);
	bark = mix(bark, root_moss.rgb, root_blend * 0.62);
	// Darker under-canopy AO at top of trunk where boughs meet!
	bark *= mix(1.0, 0.72, smoothstep(0.70, 1.0, v_height));

	ALBEDO = bark;
	ROUGHNESS = 0.92;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float shadow_vis = smoothstep(0.10, 0.86, ATTENUATION);
	float lit = smoothstep(0.38, 0.68, ndl) * shadow_vis;

	vec3 light_energy = LIGHT_COLOR / PI;
	vec3 shadow_col = ALBEDO * vec3(0.06, 0.08, 0.13);
	vec3 sun_col = ALBEDO * vec3(1.06, 1.01, 0.92);
	DIFFUSE_LIGHT += mix(shadow_col, sun_col, lit) * light_energy;
}
