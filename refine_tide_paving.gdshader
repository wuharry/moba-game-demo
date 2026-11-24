shader_type spatial;
uniform sampler2D ground_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 surface_tint : source_color = vec4(.88,.92,.92,1.0);
uniform float apron = 0.0;
varying vec3 world_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(129.7,311.1))) * 34756.51);
}

float noise21(vec2 p) {
	vec2 g = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash21(g), hash21(g+vec2(1.0,0.0)), f.x),mix(hash21(g+vec2(0.0,1.0)),hash21(g+vec2(1.0)),f.x), f.y);
}

vec3 map_tile(vec2 p, float row) {
	vec2 mirrored = 1.0 - abs(mod(p,2.0)-1.0);
	vec2 uv = vec2(.012,.012) + mirrored*.474 + vec2(0.0,row*.5);
	return texture(ground_atlas,uv).rgb;
}

float segment_distance(vec2 point, vec2 a, vec2 b) {
	vec2 leg = b - a;
	return length(point - a - leg * clamp(dot(point - a, leg) / dot(leg, leg), 0.0, 1.0));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	vec2 w = vec2(noise21(p*.32), noise21(p*.27 + 17.0));
	vec3 primer = map_tile(p*.253 + w*.19,1.0);
	vec3 aggregate = map_tile(vec2(-p.y,p.x)*.43 + vec2(3.27,0.2)+w*.12,1.0);
	float edge_x = -.60 + sin(p.y*.21)*.65;
	float verge = max(1.0-smoothstep(.08,1.6,p.x-edge_x), smoothstep(7.8,11.4,p.x));
	float track = min(segment_distance(p,vec2(5.35,15.2),vec2(3.5,7.0)),
		min(segment_distance(p,vec2(3.5,7.0),vec2(.7,2.5)),
			min(segment_distance(p,vec2(.7,2.5),vec2(2.3,-3.6)),
				segment_distance(p,vec2(2.3,-3.6),vec2(7.3,-8.4)))));
	float traffic = (1.0 - smoothstep(.58, 1.98, track + (w.x - .5) * .38)) * apron;
	float weeds = smoothstep(.49,.83,w.x*.55+w.y*.45) * verge * (1.0-traffic*.88);
	float runoff = (1.0-smoothstep(.13,1.4,abs(p.x+1.51+sin(p.y*.53)*.56))) * .32;
	float curb_run = min(segment_distance(p, vec2(-1.19, 10.1), vec2(-.43, 3.9)),
		segment_distance(p, vec2(-.43, 3.9), vec2(.21, 1.1)));
	float puddle = (1.0 - smoothstep(.08, .40, curb_run + (noise21(p * vec2(2.2, .82)) - .5) * .35))
		* (.31 + noise21(p * vec2(2.1, .62)) * .69) * apron;
	float catchbasin = 1.0 - smoothstep(.24, 1.0, length((p - vec2(8.68, 5.69)) * vec2(.55, .81)));
	float basin_streak = catchbasin * smoothstep(.22, .69, noise21(p * vec2(3.75, 1.5)));
	runoff += basin_streak * .24;
	float wet = smoothstep(.47,.77,noise21(p*.51)*.7+noise21(p*1.13)*.3+runoff + puddle * .64);
	vec3 asphalt = mix(primer,aggregate,.25+w.y*.30);
	asphalt = mix(asphalt, map_tile(p*.30+w*.22,0.0), weeds*.84);
	float stone_repair = smoothstep(.45,.80,w.x*.44+w.y*.56);
	vec3 warmer = mix(vec3(1.0), vec3(1.12,1.085,0.99), traffic *.58);
	float repairs = smoothstep(.42, .79, noise21(p*.145 + vec2(5.89,7.4))) * apron;
	float service_cut = 4.69 + sin((p.y + 5.3) * .15) * .22;
	float shoulder = smoothstep(-.14, .27, p.x - service_cut + (noise21(p * 4.8) - .5) * .089) * apron;
	float bay_patch = 1.0 - max(smoothstep(1.26, 1.36, abs(p.x - 6.43)), smoothstep(2.13, 2.22, abs(p.y + .67)));
	float west_walk = 1.0 - smoothstep(.0, .12, p.x - (edge_x + .78) + (w.x - .5) * .11);
	west_walk *= apron * (1.0 - smoothstep(11.8, 14.6, p.y));
	vec3 seal = mix(vec3(.70,.85,.94), vec3(.83,.94,.96), stone_repair);
	vec3 platform = mix(vec3(1.0), seal, shoulder * (.86 - traffic * .57));
	platform = mix(platform, vec3(1.20, 1.22, 1.18), west_walk * .60);
	float grease = (1.0 - smoothstep(.34, 1.16, length((p - vec2(6.70, .65)) * vec2(.9, .55))))
		* noise21(p * 3.86) * apron;
	float cracks = smoothstep(.94, 1.0, abs(sin(p.y * 3.7 + w.x * 6.1 + p.x * 2.38)))
		* smoothstep(.62, .87, noise21(p * .81)) * .62;
	ALBEDO = asphalt * surface_tint.rgb * COLOR.rgb * warmer * platform *
		(.86 + stone_repair*.20-wet*.24 + traffic*.20 - repairs*.10 - basin_streak*.078
		- bay_patch*.10 - grease*.27 - cracks * .19 - puddle * .13);
	ROUGHNESS = clamp(.88-wet*.45+weeds*.06-puddle*.36,.21,.98);
	SPECULAR = .39;
	float grain = dot(aggregate, vec3(.2126,.7152,.0722));
	vec3 shifted = VERTEX + NORMAL * grain * .009;
	vec3 relief = normalize(cross(dFdx(shifted), dFdy(shifted)));
	relief *= dot(relief,NORMAL) < 0.0 ? -1.0 : 1.0;
	NORMAL = normalize(mix(NORMAL, relief, .53));
}
