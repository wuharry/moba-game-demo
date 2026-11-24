shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 recessed_bed : source_color = vec4(0.44, 0.43, 0.34, 1.0);
uniform vec4 exposed_bed : source_color = vec4(0.72, 0.65, 0.49, 1.0);
uniform vec4 ledge_moss : source_color = vec4(0.38, 0.48, 0.30, 1.0);

varying vec3 world;
varying vec3 normal_world;
varying vec3 bedding;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float field(vec3 p) {
	vec3 cell = floor(p);
	vec3 d = fract(p);
	d = d*d*(3.0-2.0*d);
	float low = mix(mix(hash(cell), hash(cell + vec3(1,0,0)), d.x),
		mix(hash(cell + vec3(0,1,0)), hash(cell + vec3(1,1,0)), d.x), d.y);
	float high = mix(mix(hash(cell + vec3(0,0,1)), hash(cell + vec3(1,0,1)), d.x),
		mix(hash(cell + vec3(0,1,1)), hash(cell + vec3(1,1,1)), d.x), d.y);
	return mix(low, high, d.z);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	bedding = COLOR.rgb;
}

void fragment() {
	float above = normalize(normal_world).y;
	float washes = field(world * vec3(.38, .57, .31)) * .62 + field(world * vec3(1.18, 1.21, .65)) * .38;
	float grain = field(world * vec3(7.8, 14.2, 8.5));
	float seams = world.y * 3.91 - world.x * .295 - world.z * .28 + field(world * vec3(.29, .58, .24)) * 1.25;
	float division = smoothstep(.72, .97, sin(seams) * .50 + .50);
	float leaching = smoothstep(.44, .76, field(world * vec3(.93, .22, .86)) * .76 + washes * .24);
	float weather = washes * .72 + .28 * bedding.x;
	vec3 bed = mix(recessed_bed.rgb, exposed_bed.rgb, smoothstep(.215, .74, weather));
	bed = mix(bed, vec3(.43, .34, .23), leaching * .18 * (1.0 - max(above, .0)));
	bed *= 1.0 - division * .24 * (1.0 - max(above, .0) * .60) * smoothstep(.22, .70, washes);
	float growth = smoothstep(.47, .85, washes * .53 + .24 * bedding.y + .37 * max(above, .0));
	float lichen = smoothstep(.6, .82, field(world * 1.53)) * bedding.z;
	ALBEDO = mix(bed, ledge_moss.rgb, growth * .92);
	ALBEDO = mix(ALBEDO, ledge_moss.rgb * .72, lichen * .31) * (.89 + grain * .17);
	ROUGHNESS = .92;
	SPECULAR = .16;
}
