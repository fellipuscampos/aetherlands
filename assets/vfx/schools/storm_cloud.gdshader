shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// Pouco volume e baixa opacidade: a área e as tropas continuam legíveis sob a tempestade.
uniform vec4 color : source_color = vec4(0.43, 0.50, 0.59, 0.19);
uniform float opacity = 1.0;
varying float face_light;

void vertex() {
    face_light = mix(0.72, 1.12, NORMAL.y * 0.5 + 0.5);
}

void fragment() {
    ALBEDO = color.rgb * COLOR.rgb * face_light;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    ALPHA = color.a * opacity;
}
