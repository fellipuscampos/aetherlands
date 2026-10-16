shader_type canvas_item;
render_mode unshaded;

// The illustration stays still. A dark veil provides a quiet, readable menu area.
void fragment() {
	float left_veil = 1.0 - smoothstep(0.28, 0.64, UV.x);
	float edges = smoothstep(0.32, 0.72, distance(UV, vec2(0.56, 0.43)));
	float bottom = smoothstep(0.72, 1.0, UV.y);
	float opacity = clamp(0.12 + left_veil * 0.83 + edges * 0.22 + bottom * 0.42, 0.0, 0.98);
	COLOR = vec4(vec3(0.025, 0.070, 0.087), opacity);
}
