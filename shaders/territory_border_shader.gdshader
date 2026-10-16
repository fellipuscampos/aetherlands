shader_type spatial;
// Contorno de território estilo Civilization (HexGrid._build_city_border_mesh, geometria em TerritoryBorder.gd).
// Substitui o antigo tingimento que pintava o hexágono inteiro (escondia o terreno, "fluorescente" à noite): só uma
// faixa junto às arestas do território — linha nítida na cor da civ e um brilho suave que se apaga para dentro.
//
// UV.x = distância normalizada até a aresta (0 = limite do território, 1 = lado de dentro da faixa).
// UV.y = tipo: 0 = borda cheia (outro dono/sem dono), 1 = linha interna fina entre cidades da mesma civ.
// COLOR.rgb = cor da civ (sépia se o tile só foi EXPLORADO); COLOR.a = 1 visível, menos se explorado.
//
// SOMBREADO (diffuse_lambert, normal sempre para cima): à noite e com chuva/neve escurece junto com a cena, em vez de
// brilhar por cima de tudo. Uma emissão pequena só na linha mantém o limite legível no escuro.
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled;

uniform float line_fraction : hint_range(0.05, 0.9) = 0.42;  // parte da faixa cheia que é linha sólida (~0,11 hex)
uniform float line_alpha : hint_range(0.0, 1.0) = 0.95;
uniform float glow_alpha : hint_range(0.0, 1.0) = 0.42;      // brilho logo depois da linha, sumindo até o fim da faixa
uniform float internal_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.3;
// Fio escuro bem na aresta: contraste da linha sobre neve/areia clara.
uniform float rim_fraction : hint_range(0.0, 0.3) = 0.05;
uniform float rim_darken : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	float across = clamp(UV.x, 0.0, 1.0);
	vec3 color = COLOR.rgb;
	float alpha;
	float line = 0.0;
	if (UV.y > 0.5) {
		alpha = internal_alpha * (1.0 - smoothstep(0.6, 1.0, across));
	} else {
		line = 1.0 - smoothstep(line_fraction - 0.04, line_fraction + 0.03, across);
		float glow = 1.0 - smoothstep(line_fraction, 1.0, across);
		alpha = max(line * line_alpha, glow * glow * glow_alpha);
		color *= mix(1.0 - rim_darken, 1.0, smoothstep(0.0, rim_fraction, across));
	}
	ALBEDO = color;
	EMISSION = color * emission_strength * line;
	ALPHA = alpha * COLOR.a;
	// Normal do chão (para cima) qualquer que seja a ordem dos vértices do triângulo.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
