shader_type spatial;
render_mode cull_disabled, specular_disabled, alpha_to_coverage;

uniform sampler2D foliage_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(.6,.37,.12,1.0);
uniform float using_vertex = 0.0;
varying vec3 at_world;
varying vec3 crown_pigment;
varying float shell_ao;
varying float card_mode;
varying vec3 crown_world_normal;
varying float crown_height;

void vertex() {
	at_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	crown_pigment = mix(tint.rgb,COLOR.rgb,using_vertex);
	shell_ao = COLOR.a;
	card_mode = UV2.x;
	crown_height = UV2.y;
	crown_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	float gust = sin(dot(at_world.xz,vec2(.53,-.31))-TIME*1.35);
	VERTEX.xz += vec2(.73,-.41) * gust * .035 * shell_ao;
}

void fragment() {
	// Other users (lily pads, reeds and ground flowers) are solid geometry.
	vec4 leaf = mix(vec4(1.0),texture(foliage_atlas,UV),step(.5,card_mode));
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = .43;
	ALPHA_ANTIALIASING_EDGE = .25;
	// Reapply the authored field after automatic two-sided normal handling.
	// An outer bough normal is independent of the individual card winding.
	if (card_mode > .5) {
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(crown_world_normal),0.0)).xyz);
	}
	float painted_value = clamp((leaf.g-.32)/.68,0.0,1.0);
	vec3 body = crown_pigment;
	if (card_mode > .5) {
		float warmth = smoothstep(.025,.16,body.r - body.b);
		vec3 cool_under = mix(vec3(.73,.91,1.04),vec3(.84,.78,.93),warmth);
		vec3 warm_top = mix(vec3(1.07,1.04,.88),vec3(1.08,1.04,.94),warmth);
		body *= mix(cool_under,warm_top,smoothstep(.12,.84,crown_height));
	}
	ALBEDO = body * mix(.77,1.09,painted_value);
	ROUGHNESS = .92;
	AO = mix(.86,1.0,shell_ao);
	AO_LIGHT_AFFECT = .22;
	BACKLIGHT = crown_pigment * vec3(.19,.22,.13);
}

void light() {
	// Only direct light is added here; sky/ambient remains Environment's job.
	float wrap = clamp((dot(NORMAL,LIGHT)+.23)/1.23,0.0,1.0);
	float sunlight = smoothstep(.02,.88,wrap);
	float transmission = pow(max(dot(VIEW,-LIGHT),0.0),3.0) * .13;
	DIFFUSE_LIGHT += ALBEDO * (sunlight + transmission) * ATTENUATION * LIGHT_COLOR / PI;
}
