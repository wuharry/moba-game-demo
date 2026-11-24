shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled, alpha_to_coverage;

uniform sampler2D plant_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 quadrant = vec2(0.0);
uniform vec4 foliage_tint : source_color = vec4(1.0);
varying vec3 base_position;

void vertex() {
	base_position = MODEL_MATRIX[3].xyz;
	VERTEX.x += sin(TIME * 1.15 + base_position.x * .41 + base_position.z) * 0.042 * (1.0 - UV.y);
}

void fragment() {
	vec2 cell = clamp(UV, vec2(0.006), vec2(0.994));
	vec4 ink = texture(plant_atlas, (quadrant + cell) * 0.5);
	ALBEDO = ink.rgb * foliage_tint.rgb;
	ALPHA = ink.a;
	ALPHA_SCISSOR_THRESHOLD = 0.68;
	ALPHA_ANTIALIASING_EDGE = 0.28;
	ROUGHNESS = 0.94;
}
