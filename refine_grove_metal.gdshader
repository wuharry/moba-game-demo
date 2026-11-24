shader_type spatial;
render_mode diffuse_burley;

uniform vec4 patina : source_color;
uniform vec4 rubbed : source_color;
uniform vec4 deep : source_color;
varying vec3 world_p;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(93.8, 17.63, 64.1))) * 33652.83);
}

float weather(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 w = f * f * (3.0 - 2.0*f);
	float low = mix(mix(hash(i),hash(i+vec3(1,0,0)),w.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),w.x),w.y);
	float high = mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),w.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),w.x),w.y);
	return mix(low, high, w.z);
}

void vertex() {
	world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float scale = weather(world_p*vec3(3.4, 1.74, 4.1));
	float hairline = weather(world_p*vec3(108.0, 9.2, 106.0));
	float abrasion = smoothstep(.40,.78,scale*.77 + hairline*.23);
	float stain = smoothstep(.32,.76,weather(world_p*vec3(8.9,1.4,9.9)) + weather(world_p*2.0)*.18);
	ALBEDO = mix(mix(patina.rgb, deep.rgb, stain*.76), rubbed.rgb, abrasion*.78);
	ROUGHNESS = mix(.64,.35,abrasion*.85) + hairline*.09;
	METALLIC = .24 + abrasion*.37;
	SPECULAR = .40;
}
