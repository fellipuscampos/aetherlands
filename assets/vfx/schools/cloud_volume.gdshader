shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform vec4 color : source_color = vec4(0.5,0.56,0.64,0.62);
uniform float opacity = 1.0;
varying vec3 local_vertex;
void vertex() {
    local_vertex=VERTEX;
    float ripple=sin(VERTEX.x*5.0+TIME*0.22)*sin(VERTEX.z*6.0-TIME*0.13);
    VERTEX+=NORMAL*ripple*0.018;
}
void fragment() {
    float height=smoothstep(-0.45,0.45,local_vertex.y);
    ALBEDO=color.rgb*mix(0.62,1.18,height);
    ROUGHNESS=1.0;
    SPECULAR=0.08;
    EMISSION=ALBEDO*0.035;
    float rim=smoothstep(0.0,0.6,abs(dot(normalize(NORMAL),normalize(VIEW))));
    ALPHA=opacity*color.a*mix(0.1,1.0,rim);
}
