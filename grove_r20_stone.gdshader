shader_type spatial;

uniform sampler2D stone_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float atlas_half = 0.0;
uniform float texture_scale = 3.7;
uniform float micro_relief = 0.013;
uniform float rough_low = 0.68;
uniform float rough_high = 0.94;
varying vec3 p_world;
varying vec3 n_world;

vec2 mirror_uv(vec2 p) {
	return 1.0 - abs(mod(p, 2.0) - 1.0);
}

vec3 sample_stone(vec2 p) {
	vec2 safe = mirror_uv(p) * 0.978 + 0.011;
	return texture(stone_atlas, vec2(atlas_half * 0.5 + safe.x * 0.5, safe.y), 1.2).rgb;
}

void vertex() {
	p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_world = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 p = p_world / texture_scale;
	vec3 weights = pow(abs(normalize(n_world)), vec3(5.0));
	weights /= max(weights.x + weights.y + weights.z, 0.001);
	vec3 grain = sample_stone(p.zy) * weights.x
		+ sample_stone(p.xz) * weights.y
		+ sample_stone(p.xy) * weights.z;
	grain = mix(vec3(.47,.49,.46), grain, .56);
	float relief = dot(grain, vec3(0.2126, 0.7152, 0.0722));
	vec3 displaced = VERTEX + NORMAL * (relief * micro_relief);
	vec3 gradient = normalize(cross(dFdx(displaced), dFdy(displaced)));
	if (dot(gradient, NORMAL) < 0.0) {
		gradient = -gradient;
	}
	NORMAL = normalize(mix(NORMAL, gradient, 0.16));
	ALBEDO = grain * tint.rgb * COLOR.rgb;
	ROUGHNESS = mix(rough_high, rough_low, smoothstep(0.08, 0.72, relief));
	SPECULAR = 0.19;
}
