shader_type spatial;

uniform sampler2D painted_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 shadow_stone : source_color = vec4(0.22, 0.28, 0.31, 1.0);
uniform vec4 exposed_stone : source_color = vec4(0.44, 0.51, 0.54, 1.0);
uniform vec4 oxidized_stone : source_color = vec4(0.46, 0.40, 0.32, 1.0);
uniform vec4 lichen_stone : source_color = vec4(0.34, 0.41, 0.34, 1.0);
uniform float rock_sediment = 0.3;
uniform float pattern_scale = 4.5;
uniform float belt_size = 1.25;
uniform float detail_amount = 0.48;
uniform bool layered_ridge = false;
uniform bool eroded_bluff = false;
uniform bool jointed_talus = false;

varying vec3 world_position;
varying vec3 world_normal;

float hash(vec3 cells) {
	return fract(sin(dot(cells, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float field(vec3 point) {
	vec3 cell = floor(point);
	vec3 t = fract(point);
	t = t * t * (3.0 - 2.0 * t);
	return mix(
		mix(mix(hash(cell), hash(cell + vec3(1, 0, 0)), t.x),
			mix(hash(cell + vec3(0, 1, 0)), hash(cell + vec3(1, 1, 0)), t.x), t.y),
		mix(mix(hash(cell + vec3(0, 0, 1)), hash(cell + vec3(1, 0, 1)), t.x),
			mix(hash(cell + vec3(0, 1, 1)), hash(cell + vec3(1, 1, 1)), t.x), t.y),
		t.z
	);
}

vec3 sample_painted(vec2 p, vec2 rotation_bias) {
	vec2 uv = p + rotation_bias;
	vec2 derivative_x = dFdx(uv);
	vec2 derivative_y = dFdy(uv);
	vec2 local = fract(uv) * 0.968 + 0.016;
	vec2 atlas = vec2(0.5 + local.x * 0.5, local.y);
	return textureGrad(painted_atlas, atlas, derivative_x * vec2(0.484, 0.968), derivative_y * vec2(0.484, 0.968)).rgb;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 normal_world = normalize(world_normal);
	vec3 base_normal = NORMAL;
	vec3 tex_p = world_position / pattern_scale;
	vec3 weights = pow(abs(normal_world), vec3(3.4));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 printed = sample_painted(tex_p.zy, vec2(0.19, 0.49)) * weights.x
		+ sample_painted(tex_p.xz, vec2(0.67, 0.16)) * weights.y
		+ sample_painted(tex_p.xy, vec2(0.08, 0.88)) * weights.z;

	float granite = dot(printed, vec3(0.23, 0.61, 0.16));
	float mass_shade = field(world_position * 0.25 + vec3(18.0, 0, 0));
	float fracture = field(world_position * vec3(1.95, 0.47, 1.72));
	float chips = field(world_position * 6.1 + fracture * 2.0);
	float grain = field(world_position * 22.8);
	vec3 f = world_position;
	float broad_cut = (f.y - f.x * 0.08 + f.z * 0.13) / belt_size + mass_shade * 0.44;
	float belt = smoothstep(0.68, 0.95, fract(broad_cut + fracture * 0.68))
		* (1.0 - smoothstep(0.95, 1.0, fract(broad_cut + fracture * 0.68))) * smoothstep(0.38, 0.75, fracture);
	float facing_up = clamp(normal_world.y, 0.0, 1.0);
	float edge = clamp(COLOR.r * 1.15 - 0.10, 0.0, 1.0);
	float drift = smoothstep(0.26, 0.81, mass_shade * 0.69 + granite * 0.54);
	float face_light = clamp(0.025 + edge * 0.23 + drift * 0.32 + facing_up * 0.12 - belt * 0.18, 0.0, 1.0);
	vec3 stone = mix(shadow_stone.rgb, exposed_stone.rgb, face_light);
	float stain = smoothstep(0.54, 0.76, field(world_position * vec3(0.36, 0.21, 0.40))) * rock_sediment;
	stone = mix(stone, oxidized_stone.rgb, stain * (1.0 - facing_up * 0.39));
	float patina = smoothstep(.45, .75, chips * 0.42 + mass_shade * 0.67) * smoothstep(.17, .62, facing_up);
	stone = mix(stone, lichen_stone.rgb, patina * rock_sediment * 0.63);

	float relief = min(0.8, chips * 0.25 + grain * 0.115 + granite * 0.65 + belt * 0.21 + fracture * 0.19);
	vec3 raised = VERTEX + NORMAL * relief * 0.065;
	vec3 relief_normal = normalize(cross(dFdx(raised), dFdy(raised)));
	if (dot(relief_normal, NORMAL) < 0.0) {
		relief_normal = -relief_normal;
	}
	NORMAL = normalize(mix(NORMAL, relief_normal, 0.50 * detail_amount));
	float dark_foot = 0.72 + COLOR.g * 0.28;
	float variation = 0.48 + granite * 1.05 + grain * 0.15 + fracture * 0.36 - belt * 0.13;
	ALBEDO = stone * mix(1.0, variation, detail_amount) * dark_foot;
	float dampness = smoothstep(.27, .73, granite * 0.33 + mass_shade * 0.64 + (1.0 - facing_up) * 0.24 + (1.0 - COLOR.g) * 0.14);
	ROUGHNESS = clamp(0.86 - dampness * 0.27, 0.32, 0.92);
	SPECULAR = 0.29;
	if (layered_ridge) {
		float slip = field(f * vec3(0.46, 0.16, 0.32));
		float bed = (f.y + f.x * 0.18 - f.z * 0.20) * 1.76 + slip * 0.73;
		float exposed_lamina = smoothstep(0.62, 0.85, fract(bed))
			* (1.0 - smoothstep(0.90, 0.99, fract(bed)))
			* smoothstep(0.32, 0.75, fracture + slip * 0.17)
			* (1.0 - facing_up * 0.57);
		float dark_joint = 1.0 - smoothstep(0.04, 0.19, fract(bed + 0.21));
		dark_joint *= smoothstep(0.44, 0.68, slip + chips * 0.12);
		float mineral_colour = smoothstep(.26, .73, granite + fracture * .24);
		ALBEDO = ALBEDO * (0.91 + mineral_colour * 0.25 - dark_joint * 0.13);
		ALBEDO = mix(ALBEDO, exposed_stone.rgb, exposed_lamina * 0.26 * detail_amount);
		ROUGHNESS = mix(ROUGHNESS, 0.84, exposed_lamina * 0.23);
	}
	if (eroded_bluff) {
		float big_fold = field(f * vec3(0.144, 0.089, 0.156) + vec3(7.1, 9.4, 3.2));
		float weathering = field(f * vec3(0.65, 0.46, 0.54) + vec3(11.1, 0.27, 1.3));
		float sheared_y = f.y * 0.74 + f.x * 0.125 - f.z * 0.15 + (big_fold - 0.5) * 1.36;
		float layer = sheared_y / belt_size + weathering * 0.36 + fracture * 0.21;
		float edge_width = max(fwidth(layer) * 0.85, 0.015);
		float bedding = abs(fract(layer + 0.53) - 0.5);
		float joint_run = smoothstep(0.32, 0.68, weathering * 0.59 + fracture * 0.21 + big_fold * 0.25);
		float inner_joint = (1.0 - smoothstep(0.018, 0.075 + edge_width, bedding)) * joint_run;
		float upper_lip = smoothstep(0.06, 0.11 + edge_width, bedding) * (1.0 - smoothstep(0.14, 0.24 + edge_width, bedding));
		upper_lip *= joint_run * (1.0 - facing_up * 0.22);
		float chip_edge = abs(fract(sheared_y * 1.83 + weathering * 1.4 + chips * 0.19) - 0.5);
		float small_spalls = (1.0 - smoothstep(0.025, 0.115 + fwidth(chip_edge), chip_edge)) * smoothstep(0.54, 0.79, fracture) * detail_amount;
		float seep = field(f * vec3(1.76, 0.16, 1.58) + vec3(weathering * 0.9, 13.8, fracture * 0.26));
		float rinse = smoothstep(0.60, 0.84, seep * 0.77 + COLOR.b * 0.28) * mix(1.0, 0.38, COLOR.g);
		float foothill = (1.0 - COLOR.g) * (0.66 + seep * 0.34);
		float oxidized_skin = smoothstep(0.39, 0.74, weathering * 0.58 + granite * 0.26 + big_fold * 0.35);
		float lichen_skin = smoothstep(0.59, 0.77, weathering * 0.48 + chips * 0.26 + granite * 0.29);
		lichen_skin *= smoothstep(0.16, 0.78, facing_up) * COLOR.g;
		float exposure = 0.18 + COLOR.r * 0.15 + big_fold * 0.40 + granite * 0.25;
		exposure += upper_lip * 0.19 - inner_joint * 0.11;
		vec3 weathered = mix(shadow_stone.rgb, exposed_stone.rgb, clamp(exposure, 0.0, 0.96));
		weathered = mix(weathered, oxidized_stone.rgb, oxidized_skin * rock_sediment * (0.77 - foothill * 0.50));
		weathered = mix(weathered, lichen_stone.rgb, lichen_skin * rock_sediment * 0.82);
		float surface_value = 0.76 + granite * 0.30 + weathering * 0.13 + chips * 0.13 + grain * 0.06;
		surface_value -= inner_joint * 0.34 + small_spalls * 0.17 + rinse * 0.24;
		ALBEDO = weathered * surface_value * (1.02 - foothill * 0.37);
		ROUGHNESS = clamp(0.89 - foothill * 0.45 - rinse * 0.21 + weathering * 0.08, 0.29, 0.94);
		SPECULAR = 0.28 + (1.0 - ROUGHNESS) * 0.19;

		// Screen derivatives supply shallow relief without reintroducing the
		// triangle planes that the continuous vertex normals remove.
		float relief_height = (granite * 0.51 + weathering * 0.38 + chips * 0.16 + grain * 0.085
			+ upper_lip * 0.13 - inner_joint * 0.20 - small_spalls * 0.11) * 0.078 * detail_amount;
		vec3 surface_x = dFdx(VERTEX);
		vec3 surface_y = dFdy(VERTEX);
		vec3 ortho_x = cross(surface_y, base_normal);
		vec3 ortho_y = cross(base_normal, surface_x);
		float frame_area = dot(surface_x, ortho_x);
		vec3 gradient = sign(frame_area) * (dFdx(relief_height) * ortho_x + dFdy(relief_height) * ortho_y);
		NORMAL = normalize(max(abs(frame_area), 0.000001) * base_normal - gradient);
		if (jointed_talus) {
			float coarse_plate = field(f * vec3(0.99, 0.55, 0.84) + vec3(8.6, 2.8, 94.0));
			float plate_body = smoothstep(0.29, 0.65, coarse_plate * 0.82 + big_fold * 0.32);
			float upper_decay = smoothstep(0.40, 0.75, fracture * 0.44 + weathering * 0.53 + chips * 0.17);
			vec3 weathered_plate = mix(shadow_stone.rgb * 0.73, exposed_stone.rgb * 0.85, plate_body);
			vec3 bearing_face = mix(ALBEDO, weathered_plate, 0.20 + upper_decay * 0.23);
			float cold_run = smoothstep(0.47, 0.75, weathering * 0.63 + seep * 0.38 + COLOR.b * 0.22);
			float dry_shoulder = smoothstep(0.37, 0.68, oxidized_skin * 0.69 + plate_body * 0.46) * COLOR.g;
			bearing_face = mix(bearing_face, oxidized_stone.rgb * 0.61, dry_shoulder * rock_sediment * 0.58);
			bearing_face = mix(bearing_face, shadow_stone.rgb * vec3(0.53, 0.67, 0.73), cold_run * (0.13 + foothill * 0.42));
			ALBEDO = bearing_face * (0.86 + upper_lip * plate_body * 0.12 - inner_joint * upper_decay * 0.16);
			ROUGHNESS = clamp(0.91 - foothill * 0.29 - cold_run * 0.11, 0.44, 0.95);
			SPECULAR = mix(0.22, 0.28, foothill * cold_run);
		}
	}
}

