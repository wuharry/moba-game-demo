shader_type spatial;

uniform sampler2D painted_stone : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 stone : source_color = vec4(.69, .68, .56, 1.0);
uniform vec4 seam : source_color = vec4(.36, .35, .29, 1.0);
uniform vec4 lichen : source_color = vec4(.40, .47, .32, 1.0);
uniform float weathering = .48;
uniform float bedding = .51;
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
	float stains = field(world_p.xz*.64 + world_p.y*.71);
	float chips = field(local_p.xz*3.55 + vec2(local_p.y*3.77, -local_p.y*2.71));
	float level = local_p.y + local_p.x*.15 - local_p.z*.12;
	float vein = (level + .19*stains + .043*chips) / bedding;
	float seam_mask = (1.0 - smoothstep(.025,.11,abs(fract(vein + .5)-.5)))
		* (1.0-smoothstep(.55,.93,direction.y)) * (.42 + .46*stains);
	float canopy_spots = smoothstep(.40,.70,stains*.74+chips*.26) * weathering;
	float moss_mask = canopy_spots * (.29 + .71*smoothstep(.03,.88,direction.y));
	vec3 bedrock = mix(stone.rgb,seam.rgb,seam_mask);
	vec3 surface = mix(bedrock,lichen.rgb,moss_mask);
	ALBEDO = surface * mix(vec3(.73),paint, .61) * (.85 + .32*chips) * COLOR.rgb;
	ROUGHNESS = .85 + chips*.11 - moss_mask*.08;
	SPECULAR = .17;
}
