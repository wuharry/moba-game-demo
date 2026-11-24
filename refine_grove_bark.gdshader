shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec4 ridge : source_color = vec4(.45,.34,.25,1.0);
uniform vec4 fissure : source_color = vec4(.25,.20,.16,1.0);
uniform vec4 moss : source_color = vec4(.30,.35,.19,1.0);
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(117.4, 79.31))) * 43896.119);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), s.x),
		mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), s.x), s.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 point = vec2(world_position.x + world_position.z * .71, world_position.y);
	float bend = noise(point * vec2(2.2, 1.7));
	float strand = noise(point * vec2(29.0,1.40) + vec2(bend*2.4,0.0));
	float crack = smoothstep(.18,.54,strand);
	float footing = (1.0 - COLOR.g) * noise(point * vec2(2.9,2.0));
	vec3 base = mix(fissure.rgb, ridge.rgb, crack);
	base = mix(base, moss.rgb, smoothstep(.19,.39,footing));
	ALBEDO = base * (.86 + bend*.22 + COLOR.r*.17);
	ROUGHNESS = .93;
}
