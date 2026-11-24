shader_type spatial;

uniform vec4 paint : source_color;
uniform vec4 edge : source_color;
uniform vec4 oxide : source_color;
uniform float coat_roughness = .59;
uniform float coat_metal = .40;
varying vec3 location;
varying vec3 orientation;

float hash21(vec2 at) {
	return fract(sin(dot(at, vec2(111.6, 234.8))) * 32615.47);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	location = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	orientation = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = location;
	vec2 salt_run = vec2(p.x * .73 + p.z * .67, p.y);
	float grain = noise21(p.xz * 51.3 + p.y * 31.6);
	float stain = noise21(salt_run * vec2(4.16, .64)) * .56
		+ noise21(salt_run * vec2(23.6, 2.4)) * .21 + grain * .23;
	float bare = smoothstep(.64, .85, stain + abs(orientation.y) * .09);
	float oxidized = smoothstep(.52, .81, noise21(p.xz * .47 + p.y * .39) * .48 + stain * .52);
	float scuff = smoothstep(.64, .82, noise21(vec2(salt_run.x * 73.0, salt_run.y * 6.0)))
		* smoothstep(.41, .74, stain);
	vec3 base = mix(paint.rgb * (.80 + grain * .25 + stain * .17), oxide.rgb, oxidized * .42);
	ALBEDO = mix(base, edge.rgb, bare * .47 + scuff * .25);
	ROUGHNESS = clamp(coat_roughness + oxidized * .23 - bare * .29 + grain * .07, .26, .94);
	METALLIC = clamp(coat_metal + bare * .37 - oxidized * .24, .02, .85);
}
