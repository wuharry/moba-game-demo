shader_type sky;

uniform vec4 blue : source_color = vec4(0.10, 0.41, 0.73, 1.0);
uniform vec4 mist : source_color = vec4(0.48, 0.71, 0.79, 1.0);
uniform vec4 cloud_base : source_color = vec4(0.92, 0.87, 0.75, 1.0);
uniform vec4 cloud_top : source_color = vec4(0.98, 0.95, 0.82, 1.0);

float cloud_lobe(vec3 direction, vec3 heading, vec2 radius) {
	vec3 tangent = normalize(cross(heading, vec3(0, 1, 0)));
	vec3 vertical = cross(tangent, heading);
	vec2 uv = vec2(dot(direction, tangent), dot(direction, vertical));
	float dist = length(uv / radius);
	return (1.0 - smoothstep(.53, 1.12, dist)) * smoothstep(.3, 1., dot(direction, heading));
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float y = max(0.0, direction.y);
	vec3 color = mix(mist.rgb, blue.rgb, smoothstep(0.005, 0.68, y));
	float large = cloud_lobe(direction, normalize(vec3(-.40, .24, -.89)), vec2(.42, .07));
	large = max(large, cloud_lobe(direction, normalize(vec3(-.27, .29, -.92)), vec2(.26, .08)));
	large = max(large, cloud_lobe(direction, normalize(vec3(-.47, .31, -.91)), vec2(.16, .085)));
	float wisps = cloud_lobe(direction, normalize(vec3(.59, .42, -.72)), vec2(.38, .05));
	wisps = max(wisps, cloud_lobe(direction, normalize(vec3(.73, .43, -.63)), vec2(.18, .078)));
	float cover = max(large * .75, wisps * .65) * smoothstep(.06, .24, y);
	color = mix(color, mix(cloud_base.rgb, cloud_top.rgb, smoothstep(.24, .40, y)), cover);
	COLOR = color;
}
