shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(1.0,0.83,0.45,1.0);
uniform float opacity = 1.0;
void fragment() {
    float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.5);
    float wave=pow(max(0.0,sin(UV.y*18.0-TIME*0.8)),14.0)*0.2;
    ALBEDO=color.rgb;
    EMISSION=color.rgb*0.9;
    ALPHA=(rim*0.20+wave*0.07)*opacity;
}
