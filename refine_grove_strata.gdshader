shader_type spatial;

uniform sampler2D painted_stone : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 stone : source_color = vec4(.69, .68, .56, 1.0);
uniform vec4 seam : source_color = vec4(.36, .35, .29, 1.0);
uniform vec4 lichen : source_color = vec4(.40, .47, .32, 1.0);
uniform float weathering = .48;
uniform float bedding = .51;
uniform float ridge_weathering = 0.0;
varying vec3 world_p;
varying vec3 world_n;
varying vec3 local_p;

float hash(vec2 p) { return fract(sin(dot(p, vec2(132.1, 317.3))) * 43758.24); }
float field(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t *= t * (3.0 - 2.0 * t);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), t.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), t.x), t.y);
}

vec3 paint_at(vec2 p) {
	vec2 uv = (1.0 - abs(mod(p * .22, 2.0) - 1.0)) * .976 + .012;
	return texture(painted_stone, vec2(uv.x*.5, uv.y)).rgb;
}

void vertex() {
	world_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = MODEL_NORMAL_MATRIX * NORMAL;
	local_p = VERTEX;
}

void fragment() {
	vec3 direction = normalize(world_n);
	vec3 weights = pow(abs(direction), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, .001);
	vec3 paint = weights.x * paint_at(world_p.zy) + weights.y * paint_at(world_p.xz)
		+ weights.z * paint_at(world_p.xy);
	// Broad pigment planes carry the illustration; fine noise must not
	// become sandy speckle on every stone and distant mountain alike.
	float stains = field(world_p.xz*.36 + world_p.y*.31);
	float chips = field(local_p.xz*.93 + vec2(local_p.y*.81, -local_p.y*.67));
	float level = local_p.y + local_p.x*.15 - local_p.z*.12;
	float vein = (level + .19*stains + .043*chips) / bedding;
	float seam_mask = (1.0 - smoothstep(.025,.11,abs(fract(vein + .5)-.5)))
		* (1.0-smoothstep(.55,.93,direction.y)) * (.42 + .46*stains);
	float canopy_spots = smoothstep(.40,.70,stains*.74+chips*.26) * weathering;
	float moss_mask = canopy_spots * (.29 + .71*smoothstep(.03,.88,direction.y));
	vec3 bedrock = mix(stone.rgb,seam.rgb,seam_mask*.52);
	vec3 surface = mix(bedrock,lichen.rgb,moss_mask);
	if (ridge_weathering > .0) {
		float runnel = field(vec2(local_p.x*.38 - local_p.y*.21, local_p.z*.31+local_p.y*.09));
		float broad = field(vec2(local_p.x*.25+local_p.z*.33, local_p.y*.23));
		float strata_level = (local_p.y + local_p.x*.32 - local_p.z*.14 + broad*.41) / bedding;
		float bedding_color = smoothstep(.22,.86,field(vec2(floor(strata_level),local_p.z*.07)));
		float oxide = smoothstep(.34,.81,broad*.53 + stains*.26 + runnel*.21);
		vec3 face = mix(stone.rgb*vec3(.85,.95,1.02),stone.rgb*vec3(1.035,1.0,.93),oxide);
		face = mix(face, seam.rgb, (1.0-smoothstep(.027,.095,abs(fract(strata_level+.5)-.5)))
			*.17*(1.0-smoothstep(.55,.95,direction.y))*(.50+.5*runnel));
		float leaf_bank = smoothstep(.38,.77,broad*.57 + stains*.20 + runnel*.32);
		leaf_bank *= (.31+.69*smoothstep(.17,.83,direction.y)) * (.95-.31*smoothstep(1.9,8.8,local_p.y));
		face = mix(face, lichen.rgb, leaf_bank*.55);
		face *= mix(.95,1.055,bedding_color)*(.95+.085*runnel);
		surface = mix(surface,face,ridge_weathering);
	}
	ALBEDO = surface * mix(vec3(.75),paint, .36) * (.92 + .14*chips) * COLOR.rgb;
	ROUGHNESS = .88 + chips*.065 - moss_mask*.035;
	SPECULAR = .17;
}
