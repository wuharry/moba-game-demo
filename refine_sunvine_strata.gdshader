shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 recessed_bed : source_color = vec4(0.44, 0.43, 0.34, 1.0);
uniform vec4 exposed_bed : source_color = vec4(0.72, 0.65, 0.49, 1.0);
uniform vec4 ledge_moss : source_color = vec4(0.38, 0.48, 0.30, 1.0);

varying vec3 world;
varying vec3 normal_world;

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
}

void fragment() {
	float above = normalize(normal_world).y;
	float clouding = field(world * vec3(.58, .91, .58));
	float grain = field(world * vec3(7.8, 14.2, 8.5));
	float layers = world.y * 2.91 - world.x * .36 - world.z * .20 + .51 * clouding;
	float division = smoothstep(.70, .94, sin(layers) * .50 + .50);
	float weather = field(world * .221) * .68 + clouding * .32;
	vec3 bed = mix(recessed_bed.rgb, exposed_bed.rgb, smoothstep(.28, .73, weather));
	bed *= 1.0 - division * (.20 + clouding * .14) * (1.0 - max(above, .0) * .54);
	float growth = smoothstep(.37, .76, weather + .25 * smoothstep(.43, .93, above));
	ALBEDO = mix(bed, ledge_moss.rgb, growth * smoothstep(.36, .92, above) * .88);
	ALBEDO *= .91 + grain * .13;
	ROUGHNESS = .92;
	SPECULAR = .16;
}
