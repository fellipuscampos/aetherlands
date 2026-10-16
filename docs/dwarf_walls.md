# Muralhas anãs

Três níveis de fortificação com o granito, pedra talhada, ardósia e cobre da cidade anã existente.

| Nível | Visual | Altura por raio de tile 1 |
| --- | --- | --- |
| Muralhas I | Pedra simples, acabamento talhado, postes quadrados com tampas de ardósia e portão de madeira com ferragens de cobre | 0,252 |
| Muralhas II | Cintas de cobre, ameias largas, torres curtas com parapeitos quadrados, runas e símbolo de martelo no portão | 0,335 |
| Fortaleza | Granito reforçado, pilares talhados com runas de cobre, coberturas de ardósia e pequenas lanternas nas torres e no portão | 0,386 |

![Comparação dos três níveis](previews/dwarf_walls/walls_three_quarter.png)

![Muralhas ao redor da cidade anã](previews/dwarf_walls/cities_three_quarter.png)

O contorno acompanha o hexágono pointy-top do mapa: faixa principal de raio 0,94 e limite externo de raio 0,985. O centro fica vazio para a fundação de raio 0,84. Altura e contorno acompanham `City.tile_radius`.

O material e os PNGs de albedo/emissão são os mesmos da cidade anã aprovada. As novas faces usam regiões já pintadas do atlas; os hashes dos PNGs embutidos são verificados na exportação. A pequena placa do portão recebe a cor do dono; granito, ardósia, cobre e lanternas preservam sua pintura.

A limpeza antes da exportação elimina faces cobertas por outras peças e áreas coplanares duplicadas, interpolando os UVs originais. A auditoria inclui normais iguais e opostas, com tolerância posicional de 0,0000008 unidade para o arredondamento dos vértices. Os três modelos passam sem sobreposições. A compressão de vértices está desativada na importação para preservar as junções.

`BuildingArtCatalog.FORTIFICATION_ART` agora contém os três níveis das quatro raças. A arte segue o dono atual e o nível local de fortificação. Pesquisas, custos, escudo, defesa, ataque e upkeep continuam em `V2FortificationData`.

Arquivos: `assets/generated/dwarves/buildings/dwarf_walls_level_{1,2,3}_hex_v1/`, incluindo `.blend`, `.glb`, relatório e prévias. Modelagem via MCP com `build_dwarf_walls_mcp.py`, usando a geometria própria em `dwarf_walls_geometry.py.inc` e o fluxo compartilhado de criação/exportação. Revisão com cidades reais em `scenes/art_review/DwarfWallsReview.tscn`.

Validações: [Blender, faces e texturas](dwarf_walls_blender_validation.json), [Godot e encaixe](dwarf_walls_godot_validation.json), [testes do jogo](dwarf_walls_regression_validation.json). As fontes anãs anteriores e as nove muralhas humanas, élficas e orcs foram preservadas.
