// R20 original ground pigment; shared by terrain and grass roots.
float grove_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}

float grove_field(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f*f*(3.0-2.0*f);
	return mix(mix(grove_hash(i),grove_hash(i+vec2(1.0,0.0)),s.x),
		mix(grove_hash(i+vec2(0.0,1.0)),grove_hash(i+vec2(1.0,1.0)),s.x),s.y);
}

vec3 eval_grove_meadow(vec2 p) {
	float broad = grove_field(p*.43);
	float growth = grove_field(p*vec2(.17,.21)+vec2(1.2,-.9));
	float pigment = smoothstep(.23,.83,growth*.77+broad*.23);
	float dry_shoulder = smoothstep(.38,.77,grove_field(p*vec2(.11,.083)+vec2(8.3,2.7)));
	// Linear pigments: cool woodland recesses, sage middle plane, warm autumn turf.
	vec3 grass = mix(vec3(.068,.130,.079),vec3(.173,.254,.112),pigment);
	grass = mix(grass,grass*vec3(1.17,1.04,.88),dry_shoulder*.34);
	return grass * (.965+.047*grove_field(p*1.1));
}
