// Compatibility fallback: combine artist-controlled hemispheric fill and direct
// light in the same light pass, before output gamma. One directional sun only.
// This is a dynamic approximation, not the original game's probe/GI system.
uniform vec3 environment_color : source_color=vec3(.55,.72,.90);
uniform float environment_strength=.55;
vec3 environment_irradiance(){
    vec3 tint=OUTPUT_IS_SRGB ? pow(environment_color,vec3(2.2)) : environment_color;
    return tint*environment_strength;
}
