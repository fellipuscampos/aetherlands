shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float opacity = 1.0;
void fragment() {
    float edge=pow(max(0.0,1.0-abs(UV.y*2.0-1.0)),1.5);
    float flow=0.65+0.35*sin(UV.x*24.0-TIME*1.2);
    ALBEDO=color.rgb;
    EMISSION=color.rgb*1.2;
    ALPHA=edge*opacity*color.a*flow;
}
