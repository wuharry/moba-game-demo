shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_jade : source_color = vec4(0.30, 0.78, 0.68, 1.0);
uniform vec4 mid_aqua : source_color = vec4(0.09, 0.54, 0.55, 1.0);
uniform vec4 deep_sapphire : source_color = vec4(0.05, 0.34, 0.42, 1.0);
uniform vec4 sky_reflect : source_color = vec4(0.48, 0.78, 0.90, 1.0);
uniform vec4 foam_white : source_color = vec4(0.96, 0.99, 0.98, 1.0);
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
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), weight.x), weight.y);
}

float view_depth(vec2 uv, float depth, mat4 projection_inverse) {
	vec4 position = projection_inverse * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -position.z / position.w;
}

float caustic_net(vec2 p, float t) {
	vec2 p1 = p * 2.6 + vec2(t * 0.22, -t * 0.17);
	vec2 p2 = p * 2.9 + vec2(-t * 0.19, t * 0.25);
	float w1 = abs(sin(p1.x + sin(p1.y * 1.3)) + cos(p1.y + cos(p1.x * 1.1)));
	float w2 = abs(sin(p2.x * 1.15 - cos(p2.y)) + cos(p2.y * 1.2 + sin(p2.x)));
	float net = 1.0 - smoothstep(0.04, 0.34, min(w1, w2));
	return pow(net, 1.6);
}

void fragment() {
	vec2 p = p_world;
	vec2 shape = (p - center) / radius;
	float shore = length(shape + vec2(sin(p.y * 0.34), sin(p.x * 0.61)) * 0.08);
	float n_low = noise(p * 0.55 - vec2(TIME * 0.04, 0.0));
	float n_hi = noise(p * 2.1 + vec2(0.0, TIME * 0.08));

	// Depth reconstruction for crystal-clear Fontaine water absorption
	float floor_z = view_depth(SCREEN_UV, texture(screen_depth, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float water_depth = max(0.0, (floor_z + VERTEX.z) * abs(dot(NORMAL, VIEW)));

	// Subtle silky wave normals (smooth anime water, never noisy)
	float w_a = sin(dot(p, vec2(1.9, 1.4)) + n_low * 2.4 - TIME * 0.95);
	float w_b = sin(dot(p, vec2(-2.7, 2.3)) + n_hi * 1.8 + TIME * 1.25);
	vec2 refract_off = vec2(w_a, w_b) * 0.0032 * smoothstep(0.02, 0.35, water_depth);
	vec2 refr_uv = clamp(SCREEN_UV + refract_off, vec2(0.002), vec2(0.998));
	if (view_depth(refr_uv, texture(screen_depth, refr_uv).r, INV_PROJECTION_MATRIX) + VERTEX.z < 0.0) {
		refr_uv = SCREEN_UV;
	}
	vec3 seabed = texture(screen_color, refr_uv).rgb;

	// 3-stop jewel-toned depth gradient
	float d_shallow = smoothstep(0.0, 0.42, water_depth);
	float d_deep = smoothstep(0.32, 1.28, water_depth);
	vec3 water_tint = mix(shallow_jade.rgb, mid_aqua.rgb, d_shallow);
	water_tint = mix(water_tint, deep_sapphire.rgb, d_deep);

	// Sparkling shallow caustics
	float caust = caustic_net(p, TIME) * (1.0 - smoothstep(0.08, 0.95, water_depth)) * smoothstep(0.02, 0.14, water_depth);
	seabed = seabed * mix(vec3(0.95, 1.02, 0.98), shallow_jade.rgb * 1.15, d_shallow * 0.65) + foam_white.rgb * caust * 0.28;

	// Fresnel sky reflection + crystal clarity (balanced for both ground grazing & 45-deg MOBA overhead!)
	float fresnel = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 4.2);
	float clarity = (1.0 - smoothstep(0.06, 1.05, water_depth)) * (1.0 - fresnel * 0.55);

	// Crisp stylized anime double-line shore foam!
	float depth_foam_line = (1.0 - smoothstep(0.0, 0.075, water_depth)) * smoothstep(0.002, 0.018, water_depth);
	float ripple_ring = sin(water_depth * 36.0 - TIME * 2.1 + n_hi * 2.2);
	float secondary_foam = smoothstep(0.72, 0.95, ripple_ring) * (1.0 - smoothstep(0.04, 0.22, water_depth)) * smoothstep(0.35, 0.78, n_low);
	float sun_sparkle = smoothstep(0.94, 0.995, w_a * 0.52 + w_b * 0.48) * smoothstep(0.35, 0.85, n_hi) * 0.35;
	float foam = clamp(depth_foam_line * 0.88 + secondary_foam * 0.55, 0.0, 1.0);

	vec3 surface_col = mix(water_tint, sky_reflect.rgb, clamp(fresnel * 0.54 + 0.04, 0.0, 0.62));
	surface_col = mix(surface_col, foam_white.rgb, foam);

	NORMAL_MAP = vec3(0.5 + w_a * 0.012 + w_b * 0.008, 0.5 + (w_b - w_a) * 0.010, 1.0);
	ROUGHNESS = mix(0.12, 0.48, foam);
	SPECULAR = 0.26;
	METALLIC = 0.02;
	ALBEDO = surface_col * (1.0 - clarity * 0.72);
	EMISSION = seabed * clarity * 0.74 + foam_white.rgb * (sun_sparkle * 0.45 + foam * 0.14);
}
