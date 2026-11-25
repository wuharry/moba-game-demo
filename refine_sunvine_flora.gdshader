shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D plant_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 quadrant = vec2(1.0, 1.0);
uniform vec4 base_tint : source_color = vec4(0.26, 0.56, 0.28, 1.0);
uniform vec4 tip_tint : source_color = vec4(0.62, 0.82, 0.34, 1.0);

varying vec3 v_world;
varying float v_h;

void vertex() {
	vec3 base_pos = MODEL_MATRIX[3].xyz;
	float h = 1.0 - clamp(UV.y, 0.0, 1.0);
	float sway = sin(TIME * 1.45 + base_pos.x * 0.52 + base_pos.z * 0.61) * 0.055 * h * h;
	VERTEX.x += sway;
	// Bend normals upward so shrub cards never show dark cross-plane seams!
	NORMAL = normalize(inverse(mat3(MODEL_MATRIX)) * vec3(0.0, 1.0, 0.0));
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_h = h;
}

void fragment() {
	vec2 cell = clamp(UV, vec2(0.012), vec2(0.988));
	vec4 ink = texture(plant_atlas, (quadrant + cell) * 0.5);
	ALPHA = ink.a;
	ALPHA_SCISSOR_THRESHOLD = 0.48;

	float val = clamp((ink.g - 0.55) / 0.45, 0.0, 1.0);
	vec3 col = mix(base_tint.rgb, tip_tint.rgb, clamp(v_h * 0.68 + val * 0.36, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.90;
}

void light() {
	vec3 up_n = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float ndl = max(0.25, dot(up_n, LIGHT));
	float shadow_vis = smoothstep(0.10, 0.86, ATTENUATION);
	float lit = smoothstep(0.18, 0.65, ndl) * shadow_vis;

	vec3 light_energy = LIGHT_COLOR / PI;
	vec3 shadow_col = ALBEDO * vec3(0.05, 0.10, 0.11);
	vec3 sun_col = ALBEDO * vec3(1.05, 1.04, 0.93);
	float sss = pow(max(0.0, dot(VIEW, -LIGHT)), 2.8) * v_h * 0.22 * shadow_vis;
	DIFFUSE_LIGHT += (mix(shadow_col, sun_col, lit) + tip_tint.rgb * sss) * light_energy;
}
