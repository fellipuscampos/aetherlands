# Canteiro de construção élfico

`assets/generated/elves/buildings/elf_construction_site_hex_v1/elf_construction_site_hex_v1.tscn` é a animação genérica usada durante a construção dos edifícios élficos. O canteiro contém seis blocos soltos da paleta élfica, três peças de madeira bruta com casca e pontas cortadas, e dez telhas verdes. Três trabalhadores talham encaixes com malho e formão, serram uma tábua e aplainam uma viga. Não há parede construída, base hexagonal ou arquitetura de um prédio específico.

Os blocos, madeira, telhas verdes e folhas douradas seguem a paleta de `elf_city_level_1_hex_v1_model.py`. A casca dos troncos é feita com cuboides irregulares, preservando o estilo voxel. Os rostos pintados, cabelos e orelhas são os de `elf_settler_v1`, com escala uniforme de 0,24. Ombros articulados e antebraços curtos mantêm as correções aprovadas do canteiro humano.

O clip `construction` dura 6 segundos a 30 fps, com loop fechado e pés fixos. As 181 poses foram verificadas no Blender e na importação Godot. O contato do formão, serra e plaina é conferido sobre as peças de madeira. As 347 peças são cuboides fechados; o GLB contém 4164 triângulos, duas malhas, um material com atlas 512×512 e 25 ossos.

`HexGrid` seleciona a cena pela raça da cidade dona, posiciona o canteiro diretamente sobre o tile e aplica `hex_size` uma vez. Raiz e barra de progresso ficam fixas. A conclusão e o cancelamento removem o visual. As quatro raças usam seus próprios canteiros.

Para revisar, abra `scenes/art_review/ElfConstructionReview.tscn` com F6 ou `art_source/elf_construction_review/index.html`. Vídeo, GIF e close do malho ficam nessa pasta. O contorno azul de `previews/hex_alignment.png` é apenas uma referência do estúdio.

Validações: `elf_construction_site_hex_v1_report.json` na pasta do modelo, `docs/elf_construction_godot_validation.json`, `docs/elf_construction_regression_validation.json` e `art_source/elf_construction_review/contacts_validation.json`.
