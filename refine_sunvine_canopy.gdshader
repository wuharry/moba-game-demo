shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;

uniform sampler2D foliage_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 shadow_cool : source_color = vec4(0.14, 0.34, 0.31, 1.0);
uniform vec4 mid_leaf : source_color = vec4(0.30, 0.55, 0.26, 1.0);
uniform vec4 sun_bright : source_color = vec4(0.60, 0.77, 0.33, 1.0);
uniform vec4 sss_tint : source_color = vec4(0.78, 0.89, 0.45, 1.0);
instance uniform float exposure = 0.0;

varying vec4 v_data;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float flex = COLOR.a;
	float gust_phase = dot(world_pos.xz, vec2(0.55, -0.38)) - TIME * 1.65;
	float sway = sin(gust_phase) * 0.070 + sin(TIME * 3.4 + world_pos.x * 1.9 + world_pos.y * 2.3) * 0.018;
	VERTEX.xz += vec2(0.85, -0.53) * sway * flex;
	VERTEX.y += cos(gust_phase * 1.3) * 0.014 * flex;
	v_data = COLOR;
}

void fragment() {
	vec4 tex = texture(foliage_atlas, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.44;
	ALPHA_ANTIALIASING_EDGE = 0.24;

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}

	// Smooth painterly radial value without harsh per-card stipple
	float leaf_val = clamp((tex.g - 0.60) / 0.40, 0.0, 1.0);
	float core_ao = v_data.r;
	float crown_h = v_data.g;
	float card_var = v_data.b;

	float tone = clamp(core_ao * 0.52 + crown_h * 0.34 + leaf_val * 0.18 + (card_var - 0.5) * 0.07 - exposure * 0.04, 0.0, 1.0);
	vec3 base = mix(shadow_cool.rgb, mid_leaf.rgb, smoothstep(0.08, 0.54, tone));
	base = mix(base, sun_bright.rgb, smoothstep(0.52, 0.94, tone) * 0.68);

	ALBEDO = base;
	ROUGHNESS = 0.88;
	SPECULAR = 0.05;
	AO = mix(0.66, 1.0, core_ao);
	AO_LIGHT_AFFECT = 0.32;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float shadow_vis = smoothstep(0.12, 0.82, ATTENUATION);
	float wrap = smoothstep(0.30, 0.68, ndl) * (0.24 + 0.76 * shadow_vis);
	float sun_cap = smoothstep(0.58, 0.84, ndl) * shadow_vis;

	vec3 light_energy = LIGHT_COLOR / PI;
	vec3 warm_lit = mix(ALBEDO, sun_bright.rgb, 0.26 * sun_cap + 0.12 * v_data.g);
	vec3 cool_wrap = shadow_cool.rgb * 0.10 * (1.0 - wrap);

	float sss = pow(max(0.0, dot(VIEW, -LIGHT)), 3.0) * (0.35 + 0.65 * v_data.r) * (0.35 + 0.65 * shadow_vis);
	vec3 trans = sss_tint.rgb * sss * 0.28;

	DIFFUSE_LIGHT += (cool_wrap + warm_lit * wrap * 0.94 + trans) * light_energy;
}
