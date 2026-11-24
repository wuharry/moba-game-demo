shader_type sky;

float h(ivec2 p) {
	uint key = uint(p.x) * 0x8da6b343u ^ uint(p.y) * 0xd8163841u;
	key = (key ^ (key >> 13u)) * 0xcb1ab31fu;
	key ^= key >> 16u;
	return float(key & 0x00ffffffu) / 16777215.0;
}
float n(vec2 p) {
	ivec2 i = ivec2(floor(p));
	vec2 f = fract(p);
	vec2 s = f*f*(3.0-2.0*f);
	return mix(mix(h(i),h(i+ivec2(1,0)),s.x),mix(h(i+ivec2(0,1)),h(i+ivec2(1,1)),s.x),s.y);
}
void sky() {
	float horizon = max(0.0, EYEDIR.y);
	vec3 color = mix(vec3(.67,.76,.73),vec3(.12,.33,.54),smoothstep(0.0,.66,horizon));
	vec3 to_sun = normalize(vec3(-.67,.60,.43));
	float rim = pow(max(dot(EYEDIR,to_sun),0.0),5.0);
	float warm_haze = (1.0-smoothstep(.08,.57,horizon)) * (.52 - .36*EYEDIR.x);
	color += vec3(.19,.105,.051)*warm_haze + vec3(.17,.089,.035)*rim;
	if (EYEDIR.y > 0.02) {
		vec2 plane = EYEDIR.xz/max(.29,EYEDIR.y+.22);
		vec2 stratus = vec2(plane.x*.64,plane.y*2.4+plane.x*.28);
		float skirts = n(stratus+vec2(4.1,1.8))*.65+n(stratus*2.3+vec2(-.8,4.1))*.24+n(stratus*4.8)*.11;
		float cloud = smoothstep(.53,.81,skirts) * smoothstep(.06,.23,horizon);
		color = mix(color,vec3(.89,.87,.77)+rim*vec3(.17,.105,.042),cloud*.68);
	}
	COLOR = color;
}
