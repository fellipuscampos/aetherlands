# Canteiro de construção élfico

Canteiro genérico para qualquer edifício élfico em produção. Os materiais incluem seis blocos soltos, três peças de madeira bruta com casca e pontas cortadas, e dez telhas verdes. Três construtores preparam peças de madeira: malho e formão para encaixes, serra para tábuas e plaina para uma viga. Bancadas e andaime não representam um prédio específico; não há parede construída, porta, janela ou base hexagonal.

Blocos `(137,158,131)` e `(209,215,183)`, madeira `(113,91,55)`, telhas verdes `(48,122,88)` e adornos dourados `(206,181,112)` seguem a paleta dos edifícios élficos. Blocos e telhas repousam em pequenos pallets; madeira bruta, folhas douradas soltas, réguas de acabamento, tarugos e um balde de resina aguardam uso. Os rostos pintados, cabelos claros e seis peças de orelha de cada trabalhador vêm de `elf_settler_v1`.

- `elf_construction_site_hex_v1.blend`: fonte editável, com rig e animação.
- `elf_construction_site_hex_v1.glb`: 4164 triângulos, 2 malhas, 1 material, atlas 512×512 e 25 ossos.
- `elf_construction_site_hex_v1.tscn`: inicia e repete `construction` automaticamente.
- `previews/`: vistas gerais, closes dos trabalhadores e alinhamento ao tile.

Todas as 347 peças são cuboides fechados, sem arredondamento. A madeira bruta tem casca irregular formada por blocos. Os ombros são as próprias mangas articuladas; os antebraços mantêm os comprimentos corrigidos do canteiro humano. O malho bate com a cabeça no formão, com o cabo afastado da madeira. A serra e a plaina mantêm contato com suas peças.

O loop dura 6 segundos, a 30 fps, com pés e raiz fixos. Os trabalhadores do solo ficam em Y=0 no Godot; o terceiro apoia os pés no andaime. O modelo não exporta chão ou tile. A margem mínima dentro do footprint de raio 0,9 é 0,0388, com orientação de `HexMetrics.corner`.

O mapa usa este canteiro quando a cidade pertence a `elf`, aplicando `hex_size` uma vez. O visual desaparece ao concluir ou cancelar a construção. Abra `scenes/art_review/ElfConstructionReview.tscn` com F6 para revisar.

Página, vídeo e GIF: `art_source/elf_construction_review/`. Validações: relatório do modelo, `docs/elf_construction_godot_validation.json` e `art_source/elf_construction_review/contacts_validation.json`. Criado no Blender aberto via MCP, preservando o canteiro humano e as demais cenas.
