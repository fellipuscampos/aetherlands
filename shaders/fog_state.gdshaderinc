// ESTADO DE NÉVOA EXATO POR TILE (HexGrid._fog_state_texture): 1 texel por tile, sem filtro — 0 = nunca visto,
// 0,5 = explorado (memória), 1 = visível agora. É a fonte de tudo que precisa de uma resposta SIM/NÃO por tile:
// a camada de névoa (shaders/fog_layer.gdshader cobre os tiles nunca vistos) e o terreno (shaders/terrain.gdshader
// não desenha o que está embaixo dela). A máscara borrada de baixa resolução (alfa de biome_overlay_texture /
// liquid_type_texture) continua existindo só para o escurecimento SUAVE da área explorada.
//
// O texel de um tile usa o mesmo esquema "odd-r" de HexGrid.generate_map e da máscara de lava
// (HexGrid._fog_state_pixel): col = q + (r - (r & 1)) / 2, deslocado por fog_grid_half.
// Sem textura atribuída o padrão do Godot é branco (1 = visível): material fora do jogo nunca esconde nada.
uniform sampler2D fog_state_texture : filter_nearest, repeat_disable;
uniform vec2 fog_grid_size = vec2(1.0, 1.0);
uniform vec2 fog_grid_half = vec2(0.0, 0.0);
uniform float fog_hex_size = 1.0;

// (q, r) do tile que contém o ponto, com arredondamento em coordenada cubo (mesmo de HexMetrics.world_to_axial).
vec2 fog_world_to_axial(vec2 world_xz) {
	float x = (sqrt(3.0) / 3.0 * world_xz.x - 1.0 / 3.0 * world_xz.y) / fog_hex_size;
	float z = (2.0 / 3.0 * world_xz.y) / fog_hex_size;
	float y = -x - z;
	float rx = round(x);
	float ry = round(y);
	float rz = round(z);
	float x_diff = abs(rx - x);
	float y_diff = abs(ry - y);
	float z_diff = abs(rz - z);
	if (x_diff > y_diff && x_diff > z_diff) {
		rx = -ry - rz;
	} else if (y_diff <= z_diff) {
		rz = -rx - ry;
	}
	return vec2(rx, rz);
}

// UV do texel do tile que contém `world_xz` (vale para qualquer textura de 1 texel por tile na mesma grade).
vec2 fog_tile_uv(vec2 world_xz) {
	vec2 axial = fog_world_to_axial(world_xz);
	int row = int(axial.y);
	int col = int(axial.x) + (row - (row & 1)) / 2;
	return (vec2(float(col), float(row)) + fog_grid_half + 0.5) / fog_grid_size;
}

// Estado do tile que contém `world_xz`: 0 nunca visto, 0,5 explorado, 1 visível.
float fog_state_at(vec2 world_xz) {
	return textureLod(fog_state_texture, fog_tile_uv(world_xz), 0.0).r;
}

// O tile está sob a camada de névoa (nunca visto)?
bool fog_tile_is_unseen(vec2 world_xz) {
	return fog_state_at(world_xz) < 0.25;
}
