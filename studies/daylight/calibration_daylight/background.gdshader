shader_type spatial;
render_mode unshaded, fog_disabled;
#include "res://calibration_daylight/environment_fill.gdshaderinc"
uniform vec3 haze_color : source_color=vec3(.48,.67,.78);
uniform vec3 sun_direction=vec3(-.4,.74,.53);
uniform vec3 sun_color : source_color=vec3(1.0,.96,.87);
uniform float sun_energy=.95;
uniform bool clay_mode=false;
uniform sampler2D woodland_cover : filter_linear, repeat_disable, hint_default_black;
uniform vec4 woodland_bounds=vec4(-350.,-306.,700.,266.);
varying vec3 world_normal;
varying vec3 world_pos;
varying flat float canopy;

float hash2(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(.0973,.1031,.0897));
    q += dot(q,q.yzx + 19.19);
    return fract((q.x+q.y)*q.z);
}

float brush_noise(vec2 uv) {
    vec2 cell = floor(uv);
    vec2 f = fract(uv);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash2(cell),hash2(cell + vec2(1,0)),f.x),
               mix(hash2(cell + vec2(0,1)),hash2(cell + vec2(1)),f.x),f.y);
}

// A triangle-interpolated pigment field yields small directional paint
// planes. The flanks use quite different scales along and across the bedding.
float plane_noise(vec2 uv) {
    vec2 cell=floor(uv);
    vec2 f=fract(uv);
    float a=hash2(cell), b=hash2(cell+vec2(1,0)), c=hash2(cell+vec2(0,1));
    if(f.x+f.y<1.) return a+(b-a)*f.x+(c-a)*f.y;
    float d=hash2(cell+vec2(1,1));
    return d+(c-d)*(1.-f.x)+(b-d)*(1.-f.y);
}

void vertex() {
    world_pos=(MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(mat3(MODEL_MATRIX) * NORMAL);
    canopy=UV2.x;
}

void fragment() {
    vec3 n=normalize(world_normal);
    vec3 solar=OUTPUT_IS_SRGB ? pow(sun_color,vec3(2.2)) : sun_color;
    vec3 haze=OUTPUT_IS_SRGB ? pow(haze_color,vec3(2.2)) : haze_color;
    vec3 base=OUTPUT_IS_SRGB ? pow(COLOR.rgb,vec3(2.2)) : COLOR.rgb;
    float depth=COLOR.a;
    float incidence=dot(n,normalize(sun_direction));
    float diffuse=smoothstep(-.26,.86,incidence);
    vec3 irradiance=environment_irradiance()+solar*sun_energy*(.12+.90*diffuse);
    vec3 lit=base*irradiance;
    float alpine=smoothstep(42.0,92.0, world_pos.y);
    // Broad, slanted shelves of snow split into exposed ribs on the lee face.
    // Project onto the front/side, so the paint spans a whole mountain facet.
    vec2 face=vec2(world_pos.x + world_pos.z*.24, world_pos.y-world_pos.x*.32+world_pos.z*.17);
    float broad=brush_noise(face*vec2(.037,.048));
    float fracture=brush_noise(face*vec2(.098,.055)+vec2(72.,16.));
    float bedrock=brush_noise(face*vec2(.018,.077)+vec2(-43.,31.));
    float carry=.58*n.y + .41*broad + .23*fracture + .14*bedrock;
    float shelf=smoothstep(.53,.72,carry + (world_pos.y - 116.)*.0019);
    float exposed_rib=smoothstep(.19,.62,fracture*.54 + bedrock*.46);
    shelf *= mix(.28,1.0,exposed_rib);
    float west_peak=1.0-smoothstep(-150.0,-65.0,world_pos.x);
    float west_snow=smoothstep(111.,165.,world_pos.y)*.86;
    float snowline=smoothstep(69.0,115.0,world_pos.y + (broad-.5)*34.) * smoothstep(230.,280.,-world_pos.z);
    // Snow spills across the inclined ledges, pinches out on the steep
    // ribs, and pools in distinct shaded couloirs beneath the crowns.
    vec2 flow=vec2(world_pos.x+.33*world_pos.z-world_pos.y*.18,world_pos.y+.41*world_pos.z);
    float runnel=brush_noise(flow*vec2(.086,.022)+vec2(-12.,8.));
    float cuts=brush_noise(face*vec2(.13,.15)+vec2(41.,19.));
    float pocket=smoothstep(.38,.63,.62*runnel+.38*cuts);
    float holding=shelf+.21*(pocket-.42)+.12*(n.y-.72);
    // Wind scours the convex spurs. Narrow oblique streamers survive on
    // lee-facing shelves, with separated sunlit snow pockets between them.
    vec2 flute=vec2(world_pos.x - world_pos.y*.56 + world_pos.z*.19,world_pos.y*.68+world_pos.z*.31);
    float gully=brush_noise(flute*vec2(.108,.033)+vec2(7.8,-16.));
    float cornice=brush_noise(face*vec2(.045,.123)+vec2(-8.,17.));
    float drift=smoothstep(.32,.67,.48*gully+.34*cornice+.18*runnel);
    float ledge_snow=smoothstep(.45,.67,.31*holding+.40*drift+.29*cornice);
    float snow=alpine*snowline*mix(.86,west_snow,west_peak)*(.30+drift*.70)*ledge_snow;
    snow *= .73+.27*smoothstep(.29,.70,fracture);
    vec2 paint_face=vec2(world_pos.x-.21*world_pos.y+.23*world_pos.z,world_pos.y+.27*world_pos.x-.18*world_pos.z);
    float eroded=plane_noise(paint_face*vec2(.147,.23)+vec2(8.1,-17.3));
    float strata=plane_noise(paint_face*vec2(.083,.41)+vec2(31.4,3.9));
    float edge=smoothstep(.14,.85,4.*drift*(1.-drift));
    float white_fleck=smoothstep(.48,.77,.46*eroded+.54*strata);
    snow = clamp(snow*(.70+.50*white_fleck)+alpine*snowline*edge*.21*white_fleck,0.,.92);
    float west_crown=west_peak*smoothstep(140.,164.,world_pos.y)*(1.-smoothstep(-353.,-342.,world_pos.z));
    snow=max(snow,west_crown*smoothstep(.40,.72,strata)*(.39+.42*white_fleck));
    lit=mix(lit,haze*(.57+.39*diffuse),alpine*(.12+.16*(1.0-diffuse)));
    vec3 snow_shade=vec3(.23,.40,.59)*(.40+sun_energy*.59)+environment_irradiance()*.75;
    vec3 snow_sun=vec3(.66,.79,.88)*(environment_irradiance()+solar*sun_energy*(.63+.34*max(incidence,0.)));
    float alpine_stone=smoothstep(60.,103.,world_pos.y)*smoothstep(204.,280.,-world_pos.z);
    float day=smoothstep(.46,.90,sun_color.b);
    // A broad blue-green rock value under the high snow. The exposed shelves
    // break up the wall laterally while the lower forest is free of ice.
    float shelf_plane=brush_noise(vec2(world_pos.x*.016+world_pos.z*.008, (world_pos.y-world_pos.x*.17)*.074));
    float slate_value=.70+.27*diffuse+.13*smoothstep(.17,.77,shelf_plane);
    float ledge=smoothstep(.31,.64,.64*shelf_plane+.36*fracture);
    vec3 slate=mix(vec3(.052,.157,.265),vec3(.13,.32,.39),ledge)*slate_value;
    lit=mix(lit,slate,alpine_stone*day*.52);
    float exposed=1.0-smoothstep(.25,.65,.70*gully+.30*fracture);
    lit*=1.-alpine_stone*exposed*.23;
    // Leave quiet stone between the short cuts. A single branch tends
    // towards shadow rock, the next towards a sunlit exposed scarp.
    float interrupted=smoothstep(.33,.64,fracture*.6+cornice*.4);
    float chips=(smoothstep(.17,.81,.55*eroded+.45*strata)-.45)*.47;
    lit*=1.+alpine_stone*interrupted*chips*.43;
    // Broad diagonal shadow faces run under snow and end in the first
    // forested pass. Keep the intervening shoulder a quiet mid-blue.
    float break_face=.51*(n.x*.86-n.z*.30)+.34*(2.*shelf_plane-1.)+.15*(2.*eroded-1.);
    float lee=smoothstep(-.13,.38,break_face)*smoothstep(.05,.47,1.-n.y);
    vec3 blue_fault=lit*vec3(.48,.72,.89);
    lit=mix(lit,blue_fault,lee*alpine_stone*day*.85);
    float shelf_light=smoothstep(.15,.73,.48*diffuse+.48*shelf_plane+.13*n.y);
    // Broad slanted rock planes read through the snow on the nearer alpine shoulder.
    float exposure_plane=smoothstep(.41,.66, .67*shelf_plane+.33*eroded) * smoothstep(.16,.64,1.-n.y);
    float nearer_alpine=1.-.70*smoothstep(285.,445.,-world_pos.z);
    float cut_snow=snow*(1.-.58*exposure_plane*nearer_alpine);
    float sun_shelf=smoothstep(.45,.70,.54*broad+.46*shelf_plane)*smoothstep(-.15,.62,incidence);
    float alpine_shelf=smoothstep(70.,113.,world_pos.y)*smoothstep(218.,285.,-world_pos.z);
    float shoulder_snow=alpine_shelf*nearer_alpine*sun_shelf*(1.-.86*exposure_plane)*.94;
    float snow_cover=max(cut_snow,shoulder_snow);
    lit=mix(lit,mix(snow_shade*.79,snow_sun*1.19,shelf_light),snow_cover);
    float distant_wood=smoothstep(154.,191.,-world_pos.z)*(1.-smoothstep(267.,310.,-world_pos.z))*(1.-smoothstep(62.,83.,world_pos.y));
    float lateral=brush_noise(vec2(world_pos.x*.048,(world_pos.y-world_pos.x*.13)*.13));
    lit=mix(lit,vec3(.057,.252,.29)*(.73+.36*diffuse+.19*lateral),distant_wood*day*.24);
    // Crown pigment and optical distance are independent of the ground's
    // altitude/snow masks. A front fir keeps a darker flank even on a high ledge.
    if(canopy>.5){
        float crown_light=smoothstep(-.36,.73,incidence);
        vec3 leaves=base*(environment_irradiance()+solar*sun_energy*(.17+.91*crown_light));
        float deep_grove=smoothstep(215.,259.,-world_pos.z);
        vec3 air=vec3(.086,.25,.31)*(.68+.29*crown_light);
        float near_grove=1.-smoothstep(190.,267.,-world_pos.z);
        leaves*=mix(vec3(1.0),vec3(.82,.92,.87),near_grove*(1.-.66*crown_light));
        lit=mix(leaves,air,.08+.26*deep_grove);
    }
    // On the central moraine only, expose the inclined risers of the two ground terraces.
    float bank=smoothstep(-47.,-21.,world_pos.x)*(1.-smoothstep(59.,88.,world_pos.x))
              *smoothstep(-210.,-193.,world_pos.z)*(1.-smoothstep(-174.,-153.,world_pos.z));
    float slip=1.-smoothstep(.48,.78,n.y);
    vec3 mudstone=mix(vec3(.15,.21,.215),vec3(.32,.35,.285),broad)*irradiance;
    if(canopy<.5) lit=mix(lit,mudstone,bank*slip*(.39+.39*smoothstep(.24,.63,fracture)));
    vec2 grove_uv=(world_pos.xz-woodland_bounds.xy)/woodland_bounds.zw;
    float planted=texture(woodland_cover,grove_uv).r;
    if(canopy<.5){
        float bracken=smoothstep(.18,.72,.49*lateral+.51*broad);
        vec3 pine_floor=mix(vec3(.013,.111,.126),vec3(.040,.192,.158),bracken);
        pine_floor*=environment_irradiance()+solar*sun_energy*(.42+.45*diffuse);
        lit=mix(lit,pine_floor,planted*(.51+.14*bracken));
    }else{
        // Low crowns in one grove share a deep contact colour. Individual
        // upper leaves can still catch sunlight on their inclined flanks.
        float upper=smoothstep(.1,.80,n.y);
        lit*=mix(vec3(.60,.79,.83),vec3(1.02,1.12,1.02),upper*.75+.25*diffuse);
    }
    float high_range=smoothstep(36.0,90.0,world_pos.y)*smoothstep(150.0,305.0,-world_pos.z);
    float valley_air=(1.-smoothstep(35.,90.,world_pos.y))*smoothstep(195.,282.,-world_pos.z);
    float far_crest=smoothstep(306.,440.,-world_pos.z)*smoothstep(52.,115.,world_pos.y);
    float front_crest=smoothstep(183.,239.,-world_pos.z)*(1.-smoothstep(291.,349.,-world_pos.z))*smoothstep(46.,92.,world_pos.y);
    float mist=clamp(.060+depth*.13+smoothstep(85.,550.,length(VERTEX))*.13+high_range*.39+valley_air*.13
                    +.088*far_crest-.078*front_crest,0.,.71);
    // Day sky adds stronger blue to distant shaded rock and softens the snowy
    // range. West of the saddle a long, lower shoulder remains mostly stone.
    haze*=mix(vec3(1),vec3(.61,1.02,1.23),high_range*day);
    if(clay_mode){
        lit=vec3(.46)*irradiance;
        haze=vec3(dot(haze,vec3(.21,.72,.07)));
    }
    lit=mix(lit,haze,mist);
    if(!clay_mode){
        float blue_day=high_range*day;
        lit*=mix(vec3(1.0),vec3(.46,1.13,1.23),blue_day*.74*(1.0-.72*snow_cover)*(1.-.26*far_crest));
        float green_day=distant_wood*day*(1.0-smoothstep(210.,288.,-world_pos.z)*.56);
        lit*=mix(vec3(1.0),vec3(.62,1.09,1.02),green_day);
    }
    ALBEDO=OUTPUT_IS_SRGB ? pow(max(lit,vec3(0)),vec3(1.0/2.2)) : lit;
}
