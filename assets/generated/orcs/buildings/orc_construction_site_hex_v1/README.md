# Canteiro de construção orc

Modelo genérico para edifícios orcs em produção, com três construtores talhando pedra, serrando madeira e rebitando ferro. Os materiais incluem seis blocos soltos, três toras com casca, dez peças de telhado vermelho-terra, tiras de ferro e adornos ósseos. A paleta vem dos edifícios orcs; rostos pintados, orelhas, presas e sobrancelhas são os do colonizador orc original.

- `orc_construction_site_hex_v1.blend`: fonte editável com 363 cuboides, rig e animação.
- `orc_construction_site_hex_v1.glb`: 4356 triângulos, 2 malhas, 1 material, atlas 512×512, 25 ossos.
- `orc_construction_site_hex_v1.tscn`: inicia e repete `construction` automaticamente.
- `previews/`: vistas gerais, closes e referência de alinhamento ao tile.

Loop de 6 segundos a 30 fps. Pés e raiz fixos, braços curtos e mangas articuladas. Martelos atingem o formão e o rebite com a cabeça; os cabos e mãos ficam fora dos alvos. Não há construção específica ou chão no export. Toda a geometria é blocky, sem bevels ou suavização.

Integrado em `HexGrid` para cidades `orc`, com escala `hex_size` aplicada uma vez. O canteiro desaparece ao concluir ou cancelar a produção. Revisão nativa: `scenes/art_review/OrcConstructionReview.tscn`. Página, vídeo e GIF: `art_source/orc_construction_review/`.
