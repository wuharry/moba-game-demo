shader_type spatial;
uniform sampler2D ground_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 surface_tint : source_color = vec4(.88,.92,.92,1.0);
uniform float apron = 0.0;
varying vec3 world_position;

float hash21(ivec2 p) {
	uint key = uint(p.x) * 0x8da6b343u ^ uint(p.y) * 0xd8163841u;
	key = (key ^ (key >> 13u)) * 0xcb1ab31fu;
	key ^= key >> 16u;
	return float(key & 0x00ffffffu) / 16777215.0;
}

float noise21(vec2 p) {
	ivec2 g = ivec2(floor(p));
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash21(g), hash21(g+ivec2(1,0)), f.x),mix(hash21(g+ivec2(0,1)),hash21(g+ivec2(1,1)),f.x), f.y);
}

vec3 map_tile(vec2 p, float row) {
	vec2 mirrored = 1.0 - abs(mod(p,2.0)-1.0);
	vec2 uv = vec2(.012,.012) + mirrored*.474 + vec2(0.0,row*.5);
	return texture(ground_atlas,uv).rgb;
}

vec3 brush_sample(vec2 field, ivec2 key, float row) {
	float phase = hash21(key);
	float angle = floor(phase * 4.0) * 1.5707963;
	mat2 basis = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
	vec2 p = basis * (field - vec2(key)) * .77 + vec2(phase, hash21(key + ivec2(5,31)));
	return map_tile(p, row);
}

vec3 brush_layer(vec2 field, float row) {
	ivec2 key = ivec2(floor(field));
	vec2 edge = smoothstep(vec2(.07), vec2(.93), fract(field));
	return mix(
		mix(brush_sample(field,key,row), brush_sample(field,key+ivec2(1,0),row), edge.x),
		mix(brush_sample(field,key+ivec2(0,1),row), brush_sample(field,key+ivec2(1,1),row), edge.x), edge.y);
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
	vec3 primer = brush_layer(p*.255 + w*.17,1.0);
	vec3 aggregate = map_tile(vec2(-p.y,p.x)*.52 + vec2(3.27,0.2)+w*.14,1.0);
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
	// Asphalt wears down along the real route. The repaired casting only
	// meets the raised pressure inlet and service pump, not the full pad.
	float paint_break = (noise21(p * vec2(1.81, .78)) - .5);
	vec2 shaped = p - vec2(.67, -5.6);
	vec2 cast_p = mat2(vec2(.973, -.230), vec2(.230,.973)) * shaped;
	float gate_patch = max(abs(cast_p.x) - (2.06 + .27 * paint_break),
		abs(cast_p.y) - (2.19 + .37 * w.x));
	float inlet_repair = (1.0 - smoothstep(-.24,.06,gate_patch)) * apron;
	float pump_cast = smoothstep(.2,.85,bay_patch) * shoulder * apron * .74;
	float casting = max(inlet_repair, pump_cast);
	float chalk = smoothstep(.43,.74, noise21(p * vec2(.86,.49) + 13.4));
	vec3 fresh_cast = mix(primer * vec3(1.06,1.12,1.08), aggregate * vec3(1.24,1.25,1.08), .34);
	fresh_cast *= .94 + chalk * .21;
	float seam_line = (1.0 - smoothstep(.014,.067,abs(gate_patch + .08))) * apron * (.55 + chalk * .30);
	float road_grain = noise21(p * 15.2 + 1.93);
	float cold_coarse = smoothstep(.21,.78,noise21(p * vec2(.26,.47) + 16.5));
	float chip = smoothstep(.78,.96,road_grain) * (1.0-traffic*.75) * (1.0-casting*.45);
	float seep_tongue = (1.0 - smoothstep(.03,.53,curb_run + paint_break * .16)) * (.37+.51*chalk) * apron;
	float salt_edge = (1.0-smoothstep(.075,.17,abs(curb_run - (.43+paint_break*.14))))
		* smoothstep(.23,.77,noise21(p * vec2(1.76,.68))) * apron;
	vec3 base = asphalt * warmer * platform *
		(.86 + stone_repair*.20-wet*.24 + traffic*.20 - repairs*.10 - basin_streak*.078
		- bay_patch*.10 - grease*.27 - puddle * .13);
	base = mix(base, base * vec3(.75,.79,.78), cold_coarse * (.26 - traffic*.12));
	base = mix(base, fresh_cast, casting * .73);
	base = mix(base, base * vec3(.51,.66,.71), seep_tongue * .56 + seam_line * .43);
	base = mix(base, fresh_cast * vec3(1.33,1.27,1.11), salt_edge * .37 + chip * .16);
	ALBEDO = base * surface_tint.rgb * COLOR.rgb;
	ROUGHNESS = clamp(.91-wet*.21+weeds*.06-puddle*.28-seep_tongue*.18-casting*.05,.34,.98);
	SPECULAR = .29 + seep_tongue * .12;
	float grain = dot(aggregate, vec3(.2126,.7152,.0722));
	vec3 shifted = VERTEX + NORMAL * (grain*.011 + road_grain*.0017) * (1.0 - puddle *.63);
	vec3 relief = normalize(cross(dFdx(shifted), dFdy(shifted)));
	relief *= dot(relief,NORMAL) < 0.0 ? -1.0 : 1.0;
	NORMAL = normalize(mix(NORMAL, relief, .53));
}
