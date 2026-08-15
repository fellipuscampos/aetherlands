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
// (agua) ou 1 (Mar de Lava); G = distancia normalizada ate a costa (ver
// COAST_DISTANCE_NORM_MAX abaixo); A = fog_level continuo (0=Unexplored,
// 0.5=Explored, 1=Visible — mesma semantica do canal alfa de
// biome_overlay_texture em terrain.gdshader).
// ---------------------------------------------------------------------
uniform sampler2D overlay_texture : filter_linear, repeat_disable;
uniform sampler2D liquid_type_texture : filter_linear, repeat_disable;
uniform vec2 overlay_half_extents = vec2(50.0, 50.0);

// Classificacao lava-vs-agua EXATA por TILE (pedido do usuario: "quero que
// as celulas de lava ocupem a celula inteira" — duas rodadas anteriores
// (filtro linear, depois nearest) sobre liquid_type_texture MELHORARAM mas
// nunca eliminaram o problema, porque QUALQUER amostragem continua de uma
// grade de baixa resolucao (WATER_OVERLAY_RESOLUTION, pro mapa INTEIRO)
// nunca alinha perfeitamente com o contorno HEXAGONAL de verdade — nearest
// so trocou "recuo suave" por "escada de pixels em blocos". lava_tile_mask
// (HexGrid._rebuild_lava_tile_mask) tem 1 TEXEL POR TILE — o fragment()
// abaixo converte world_pos.xz pro coord axial EXATO do tile que aquele
// pixel realmente pertence (world_to_axial_round, porta fiel de
// HexMetrics.world_to_axial/_round_axial) e busca DIRETO esse tile —
// garantido bater com a fronteira hexagonal real, sem zona fracionaria/
// blocao nenhuma, ja que nao e mais uma amostra de POSICAO continua, e sim
// um lookup EXATO por indice de tile.
uniform sampler2D lava_tile_mask : filter_nearest, repeat_disable;
// Tamanho da grade (map_width x map_height, 1:1 com HexGrid.tiles) e o
// deslocamento pra converter col/row (pode ser negativo) num indice de
// texel valido — TEM que bater com HexGrid._rebuild_lava_tile_mask (mesmos
// nomes/valores, comentado la tambem).
uniform vec2 lava_grid_size = vec2(1.0, 1.0);
uniform vec2 lava_grid_half = vec2(0.0, 0.0);
uniform float lava_hex_size : hint_range(0.1, 10.0) = 1.0;

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
// Terceira camada, escala fina de verdade (bem mais alta que detail_scale)
// cruzando wave_direction_a/b em vez de somar as duas numa unica direcao
// combinada como detail_scale faz (pedido do usuario: "duas camadas de
// normal maps em escala fina se cruzando em direcoes levemente opostas...
// reflexos cintilantes de sol nas cristas"). E ESSA alta frequencia que
// quebra o reflexo especular unico em varios glints pequenos tremulando —
// o efeito "caustics"/cintilante pedido nao e uma textura separada, e uma
// consequencia direta de NORMAL variando bastante pixel a pixel (o pipeline
// specular_schlick_ggx do render_mode ja faz o resto).
uniform float fine_scale : hint_range(0.5, 12.0) = 3.2;
uniform float fine_strength : hint_range(0.0, 2.0) = 0.5;

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

// Cores/transparencia estilo Civilization VI/VII (pedido do usuario:
// "gradiente de 3 cores... raso turquesa/esmeralda cristalino, medio azul
// vivo, profundo azul-marinho escuro e denso"). ALPHA vem exatamente do
// alpha destes uniforms. RGB do shallow_color escureceu um pouco (era
// 0.85/0.8, pedido do usuario: "cor da agua rasa nas bordas dos
// continentes ta muito clara") — alfa (0.88) ficou igual, a mudanca e so
// tom, nao opacidade.
uniform vec4 shallow_color : source_color = vec4(0.0, 0.68, 0.64, 0.88);
uniform vec4 mid_color : source_color = vec4(0.06, 0.42, 0.68, 0.78);
uniform vec4 deep_color : source_color = vec4(0.01, 0.09, 0.32, 0.95);
// PROFUNDIDADE REAL (via depth_diff/DEPTH_TEXTURE) so existe numa faixa
// finissima: agua nao tem malha de fundo do mar submersa, so a "saia"
// vertical do prisma de terreno (LAND_PRISM_DEPTH_FACTOR em HexGrid.gd) —
// alem da borda do hex, depth_diff salta quase direto pro maximo (pedido
// do usuario, regressao: "shader salta direto pro azul escuro logo apos a
// borda do hexagono"). COAST_DISTANCE_NORM_MAX/coast_band_tiles/
// coast_mid_extent_tiles abaixo dao uma "falsa profundidade" baseada em
// DISTANCIA HORIZONTAL ate a terra mais proxima (baked por HexGrid.
// _compute_coast_distance_tiles/_rebuild_water_overlay, canal G de
// liquid_type_texture) — combinada com a profundidade real via min() no
// fragment(), pra nunca ficar mais rasa do que a distancia manda mesmo
// se/quando o depth real disser "profundo" cedo demais.
//
// TEM que bater com a const homonima em HexGrid.gd (mesmo comentario la).
const float COAST_DISTANCE_NORM_MAX = 6.0;
uniform float coast_band_tiles : hint_range(0.3, 3.0) = 1.25; // largura do turquesa raso, em tiles (pedido do usuario: "1.0 a 1.5 tiles")
uniform float coast_mid_extent_tiles : hint_range(1.0, 6.0) = 3.5; // a partir daqui (em tiles) e oceano aberto/profundo pra fins de distancia
uniform float shallow_fade_distance : hint_range(0.02, 3.0) = 0.7;
uniform float depth_fade_distance : hint_range(0.05, 5.0) = 2.2;

// Mar Gelado (pedido do usuario, ultima rodada: "faça o mar gelado ser a
// mesma água do resto do mapa, porém com a cor mais esbranquiçada apenas"
// — versoes anteriores tambem mudavam roughness/specular e congelavam a
// animacao, o que lia como plastico/pintura estatica; agora e a MESMA
// agua, ver fragment(), so a cor muda). Azul-branco bem claro — nao e
// branco puro (isso lia como isopor numa rodada anterior), mas
// perceptivelmente mais claro/esbranquicado que a agua aberta. Alfa < 1.0
// mantem o gelo TRANSLUCIDO — o degrade raso/fundo por baixo
// (shallow_color/deep_color) ainda transparece um pouco por baixo.
uniform vec4 frozen_tint : source_color = vec4(0.8, 0.88, 0.92, 0.75);

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

// Rugosidade baixa / especular alta (pedido do usuario, ultima rodada:
// "aumente levemente a intensidade da luz especular... pontos cintilantes
// de luz solar nas micro-ondas" — subiu 0.5 -> 0.62). O normal agora tem
// TRES camadas (broad+detail+fine, ver fine_scale/fine_strength acima) que
// ja quebram o reflexo em varios pontos tremulando em vez de um "holofote"
// unico e liso, entao o specular mais alto vira glints pequenos e nao um
// brilho chapado.
uniform float water_roughness : hint_range(0.0, 1.0) = 0.2;
uniform float water_specular : hint_range(0.0, 1.0) = 0.62;
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.0;
uniform float fresnel_alpha_boost : hint_range(0.0, 1.0) = 0.35;

// ---------------------------------------------------------------------
// Lava — crosta de basalto + fendas de magma (pedido do usuario: o visual
// anterior era um mix linear cool->hot sobre o campo de turbulencia
// INTEIRO, sem nenhuma area realmente escura/solida contrastando — a
// maior parte da superficie acabava lendo como um amarelo/laranja
// uniforme e brilhante ("polenta"), nao rocha vulcanica de verdade.
// ---------------------------------------------------------------------
uniform vec2 flow_direction_a = vec2(1.0, 0.3);
uniform vec2 flow_direction_b = vec2(-0.5, 0.9);
uniform float flow_speed_a : hint_range(0.0, 2.0) = 0.18;
uniform float flow_speed_b : hint_range(0.0, 2.0) = 0.11;
uniform float flow_scale : hint_range(0.5, 10.0) = 2.2;
uniform float lava_normal_strength : hint_range(0.0, 3.0) = 0.6; // lava e mais viscosa/lisa que agua, superficie menos agitada

// Placas de basalto (rocha vulcanica solida escura) cobrem a MAIOR PARTE
// da superficie por padrao — so' as fendas (ver lava_fissure_* abaixo)
// mostram o magma por baixo.
uniform vec4 lava_crust_color : source_color = vec4(0.05, 0.04, 0.045, 1.0);
// Fenda de magma incandescente entre as placas — vermelho-fogo/laranja
// intenso, com EMISSION concentrada so' aqui (ver lava_fissure_mask no
// fragment()), nao espalhada pela superficie inteira.
uniform vec4 lava_fissure_color : source_color = vec4(1.0, 0.32, 0.05, 1.0);
// Largura da fenda, como fracao do campo de turbulencia (banda estreita
// em volta do meio do range) — estreito de proposito, senao vira um
// mosaico grosso em vez de uma rede fina de rachaduras.
uniform float lava_fissure_width : hint_range(0.01, 0.4) = 0.09;
// Escala do padrao de placas — maior = placas maiores/mais espacadas.
uniform float lava_crust_scale : hint_range(0.3, 6.0) = 1.6;
// Bem mais lento que a "respiracao" do brilho (pulse_speed abaixo) — as
// placas se movem devagar (pedido do usuario: "flutuam lentamente"), a
// fenda cintila mais rapido por cima. turbulent_flow ja tem domain-warp
// de 2 camadas embutido (ver funcao acima), entao esse deslocamento lento
// ja da a "distorcao de textura" animada pedida de graca.
uniform float lava_plate_drift_speed : hint_range(0.0, 1.0) = 0.05;

uniform float emission_strength : hint_range(0.0, 3.0) = 1.2;
// Teto absoluto de EMISSION (soma do brilho base + borda) — pedido do
// usuario: sem isso a lava estourava os pixels da tela (bloom lendo
// como um clarao branco em vez de uma superficie incandescente
// controlada). clamp() no fragment() abaixo, nao so o uniform limitado.
uniform float max_emission : hint_range(0.0, 5.0) = 2.2;
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.6; // "respiracao" do brilho nas fendas (pedido do usuario: "brilho pulsante no magma")
uniform float lava_transparency : hint_range(0.0, 1.0) = 0.97; // lava e densa: quase opaca por padrao, diferente de agua

// Distancia (depth_diff) onde o magma fica mais quente/brilhante perto da
// agua/rocha externa — ver edge_mask no fragment(). Cor da borda NAO e mais
// um uniform separado (edge_glow_color, removido — pedido do usuario: "a
// borda amarela neon estatica" lia como um contorno artificial); o brilho
// da borda agora reusa lava_fissure_color, a MESMA paleta de magma da
// fenda, entao a borda "pulsa junto" em vez de ficar plana.
uniform float edge_glow_width : hint_range(0.01, 2.0) = 0.4;

// Subiu de 0.35 (pedido do usuario: crosta de rocha, nao mais liquido
// homogeneo — rocha vulcanica e bem mais fosca que a superficie liquida
// anterior).
uniform float lava_roughness : hint_range(0.0, 1.0) = 0.55;
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

// Porta EXATA de HexMetrics.world_to_axial/_round_axial (GDScript,
// scripts/world/HexMetrics.gd) — dado world_xz, devolve o coord axial
// (q, r) do tile que REALMENTE contem esse ponto. Arredondamento em
// coordenada CUBO (x+y+z=0, y=-x-z), nao um floor/round ingenuo direto em
// (q, r) — um round ingenuo erraria perto dos CANTOS do hexagono (onde a
// distancia pro proprio centro E pro centro do vizinho diagonal fica bem
// parecida); o metodo cubo corrige o componente com MAIOR erro de
// arredondamento pra sempre fechar x+y+z=0 de novo, dando o tile certo ate
// exatamente na fronteira. Usado pra buscar lava_tile_mask (ver uniforms
// acima) com precisao EXATA de tile.
vec2 world_to_axial_round(vec2 world_xz, float size) {
	float q = (sqrt(3.0) / 3.0 * world_xz.x - 1.0 / 3.0 * world_xz.y) / size;
	float r = (2.0 / 3.0 * world_xz.y) / size;
	float x = q;
	float z = r;
	float y = -x - z;
	float rx = round(x);
	float ry = round(y);
	float rz = round(z);
	float x_diff = abs(rx - x);
	float y_diff = abs(ry - y);
	float z_diff = abs(rz - z);
	if (x_diff > y_diff && x_diff > z_diff) {
		rx = -ry - rz;
	} else if (y_diff > z_diff) {
		ry = -rx - rz;
	} else {
		rz = -rx - ry;
	}
	return vec2(rx, rz);
}

// Amostra lava_tile_mask pelo TILE exato de world_xz (nao por posicao
// continua, ver world_to_axial_round acima) — col/row usa o MESMO esquema
// de coordenada offset "odd-r" que HexGrid.generate_map usa pra popular
// `tiles` (invertido: dado axial q/r, `col = q + (row - (row&1))/2`
// desfaz `q = col - (row - (row&1))/2` de generate_map), garantindo
// indices sempre dentro da grade sem precisar de margem extra —
// lava_grid_half (ver uniform acima) desloca pra nunca ficar negativo.
float sample_lava_tile_mask(vec2 world_xz) {
	vec2 axial = world_to_axial_round(world_xz, lava_hex_size);
	int row_i = int(axial.y);
	int col_i = int(axial.x) + (row_i - (row_i & 1)) / 2;
	float px = float(col_i) + lava_grid_half.x;
	float py = float(row_i) + lava_grid_half.y;
	vec2 lava_uv = (vec2(px, py) + 0.5) / lava_grid_size;
	return texture(lava_tile_mask, lava_uv).r;
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
	// Lookup EXATO por tile (ver lava_tile_mask/sample_lava_tile_mask acima)
	// pra decisao de RAMO lava-vs-agua — G/A do gradiente suave continuam
	// vindo de type_sample (linear); R DELE tambem continua em uso mais
	// abaixo (lava_proximity, pro tingimento cosmetico da agua perto de
	// lava), so a decisao de ramo em si e que agora e exata por tile.
	float is_lava = sample_lava_tile_mask(world_pos.xz);
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

		// Placas de basalto flutuando lentamente (pedido do usuario):
		// MESMA funcao de turbulencia usada pro normal acima, mas com seu
		// PROPRIO "tempo" bem mais lento (lava_plate_drift_speed) e escala
		// propria (lava_crust_scale) — nao reusa o `t`/flow_scale cru do
		// normal de proposito, senao as placas se moveriam rapido demais
		// junto com o tremor fino da superficie, sem ler como "flutuando
		// devagar". (lava_crust_scale / flow_scale) cancela o flow_scale
		// que turbulent_flow ja multiplica por dentro, dando controle
		// direto via lava_crust_scale sozinho.
		float plate_field = turbulent_flow(world_pos.xz * (lava_crust_scale / flow_scale), t * lava_plate_drift_speed);
		// Fenda = banda ESTREITA em volta de plate_field == 0.5 (onde o
		// campo de turbulencia cruza o meio do range) — o resto (a maior
		// parte da area) fica solido/escuro (crosta), nao um gradiente
		// amarelo cobrindo tudo.
		float fissure_mask = 1.0 - smoothstep(0.0, lava_fissure_width, abs(plate_field - 0.5));

		// Brilho pulsante do magma NAS FENDAS (pedido do usuario) — a
		// crosta e rocha solida, nao pulsa; so' a fissura "respira".
		float pulse = sin(t * pulse_speed + world_pos.x * 0.5 + world_pos.z * 0.5) * 0.5 + 0.5;
		float fissure_glow = fissure_mask * (0.6 + pulse * 0.4);

		vec3 lava_color = mix(lava_crust_color.rgb, lava_fissure_color.rgb, fissure_mask);

		// Perto da agua/rocha externa (edge_mask, de depth_diff) o magma fica
		// MAIS QUENTE/brilhante — reusa a MESMA cor de fenda (pedido do
		// usuario: "brilho de emissao de magma em fusao natural" em vez de
		// uma cor separada estatica tipo neon, a "borda amarela" removida
		// aqui) e o MESMO pulso da fenda, pra a borda "respirar" junto em vez
		// de ficar parada.
		float edge_mask = 1.0 - smoothstep(0.0, edge_glow_width, depth_diff);
		vec3 lava_final_color = mix(lava_color, lava_fissure_color.rgb, edge_mask * 0.6);

		float edge_glow_boost = edge_mask * (0.6 + pulse * 0.4);
		vec3 base_emission = lava_fissure_color.rgb * emission_strength * max(fissure_glow, edge_glow_boost);
		// Teto absoluto (pedido do usuario) — sem isso o glow podia passar de
		// 5+ em HDR bruto, estourando numa mancha branca cega em vez de ler
		// como superficie incandescente. overlay.rgb SEMPRE fica em [0,1]
		// (fog/destaque so escurece, nunca amplifica — ver HexGrid.
		// _rebuild_water_overlay), entao multiplicar por ele depois do
		// clamp() nunca reabre a possibilidade de estourar de novo.
		vec3 lava_emission = clamp(base_emission, 0.0, max_emission);

		ALBEDO = lava_final_color * overlay.rgb;
		EMISSION = lava_emission * overlay.rgb;
		ALPHA = lava_transparency;
		ROUGHNESS = lava_roughness;
		SPECULAR = lava_specular;
		METALLIC = 0.0;
	} else {
		// 0 = Mar Gelado, 1 = Oceano comum — usado SO pra decidir o tingimento
		// de cor abaixo (frozen_amount). Pedido do usuario (regressao): o Mar
		// Gelado usava isso pra CONGELAR o tempo (t = TIME * v_animate = 0)
		// e trocar roughness/specular por um par fosco — um plano
		// perfeitamente estatico e sem brilho especular e exatamente a
		// definicao visual de "plastico"/superficie pintada, nao de agua.
		// Agora o Mar Gelado usa a MESMA animacao de onda, mesma espuma e
		// MESMO material (roughness/specular) da agua aberta — a UNICA
		// diferenca entre os dois biomas e a cor (mais esbranquicada), ver
		// frozen_amount abaixo.
		float v_animate = overlay.a;
		float t = TIME;

		// Proximidade de Lava (0=longe, 1=bem perto/dentro de um lago de
		// magma) — reusa o canal R de liquid_type_texture (linear, gradiente
		// continuo por posicao-mundo — diferente de lava_tile_mask/is_lava
		// acima, que agora e um lookup EXATO por tile), que rampeia suave
		// 0..1 nos poucos texels perto de uma fronteira real. Pedido do
		// usuario, regressao: "a saia
		// vertical [...] deve usar tom de rocha escuro/basalto [...] sem o
		// efeito de praia/agua" — usado abaixo pra apagar coast_foam e tingir
		// a agua de basalto perto de qualquer Mar de Lava, em vez do turquesa
		// alegre de praia. Nao precisa reconstruir a fronteira exata: mesmo
		// que a classificacao nearest do ramo acima erre por 1 texel perto da
		// borda, o PIOR caso vira um pixel de agua com uma leve tintura de
		// rocha, nunca mais um contorno turquesa berrante colado na lava.
		float lava_proximity = clamp(type_sample.r, 0.0, 1.0);

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
		// Camada fina cruzando A e B DIRETO (nao combinadas numa direcao so,
		// diferente de n_detail acima) em escalas levemente diferentes entre
		// si (fine_scale vs fine_scale*1.15) pra nunca correlacionar/formar
		// um padrao xadrez entre as duas — ver comentario do uniform
		// fine_scale acima pro motivo do brilho cintilante.
		vec3 n_fine = normalize(
			procedural_wave_normal(world_pos.xz, wave_direction_a, wave_speed_a * 1.3, t, fine_scale)
			+ procedural_wave_normal(world_pos.xz, wave_direction_b, wave_speed_b * 1.3, t, fine_scale * 1.15)
		);
		vec3 n_proc = normalize(n_broad + n_detail * detail_strength + n_fine * fine_strength);
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

		// Gradiente de 3 cores (pedido do usuario, estilo Civ VI/VII: raso
		// turquesa/esmeralda -> medio azul vivo -> profundo azul-marinho),
		// mesmo padrao de 2 smoothstep encadeados ja usado pra nevoa de
		// guerra abaixo (Unexplored/Explored/Visible). DOIS sinais
		// independentes alimentam cada transicao, combinados com min()
		// (pedido do usuario: "nao dependa EXCLUSIVAMENTE da profundidade
		// vertical"):
		//   - *_by_depth: profundidade REAL via depth_diff — funciona bem
		//     rente a costa (onde a "saia" do prisma de terreno da um degrade
		//     de verdade), mas satura quase instantaneamente mar adentro (sem
		//     malha de fundo do mar, ver COAST_DISTANCE_NORM_MAX acima).
		//   - *_by_dist: distancia HORIZONTAL ate a terra mais proxima, em
		//     tiles (baked por HexGrid, ver COAST_DISTANCE_NORM_MAX) — nao
		//     depende de geometria nenhuma, garante a largura MINIMA da faixa
		//     turquesa (coast_band_tiles) e da faixa azul-media
		//     (coast_mid_extent_tiles) mesmo onde o sinal de profundidade
		//     falha.
		// min() entre os dois: o pixel so avanca pra proxima cor quando AMBOS
		// os sinais concordam que pode — nunca fica "mais raso" do que a
		// distancia manda, mesmo se/quando o depth real disser "profundo"
		// cedo demais (o bug reportado).
		float shallow_to_mid_by_depth = smoothstep(0.0, shallow_fade_distance, depth_diff);
		float mid_to_deep_by_depth = smoothstep(shallow_fade_distance, depth_fade_distance, depth_diff);
		float coast_dist_tiles = type_sample.g * COAST_DISTANCE_NORM_MAX;
		float shallow_to_mid_by_dist = smoothstep(0.0, coast_band_tiles, coast_dist_tiles);
		float mid_to_deep_by_dist = smoothstep(coast_band_tiles, coast_mid_extent_tiles, coast_dist_tiles);
		float shallow_to_mid = min(shallow_to_mid_by_depth, shallow_to_mid_by_dist);
		float mid_to_deep = min(mid_to_deep_by_depth, mid_to_deep_by_dist);
		vec3 water_color = mix(shallow_color.rgb, mid_color.rgb, shallow_to_mid);
		water_color = mix(water_color, deep_color.rgb, mid_to_deep);

		// ISOLADO ao bioma congelado (pedido do usuario, regressao): a
		// primeira versao somava ruido espacial (value_noise) ANTES do
		// clamp() pra suavizar a borda Oceano/Mar Gelado, mas
		// clamp(0.0 + noise*0.5, 0, 1) nao e zero pra noise negativo — em
		// QUALQUER tile de oceano aberto (v_animate=1, "1.0-v_animate"=0)
		// isso ainda produzia frozen_amount de ate ~0.25, entao a tintura/
		// roughness/specular de gelo vazava pro mapa INTEIRO seguindo a
		// grade de baixa frequencia do value_noise — lido pelo usuario como
		// um efeito "xadrez/Minecraft" em blocos sobre o oceano normal.
		// frozen_amount agora vem SO de overlay.a (v_animate), que e 0.0/1.0
		// exato no interior de cada bioma e so varia nos poucos texels perto
		// da fronteira real (ja suavizado pelo filter_linear da textura) —
		// zero chance de tingir agua aberta longe de qualquer Mar Gelado.
		//
		// "Linhas topograficas" reportadas pelo usuario (2a rodada): o
		// filter_linear da textura interpola de forma PIECEWISE-LINEAR —
		// reta dentro de cada texel, mas a INCLINACAO muda abruptamente nos
		// pontos onde a rampa "encosta" no 0.0/1.0 plano de cada lado
		// (derivada descontinua, um "vinco" em vez de uma curva lisa). O
		// olho humano enxerga esses vincos como arestas (efeito Mach band) —
		// como o valor cru vem de uma textura de baixa resolucao
		// (WATER_OVERLAY_RESOLUTION), esses vincos se repetem a cada texel
		// da faixa de transicao e leem como varias linhas paralelas
		// (contorno topografico). smoothstep() tem derivada ZERO nos dois
		// extremos (0 e 1) — encaixando a curva sem vinco nas regioes planas
		// dos dois lados, eliminando a descontinuidade que o olho detecta,
		// sem precisar de mais resolucao de textura.
		float frozen_amount = clamp(1.0 - v_animate, 0.0, 1.0);
		frozen_amount = smoothstep(0.0, 1.0, frozen_amount);

		water_color = mix(water_color, frozen_tint.rgb, frozen_amount * 0.65);
		float base_alpha = mix(shallow_color.a, mid_color.a, shallow_to_mid);
		base_alpha = mix(base_alpha, deep_color.a, mid_to_deep);
		// Gelo TRANSLUCIDO de verdade (pedido do usuario) — antes so a COR
		// misturava, o alfa sempre seguia o degrade raso/fundo normal da
		// agua aberta. frozen_tint.a (0.75, ver uniform) deixa o Mar Gelado
		// um pouco mais opaco que a agua rasa mas ainda deixando o fundo
		// transparecer, em vez de virar uma capa 100% solida.
		base_alpha = mix(base_alpha, frozen_tint.a, frozen_amount);

		// Perto de Mar de Lava (pedido do usuario: "a saia vertical deve
		// usar tom de rocha escuro/basalto [...] com uma transicao suave pro
		// calor do magma") — reusa lava_crust_color (MESMA cor de basalto do
		// ramo de lava acima, uma unica fonte de verdade pra "rocha
		// vulcanica escura" no arquivo inteiro) por cima da agua/gelo, e
		// deixa mais denso/opaco (agua rasa cristalina nao faz sentido colada
		// em magma). Aplicado DEPOIS do frozen_tint de proposito — os dois
		// biomas sao mutuamente exclusivos por temperatura na pratica, mas se
		// algum dia colidirem, "perto de lava" deve vencer.
		water_color = mix(water_color, lava_crust_color.rgb, lava_proximity * 0.85);
		base_alpha = mix(base_alpha, 0.95, lava_proximity);

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
		// coast_foam_* (pedido do usuario: "linha fina de espuma branca e
		// dinamica onde a agua intersecta com as paredes/praias da terra").
		float coast_foam_falloff = 1.0 - smoothstep(0.0, foam_distance, depth_diff);
		float coast_foam_wave = sin(depth_diff * foam_frequency - t * foam_speed) * 0.5 + 0.5;
		float coast_foam_noise = value_noise(world_pos.xz * foam_noise_scale + vec2(t * foam_speed * 0.08, -t * foam_speed * 0.05));
		float coast_foam_mask = coast_foam_falloff * coast_foam_wave * smoothstep(0.1, 0.9, coast_foam_noise);
		// Espuma agora ativa no Mar Gelado tambem (pedido do usuario: "mesma
		// agua do resto do mapa"), sem gating por v_animate — antes ficava
		// sempre desligada ali, mais um motivo pro Mar Gelado ler como uma
		// chapa parada em vez de agua de verdade. (1.0 - lava_proximity)
		// apaga a espuma turquesa perto de Mar de Lava (pedido do usuario,
		// regressao: "remova a espuma marinha em celulas de lava") — praia
		// nao faz sentido tematico bem do lado de magma.
		coast_foam_mask = clamp(coast_foam_mask * foam_intensity, 0.0, 1.0) * (1.0 - lava_proximity);

		// Pico branco cintilante (pedido do usuario, 4a rodada): coast_foam_mask
		// ja mistura foam_color proporcional ao pulso, mas fica "lavado"
		// pelo coast_foam_noise (manchas organicas) — o resultado nunca chega
		// perto do branco puro de foam_color mesmo no auge do seno.
		// coast_foam_crest usa SO coast_foam_wave (sem o noise) elevado a uma
		// potencia alta pra concentrar um "flash" nitido bem no topo da onda
		// (coast_foam_wave -> 1), somado por CIMA do mix normal em vez de
		// substituir — e isso que faz o contorno da praia cintilar em branco
		// sobre o turquesa raso a cada pulso, em vez de so um turquesa mais
		// claro.
		float coast_foam_crest = pow(coast_foam_wave, 5.0) * coast_foam_falloff * (1.0 - lava_proximity);
		vec3 water_final_color = mix(water_color, foam_color.rgb, coast_foam_mask) + foam_color.rgb * coast_foam_crest * 0.6;
		water_final_color = clamp(water_final_color, 0.0, 1.0);
		float water_alpha = clamp(mix(base_alpha, foam_color.a, coast_foam_mask), 0.0, 1.0);

		float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
		water_alpha = clamp(water_alpha + fresnel * fresnel_alpha_boost, 0.0, 1.0);

		// MESMO material da agua aberta pro Mar Gelado (pedido do usuario:
		// "faça a parte do mar gelado ser a mesma água do restante do
		// mapa... a água normal parece realmente água e o mar gelado
		// parece plástico") — uma tentativa anterior deixava o Mar Gelado
		// fosco (roughness alto/specular baixo, sem reflexo), o que
		// eliminava o brilho especular que da a leitura de "liquido" a
		// qualquer superficie; combinado com o tempo congelado (fix acima),
		// isso e o que lia como plastico/pintura solida. Agora
		// ROUGHNESS/SPECULAR sao os MESMOS dos dois lados — a UNICA
		// diferenca entre os biomas fica sendo a cor (frozen_amount acima).
		ALBEDO = water_final_color * overlay.rgb;
		ALPHA = water_alpha;
		ROUGHNESS = water_roughness;
		SPECULAR = water_specular;
		METALLIC = 0.0;
		// "Leve brilho magmatico" na agua/rocha perto de Mar de Lava (pedido
		// do usuario) — bem mais fraco que a EMISSION de verdade do ramo de
		// lava acima (sem TIME/pulso: e so um resplendor ambiente refletido,
		// nao a fonte de calor em si).
		EMISSION = lava_fissure_color.rgb * lava_proximity * 0.3;
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
