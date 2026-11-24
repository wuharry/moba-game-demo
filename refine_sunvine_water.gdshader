shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 deep : source_color = vec4(0.11, 0.33, 0.31, 1.0);
uniform vec4 shallow : source_color = vec4(0.36, 0.55, 0.42, 1.0);
uniform vec4 surface_light : source_color = vec4(0.66, 0.81, 0.67, 1.0);
uniform sampler2D screen_color : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D screen_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec2 center = vec2(8.7, -1.0);
uniform vec2 radius = vec2(6.0, 8.5);
varying vec2 p_world;

void vertex() {
	p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 xy) {
	vec2 cell = floor(xy);
	vec2 f = fract(xy);
	vec2 weight = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), weight.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), weight.x), weight.y);
}

float view_depth(vec2 uv, float depth, mat4 projection_inverse) {
	vec4 position = projection_inverse * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -position.z / position.w;
}

float shore_caustics(vec2 p, float wave, float tide) {
	vec2 warp = p + vec2(sin(p.y * 1.66 - tide), cos(p.x * 2.32 + tide)) * .24;
	vec2 bands = vec2(dot(warp, vec2(4.4, 2.84)), dot(warp, vec2(-3.18, 5.62)));
	float crossings = sin(bands.x + wave * .42) + sin(bands.y - tide * .43) + sin((bands.x + bands.y) * .70);
	return smoothstep(.084,.172, abs(crossings*.46)) * (1.0 - smoothstep(.17,.25, abs(crossings*.46)));
}

void fragment() {
	vec2 p = p_world;
	vec2 shape = (p - center) / radius;
	float shore = length(shape + vec2(sin(p.y * 0.34), sin(p.x * 0.61)) * 0.08);
	float shelf = noise(p * 0.45);
	float strata = noise(p * 1.38 + vec2(18.0, 2.0));
	float edge = smoothstep(0.58, 0.99, shore + shelf * 0.09 - 0.028);
	float direction = dot(p, vec2(0.76, 0.649));
	float drift = noise(p * vec2(0.50, 0.83) - vec2(TIME * 0.052, 0.0));
	float wave_a = sin(direction * 1.81 + drift * 2.17 - TIME * 0.58);
	float wave_b = sin(direction * 7.1 + drift * 7.0 - TIME * 1.3);
	float wave_cross = sin(dot(p, vec2(-.47, .88)) * 10.8 - drift * 2.7 + TIME * .88);
	float wave_falloff = mix(.19, .68, drift);
	float foam = smoothstep(0.950, 0.993, shore + strata * 0.014) * (1.0 - smoothstep(1.009, 1.05, shore));
	foam *= smoothstep(.43, .72, strata) * smoothstep(.43, .88, shelf);
	float sun_cell = smoothstep(.71, .96, wave_cross * .32 + wave_b * .37 + strata * .63) * (.26 + edge * .74);
	vec3 lake = mix(deep.rgb, shallow.rgb, edge * .80);
	lake *= .92 + shelf * .13;
	float horizon_tint = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 3.0);
	lake = mix(lake, vec3(.11, .21, .24), horizon_tint * .22);
	float floor_depth = view_depth(SCREEN_UV, texture(screen_depth, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float water_depth = max(0.0, (floor_depth + VERTEX.z) * abs(dot(NORMAL, VIEW)));
	vec2 waviness = vec2(wave_b * .001 + wave_cross * .0019, wave_cross * .001 - wave_a * .0011);
	vec2 distorted = SCREEN_UV + waviness * (1.0 - horizon_tint) * smoothstep(.015, .22, water_depth);
	float distorted_depth = view_depth(distorted, texture(screen_depth, distorted).r, INV_PROJECTION_MATRIX);
	if (distorted_depth + VERTEX.z < 0.0) {
		distorted = SCREEN_UV;
	}
	vec3 bottom = texture(screen_color, distorted).rgb * vec3(.68, .91, .64);
	float through_water = (1.0 - smoothstep(.04, .72, water_depth)) * .71 * (1.0 - horizon_tint * .64) * smoothstep(.42, .79, edge);
	float caustic = shore_caustics(p, wave_a, TIME * .41) * through_water * smoothstep(.30,.73,shelf);
	float ripple = smoothstep(.93, .999, wave_cross) * smoothstep(.54, .79, wave_b * .22 + strata * .77);
	float bay = 1.0 - smoothstep(.28, 1.56, length((p - vec2(5.40, 4.27)) * vec2(.56, 1.22)));
	float outlet = 1.0 - smoothstep(.22, 1.70, length((p - vec2(7.26,-7.12)) * vec2(.73, 1.17)));
	float crest = sin(dot(p, vec2(5.2, 2.67)) + .46 * sin(p.y * 2.1 + p.x) - TIME * .51);
	float clear_water = max(bay, outlet * .66) * smoothstep(.82, .98, crest) * (.29 + .71 * edge);
	ALBEDO = mix(lake, surface_light.rgb, sun_cell * .037 + foam * .19);
	NORMAL_MAP = vec3(0.5 + (wave_cross * .007 + wave_b * .004) * wave_falloff,
		0.5 + wave_a * .004 * wave_falloff, 1.0);
	ROUGHNESS = mix(.54, .61, shelf);
	SPECULAR = .19;
	EMISSION = ALBEDO * .154 + bottom * through_water * .55 + surface_light.rgb * (caustic * .43 + ripple * .017 + clear_water * .16);
	ALBEDO *= (1.0 - through_water * .51);
}
