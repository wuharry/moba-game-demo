shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 meadow_deep : source_color = vec4(0.21, 0.45, 0.28, 1.0);
uniform vec4 meadow_mid : source_color = vec4(0.34, 0.58, 0.27, 1.0);
uniform vec4 meadow_sun : source_color = vec4(0.54, 0.71, 0.32, 1.0);
uniform vec4 tip_sun : source_color = vec4(0.69, 0.82, 0.38, 1.0);

varying vec3 v_world;
varying float v_tip;
varying float v_gust;
varying float v_var;

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

vec3 eval_meadow_tint(vec2 p, float y_world) {
	float macro_a = field(p * 0.085 + vec2(3.1, -1.7));
	float macro_b = field(p * 0.23 - vec2(4.2, 2.9));
	float patches = macro_a * 0.62 + macro_b * 0.38;
	vec2 wind_plane = vec2(dot(p, vec2(0.85, -0.53)), dot(p, vec2(0.53, 0.85)));
	float ribbon = field(wind_plane * vec2(0.11, 0.24) + vec2(-0.4, 1.8));
	float lush = clamp(patches * 0.68 + ribbon * 0.32 + smoothstep(0.0, 2.8, y_world) * 0.08, 0.0, 1.0);

	vec3 grass = mix(meadow_deep.rgb, meadow_mid.rgb, smoothstep(0.16, 0.58, lush));
	grass = mix(grass, meadow_sun.rgb, smoothstep(0.54, 0.90, lush) * 0.82);
	return grass;
}

void vertex() {
	vec3 world_origin = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind_dir = normalize(vec2(0.85, -0.53));

	// Sweeping Genshin wind waves across the meadow
	float wave_phase = dot(world_origin.xz, wind_dir) * 0.42 - TIME * 1.85 + sin(world_origin.z * 0.35) * 0.6;
	float gust = smoothstep(-0.35, 0.92, sin(wave_phase));
	float flutter = sin(TIME * 3.6 + world_origin.x * 2.3 + world_origin.z * 1.9) * 0.18;

	float h = clamp(UV.y, 0.0, 1.0);
	float bend = h * h;
	vec3 world_disp = vec3(
		wind_dir.x * (0.04 + (gust * 0.19 + flutter * 0.04)) * bend,
		-gust * 0.045 * bend,
		wind_dir.y * (0.04 + (gust * 0.19 + flutter * 0.04)) * bend
	);

	// Apply displacement in model space cleanly (works for both single mesh and MultiMesh!)
	VERTEX += ( inverse(mat3(MODEL_MATRIX)) * world_disp );
	// GDC 2021 Rule: Bend grass vertex normals upward so blades catch clean sky/sun light without black backfaces!
	NORMAL = normalize(inverse(mat3(MODEL_MATRIX)) * normalize(vec3(wind_dir.x * gust * 0.18, 1.0, wind_dir.y * gust * 0.18)));

	v_world = world_origin;
	v_tip = h;
	v_gust = gust * bend;
	v_var = COLOR.r;
}

void fragment() {
	// Root matches underlying terrain macro-tint 100%; upper blade lifts to sunlit chartreuse!
	vec3 root_col = eval_meadow_tint(v_world.xz, v_world.y) * (0.94 + v_var * 0.12);
	vec3 upper_col = mix(root_col * vec3(1.12, 1.18, 0.92), tip_sun.rgb, 0.52 + v_var * 0.22);
	vec3 blade = mix(root_col, upper_col, smoothstep(0.12, 0.92, v_tip));
	// Wind wave sheen ripple across hilltops
	blade += tip_sun.rgb * v_gust * 0.16;

	ALBEDO = blade;
	ROUGHNESS = 0.90;
}

void light() {
	vec3 up_n = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float ndl = max(0.25, dot(up_n, LIGHT));
	float shadow_vis = smoothstep(0.08, 0.86, ATTENUATION);
	float lit = smoothstep(0.15, 0.62, ndl) * shadow_vis;

	vec3 light_energy = LIGHT_COLOR / PI;
	vec3 cool_fill = ALBEDO * vec3(0.04, 0.10, 0.11);
	vec3 sun_col = ALBEDO * vec3(1.07, 1.06, 0.93);
	float sss = pow(max(0.0, dot(VIEW, -LIGHT)), 2.8) * v_tip * (0.25 + 0.75 * shadow_vis);

	DIFFUSE_LIGHT += (mix(cool_fill, sun_col, lit) + tip_sun.rgb * sss * 0.22) * light_energy;
}
