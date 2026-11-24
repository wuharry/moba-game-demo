shader_type sky;

uniform vec4 zenith : source_color = vec4(0.12, 0.20, 0.32, 1.0);
uniform vec4 horizon : source_color = vec4(0.60, 0.70, 0.72, 1.0);
uniform vec4 overcast : source_color = vec4(0.31, 0.40, 0.50, 1.0);
uniform vec4 opening : source_color = vec4(0.82, 0.79, 0.66, 1.0);
uniform vec3 key_direction = vec3(-0.68, 0.35, -0.64);
uniform bool clearing = false;

float lump(vec2 p) {
	return fract(sin(dot(p, vec2(121.7, 71.28))) * 15345.52314);
}

float grain(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(lump(i), lump(i + vec2(1, 0)), u.x),
		mix(lump(i + vec2(0, 1)), lump(i + vec2(1)), u.x), u.y);
}

float cloud_field(vec2 uv) {
	return .57 * grain(uv) + .24 * grain(uv * 2.01 + 19.1) +
		.12 * grain(uv * 4.13 + 23.5) + .07 * grain(uv * 8.15);
}

void sky() {
	float height = max(0.0, EYEDIR.y);
	vec3 basic = mix(horizon.rgb, zenith.rgb, smoothstep(-0.07, 0.75, EYEDIR.y));
	vec2 cloud_uv = EYEDIR.xz / max(0.25, height + 0.33);
	cloud_uv = cloud_uv * vec2(2.34, 3.54) + vec2(1.73, 8.49);
	float field = cloud_field(cloud_uv);
	float bank = smoothstep(0.38, 0.73, field) * smoothstep(0.0, .19, height);
	float diffuse_opening = pow(clamp(dot(EYEDIR, normalize(key_direction)), 0.0, 1.0), 14.0);
	vec3 body = mix(overcast.rgb, horizon.rgb, smoothstep(.43, .65, field) * 0.41);
	COLOR = mix(basic, body, bank * .87) + opening.rgb * diffuse_opening * 0.29;
	if (clearing) {
		vec3 ray = normalize(EYEDIR);
		vec2 atlas = ray.xz / max(.19, height + .23);
		float wind_shelf = cloud_field(atlas * vec2(1.41, 2.23) + vec2(2.43, 6.81));
		float high_shelf = smoothstep(.38,.73, wind_shelf) * smoothstep(.08,.27, height);
		float broad_light = pow(max(0.0,dot(ray, normalize(vec3(-.44, .30, -.81)))), 16.0);
		float skyline = smoothstep(.01,.20,height) * (1.0 - smoothstep(.23,.52,height));
		COLOR = mix(COLOR, vec3(.21, .31, .42), high_shelf * .46);
		COLOR += vec3(.32, .25, .15) * skyline * broad_light * smoothstep(.47,.81,1.0 - wind_shelf);
	}
}
