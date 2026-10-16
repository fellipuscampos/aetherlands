# Fortaleza - humana

Muralha baixa para o nível 3 de fortificação, criada no Blender via MCP e integrada em BuildingArtCatalog.FORTIFICATION_ART.

Contorno hexagonal pointy-top; faixa principal de raio 0,94, limite externo 0,985 e altura 0.394 para tile de raio 1. A escala acompanha City.tile_radius; o centro permanece livre para a fundação humana de raio 0,84.

Material e pixels do atlas da Cidade IV humana preservados. Filtro nearest e faces planas. 4002 triângulos em 2 malha(s) no jogo; as 258 peças continuam editáveis no .blend.

As faces internas cobertas e os trechos coplanares sobrepostos foram eliminados, preservando os UVs originais. A auditoria confirma zero sobreposições nos dois sentidos das normais. A compressão de vértices está desativada na importação para preservar as junções.

![Modelo](previews/three_quarter.png)

![Com a cidade](previews/with_city.png)

Fonte: tools/art_pipeline/build_human_walls_mcp.py. Correção: tools/art_pipeline/repair_human_wall_faces_mcp.py. Documentação e verificações em docs/human_walls.md.
