shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform bool spillway = false;
varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_point.xz;
	vec2 outlet = p - vec2(-4.92, .22);
	vec2 axis = normalize(vec2(-.06, .99));
	float run = dot(outlet, axis);
	float across = dot(outlet, vec2(-axis.y, axis.x));
	float reach = smoothstep(-.10, .25, run) * (1.0 - smoothstep(.8, 2.5, run));
	float fan = (1.0 - smoothstep(.02, .48 + max(0.0, run) * .32, abs(across)));
	float current = (run + across * across * .43) * 11.0 - TIME * 2.19;
	float ripples = (.7 * sin(current) + .3 * sin(current * 1.56 + across * 4.4)) * fan * reach;
	float quiet = sin(dot(p, vec2(.84,1.27)) + TIME * .51) * .4 +
		sin(dot(p, vec2(1.43,-.95)) + TIME * .67) * .26;
	vec3 displaced = VERTEX + NORMAL * (.018 * ripples + quiet * .006);
	vec3 adjusted = normalize(cross(dFdx(displaced), dFdy(displaced)));
	adjusted *= dot(adjusted, NORMAL) < 0.0 ? -1.0 : 1.0;
	NORMAL = normalize(mix(NORMAL, adjusted, .81));
	float dark_suspension = smoothstep(.60, 2.9, length((p - vec2(-4.81, 2.22)) * vec2(1.22, .75)));
	vec3 body = mix(vec3(.017,.067,.078), vec3(.044,.122,.110), dark_suspension);
	float angle = pow(1.0 - clamp(dot(NORMAL, VIEW),0.0,1.0),3.0);
	vec3 sky = mix(vec3(.077,.157,.174), vec3(.132,.183,.171),
		smoothstep(.04, .93, across * .45 + quiet * .38));
	float crease = smoothstep(.28, .82, ripples) * (.65 + quiet * .28);
	float shallow = smoothstep(1.12, 2.21, length((p - vec2(-4.81, 2.22)) * vec2(1.18, .73)));
	float reflected_light = smoothstep(.28, .91, sin(p.x * 2.7 - p.y * .59 + quiet)) * shallow;
	vec3 tint = mix(body, sky, angle * .69 + reflected_light * .25) + vec3(.10,.139,.119) * crease;
	float roughness = .25 + .07 * quiet + .12 * crease;
	if (spillway) {
		float fissures = .54 + .21 * sin(UV.x * 41.0 - UV.y * 15.0 + TIME * .29)
			+ .10 * sin(UV.x * 85.5 + UV.y * 28.0);
		float fringe = sin(UV.y * 26.4 - TIME * 2.9 + sin(UV.x * 3.11) * 1.72);
		float breaks = smoothstep(.21, .72, fringe * fissures + quiet * .68);
		float sheen = sin(clamp(UV.x,0.0,1.0) * 3.14159) * (.24 + .48 * breaks);
		tint = mix(vec3(.055,.108,.096), vec3(.201,.318,.272), sheen);
		roughness = mix(.52,.22,sheen);
	}
	ALBEDO = tint;
	ROUGHNESS = roughness;
	SPECULAR = .32;
}
