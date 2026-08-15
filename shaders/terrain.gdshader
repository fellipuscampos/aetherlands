shader_type spatial;
// cull_disabled fica seguro enquanto a winding order da mesh procedural
// nao foi conferida visualmente no editor; depois de validar, pode trocar
// para cull_back para ganhar performance. O fix de normal (FRONT_FACING)
// abaixo garante iluminacao correta mesmo com as duas faces ativas.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float noise_scale = 6.0;
uniform float noise_strength = 0.08;

// Textura real (ambientCG "Ground037", CC0) projetada em triplanar —
// evita esticar/distorcer nas laterais do prisma hexagonal, que planar
// UV simples nao resolveria direito. texture_strength controla o quanto
// ela se mistura com a cor lisa (0 = so cor, 1 = full textura).
uniform sampler2D albedo_tex : source_color, repeat_enable;
uniform float texture_scale = 0.6;
uniform float texture_brightness = 1.6;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.7;

// Uma textura real CC0 por bioma especial (ver HexGrid._material_kind_for
// pra qual mat_kind usa qual). hint_default_white: se o arquivo faltar no
// disco, o sampler cai no branco padrao (a tint sozinha ainda funciona,
// sem pintar o tile de preto).
uniform sampler2D snow_tex : source_color, repeat_enable, hint_default_white;
uniform sampler2D desert_tex : source_color, repeat_enable, hint_default_white;
uniform sampler2D lava_tex : source_color, repeat_enable, hint_default_white;
uniform sampler2D crystal_tex : source_color, repeat_enable, hint_default_white;

// "Sombra de contato" falsa nas paredes do prisma (ver v_local_y) — sem
// isso cada tile lia como um bloco solido/plastico com parede lisa
// uniforme em vez de terreno com profundidade. prism_depth precisa bater
// com `size * LAND_PRISM_DEPTH_FACTOR` de HexGrid._build_hex_prism_mesh
// (setado em HexGrid._build_terrain_multimesh a partir de hex_size, nao
// hardcoded aqui, pra nunca dessincronizar se um dos dois mudar).
uniform float prism_depth : hint_range(0.05, 2.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.35;

// Variacao sutil por tile (requisito: "evitar aspecto de plastico") —
// usa v_seed (aleatorio por instancia, ver HexGrid._rebuild_multimesh),
// separado do ruido de posicao continuo (noise_strength acima), que por
// si só faz dois tiles ADJACENTES do mesmo bioma/altura ficarem quase
// identicos.
uniform float color_variation : hint_range(0.0, 1.0) = 0.15;
uniform float roughness_variation : hint_range(0.0, 1.0) = 0.2;

// Falesia/parede lateral (pedido do usuario: "paredes usam a mesma cor do
// topo, em vez de falesias/rochas") — abaixo deste limiar de NORMAL.y a
// face e considerada parede, nao topo, e vira sempre rocha escura
// (reaproveita lava_tex, unico asset de rocha ja carregado no material,
// ver HexGrid._build_terrain_multimesh — evita precisar baixar um asset
// novo so pra isso).
uniform float cliff_normal_threshold : hint_range(0.0, 1.0) = 0.6;
uniform vec3 cliff_tint : source_color = vec3(0.24, 0.21, 0.19);
uniform float cliff_roughness : hint_range(0.0, 1.0) = 0.92;
// Escurece a falesia por cima de tudo (textura+tint) pra criar uma
// separacao forte e elegante contra o topo plano do bioma (pedido do
// usuario) — 0.65 multiplicando ALBEDO, nao um tom novo por cima.
uniform float cliff_darken : hint_range(0.0, 1.0) = 0.65;

// Micro-relevo no TOPO do prisma (pedido do usuario: "topos perfeitamente
// planos geram visual de tabuleiro") — desloca VERTEX.y por um ruido de
// mundo pequeno, nunca a base (ver vertex(), is_top), pra nao reabrir a
// fresta entre a "saia" submersa e a agua (LAND_PRISM_DEPTH_FACTOR).
uniform float elevation_noise_scale : hint_range(0.5, 20.0) = 3.0;
uniform float elevation_noise_strength : hint_range(0.0, 0.3) = 0.08;

// Volumetria de Montanha/Colina (pedido do usuario) — eleva o CENTRO do
// leque do topo (o unico vertice do mesh que fica exatamente no centro do
// hexagono, ver HexGrid._build_hex_prism_mesh) formando um pico/domo que
// cai ate zero na borda (elevation_height abaixo), encaixando sem fresta
// nos vizinhos pela mesma razao que o micro-relevo encaixa. v_elevation_
// kind vem de INSTANCE_CUSTOM.g (0 = plano, 1 = Colina, 2 = Montanha, ver
// HexGrid._build_terrain_multimesh).
uniform float peak_height : hint_range(0.0, 2.0) = 0.9;
uniform float peak_sharpness : hint_range(0.5, 4.0) = 1.6; // queda mais abrupta que linear perto da borda = base mais rochosa/vertical
uniform float hill_height : hint_range(0.0, 1.0) = 0.35;
// Continuidade de cordilheira (pedido do usuario): ruido de escala BEM
// maior que peak_noise acima (0.05 varia lentamente por dezenas de tiles,
// nao por tile) module a altura INTEIRA do pico — tiles de Montanha
// proximos no mundo caem no MESMO trecho da onda lenta, entao sobem/descem
// juntos formando uma cordilheira continua com picos de altura variada,
// em vez de cada tile ser um cone isolado e independente do vizinho.
uniform float mountain_range_noise_scale : hint_range(0.01, 0.3) = 0.05;
uniform float mountain_range_variation : hint_range(0.0, 1.0) = 0.5;

// Neve no pico (pedido do usuario) — mascara por ALTURA (v_local_y, ja
// inclui o pico) E por INCLINACAO (v_world_normal.y, reusa o MESMO
// limiar de cliff_normal_threshold: a partir do ponto que uma face deixa
// de ser "encosta ingreme o bastante pra virar falesia rochosa", ela
// tambem fica "plana o bastante pra neve se acumular" — encosta continua
// rocha escura mesmo dentro da faixa de altura da neve).
// peak_snow_color (nao "snow_color" — esse nome ja existe como variavel
// LOCAL dentro do branch mat_kind==1/Neve-Gelo-Eterno abaixo, evitar
// colisao/sombreamento de nome com o uniform). Tom fosco/sujo (pedido do
// usuario) em vez de branco puro — branco puro + especular alto e o que
// estourava a iluminacao; ROUGHNESS/SPECULAR da neve tambem baixaram no
// mix() de fragment() mais abaixo pelo mesmo motivo.
uniform vec3 peak_snow_color : source_color = vec3(0.85, 0.9, 0.95);
uniform float snow_threshold : hint_range(0.0, 1.5) = 0.5;
uniform float snow_blend : hint_range(0.01, 1.0) = 0.25;
// Ruido de media frequencia SO na linha da neve (nao na geometria) — pedido
// do usuario: "interdigitar com a rocha escura das encostas" em vez de
// cortar numa linha reta/circular. Perturba o LIMIAR de altura por
// posicao, entao a fronteira neve/rocha vira irregular tipo dedos
// entrelacados, nao um anel geometrico perfeito em volta do pico.
uniform float snow_edge_noise_scale : hint_range(1.0, 30.0) = 10.0;
uniform float snow_edge_noise_strength : hint_range(0.0, 1.0) = 0.35;

// Transicao organica de bioma nas bordas do hexagono — evoluido pra usar
// uma MASCARA GLOBAL (mesma estrategia vencedora da agua, pedido do
// usuario: ver HexGrid._rebuild_biome_overlay/water_shader.gdshader
// overlay_texture). biome_overlay_texture guarda a cor REAL de bioma de
// CADA tile do mapa (ja com o escurecimento de fog-of-war embutido, pra
// nunca vazar cor de tile nao explorado atraves da mistura), amostrada
// aqui por posicao-mundo com filtro linear — a resolucao BAIXA de
// proposito (bem menor que WATER_OVERLAY_RESOLUTION) faz o proprio filtro
// bilinear borrar a cor suavemente entre tiles vizinhos, sem precisar
// reamostrar o vizinho manualmente.
uniform sampler2D biome_overlay_texture : source_color, filter_linear, repeat_disable;
uniform vec2 biome_overlay_half_extents = vec2(50.0, 50.0);
// Ruido de baixa frequencia deslocando a posicao de amostragem da mascara
// (nao so misturar direto) — sem isso a linha de transicao reproduziria a
// MESMA silhueta hexagonal reta de antes, so borrada, em vez de organica.
uniform float biome_blend_warp_scale : hint_range(0.5, 10.0) = 3.0;
uniform float biome_blend_warp_strength : hint_range(0.0, 0.05) = 0.015;
uniform float biome_blend_strength : hint_range(0.0, 1.0) = 0.8;
uniform float edge_blend_start : hint_range(0.0, 1.0) = 0.55;
uniform float edge_noise_scale : hint_range(0.5, 20.0) = 5.0;
uniform float edge_noise_strength : hint_range(0.0, 1.0) = 0.3;
// Raio do hexagono (= hex_size, ver HexGrid._build_terrain_multimesh) —
// normaliza a distancia do vertice ao centro do tile pra 0..1 sem o shader
// precisar conhecer hex_size por outro caminho (prism_depth so da o
// produto hex_size*LAND_PRISM_DEPTH_FACTOR, nao hex_size isolado).
uniform float hex_radius : hint_range(0.1, 10.0) = 1.0;

// Nevoa de guerra (pedido do usuario: "escurecimento direto... corte seco
// no formato do hexagono" virando 3 estados visuais refinados). O canal
// ALFA de biome_overlay_texture guarda o fog_level continuo do tile
// (0=Unexplored, 0.5=Explored, 1=Visible — ver HexGrid._fog_level_for),
// amostrado aqui com o MESMO filtro linear/baixa-resolucao que ja da
// mistura suave de cor de bioma entre vizinhos — reusar essa mascara
// entrega a "borda suave / dithered blending" pedida sem nenhum trabalho
// extra de shader, e sem risco de fog_level e cor de bioma dessincronizarem
// (sao a MESMA textura). Camada final em fragment(), por cima de QUALQUER
// branch anterior (bioma/falesia/neve/leito de rio) — pedido do usuario:
// Unexplored "escondendo o terreno por completo".
// Cinza-azulado fechado (pedido do usuario: o tom anterior, quase branco,
// se confundia com o bioma de Neve/Gelo Eterno real — precisa de contraste
// imediato, nao ler como "mais um pico nevado").
uniform vec3 fog_cloud_color : source_color = vec3(0.35, 0.38, 0.42);
uniform float fog_cloud_noise_scale : hint_range(0.05, 5.0) = 0.5;
uniform float fog_cloud_speed : hint_range(0.0, 0.5) = 0.035;
uniform float fog_cloud_warp_strength : hint_range(0.0, 2.0) = 0.8;
uniform vec3 fog_explored_tint : source_color = vec3(0.55, 0.48, 0.36);
uniform float fog_explored_desaturate : hint_range(0.0, 1.0) = 0.6;
uniform float fog_explored_darken : hint_range(0.0, 1.0) = 0.4;

varying vec3 world_pos;
varying vec3 v_world_normal;
varying vec2 v_local_xz; // posicao LOCAL (antes do MODEL_MATRIX) no plano XZ — pra distancia ao centro do tile (transicao de borda)
varying float v_local_y; // altura LOCAL do vertice dentro do prisma (0 = topo, -prism_depth = base) — so pra sombra de contato falsa
varying float v_seed; // aleatorio por tile (INSTANCE_CUSTOM.r) — variacao de cor/rugosidade
varying float v_elevation_kind; // INSTANCE_CUSTOM.g: 0 = plano, 1 = Colina, 2 = Montanha (ver HexGrid._build_terrain_multimesh)
// Qual tratamento visual especial este tile usa (ver HexGrid._material_
// kind_for): 0 = terreno comum, 1 = Neve/Gelo Eterno, 2 = Deserto,
// 3 = Lava, 4 = Campos de Cristal. Agua/Mar de Lava NAO passam mais por
// este shader (tem shader proprio, ver shaders/water_shader.gdshader e
// shaders/lava_shader.gdshader) — mat_kind 5 (Mar de Lava) nunca aparece
// aqui, so existe pro proposito historico de HexGrid._material_kind_for.
varying float v_material_kind;

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

// Nuvem volumetrica animada da nevoa de guerra (ver uniforms fog_cloud_*
// acima) — 2 camadas de value_noise com domain-warp, mesma tecnica ja usada
// no resto do arquivo, so em movimento lento via TIME. Funcao pura (recebe
// `t` como parametro em vez de ler TIME direto) pra deixar explicito que a
// unica dependencia externa e essa, sem nenhum built-in magico de fragment().
float fog_cloud_pattern(vec2 world_xz, float t) {
	vec2 p = world_xz * fog_cloud_noise_scale;
	vec2 drift = vec2(t * fog_cloud_speed, t * fog_cloud_speed * 0.6);
	vec2 warp = vec2(
		value_noise((p + drift) * 0.5),
		value_noise((p - drift) * 0.5 + vec2(17.3, 9.1))
	) * fog_cloud_warp_strength;
	float n1 = value_noise(p + drift + warp);
	float n2 = value_noise(p * 1.8 - drift * 1.3 + warp);
	return clamp(n1 * 0.6 + n2 * 0.4, 0.0, 1.0);
}

// Altura extra (acima do topo plano padrao) num ponto do topo do prisma.
// local_xz e a posicao LOCAL (relativa ao CENTRO do tile, r=0 no centro,
// r=hex_radius na borda); world_xz e a mesma posicao em espaco MUNDO, so
// pro ruido (chave estavel entre tiles vizinhos, ver vertex()). Chamada
// tanto pra deslocar VERTEX.y quanto (por diferenca central) pra
// recalcular a normal — por isso e uma funcao pura de posicao, nao lê
// nenhum built-in magico (permitido fora de fragment(), so o contrario
// que da erro nesta versao da Godot).
float elevation_height(vec2 local_xz, vec2 world_xz, float elevation_kind) {
	float r = length(local_xz) / max(hex_radius, 0.001);

	float h = (value_noise(world_xz * elevation_noise_scale) - 0.5) * elevation_noise_strength;
	if (elevation_kind > 1.5) {
		// Montanha: pico alto, queda mais abrupta que linear (peak_sharpness
		// > 1) perto da borda pra dar uma base mais vertical/rochosa em vez
		// de um cone raso. peak_noise (alta frequencia) quebra a simetria
		// radial perfeita DENTRO do tile — sem isso todo pico seria o MESMO
		// cone geometrico. range_factor (baixissima frequencia, pedido do
		// usuario) faz a MAGNITUDE do pico variar lentamente pelo MUNDO —
		// tiles de Montanha vizinhos caem no mesmo trecho da onda lenta e
		// sobem/descem juntos, formando cordilheira continua em vez de
		// cones isolados e independentes.
		float shape = pow(clamp(1.0 - r, 0.0, 1.0), peak_sharpness);
		float peak_noise = 0.75 + 0.5 * value_noise(world_xz * 4.0);
		float range_noise = value_noise(world_xz * mountain_range_noise_scale) - 0.5;
		float range_factor = 1.0 + range_noise * 2.0 * mountain_range_variation;
		h += peak_height * shape * peak_noise * range_factor;
	} else if (elevation_kind > 0.5) {
		// Colina: domo suave (smoothstep em vez de pow — sobe/desce mais
		// gradual, sem o "topo achatado" que pow(x,>1) da perto do centro).
		float shape = 1.0 - smoothstep(0.0, 1.0, r);
		h += hill_height * shape;
	}

	return h;
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
	v_seed = INSTANCE_CUSTOM.r;
	v_elevation_kind = INSTANCE_CUSTOM.g;
	v_material_kind = INSTANCE_CUSTOM.a;
	v_local_xz = VERTEX.xz;

	// A borda superior do prisma tem DOIS vertices na mesma posicao local
	// (um pertencendo ao leque do topo, outro a parede — copias separadas,
	// ver HexGrid._build_hex_prism_mesh, cada add_vertex() cria uma entrada
	// nova mesmo com posicao coincidente). So o NORMAL ORIGINAL (antes de
	// qualquer alteracao abaixo) distingue os dois: leque do topo usa
	// Vector3.UP (NORMAL.y=1), parede usa side_normal horizontal
	// (NORMAL.y=0) pros DOIS pares (topo E base da parede).
	float is_top_face = step(0.5, NORMAL.y);

	// MODEL_MATRIX das instancias de terreno e SO translacao (ver
	// HexGrid._build_terrain_multimesh: Transform3D(Basis(), world), sem
	// rotacao/escala) — entao a posicao mundo XZ de um vertice nao muda
	// se a gente alterar VERTEX.y depois, e podemos calcular uma vez so
	// aqui e reusar como chave de ruido estavel.
	vec3 pre_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Desloca a altura de QUALQUER vertice na borda SUPERIOR (VERTEX.y ~ 0)
	// — leque do topo E borda superior da parede JUNTOS, pra nao abrir uma
	// fresta vertical entre topo e parede na propria borda do tile. Nunca a
	// base da parede (VERTEX.y ~ -prism_depth), senao reabriria a fresta da
	// saia submersa (LAND_PRISM_DEPTH_FACTOR). elevation_height() cobre TANTO
	// o micro-relevo de sempre QUANTO o pico/domo de Montanha/Colina — os
	// dois precisam da MESMA chave de posicao (mundo pro ruido, local pro
	// raio ao centro do tile) pra fechar sem fresta com os vizinhos, ja que
	// na borda (r=hex_radius) o termo de pico/domo cai pra exatamente zero.
	float is_top_edge = float(VERTEX.y > -0.001);
	VERTEX.y += elevation_height(VERTEX.xz, pre_world.xz, v_elevation_kind) * is_top_edge;

	// Normal recalculada por diferenca central na MESMA funcao de altura
	// (mesma tecnica das ondas da agua, ver water_shader.gdshader
	// procedural_wave_normal) — cobre tanto o tremor sutil do micro-relevo
	// QUANTO a encosta real de um pico de Montanha (a diferenca de altura
	// entre dois pontos vizinhos vira bem maior perto de um pico, entao a
	// normal inclina de verdade, dando sombra/luz marcada na encosta em vez
	// de luz uniforme so pela silhueta). So mistura na face do TOPO
	// (is_top_face, nao is_top_edge): a borda superior da PAREDE precisa
	// manter o normal horizontal original mesmo deslocada, senao a deteccao
	// de falesia (cliff_normal_threshold) erraria bem na beirada do tile.
	float eps = 0.35;
	float h_l = elevation_height(VERTEX.xz + vec2(-eps, 0.0), pre_world.xz + vec2(-eps, 0.0), v_elevation_kind);
	float h_r = elevation_height(VERTEX.xz + vec2(eps, 0.0), pre_world.xz + vec2(eps, 0.0), v_elevation_kind);
	float h_d = elevation_height(VERTEX.xz + vec2(0.0, -eps), pre_world.xz + vec2(0.0, -eps), v_elevation_kind);
	float h_u = elevation_height(VERTEX.xz + vec2(0.0, eps), pre_world.xz + vec2(0.0, eps), v_elevation_kind);
	vec3 bump_normal = normalize(vec3(h_l - h_r, 2.0 * eps, h_d - h_u));
	NORMAL = mix(NORMAL, bump_normal, is_top_face);

	v_local_y = VERTEX.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Normal em espaco mundo so pros pesos do triplanar e a deteccao de
	// falesia (cliff_normal_threshold) — abs() nos pesos do triplanar
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

	// Falesia/parede lateral tem prioridade sobre TUDO abaixo (inclusive
	// os branches de bioma especial) — pedido do usuario: parede nunca usa
	// a cor/textura do bioma do topo, sempre rocha escura.
	bool is_cliff = v_world_normal.y < cliff_normal_threshold;

	float n = value_noise(world_pos.xz * noise_scale);

	// Transicao organica de bioma perto da borda do hexagono, via mascara
	// global (ver uniforms acima) — so faz sentido no TOPO, entao fica de
	// fora do branch de falesia (que ja sobrescreve ALBEDO inteiro). edge_
	// factor (posicao local dentro do hexagono + ruido) continua decidindo
	// ONDE a mistura fica mais forte; agora o ALVO da mistura e a cor real
	// do bioma vizinho amostrada da mascara, nao mais um tom neutro fixo.
	float edge_dist = length(v_local_xz) / hex_radius;
	float edge_n = value_noise(world_pos.xz * edge_noise_scale) - 0.5;
	float edge_factor = clamp(edge_dist + edge_n * edge_noise_strength, 0.0, 1.0);
	float transition_amount = smoothstep(edge_blend_start, 1.0, edge_factor) * biome_blend_strength;

	vec2 biome_uv = world_pos.xz / (biome_overlay_half_extents * 2.0) + 0.5;
	vec2 biome_warp = vec2(
		value_noise(world_pos.xz * biome_blend_warp_scale) - 0.5,
		value_noise(world_pos.xz * biome_blend_warp_scale + vec2(37.1, 91.7)) - 0.5
	) * biome_blend_warp_strength;
	vec4 overlay_sample = texture(biome_overlay_texture, biome_uv + biome_warp);
	vec3 blended_biome_color = overlay_sample.rgb;
	// Nivel de visibilidade continuo (0=Unexplored, 0.5=Explored, 1=Visible),
	// amostrado a FORCA TOTAL (nao multiplicado por transition_amount, que e
	// so pra mistura de COR de bioma perto da borda) — a nevoa precisa se
	// aplicar em TODO pixel do tile, nao so perto da borda, ver uso no fim
	// de fragment().
	float fog_level = overlay_sample.a;
	vec3 edge_blended_color = mix(COLOR.rgb, blended_biome_color, transition_amount);

	vec3 tint = edge_blended_color
		* (1.0 - noise_strength * 0.5 + n * noise_strength)
		* (1.0 - color_variation * 0.5 + v_seed * color_variation);

	int mat_kind = int(v_material_kind + 0.5);
	vec3 weights = triplanar_weights(v_world_normal);

	if (is_cliff) {
		// Reaproveita lava_tex (ambientCG "Rock035", unico asset de rocha
		// ja carregado no material, ver HexGrid._build_terrain_multimesh)
		// pra TODA parede, independente do bioma do topo — e so uma
		// textura de pedra escura, nao "lava" tematicamente aqui.
		vec3 cliff_tex_color = triplanar_sample(lava_tex, world_pos, weights, texture_scale) * texture_brightness;
		ALBEDO = mix(cliff_tint, cliff_tex_color, 0.6) * (0.85 + v_seed * 0.3);
		// Escurece por cima de tudo (pedido do usuario) — separa fortemente
		// a parede do topo plano do bioma em vez de so mudar a textura.
		ALBEDO *= cliff_darken;
		ROUGHNESS = cliff_roughness;
		SPECULAR = 0.15;
		METALLIC = 0.0;
	} else if (mat_kind == 1) {
		// Neve/Gelo Eterno: textura real de neve (ambientCG "Snow006")
		// com brilho pontual tipo cristal de gelo pegando luz por cima.
		vec3 snow_color = triplanar_sample(snow_tex, world_pos, weights, texture_scale) * texture_brightness;
		float sparkle = pow(clamp(value_noise(world_pos.xz * 18.0), 0.0, 1.0), 6.0);
		ALBEDO = tint * snow_color + vec3(sparkle * 0.5);
		ROUGHNESS = 0.35;
		SPECULAR = 0.6;
		METALLIC = 0.0;
	} else if (mat_kind == 2) {
		// Deserto: textura real de areia (ambientCG "Ground033") com
		// ondulacao de duna (faixas) por cima.
		vec3 sand_color = triplanar_sample(desert_tex, world_pos, weights, texture_scale) * texture_brightness;
		float dune = sin(world_pos.x * 3.0 + world_pos.z * 1.5 + n * 4.0) * 0.5 + 0.5;
		ALBEDO = tint * sand_color * (0.82 + dune * 0.32);
		ROUGHNESS = 0.85;
		METALLIC = 0.0;
	} else if (mat_kind == 3) {
		// Lava (bioma vulcanico, terreno solido): so pedra negra real
		// (ambientCG "Rock035") sem brilho nenhum — o brilho de verdade
		// fica so pro Mar de Lava (shaders/lava_shader.gdshader).
		vec3 rock_tex_color = triplanar_sample(lava_tex, world_pos, weights, texture_scale) * texture_brightness;
		ALBEDO = tint * rock_tex_color * 0.6;
		ROUGHNESS = 0.75;
		METALLIC = 0.0;
	} else if (mat_kind == 4) {
		// Campos de Cristal: textura facetada tipo gelo rachado (ambientCG
		// "Ice003", tingida na cor do bioma) com leve brilho magico.
		vec3 crystal_tex_color = triplanar_sample(crystal_tex, world_pos, weights, texture_scale) * texture_brightness;
		float facet = pow(clamp(value_noise(world_pos.xz * 10.0 + vec2(TIME * 0.1, 0.0)), 0.0, 1.0), 3.0);
		ALBEDO = tint * crystal_tex_color + vec3(facet * 0.4);
		EMISSION = tint * facet * 0.6;
		ROUGHNESS = 0.2;
		SPECULAR = 0.8;
		METALLIC = 0.0;
	} else {
		vec3 tex_color = triplanar_sample(albedo_tex, world_pos, weights, texture_scale) * texture_brightness;
		vec3 textured = tint * tex_color;
		ALBEDO = mix(tint, textured, texture_strength);
		ROUGHNESS = 0.9;
		METALLIC = 0.0;
	}

	// Rocha predominando no CORPO da Montanha (pedido do usuario: "a encosta
	// precisa mostrar rocha escura... deixando a neve apenas nos topos mais
	// planos"). O branch is_cliff acima ja cobre as PAREDES retas do prisma,
	// mas a encosta do DOMO gerado por elevation_height e tecnicamente
	// "topo" (mat_kind generico, textura de chao) mesmo sendo ingreme — sem
	// isso a Montanha lia como "gramada" fora da propria parede vertical.
	// rockiness cresce suavemente conforme a face fica mais inclinada
	// (mesmo limiar de cliff_normal_threshold), sobrepondo rocha por cima
	// da textura generica so onde faz sentido fisico.
	if (v_elevation_kind > 1.5 && !is_cliff) {
		vec3 mountain_rock_color = triplanar_sample(lava_tex, world_pos, weights, texture_scale) * texture_brightness;
		float rockiness = 1.0 - smoothstep(cliff_normal_threshold, 1.0, v_world_normal.y);
		ALBEDO = mix(ALBEDO, mix(cliff_tint, mountain_rock_color, 0.6) * (0.85 + v_seed * 0.3), rockiness);
		ROUGHNESS = mix(ROUGHNESS, cliff_roughness, rockiness);
	}

	// Neve no pico da Montanha (pedido do usuario) — por cima de QUALQUER
	// branch acima (inclusive falesia/rocha, se a encosta entrar na faixa de
	// altura mas ainda for ingreme demais pra neve grudar). Duas mascaras
	// independentes, multiplicadas: ALTURA (v_local_y, ja inclui o pico —
	// so acima de snow_threshold, com o limiar em si perturbado por ruido
	// pra a fronteira "interdigitar" com a rocha em vez de cortar reto) E
	// INCLINACAO (v_world_normal.y, reusa cliff_normal_threshold como o
	// MESMO limiar onde uma face deixa de ser "ingreme demais" — a mesma
	// inclinacao que define rocha exposta tambem define onde a neve nao se
	// acumula). So Montanha (v_elevation_kind > 1.5) — Colina fica com o
	// bioma original, pedido do usuario.
	if (v_elevation_kind > 1.5) {
		float snow_edge_noise = value_noise(world_pos.xz * snow_edge_noise_scale) - 0.5;
		float local_snow_threshold = snow_threshold + snow_edge_noise * snow_edge_noise_strength;
		float snow_height_mask = smoothstep(local_snow_threshold - snow_blend, local_snow_threshold, v_local_y);
		float snow_slope_mask = smoothstep(cliff_normal_threshold, cliff_normal_threshold + 0.15, v_world_normal.y);
		float snow_mask = snow_height_mask * snow_slope_mask;
		// Fosco (pedido do usuario): rugosidade alta, especular baixo — o
		// brilho pontual sob o sol era o que lia como "estourado em branco".
		ALBEDO = mix(ALBEDO, peak_snow_color, snow_mask);
		ROUGHNESS = mix(ROUGHNESS, 0.8, snow_mask);
		SPECULAR = mix(SPECULAR, 0.15, snow_mask);
	}

	// Sombra de contato falsa: escurece as PAREDES do prisma perto da
	// base (v_local_y -> -prism_depth), nunca o topo (v_local_y == 0) —
	// cada tile passa a ter uma transicao suave na propria borda em vez
	// de parede lisa uniforme, sem precisar re-tesselar o mapa numa
	// grade continua (o SSAO do WorldEnvironment cobre o resto, nas
	// frestas entre vizinhos de altura parecida).
	float wall_ao = 1.0 - clamp(-v_local_y / max(prism_depth, 0.001), 0.0, 1.0) * ao_strength;
	ALBEDO *= wall_ao;

	// Rugosidade varia um pouco por tile (mesmo seed da cor) — evita o
	// aspecto "plastico" de todo tile do mesmo bioma refletir luz IDENTICO.
	ROUGHNESS = clamp(ROUGHNESS + (v_seed - 0.5) * roughness_variation, 0.0, 1.0);

	// Nevoa de guerra — 3 estados com transicao suave via fog_level continuo
	// (ver uniforms fog_cloud_*/fog_explored_* e overlay_sample acima) — por
	// cima de QUALQUER branch anterior (bioma/falesia/neve/leito de rio),
	// pedido do usuario ("Unexplored escondendo o terreno por completo").
	// Dois smoothstep encadeados nos keypoints 0/0.5/1 dao a interpolacao
	// Unexplored -> Explored -> Visible sem nenhum corte: em fog_level=0 o
	// resultado e 100% cloud_albedo, em 0.5 e 100% sepia_albedo, em 1.0 e
	// 100% ALBEDO original — e a mistura JA fica suave entre tiles vizinhos
	// de graca, porque fog_level em si vem de uma textura de baixa
	// resolucao com filtro linear (nao um valor uniforme "seco" por tile).
	float sepia_luma = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
	vec3 sepia_albedo = mix(vec3(sepia_luma), fog_explored_tint * (sepia_luma + 0.3), fog_explored_desaturate) * (1.0 - fog_explored_darken);

	float cloud_pattern = fog_cloud_pattern(world_pos.xz, TIME);
	vec3 cloud_albedo = fog_cloud_color * (0.7 + cloud_pattern * 0.5);

	float fog_cloud_weight = 1.0 - smoothstep(0.0, 0.5, fog_level);
	vec3 stage_unexplored_to_explored = mix(cloud_albedo, sepia_albedo, smoothstep(0.0, 0.5, fog_level));
	ALBEDO = mix(stage_unexplored_to_explored, ALBEDO, smoothstep(0.5, 1.0, fog_level));

	// Achata reflexo/brilho sob nuvem (senao a "nuvem" lia como terreno
	// molhado/plastico com o mesmo especular de baixo) e apaga emissao
	// (evita um Campo de Cristal brilhando por baixo de uma nuvem que
	// deveria escondê-lo por completo).
	ROUGHNESS = mix(ROUGHNESS, 0.95, fog_cloud_weight);
	SPECULAR = mix(SPECULAR, 0.05, fog_cloud_weight);
	EMISSION *= mix(1.0 - fog_explored_darken, 1.0, smoothstep(0.5, 1.0, fog_level)) * smoothstep(0.0, 0.35, fog_level);
}
