shader_type spatial;

uniform vec4 paint : source_color;
uniform vec4 edge : source_color;
uniform vec4 oxide : source_color;
uniform float coat_roughness = .59;
uniform float coat_metal = .40;
varying vec3 location;
varying vec3 orientation;

float hash21(ivec2 p) {
	uint key = uint(p.x) * 0x8da6b343u ^ uint(p.y) * 0xd8163841u;
	key = (key ^ (key >> 13u)) * 0xcb1ab31fu;
	key ^= key >> 16u;
	return float(key & 0x00ffffffu) / 16777215.0;
}

float noise21(vec2 p) {
	ivec2 i = ivec2(floor(p));
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash21(i), hash21(i + ivec2(1,0)), f.x),
		mix(hash21(i + ivec2(0,1)), hash21(i + ivec2(1,1)), f.x), f.y);
}

void vertex() {
	location = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	orientation = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = location;
	vec2 salt_run = vec2(p.x * .73 + p.z * .67, p.y);
	float grain = noise21(p.xz * 51.3 + p.y * 31.6);
	float exposed = smoothstep(-.11, .88, orientation.y);
	float vertical = 1.0 - smoothstep(.31,.81,abs(orientation.y));
	float salt_veil = smoothstep(.42,.76,noise21(salt_run * vec2(1.67,.51) - vec2(.91,3.7)));
	float runoff = smoothstep(.55,.85,noise21(salt_run * vec2(12.0,.73) + vec2(-.87,3.47)));
	runoff *= vertical * salt_veil;
	float stain = noise21(salt_run * vec2(4.16, .64)) * .56
		+ noise21(salt_run * vec2(23.6, 2.4)) * .21 + grain * .23;
	float bare = smoothstep(.60, .84, stain + exposed * .1);
	float oxidized = smoothstep(.52, .81, noise21(p.xz * .47 + p.y * .39) * .48 + stain * .52);
	float scuff = smoothstep(.64, .82, noise21(vec2(salt_run.x * 73.0, salt_run.y * 6.0)))
		* smoothstep(.41, .74, stain);
	vec3 base = mix(paint.rgb * (.82 + grain * .17 + stain * .12), oxide.rgb, oxidized * .35 + runoff * .29);
	vec3 mineral = mix(edge.rgb, vec3(.27,.31,.29), salt_veil * .24);
	base = mix(base, mineral, salt_veil * exposed * .17);
	ALBEDO = mix(base, edge.rgb, bare * .49 + scuff * .23);
	ROUGHNESS = clamp(coat_roughness + oxidized * .23 + runoff * .13 - bare * .24 + grain * .07, .32, .94);
	METALLIC = clamp(coat_metal + bare * .37 - oxidized * .24, .02, .85);
}
