# Aranha Gigante V1 — Aetherlands

## Animações atuais

O `.blend` contém a aranha com os cortes manuais e a textura sem verde: **31 peças
editáveis, 372 triângulos, rig de 23 ossos**, com três ações a 24 fps.

| Ação | Frames locais | Duração | Faixa NLA | Movimento |
| --- | --- | --- | --- | --- |
| `Spider_Idle` | 1–61 | 2,50 s | 1–61 | Abdômen e palpos discretos, seis apoios fixos; loop |
| `Spider_Walk` | 1–33 | 1,33 s | 81–113 | Dois grupos alternados de quatro pernas; loop no lugar |
| `Spider_Attack` | 1–37 | 1,50 s | 131–167 | Elevação frontal, bote com presas, recuperação |

Impacto no frame local **15**, frame **145** da NLA. Para rever um ciclo no
Blender, use o intervalo NLA da tabela; as lacunas mostram a pose de repouso.
A caminhada corresponde a **0,3145 m/s** para frente (-Y), com o root parado.
As oito pernas têm poses calculadas e gravadas nos ossos, sem dependência de IK
em tempo de execução. A trajetória dos joelhos traseiros evita o abdômen.

Prévia de cada ação em `previews/animations/Spider_{Idle,Walk,Attack}.{mp4,gif}`.
Conferência em `animation_report.json` e `animation_validation.json`: loops
fechados, apoios no piso, pelo menos quatro pernas apoiadas na caminhada e
nenhum novo cruzamento de superfície nos pares verificados.
A versão estática sem verde está preservada em
`art_source/giant_spider_v1/giant_spider_v1_static_no_green.blend`.

Scripts desta etapa, sobre a cena atual, sem reconstrução do modelo:
`spider_animate.py`, `spider_animation_validate.py`,
`spider_animation_previews.py`, `encode_spider_previews.py` (Python local),
`spider_animation_save.py`. Os demais rodam pelo cliente MCP.
O GLB existente continua sendo a exportação estática anterior.

## Revisão atual da textura

Os detalhes verdes foram removidos do atlas e do `.blend`, preservando os cortes
manuais feitos na cena aberta e todas as UVs. Os olhos continuam violetas. Apenas
os pixels verdes foram substituídos pela superfície escura correspondente.
Conferência em `texture_edit_report.json`; prévia em `previews/no_green.png`.
O GLB e os dados da entrega original abaixo ainda pertencem à revisão anterior.

## Entrega original (antes dos cortes manuais)

Criada no Blender 5.2.2 exclusivamente pelo MCP em localhost:9876. Mesma construção do
bestiário aprovado: volumes retangulares, Shade Flat, transições duras e pixel art em
escala métrica. **Com rig, sem animações** (etapa de validação visual).

## Arquivos

- `giant_spider_v1.blend`: fonte editável com rig (cena `Giant_Spider_V1`, atlas packed).
- `giant_spider_v1.glb`: export para o jogo (armature de 23 ossos, malha skinned `Model`,
  1 material, textura embutida, pose de repouso, sem clips).
- `giant_spider_v1_atlas.png`: atlas único 512×512.
- `giant_spider_v1_report.json`: medições, UV, rig, teste de pose e conferência do GLB.
- `previews/{three_quarter,front,side,back,game_top}.png`: renders Cycles 1000×1000
  (`game_top` aproxima a câmera alta do jogo); `previews/pose_test.png`: teste do rig.

## Forma

- Corpo baixo: **cefalotórax** achatado (frente levemente abaixada), cintura curta e um
  **abdômen grande erguido para trás**, escalonado em dois blocos para ler arredondado,
  com fiandeiras na ponta.
- **8 pernas de só 2 segmentos** (fêmur subindo até um joelho alto acima do corpo, tíbia
  descendo afinando até o chão), grossas o bastante para não parecerem frágeis; o par
  da frente fica levemente erguido, pronto para o bote.
- Frente: **quelíceras com presas curvas**, palpos curtos, **6 olhos** em geometria
  (2 grandes, 4 menores).

## Materiais

- **Carapaça de quitina** negro-violeta: placas com juntas, sulco dorsal, faixa de
  brilho de casco duro nas laterais.
- **Abdômen** com **divisas verde-ácido** venenosas no dorso, linha pontilhada de veneno
  nas laterais e uma marca na ponta traseira.
- Pernas em quitina escura com anéis discretos nas juntas, cerdas esparsas e **pontas
  pretas**; presas pretas brilhantes com **gota de veneno verde**.
- Olhos com **brilho violeta** sombrio.

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 396 |
| Altura | 1,17 m (joelhos) |
| Comprimento | 2,93 m (presas às fiandeiras) |
| Largura (pernas abertas) | 3,16 m |
| Peças editáveis no .blend | 33 |
| Materiais | 1 |
| Textura | 512×512, sRGB, nearest |
| Densidade | 64 px/m nos dois eixos (medido 63,9993–64,0004), igual aos demais |
| Geometria | Fechada (0 arestas non-manifold), faces sem área zero, flat |
| Pivot / frente | Origem no chão (0,0,0); frente -Y no Blender / +Z no glTF |

## Rig

23 ossos: `root`, `cephalothorax`, `abdomen`, `chelicera_{l,r}` (com as presas),
`palp_{l,r}`, e `leg{1..4}_femur_{l,r}` / `leg{1..4}_tibia_{l,r}`. Skin rígido por bloco:
cada peça segue um único osso (olhos no cefalotórax; cintura, abdômen e fiandeiras no
abdômen). Teste de pose (pernas da frente erguidas, demais pisando, abdômen inclinado e
balançado, quelíceras abertas, palpos estendidos): **nenhum cruzamento novo** de
superfície (pernas × corpo, pernas × pernas, presas × palpos). O abdômen foi recuado para
que os fêmures do 4º par não o toquem em repouso.

## Organização no Blender

Coleções `01_BODY`, `02_HEAD`, `03_LEGS`, `04_STUDIO`, `05_RIG`; todas as peças são
filhas do rig, que é filho de `Giant_Spider_V1_ROOT`.

## Reprodução via MCP

`python tools/art_pipeline/blender_mcp_client.py <script>`, em sequência:

1. `spider_model.py`: geometria + UV métrica (recusa sobrescrever; prefixe `REBUILD=True`).
2. `spider_paint_save.py`: pintura pixel art (sempre um datablock de imagem novo).
3. `spider_previews.py`: renders de revisão.
4. `spider_rig.py`: rig, teste de pose, `.blend`, export e reimportação do `.glb`
   (falha se a textura embutida divergir do atlas em disco).

Verificação no Godot: `godot --headless --path . -s tools/art_pipeline/verify_spider_import.gd`.

## Integração

Integrado ao jogo em 2026-10-03: kind "giant_spider" (`MonsterDatabase.HANDMADE_MODELS`), escala 1,0, yaw 0,
crossfade de 0,2 s entre Spider_Idle/Spider_Walk/Spider_Attack (`animation_blend_time`).
O `giant_spider_v1.glb` anterior era o export estático (sem clipes, atlas ainda com verde);
foi re-exportado do `.blend` animado por `tools/art_pipeline/spider_export.py`, que confere
que o atlas embutido é idêntico a `giant_spider_v1_atlas.png`. Loops via `spider_import.gd`.

## Escala (2026-10-04)

O nó `Giant_Spider_V1_ROOT` (pai do rig) tem escala uniforme **0,60** no `.blend` e no `.glb`.
Malha, UVs, texturas, rig e animações não mudaram: só esse nó. Medidas em jogo:
**1,90 × 1,60 m de pegada (pernas abertas), 0,70 m de altura** (o resto deste README descreve o modelo em escala 1,0). A escala foi
gravada direto no nó raiz do GLB, sem re-export, e copiada para o `.blend`. Um
re-export mantém a escala porque o `_ROOT` vai junto.
