# Muralhas orcs

Três níveis de fortificação com os materiais da cidade orc: madeira pesada, basalto, ferro escuro, coberturas vermelhas e presas de marfim.

| Nível | Visual | Altura por raio de tile 1 |
| --- | --- | --- |
| Muralhas I | Paliçada fechada de madeira sobre basalto, travessas e postes com cintas de ferro | 0,238 |
| Muralhas II | Base de pedra, madeira, reforços e rebites de ferro, parapeito irregular, presas nas torres e cobertura vermelha no portão | 0,337 |
| Fortaleza | Basalto robusto, apoios de madeira e ferro, torres curtas com telhados de duas águas em degraus, presas e símbolo do clã no portão | 0,390 |

![Comparação dos três níveis](previews/orc_walls/walls_three_quarter.png)

![Muralhas ao redor da cidade orc](previews/orc_walls/cities_three_quarter.png)

O contorno acompanha o mesmo hexágono pointy-top usado pelo mapa. A faixa principal segue o raio 0,94; todos os detalhes ficam dentro do hexágono de raio 0,985. O centro permanece vazio para a fundação de raio 0,84 da cidade. A escala acompanha `City.tile_radius`.

Material e pixels dos PNGs de albedo/emissão foram reutilizados da cidade orc existente. A exportação verifica os hashes dos PNGs embutidos. Apenas a pequena placa do clã recebe a cor do dono; madeira, basalto, ferro, coberturas e presas preservam sua pintura.

Antes da exportação, a limpeza remove faces internas cobertas e trechos coplanares duplicados, interpolando os UVs originais. A auditoria confirma zero sobreposições de faces com normais iguais ou opostas. A compressão de vértices está desativada na importação para preservar as junções.

`BuildingArtCatalog.FORTIFICATION_ART` registra os três níveis orcs. Requisitos, pesquisas, custos, escudo, defesa, ataque e upkeep permanecem em `V2FortificationData`. Capturar uma cidade entre humanos, elfos e orcs troca a arquitetura e conserva o nível de fortificação.

Arquivos: `assets/generated/orcs/buildings/orc_walls_level_{1,2,3}_hex_v1/`, com `.blend`, `.glb`, relatório e prévias. `build_orc_walls_mcp.py` usa a geometria própria em `orc_walls_geometry.py.inc` e o fluxo compartilhado de criação/exportação. A revisão com cidades reais está em `scenes/art_review/OrcWallsReview.tscn`.

Validações: [Blender, faces e atlas](orc_walls_blender_validation.json), [Godot e encaixe](orc_walls_godot_validation.json), [testes do jogo](orc_walls_regression_validation.json). As fontes orcs anteriores e as muralhas humanas e élficas foram preservadas.
