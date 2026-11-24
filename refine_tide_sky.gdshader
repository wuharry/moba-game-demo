shader_type sky;

uniform vec4 blue_zenith : source_color = vec4(.21,.34,.49,1.0);
uniform vec4 low_mist : source_color = vec4(.42,.53,.61,1.0);
uniform vec4 overcast : source_color = vec4(.28,.39,.51,1.0);
uniform vec4 silver : source_color = vec4(.82,.75,.62,1.0);

void sky() {
	vec3 d = normalize(EYEDIR);
	float height = d.y;
	float lateral = dot(d, vec3(.82, 0.0, -.59));
	float center = .165 + .043 * sin(lateral * 11.0 + 1.3) + .023 * sin(lateral * 21.5);
	float ridge = (height - center) * 6.8;
	float high_ridge = (height - .40 + .09 * sin(lateral * 4.4)) * 4.8;
	float passage = sin(lateral * 19.9 + height * 28.9 + .7 * sin(lateral * 23.4 - height * 13.0));
	float feather = .65 + .24 * passage + .11 * sin(lateral * 36.2 - height * 60.7);
	float cloud = exp(-ridge * ridge) * feather * .59 + exp(-high_ridge * high_ridge) * (1.0 - feather) * .63;
	float daylight = pow(max(dot(d, normalize(vec3(-.77, .13, -.62))), 0.0), 15.0);
	float glow_line = exp(-height * height * 33.2);
	vec3 base = mix(low_mist.rgb, blue_zenith.rgb, smoothstep(-.07, .53, height));
	vec3 airborne = mix(overcast.rgb, silver.rgb, .13 + daylight * .60);
	vec3 horizon = silver.rgb * daylight * glow_line * .23;
	COLOR = mix(base + horizon, airborne + horizon, clamp(cloud, 0.0, .77));
}
