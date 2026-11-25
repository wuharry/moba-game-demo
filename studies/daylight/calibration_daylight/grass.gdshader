shader_type spatial;
#include "res://calibration_daylight/environment_fill.gdshaderinc"
render_mode cull_disabled, specular_disabled, ambient_light_disabled;
#include "res://calibration_daylight/meadow_shared.gdshaderinc"
uniform float transmission_strength = 0.0;
varying float blade_tip;
uniform bool animate_wind=false;
uniform float frozen_time=0.0;
varying vec3 world_pos;
varying vec3 authored_normal;
varying flat vec3 root_position;
varying flat vec3 ground_up;
varying float instance_phase;
varying flat float stand_height;
varying flat float painted_herb;
varying flat float sedge_fold;
varying flat float meadow_warmth;
varying flat float authored_stand_tip;
void vertex(){
    root_position=MODEL_MATRIX[3].xyz;
    vec2 field_uv=(root_position.xz-ground_edge_bounds.xy)/max(ground_edge_bounds.zw,vec2(1.0));
    vec2 slope=textureLod(ground_edge_field,field_uv,0.0).ba*2.0-1.0;
    ground_up=normalize(vec3(slope.x,sqrt(max(.001,1.0-dot(slope,slope))),slope.y));
    instance_phase=INSTANCE_CUSTOM.g*6.28318;
    stand_height=INSTANCE_CUSTOM.r;
    painted_herb=1.0-INSTANCE_CUSTOM.a;
    sedge_fold=painted_herb*INSTANCE_CUSTOM.b;
    meadow_warmth=max(0.0,INSTANCE_CUSTOM.b)*(1.0-painted_herb);
    authored_stand_tip=clamp(-INSTANCE_CUSTOM.b,0.0,1.0)*(1.0-painted_herb);
    // Only ordinary grass inside the scuffed limestone foothill is grazed.
    // The field also controls the soil pigment directly beneath these roots.
    if (painted_herb<.5 && root_position.x>-35.0 && root_position.x<1.0 &&
        root_position.z>3.0 && root_position.z<19.0){
        float scuff=textureLod(habitat_wash,meadow_habitat_uv(root_position.xz),0.0).a;
        float grazed=smoothstep(.25,.90,scuff);
        VERTEX.y*=mix(1.0,.23+.14*INSTANCE_CUSTOM.g,grazed);
        VERTEX.xz*=mix(1.0,.71,grazed);
    }
    authored_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    float phase=animate_wind ? TIME : frozen_time;
    float sway=mix(1.0, .28+.72*stand_height, painted_herb);
    VERTEX.x+=sway*sin(phase*1.7+instance_phase+world_pos.x*.17+world_pos.z*.24)*.09*UV.y*UV.y;
    VERTEX.z+=sway*sin(phase+world_pos.x*.11)*.04*UV.y*UV.y;
}
void fragment(){
    SPECULAR=0.0;
    // Fragment assignment prevents the two-sided backface from inverting the intended meadow normal.
    float quiet_clearing;
    vec3 col=meadow_color_sample(root_position,1.0,quiet_clearing);
    // On the open east landing the short, fine growth holds a broad cool
    // value. Let fewer edge highlights break it than on the tufted margins.
    quiet_clearing *= 1.0-painted_herb;
    float local_face=mix(.16,.40,smoothstep(.09,.83,UV.y))*(1.0-.28*quiet_clearing);
    local_face=mix(local_face,.18+.62*smoothstep(.04,.58,UV.y),sedge_fold);
    vec3 meadow_normal=normalize(mix(ground_up,authored_normal,local_face));
    NORMAL=normalize((VIEW_MATRIX*vec4(meadow_normal,0.0)).xyz);
    float height=smoothstep(.0,.95,UV.y);
    // Short blades disappear into their sampled ground colour. Longer bent
    // leaves carry a shared, warmer upper band across the sunlit verge.
    float windrow=smoothstep(-.75,.8,sin(root_position.x*.23+root_position.z*.42));
    vec3 tip=col*mix(vec3(1.025,1.04,.97),vec3(1.14,1.085,.80),windrow);
    tip*=mix(vec3(1.0),vec3(1.12,1.06,.74),meadow_warmth);
    tip+=stand_height*(.22+.78*windrow)*vec3(.065,.037,.002);
    // P34-C only: marked new stands keep broader, calmer tips; roots and
    // existing grass pigments are untouched, as is the lighting function.
    tip*=mix(vec3(1.0),vec3(.85,.88,.94),authored_stand_tip);
    // Basal leaves turn cool in the lower sweep, with one side of each
    // folded blade catching the light as it leans. Values stay tied to turf.
    vec3 basal=col*vec3(.78,.84,.96)+vec3(.0,.0,.010);
    vec3 grass=mix(basal,tip,height);
    float fold=(.5-UV.x)*.14 + .065*exp(-abs(UV.x-.48)*10.0);
    grass*=1.0+fold*(.38+.62*sin(height*PI));
    // A cuff of turf pigment covers each buried sheath without stochastic alpha.
    grass=mix(col,grass,smoothstep(.045,.36,UV.y)*(1.0-.28*quiet_clearing));
    // Broad painted laminae, folded leaf ridges and straw husks share the
    // ground wash near their stems, then retain their own authored pigment.
    vec3 organ_pigment=vec3(UV2.rg,UV.x);
    float herb_pigment=.25+.66*smoothstep(.015,.28,UV.y);
    vec3 herb=mix(col,organ_pigment,herb_pigment);
    blade_tip = height;
    ALBEDO=mix(grass,herb,painted_herb);
    ROUGHNESS=1.0;

}
void light(){
    float diffuse=smoothstep(-.10,.90,dot(NORMAL,LIGHT));
    DIFFUSE_LIGHT+=LIGHT_COLOR/PI*(.05+.95*diffuse)*ATTENUATION+environment_irradiance();
    float backlit = smoothstep(-.10,.91,dot(-VIEW,LIGHT));
    DIFFUSE_LIGHT += LIGHT_COLOR/PI*vec3(1.,.88,.46)*(.52*transmission_strength)*blade_tip*backlit*ATTENUATION;
}
