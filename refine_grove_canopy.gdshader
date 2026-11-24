shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 tint : source_color = vec4(.6,.37,.12,1.0);
uniform float using_vertex = 0.0;
varying vec3 at_world;
float hash(vec2 p) { return fract(sin(dot(p,vec2(41.7,269.3))) * 17358.5453); }
float n(vec2 p) {
	vec2 i=floor(p);
	vec2 f=fract(p);
	vec2 s=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),s.x),mix(hash(i+vec2(0.0,1.0)),hash(i+vec2(1.0,1.0)),s.x),s.y);
}
void vertex() { at_world=(MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p=at_world.xz + at_world.y * vec2(.62,-.43);
	vec3 pigment=mix(tint.rgb,COLOR.rgb,using_vertex);
	float chunks=n(p*.84);
	float grains=n(p*6.2);
	ALBEDO=pigment*(.86+chunks*.23+grains*.044);
	ROUGHNESS=.91;
	BACKLIGHT=pigment*vec3(.17,.19,.17);
}
