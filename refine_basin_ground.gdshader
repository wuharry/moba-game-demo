shader_type spatial;

uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float patch_scale = 4.1;
uniform float lane_amount = 0.0;
uniform float puddles = 0.0;
uniform float traffic_breakup = 0.0;
uniform float continuous_sampling = 0.0;
uniform float repair_weathering = 0.0;
uniform bool service_apron = false;
uniform bool split_approach = false;
uniform bool runoff_layers = false;
uniform bool soft_sky_return = false;
uniform bool saturated_concrete = false;
uniform bool cast_cap = false;
uniform bool reserve_guide_glare = false;
uniform bool drained_pavement = false;
uniform bool worn_joints = false;
uniform vec4 tint : source_color = vec4(1.0);
varying vec3 p;
varying vec3 n;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(123.7, 278.9))) * 43758.5453);
}

float noise(vec2 field) {
	vec2 cell = floor(field);
	vec2 xy = fract(field);
	vec2 w = xy * xy * (3.0 - 2.0 * xy);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), w.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), w.x), w.y);
}

vec3 paint_cell(vec2 field, vec2 key, vec2 atlas_cell) {
	float salt = hash(key);
	float direction = floor(salt * 4.0) * 1.57079633;
	float s = sin(direction);
	float c = cos(direction);
	vec2 reference = mat2(vec2(c, -s), vec2(s, c)) * (field - key) * 0.61 + vec2(salt * 0.39, hash(key + 25.1));
	vec2 centered = fract(reference);
	if (continuous_sampling > 0.5) {
		centered = 1.0 - abs(mod(reference, 2.0) - 1.0);
	}
	return texture(paint, (atlas_cell + centered * 0.952 + 0.024) * 0.5).rgb;
}

vec3 dab(vec2 field, vec2 tile) {
	vec2 cell = floor(field);
	vec2 w = smoothstep(vec2(0.04), vec2(0.96), fract(field));
	return mix(mix(paint_cell(field, cell, tile), paint_cell(field, cell + vec2(1.0, 0.0), tile), w.x),
		mix(paint_cell(field, cell + vec2(0.0, 1.0), tile), paint_cell(field, cell + vec2(1.0), tile), w.x), w.y);
}

float segment_distance(vec2 at, vec2 beginning, vec2 ending) {
	vec2 axis = ending - beginning;
	float t = clamp(dot(at - beginning, axis) / dot(axis, axis), 0.0, 1.0);
	return length(at - (beginning + axis * t));
}

float road_patch(vec2 position, vec2 center, vec2 width, float tilt) {
	float s = sin(tilt);
	float c = cos(tilt);
	vec2 rotated_patch = (mat2(vec2(c, -s), vec2(s, c)) * (position - center)) / width;
	float edge = length(rotated_patch) + (noise(position * 3.0) - 0.5) * 0.51;
	return (1.0 - smoothstep(0.53, 0.97, edge)) * smoothstep(0.15, 0.65, noise(position * 5.0 + 4.9));
}

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 ground = p.xz;
	vec2 field = ground / patch_scale;
	float large_scale = noise(field * 1.15 + vec2(7.0, 2.0));
	float medium_scale = noise(ground * 0.73 + vec2(-4.0, 7.0));
	float detail = noise(ground * 8.9);
	float main_track = segment_distance(ground, vec2(-0.17, 15.4), vec2(0.15, -4.2));
	float bypass = min(segment_distance(ground, vec2(5.1, 6.7), vec2(5.0, -7.8)),
		min(segment_distance(ground, vec2(2.6, 9.2), vec2(5.1, 6.7)),
		segment_distance(ground, vec2(5.0, -7.8), vec2(0.0, -9.3))));
	float track = max(1.0 - smoothstep(1.68, 3.19, main_track + (medium_scale - 0.5) * 1.3),
		1.0 - smoothstep(0.68, 1.93, bypass + (large_scale - 0.5) * 0.85));
	float plane = smoothstep(0.30, 0.77, n.y);
	track *= lane_amount * plane;
	float repairs = noise(vec2(ground.x * 1.31, ground.y * 0.44) + vec2(2.3, 0.7));
	track *= 1.0 - traffic_breakup * 0.28 * smoothstep(.42, .87, repairs);
	vec3 base = dab(field, vec2(0.0, 0.0));
	vec3 road = dab(field * 1.08 + vec2(9.45, 3.22), vec2(0.0, 1.0));
	vec3 material = mix(base * (0.80 + large_scale * 0.22) * tint.rgb,
		road * vec3(0.97, 1.02, 1.01) * (0.88 + large_scale * 0.28), track);
	material *= mix(1.0, .89 + repairs * .13, traffic_breakup);
	float wear = 0.0;
	if (repair_weathering > .5) {
		wear = max(road_patch(ground, vec2(-2.73, 3.24), vec2(.95, 1.2), .47),
			road_patch(ground, vec2(2.53, 5.55), vec2(.61, 1.46), -.36));
		wear = max(wear, road_patch(ground, vec2(4.65, -.20), vec2(.74, 1.66), .14));
		wear = max(wear, road_patch(ground, vec2(-2.60, 7.02), vec2(.46, 1.11), .24));
		wear = max(wear, road_patch(ground, vec2(-1.53, -7.14), vec2(.67, .89), .45));
		wear *= plane;
		vec3 aggregate = dab(field * 1.63 + vec2(21.34, 9.03), vec2(0.0, 1.0));
		material = mix(material, aggregate * vec3(.78, .91, .89), .62 * wear);
	}
	if (service_apron) {
		// Cast the work yard across the relay's actual apron, leaving the
		// natural verge soft and following the curve of the travel lane.
		float bay = max(abs(ground.x + 0.43 + ground.y * 0.07) - (2.82 + 0.43 * medium_scale),
			abs(ground.y + 2.17) - 5.9);
		float cast_mask = (1.0 - smoothstep(-0.34, 0.47, bay + (medium_scale - 0.5) * 0.68)) * plane;
		float slab_band = floor((ground.y + ground.x * .11 + 18.33) / 3.14);
		float slab_offset = fract(slab_band * .374 + .11) * 1.49;
		vec2 cast_field = vec2(ground.x - slab_offset, ground.y + ground.x * .11);
		vec2 joint_grid = abs(fract((cast_field + vec2(.21, .11)) / vec2(3.78, 3.14)) - .5);
		float joint = smoothstep(.480, .497, max(joint_grid.x, joint_grid.y));
		float tile_tone = hash(floor((cast_field + vec2(.21, .11)) / vec2(3.78, 3.14)));
		vec3 pour = mix(road, base, .21) * vec3(.93, 1.02, 1.00);
		pour *= (.78 + .17 * tile_tone + .12 * medium_scale) * (1.0 - .27 * joint);
		material = mix(material, pour, cast_mask * .83);
		float gutter_center = -3.47 + .22 * sin(ground.y * .47);
		float gutter_mask = (1.0 - smoothstep(.14, .75, abs(ground.x - gutter_center))) * plane;
		float iron_stain = gutter_mask * smoothstep(.39, .72, medium_scale);
		material = mix(material, material * vec3(.73, .66, .50), iron_stain * .69);
		material = mix(material, material * vec3(.80, .90, .85), gutter_mask * .39);
	}
	if (split_approach) {
		float apron_width = mix(2.62, 1.96, smoothstep(-3.45, 7.29, ground.y));
		float central = (1.0 - smoothstep(apron_width - .36, apron_width + .28, main_track)) * plane;
		float side_route = (1.0 - smoothstep(.65, 1.79, bypass + (medium_scale - .5) * .28)) * plane;
		float lee_edge = (1.0 - central) * smoothstep(3.5, 9.7, ground.y) * .33;
		float walkway = central * (1.0 - side_route * .74);
		material = mix(material, material * vec3(.83, .81, .70), side_route * .52);
		material *= 1.0 - lee_edge * plane;
		material = mix(material, material * vec3(.96, 1.04, 1.07), walkway * .77);
		float approach_line = abs(ground.x - mix(2.32, 1.62, smoothstep(-2.8, 5.6, ground.y)));
		float fade_line = smoothstep(-2.8, -1.8, ground.y) * (1.0 - smoothstep(4.4, 6.2, ground.y));
		float stripe = (1.0 - smoothstep(.022, .071, approach_line)) * fade_line * plane;
		stripe *= smoothstep(.09, .36, fract((ground.y + .18) * .68)) * smoothstep(.33, .69, detail + .1);
		material = mix(material, vec3(.245, .167, .066), stripe * .48);
	}
	float drains = exp(-pow((ground.x + 3.65 + sin(ground.y * 0.76) * 0.26) / 1.27, 2.0));
	float seep = smoothstep(0.56, 0.87, large_scale * 0.63 + medium_scale * 0.31 + drains * 0.24);
	float pond = seep * puddles * plane;
	float dark_rim = 0.0;
	if (runoff_layers) {
		// Water follows ruts and sags. Calm puddle centers can reflect the
		// relay, while fractured slab margins remain gritty and matte.
		float disturbance = noise(ground * vec2(4.26, 2.68)) * .12 + medium_scale * .13;
		float apron_low = road_patch(ground, vec2(-1.77, .76), vec2(1.11, 2.58), .22);
		apron_low = max(apron_low, road_patch(ground, vec2(1.22, -2.68), vec2(1.08, 1.60), -.24));
		float side_low = road_patch(ground, vec2(5.24, 2.42), vec2(.68, 2.40), -.13);
		float mud_run = drains * .77 + medium_scale * .18;
		float water_level = max(max(apron_low, side_low), mud_run) + disturbance;
		float pooled = smoothstep(.69, .88, water_level) * (soft_sky_return ? .91 : 1.0);
		if (saturated_concrete) {
			pooled *= smoothstep(-4.65, -2.92, ground.x);
		}
		pond = max(pond * .65, pooled * plane);
		dark_rim = smoothstep(.34, .73, water_level) * plane;
		material = mix(material, material * vec3(.59,.72,.71), dark_rim * .41);
		float joint_bed = ground.y + ground.x * .11 + .11;
		float joint = abs(fract(joint_bed / 3.14) - .5);
		float exposed_cut = smoothstep(.476, .494, joint) * track;
		float damp_edge = smoothstep(.42, .47, joint) * (1.0 - exposed_cut) * track;
		material *= 1.0 - (.19 * exposed_cut + .08 * damp_edge) * (.52 + medium_scale * .48);
		float scatter = smoothstep(.59, .83, noise(ground * 12.3)) * smoothstep(.38, .69, repairs);
		material = mix(material, material * vec3(1.18, 1.11, .96), scatter * (1.0 - pooled) * .58);
	}
	if (cast_cap) {
		float sand = smoothstep(.26,.72,noise(ground * .47 + vec2(6.3,7.7)));
		vec3 aggregate = dab(field * 1.38 + vec2(6.72, 2.39), vec2(0.0, 1.0));
		vec3 slab = mix(material, aggregate * mix(vec3(.74,.87,.86), vec3(1.03,.98,.85), sand), .47);
		float border = 1.0 - smoothstep(.016, .075, p.y);
		material = mix(slab, material * vec3(.94,.94,.90), border * .67);
	}
	float inner_pool = 0.0;
	if (drained_pavement) {
		float grout = noise(ground * vec2(2.1,1.7) + vec2(1.6,8.44));
		float broad_paste = noise(ground * vec2(.36,.53) + vec2(4.39,.83));
		float dry_joint = (ground.y + ground.x * .084) / 3.08;
		float edge_offset = worn_joints ? (grout - .5) * .025 : 0.0;
		float cut = (1.0 - smoothstep(.013,.047,abs(fract(dry_joint + .11 + edge_offset) - .5))) * track * plane;
		if (worn_joints) {
			float filled = noise(ground * vec2(.78,2.9) + vec2(17.81,3.48));
			float abraded = .13 + smoothstep(.31,.78,filled) * .49;
			float service_split = smoothstep(.51,1.54,abs(ground.x - 3.08));
			cut *= abraded * service_split;
		}
		float north_drain = road_patch(ground, vec2(-1.30,-1.96), vec2(.65,1.57), -.21);
		float approach_drain = road_patch(ground, vec2(-.56,2.50), vec2(.82,1.58), .10);
		float side_drain = road_patch(ground, vec2(4.34,3.73), vec2(.48,2.59), -.18);
		float rut_edge = max(approach_drain * .97, max(north_drain, side_drain)) * plane;
		float damp = smoothstep(.17,.77, rut_edge + (grout - .4) * rut_edge * .55);
		inner_pool = smoothstep(.71,.91,rut_edge) * smoothstep(.25,.83,grout);
		float bitumen = smoothstep(.31,.69,broad_paste * .82 + grout * .18);
		float paste = smoothstep(.38,.66, broad_paste * .73 + detail * .27);
		vec3 used_stone = material * mix(vec3(.72,.84,.85), vec3(1.22,1.15,1.04), paste);
		vec3 poolbed = mix(used_stone * vec3(.64,.79,.81), vec3(.040,.085,.088), inner_pool * .41);
		material = mix(used_stone, poolbed, damp * .81);
		material *= 1.0 - (.34 + bitumen * .39) * cut;
		dark_rim = max(dark_rim, damp);
		pond = max(pond * .62, inner_pool * .89);
	}
	float texture_bump = (0.0032 * detail + 0.0047 * medium_scale) * (1.0 - pond);
	vec3 slope = VERTEX + NORMAL * texture_bump;
	vec3 surface = normalize(cross(dFdx(slope), dFdy(slope)));
	if (dot(surface, NORMAL) < 0.0) {
		surface = -surface;
	}
	NORMAL = normalize(mix(NORMAL, surface, 0.2));
	ALBEDO = material * (0.98 - pond * 0.26);
	float water_roughness = soft_sky_return ? .18 : (runoff_layers ? .105 : .19);
	float water_specular = soft_sky_return ? .43 : (runoff_layers ? .63 : .46);
	if (saturated_concrete) {
		water_roughness = .235;
		water_specular = .24;
	}
	ROUGHNESS = mix(0.89 - 0.10 * track + .09 * wear - .14 * dark_rim, water_roughness, pond);
	SPECULAR = mix(0.21, water_specular, pond);
	if (reserve_guide_glare) {
		float calm_edge = 1.0 - smoothstep(-4.36, -3.19, ground.x);
		ROUGHNESS = mix(ROUGHNESS, .70, calm_edge * .86);
		SPECULAR *= 1.0 - calm_edge * .50;
	}
	if (drained_pavement) {
		float grazed = pow(1.0 - max(0.0,dot(NORMAL,VIEW)), 3.4);
		ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.05,1.32,1.36), inner_pool * grazed * .48);
		ROUGHNESS = mix(ROUGHNESS,.21,inner_pool * .74);
		SPECULAR = mix(SPECULAR,.31,inner_pool * .82);
		float outside = 1.0 - smoothstep(-4.22,-2.02,ground.x);
		ROUGHNESS = mix(ROUGHNESS,.83,outside * .92);
		SPECULAR *= 1.0 - outside * .91;
	}
}
