shader_type spatial;

uniform sampler2D stone_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D stone_nh : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.92, 0.86, 0.74, 1.0);
uniform vec4 moss_tint : source_color = vec4(0.32, 0.58, 0.28, 1.0);
uniform float texture_scale = 3.8;
uniform float normal_strength = 0.45;
uniform float rough_base = 0.78;
uniform float metallic_val = 0.0;
uniform float moss_strength = 0.0;
uniform float skirt_blend = 0.0;
uniform float use_triplanar = 1.0;

varying vec3 p_world;
varying vec3 n_world;
varying vec4 v_col;

vec2 mirror_uv(vec2 p) {
	return 1.0 - abs(mod(p, 2.0) - 1.0);
}

vec3 sample_stone(vec2 p) {
	vec2 safe = mirror_uv(p) * 0.976 + 0.012;
	return texture(stone_atlas, vec2(safe.x * 0.5, safe.y)).rgb;
}

void vertex() {
	p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	v_col = COLOR;
}

void fragment() {
	vec3 nw = normalize(n_world);
	vec3 p = p_world / max(0.2, texture_scale);
	vec3 weights = pow(abs(nw), vec3(4.5));
	weights /= max(weights.x + weights.y + weights.z, 0.001);

	vec3 grain = sample_stone(p.zy) * weights.x + sample_stone(p.xz) * weights.y + sample_stone(p.xy) * weights.z;
	vec4 nh = texture(stone_nh, (p.xz * weights.y + p.xy * weights.z + p.zy * weights.x) * 0.85);

	// Blend painted stone grain with clean architectural/rock tint
	vec3 col = mix(tint.rgb, grain * tint.rgb * 1.24, 0.46 * use_triplanar);
	// Vertex color R = baked bevel/edge highlight (>0.5 lifts, <0.5 subtle crevice AO)
	col *= 0.86 + v_col.r * 0.28;

	// Subtle chiselled bevel highlight from normal derivatives
	float curv = clamp(length(fwidth(nw)) * 1.4, 0.0, 1.0);
	col = mix(col, tint.rgb * 1.18 + vec3(0.05), curv * 0.30 * use_triplanar);

	// Optional top-ledge moss & BlendStone ground skirt (v_col.a = skirt mask, v_col.g = moss mask)
	float up = clamp(nw.y, 0.0, 1.0);
	float moss = smoothstep(0.56, 0.88, up * 0.72 + nh.a * 0.28) * moss_strength * v_col.g;
	float skirt = clamp(v_col.a * skirt_blend, 0.0, 1.0);
	float green_mix = clamp(max(moss, skirt * 0.85), 0.0, 1.0);
	col = mix(col, moss_tint.rgb * (0.88 + nh.a * 0.26), green_mix);

	ALBEDO = col;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nh.rgb, normal_strength * (1.0 - green_mix * 0.65));
	NORMAL_MAP_DEPTH = 0.65;
	ROUGHNESS = mix(rough_base, 0.91, green_mix);
	METALLIC = metallic_val * (1.0 - green_mix);
	SPECULAR = mix(0.24, 0.50, metallic_val);
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float shadow_vis = smoothstep(0.10, 0.86, ATTENUATION);
	float lit = smoothstep(0.35, 0.66, ndl) * shadow_vis;

	vec3 light_energy = LIGHT_COLOR / PI;
	float bounce = clamp(1.0 - smoothstep(-0.2, 2.6, p_world.y), 0.0, 1.0) * 0.06;
	vec3 shadow_col = ALBEDO * (vec3(0.06, 0.09, 0.14) + vec3(0.95, 0.82, 0.62) * bounce);
	vec3 sun_col = ALBEDO * vec3(1.02, 0.99, 0.94);

	DIFFUSE_LIGHT += mix(shadow_col, sun_col, lit) * light_energy;

	if (METALLIC > 0.05) {
		vec3 h = normalize(LIGHT + VIEW);
		float spec = pow(max(0.0, dot(NORMAL, h)), mix(24.0, 64.0, 1.0 - ROUGHNESS)) * shadow_vis;
		SPECULAR_LIGHT += ALBEDO * spec * (0.40 + 0.65 * METALLIC) * light_energy;
	}
}
