# Muralhas élficas

Três modelos para os níveis existentes de fortificação, com a pedra clara, madeira, telhados esmeralda e folhas douradas das construções élficas.

| Nível | Visual | Altura por raio de tile 1 |
| --- | --- | --- |
| Muralhas I | Pedra simples, acabamento claro, postes de madeira com pequenas coberturas verdes e portão em degraus | 0,237 |
| Muralhas II | Ameias estreitas em degraus, apoios de madeira em forma de ramos, capitéis esmeralda e brotos dourados | 0,333 |
| Fortaleza | Pedra trabalhada, frisos verdes, folhas douradas, torres curtas com quatro camadas de telhado e ornamento no portão | 0,394 |

![Comparação dos três níveis](previews/elf_walls/walls_three_quarter.png)

![Muralhas ao redor da cidade élfica](previews/elf_walls/cities_three_quarter.png)

O contorno segue o hexágono pointy-top do mapa. A faixa principal mantém o raio 0,94; todos os detalhes ficam dentro do hexágono de raio 0,985. O centro permanece vazio para a fundação da cidade, de raio 0,84. A escala acompanha `City.tile_radius`, incluindo tiles maiores.

O material e os PNGs de albedo/emissão foram reutilizados da cidade élfica existente. Os UVs usam regiões já pintadas do atlas de 1024 pixels, sem alterar os pixels aprovados. As placas do portão recebem a cor do dono pelo mecanismo já usado nas construções.

As faces cobertas por outras peças e os trechos coplanares duplicados foram eliminados antes da exportação, preservando os UVs. A auditoria inclui normais iguais e opostas e confirma zero sobreposições nos três modelos. A compressão de vértices está desativada na importação para preservar as junções.

`BuildingArtCatalog.FORTIFICATION_ART` seleciona o modelo élfico pelo nível local de fortificação. As pesquisas de Urbanização, requisitos de Cidade II–IV, custos e demais regras permanecem em `V2FortificationData`. A cidade usa seu centro élfico já disponível em todos os níveis desta revisão.

Os arquivos editáveis e de jogo ficam em `assets/generated/elves/buildings/elf_walls_level_{1,2,3}_hex_v1/`, com relatórios e prévias próprias. A modelagem usa `tools/art_pipeline/build_elf_walls_mcp.py` no Blender aberto via MCP; a revisão usa `scenes/art_review/ElfWallsReview.tscn`.

Validações: [geometria, texturas e faces](elf_walls_blender_validation.json), [Godot e encaixe na cidade](elf_walls_godot_validation.json), [testes do jogo](elf_walls_regression_validation.json). As fontes das construções élficas e as três muralhas humanas foram preservadas.
