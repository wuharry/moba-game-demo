shader_type sky;

uniform sampler2D panorama : source_color, filter_linear, repeat_disable;
uniform float cloud_warmth = 0.0;
uniform float energy = 1.0;
uniform float clear_sky_tint = 1.0;

void sky() {
    // Bring the lit upper lobes of the western bank down behind the foothills.
    // The displacement goes to zero at either side of the bank and at both poles.
    float bank_offset = (SKY_COORDS.x - .134) / .042;
    float west = exp(-bank_offset*bank_offset);
    float altitude_band = smoothstep(.10,.33,SKY_COORDS.y) * (1.0-smoothstep(.44,.62,SKY_COORDS.y));
    vec2 uv = SKY_COORDS - vec2(.011,.074)*west*altitude_band*clear_sky_tint;
    vec3 paint = texture(panorama, uv).rgb;
    float sky_blue = 1.0-smoothstep(.27,.74,paint.r);
    vec3 day = paint*mix(vec3(1.), vec3(.61,1.02,.954),sky_blue);
    float rim = smoothstep(.40,.84,paint.r)*west;
    day += (vec3(1.)-day)*rim*vec3(.43,.50,.35);
    // A cooler body separates the sunlit edge from the hazy ridge underneath.
    float body = west*smoothstep(.43,.77,paint.r);
    day.r *= 1.0 - body*.125*(1.0-.40*smoothstep(.89,.98,paint.g));
    day.b = mix(day.b,1.0,body*.73);
    vec3 sky_color = mix(paint,day,clear_sky_tint);
    // Warm the illuminated lobes. Keep their painted luma structure, cool bases and blue gaps.
    float cloud = smoothstep(.43,.92,paint.r) * smoothstep(.48,.88,paint.g);
    float cloud_value = dot(sky_color,vec3(.2126,.7152,.0722));
    vec3 ivory = cloud_value * vec3(1.045,1.012,.91);
    // Roll off the brightest painted lobes without flattening their red channel.
    vec3 peak = max(ivory - vec3(.94), vec3(0.0));
    ivory = min(ivory, vec3(.94)) + .056 * peak / (.056 + peak);
    // Spread the west bank's warm air across the horizon only.
    float west_horizon = (SKY_COORDS.x-.134)/.105;
    float low_sky = smoothstep(.34,.485,SKY_COORDS.y)*(1.0-smoothstep(.50,.57,SKY_COORDS.y));
    float scattered = cloud_warmth*low_sky*exp(-west_horizon*west_horizon)*(1.0-cloud);
    sky_color = mix(sky_color,vec3(.97,.855,.73),.20*scattered);
    sky_color = mix(sky_color, ivory, cloud_warmth*cloud);
    COLOR = sky_color*energy;
}
