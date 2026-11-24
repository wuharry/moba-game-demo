shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec4 pine_shadow : source_color = vec4(.27, .42, .33, 1.0);
uniform vec4 sun_rock : source_color = vec4(.53, .63, .51, 1.0);
uniform float detail_strength = .7;
varying vec3 p;
varying vec3 ground_normal;

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float hash(vec3 q) {
	return fract(sin(dot(q, vec3(127.1, 311.7, 99.2))) * 43758.5453);
}

float field(vec3 pos) {
	vec3 i = floor(pos);
	vec3 f = fract(pos);
	vec3 w = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), w.x),
		mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), w.x), w.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), w.x),
		mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), w.x), w.y), w.z);
}

void fragment() {
	vec3 n = normalize(ground_normal);
	float exposure = max(0.0, dot(n, normalize(vec3(.41, .72, .45))));
	float broad = field(p * vec3(.10, .14, .12)) * .67 + field(p * .37) * .33;
	float ridge = smoothstep(.38, .66, field(vec3(p.x * .12, p.y * .21 + p.x * .072, p.z * .096)));
	float steep = 1.0 - smoothstep(.24, .68, n.y);
	vec3 whiskers = vec3((p.x - p.y * .31) * .182, p.y * .082, p.z * .26);
	float clefts = smoothstep(.26, .66, field(whiskers) * .70 + field(whiskers * 2.42) * .30);
	float rocky = smoothstep(.27, .74, broad * .37 + exposure * .41 + steep * .31 + detail_strength * ridge * .16);
	vec3 material = mix(pine_shadow.rgb, sun_rock.rgb, rocky);
	ALBEDO = material * (0.79 + broad * .27 + (detail_strength + .12) * .17 * ridge);
	ALBEDO *= 1.0 - clefts * steep * (.11 + detail_strength * .11);
	ROUGHNESS = .95;
}
