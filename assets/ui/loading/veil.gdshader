shader_type canvas_item;
render_mode unshaded;
void fragment() {
    float lower_band = smoothstep(0.42, 0.72, UV.y);
    float edge = smoothstep(0.28, 0.78, distance(UV, vec2(0.58, 0.40)));
    COLOR = vec4(vec3(0.025, 0.070, 0.087), clamp(0.12 + lower_band * 0.84 + edge * 0.22, 0.0, 0.98));
}
