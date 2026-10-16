# Muralhas II - anões

Muralha baixa do nível 2 de fortificação, criada no Blender via MCP e integrada em BuildingArtCatalog.FORTIFICATION_ART.

Contorno hexagonal: faixa principal de raio 0,94, limite externo 0,985 e altura 0.335 para tile de raio 1. A escala acompanha City.tile_radius e o centro fica livre para a fundação de raio 0,84.

Material e atlas aprovados da cidade anã: granito, pedra talhada, ardósia e cobre. 4298 triângulos em 2 malha(s) no jogo; 280 peças editáveis na fonte.

Limpeza antes da exportação: zero sobreposições coplanares na auditoria, incluindo normais opostas. UVs e pixels preservados. Compressão de vértices desativada na importação.

![Modelo](previews/three_quarter.png)

![Com a cidade](previews/with_city.png)

Fonte: tools/art_pipeline/build_dwarf_walls_mcp.py e dwarf_walls_geometry.py.inc. Revisão: scenes/art_review/DwarfWallsReview.tscn. Documentação: docs/dwarf_walls.md.
