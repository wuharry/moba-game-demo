shader_type spatial;
#include "res://calibration_daylight/environment_fill.gdshaderinc"
render_mode ambient_light_disabled;
#include "res://calibration_daylight/meadow_shared.gdshaderinc"
uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bedding_mask : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 stone_color : source_color=vec3(.595,.600,.590);
uniform bool meadow=false;
uniform bool clay_mode=false;
uniform float illustration_light : hint_range(0.0, 1.0) = 1.0;
varying float exposed_rock;
varying float wide_face;
varying float miniature_bank;
varying vec3 world_pos;
varying vec3 world_normal;
// Three frequency bands from our own paint source; this is not the original game's shader.
vec3 rock_band(vec3 p,vec3 weights,float scale){
    return texture(paint,p.zy*scale).rgb*weights.x+texture(paint,p.xz*scale).rgb*weights.y+texture(paint,p.xy*scale).rgb*weights.z;
}

// A bed has a common dip on adjacent cliff faces. Top faces use an oblique
// plan section. Independent offsets avoid duplicating a seam around a corner.
vec4 mineral_beds(vec3 p, vec3 weights, float scale) {
    vec2 section_x = vec2(p.z, -p.y + .105*p.z - .045*p.x);
    vec2 section_z = vec2(p.x, -p.y + .105*p.z - .045*p.x);
    vec2 plan = vec2(.86*p.x+.51*p.z, -.51*p.x+.86*p.z);
    vec2 repeat_scale = vec2(.075, .118) * scale;
    return texture(bedding_mask, section_x*repeat_scale+vec2(.23,.18))*weights.x
         + texture(bedding_mask, plan*repeat_scale+vec2(.47,.69))*weights.y
         + texture(bedding_mask, section_z*repeat_scale+vec2(.73,.34))*weights.z;
}

// A finite, pinching fracture in the rock section. The worn edge is a pale
// mineral deposit, so its colour stays independent of the sun direction.
vec2 bed_parting(vec2 section, vec2 midpoint, float span, float slope, float width) {
    vec2 offset = section-midpoint;
    float u = offset.x/span;
    float ends = 1.0-smoothstep(.51,1.0,abs(u));
    float displacement = .24*sin(3.6*u)+.13*sin(8.4*u+.72);
    float height = offset.y - slope*offset.x - displacement;
    float taper_width = width*mix(.42,1.0,ends);
    float recess = 1.0-smoothstep(.025,taper_width,abs(height));
    float rim = 1.0-smoothstep(.04,taper_width*1.47,abs(height+taper_width*.94));
    return vec2(recess,rim*(1.0-recess*.80))*ends;
}

vec3 middle_cliff_pigment(vec3 pigment, vec3 p, vec3 normal, vec4 bedding, float distance_m) {
    // Broad seams read between subsidiary joints at the arriving camera.
    // These are local finite segments with different slopes and heights.
    vec2 region = (p.xz-vec2(-3.0,-17.5))/vec2(15.3,10.9);
    float influence = (1.0-smoothstep(.65,1.0,max(abs(region.x),abs(region.y))))
                    * (1.0-smoothstep(.47,.86,normal.y))
                    * (1.0-smoothstep(65.0,110.0,distance_m));
    if (influence <= .001) {
        return pigment;
    }
    vec2 section = vec2(p.x+.21*(p.z+17.5),p.y+.075*(p.z+17.5));
    vec2 west = bed_parting(section,vec2(-11.7,5.60),5.75,-.23,.22);
    vec2 main = bed_parting(section,vec2(-2.1,6.15),5.9,.16,.25);
    vec2 upper = bed_parting(section,vec2(4.6,7.18),3.7,.25,.20);
    vec2 toe = bed_parting(section,vec2(1.8,3.85),4.0,-.14,.14);
    vec2 seams = max(max(west,main),max(upper,toe));
    float spall = smoothstep(.59,.88,bedding.a) * smoothstep(.24,.76,bedding.r);
    float recess = influence*seams.x;
    float rim = influence*seams.y;
    pigment *= mix(vec3(1.0),vec3(.47,.57,.65),recess*mix(.55,.93,bedding.r));
    pigment = mix(pigment,pigment*1.24+vec3(.007,.006,.005),rim*.86);
    return pigment*mix(vec3(1.0),vec3(1.10,1.077,1.042),influence*spall);
}

// Local worn chalk on the cut face, feathered into the surrounding strata.
vec3 cut_face_pigment(vec3 pigment, vec3 point, vec3 up) {
    vec2 patch = vec2((point.x+14.2-.34*(point.y-6.5))/4.9,
                      (point.z+9.5+.40*(point.y-6.5))/3.65);
    float face = (1.0-smoothstep(.34,1.0,length(patch)))
               * smoothstep(.27,.78,abs(up.x))
               * (1.0-smoothstep(.57,.86,up.y));
    float value=dot(pigment,vec3(.26,.63,.11));
    vec3 limestone=vec3(value)*vec3(1.095,1.045,1.00)+vec3(.045,.035,.017);
    return mix(pigment,limestone,face*.64);
}

vec3 backwall_mineral(vec3 pigment, vec3 up, vec3 p) {
    // Colour on the weathered bed follows the actual turned side faces.
    float bed_z = p.z - .21*(p.y - 7.3);
    float depth = smoothstep(-29.1,-26.1,p.x)*(1.0-smoothstep(-21.3,-19.4,p.x));
    float bed = smoothstep(-11.0,-9.78,bed_z)*(1.0-smoothstep(-8.57,-7.18,bed_z));
    float height = smoothstep(3.4,4.8,p.y)*(1.0-smoothstep(8.6,11.7,p.y));
    float turned = smoothstep(.18,.68,abs(up.z))*(1.0-smoothstep(.65,.9,up.y));
    vec3 stained=pigment*mix(vec3(1.0),vec3(1.17,1.145,1.085),depth*bed*height*turned);
    // Limestone on the newly exposed tread follows its upward-facing facets.
    float tread_depth=smoothstep(-24.0,-22.85,p.x)*(1.0-smoothstep(-18.85,-17.55,p.x));
    float tread_span=smoothstep(-10.45,-8.10,p.z)*(1.0-smoothstep(-4.22,-2.42,p.z));
    float tread_height=p.y+.19*(p.z+6.3);
    float exposed=smoothstep(3.5,4.57,tread_height)*(1.0-smoothstep(6.0,6.95,tread_height));
    float tread=tread_depth*tread_span*exposed*smoothstep(.35,.77,up.y);
    vec3 chalk=stained*vec3(1.42,1.35,1.25)+vec3(.065,.060,.048);
    return mix(stained,chalk,tread);
}

// An oblique soil pocket on a limestone cap. Both ends taper into the bed.
float cap_turf(vec2 xz, vec2 centre, vec2 scale, float shear) {
    vec2 delta=xz-centre;
    vec2 local=vec2(delta.x+shear*delta.y,delta.y-shear*delta.x)/scale;
    float opening=length(local*vec2(.93,1.0))+.085*sin(delta.x*1.19+delta.y*.66);
    return 1.0-smoothstep(.55,1.08,opening);
}
void vertex(){
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
    SPECULAR=0.0;
    ROUGHNESS=.97;
    exposed_rock=0.0;
    vec3 p=world_pos;
    float bevel_area=smoothstep(-29.1,-26.8,p.x)*(1.0-smoothstep(-21.3,-20.4,p.x))
                    * smoothstep(-12.65,-11.4,p.z)*(1.0-smoothstep(-8.3,-7.5,p.z));
    wide_face=bevel_area*smoothstep(7.0,8.7,p.y)*smoothstep(.35,.67,world_normal.y);
    miniature_bank=miniature_material*lower_bank_area(world_pos.xz);
    vec3 col;
    if(meadow){col=meadow_color(world_pos);}
    else{
        vec3 blend=pow(abs(normalize(world_normal)),vec3(4.0));
        blend/=max(blend.x+blend.y+blend.z,.001);
        float camera_distance=length(VERTEX);
        vec3 broad=rock_band(world_pos,blend,.024);
        vec3 middle=rock_band(world_pos+vec3(7.3,2.7,-4.1),blend,.13);
        vec3 fine=rock_band(world_pos+vec3(1.7,-3.3,9.2),blend,.72);
        float mid_weight=1.0-smoothstep(32.0,105.0,camera_distance);
        float fine_weight=1.0-smoothstep(5.0,22.0,camera_distance);
        vec3 pigment=clamp((broad-vec3(.75))*1.70+vec3(1.0),vec3(.72),vec3(1.22));
        pigment*=mix(vec3(1.0),clamp((middle-vec3(.75))*1.20+vec3(1.0),vec3(.78),vec3(1.18)),.34*mid_weight);
        pigment*=mix(vec3(1.0),clamp((fine-vec3(.75))*.55+vec3(1.0),vec3(.90),vec3(1.10)),.14*fine_weight);
        col=stone_color*pigment*mix(vec3(1.0),COLOR.rgb,.35);
        col*=mix(vec3(.91,.96,1.04),vec3(1.04,1.015,.94),smoothstep(-.1,.85,world_normal.y));
        // Warm chalk and cooler mineral patches come from the authored pigment.
        // Preserve distinct large colour planes without assigning a light direction.
        float plate=dot(broad-mix(middle,broad,.30),vec3(.25,.6,.15));
        col*=mix(vec3(.86,.952,1.04),vec3(1.054,1.045,1.00),smoothstep(-.055,.064,plate));
        // Pigment planes survive distance; only the small partings disappear.
        // The permeability of the broad bed decides where small flakes show.
        vec4 bed = mineral_beds(world_pos,blend,1.0);
        vec4 shale = mineral_beds(world_pos+vec3(8.6,-1.9,3.2),blend,3.28);
        float small_bed_weight = (1.0-smoothstep(9.0,38.0,camera_distance))
                               * mix(.36,.84,smoothstep(.34,.63,bed.r));
        float close_exposure = 1.0-smoothstep(4.0,17.0,camera_distance);
        float mineral = bed.r + (shale.r-.5)*(small_bed_weight+.11*close_exposure);
        // Group several exposed faces into the same tilted bed. Broken ends
        // and shale partings survive as accents inside this much larger wash.
        float dip = world_pos.y - .13*world_pos.x + .075*world_pos.z;
        float bed_drift = sin(.105*world_pos.x+.057*world_pos.z)*.78;
        float chalk_body = smoothstep(-.62,.65,sin(dip*.44+bed_drift)+(bed.r-.50)*1.3);
        float bed_tone = .67*smoothstep(.27,.72,mineral)+.33*chalk_body;
        vec3 cool_slate = vec3(.72,.86,1.025);
        vec3 warm_chalk = vec3(1.15,1.12,1.045);
        col *= mix(cool_slate,warm_chalk,bed_tone);
        // Rain exposes a paler, less chromatic skin on broad upward shoulders.
        // Its edge follows the sheet of stone, independently of the sun angle.
        float scoured_top=smoothstep(.25,.87,world_normal.y)
                        * (.32+.68*smoothstep(.15,.82,bed_tone));
        float chalk_value=dot(col,vec3(.263,.625,.112));
        vec3 pale_chalk=vec3(chalk_value)*vec3(1.09,1.065,1.025)+vec3(.037,.030,.023);
        col=mix(col,pale_chalk,.66*scoured_top);
        float line_visibility = 1.0-smoothstep(24.0,89.0,camera_distance);
        float recess = max(bed.g*.92*line_visibility,shale.g*small_bed_weight*.58);
        float lip = max(bed.b*.88*line_visibility,shale.b*small_bed_weight*.57);
        col *= mix(vec3(1.0),vec3(.53,.63,.72),recess);
        col *= mix(vec3(1.0),vec3(1.26,1.21,1.14),lip);
        // Broad scuffs and smaller thin chips occupy the same rock beds.
        // A clear surface outside those patches retains the underlying brush.
        float scuff = (bed.a-.50)*.34 + (shale.a-.50)*.54;
        col *= vec3(1.0) + scuff*close_exposure*vec3(.93,.79,.63);
        col = middle_cliff_pigment(col,world_pos,normalize(world_normal),bed,camera_distance);
        col = cut_face_pigment(col,world_pos,normalize(world_normal));
        col = backwall_mineral(col,normalize(world_normal),world_pos);
        float turf=smoothstep(.23,.85,COLOR.a+.11*clamp(plate*13.0,-1.0,1.0))*smoothstep(.22,.68,world_normal.y);
        turf=mix(turf,1.0,smoothstep(.86,.999,COLOR.a));
        if (UV2.y > .001) {
            float pockets=max(cap_turf(world_pos.xz,vec2(25.3,1.95),vec2(3.45,1.45),.32),
                              cap_turf(world_pos.xz,vec2(-1.9,3.65),vec2(4.9,1.68),-.32));
            float continuous_cover=max(pockets*.89,smoothstep(.61,1.0,COLOR.a));
            turf=mix(turf,continuous_cover,UV2.y);
        }
        // UV2.x measures proximity to grass below the continuous cliff, or actual
        // world-space ground clearance for a fallen stone. The stain breaks into
        // pockets along a bed and never becomes a uniform dark outline.
        float broken_toe = UV2.x * (.31+.69*smoothstep(.27,.72,mineral));
        float shoulder = 4.0*turf*(1.0-turf)*smoothstep(.26,.83,world_normal.y);
        vec3 dry_soil = col*vec3(.87,.86,.72) + vec3(.023,.019,.005);
        vec3 damp_soil = col*vec3(.69,.79,.72);
        col=mix(col,mix(dry_soil,damp_soil,1.0-chalk_body),broken_toe*.78);
        col=mix(col,dry_soil,shoulder*.53);
        if (miniature_bank > .0 && !clay_mode) {
            // Limestone partings follow one inclined bed across neighbouring faces.
            // Soft, irregular joints avoid high-frequency contrast at gameplay scale.
            float joint_position = dip*1.62 + .20*bed.r + .19*sin(world_pos.x*.36+world_pos.z*.19);
            float joint = 1.0-smoothstep(.045,.28,abs(fract(joint_position)-.5));
            joint *= mix(.33,.88,smoothstep(.28,.73,bed.r)) * (1.0-.62*world_normal.y);
            float powder = dot(middle-broad,vec3(.25,.60,.15));
            vec3 lime = col*vec3(1.08,.995,.85)*(.99+.35*powder);
            lime *= mix(vec3(1.0),vec3(.54,.58,.60),joint);
            lime *= 1.0-.20*broken_toe;
            col = mix(col,lime,miniature_bank*.86);
        }
        col=mix(col,meadow_color(world_pos),clamp(turf,0.0,1.0));
        exposed_rock = clay_mode ? 0.0 : 1.0-clamp(turf,0.0,1.0);
        ROUGHNESS=mix(.97, mix(.83,.95,chalk_body)-.088*miniature_bank,exposed_rock);
    }
    if(clay_mode)col=vec3(.55);
    ALBEDO=col;
    // Environment irradiance supplies the shadow fill and follows the lighting preset.
    AO=1.0;
}
void light(){
    float facing=dot(NORMAL,LIGHT);
    float continuous=smoothstep(-.10,.90,facing);
    // Two broad transitions leave a middle plane between shaded and bright rock.
    // Keep some continuous light so narrow bevels and curved sections can turn.
    float bands=.46*smoothstep(.09,.26,facing)+.54*smoothstep(.49,.70,facing);
    float weight=.76*illustration_light*exposed_rock*(1.0-.46*miniature_bank)*(1.0-.68*wide_face);
    float diffuse=mix(continuous,bands,weight);
    vec3 half_tone=mix(vec3(.91,.96,1.045),vec3(1.025,1.01,.97),
                       smoothstep(.13,.62,facing));
    vec3 direct=LIGHT_COLOR/PI*(.05+.95*diffuse)*ATTENUATION;
    DIFFUSE_LIGHT+=direct*mix(vec3(1.0),half_tone,weight)+environment_irradiance();
    // A rough dielectric lobe on exposed limestone. Diffuse bands and sky fill
    // remain art directed. There is no painted-in highlight on the rock skin.
    if (exposed_rock > 0.0 && facing > 0.0) {
        vec3 h=normalize(LIGHT+VIEW);
        float nh=max(dot(NORMAL,h),0.0);
        float nv=max(dot(NORMAL,VIEW),.001);
        float vh=max(dot(VIEW,h),0.0);
        float alpha=ROUGHNESS*ROUGHNESS;
        float alpha2=alpha*alpha;
        float denominator=nh*nh*(alpha2-1.0)+1.0;
        float distribution=alpha2/(PI*denominator*denominator);
        float smith_v=facing*sqrt(nv*nv*(1.0-alpha2)+alpha2);
        float smith_l=nv*sqrt(facing*facing*(1.0-alpha2)+alpha2);
        float visibility=.5/max(smith_v+smith_l,.001);
        float fresnel=.025+.975*pow(1.0-vh,5.0);
        SPECULAR_LIGHT+=LIGHT_COLOR*ATTENUATION*(fresnel*distribution*visibility*facing*exposed_rock);
    }
}
