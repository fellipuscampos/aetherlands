shader_type spatial;
// cull_disabled fica seguro enquanto a winding order da mesh procedural
// nao foi conferida visualmente no editor; depois de validar, pode trocar
// para cull_back para ganhar performance. O fix de normal (FRONT_FACING)
// abaixo garante iluminacao correta mesmo com as duas faces ativas.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float noise_scale = 6.0;
uniform float noise_strength = 0.08;
uniform float water_wave_height = 0.06;
uniform float water_wave_speed = 1.6;

// Textura real (ambientCG "Ground037", CC0) projetada em triplanar —
// evita esticar/distorcer nas laterais do prisma hexagonal, que planar
// UV simples nao resolveria direito. So aplicada em tiles que nao sao
// agua (o oceano usa o glint animado abaixo). texture_strength controla
// o quanto ela se mistura com a cor lisa (0 = como era antes, 1 = full
// textura) — de proposito exposto como uniform pra dar pra ajustar no
// Inspector do material sem mexer no shader.
uniform sampler2D albedo_tex : source_color, repeat_enable;
uniform float texture_scale = 0.6;
uniform float texture_brightness = 1.6;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.7;

varying vec3 world_pos;
varying vec3 v_world_normal;
varying float v_is_water;
varying float v_phase;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec3 triplanar_weights(vec3 world_normal) {
	vec3 blending = abs(world_normal);
	blending = max(blending, vec3(0.00001));
	return blending / (blending.x + blending.y + blending.z);
}

vec3 triplanar_sample(sampler2D tex, vec3 pos, vec3 weights, float scale) {
	vec3 x_axis = texture(tex, pos.yz * scale).rgb;
	vec3 y_axis = texture(tex, pos.xz * scale).rgb;
	vec3 z_axis = texture(tex, pos.xy * scale).rgb;
	return x_axis * weights.x + y_axis * weights.y + z_axis * weights.z;
}

void vertex() {
	v_is_water = INSTANCE_CUSTOM.r;
	v_phase = INSTANCE_CUSTOM.g;

	if (v_is_water > 0.5) {
		VERTEX.y += sin(TIME * water_wave_speed + v_phase * 6.2831853) * water_wave_height;
	}

	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Normal em espaco mundo so pros pesos do triplanar — abs() nos pesos
	// torna o sinal irrelevante, entao nao precisa do fix de FRONT_FACING
	// que o NORMAL (espaco de view, usado pra iluminacao) recebe abaixo.
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 normal = NORMAL;
	if (!FRONT_FACING) {
		normal = -normal;
	}
	NORMAL = normal;

	float n = value_noise(world_pos.xz * noise_scale);
	vec3 tint = COLOR.rgb * (1.0 - noise_strength * 0.5 + n * noise_strength);

	if (v_is_water > 0.5) {
		float glint = value_noise(world_pos.xz * noise_scale * 2.5 + vec2(TIME * 0.35, TIME * 0.2));
		ALBEDO = tint + vec3(glint * 0.12);
		ROUGHNESS = 0.1;
		SPECULAR = 0.9;
		METALLIC = 0.0;
	} else {
		vec3 weights = triplanar_weights(v_world_normal);
		vec3 tex_color = triplanar_sample(albedo_tex, world_pos, weights, texture_scale) * texture_brightness;
		vec3 textured = tint * tex_color;
		ALBEDO = mix(tint, textured, texture_strength);
		ROUGHNESS = 0.9;
		METALLIC = 0.0;
	}
}
