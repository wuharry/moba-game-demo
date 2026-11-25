shader_type spatial;

uniform sampler2D stone_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D ground_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D stone_nh : filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 meadow_deep : source_color = vec4(0.21, 0.45, 0.28, 1.0);
uniform vec4 meadow_mid : source_color = vec4(0.34, 0.58, 0.27, 1.0);
uniform vec4 meadow_sun : source_color = vec4(0.54, 0.71, 0.32, 1.0);
uniform vec4 stone_cream : source_color = vec4(0.90, 0.84, 0.71, 1.0);
uniform vec4 stone_warm : source_color = vec4(0.83, 0.74, 0.58, 1.0);
uniform vec4 mortar_col : source_color = vec4(0.56, 0.51, 0.43, 1.0);

varying vec3 p_world;
varying vec3 masks;
varying vec3 n_world;
varying float v_is_path;

float rand2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float field(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rand2(i), rand2(i + vec2(1.0, 0.0)), f.x),
		mix(rand2(i + vec2(0.0, 1.0)), rand2(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 texture_cell(vec2 p, vec2 quadrant) {
	vec2 safe = (1.0 - abs(mod(p, 2.0) - 1.0)) * 0.973 + 0.0135;
	return texture(ground_atlas, (quadrant + safe) * 0.5).rgb;
}

// Shared macro-tint meadow function (also matched by refine_sunvine_meadow.gdshader!)
vec3 eval_meadow_tint(vec2 p, float up, float y_world) {
	float macro_a = field(p * 0.085 + vec2(3.1, -1.7));
	float macro_b = field(p * 0.23 - vec2(4.2, 2.9));
	float patches = macro_a * 0.62 + macro_b * 0.38;
	vec2 wind_plane = vec2(dot(p, vec2(0.85, -0.53)), dot(p, vec2(0.53, 0.85)));
	float ribbon = field(wind_plane * vec2(0.11, 0.24) + vec2(-0.4, 1.8));
	float lush = clamp(patches * 0.68 + ribbon * 0.32 + smoothstep(0.0, 2.8, y_world) * 0.08, 0.0, 1.0);

	vec3 grass = mix(meadow_deep.rgb, meadow_mid.rgb, smoothstep(0.16, 0.58, lush));
	grass = mix(grass, meadow_sun.rgb, smoothstep(0.54, 0.90, lush) * 0.82 * smoothstep(0.65, 0.96, up));
	return grass;
}

void vertex() {
	p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	masks = COLOR.rgb;
	n_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	v_is_path = masks.r;
}

void fragment() {
	vec2 p = p_world.xz;
	float up = clamp(normalize(n_world).y, 0.0, 1.0);

	// 1. Genshin Macro-Tinted Meadow Turf
	vec3 grass = eval_meadow_tint(p, up, p_world.y);
	vec3 meadow_paint = mix(
		texture_cell(p * 0.26, vec2(1.0, 0.0)),
		texture_cell(p.yx * 0.31 + vec2(1.42, 0.0), vec2(1.0, 0.0)),
		field(p * 0.42)
	);
	float paint_luma = dot(meadow_paint, vec3(0.299, 0.587, 0.114));
	grass *= 0.86 + paint_luma * 0.34;

	// Steep slope limestone/chalk exposure on outer hillsides
	float slope_rock = smoothstep(0.76, 0.42, up) * (1.0 - smoothstep(0.15, 0.55, masks.r));
	vec3 cliff_tex = texture_cell(p * 0.24, vec2(1.0, 1.0)) * vec3(0.92, 0.88, 0.75);
	grass = mix(grass, cliff_tex, slope_rock * 0.72);

	// Warm sandy pond beach rim
	vec3 beach_sand = mix(stone_warm.rgb, stone_cream.rgb, 0.55) * (0.90 + field(p * 3.2) * 0.14);
	grass = mix(grass, beach_sand, smoothstep(0.38, 0.86, masks.b) * 0.78);

	// Subtle orchard footpath warm earth-stone
	float orchard_wear = smoothstep(0.35, 0.85, masks.g) * (1.0 - smoothstep(0.45, 0.85, masks.r));
	grass = mix(grass, stone_warm.rgb * 0.76, orchard_wear * 0.45);

	// 2. Fontaine / Mondstadt Carved Ashlar Flagstone Paving
	vec2 laid = vec2(p.x * 1.18 + 0.18 * sin(p.y * 0.35), p.y * 1.28);
	float row_id = floor(laid.y);
	laid.x += fract(row_id * 0.5 + rand2(vec2(row_id, 7.0)) * 0.25);
	vec2 warp = (vec2(field(p * 2.4), field(p * 2.4 + vec2(13.7, 5.1))) - 0.5) * 0.09;
	vec2 cell_id = floor(laid + warp);
	vec2 cell_uv = fract(laid + warp);
	vec2 edge_d = abs(cell_uv - 0.5);
	float bevel_dist = max(edge_d.x, edge_d.y);
	float mortar_mask = smoothstep(0.455, 0.492, bevel_dist);
	float stone_bevel_hi = smoothstep(0.41, 0.452, bevel_dist) * (1.0 - mortar_mask);

	vec4 nh = texture(stone_nh, p * 0.28 + cell_id * 0.17);
	vec3 sand_paint = texture_cell(p * 0.36, vec2(1.0, 1.0));
	float tile_var = rand2(cell_id);
	vec3 flagstone = mix(stone_warm.rgb, stone_cream.rgb, 0.35 + 0.55 * tile_var);
	flagstone = mix(flagstone, sand_paint * 1.18, 0.38);
	flagstone += vec3(0.06, 0.055, 0.04) * stone_bevel_hi;

	// Soft worn center on main courtyard thoroughfare, crisper joints toward borders
	float center_wear = smoothstep(0.75, 0.98, masks.r) * 0.38;
	vec3 paving = mix(flagstone, mortar_col.rgb, mortar_mask * (0.48 - center_wear * 0.45));

	// 3. Height-Lerp Transition (grass tufts creep into stone joints at road borders!)
	float grass_height = 0.35 + field(p * 4.6) * 0.42 + mortar_mask * 0.32;
	float stone_height = masks.r * 1.22 + nh.a * 0.16 - 0.12;
	float path_blend = smoothstep(-0.09, 0.09, stone_height - grass_height * (1.0 - smoothstep(0.68, 0.95, masks.r)));

	ALBEDO = mix(grass, paving, path_blend);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), nh.rgb, path_blend * 0.48 + slope_rock * 0.35);
	NORMAL_MAP_DEPTH = 0.65;
	ROUGHNESS = mix(0.91, 0.74, path_blend);
	SPECULAR = mix(0.10, 0.20, path_blend);
}

void light() {
	float ndl = max(0.0, dot(NORMAL, LIGHT));
	float shadow_vis = smoothstep(0.08, 0.86, ATTENUATION);
	float lit = smoothstep(0.06, 0.52, ndl) * shadow_vis;

	vec3 light_energy = LIGHT_COLOR / PI;
	vec3 cool_fill = mix(vec3(0.04, 0.10, 0.11), vec3(0.06, 0.08, 0.13), clamp(v_is_path, 0.0, 1.0)) * ALBEDO;
	vec3 sun_col = ALBEDO * mix(vec3(1.06, 1.05, 0.94), vec3(1.02, 0.99, 0.94), clamp(v_is_path, 0.0, 1.0));

	DIFFUSE_LIGHT += mix(cool_fill, sun_col, lit) * light_energy;
}
