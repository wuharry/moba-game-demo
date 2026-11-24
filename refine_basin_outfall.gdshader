shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform bool aerated_fall = false;
uniform bool shelf_film = false;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(114.31, 274.97))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), t.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), t.x), t.y);
}

void fragment() {
	float currents = noise(vec2(UV.x * 17.0 + 0.75 * sin(UV.y * 5.0), UV.y * 1.9 - TIME * 2.4));
	float tear = noise(vec2(UV.x * 8.2, UV.y * 13.0 - TIME * 3.7));
	float boundary = sin(clamp(UV.x, 0.0, 1.0) * 3.14159265);
	float wet_streak = smoothstep(0.28, 0.82, currents * .8 + tear * .2);
	float foam = smoothstep(.64, .96, UV.y) * wet_streak;
	float fade = smoothstep(.03, .14, UV.y) * (1.0 - smoothstep(.89, 1.0, UV.y));
	ALBEDO = mix(vec3(.08, .18, .18), vec3(.36, .49, .48), wet_streak * .9);
	EMISSION = vec3(.04, .09, .096) * foam;
	ROUGHNESS = mix(.28, .64, foam);
	ALPHA = fade * boundary * (.52 + wet_streak * .39);
	if (aerated_fall) {
		float jets = smoothstep(.04, .79, currents * .74 + tear * .26);
		float froth = smoothstep(.39, .81, UV.y) * jets;
		ALBEDO = mix(vec3(.08,.16,.17), vec3(.52,.63,.61), jets * (.35 + froth * .65));
		EMISSION = vec3(.032,.058,.056) * (.49 * jets + froth * .51);
		ALPHA = fade * boundary * (.53 + jets * .43);
	}
	if (shelf_film) {
		float wavering = noise(vec2(UV.x * 11.81 + sin(UV.y * 6.0) * .39, UV.y * 5.51 - TIME * 2.33));
		float shifts = smoothstep(.30,.82, noise(vec2(UV.x * 5.82, UV.y * 10.31 - TIME * 1.91)));
		float streaks = smoothstep(.51, .91, currents * .45 + shifts * .30 + wavering * .38);
		ALBEDO = mix(vec3(.085,.150,.159), vec3(.37,.48,.465), streaks * .82);
		EMISSION = vec3(.026,.067,.065) * (.29 + streaks * .63);
		ROUGHNESS = .64;
		SPECULAR = .24;
		ALPHA = pow(boundary, 1.35) * fade * (.40 + streaks * .49);
	}
}
