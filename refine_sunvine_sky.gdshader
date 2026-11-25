shader_type sky;

uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 sun_dir = vec3(0.458, 0.682, 0.570);
uniform vec4 sky_zenith : source_color = vec4(0.08, 0.31, 0.72, 1.0);
uniform vec4 sky_mid : source_color = vec4(0.24, 0.56, 0.89, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.68, 0.87, 0.96, 1.0);
uniform vec4 sun_blush : source_color = vec4(0.99, 0.93, 0.80, 1.0);
uniform vec4 cloud_lit : source_color = vec4(1.00, 0.99, 0.95, 1.0);
uniform vec4 cloud_mid : source_color = vec4(0.86, 0.92, 0.98, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.55, 0.69, 0.87, 1.0);
uniform vec4 cloud_rim : source_color = vec4(1.00, 0.97, 0.84, 1.0);

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n00 = mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x);
	float n10 = mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x);
	float n01 = mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x);
	float n11 = mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x);
	return mix(mix(n00, n10, f.y), mix(n01, n11, f.y), f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	v += 0.50 * vnoise3(p);
	v += 0.27 * vnoise3(p * 2.09 + vec3(4.1, 1.7, -3.2));
	v += 0.14 * vnoise3(p * 4.23 + vec3(-2.8, 6.3, 1.9));
	v += 0.09 * vnoise3(p * 8.51 + vec3(7.4, -4.2, 5.1));
	return v;
}

float puff_lobe(vec3 dir, vec3 center_dir, vec2 scale_xy, float base_y) {
	vec3 c = normalize(center_dir);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), c));
	vec3 up = cross(c, right);
	vec2 local = vec2(dot(dir - c, right) / scale_xy.x, dot(dir - c, up) / scale_xy.y);
	// Crisp flat perspective cumulus base
	if (dir.y < base_y) {
		local.y -= (base_y - dir.y) * 18.0;
	}
	return 1.0 - length(local);
}

// Seamless 3D directional cloud density field (zero UV wrap seams anywhere!)
float cloud_density(vec3 dir) {
	float billow = fbm3(dir * 14.5 + vec3(1.2, 0.4, -0.8));
	float cauliflower = abs(fbm3(dir * 31.0 - vec3(2.1, -1.3, 0.7)) * 2.0 - 1.0);
	float sculpt = billow * 0.44 - cauliflower * 0.17;

	// Hero multi-tiered Genshin cumulus anvil behind left-center & right peaks
	float m1 = puff_lobe(dir, vec3(-0.22, 0.21, -0.95), vec2(0.11, 0.065), 0.125);
	m1 = max(m1, puff_lobe(dir, vec3(-0.14, 0.25, -0.96), vec2(0.075, 0.068), 0.125));
	m1 = max(m1, puff_lobe(dir, vec3(-0.30, 0.18, -0.93), vec2(0.085, 0.050), 0.125));
	m1 = max(m1, puff_lobe(dir, vec3(-0.07, 0.19, -0.97), vec2(0.070, 0.048), 0.125));

	// Second grand cumulus bank over right peaks
	float m2 = puff_lobe(dir, vec3(-0.62, 0.19, -0.76), vec2(0.13, 0.062), 0.115);
	m2 = max(m2, puff_lobe(dir, vec3(-0.54, 0.24, -0.80), vec2(0.082, 0.068), 0.115));
	m2 = max(m2, puff_lobe(dir, vec3(-0.71, 0.17, -0.68), vec2(0.095, 0.048), 0.115));

	// Floating distant cumulus puffs around rest of horizon
	float m3 = puff_lobe(dir, vec3(0.24, 0.18, -0.95), vec2(0.11, 0.055), 0.110);
	m3 = max(m3, puff_lobe(dir, vec3(0.32, 0.22, -0.92), vec2(0.075, 0.058), 0.110));
	float m4 = puff_lobe(dir, vec3(0.75, 0.20, 0.62), vec2(0.16, 0.070), 0.115);
	float m5 = puff_lobe(dir, vec3(-0.45, 0.21, 0.86), vec2(0.16, 0.070), 0.115);

	float raw = max(max(m1, m2), max(m3, max(m4, m5)));
	return raw + sculpt;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sdir = normalize(sun_dir);
	float y = clamp(dir.y, 0.0, 1.0);
	float sun_cos = max(0.0, dot(dir, sdir));

	// Rich Mondstadt/Fontaine cerulean sky dome
	vec3 col = mix(sky_horizon.rgb, sky_mid.rgb, smoothstep(0.0, 0.22, y));
	col = mix(col, sky_zenith.rgb, smoothstep(0.18, 0.76, y));

	float horizon_band = pow(1.0 - y, 3.5);
	col = mix(col, sun_blush.rgb, horizon_band * pow(sun_cos, 2.5) * 0.34);
	col += vec3(1.0, 0.95, 0.82) * pow(sun_cos, 16.0) * 0.10;
	if (!AT_CUBEMAP_PASS) {
		col += vec3(1.0, 0.97, 0.88) * smoothstep(0.9985, 0.9997, sun_cos) * 1.30;
	}

	if (dir.y > 0.02) {
		// Delicate high-altitude anime cirrus ribbons (seamless 3D, full screen resolution!)
		float wisp = fbm3(vec3(dir.x * 5.8, dir.y * 25.0, dir.z * 5.8));
		float cirrus = smoothstep(0.63, 0.84, wisp) * smoothstep(0.14, 0.24, y) * (1.0 - smoothstep(0.34, 0.54, y));
		col = mix(col, vec3(0.91, 0.97, 1.0), cirrus * 0.46);

		// GDC 2021 Cumulus Cloud + Real Directional Sun-Offset Volumetric Self-Shadowing!
		float d_here = cloud_density(dir);
		float horizon_fade = smoothstep(0.05, 0.12, y) * (1.0 - smoothstep(0.36, 0.52, y));
		float cov = smoothstep(0.13, 0.21, d_here) * horizon_fade;

		if (cov > 0.002) {
			vec3 light_step = normalize(mix(sdir, vec3(0.0, 1.0, 0.0), 0.45));
			float d_sunward = cloud_density(normalize(dir + light_step * 0.028));
			float d_deep = cloud_density(normalize(dir + light_step * 0.058));
			float internal_fold = fbm3(dir * 22.0 + vec3(3.1, 1.4, -2.2));

			// Balanced 3-step cel shading: periwinkle shadow belly + soft blue-cream mid + bright ivory crown!
			float occ = (d_sunward - d_here) * 5.2 + (d_deep - d_here) * 2.8;
			float light_val = clamp(0.44 - occ * 0.72 + smoothstep(0.11, 0.26, y) * 0.34 + (internal_fold - 0.5) * 0.24, 0.0, 1.0);

			vec3 c_col = mix(cloud_shadow.rgb, cloud_mid.rgb, smoothstep(0.28, 0.48, light_val));
			c_col = mix(c_col, cloud_lit.rgb, smoothstep(0.58, 0.76, light_val));

			float outer_edge = (1.0 - smoothstep(0.19, 0.28, d_here)) * smoothstep(0.56, 0.82, light_val);
			c_col += cloud_rim.rgb * outer_edge * 0.32;

			c_col = mix(sky_horizon.rgb, c_col, smoothstep(0.06, 0.13, y));
			col = mix(col, c_col, cov * 0.96);
		}
	} else {
		vec3 bounce = vec3(0.45, 0.51, 0.41);
		col = mix(sky_horizon.rgb * 0.82, bounce, smoothstep(0.0, 0.35, -dir.y));
	}

	COLOR = col;
}
