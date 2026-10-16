# Devorador de Mana — Núcleo e pedras

Um cubo de mana gira lentamente, mantendo quatro pedras cinzentas em órbita.
As fissuras discretas da pedra recebem a mesma energia do núcleo. O conjunto
representa o fenômeno natural estudado pelos elfos que permitiu aos humanos
desenvolver o método de dar vida à pedra usado nos golens.

Modelado no Blender aberto via MCP. Referência visual: golem de pedra V2 do
próprio jogo; faces planas, cantos quadrados e textura de pedra em pixels.

Cinco formas principais: uma malha de cubo e quatro pedras com um canto
quebrado em degraus. 92 triângulos, sete ossos rígidos, uma malha exportada,
um material e dois atlas incorporados de 256 × 256 com filtro nearest.

| Animação | Duração | Comportamento |
|---|---:|---|
| ManaDevourer_Idle | 16 s | Rotação lenta do núcleo e órbita completa; loop |
| ManaDevourer_Walk | 8 s | Órbita mais rápida durante deslocamento no lugar; loop |
| ManaDevourer_Attack | 1,5 s | Pulso do núcleo, leve contração e expansão da órbita; execução única |

A órbita usa um osso comum de rotação, preservando a distância ao núcleo
durante as transições de animação do Godot. Origem no chão, raiz imóvel,
escala nativa. O piso de estúdio não faz parte do GLB.

Revisão: `art_source/mana_devourer_blocky_v3_review/index.html`.
Godot: `scenes/art_review/ManaDevourerBlockyReview.tscn`, F6.
Teclas 1/2/3: animações; setas: girar; espaço: pausar.

Fonte `.blend` isolada, contendo somente a cena nova e texturas empacotadas.
As versões anteriores e os demais modelos foram preservados.
Relatórios: `mana_devourer_blocky_v3_report.json`, `godot_validation.json`.
