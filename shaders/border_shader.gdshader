shader_type spatial;
// Malha: uma fita FINA (SurfaceTool) por cidade, um trecho por aresta
// EXTERNA do territorio (City.owned_tiles) — ver HexGrid._build_city_
// border_mesh. Redesenhado (pedido do usuario: a versao anterior, mais
// larga e brilhante, lia como "fita de neon" — o alvo agora e uma linha
// fina, tracejada, estilo tinta/marcador territorial, mais perto do
// Civilization VI que de um efeito de scifi).
//
// COLOR.rgb = cor da civilizacao dona, OU a mesma cor passada por
// HexGrid._sepia_prop_color se o tile daquele trecho estiver so EXPLORED
// (nunca VISIBLE agora) — fog fica INTEIRO embutido por vertice a cada
// reconstrucao (mesmo padrao de COLOR.rgb em river_shader.gdshader), tile
// UNSEEN nem gera geometria (0 triangulos pra aquele trecho).
// COLOR.a = 1.0 (VISIBLE) ou HexGrid.EXPLORED_BORDER_ALPHA (EXPLORED).
//
// UV.x = 0.0 na aresta EXTERNA (limite real do territorio, onde a linha
// assenta) ate 1.0 na aresta INTERNA (deslocada BORDER_THICKNESS pra
// dentro, ~0.025 — bem mais fina que antes) — usado abaixo tanto pro
// contorno escuro nas duas margens quanto pro fade final rumo ao chao.
// UV.y = distancia de MUNDO ao longo do trecho (0..hex_size, reinicia a
// cada aresta) — usado pro padrao tracejado, em unidades fixas de mundo
// pra todo traco/vao ter o MESMO tamanho em qualquer lugar do mapa.
render_mode blend_mix, cull_disabled, depth_draw_always, unshaded;

// Contorno escuro (pedido do usuario: "contraste... visivel tanto na
// neve/areia clara quanto na grama/agua escura") — mistura pra essa cor
// nas duas margens da fita (perto de UV.x=0 e UV.x=1), cor cheia do
// jogador so no miolo. outline_width e a fracao (de edge_dist, 0=centro,
// 1=margem) que vira contorno.
uniform vec4 outline_color : source_color = vec4(0.05, 0.05, 0.06, 0.9);
uniform float outline_width : hint_range(0.0, 1.0) = 0.35;

// Tracejado (pedido do usuario: "padrao tracejado... espacamentos
// regulares"), em unidades de MUNDO ao longo de UV.y — cada aresta de
// hexagono mede exatamente hex_size, entao dash_length+gap_length = 0.5
// da 2 repeticoes de traco+vao por aresta num mapa com hex_size padrao
// (1.0). dash_softness suaviza a transicao traco/vao (evita serrilhado
// duro na borda do traco).
uniform float dash_length : hint_range(0.01, 2.0) = 0.3;
uniform float gap_length : hint_range(0.0, 2.0) = 0.2;
uniform float dash_softness : hint_range(0.0, 0.25) = 0.04;

// Emissao BEM reduzida (pedido do usuario: "remova o brilho/glow
// exagerado... linha opaca ou levemente semi-transparente, cor limpa e
// nitida") — so o suficiente pra linha nao sumir sob sombra forte, longe
// do "glow" antigo.
uniform float emission_strength : hint_range(0.0, 1.0) = 0.2;

// Fade final BEM perto da margem interna so — a linha agora e fina o
// bastante pra nao precisar de um degrade largo, so um acabamento suave
// nos ultimos passos rumo ao chao (a margem EXTERNA, UV.x perto de 0,
// fica sempre solida — e o limite territorial de verdade).
uniform float inner_fade_start : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	float edge_dist = abs(UV.x - 0.5) * 2.0; // 0 no centro da fita, 1 em qualquer margem
	float outline_mask = smoothstep(1.0 - outline_width, 1.0, edge_dist);
	vec3 line_color = mix(COLOR.rgb, outline_color.rgb, outline_mask);
	float line_alpha = mix(1.0, outline_color.a, outline_mask);

	float period = dash_length + gap_length;
	float phase = mod(UV.y, period);
	float dash_mask = 1.0 - smoothstep(dash_length - dash_softness, dash_length + dash_softness, phase);

	float inner_fade = 1.0 - smoothstep(inner_fade_start, 1.0, UV.x);

	ALBEDO = line_color;
	EMISSION = line_color * emission_strength;
	// Sem no_depth_test (pedido do usuario, "reative o Depth Test") — o
	// deslocamento geometrico real (HexGrid.BORDER_ABOVE_OFFSET) ja evita
	// z-fighting contra o terreno, entao o depth test padrao (nao
	// desligado aqui) deixa a linha corretamente OCLUIDA atras de um morro
	// na frente da camera, em vez do "raio-X" de antes.
	ALPHA = COLOR.a * line_alpha * inner_fade * dash_mask;
}
