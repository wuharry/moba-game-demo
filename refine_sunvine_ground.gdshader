shader_type spatial;

uniform sampler2D stone_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D ground_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 meadow : source_color = vec4(0.40, 0.56, 0.27, 1.0);
uniform vec4 meadow_shadow : source_color = vec4(0.18, 0.35, 0.25, 1.0);
uniform vec4 meadow_light : source_color = vec4(0.61, 0.67, 0.33, 1.0);
uniform vec4 sand : source_color = vec4(0.84, 0.74, 0.56, 1.0);
uniform vec4 mortar : source_color = vec4(0.51, 0.39, 0.25, 1.0);
varying vec3 p_world;
varying vec3 masks;

float rand2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float field(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rand2(i), rand2(i + vec2(1, 0)), f.x),
		mix(rand2(i + vec2(0, 1)), rand2(i + vec2(1)), f.x), f.y);
}

vec3 texture_cell(vec2 p, vec2 quadrant) {
	vec2 safe = (1.0 - abs(mod(p, 2.0) - 1.0)) * 0.973 + 0.0135;
	return texture(ground_atlas, (quadrant + safe) * 0.5).rgb;
}

void vertex() {
	p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	masks = COLOR.rgb;
}

void fragment() {
	vec2 p = p_world.xz;
	float patches = field(p * 0.24) * 0.60 + field(p * 0.74) * 0.40;
	float grass_noise = field(p * 8.0);
	vec3 grass = mix(meadow_shadow.rgb, meadow.rgb, smoothstep(0.19, 0.63, patches));
	grass = mix(grass, meadow_light.rgb, smoothstep(0.58, 0.88, patches) * 0.81);
	grass *= 0.88 + grass_noise * 0.17;
	vec3 meadow_paint = mix(texture_cell(p * 0.27, vec2(1, 0)), texture_cell(p.yx * 0.33 + vec2(1.42, 0), vec2(1, 0)), field(p * 0.47));
	grass = mix(grass, meadow_paint * vec3(1.08, 1.20, .90), 0.52);
	grass = mix(grass, sand.rgb * 0.65, smoothstep(0.46, 0.82, masks.b) * 0.7);

	vec2 laid = vec2(p.x * 1.48 + 0.29 * sin(p.y * 0.41), p.y * 1.65);
	laid.x += fract(floor(laid.y) * 0.51);
	vec2 warp = vec2(field(p * 2.78), field(p * 2.44 + vec2(15.7))) * 0.12;
	vec2 joint = abs(fract(laid + warp) - 0.5);
	float seam = smoothstep(0.454, 0.491, max(joint.x, joint.y));
	vec2 tile_uv = (1.0 - abs(mod(p * 0.22, 2.0) - 1.0)) * 0.98 + 0.01;
	vec3 rock = texture(stone_atlas, vec2(tile_uv.x * 0.5, tile_uv.y)).rgb;
	float mottling = rand2(floor(laid + warp)) * 0.19 + patches * 0.18;
	vec3 sand_paint = texture_cell(p * .42, vec2(1, 1));
	vec3 paving = mix(sand.rgb * (0.74 + mottling), mix(rock, sand_paint, .65) * 1.05, 0.56);
	// Lower the regular seam rhythm where the apron has washed aggregate or worn sandstone.
	float track_wear = smoothstep(.25, .68, field(p * .39 + vec2(27.0, -5.0)) * .68
		+ field(p * 1.12 + vec2(-8.0, 2.36)) * .32);
	float sediment = smoothstep(.63, .86, field(p * .43 + vec2(9.0, 3.0)) + patches * .23);
	vec3 weathered = sand_paint * vec3(.84, .88, .78) * (.93 + grass_noise * .16);
	paving = mix(paving, weathered, .30 * track_wear);
	paving = mix(paving, mortar.rgb, seam * (0.36 - 0.20 * patches) * (1.0 - .48 * track_wear));
	paving = mix(paving, grass * .74, sediment * .13 * smoothstep(0.08, .32, 1.0 - masks.r));
	paving = mix(paving, weathered * vec3(.87, .90, .81), masks.g * .42);
	float bare_soil = smoothstep(.55, .86, field(p * .53 + vec2(3.7, 18.8))) * masks.g * (1.0 - smoothstep(.50, .88, masks.r));
	grass = mix(grass, weathered * vec3(.48, .53, .38), bare_soil * .53);
	float path = smoothstep(0.05, 0.69, masks.r + patches * 0.11 - 0.06);
	ALBEDO = mix(grass, paving, path);
	ROUGHNESS = mix(0.92, 0.81, path);
	SPECULAR = 0.22;
}
