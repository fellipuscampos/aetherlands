# Muralhas II - orcs

Muralha baixa do nível 2 de fortificação, criada no Blender via MCP e integrada em BuildingArtCatalog.FORTIFICATION_ART.

Contorno hexagonal de raio principal 0,94, limite externo 0,985 e altura 0.337 para tile de raio 1. Escala por City.tile_radius, com centro livre para a fundação de raio 0,84.

Material e atlas aprovados da cidade orc: madeira, basalto, ferro, cobertura vermelha e marfim. 4514 triângulos em 2 malha(s) no jogo; 339 peças editáveis na fonte.

Limpeza antes da exportação: zero sobreposições coplanares, incluindo normais opostas. Pixels e UVs preservados, compressão de vértices desativada na importação.

![Modelo](previews/three_quarter.png)

![Com a cidade](previews/with_city.png)

Fonte: tools/art_pipeline/build_orc_walls_mcp.py e orc_walls_geometry.py.inc. Revisão: scenes/art_review/OrcWallsReview.tscn. Documentação e verificações: docs/orc_walls.md.
