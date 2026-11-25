shader_type spatial;
#include "res://calibration_daylight/environment_fill.gdshaderinc"
render_mode cull_disabled, specular_disabled, ambient_light_disabled;
uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(0.43,0.73,0.67);
uniform float illustration_light : hint_range(0.0, 1.0) = 1.0;
uniform float transmission_strength = 0.0;
varying float thin_leaf;
uniform float wind_strength = 0.035;
uniform float frozen_time = 0.0;
uniform bool animate_wind = false;
varying flat float woody_surface;
varying vec3 world_pos;
varying vec3 local_pos;
varying vec3 authored_normal;
void vertex(){
    local_pos=VERTEX;
    woody_surface=max(1.0-step(.85,UV2.x),step(.5,UV2.y));
    authored_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    float phase=animate_wind ? TIME : frozen_time;
    VERTEX.x += sin(phase*1.4+world_pos.x*.7+world_pos.z*.4)*wind_strength*UV.y;
}
void fragment(){
    SPECULAR=0.0;
    NORMAL=normalize((VIEW_MATRIX*vec4(authored_normal,0.0)).xyz);
    vec4 tex=texture(leaves,UV);
    // GDC 23:04–24:22: fade grazing cards using their geometric normal,
    // while spherical normals continue to control the broad crown lighting.
    vec3 face_normal=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
    float facing=abs(dot(face_normal,normalize(-VERTEX)));
    float core=step(0.5,UV2.x);
    ALPHA=mix(tex.a*smoothstep(.08,.26,facing),1.0,core);
    ALPHA_SCISSOR_THRESHOLD=0.45;
    vec3 painted=mix(vec3(dot(tex.rgb,vec3(.23,.61,.16))),tex.rgb,.78);
    // Keep card details within the value range of their supporting bough.
    float upper=smoothstep(-.38,.93,authored_normal.y);
    vec3 foliage_tone=mix(vec3(.13,.37,.25),vec3(.31,.55,.23),upper);
    vec3 leafy=mix(foliage_tone,painted*tint,.36)*COLOR.rgb;
    vec3 solid=COLOR.rgb;
    if (UV2.x>.55 && UV2.x<.85) {
        // Two orientations of the authored leafy atlas break up the interior
        // seen through spray gaps. Its opacity stays continuous like a bough.
        vec4 brush=texture(leaves,fract(local_pos.xy*.62+local_pos.z*.18));
        vec4 fleck=texture(leaves,fract(local_pos.zy*.90-local_pos.x*.15));
        solid*=.88+.28*brush.a*dot(brush.rgb,vec3(.20,.64,.16))+.10*fleck.a;
    }
    if (UV2.y>.5) {
        // A shaded stand has continuous cool foliage under its brighter tips.
        // The texture adds short leaf strokes while the bough governs the value.
        solid=mix(COLOR.rgb,solid,.72);
        leafy=COLOR.rgb*(.86+.29*dot(painted,vec3(.25,.59,.16)));
    }
    vec3 foliage=mix(leafy,solid,core);
    if (UV2.y<.5 && UV2.x<.85) {
        // Shade in the original coppice overlaps with the riparian shrubs.
        vec2 bank=(world_pos.xz-vec2(-1.5,-7.5))/vec2(16.0,10.0);
        float shelter=1.0-smoothstep(.39,1.21,length(bank));
        foliage*=mix(vec3(1.0),vec3(.70,1.05,1.10),shelter);
    }
    thin_leaf = (1.0-core)*smoothstep(.18,.79,UV.y);
    ALBEDO=foliage;
    ROUGHNESS=1.0;

}
void light(){
    float incidence=dot(NORMAL,LIGHT);
    float diffuse=smoothstep(-.30,.80,incidence);
    vec3 continuous=vec3(.08+.92*diffuse);
    // Soft joins make the clump read as one painted plane at play distance.
    // It still follows the sun direction and the received directional shadow.
    vec3 planes=mix(vec3(.085,.16,.215),vec3(.52,.654,.64),smoothstep(.09,.29,incidence));
    planes=mix(planes,vec3(1.13,1.065,.93),smoothstep(.55,.74,incidence));
    vec3 direct=mix(continuous,planes,woody_surface*illustration_light*.87);
    DIFFUSE_LIGHT+=LIGHT_COLOR/PI*direct*mix(.35,1.0,ATTENUATION)+environment_irradiance();
    float backlit = smoothstep(-.15,.91,dot(-VIEW,LIGHT)) * (1.0-smoothstep(.0,.67,incidence));
    DIFFUSE_LIGHT += LIGHT_COLOR/PI*vec3(1.0,.89,.46)*transmission_strength*thin_leaf*backlit*ATTENUATION;
}
