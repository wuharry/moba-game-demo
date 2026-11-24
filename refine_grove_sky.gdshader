shader_type sky;

float h(vec2 p) { return fract(sin(dot(p, vec2(79.1,129.7))) * 17358.5453); }
float n(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f*f*(3.0-2.0*f);
	return mix(mix(h(i),h(i+vec2(1.0,0.0)),s.x),mix(h(i+vec2(0.0,1.0)),h(i+vec2(1.0,1.0)),s.x),s.y);
}
void sky() {
	float horizon = max(0.0, EYEDIR.y);
	vec3 color = mix(vec3(.62,.76,.73),vec3(.13,.35,.55),smoothstep(0.0,.68,horizon));
	vec3 to_sun = normalize(vec3(-.39,.45,-.80));
	float rim = pow(max(dot(EYEDIR,to_sun),0.0),5.0);
	color += vec3(.19,.134,.052) * rim;
	if (EYEDIR.y > 0.02) {
		vec2 plane = EYEDIR.xz/max(.29,EYEDIR.y+.22);
		float skirts = n(plane*.9+vec2(4.1,1.8))*.60+n(plane*1.9+vec2(-.8,4.1))*.27+n(plane*4.8)*.13;
		float cloud = smoothstep(.49,.71,skirts) * smoothstep(.03,.19,horizon);
		color = mix(color,vec3(.91,.91,.79)+rim*vec3(.17,.105,.042),cloud*.76);
	}
	COLOR = color;
}
