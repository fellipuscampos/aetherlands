shader_type spatial;
// CAMADA DE NÉVOA DE GUERRA (FogLayer): um bloco hexagonal opaco por tile NUNCA VISTO, acima do mapa — tampa e
// paredes, do nível FogLayer.TOP_Y até abaixo do plano de água. Pedido do usuário 2026-10-12: "a fog foi feita de forma
// errada por ser uma textura sobre a superfície; ela devia ser algo acima do mapa cobrindo o chão, assim não dá pra
// ver nada do que tem embaixo, como se fosse uma camada realmente".
//
// É geometria de verdade, então cobre terra e mar com a MESMA superfície na MESMA altura: nada do relevo, da costa,
// das ondas ou das sombras de quem está embaixo chega a ser desenhado por cima dela (o terreno nunca visto nem é
// desenhado: terrain.gdshader recolhe o prisma do tile). Tile explorado ou visível = bloco recolhido a um ponto
// (triângulos degenerados, custo de rasterização zero).
//
// Leve: o estado vem de UMA textura de 1 texel por tile (fog_state.gdshaderinc), lida uma vez por vértice; o
// fragmento é um ruído de 2 amostras. Iluminada pela cena (acompanha dia, noite e clima sem código próprio), fosca.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

#include "res://shaders/fog_state.gdshaderinc"

uniform vec3 fog_color : source_color = vec3(0.30, 0.33, 0.39);
uniform vec3 fog_color_deep : source_color = vec3(0.20, 0.22, 0.28);
uniform float cloud_scale : hint_range(0.02, 2.0) = 0.22;
uniform float cloud_speed : hint_range(0.0, 0.5) = 0.02;
// Paredes um pouco mais escuras que a tampa: a borda da camada lê como espessura, não como tinta no chão.
uniform float wall_shade : hint_range(0.0, 1.0) = 0.72;
// DESTAQUE (alcance de movimento, ataque, trajeto, obra) em tile nunca visto — uma unidade pode andar para dentro da
// névoa, e o jogador precisa ver até onde. 1 texel por tile na mesma grade do estado (HexGrid._apply_fog_highlight):
// rgb = cor, a = força. Sem textura = transparente (nenhum destaque).
uniform sampler2D fog_highlight_texture : source_color, hint_default_transparent, filter_nearest, repeat_disable;

varying vec3 world_pos;
varying float is_top;
varying flat vec2 tile_uv;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	vec2 tile_xz = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz;
	tile_uv = fog_tile_uv(tile_xz);
	if (textureLod(fog_state_texture, tile_uv, 0.0).r >= 0.25) {
		VERTEX = vec3(0.0);
	}
	is_top = step(0.5, NORMAL.y);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Nuvem lenta em espaço de mundo: contínua de um bloco para o vizinho, sem denunciar a grade.
	vec2 drift = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.6);
	float cloud = value_noise(world_pos.xz * cloud_scale + drift) * 0.65 + value_noise(world_pos.xz * cloud_scale * 2.7 - drift * 1.4) * 0.35;
	vec3 color = mix(fog_color_deep, fog_color, cloud);
	vec4 highlight = texture(fog_highlight_texture, tile_uv);
	color = mix(color, highlight.rgb, highlight.a * is_top);
	ALBEDO = color * mix(wall_shade, 1.0, is_top);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
