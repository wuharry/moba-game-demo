shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform float channel_mid = -7.03;
uniform float channel_width = 3.08;
uniform bool seepage_detail = false;
uniform bool geographic_water = false;
uniform bool retention_pool = false;
uniform bool contact_riffles = false;
uniform bool spring_inflow = false;
uniform bool cut_flow = false;
uniform bool soft_sky_return = false;
uniform bool flood_bays = false;
uniform bool spillway_depth = false;
varying vec3 p;

float h(vec2 key) {
	return fract(sin(dot(key, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 pt) {
	vec2 i = floor(pt);
	vec2 f = fract(pt);
	vec2 s = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), s.x),
		mix(h(i + vec2(0, 1)), h(i + vec2(1)), s.x), s.y);
}

float spreading_wake(vec2 point, vec2 contact) {
	vec2 ripple = point - contact;
	float down = max(0.0, -ripple.y);
	float shoulders = .12 + down * .22;
	float pulse = noise(vec2(point.x * 6.1, point.y * 3.18 + TIME * .23));
	float curl = abs(abs(ripple.x + down * .035) - shoulders);
	return smoothstep(.02, .27, -ripple.y) * (1.0 - smoothstep(.22, 1.94, down))
		* (1.0 - smoothstep(.024, .22, curl)) * (.31 + pulse * .69);
}

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = p.xz;
	float current = noise(vec2(q.x * 2.1, q.y * .98 - TIME * .16));
	float wash = noise(vec2(q.x * 3.4 + current * 0.4, q.y * 2.5 - TIME * .3));
	float wind = sin(q.y * 15.0 + q.x * 4.1 + current * 11.0 - TIME * 2.2);
	float shore = (channel_width * 0.5 - abs(q.x - channel_mid)) + (current - .5) * .06;
	if (flood_bays) {
		float outer = -8.56 - .99 * exp(-pow((q.y + 7.78) / 2.9, 2.0)) - .65 * exp(-pow((q.y - 3.65) / 2.2, 2.0));
		shore = min(q.x - outer, -5.49 - q.x) + (current - .5) * .08;
	}
	float edge = (1.0 - smoothstep(0.03, 0.35, shore)) * smoothstep(.46, .82, wash + wind * .10);
	float reflected = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 3.3);
	vec3 blue = mix(vec3(0.028, 0.081, 0.091), vec3(0.065, 0.138, 0.156), current);
	if (seepage_detail) {
		float event = max(1.0 - smoothstep(.25, 1.95, abs(q.y + 12.4)),
			(1.0 - smoothstep(.18, 1.4, abs(q.y - 1.5))) * .52);
		float baseline = smoothstep(.28, .62, noise(vec2(q.x * 4.0, q.y * 3.2 - TIME * .21)));
		float drift = 1.0 - smoothstep(.4, 1.41, abs(channel_mid - q.x + sin(q.y * .28) * .31));
		blue = mix(blue, blue * vec3(.65, .84, .99), .35 * drift);
		edge = clamp(edge * .52 + event * baseline * (1.0 - smoothstep(.06, .63, shore)) * .48, 0.0, 1.0);
	}
	if (geographic_water) {
		float channel_flow = noise(vec2(q.x * 3.33 + sin(q.y * .29) * 2.13, q.y * .54 + TIME * .075));
		float threads = noise(vec2(q.x * 13.3 + sin(q.y * .72) * 1.22, q.y * 1.1 + TIME * .31));
		float depth = smoothstep(.12, .92, shore + (channel_flow - .5) * .29);
		blue = mix(vec3(.057,.104,.097), vec3(.024,.062,.078), depth);
		blue += vec3(.012,.026,.024) * (channel_flow * .65 + threads * .35);
		edge = max(spreading_wake(q, vec2(-7.72, 4.71)), spreading_wake(q, vec2(-6.17,-5.64)));
		edge = max(edge, spreading_wake(q, vec2(-8.08,-10.50)) * .87);
		edge *= .51;
		wind *= .19;
		reflected *= .73;
	}
	if (retention_pool) {
		float drift = noise(vec2(q.x * .73 + q.y * .21, q.y * .97 - TIME * .11));
		float throat = smoothstep(-21.2, -16.3, q.y);
		float depth = smoothstep(.15, .89, 1.0 - abs(q.x + 5.55 + 1.19 * throat) / 7.7);
		blue = mix(vec3(.068, .108, .095), vec3(.022, .055, .072), depth);
		blue += vec3(.011, .031, .030) * drift;
		float gate_wakes = max(1.0 - smoothstep(.25, 1.28, abs(q.x + 7.04 - drift * .41)),
			1.0 - smoothstep(.20, 1.14, abs(q.x + 3.13 + drift * .28)));
		float running_foam = smoothstep(-21.64, -20.86, q.y) * (1.0 - smoothstep(-20.72, -18.09, q.y));
		edge = gate_wakes * running_foam * smoothstep(.49, .8, wash) * .68;
		wind *= .16;
		reflected *= .79;
	}
	if (contact_riffles) {
		float drift_bank = noise(vec2(q.x * 1.9, q.y * .42));
		float shallow = 1.0 - smoothstep(.16, .77, shore + drift_bank * .46);
		blue = mix(blue * vec3(.84, .83, .87), vec3(.105, .139, .103), shallow * .52 + edge * .11);
		float ripples = abs(sin((wind * .12 + q.y * 3.32 + drift_bank * 2.4) - TIME * .71));
		edge = max(edge, shallow * smoothstep(.80, .95, ripples) * wash * .24);
		reflected *= .69;
	}
	if (spring_inflow) {
		vec2 inflow = (q - vec2(-8.31, -7.64)) * vec2(.73, 1.0);
		float ring = length(inflow);
		float churn = noise(vec2(q.x * 4.1 - TIME * .33, q.y * 2.7 + TIME * .21));
		float expanding = abs(sin(ring * 10.6 - TIME * 1.7 + churn * 4.2));
		float spread = (1.0 - smoothstep(.3, 1.51, ring)) * smoothstep(.36, .76, churn);
		float dark_runnel = smoothstep(.05, .83, shore);
		blue = mix(blue * vec3(.83, .92, .89), vec3(.023, .054, .052), dark_runnel * .25);
		edge = max(edge, spread * smoothstep(.49, .87, expanding) * .74);
		reflected *= .77;
	}
	if (cut_flow) {
		// Turbulence is localized where falling water enters the cut.
		vec2 impact = (q - vec2(-8.30,-7.65)) * vec2(.86,.64);
		float ripple_radius = length(impact);
		float pulse = noise(vec2(q.x * 6.4, q.y * 3.8 + TIME * .69));
		float broken_arc = smoothstep(.75,.96,abs(sin(ripple_radius * 17.2 - TIME * 3.9 + pulse * 2.9)));
		float turbulent = 1.0 - smoothstep(.12,1.65,ripple_radius);
		float drop = max(0.0,-impact.y);
		float thread_x = (impact.x - drop * .35) * 7.5;
		float foam_trail = (1.0 - smoothstep(.16,.79,abs(thread_x))) * smoothstep(.17,.42,drop) * (1.0 - smoothstep(.85,2.52,drop));
		edge = max(edge, broken_arc * turbulent * (.35 + pulse * .56));
		edge = max(edge, foam_trail * smoothstep(.42,.69,wash) * .41);
		float depth = smoothstep(.12,1.03,shore + (current - .53) * .30);
		vec3 bank_colour = mix(vec3(.065,.136,.122),vec3(.035,.065,.085),depth);
		blue = mix(blue, bank_colour * (.93 + pulse * .15), .55);
		wind += sin(q.y * 22.0 - TIME * 1.9 + q.x * 6.0 + pulse * 3.5) * .29;
	}
	if (spillway_depth) {
		float outfall_basin = 1.0 - smoothstep(.29, 2.58, length((q - vec2(-8.30,-7.82)) * vec2(1.0,.61)));
		float sandbar = smoothstep(.36,.82,noise(q * vec2(1.12,.36) + vec2(4.2,.32)));
		float shallows = (1.0 - smoothstep(.075,.68,shore + current * .18)) * (.33 + sandbar * .67);
		vec3 glaucous = mix(vec3(.021,.052,.068), vec3(.073,.177,.166), shallows * .62 + sandbar * .17);
		blue = mix(blue, glaucous, .68);
		blue = mix(blue, vec3(.067,.166,.163), outfall_basin * .78);
		edge *= .73 + outfall_basin * .43;
	}
	blue = mix(blue, vec3(0.136, 0.215, 0.247), reflected * .54);
	ALBEDO = mix(blue, vec3(0.43, 0.52, 0.48), edge * 0.65);
	ROUGHNESS = cut_flow ? .23 + current * .17 + edge * .38 :
		.23 + current * .16 + edge * .37 + (contact_riffles || retention_pool ? .11 : .0);
	SPECULAR = cut_flow ? .42 : (spring_inflow ? .14 : (contact_riffles || retention_pool ? .29 : .43));
	if (soft_sky_return) {
		ROUGHNESS += .043 + wash * .036;
		SPECULAR = .25;
	}
	float relief = (wind * .005 + current * .016) * (geographic_water ? .25 : 1.0);
	vec3 displaced = VERTEX + NORMAL * relief;
	vec3 water_normal = normalize(cross(dFdx(displaced), dFdy(displaced)));
	if (dot(water_normal, NORMAL) < 0.0) {
		water_normal = -water_normal;
	}
	NORMAL = normalize(mix(NORMAL, water_normal, .40));
}
