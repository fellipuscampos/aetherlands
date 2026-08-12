shader_type spatial;
// UM plano continuo pra TODO liquido do mapa (agua E lava) — nao 2 planos
// sobrepostos (isso cortava o mapa ao meio: com os dois cobrindo a mesma
// area e nenhum escrevendo profundidade — depth_draw_never — a ordem de
// blend entre eles virava inconsistente pela cena, reportado pelo
// usuario) nem 1 prisma por tile (isso dava fresta entre vizinhos,
// reportado antes). HexGrid._rebuild_water_overlay manda uma textura
// dizendo, pixel a pixel, "isso aqui e agua ou lava" (liquid_type_texture)
// — o fragment() abaixo escolhe qual dos dois "modos" desenhar. blend_mix:
// translucido pro degrade de profundidade (DEPTH_TEXTURE) e pra deixar o
// fundo/costa aparecer por baixo perto da praia. depth_draw_never: nao
// escreve no depth buffer (nao afeta a LEITURA do depth_texture, que
// sempre reflete o passe OPACO/terreno).
render_mode blend_mix, cull_back, depth_draw_never, diffuse_burley, specular_schlick_ggx;

// ---------------------------------------------------------------------
// Fog-of-war / destaque de movimento / classificacao agua-vs-lava — ver
// HexGrid._rebuild_water_overlay. overlay: RGB = multiplicador de destaque
// de movimento/ataque/construcao (nao mais a nevoa de guerra em si, ver
// abaixo), A = 0 pra Mar Gelado / 1 pra Oceano comum. liquid_type: R = 0
// (agua) ou 1 (Mar de Lava) — filtro linear da uma borda levemente
// suavizada de graca onde um lago de lava encontra agua; A = fog_level
// continuo (0=Unexplored, 0.5=Explored, 1=Visible — mesma semantica do
// canal alfa de biome_overlay_texture em terrain.gdshader).
// ---------------------------------------------------------------------
uniform sampler2D overlay_texture : filter_linear, repeat_disable;
uniform sampler2D liquid_type_texture : filter_linear, repeat_disable;
uniform vec2 overlay_half_extents = vec2(50.0, 50.0);

// Nevoa de guerra (pedido do usuario: "a camada de nuvens deve cobrir a
// agua nao explorada da mesma forma que cobre a terra... transicao
// terra/mar homogenea") — MESMOS valores padrao de terrain.gdshader
// fog_cloud_color/fog_explored_* pra a nuvem/sepia lerem como uma unica
// camada continua atravessando a linha da costa, nao dois tratamentos
// diferentes se encontrando na praia.
uniform vec3 fog_cloud_color : source_color = vec3(0.35, 0.38, 0.42);
uniform float fog_cloud_noise_scale : hint_range(0.05, 5.0) = 0.5;
uniform float fog_cloud_speed : hint_range(0.0, 0.5) = 0.035;
uniform float fog_cloud_warp_strength : hint_range(0.0, 2.0) = 0.8;
uniform vec3 fog_explored_tint : source_color = vec3(0.55, 0.48, 0.36);
uniform float fog_explored_desaturate : hint_range(0.0, 1.0) = 0.6;
uniform float fog_explored_darken : hint_range(0.0, 1.0) = 0.4;

// ---------------------------------------------------------------------
// Agua — ondas (2 camadas em direcoes/velocidades opostas)
// ---------------------------------------------------------------------
uniform vec2 wave_direction_a = vec2(1.0, 0.4);
uniform vec2 wave_direction_b = vec2(-0.6, 1.0);
uniform float wave_speed_a : hint_range(0.0, 2.0) = 0.35;
uniform float wave_speed_b : hint_range(0.0, 2.0) = 0.22;
// Baixo de proposito (pedido do usuario: "ondas amplas e suaves") — em
// cima do fix de precisao do hash() acima, uma escala pequena tambem
// mantem o argumento do seno mais longe do regime onde a precisao
// degrada, entao os dois ajustes se reforcam.
uniform float wave_scale : hint_range(0.01, 1.0) = 0.08;
uniform float water_normal_strength : hint_range(0.0, 3.0) = 1.1;
// Segunda camada, BEM mais fina que wave_scale — sem ela a agua ficava
// "lisa demais" (wave_scale baixo sozinho da inchaco amplo mas nenhum
// tremor fino, lida como plastico). Direcoes/velocidades DIFERENTES das
// camadas de wave_scale (nao um multiplo simples delas) de proposito,
// pra nunca correlacionar visualmente e parecer um padrao repetido.
uniform float detail_scale : hint_range(0.1, 5.0) = 0.6;
uniform float detail_strength : hint_range(0.0, 2.0) = 0.6;

// Normal maps DE VERDADE sao opcionais. O plano e sempre perfeitamente
// plano/horizontal em espaco mundo, entao uma base tangente manual
// T=(1,0,0)/B=(0,0,1)/N=(0,1,0) e 100% correta pra ele (mais simples que
// depender do TANGENT autoral do PlaneMesh). Sem arquivo no disco,
// texture() com sampler vazio cai em preto — inofensivo, texture_influence
// fica em 0 por padrao (mix() zera a contribuicao) e o visual usa so o
// normal PROCEDURAL abaixo, ja funciona bonito sem nenhum asset externo.
uniform sampler2D wave_normal_a : repeat_enable;
uniform sampler2D wave_normal_b : repeat_enable;
uniform float texture_influence : hint_range(0.0, 1.0) = 0.0;

// filter_nearest (nao linear/mipmap) de proposito: um buffer de
// profundidade tem descontinuidades DURAS nas silhuetas dos objetos —
// filtrar linearmente mistura profundidade de perto com profundidade de
// longe bem na borda de qualquer coisa, criando um halo/franja errado
// exatamente onde a tecnica de espuma/degrade mais precisa ser exata (a
// linha da costa).
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

// Cores/transparencia estilo Civilization VI (pedido do usuario) — rasa
// turquesa clara e mais transparente, funda azul-marinho e quase opaca.
// ALPHA vem exatamente do alpha destes uniforms (0.45 raso / 0.92 fundo),
// nao mais multiplicado por um "water_transparency" generico por cima.
uniform vec4 shallow_color : source_color = vec4(0.15, 0.65, 0.75, 0.45);
uniform vec4 deep_color : source_color = vec4(0.02, 0.12, 0.38, 0.92);
// Subiu de 1.0 -> 1.6 -> 2.2 (pedido do usuario, 3a rodada: transicao
// ainda mais gradual, "deixar transparecer sutilmente a parede submersa
// do terreno atraves da agua") — quanto maior, mais longe da costa o azul
// profundo so aparece, entao a faixa rasa/translucida (que revela o
// prisma submerso por baixo, ver LAND_PRISM_DEPTH_FACTOR em HexGrid.gd)
// fica mais larga.
uniform float depth_fade_distance : hint_range(0.05, 5.0) = 2.2;
uniform vec4 frozen_tint : source_color = vec4(0.82, 0.9, 0.95, 1.0); // Mar Gelado (overlay.a=0) mistura essa cor palida/gelada por cima

// Espuma em "linhas" deslizando pra costa (sin(depth_diff*foam_frequency
// - TIME*foam_speed), pedido do usuario) — foam_noise_scale/foam_speed
// tambem quebram essas linhas em manchas organicas por cima, pra nao
// ficarem retas/artificiais demais.
// Branco azulado (pedido do usuario, 4a rodada) em vez de branco puro —
// combina melhor com o turquesa raso em vez de destoar frio/artificial.
uniform vec4 foam_color : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform float foam_distance : hint_range(0.01, 2.0) = 0.55;
uniform float foam_frequency : hint_range(1.0, 40.0) = 14.0;
uniform float foam_speed : hint_range(0.0, 5.0) = 1.8;
uniform float foam_noise_scale : hint_range(1.0, 20.0) = 6.0;
// Subiu 1.4 -> 1.6 pra compensar a remocao do pow() acima: sem ele o
// foam_wave passa mais tempo perto de 0 (o vale do pulso), entao o pico
// (foam_wave perto de 1) precisa de um pouco mais de ganho pra continuar
// lendo como espuma "cheia" e nao so um brilho fraco passageiro.
uniform float foam_intensity : hint_range(0.0, 2.0) = 1.6;

// Rugosidade baixa / especular alta (pedido do usuario, 3a rodada:
// "brilho cintilante da luz") — 0.2/0.5 concentra mais o reflexo do sol
// do que o 0.3/0.4 anterior, mas o normal de duas camadas (broad+detail)
// ja quebra esse reflexo em varios pontos tremulando em vez de um
// "holofote" unico e liso (o problema da rodada anterior, quando o
// shader ainda nao tinha a camada de detail_scale pra tremer a normal).
uniform float water_roughness : hint_range(0.0, 1.0) = 0.2;
uniform float water_specular : hint_range(0.0, 1.0) = 0.5;
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.0;
uniform float fresnel_alpha_boost : hint_range(0.0, 1.0) = 0.35;

// ---------------------------------------------------------------------
// Lava — fluxo turbulento (2 camadas com domain warp)
// ---------------------------------------------------------------------
uniform vec2 flow_direction_a = vec2(1.0, 0.3);
uniform vec2 flow_direction_b = vec2(-0.5, 0.9);
uniform float flow_speed_a : hint_range(0.0, 2.0) = 0.18;
uniform float flow_speed_b : hint_range(0.0, 2.0) = 0.11;
uniform float flow_scale : hint_range(0.5, 10.0) = 2.2;
uniform float lava_normal_strength : hint_range(0.0, 3.0) = 0.6; // lava e mais viscosa/lisa que agua, superficie menos agitada

uniform vec4 lava_color_cool : source_color = vec4(0.25, 0.04, 0.02, 1.0);
uniform vec4 lava_color_hot : source_color = vec4(1.0, 0.55, 0.08, 1.0);
uniform float emission_strength : hint_range(0.0, 3.0) = 1.2;
// Teto absoluto de EMISSION (soma do brilho base + borda) — pedido do
// usuario: sem isso a lava estourava os pixels da tela (bloom lendo
// como um clarao branco em vez de uma superficie incandescente
// controlada). clamp() no fragment() abaixo, nao so o uniform limitado.
uniform float max_emission : hint_range(0.0, 5.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.6; // "respiracao" lenta do brilho, nao so ruido estatico
uniform float lava_transparency : hint_range(0.0, 1.0) = 0.97; // lava e densa: quase opaca por padrao, diferente de agua

uniform vec4 edge_glow_color : source_color = vec4(1.0, 0.75, 0.2, 1.0);
uniform float edge_glow_width : hint_range(0.01, 2.0) = 0.4;
uniform float edge_glow_strength : hint_range(0.0, 3.0) = 1.2;

uniform float lava_roughness : hint_range(0.0, 1.0) = 0.35;
uniform float lava_specular : hint_range(0.0, 1.0) = 0.5;

varying vec3 world_pos;

// mod() limita a magnitude ANTES do seno — sin() na GPU perde precisao
// pra angulos grandes (milhares de radianos), causando um artefato de
// "quadriculado"/ladrilho repetitivo (reportado pelo usuario) e, no pior
// caso, um vetor de normal completamente errado onde a magnitude e maior
// (perto dos CANTOS do mapa, onde |world_pos.x| e |world_pos.z| sao
// maximos ao MESMO tempo — exatamente onde o usuario viu uma "onda
// gigante e distorcida"). Sem isso, `moved` em procedural_wave_normal/
// turbulent_flow crescia sem limite (posicao mundo * escala, MAIS
// TIME * velocidade acumulando pra sempre com o tempo de jogo) ate sair
// da faixa onde sin() ainda e preciso. 1000.0 e bem maior que qualquer
// area visivel de perto (mapa Grande tem ~100 unidades de raio), entao a
// costura do wrap-around nunca fica visivel em uso normal.
float hash(vec2 p) {
	p = mod(p, 1000.0);
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

// Nuvem volumetrica animada da nevoa de guerra — MESMA tecnica/formula de
// terrain.gdshader fog_cloud_pattern (2 camadas de value_noise com domain-
// warp, TIME passado como parametro em vez de lido direto), duplicada aqui
// porque shaders nao compartilham codigo entre arquivos neste projeto
// (mesmo padrao de hash()/value_noise() acima, cada shader com sua propria
// copia). Precisa ser uma copia FIEL (nao so "parecida") pra nuvem de agua
// e nuvem de terra se moverem em sincronia e a transicao na costa nunca
// criar uma costura visivel entre os dois shaders.
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

// Normal pseudo-procedural derivado por diferenca central sobre um campo
// de ruido "em movimento" — dispensa textura de normal map de verdade.
// `scale` e passado pelo chamador (wave_scale pras ondas amplas,
// detail_scale pro tremor fino, ver fragment()) em vez de usar o uniform
// wave_scale direto, pra uma funcao so servir as duas camadas.
vec3 procedural_wave_normal(vec2 pos, vec2 dir, float speed, float t, float scale) {
	vec2 moved = pos * scale + dir * speed * t;
	float e = 0.08;
	float h = value_noise(moved);
	float hx = value_noise(moved + vec2(e, 0.0));
	float hz = value_noise(moved + vec2(0.0, e));
	float dx = (hx - h) / e;
	float dz = (hz - h) / e;
	return normalize(vec3(-dx * water_normal_strength, 1.0, -dz * water_normal_strength));
}

// 2 camadas de ruido em direcoes opostas, uma delas amostrando a posicao
// JA deslocada pela outra (domain warp) — da a leitura de rocha derretida
// "remoinhando" em vez de duas ondas planas se sobrepondo.
float turbulent_flow(vec2 pos, float t) {
	vec2 p1 = pos * flow_scale + flow_direction_a * flow_speed_a * t;
	float warp = value_noise(p1) * 2.0 - 1.0;
	vec2 p2 = pos * flow_scale * 1.4 + flow_direction_b * flow_speed_b * t + warp * 0.6;
	return value_noise(p2);
}

vec3 procedural_flow_normal(vec2 pos, float t) {
	float e = 0.08;
	float h = turbulent_flow(pos, t);
	float hx = turbulent_flow(pos + vec2(e, 0.0), t);
	float hz = turbulent_flow(pos + vec2(0.0, e), t);
	float dx = (hx - h) / e;
	float dz = (hz - h) / e;
	return normalize(vec3(-dx * lava_normal_strength, 1.0, -dz * lava_normal_strength));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Tudo dentro de UMA fragment() so (nao em funcoes auxiliares
// water_pass()/lava_pass() separadas, como numa primeira versao) — Godot
// nesta versao nao deixa funcao auxiliar ler/escrever os built-ins
// magicos do estagio de fragmento (NORMAL, ALBEDO, VIEW, SCREEN_UV etc),
// "Unknown identifier" testado na pratica. Os dois ramos (agua/lava) tem
// nomes de variavel local diferentes de proposito, entao nenhum conflito
// mesmo os dois vivendo na mesma funcao.
void fragment() {
	vec2 overlay_uv = world_pos.xz / (overlay_half_extents * 2.0) + 0.5;
	vec4 overlay = texture(overlay_texture, overlay_uv);
	vec4 type_sample = texture(liquid_type_texture, overlay_uv);
	float is_lava = type_sample.r;
	float fog_level = type_sample.a;

	// Reconstroi a profundidade linear do que esta ATRAS do liquido
	// (terreno ja desenhado no passe opaco) e compara com a profundidade
	// da propria superficie — a diferenca e "quanto liquido tem ali":
	// perto de zero = costa rasa (espuma na agua / borda incandescente na
	// lava), grande = fundo (cor escura na agua) / interior (cor quente
	// na lava).
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float scene_depth = -view.z;
	float surface_depth = -VERTEX.z;
	float depth_diff = max(scene_depth - surface_depth, 0.0);

	if (is_lava > 0.5) {
		float t = TIME;
		vec3 lava_world_normal = procedural_flow_normal(world_pos.xz, t);
		NORMAL = normalize((VIEW_MATRIX * vec4(lava_world_normal, 0.0)).xyz);

		float flow = turbulent_flow(world_pos.xz, t);
		float pulse = sin(t * pulse_speed + world_pos.x * 0.5 + world_pos.z * 0.5) * 0.5 + 0.5;
		float heat = clamp(flow * 0.7 + pulse * 0.3, 0.0, 1.0);
		vec3 lava_color = mix(lava_color_cool.rgb, lava_color_hot.rgb, heat);

		float edge_mask = 1.0 - smoothstep(0.0, edge_glow_width, depth_diff);
		vec3 lava_final_color = mix(lava_color, edge_glow_color.rgb, edge_mask);

		vec3 base_emission = lava_color * emission_strength * (0.3 + heat * 0.7);
		vec3 edge_emission = edge_glow_color.rgb * edge_glow_strength * edge_mask;
		// Teto absoluto (pedido do usuario) — sem isso a soma base+borda
		// podia passar de 5+ em HDR bruto, estourando o glow numa mancha
		// branca cega em vez de ler como superficie incandescente.
		// overlay.rgb SEMPRE fica em [0,1] (fog/destaque so escurece,
		// nunca amplifica — ver HexGrid._rebuild_water_overlay), entao
		// multiplicar por ele depois do clamp nunca reabre a
		// possibilidade de estourar de novo.
		vec3 lava_emission = clamp(base_emission + edge_emission, 0.0, max_emission);

		ALBEDO = lava_final_color * overlay.rgb;
		EMISSION = lava_emission * overlay.rgb;
		ALPHA = lava_transparency;
		ROUGHNESS = lava_roughness;
		SPECULAR = lava_specular;
		METALLIC = 0.0;
	} else {
		float v_animate = overlay.a; // 0 = Mar Gelado (parado, sem espuma), 1 = Oceano comum
		float t = TIME * v_animate;

		// Camada AMPLA (wave_scale, inchaco suave) + camada de DETALHE
		// (detail_scale, tremor fino) — a amplo sozinho lia como plastico
		// liso (reportado pelo usuario); a fina sozinha reintroduziria o
		// artefato de tiling do wave_scale alto de antes. As duas juntas,
		// em direcoes/escalas cruzadas, dao "agua tremulando" sem padrao
		// repetido.
		vec3 n_broad = normalize(
			procedural_wave_normal(world_pos.xz, wave_direction_a, wave_speed_a, t, wave_scale)
			+ procedural_wave_normal(world_pos.xz, wave_direction_b, wave_speed_b, t, wave_scale)
		);
		vec3 n_detail = procedural_wave_normal(world_pos.xz, wave_direction_a + wave_direction_b, (wave_speed_a + wave_speed_b) * 0.8, t, detail_scale);
		vec3 n_proc = normalize(n_broad + n_detail * detail_strength);
		vec2 uv_a = world_pos.xz * 0.15 + wave_direction_a * wave_speed_a * t * 0.1;
		vec2 uv_b = world_pos.xz * 0.19 + wave_direction_b * wave_speed_b * t * 0.1;
		vec3 tsn_a = texture(wave_normal_a, uv_a).rgb * 2.0 - 1.0;
		vec3 tsn_b = texture(wave_normal_b, uv_b).rgb * 2.0 - 1.0;
		vec3 t_axis = vec3(1.0, 0.0, 0.0);
		vec3 b_axis = vec3(0.0, 0.0, 1.0);
		vec3 n_axis = vec3(0.0, 1.0, 0.0);
		vec3 n_tex = normalize(t_axis * (tsn_a.x + tsn_b.x) + b_axis * (tsn_a.y + tsn_b.y) + n_axis * (tsn_a.z + tsn_b.z));
		vec3 water_world_normal = normalize(mix(n_proc, n_tex, texture_influence));
		NORMAL = normalize((VIEW_MATRIX * vec4(water_world_normal, 0.0)).xyz);

		// smoothstep (pedido do usuario), nao clamp linear — transicao rasa
		// -> funda com "ombros" suaves em vez de uma rampa reta.
		float depth_factor = smoothstep(0.0, depth_fade_distance, depth_diff);
		vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_factor);
		water_color = mix(water_color, frozen_tint.rgb, (1.0 - v_animate) * 0.5);
		float base_alpha = mix(shallow_color.a, deep_color.a, depth_factor);

		// Linhas de espuma deslizando pra costa (pedido do usuario):
		// sin(depth_diff*foam_frequency - TIME*foam_speed) da as "cristas"
		// se movendo; foam_falloff restringe isso a perto da costa
		// (depth_diff pequeno); foam_noise quebra as linhas em manchas
		// organicas em vez de retas perfeitas.
		//
		// foam_wave usado SEM pow() de proposito (3a rodada de ajuste,
		// pedido do usuario: espuma "viva"/pulsante na praia, nao uma fita
		// estatica) — a rodada anterior tinha pow(foam_wave, 0.6), que
		// alargava a fase "acesa" tanto que o valor quase nunca descia
		// perto de 0, entao a oscilacao do seno ficava imperceptivel (lida
		// como espuma parada, so a POSICAO da faixa mudava com a costa,
		// nunca a INTENSIDADE). Sem o pow(), o brilho da espuma sobe e desce
		// (0->1->0) de verdade a cada ciclo — e essa respiracao ritmica que
		// da o efeito de onda "quebrando" e recuando.
		float foam_falloff = 1.0 - smoothstep(0.0, foam_distance, depth_diff);
		float foam_wave = sin(depth_diff * foam_frequency - t * foam_speed) * 0.5 + 0.5;
		float foam_noise = value_noise(world_pos.xz * foam_noise_scale + vec2(t * foam_speed * 0.08, -t * foam_speed * 0.05));
		float foam_mask = foam_falloff * foam_wave * smoothstep(0.1, 0.9, foam_noise);
		foam_mask = clamp(foam_mask * foam_intensity, 0.0, 1.0) * v_animate; // Mar Gelado nunca tem espuma

		// Pico branco cintilante (pedido do usuario, 4a rodada): foam_mask
		// ja mistura foam_color proporcional ao pulso, mas fica "lavado"
		// pelo foam_noise (manchas organicas) — o resultado nunca chega
		// perto do branco puro de foam_color mesmo no auge do seno. foam_crest
		// usa SO foam_wave (sem o noise) elevado a uma potencia alta pra
		// concentrar um "flash" nitido bem no topo da onda (foam_wave -> 1),
		// somado por CIMA do mix normal em vez de substituir — e isso que
		// faz o contorno da praia cintilar em branco sobre o turquesa raso
		// a cada pulso, em vez de so um turquesa mais claro.
		float foam_crest = pow(foam_wave, 5.0) * foam_falloff * v_animate;
		vec3 water_final_color = mix(water_color, foam_color.rgb, foam_mask) + foam_color.rgb * foam_crest * 0.6;
		water_final_color = clamp(water_final_color, 0.0, 1.0);
		float water_alpha = clamp(mix(base_alpha, foam_color.a, foam_mask), 0.0, 1.0);

		float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
		water_alpha = clamp(water_alpha + fresnel * fresnel_alpha_boost, 0.0, 1.0);

		ALBEDO = water_final_color * overlay.rgb;
		ALPHA = water_alpha;
		ROUGHNESS = water_roughness;
		SPECULAR = water_specular;
		METALLIC = 0.0;
	}

	// Nevoa de guerra — mesma logica de terrain.gdshader (2 smoothstep
	// encadeados nos keypoints 0/0.5/1 de fog_level: Unexplored 100% nuvem,
	// Explored 100% sepia, Visible 100% cor original), por cima de QUALQUER
	// um dos dois ramos acima (agua OU lava) — pedido do usuario: cobrir a
	// agua nao explorada "da mesma forma que cobre a terra", nao deixar so
	// escura, com transicao homogenea entre terra e mar na mesma area de
	// Terra Incognita.
	float sepia_luma = dot(ALBEDO, vec3(0.299, 0.587, 0.114));
	vec3 sepia_albedo = mix(vec3(sepia_luma), fog_explored_tint * (sepia_luma + 0.3), fog_explored_desaturate) * (1.0 - fog_explored_darken);

	float cloud_pattern = fog_cloud_pattern(world_pos.xz, TIME);
	vec3 cloud_albedo = fog_cloud_color * (0.7 + cloud_pattern * 0.5);

	float fog_cloud_weight = 1.0 - smoothstep(0.0, 0.5, fog_level);
	vec3 stage_unexplored_to_explored = mix(cloud_albedo, sepia_albedo, smoothstep(0.0, 0.5, fog_level));
	ALBEDO = mix(stage_unexplored_to_explored, ALBEDO, smoothstep(0.5, 1.0, fog_level));

	// Sob nuvem a agua/lava fica opaca (senao daria pra ver o degrade de
	// profundidade/espuma/brilho por baixo de uma nuvem que deveria
	// escondê-la por completo) — volta ao ALPHA natural assim que
	// fog_level passa de Unexplored (Explored e Visible mostram a forma
	// real do liquido, so Unexplored precisa esconder).
	ALPHA = mix(1.0, ALPHA, smoothstep(0.0, 0.5, fog_level));
	ROUGHNESS = mix(ROUGHNESS, 0.95, fog_cloud_weight);
	SPECULAR = mix(SPECULAR, 0.05, fog_cloud_weight);
	EMISSION = mix(EMISSION, vec3(0.0), fog_cloud_weight) * mix(1.0 - fog_explored_darken, 1.0, smoothstep(0.5, 1.0, fog_level));
}
