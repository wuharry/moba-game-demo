shader_type sky;

float hash3(vec3 p) {
	p = fract(p * .1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float cloud_field(vec3 p) {
	vec3 i = floor(p);
	vec3 t = fract(p); t = t*t*(3.0-2.0*t);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),t.x),
		mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),t.x),t.y),
		mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),t.x),
		mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),t.x),t.y),t.z);
}
void sky() {
	float altitude = max(EYEDIR.y,0.0);
	vec3 sunlight = normalize(vec3(-.67,.60,.43));
	float sunward = pow(max(dot(EYEDIR,sunlight),0.0),7.0);
	vec3 clear_sky = mix(vec3(.64,.79,.83),vec3(.11,.34,.57),smoothstep(.0,.72,altitude));
	clear_sky += vec3(.08,.048,.013) * sunward;
	vec3 q = EYEDIR * vec3(6.2,9.5,6.2) + vec3(3.4,.8,-1.6);
	float broad = cloud_field(q);
	float shape = broad * .78 + cloud_field(q * 2.7) * .22;
	float density = smoothstep(.52,.69,shape) * smoothstep(.035,.19,altitude);
	float toward_light = cloud_field(q+sunlight*.25);
	float lit = clamp(.57 + (broad-toward_light)*2.7 + altitude*.30,0.0,1.0);
	vec3 cloud = mix(vec3(.45,.59,.69),vec3(.95,.94,.85),lit);
	cloud += vec3(.055,.042,.016) * sunward;
	COLOR = mix(clear_sky,cloud,density*.94);
}
