// Authored palette shared by terrain and grass; evaluated in world space.
// Generated paint contributes subtle broad brush variation, never baked lighting.
uniform sampler2D meadow_paint : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D habitat_wash : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D turf_floor : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_edge_field : hint_default_white, filter_linear, repeat_disable;
uniform vec4 ground_edge_bounds;
uniform float miniature_material : hint_range(0.0, 1.0) = 0.0;

float lower_bank_area(vec2 p) {
    vec2 bank = (p-vec2(15.0,5.0))/vec2(26.0,13.0);
    return 1.0-smoothstep(.62,1.08,length(bank));
}
uniform sampler2D sward_opening : hint_default_black, filter_linear, repeat_disable;
uniform vec3 grass_sun : source_color = vec3(0.502,0.699,0.227);
uniform vec3 grass_cool : source_color = vec3(0.19,0.45,0.26);
uniform vec3 trail_color : source_color = vec3(0.54,0.52,0.33);
vec2 meadow_habitat_uv(vec2 xz){
    vec2 warp = vec2(sin(xz.y*.43+xz.x*.11)+.42*sin(xz.y*.92),
                     sin(xz.x*.39-xz.y*.095)+.36*sin(xz.x*.82));
    return (xz-ground_edge_bounds.xy + .86*warp)/max(ground_edge_bounds.zw,vec2(1.0));
}
float sward_patch(vec2 xz, vec2 centre, vec2 extent) {
    vec2 local = xz-centre;
    vec2 rotated = vec2(local.x*.9+local.y*.43, local.y*.9-local.x*.43)/extent;
    float radius = length(rotated)+.09*sin(local.x*1.35+local.y*.91)
                                  +.065*sin(local.y*2.1-local.x*.83);
    return 1.0-smoothstep(.48,1.16,radius);
}

vec3 meadow_color_sample(vec3 p,float paint_lod,out float quiet_clearing){
    float broad=sin(p.x*.055+p.z*.031)*.5+.5;
    float secondary=sin(p.x*.11-p.z*.067)*.5+.5;
    vec2 hollow=(p.xz-vec2(-22.0,-4.0))/vec2(14.0,21.0);
    float cool_pocket=exp(-dot(hollow,hollow));
    float wash=smoothstep(.06,.94,.11+.66*broad+.21*secondary-.42*cool_pocket);
    vec3 col=mix(grass_cool,grass_sun,wash);
    vec3 paint=paint_lod<0.0 ? texture(meadow_paint,p.xz*.05).rgb : textureLod(meadow_paint,p.xz*.05,paint_lod).rgb;
    float brush=dot(paint,vec3(.24,.59,.17));
    vec2 down_slope=vec2(p.x*.15+p.z*.05,p.z*.29-p.x*.035);
    float meadow_patches=sin(down_slope.x+.95*sin(down_slope.y*.55))+.64*sin(down_slope.y+down_slope.x*.46);
    float warm_turf=smoothstep(.28,1.36,meadow_patches)*(.22+.29*wash);
    col=mix(col,col*vec3(1.15,1.05,.84),warm_turf);
    col*=mix(vec3(.90,.95,1.04),vec3(1.0),smoothstep(-1.25,.10,meadow_patches));
    // Moist grass below the nearer rock shelf forms a connected, cooler swath.
    // Its edge follows the land rather than the centreline of the footpath.
    vec2 damp=(p.xz-vec2(17.0,12.0))/vec2(18.0,5.8);
    damp.y+=.43*damp.x+.31*sin(damp.x*3.2);
    float wet_sward=exp(-dot(damp,damp))*(.76+.24*smoothstep(-.7,.7,meadow_patches));
    col=mix(col,col*vec3(.75,.92,1.13),wet_sward*.80);
    // Lower-terrace dry islands follow the contour; exposed turf and blades share them.
    vec2 slope=(p.xz-vec2(-8.0,10.0))/vec2(13.0,5.5);
    slope.x+=slope.y*.42;
    float dry=exp(-dot(slope,slope))*(.55+.45*smoothstep(.36,.75,brush));
    col=mix(col,vec3(.54,.61,.23),dry*.50);
    // Shelter, paint and the irregular crest decide where exposed earth collects.
    // R is the measured distance to actual bare rock. G compares its height
    // with this point. Reading the same map at each blade root ties it to the turf.
    vec2 edge_uv = (p.xz-ground_edge_bounds.xy)/max(ground_edge_bounds.zw,vec2(1.0));
    vec2 edge = textureLod(ground_edge_field,edge_uv,0.0).rg;
    // The clearings occupy the convex shoulders. Cool broadleaf sward follows
    // the moist foot of the belt and narrows to tongues between shoulders.
    // The same world data is sampled on the terrain and at each grass root.
    vec4 habitat = textureLod(habitat_wash,meadow_habitat_uv(p.xz),0.0);
    float sheltered = (1.0-smoothstep(.03,.83,edge.r))*smoothstep(.30,.86,edge.g);
    float green_sward = clamp(habitat.g + sheltered*.21, 0.0, 1.0);
    float ripe_sward = habitat.r*(1.0-green_sward*.69);
    float front_sun = smoothstep(6.0,17.0,p.z);
    float western_crest = front_sun*(1.0-smoothstep(8.0,23.0,p.x));
    vec3 ripe_pigment = col*vec3(1.025+.116*western_crest,1.103,.78-.15*front_sun);
    col = mix(col, ripe_pigment+vec3(.009+.013*western_crest,.017,.006),ripe_sward);
    col = mix(col, col*vec3(.73,1.035,1.07)+vec3(.003,.015,.026),green_sward);
    // Fresh growth at the exposed west foot is pale sage. The right-hand
    // clearing has a bluer, quieter centre; it meets the warm foreground in tongues.
    float western_foot = 1.0-smoothstep(-2.0,20.0,p.x);
    quiet_clearing = habitat.b*(1.0-western_foot);
    vec3 bank = col*mix(vec3(.87,.98,1.11),vec3(1.16,1.14,1.12),western_foot)
              + mix(vec3(.0,.004,.018),vec3(.035,.041,.023),western_foot);
    // Under a mature, oat-bearing canopy the shorter leaves have a
    // less dry pigment than their golden seed heads. Preserve a green-blue
    // component in the sun even where the broad pasture itself is ripe.
    float oat_bank = smoothstep(8.0,15.0,p.z)*(1.0-western_foot);
    bank=mix(bank, col*vec3(.985,.929,1.17)+vec3(.012,.002,.056),oat_bank);
    col = mix(col,bank,habitat.b*(1.0-.36*green_sward));
    float pocket = smoothstep(-.52,.79,meadow_patches+.75*sin(p.x*.71+p.z*.32));
    float reach = mix(.18,.69,pocket)*mix(.70,1.0,edge.g);
    float at_rock = 1.0-smoothstep(.015,reach,edge.r);
    float bare_edge = at_rock*(.22+.78*pocket)*(.65+.35*edge.g);
    col=mix(col,trail_color*vec3(.91,.88,.75),bare_edge*.48);
    col*=.81+.34*brush;
    // Pockets of flattened leaves and litter stay at the scale of a boot.
    // Large pigment shapes continue through both the ground and blade roots.
    vec2 floor_uv = vec2(p.x*.94+p.z*.34, -p.x*.34+p.z*.94)/2.9;
    floor_uv += vec2(sin(p.z*.84+p.x*.29), sin(p.x*.72-p.z*.36))*.096;
    vec3 floor_paint = paint_lod < 0.0 ? texture(turf_floor,floor_uv).rgb
                                       : textureLod(turf_floor,floor_uv,2.0).rgb;
    // On the high, bare west summit thin alpine grass has a grey sage
    // cast. Its irregular fringe still takes the same dynamic sun and shade.
    float upper_west = (1.0-smoothstep(-32.0,-17.0,p.x))*smoothstep(9.0,16.0,p.y);
    upper_west *= (.40+.60*(1.0-edge.r))*(.73+.27*meadow_patches*.5);
    float summit_value=dot(col,vec3(.26,.60,.14));
    col = mix(col,vec3(summit_value*.97,summit_value*1.03,summit_value*.97),upper_west*.70);
    // A broken mineral soil body appears inside the scuffs, with a rim
    // of pale new growth. The dry scuffs belong only to the west-facing toe.
    float chalk = habitat.a*(.83+.17*edge.g);
    float fresh_rim = smoothstep(.03,.5,chalk);
    col = mix(col, col*vec3(1.12,1.15,1.12)+vec3(.018,.027,.03),fresh_rim);
    float broken_soil = smoothstep(.25,.83,chalk+.21*(floor_paint.r-.49));
    vec3 lime_earth = mix(vec3(.50,.60,.398),vec3(.70,.72,.55),
                          smoothstep(.32,.64,brush+(floor_paint.r-.486)*.32));
    col = mix(col,lime_earth,broken_soil*(paint_lod<0.0?.72:.32));
    // Open sunlit ground reads in broad washes at gameplay distance.
    float east_bank = smoothstep(-8.0,8.0,p.x) * smoothstep(-6.0,7.0,p.z);
    floor_paint = mix(floor_paint, vec3(.486,.04,.028),east_bank*.76);
    col *= 1.0+(floor_paint.r-.486)*mix(.75,.49,quiet_clearing);
    float litter = (.24+.69*bare_edge+.15*(1.0-wash))*floor_paint.b;
    col = mix(col, trail_color*vec3(1.17,1.02,.78), litter);
    col *= 1.0-floor_paint.g*(.33+.14*bare_edge);

    // Worn ground shows through between the larger leaf colonies. The same
    // mapped openings thin the grass instances, so the pigment is continuous in motion.
    vec2 pasture=textureLod(sward_opening,edge_uv,0.0).rg;
    // Deep, wet foliage grows in connected patches; its floor and blades
    // share a cool undercolour. The exposed shoulders carry dusty clay.
    col=mix(col, col*vec3(.81,.91,1.20)+vec3(.010,.007,.046), pasture.g*.69);
    vec3 dry_soil=mix(col*vec3(1.10,.99,.93),vec3(.64,.604,.389),.59);
    col=mix(col,dry_soil,smoothstep(.06,.95,pasture.r)*(.47+.17*smoothstep(.33,.62,brush)));

    // Cool low ground behind the dry, pale brows of the meadow ledges.
    vec2 lowland=p.xz-vec2(6.,5.);
    float toe=lowland.y+.28*lowland.x+1.1*sin(lowland.x*.24);
    float hollow_mask=(1.-smoothstep(1.1,4.2,abs(toe))) *
                      (1.-smoothstep(10.,21.,abs(lowland.x)));
    col=mix(col,col*vec3(.70,.89,1.13)+vec3(.001,.007,.013),hollow_mask*.78);
    float bend=(p.z+23.0)/27.0;
    float center=5.0+14.0*exp(-bend*bend)-3.0*sin(p.z*.073);
    center=mix(center,17.0-2.5*sin((p.z+44.0)*.07),smoothstep(32.0,43.0,-p.z));
    vec2 bends=(vec2(p.z)+vec2(19.0,68.0))/vec2(17.0,14.0);
    center+=dot(vec2(10.0,-8.0),exp(-bends*bends));
    float width=.9+.4*sin(p.z*.19)+.20*sin(p.z*.47);
    // Small turf tongues interrupt the mineral edge of the east shoulder.
    float shoulder = smoothstep(.72,1.84,p.x-center) * (1.0-smoothstep(2.9,4.7,p.x-center));
    shoulder *= smoothstep(-5.0,5.0,p.z)*(1.0-smoothstep(15.0,23.0,p.z));
    float fringe = .50*sin(p.z*.48+.63*sin(p.z*.73))+.23*sin(p.z*1.19+p.x*.49);
    float path=1.0-smoothstep(.25,width+1.1,abs(p.x-center)+sin(p.z*.42)*.20+shoulder*fringe);
    path*=.65+.35*smoothstep(-.7,.6,sin(p.z*.17+p.x*.06));
    float worn_patches=smoothstep(-.58,.62,meadow_patches-.25*sin(p.z*.28));
    float wear=mix(.24,.61,smoothstep(-4.0,24.0,-p.z));
    float walked=smoothstep(-11.,-1.,p.z)*(1.-smoothstep(17.,29.,p.z));
    float meander=center+.65*sin(p.z*.37)+.48*sin(p.z*.18+.65);
    float footfall=1.-smoothstep(.42,2.0,abs(p.x-meander)+.22*sin(p.z*.92)+shoulder*fringe*.8);
    float sward=walked*footfall*(.35+.39*worn_patches);
    vec3 straw=mix(col,vec3(.56,.54,.31)*(.85+.30*brush),.52);
    col=mix(col,straw,sward);
    float local_bank = lower_bank_area(p.xz);
    float verge_cover = (1.0-.9*path)*local_bank;
    float cool_sward = max(sward_patch(p.xz,vec2(3.8,6.7),vec2(4.7,3.2)),
                           sward_patch(p.xz,vec2(19.7,4.8),vec2(4.0,3.5)));
    cool_sward=max(cool_sward,.80*sward_patch(p.xz,vec2(22.2,11.6),vec2(4.0,2.4)));
    float dry_sward = max(sward_patch(p.xz,vec2(13.8,10.7),vec2(4.3,3.0)),
                          sward_patch(p.xz,vec2(14.8,-2.8),vec2(3.3,3.7)));
    dry_sward=max(dry_sward,.60*sward_patch(p.xz,vec2(19.3,14.0),vec2(4.4,2.7)));
    col = mix(col,col*vec3(.71,.87,.98)+vec3(.004,.006,.017),cool_sward*verge_cover*.84);
    col = mix(col,col*vec3(1.10,1.025,.72)+vec3(.023,.013,.005),dry_sward*verge_cover*.72);
    float clear_ground = smoothstep(.15,.91,pasture.r)*(1.0-.73*pasture.g)*(1.0-.40*path);
    float growing_margin = smoothstep(.14,.68,pasture.g)*(1.0-.60*path);
    col = mix(col, vec3(.57,.535,.345) * (.91+.15*brush), clear_ground * local_bank * .52);
    col *= mix(vec3(1.0),vec3(.78,.89,.84),growing_margin * local_bank * .49);
    if (miniature_material > .0) {
        float mineral_grain = dot(floor_paint-vec3(.486,.04,.028),vec3(.57,-.24,.20));
        float contact = (1.0-smoothstep(.015,.25,edge.r))*edge.g;
        float verge = (1.0-.90*path)*local_bank;
        float soil_scale = verge * clear_ground * (.73 + .21*brush + .46*mineral_grain);
        col = mix(col,vec3(.51,.418,.29),miniature_material*soil_scale*.44);
        col *= 1.0-miniature_material*.23*contact*verge;
        col = mix(col,col*vec3(.91,.95,1.03),miniature_material*local_bank*.56);
    }
    return mix(col,trail_color*(.91+.14*brush),path*wear*(.25+.75*worn_patches));
}



vec3 meadow_color(vec3 p){
    float quiet_clearing;
    return meadow_color_sample(p,-1.0,quiet_clearing);
}
