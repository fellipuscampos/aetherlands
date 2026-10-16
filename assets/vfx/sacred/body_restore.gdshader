shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float floor_y = 0.0;
uniform float body_height = 1.8;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_color : source_color = vec4(0.62, 0.92, 0.80, 1.0);
uniform vec4 band_color : source_color = vec4(1.0, 0.91, 0.58, 1.0);
varying vec3 world_vertex;

void vertex() {
    world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float height = (world_vertex.y - floor_y) / max(body_height, 0.2);
    float band = height;
    float sweep = 1.0 - smoothstep(0.04, 0.22, abs(band - progress * 1.2));
    ALBEDO = mix(base_color.rgb, band_color.rgb, sweep);
    float rim = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
    EMISSION = band_color.rgb * sweep * strength * 0.35;
    ALPHA = strength * (rim*0.10 + sweep * 0.18);
}
