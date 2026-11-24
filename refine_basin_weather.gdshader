shader_type spatial;

uniform vec4 coating : source_color = vec4(0.38, 0.46, 0.45, 1.0);
uniform float dry_roughness = 0.79;
uniform float nominal_metal = 0.28;
varying vec3 p_local;
varying vec3 p_world;
varying vec3 normal_world;

float salt(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float fleck(vec3 p) {
	vec3 i = floor(p);
	vec3 s = fract(p);
	s = s * s * (3.0 - 2.0 * s);
	return mix(
		mix(mix(salt(i), salt(i + vec3(1,0,0)), s.x),
			mix(salt(i + vec3(0,1,0)), salt(i + vec3(1,1,0)), s.x), s.y),
		mix(mix(salt(i + vec3(0,0,1)), salt(i + vec3(1,0,1)), s.x),
			mix(salt(i + vec3(0,1,1)), salt(i + vec3(1,1,1)), s.x), s.y), s.z);
}

void vertex() {
	p_local = VERTEX;
	p_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float clouds = fleck(p_world * vec3(2.4, .97, 2.07));
	float stain = fleck(p_world * vec3(10.3, 1.5, 8.5) + clouds * 2.8);
	float pigment = fleck(p_world * 19.0);
	float vertical = 1.0 - abs(normal_world.y);
	float lower = 1.0 - smoothstep(-.65, .55, p_local.y);
	float corrosion = smoothstep(.44, .83, stain * .42 + clouds * .36 + lower * .29) * vertical;
	float exposed = smoothstep(.64, .88, pigment + .08 * clouds) * nominal_metal * .27;
	vec3 neutral = coating.rgb * (.76 + clouds * .28 + pigment * .13);
	vec3 wear = mix(vec3(.102, .126, .115), vec3(.25, .12, .069), smoothstep(.10, .55, nominal_metal));
	ALBEDO = mix(mix(neutral, wear, corrosion * .46), vec3(.283, .294, .272), exposed);
	ROUGHNESS = clamp(dry_roughness + (clouds - .5) * .25 + .16 * corrosion - .17 * exposed, .26, .96);
	METALLIC = nominal_metal * (1.0 - corrosion * .73);
	SPECULAR = .34;
}
