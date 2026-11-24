shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

varying float gust;

void vertex() {
	vec2 position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 wind = normalize(vec2(.85, -.53));
	float phase = dot(position, wind) * .63 - TIME * 1.72;
	float swell = sin(phase + sin(position.y * .46) * .36);
	float pulse = smoothstep(-.45, .92, swell);
	float tips = UV.y * UV.y;
	VERTEX.xz += wind * (.026 + pulse * .14) * tips;
	VERTEX.y -= pulse * .034 * tips;
	gust = pulse * tips;
}

void fragment() {
	vec3 leaf = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = leaf * (.94 + gust * .24);
	BACKLIGHT = leaf * (.11 + gust * .08);
	ROUGHNESS = .94;
}
