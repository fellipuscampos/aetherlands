# Canteiro de construção anão

`assets/generated/dwarves/buildings/dwarf_construction_site_hex_v1/dwarf_construction_site_hex_v1.tscn` é o visual genérico dos edifícios anões em produção. Os trabalhadores talham granito com martelo e formão, limam uma telha e rebitam uma chapa de cobre sobre uma bigorna. O andaime e as bancadas são equipamentos de trabalho, sem parede, porta, janela ou base hexagonal.

As imagens do centro da cidade, oficina e salão dos guardiões foram conferidas antes da modelagem. A paleta de `dwarf_city_level_1_hex_v1_model.py` fornece a pedra `(117,124,123)`, pedra lavrada `(175,172,152)`, cobre `(191,133,71)` e telhado cinza-azulado escuro `(67,82,89)`. O canteiro contém nove blocos soltos, três chapas, seis lingotes, três cantoneiras, três cintas de cobre e dez telhas. Uma bancada de pedra sustenta a bigorna; colares de cobre reforçam o andaime.

Corpos, rostos e detalhes das cabeças vêm de `dwarf_settler_v1`, em escala uniforme de 0,26. Cada anão conserva os 18 blocos da barba e 30 acessórios originais da cabeça, incluindo bigode, sobrancelhas, nariz e boné de oficina. Não foram inventados detalhes faciais. As mangas articuladas formam os ombros; os antebraços medem aproximadamente 0,078–0,083 unidades.

O clip `construction` dura 6 segundos a 30 fps, com 181 poses, raiz e pés fixos e loop fechado. Os trabalhadores do solo ficam em Y=0 no Godot; o trabalhador da bigorna fica no andaime em Y=0,207. As 386 peças são cuboides fechados; o GLB contém 4632 triângulos, duas malhas, um material opaco, atlas 1024×1024 e 25 ossos. A margem mínima dentro do footprint reservado de raio 0,9 é 0,0388, na orientação de `HexMetrics.corner`.

`HexGrid` seleciona a cena de raça `dwarf`, coloca-a diretamente no terreno e aplica `hex_size` uma vez. A barra de progresso fica acima do canteiro; conclusão e cancelamento removem o modelo. Cada uma das quatro raças agora usa seu próprio canteiro.

Revisão: `scenes/art_review/DwarfConstructionReview.tscn` com F6 ou `art_source/dwarf_construction_review/index.html`, com vídeo, GIF, close do martelo e as referências visuais. O contorno de `previews/hex_alignment.png` é apenas uma referência do estúdio.

Validações: relatório do modelo, `docs/dwarf_construction_export_validation.json`, `docs/dwarf_construction_godot_validation.json`, `docs/dwarf_construction_regression_validation.json` e `art_source/dwarf_construction_review/contacts_validation.json`.
