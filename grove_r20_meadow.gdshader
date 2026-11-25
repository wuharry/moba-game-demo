shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://grove_r20_meadow_shared.gdshaderinc"

varying vec3 root_world;
varying float tip;
varying float core;
varying float pigment_variation;

void vertex() {
	root_world = (MODEL_MATRIX * vec4(0.0,0.0,0.0,1.0)).xyz;
	tip = UV.y;
	core = INSTANCE_CUSTOM.r;
	pigment_variation = INSTANCE_CUSTOM.g;
	float wind = sin(root_world.x*.58 + root_world.z*.33 + TIME*1.38);
	VERTEX.x += .052 * wind * tip * tip;
	VERTEX.z += .027 * sin(root_world.z*.37 + TIME*.93) * tip * tip;
}

void fragment() {
	vec3 base = eval_grove_meadow(root_world.xz);
	vec3 tip_color = mix(base*vec3(.96,1.04,.95),base*vec3(.66,.80,.73),core);
	tip_color *= mix(.91,1.08,pigment_variation);
	ALBEDO = mix(base,tip_color,smoothstep(.14,1.0,tip));
	ROUGHNESS = .96;
	SPECULAR = .08;
	BACKLIGHT = ALBEDO * (.05+.06*tip);
}
