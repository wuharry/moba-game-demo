shader_type spatial;

uniform sampler2D stone_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D stone_nh : filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 recessed_bed : source_color = vec4(0.46, 0.50, 0.48, 1.0);
uniform vec4 exposed_bed : source_color = vec4(0.84, 0.77, 0.61, 1.0);
uniform vec4 sunlit_crest : source_color = vec4(0.94, 0.89, 0.75, 1.0);
uniform vec4 ledge_moss : source_color = vec4(0.32, 0.59, 0.28, 1.0);
uniform vec4 skirt_grass : source_color = vec4(0.28, 0.55, 0.27, 1.0);

varying vec3 world;
varying vec3 normal_world;
varying vec4 bedding;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float field(vec3 p) {
	vec3 cell = floor(p);
	vec3 d = fract(p);
	d = d * d * (3.0 - 2.0 * d);
	float low = mix(mix(hash(cell), hash(cell + vec3(1, 0, 0)), d.x),
		mix(hash(cell + vec3(0, 1, 0)), hash(cell + vec3(1, 1, 0)), d.x), d.y);
	float high = mix(mix(hash(cell + vec3(0, 0, 1)), hash(cell + vec3(1, 0, 1)), d.x),
		mix(hash(cell + vec3(0, 1, 1)), hash(cell + vec3(1, 1, 1)), d.x), d.y);
	return mix(low, high, d.z);
}

vec3 triplanar_stone(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.001);
	vec2 uvx = (1.0 - abs(mod(p.zy * 0.24, 2.0) - 1.0)) * 0.96 + 0.02;
	vec2 uvy = (1.0 - abs(mod(p.xz * 0.24, 2.0) - 1.0)) * 0.96 + 0.02;
	vec2 uvz = (1.0 - abs(mod(p.xy * 0.24, 2.0) - 1.0)) * 0.96 + 0.02;
	return texture(stone_atlas, vec2(uvx.x * 0.5, uvx.y)).rgb * w.x
		+ texture(stone_atlas, vec2(uvy.x * 0.5, uvy.y)).rgb * w.y
		+ texture(stone_atlas, vec2(uvz.x * 0.5, uvz.y)).rgb * w.z;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	bedding = COLOR;
}

void fragment() {
	vec3 nw = normalize(normal_world);
	float above = clamp(nw.y, 0.0, 1.0);
	float washes = field(world * vec3(0.32, 0.52, 0.29)) * 0.65 + field(world * 1.15) * 0.35;

	// Blur-Slope sculpted sedimentary strata & chisel planes
	vec3 tex_stone = triplanar_stone(world, nw);
	vec4 nh = texture(stone_nh, world.xz * 0.22 + world.y * 0.14);
	float seams = world.y * 3.6 - world.x * 0.26 - world.z * 0.24 + washes * 1.1;
	float step_band = smoothstep(0.76, 0.96, sin(seams) * 0.5 + 0.5);

	float weather = clamp(washes * 0.62 + bedding.r * 0.38, 0.0, 1.0);
	vec3 rock = mix(recessed_bed.rgb, exposed_bed.rgb, smoothstep(0.18, 0.72, weather));
	rock = mix(rock, tex_stone * 1.12, 0.42);
	rock *= 1.0 - step_band * 0.18 * (1.0 - above * 0.65);

	// Crisp chiselled bevel edge highlight (screen-space normal curvature!)
	float edge_curv = clamp(length(fwidth(nw)) * 1.65, 0.0, 1.0);
	rock = mix(rock, sunlit_crest.rgb, edge_curv * 0.38);

	// Lush top-ledge moss cap + Genshin BlendStone skirt blending at cliff/boulder base!
	float top_moss = smoothstep(0.52, 0.84, above * 0.62 + bedding.g * 0.26 + washes * 0.28);
	vec3 moss_col = mix(ledge_moss.rgb, vec3(0.50, 0.72, 0.30), smoothstep(0.4, 0.9, washes));
	rock = mix(rock, moss_col, top_moss * 0.88);

	// COLOR.a = 1.0 at ground skirt -> 0.0 above 0.55m (BlendStone seamless base!)
	float skirt = clamp(bedding.a, 0.0, 1.0);
	rock = mix(rock, skirt_grass.rgb * (0.90 + washes * 0.22), smoothstep(0.15, 0.88, skirt) * 0.82);

	ALBEDO = rock;
	NORMAL_MAP = mix(nh.rgb, vec3(0.5, 0.5, 1.0), max(top_moss, skirt) * 0.75);
	NORMAL_MAP_DEPTH = 0.55;
	ROUGHNESS = mix(0.84, 0.92, max(top_moss, skirt));
	SPECULAR = 0.18;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float shadow_vis = smoothstep(0.10, 0.86, ATTENUATION);
	float lit = smoothstep(0.38, 0.68, ndl) * shadow_vis;

	vec3 light_energy = LIGHT_COLOR / PI;
	vec3 shadow_col = ALBEDO * vec3(0.06, 0.09, 0.14);
	vec3 sun_col = ALBEDO * vec3(1.04, 1.01, 0.94);

	DIFFUSE_LIGHT += mix(shadow_col, sun_col, lit) * light_energy;
}
