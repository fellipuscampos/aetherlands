shader_type spatial;
// Malha: um leque de triangulos (SurfaceTool) por tile do territorio da
// cidade (City.owned_tiles), um "tampo" plano cobrindo o hexagono inteiro
// — ver HexGrid._build_city_tint_mesh. Pedido do usuario, apos abandonar
// o antigo sistema de linha de contorno (repetidos problemas de
// renderizacao/juncao de geometria — ver comentario de TERRITORY_TINT_
// ALPHA em HexGrid.gd): "faça apenas com que o territorio de uma nacao
// tenha uma cor especifica... colorir o topo de cada celula com essa
// cor". Este tingimento e hoje o UNICO sinal visual de posse territorial
// — camada fina e translucida, deitada por cima do terreno de verdade,
// nao um material do proprio terreno.
//
// COLOR.rgb = cor primaria da civ JA fog-ajustada por vertice pela CPU
// (sepia se o tile so EXPLORED, ver HexGrid._sepia_prop_color).
// COLOR.a = opacidade do tingimento (HexGrid.TERRITORY_TINT_ALPHA pra
// VISIBLE, uma fracao disso pra EXPLORED).
render_mode blend_mix, cull_disabled, depth_draw_always, unshaded;

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
