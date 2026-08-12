shader_type spatial;
// Malha: um ribbon (SurfaceTool) por aresta de rio, ver
// HexGrid._add_river_segment. UV.y = 0..1 ao longo do COMPRIMENTO de cada
// segmento (usado pro scroll de fluxo); UV.x = 0..1 na LARGURA (0 e 1 sao
// as duas margens, 0.5 o meio do canal — usado pra mascara de espuma de
// margem). COLOR.rgb = fog-of-war (brilho, ja embutido por vertice em
// HexGrid._rebuild_river_mesh, mesma escala 0.02/0.45/1.0 de sempre).
// COLOR.a = fator de desvanecimento da foz (pedido do usuario, "transicao
// suave no oceano") — 1.0 no rio normal, cai gradualmente ate 0.0 no fim
// do ultimo trecho de um rio que desagua em agua de verdade (ver
// HexGrid._add_river_path, is_river_mouth/RIVER_MOUTH_*).
// depth_draw_always (pedido do usuario, correcao do bug de rio invisivel):
// forca o rio a escrever no depth buffer mesmo sendo transparente — sem
// isso, dependendo da ordem de desenho de objetos transparentes, o rio
// podia ser descartado/coberto por outro elemento transparente proximo
// (o plano de agua do oceano, por exemplo) em vez de aparecer por cima do
// terreno. A causa RAIZ do rio invisivel era a malha ficar embaixo da
// superficie do terreno (corrigido em HexGrid._edge_midpoint/RIVER_ABOVE_
// OFFSET); isso aqui e reforco extra pedido explicitamente, nao a causa
// principal.
//
// cull_disabled (pedido do usuario, suspeita de winding order invertido):
// conferi a mao o produto vetorial dos dois triangulos de cada quad em
// HexGrid._add_river_path e a normal implicita ja da pra CIMA (+Y) com a
// ordem atual dos vertices — entao cull_back sozinho ja deveria mostrar a
// face de cima pra uma camera olhando de cima, e o winding NAO parecia ser
// o bug. Mesmo assim, cull_disabled custa muito pouco numa fita fina como
// essa e elimina de vez essa hipotese: com as duas faces sempre desenhadas,
// a orientacao do triangulo deixa de importar pra visibilidade.
render_mode blend_mix, cull_disabled, depth_draw_always, diffuse_burley, specular_schlick_ggx;

// Paleta herdada do water_shader (pedido do usuario: "mantenha a
// identidade visual") — um tom so (nao raso/fundo gradiente, o rio e
// estreito demais pra um degrade de profundidade fazer sentido), entre o
// shallow_color e deep_color de la.
uniform vec4 river_color : source_color = vec4(0.18, 0.58, 0.68, 0.78);

// Fluxo (pedido do usuario: "UV scrolling/flow ao longo do caminho do
// rio, TIME * flow_speed"). flow_scale controla a frequencia do ruido ao
// longo de UV.y — maior = "correnteza" mais picotada/agitada.
uniform float flow_speed : hint_range(0.0, 5.0) = 1.4;
uniform float flow_scale : hint_range(0.5, 12.0) = 4.0;
uniform float flow_normal_strength : hint_range(0.0, 3.0) = 0.9;

// Espuma de margem (pedido do usuario: "leve espuma/transicao suave nas
// bordas... integrar organicamente com a grama/areia") — mascara por
// distancia ao CENTRO do canal (UV.x), nao por profundidade de cena (o
// rio nao tem DEPTH_TEXTURE util aqui, e so uma faixa estreita) — mesma
// paleta/tecnica de ruido do foam do water_shader, adaptada pra UV em vez
// de world_pos (UV.y ja e "distancia percorrida ao longo do rio", a
// coordenada certa pra animar a espuma fluindo, diferente do water_shader
// onde nao existe um "ao longo" global).
uniform vec4 foam_color : source_color = vec4(0.9, 0.98, 1.0, 1.0);
uniform float foam_margin : hint_range(0.0, 0.5) = 0.22; // fracao de UV.x (a partir da margem) onde a espuma pode aparecer
uniform float foam_speed : hint_range(0.0, 5.0) = 1.6;
uniform float foam_noise_scale : hint_range(1.0, 20.0) = 7.0;
uniform float foam_intensity : hint_range(0.0, 2.0) = 1.3;

// Fusao com a calha (pedido do usuario: "bordas laterais... fade
// transparente... a agua se fundir suavemente com a terra da calha") —
// separado da espuma acima: a espuma ainda pode aparecer perto da margem,
// mas a opacidade de TUDO (agua+espuma) cai pra 0 bem na beirada da fita,
// suavizando o contorno reto do quad contra o chao esculpido do
// terrain.gdshader em vez de terminar numa linha dura.
uniform float margin_fade_start : hint_range(0.0, 1.0) = 0.75; // fracao de UV.x (distancia ao centro) onde o fade comeca

// Mesmos valores tunados do water_shader nesta sessao (fosco o bastante
// pra nao "estourar" sob o sol, mas ainda com brilho sutil tremulando).
uniform float river_roughness : hint_range(0.0, 1.0) = 0.2;
uniform float river_specular : hint_range(0.0, 1.0) = 0.5;
uniform float fresnel_power : hint_range(0.5, 8.0) = 4.0;
uniform float fresnel_alpha_boost : hint_range(0.0, 1.0) = 0.3;

// DEBUG (usado pra confirmar visibilidade — era o bug de AABB/frustum
// culling, ja corrigido em HexGrid._rebuild_river_mesh custom_aabb).
// DESLIGADO agora que a causa raiz foi confirmada — deixado no shader (nao
// removido) caso precise religar rapido num problema futuro parecido.
uniform bool debug_bright_color = false;
uniform vec3 debug_color : source_color = vec3(0.0, 0.8, 1.0);

varying vec3 world_pos;

// hash/value_noise identicos aos de water_shader/terrain.gdshader (cada
// .gdshader e um arquivo independente no Godot, sem #include — copia
// deliberada, nao duplicação por descuido). mod(p,1000.0) e o mesmo fix de
// precisao do sin() em argumentos grandes ja aplicado la.
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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Normal de fluxo: desloca o campo de ruido ao longo de UV.y com o
	// tempo (pedido do usuario: TIME * flow_speed) — da a impressao da
	// correnteza escoando na direcao do rio. Duas amostras (n1/n2)
	// deslocadas em UV.x e frequencia pra nao ficar uma unica onda lisa
	// demais, mesmo espirito do broad+detail do water_shader.
	float flow_t = UV.y * flow_scale - TIME * flow_speed;
	float n1 = value_noise(vec2(UV.x * flow_scale * 2.0, flow_t));
	float n2 = value_noise(vec2(UV.x * flow_scale * 2.0 + 3.7, flow_t * 1.4 + 1.3));
	vec3 flow_normal = normalize(vec3(
		(n1 - 0.5) * flow_normal_strength,
		1.0,
		(n2 - 0.5) * flow_normal_strength
	));
	NORMAL = normalize((VIEW_MATRIX * vec4(flow_normal, 0.0)).xyz);

	// Espuma de margem: mais forte perto de UV.x=0/1 (as duas bordas do
	// ribbon), quase zero no centro do canal — falloff + ruido animado
	// (scroll com foam_speed) pra nao virar uma linha reta continua.
	float edge_dist = abs(UV.x - 0.5) * 2.0; // 0 no centro, 1 na margem
	float foam_falloff = smoothstep(1.0 - foam_margin, 1.0, edge_dist);
	float foam_wave = value_noise(vec2(UV.y * foam_noise_scale - TIME * foam_speed, UV.x * 5.0));
	float foam_mask = clamp(foam_falloff * foam_wave * foam_intensity, 0.0, 1.0);

	vec3 final_color = mix(river_color.rgb, foam_color.rgb, foam_mask);
	float alpha = mix(river_color.a, foam_color.a, foam_mask);

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	alpha = clamp(alpha + fresnel * fresnel_alpha_boost, 0.0, 1.0);
	// Desvanecimento da foz (pedido do usuario) — COLOR.a cai pra 0 ao
	// longo do ultimo trecho de um rio que desagua no oceano (ver
	// HexGrid._add_river_path), entao a espuma/cor tambem somem junto com
	// a transparencia em vez de cortar seco na linha da costa.
	alpha *= COLOR.a;
	// Fusao com a calha (pedido do usuario) — reusa o MESMO edge_dist da
	// espuma acima; a agua (e a espuma perto da margem) desvanece pra
	// transparente bem na beirada da fita, se fundindo com a terra
	// esculpida do terrain.gdshader em vez de terminar numa linha reta.
	float margin_fade = 1.0 - smoothstep(margin_fade_start, 1.0, edge_dist);
	alpha *= margin_fade;

	if (debug_bright_color) {
		// Bypassa fog/paleta de proposito — ver comentario do uniform acima.
		ALBEDO = debug_color;
		EMISSION = debug_color * 0.6;
		ALPHA = 1.0;
	} else {
		ALBEDO = final_color * COLOR.rgb; // COLOR.rgb = fog-of-war, ver HexGrid._river_fog_factor
		ALPHA = alpha;
	}
	ROUGHNESS = river_roughness;
	SPECULAR = river_specular;
	METALLIC = 0.0;
}
