shader_type sky;
uniform vec3 zenith : source_color=vec3(0.12,0.48,0.80);
uniform vec3 horizon : source_color=vec3(0.58,0.83,0.88);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*.55+noise(p*2.03)*.28+noise(p*4.1)*.12+noise(p*8.2)*.05;}
void sky(){
    float h=max(EYEDIR.y,0.0);
    vec3 col=mix(horizon,zenith,smoothstep(0.0,.7,h));
    vec2 p=EYEDIR.xz/(h+.22)*2.2+vec2(5.1,2.3);
    float body=fbm(p);
    float cloud=smoothstep(.53,.68,body)*smoothstep(.01,.1,h)*smoothstep(.95,.5,h);
    vec3 cloud_col=mix(vec3(.68,.80,.85),vec3(1.0,.99,.89),smoothstep(.54,.75,body));
    COLOR=mix(col,cloud_col,cloud*.90);
}
