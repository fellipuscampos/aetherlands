# Devorador de Mana — Blocky V2

Modelado no Blender aberto por MCP. Referências visuais: o devorador anterior,
o golem de pedra V2 e o troll blocky V3 do próprio jogo.

55 cuboides sem bevel ou suavização, 660 triângulos, 18 ossos com pesos rígidos,
uma malha e um material. Atlas albedo/emissão 512 × 512 com filtro nearest.
Não há esfera escondida nem superfície fechando o vazio central.

Massas assimétricas flutuam em torno do vazio. Pequenos cubos violetas convergem
para o centro; cubos ciano/brancos emergem em outras direções. As dobras têm
movimentos diferentes, conservando os blocos rígidos.

| Animação | Duração | Comportamento |
|---|---:|---|
| ManaDevourer_Idle | 4 s | Flutuação discreta, absorção e emissão contínuas; loop |
| ManaDevourer_Walk | 2 s | Deslocamento no lugar com fluxo mais rápido; loop |
| ManaDevourer_Attack | 1,5 s | Contração, absorção, expansão e recuperação; execução única |

Origem no chão, frente +Z no Godot, escala nativa sem movimento da raiz.
As 183 poses foram verificadas no Blender; folga mínima de 0,1478 m do chão.
O post-import mantém os loops de Idle e Walk. MonsterDatabase aponta para V2;
os parâmetros, habilidades e o asset V1 permanecem preservados.

Revisão: `art_source/mana_devourer_blocky_v2_review/index.html`.
Godot: `scenes/art_review/ManaDevourerBlockyReview.tscn`, F6.
Teclas 1/2/3: animações; setas: girar; espaço: pausar.

Fonte editável: `.blend` isolado contendo somente esta cena, com texturas
empacotadas. GLB contém skin, três animações e ambas as texturas incorporadas.
Relatórios: `mana_devourer_blocky_v2_report.json` e `godot_validation.json`.

Pipeline reproduzível: build → finish → render via
`tools/art_pipeline/blender_mcp_client.py`; validação/importação por
`tools/art_pipeline/validate_mana_devourer_blocky_v2.py`; previews por
`tools/art_pipeline/encode_mana_devourer_blocky_v2.py`.
