# Muralhas humanas

Três modelos de fortificação para os níveis existentes de `V2FortificationData`:

| Nível | Pesquisa | Visual | Altura por raio de tile 1 |
| --- | --- | --- | --- |
| Muralhas I | Urbanização N1 | Pedra simples, acabamento superior, seis postes quadrados e portão de madeira | 0,259 |
| Muralhas II | Urbanização N2 | Ameias, torres curtas com parapeito, seteiras e cobertura azul no portão | 0,346 |
| Fortaleza | Urbanização N3 | Pedra trabalhada, reforços, torres baixas com telhados azuis em degraus e detalhes dourados | 0,394 |

![Comparação das muralhas](previews/human_walls/walls_three_quarter.png)

![Muralhas com os centros de cidade](previews/human_walls/cities_three_quarter.png)

As muralhas seguem o hexágono pointy-top de `HexMetrics.corner`. A faixa principal acompanha o raio 0,94 da muralha anterior; todos os detalhes ficam dentro de um hexágono de raio 0,985. O centro permanece vazio, sem placa de chão. A fundação de raio 0,84 dos centros humanos continua separada da muralha. A altura e o contorno escalam juntos com `City.tile_radius`.

O material e os pixels de albedo/emissão são os mesmos da Cidade IV humana. Os novos UVs usam regiões existentes do atlas de pedra, madeira, metal e telhas; a exportação confere os hashes dos PNGs embutidos. Apenas a placa neutra do portão recebe a cor do dono.

`BuildingArtCatalog.FORTIFICATION_ART` seleciona o modelo por raça e nível. `City._add_walls` usa o modelo humano e conserva a versão procedural para raças ainda sem esses assets. Os modelos são separados do centro e aparecem pelos caminhos já existentes de conclusão, reconstrução, captura e carregamento. Requisitos, custos, escudo, defesa, ataque e upkeep continuam em `V2FortificationData`.

Os `.blend` editáveis e `.glb` ficam em `assets/generated/humans/buildings/human_walls_level_{1,2,3}_hex_v1/`. Cada pasta contém seu relatório e prévias próprias.

Modelagem: `tools/art_pipeline/build_human_walls_mcp.py`, executado no Blender aberto por `blender_mcp_client.py`. Revisão com cidades reais: `scenes/art_review/HumanWallsReview.tscn`.

Verificações: [Blender e exportação](human_walls_blender_validation.json), [Godot e dimensões reais](human_walls_godot_validation.json), [testes de regressão](human_walls_regression_validation.json). As fontes anteriores das quatro cidades humanas foram preservadas.

Correção das junções: as faces cobertas por outras peças e os trechos coplanares duplicados foram removidos, com interpolação dos UVs originais. As peças editáveis representam as seções da superfície visível; interfaces internas não têm tampas duplicadas. A [verificação de faces](human_walls_face_cleanup_validation.json) confirma zero sobreposições coplanares nos três níveis, sem alterar os limites da silhueta ou os pixels do atlas. A compressão de vértices desses três modelos está desativada na importação para preservar as junções calculadas.
