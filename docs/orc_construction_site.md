# Canteiro de construção orc

`assets/generated/orcs/buildings/orc_construction_site_hex_v1/orc_construction_site_hex_v1.tscn` é a animação genérica de produção dos edifícios orcs. Três trabalhadores talham um bloco com martelo e formão, serram uma tábua e rebitam uma chapa de ferro. O andaime pesado e as bancadas servem a qualquer construção; não há parede, porta, janela ou base hexagonal.

Os materiais seguem `orc_city_level_1_hex_v1_model.py`: seis blocos de pedra escura e clara, três toras brutas com casca, dez peças vermelho-terra para o telhado de couro, três tiras de ferro e três adornos ósseos ainda soltos. Colares de ferro reforçam os postes. Pregos, ferragens, tarugos e um balde de piche completam os suprimentos.

Os rostos pintados e a anatomia do corpo vêm de `orc_settler_v1`, em escala uniforme de 0,21. Cada cabeça conserva suas seis peças originais de orelha, quatro de presa e duas de sobrancelha. As mangas articuladas formam os ombros; não há quadrados extras fixos. Os antebraços medem aproximadamente 0,082–0,087 unidades, com planos de cotovelo estáveis.

O clip `construction` dura 6 segundos a 30 fps, com 181 poses, loop fechado, raiz e pés fixos. Os dois orcs do solo ficam em Y=0 no Godot; o rebiteiro apoia os pés no andaime em Y=0,207. O GLB contém 363 cuboides fechados, 4356 triângulos, duas malhas, um material opaco com atlas 512×512 e 25 ossos. A margem mínima dentro do footprint reservado de raio 0,9 é 0,0388, na orientação de `HexMetrics.corner`.

`HexGrid` seleciona este modelo para cidades de raça `orc`, posiciona-o no terreno e aplica `hex_size` uma vez. A barra de progresso fica acima do canteiro; conclusão ou cancelamento removem o visual. As quatro raças usam seus respectivos modelos.

Abra `scenes/art_review/OrcConstructionReview.tscn` com F6 ou `art_source/orc_construction_review/index.html`. Vídeo, GIF e close do martelo estão nessa pasta. O contorno de `previews/hex_alignment.png` é somente uma referência do estúdio e não está no modelo exportado.

Validações: relatório na pasta do modelo, `docs/orc_construction_export_validation.json`, `docs/orc_construction_godot_validation.json`, `docs/orc_construction_regression_validation.json` e `art_source/orc_construction_review/contacts_validation.json`.
