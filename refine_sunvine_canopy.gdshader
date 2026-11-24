shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform sampler2D ground_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
instance uniform float exposure = 0.0;
varying vec3 world_position;
varying vec3 world_normal;

vec3 leaf_ink(vec2 p) {
	vec2 uv = (1.0 - abs(mod(p, 2.0) - 1.0)) * 0.97 + 0.015;
	return texture(ground_atlas, vec2(0.5, 0.0) + uv * 0.5).rgb;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = world_position * 0.82;
	vec3 weights = abs(normalize(world_normal));
	weights = pow(weights, vec3(3.0));
	weights /= max(0.001, weights.x + weights.y + weights.z);
	vec3 detail = leaf_ink(p.zy) * weights.x + leaf_ink(p.xz) * weights.y + leaf_ink(p.xy) * weights.z;
	float paint = clamp(dot(detail, vec3(.42, .48, .1)) * 2.0, .12, .93);
	vec3 broad_position = p * 1.67 + vec3(7.2, 8.1, 3.7);
	vec3 broad_detail = leaf_ink(broad_position.zy) * weights.x + leaf_ink(broad_position.xz) * weights.y + leaf_ink(broad_position.xy) * weights.z;
	float veins = smoothstep(.23, .58, dot(broad_detail, vec3(.33, .47, .20))) * .16;
	vec3 base_color = pow(max(COLOR.rgb, vec3(.0)), vec3(2.2));
	float pigment = dot(base_color, vec3(.2126, .7152, .0722));
	vec3 highland_green = pigment * mix(vec3(.76, 1.16, .70), vec3(.89, 1.09, .83), paint);
	base_color = mix(base_color, highland_green, exposure * .59);
	float leaf_exposure = dot(normalize(world_normal), normalize(vec3(.62,.77,.36))) * .5 + .5;
	ALBEDO = base_color * (0.65 + paint * .44 + veins + leaf_exposure * .13);
	ALBEDO = mix(ALBEDO * vec3(.86, .96, 1.05), ALBEDO, smoothstep(.06, .70, leaf_exposure));
	BACKLIGHT = base_color * .12;
	ROUGHNESS = .92;
}
