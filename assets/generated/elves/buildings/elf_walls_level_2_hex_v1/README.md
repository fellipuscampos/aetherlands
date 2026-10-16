# Muralhas II - elfos

Modelo baixo do nível 2 de fortificação, criado no Blender via MCP e integrado em BuildingArtCatalog.FORTIFICATION_ART.

Contorno hexagonal de raio principal 0,94; limite externo 0,985; altura 0.333 para tile de raio 1. A escala acompanha City.tile_radius e preserva o espaço central para a fundação de raio 0,84.

Material e atlas originais da cidade élfica: pedra clara, madeira, telhas esmeralda e ouro. 3924 triângulos em 2 malha(s) no jogo, com 258 peças editáveis na fonte.

Limpeza de superfícies antes da exportação: zero faces coplanares sobrepostas, incluindo normais opostas. UVs e pixels preservados; compressão de vértices desativada na importação.

![Modelo](previews/three_quarter.png)

![Com a cidade](previews/with_city.png)

Fonte: tools/art_pipeline/build_elf_walls_mcp.py. Revisão: scenes/art_review/ElfWallsReview.tscn. Documentação e validações: docs/elf_walls.md.
