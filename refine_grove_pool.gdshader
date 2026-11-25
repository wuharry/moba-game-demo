shader_type spatial;
render_mode depth_draw_never;

varying vec3 world_p;
// Hash the integer lattice so adjacent cells agree on their shared ends.
float h(ivec2 p) {
	uint key = uint(p.x) * 0x8da6b343u ^ uint(p.y) * 0xd8163841u;
	key = (key ^ (key >> 13u)) * 0xcb1ab31fu;
	key ^= key >> 16u;
	return float(key & 0x00ffffffu) / 16777215.0;
}
float n(vec2 p) {
	ivec2 i=ivec2(floor(p));
	vec2 f=fract(p);
	vec2 q=f*f*(3.0-2.0*f);
	return mix(mix(h(i),h(i+ivec2(1,0)),q.x),mix(h(i+ivec2(0,1)),h(i+ivec2(1,1)),q.x),q.y);
}
float caustic_cells(vec2 p) {
	vec2 cell = floor(p);
	vec2 uv = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y=-1; y<=1; y++) {
		for (int x=-1; x<=1; x++) {
			ivec2 grid = ivec2(cell) + ivec2(x,y);
			vec2 seed = vec2(h(grid),h(grid+ivec2(17,53)));
			seed = .5 + .34*sin(seed*6.28318 + TIME*.31);
			float d = length(vec2(float(x),float(y))+seed-uv);
			if (d<first) { second=first; first=d; }
			else { second=min(second,d); }
		}
	}
	return 1.0-smoothstep(.018,.075,second-first);
}
float crown(vec2 ray, vec2 root, vec2 span) {
	float d = length((ray - root) / span) + .36 * n(ray*2.23);
	return 1.0 - smoothstep(.30,1.20,d);
}

void vertex() {
	world_p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	vec2 p = world_p.xz;
	float depth = COLOR.r;
	float broad = n(p * vec2(.19,.13) + vec2(0.0,TIME*.028));
	float fine = n(p * vec2(1.81,2.33));
	float wave_a = sin(p.x*4.25+p.y*1.26 + broad*4.34 + TIME*.77);
	float wave_b = sin(p.y*5.7-p.x*1.27 + fine*2.1 - TIME*1.03);
	float grain = n(p*vec2(5.8,2.23)+vec2(-TIME*.085,TIME*.041));
	float light_web = pow(clamp(1.0 - abs(wave_a * .63 + wave_b * .37), 0.0, 1.0),5.8);
	float caustic = caustic_cells(p*1.12 + vec2(broad*.43,fine*.18));
	caustic *= smoothstep(.19,.58,broad)*.72;
	float sediment = n(p * vec2(.48,.34) + vec2(1.2,-3.4))*.68
		+ n(p * vec2(2.53,1.93))*.32;
	float shore_reach = mix(.19,.59,smoothstep(.19,.79,sediment));
	float shallow_weight = (1.0 - smoothstep(.016,shore_reach,depth));
	float swept_light = n(p * vec2(.21,.34) + vec2(broad * 2.1, .8));
	vec3 deep = mix(vec3(.011,.068,.086),vec3(.027,.143,.148),smoothstep(.29,.74,swept_light));
	float pebbles = smoothstep(.42,.66,n(p*5.87)) * .28;
	vec3 gravel = mix(vec3(.075,.171,.116),vec3(.218,.242,.151),sediment*.67+fine*.21+pebbles);
	vec3 bed = mix(deep, gravel, shallow_weight*.99);
	float east_bank = crown(p, vec2(7.6,2.6), vec2(2.5,4.2));
	float foot = crown(p, vec2(3.0,-3.0), vec2(3.2,2.28));
	float sunny_shallows = smoothstep(.25,.61,broad * .63 + sediment * .45) * shallow_weight;
	bed += vec3(.23,.235,.142) * light_web * sunny_shallows * (1.0 - grain*.42) * (.47 + east_bank * .53);
	float canopy_shade = max(crown(p,vec2(7.10,4.99),vec2(3.67,3.82)),
		crown(p,vec2(7.65,-4.63),vec2(3.1,3.89)));
	canopy_shade = max(canopy_shade, foot * .52);
	bed *= mix(vec3(1.0), vec3(.66,.81,.85), canopy_shade*.42);
	vec3 base_normal = NORMAL;
	NORMAL = normalize(base_normal + vec3(wave_a*.021,wave_b*.017,0.0));
	vec3 reflection = mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL);
	float fresnel = pow(clamp(1.0-dot(NORMAL,VIEW),0.0,1.0),3.0);
	float open_sky = smoothstep(.19,.76,reflection.y + (broad - .5)*.28);
	vec2 reflected_height = p + reflection.xz / max(reflection.y,.19) * 3.43;
	reflected_height += vec2(wave_a*.21 + wave_b*.12,wave_b*.19);
	float trees = max(crown(reflected_height,vec2(8.9,3.7),vec2(3.3,2.9)),
		crown(reflected_height,vec2(8.6,-5.4),vec2(3.0,2.7)));
	trees = max(trees,crown(reflected_height,vec2(2.1,-14.5),vec2(3.9,3.1)));
	float canopy_breaks = n(reflected_height * .53);
	vec3 sky = mix(vec3(.063,.170,.193),vec3(.161,.302,.334),open_sky);
	vec3 canopy = mix(vec3(.012,.027,.024),vec3(.046,.071,.040),canopy_breaks);
	vec3 reflected = mix(sky,canopy,trees*.84);
	float surface_visibility = .045 + fresnel * .20 + (1.0-shallow_weight)*.055;
	vec3 color = mix(bed,reflected,surface_visibility);
	float reflected_leaves = smoothstep(.43,.66,n(reflected_height * vec2(1.84,2.41)));
	color = mix(color, canopy * vec3(1.37,1.62,1.12), trees * reflected_leaves * (.09 + .32 * fresnel));
	float wind_lane = smoothstep(.50,.83,broad*.55+fine*.32+wave_a*.10);
	float glint = pow(clamp(wave_a*.48+wave_b*.18+grain*.34,0.0,1.0),6.0);
	// Follow the outlet at the foot of the four stone sills. The arc
	// widens downstream and breaks into short, moving capillary streaks.
	vec2 water_axis = normalize(vec2(-.91, -.414));
	vec2 outlet = p - vec2(6.69,-1.9);
	float downstream = dot(outlet, water_axis);
	float across = dot(outlet, vec2(-water_axis.y,water_axis.x));
	float flow_decay = smoothstep(-.08,.39,downstream) * (1.0 - smoothstep(1.7,3.9,downstream));
	float spread = 1.0 - smoothstep(.35,.86 + max(0.0,downstream) * .44,abs(across));
	float radial = sqrt(downstream*downstream*.80 + across*across*.40);
	float riffle = sin(radial * 9.8 - TIME * 1.72 + fine * 3.9 + swept_light * 2.3);
	float broken_ring = smoothstep(.38,.90,riffle);
	float break_up = smoothstep(.3,.78,n(p * vec2(2.28,3.13) + vec2(TIME * .10,.26)));
	float sill_glint = flow_decay * spread * broken_ring * break_up * (.72 - .49 * smoothstep(.62,2.21,downstream));
	float open_tracks = glint * wind_lane * (.44 + fresnel) * (1.0 - canopy_shade*.66);
	float near_bank = (1.0-smoothstep(.12,.71,depth));
	float foam_edge = smoothstep(.008,.024,depth)*(1.0-smoothstep(.039,.078,depth));
	foam_edge *= smoothstep(.26,.66,broad*.55+fine*.45)*.34;
	ALBEDO = color + vec3(.112,.154,.150) * open_tracks + vec3(.107,.185,.177) * sill_glint;
	ALBEDO += vec3(.12,.21,.16)*caustic*(.015+near_bank*.48);
	ALBEDO = mix(ALBEDO,vec3(.44,.62,.51),foam_edge);
	EMISSION = vec3(.009,.024,.022)*sill_glint + vec3(.006,.013,.010)*caustic*near_bank;
	ROUGHNESS = mix(.17,.24,broad) + shallow_weight*.045;
	SPECULAR = .26;
	float bottom_haze = smoothstep(.03,.63,depth);
	ALPHA = (mix(.37,.93,bottom_haze) + fresnel * .06 * (1.0-bottom_haze)) * smoothstep(.0,.024,depth);
}
