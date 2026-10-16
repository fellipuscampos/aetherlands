shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform float strength = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform vec4 focus_rects[6];
uniform bool use_uv_mask = false;
uniform bool use_emission_texture = false;
uniform sampler2D emission_mask : filter_nearest;
uniform vec3 focus_world = vec3(0.0);
varying vec3 world_vertex;
void vertex() { world_vertex = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float mask = 0.0;
    if (use_uv_mask) {
        for (int i=0; i<6; i++) {
            vec4 r = focus_rects[i];
            mask = max(mask,step(r.x-0.00005,UV.x)*step(r.y-0.00005,UV.y)*step(UV.x,r.z+0.00005)*step(UV.y,r.w+0.00005));
        }
    } else if (use_emission_texture) {
        vec3 texel = texture(emission_mask,UV).rgb;
        mask = max(texel.r,max(texel.g,texel.b));
    } else {
        mask = 1.0-smoothstep(0.07,0.16,distance(world_vertex,focus_world));
    }
    ALBEDO = glow_color.rgb;
    EMISSION = glow_color.rgb * strength * 3.2;
    ALPHA = mask * min(strength,1.0);
}
