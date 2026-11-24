shader_type spatial;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D ground_sheet : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float waterline = -.72;
varying vec3 world_p;
varying vec3 world_n;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float field(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),s.x),
		mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),s.x),s.y);
}

void vertex() {
	world_p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_n = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec2 p = world_p.xz;
	float broad = field(p*.43);
	float medium = field(p*1.5);
	float detail = field(p*8.0);
	float growth = field(p*vec2(.17,.21)+vec2(1.2,-.9));
	float moss_mask = smoothstep(.27,.82,growth*.73+broad*.24+medium*.07);
	float meadow = smoothstep(.26,.71,field(p*vec2(.15,.10)+vec2(8.3,2.7)));
	vec3 grass = mix(vec3(.062,.104,.056), vec3(.196,.229,.111), moss_mask);
	grass = mix(grass,grass*vec3(1.25,1.14,.93),meadow*.47);
	vec2 turf_uv = (1.0-abs(mod(p*.149 + vec2(broad*.38, medium*.12), 2.0)-1.0)) * .966+.017;
	vec3 turf = texture(ground_sheet, vec2(.5 + turf_uv.x * .5, turf_uv.y * .5)).rgb;
	grass = mix(grass,turf*vec3(.36,.46,.35),.20);
	grass *= .90+detail*.12;
	vec2 warped = p * .152 + vec2(broad * .23, medium * .10);
	warped = (1.0-abs(mod(warped, 2.0)-1.0)) * .976 + .012;
	vec3 pigment = texture(atlas, vec2(warped.x*.5, warped.y)).rgb;
	vec3 sand = texture(ground_sheet, vec2(.5 + warped.x*.5,.5 + warped.y*.5)).rgb;
	vec3 moss = texture(ground_sheet, warped*.5).rgb;
	float travel = smoothstep(.52,.88,COLOR.r);
	vec3 shoulder = vec3(.168,.137,.094);
	vec3 crushed = vec3(.246,.213,.157);
	vec3 soil = mix(mix(shoulder,crushed,travel*.61),sand*vec3(.60,.57,.51),.30)
		* (.90+.09*medium+.041*detail);
	float slope = smoothstep(.18, .50, 1.0-abs(normalize(world_n).y));
	vec3 base = mix(grass, soil, max(pow(COLOR.r,.67)*.93,slope*.69));
	float outcrop = field(vec2((p.x-p.y*.17)*.37,p.y*.58)+vec2(-3.6,4.0));
	float shelves = field(vec2((p.x+p.y*.31)*.66,p.y*.28));
	float stone_mask = smoothstep(.34,.70,slope*.54+outcrop*.35+shelves*.24)
		* smoothstep(.23,1.46,world_p.y) * (1.0-COLOR.r);
	vec3 exposed = mix(vec3(.173,.174,.119),pigment*vec3(.59,.57,.43),.66)
		* (.76+outcrop*.21+detail*.10);
	base = mix(base,exposed,stone_mask*.71);
	float shore_cells = field(p*vec2(.61,.88)+vec2(2.4,6.1))*.62+medium*.38;
	vec3 damp = mix(base*vec3(.35,.46,.38),moss*vec3(.57,.67,.49),.44+shore_cells*.27);
	float wet_mask = COLOR.b * (.38+smoothstep(.17,.73,shore_cells)*.59+detail*.07);
	float below = 1.0-smoothstep(waterline-.17,waterline+.05,world_p.y);
	float silt = field(p*1.97) * .42 + shore_cells*.58;
	vec3 bed = mix(vec3(.074,.102,.059),vec3(.176,.163,.099),silt) * (.88+medium*.21);
	ALBEDO = mix(mix(base,damp,wet_mask),bed,below);
	ROUGHNESS = mix(mix(.82,.98,medium),.61,wet_mask*.58) - stone_mask*.07;
	SPECULAR = .18;
}
