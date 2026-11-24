shader_type spatial;

uniform sampler2D stone_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 dry_basalt : source_color = vec4(.50, .57, .55, 1.0);
uniform vec4 soaked_basalt : source_color = vec4(.25, .36, .37, 1.0);
uniform vec4 ocher : source_color = vec4(.61, .57, .42, 1.0);
uniform vec4 algae : source_color = vec4(.37, .48, .36, 1.0);
varying vec3 world_point;
varying vec3 world_normal;

float hash21(vec2 at) {
	return fract(sin(dot(at, vec2(142.3, 318.8))) * 23687.89);
}

float noise21(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash21(cell), hash21(cell + vec2(1, 0)), blend.x),
		mix(hash21(cell + vec2(0, 1)), hash21(cell + vec2(1, 1)), blend.x), blend.y);
}

float rock_grain(vec2 p) {
	vec2 mirrored = 1.0 - abs(mod(p, 2.0) - 1.0);
	vec3 source = texture(stone_atlas, vec2(.507, .014) + mirrored * vec2(.478, .972)).rgb;
	return dot(source, vec3(.2126, .7152, .0722));
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 w = normalize(world_normal);
	vec3 p = world_point;
	float broken = noise21(p.xz * .56) * .58 + noise21(p.xz * 1.19 + p.y * .29) * .42;
	float elevation = p.y + p.z * .068 + p.x * .032;
	float bed = fract(elevation * 1.12 + (broken - .5) * .30);
	float cracks = smoothstep(.82, .98, bed) * (.18 + broken * .62) * (1.0 - abs(w.y));
	float warm_face = smoothstep(.36, .72, noise21(p.xz * .19 + p.y * .13)) * (1.0 - abs(w.y) * .54);
	float low = 1.0 - smoothstep(-.66, .38, p.y + (broken - .5) * .45);
	float salt = (1.0 - smoothstep(.09, .56, abs(p.y - .31 + (broken - .5) * .57))) * broken;
	float root = smoothstep(.11, .75, w.y) * smoothstep(.47, .76, broken);
	vec3 weights = pow(abs(w), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, .001);
	float grain = rock_grain(p.zy * vec2(.16, .27)) * weights.x
		+ rock_grain(p.xz * .18) * weights.y + rock_grain(p.xy * vec2(.16, .27)) * weights.z;
	float flake = rock_grain(p.xz * .56 + vec2(.83, p.y * .38));
	float weathered = mix(grain, flake, .31);
	float fractured = noise21(vec2(p.z + p.y * .36, p.x) * vec2(1.2, .71));
	float rind = smoothstep(.39, .73, fractured + p.y * .032);
	float scoured = noise21(p.xz * 1.64 + vec2(p.y * .29)) * .58 + weathered * .42;
	float runnels = noise21(vec2(p.z + p.x * .8 + p.y * .29, p.y) * vec2(2.39, .25));
	float seep = smoothstep(.47, .79, runnels) * smoothstep(-.75, .2, p.y)
		* (1.0 - smoothstep(2.2, 5.6, p.y)) * (1.0 - abs(w.y) * .81);
	vec3 surface = mix(dry_basalt.rgb, ocher.rgb, warm_face * .45);
	surface = mix(surface, soaked_basalt.rgb, max(low * .83, seep * .75));
	surface = mix(surface, algae.rgb, max(salt * .46, root * .47));
	ALBEDO = surface * (.24 + weathered * 1.33 + scoured * .19 - cracks * .35)
		* (.71 + rind * .31 - seep * .14) * COLOR.rgb;
	ROUGHNESS = clamp(.93 - low * .42 + weathered * .11 - seep * .38, .42, .97);
	SPECULAR = .32;
	float chip = scoured * .021 + weathered * .026 - cracks * .035;
	vec3 displaced = VERTEX + NORMAL * chip;
	vec3 changed = normalize(cross(dFdx(displaced), dFdy(displaced)));
	changed *= dot(changed, NORMAL) < 0.0 ? -1.0 : 1.0;
	NORMAL = normalize(mix(NORMAL, changed, .32));
}
