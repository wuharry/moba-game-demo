shader_type spatial;
render_mode diffuse_burley;

uniform vec4 deep_color : source_color = vec4(0.041, 0.117, 0.143, 1.0);
uniform vec4 shelf_color : source_color = vec4(0.119, 0.256, 0.227, 1.0);
uniform vec4 foam_color : source_color = vec4(0.61, 0.72, 0.67, 1.0);
varying vec3 world_position;

float hash21(vec2 at) {
	return fract(sin(dot(at, vec2(129.7, 311.1))) * 34756.51);
}

float patch(vec2 at) {
	vec2 cell = floor(at);
	vec2 r = smoothstep(vec2(0.0), vec2(1.0), fract(at));
	float a = mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), r.x);
	float b = mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), r.x);
	return mix(a, b, r.y);
}

float toward(vec2 p, vec2 a, vec2 b) {
	vec2 line = b - a;
	return length(p - (a + line * clamp(dot(p - a, line) / dot(line, line), 0.0, 1.0)));
}

float shoal_distance(vec2 p) {
	float cliff = min(toward(p, vec2(-6.3, -17.0), vec2(-5.1, -10.0)),
		toward(p, vec2(-5.1, -10.0), vec2(-3.0, -4.3)));
	float quay = min(toward(p, vec2(-5.9, -2.5), vec2(-7.2, -0.2)),
		min(toward(p, vec2(-7.2, -0.2), vec2(-7.5, 3.28)),
			toward(p, vec2(-7.5, 3.28), vec2(-3.2, 6.4))));
	float reach = toward(p, vec2(-3.0, 5.8), vec2(-2.8, 17.5));
	float breakwater = min(toward(p, vec2(-34.0, -22.0), vec2(-26.2, -22.5)),
		toward(p, vec2(-26.2, -22.5), vec2(-13.2, -16.4)));
	float shelf_fore = min(toward(p, vec2(-7.0, 16.6), vec2(-7.6, 13.55)),
		min(toward(p, vec2(-7.6, 13.55), vec2(-6.4, 10.85)),
			toward(p, vec2(-6.4, 10.85), vec2(-6.2, 7.7))));
	float shelf_mid = min(toward(p, vec2(-8.2, -8.9), vec2(-10.5, -12.1)),
		toward(p, vec2(-10.5, -12.1), vec2(-14.6, -19.3)));
	float reef = min(toward(p, vec2(-8.8, 7.9), vec2(-11.63, 3.1)),
		toward(p, vec2(-11.63, 3.1), vec2(-8.47, 0.16)));
	float spit = min(toward(p, vec2(-10.5, -6.1), vec2(-14.38, -11.5)),
		toward(p, vec2(-14.38, -11.5), vec2(-17.9, -17.9)));
	float extension = min(toward(p, vec2(-32.08, -22.2), vec2(-42.0, -22.84)),
		toward(p, vec2(-42.0, -22.84), vec2(-48.08, -25.05)));
	float windward = min(toward(p, vec2(-13.26, -4.16), vec2(-11.76, -2.42)),
		toward(p, vec2(-11.76, -2.42), vec2(-10.06, .23)));
	return min(min(min(cliff, quay), min(min(reach, breakwater), min(shelf_fore, shelf_mid))),
		min(min(reef, spit), min(extension, windward)));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float moment = TIME;
	float warp_a = patch(p * 0.13 + vec2(-moment * 0.04, 0.0));
	float warp_b = patch(p * 0.21 + vec2(19.0, moment * 0.037));
	vec2 flow = p + vec2(warp_a - 0.5, warp_b - 0.5) * 3.16;
	float depth_shifting = patch(flow * vec2(0.24, 0.18) + vec2(moment * 0.053, 4.4));
	float short_ripple = patch(flow * vec2(1.0, 1.46) + vec2(moment * 0.42, -moment * 0.19));
	float swell = sin(dot(flow, vec2(0.61, 0.22)) + warp_b * 3.8 - moment * 0.72);
	float broken = sin(dot(flow, vec2(0.89, -1.43)) + depth_shifting * 5.1 + moment * 1.19);
	float shore = shoal_distance(p);
	float shelf = exp(-shore * 0.26);
	float shore_force = 0.27 + shelf * 0.40;
	float shore_phase = shore * 4.6 - moment * 0.48 + (warp_a - 0.5) * 1.9;
	float wave_face = cos(shore_phase);
	float wind_arc = sin(dot(p, vec2(.36, -.77)) + warp_b * 5.2 - moment * .29);
	float shoal_wind = patch(flow * vec2(0.96, 0.32) + vec2(9.0 + moment * 0.27, -moment * 0.071));
	float water_height = (swell * 0.024 + broken * 0.010 + (short_ripple - 0.5) * 0.018)
		* shore_force;
	float far_ripple = sin(dot(flow, vec2(0.62, 0.84)) + moment * 0.76 + warp_a * 2.26);
	water_height += far_ripple * 0.007 + wave_face * shelf * shelf * .013 + wind_arc * .004;
	vec3 moved = VERTEX + NORMAL * water_height;
	vec3 tilt = normalize(cross(dFdx(moved), dFdy(moved)));
	tilt *= dot(tilt, NORMAL) < 0.0 ? -1.0 : 1.0;
	NORMAL = normalize(mix(NORMAL, tilt, 0.71));
	float contact = exp(-pow((shore - .35 + 0.41 * swell) * 1.14, 2.0));
	float foam_fray = patch(flow * vec2(3.2, 2.1) + vec2(moment * .22, -moment * .12));
	float ripple_foam = smoothstep(0.43, 0.73, depth_shifting * 0.26 + foam_fray * 0.53 + shoal_wind * 0.21);
	float breaker = smoothstep(.82, .995, wave_face) * exp(-shore * .72) * ripple_foam;
	float wash = contact * smoothstep(0.05, 0.79, 0.46 + 0.39 * broken + 0.19 * swell);
	float foam = clamp(wash * ripple_foam * .74 + breaker * .74, 0.0, 1.0);
	vec2 windward = p - vec2(-11.63, -2.27);
	float windward_break = 1.0 - smoothstep(.55, 4.15, length(windward * vec2(1.0, .64)));
	vec2 windward_cross = vec2(.83, .55);
	float seaward = -dot(windward, windward_cross);
	float leeward = smoothstep(.06, 1.48, -seaward) * windward_break;
	float reflected_swell = seaward * 4.25 + warp_b * 3.1 + moment * 1.82;
	float foam_limbs = smoothstep(.43, .69, patch(flow * vec2(1.21, .79) + short_ripple * .14));
	float white_water = smoothstep(.06, 1.0, seaward) * windward_break
		* smoothstep(.38, .92, cos(reflected_swell)) * foam_limbs;
	float dispersing = smoothstep(.44, .89, cos(reflected_swell * 1.9 - swell))
		* windward_break * foam_fray * smoothstep(.24, 1.48, seaward);
	foam = max(foam, clamp(white_water * .66 + dispersing * .29, 0.0, .83));
	float angle = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.1);
	vec3 body = mix(deep_color.rgb, shelf_color.rgb, shelf * (0.59 + depth_shifting * 0.35));
	body *= 0.79 + warp_b * 0.22 + depth_shifting * 0.19 + shoal_wind * 0.08 + far_ripple * 0.025
		+ wind_arc * .035 + wave_face * shelf * .067;
	vec3 reflected = normalize(mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL));
	float sky_break = pow(max(0.0, dot(reflected, normalize(vec3(-.71, .18, -.68)))), 11.0);
	float sky_lacing = exp(-pow((reflected.y - .13 + warp_b * .024) * 3.4, 2.0));
	vec3 cool_sky = mix(vec3(.082, .142, .157), vec3(.235, .268, .247), sky_break * sky_lacing * .67);
	body = mix(body, cool_sky, angle * (.38 + .25 * sky_break));
	body = mix(body, vec3(.079,.167,.145), leeward * .44);
	ALBEDO = mix(body, foam_color.rgb, foam * 0.67);
	ROUGHNESS = 0.34 + short_ripple * 0.10 + foam * 0.19;
	SPECULAR = 0.40;
}
