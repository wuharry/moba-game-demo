shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec4 pine_shadow : source_color = vec4(.27, .42, .33, 1.0);
uniform vec4 sun_rock : source_color = vec4(.53, .63, .51, 1.0);
uniform vec4 valley_floor : source_color = vec4(.43, .60, .51, 1.0);
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
	float exposure = max(0.0, dot(n, normalize(vec3(.43, .53, .65))));
	float broad = field(p * vec3(.096, .11, .096)) * .73 + field(p * .291) * .27;
	float slope = 1.0 - smoothstep(.29, .87, n.y);
	float fall_line = field(vec3((p.x + p.z * .66 + p.y * .21) * .36, p.y * .038, p.z * .032));
	float cut = smoothstep(.50, .82, fall_line) * smoothstep(.10, .85, slope + (broad - .5) * .33);
	float chalk = smoothstep(.35, .78, slope * .42 + exposure * .28 + broad * .30);
	float band_pigment = field(vec3(.081 * p.x, .33 * (p.y + p.x * .060) + broad * .61, .093 * p.z));
	float shelf = smoothstep(.42, .68, band_pigment) * .72 + broad * .28;
	vec3 stone = sun_rock.rgb * (.90 + shelf * .20);
	vec3 brush = pine_shadow.rgb * (.81 + broad * .34);
	vec3 material = mix(brush, stone, chalk * (.89 + cut * .11));
	vec3 face_color = mix(pine_shadow.rgb, material, .62 + detail_strength * .34);
	face_color *= (1.0 - cut * (.10 + detail_strength * .19)) * (.92 + .14 * exposure);
	float bank = smoothstep(-2.29, 1.73 + (broad - .5) * 1.04, p.y);
	ALBEDO = mix(valley_floor.rgb, face_color, bank);
	vec3 bottom_normal = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(bottom_normal, NORMAL, bank));
	ROUGHNESS = mix(.97, .95, bank);
}
