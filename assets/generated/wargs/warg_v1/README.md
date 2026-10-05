# Warg V1 — Aetherlands

Lobo monstruoso de fantasia, criado no Blender 5.2.2 exclusivamente pelo MCP em
localhost:9876. Mesma construção do Troll, Goblin, Minotauro e Esqueleto: volumes
retangulares, Shade Flat, transições duras e pixel art em escala métrica.
Inclui rig de quadrúpede e as ações Idle, Walk e Attack.

## Arquivos

- `warg_v1.blend`: fonte editável final (cena `Warg_V1`, rig, 3 actions na NLA, atlas packed).
- `warg_v1.glb`: export para o jogo (armature de 20 ossos, malha skinned `Body`, 1 material,
  textura embutida, 3 clips).
- `warg_import.gd` / `.glb.import`: importação Godot a 24 fps; Idle/Walk em loop, Attack sem loop.
- `warg_v1_animation_validation.json`: conferência de todos os frames.
- `previews/animations/Warg_{Idle,Walk,Attack}.{mp4,gif}`: prévias EEVEE 640×640.
- `warg_v1_atlas.png`: atlas único 512×512.
- `warg_v1_report.json`: medições, UV, conferência do GLB reimportado e mapa peça→osso.
- `previews/{three_quarter,front,side,back,game_top}.png`: renders Cycles 1000×1000
  (`game_top` aproxima a câmera alta do jogo).

## Forma e identidade (V2, refeito após revisão)

A primeira versão (de pé, com pontas de pelo eriçado) foi rejeitada. A V2 segue a
direção da referência aprovada pelo usuário, sem copiá-la:

- Pose agachada de bote: corpo baixo e horizontal, cabeça baixa à frente, patas
  dianteiras esticadas para frente, traseiras dobradas como mola. Passa velocidade.
- Cabeça larga, orelhas em pé, focinho forte com nariz preto grande, mandíbula
  entreaberta com língua, dentes inferiores e duas presas; olhos amarelos com pupila
  em fenda sob sobrancelhas inclinadas.
- Pelo por **mechas sobrepostas com borda irregular**, não por espinhos: juba grossa
  no pescoço, ruff pendendo do peito, tufos nas bochechas, mechas no ombro e na coxa.
- Textura de fios longos e de baixo contraste seguindo a direção do pelo (para baixo
  nas laterais, para trás no dorso); dorso um pouco mais escuro, barriga e pontas das
  mechas claras, garras e nariz escuros, cauda espessa com ponta clara.

Estrutura: cabeça, focinho, nariz, mandíbula, pescoço (com juba), peito, quadril,
perna dianteira (superior/inferior/pata+garras), perna traseira (coxa/inferior/pata+garras),
cauda (base/ponta). Sem joelhos extras e sem peças escondidas.

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 604 |
| Altura | 1,19 m (pontas das orelhas, agachado) |
| Comprimento | 2,60 m (nariz à ponta da cauda) |
| Peças editáveis no .blend | 39 |
| Materiais | 1 |
| Textura | 512×512, sRGB, nearest |
| Densidade | 64 px/m nos dois eixos, igual aos demais |
| Geometria | Fechada (0 arestas non-manifold), faces sem área zero, flat |
| Pivot / frente | Origem no chão (0,0,0); frente -Y no Blender / +Z no glTF |

## Animações

| Action / clip | Frames locais a 24 fps | Duração | Loop | NLA |
| --- | --- | --- | --- | --- |
| `Warg_Idle` | 1–49 | 2,00 s | Sim | 1–49 |
| `Warg_Walk` | 1–29 | 1,1667 s | Sim | 61–89 |
| `Warg_Attack` | 1–33 | 1,3333 s | Não | 101–133 |

- **Idle**: à espreita na pose de bote aprovada; respiração baixando o peito, rosnado
  (mandíbula tremendo), cabeça oscilando de leve, cauda balançando. Patas plantadas.
- **Walk**: espreita baixa **no lugar**, sequência lateral de quadrúpede (traseira E,
  dianteira E, traseira D, dianteira D, um quarto de ciclo de diferença), 65% de apoio.
  As patas da frente trabalham um pouco atrás da pose esticada para caber a passada.
  Velocidade sugerida ao controlador: **0,316 m/s**.
- **Attack**: bote com mordida. Agacha descendo o peito com a cabeça nivelada na presa
  (1–10), salta à frente com a boca escancarada (10–14), **fecha a mordida no impacto,
  frame 15** (0,583 s no clip exportado), segura e volta à pose (até 33).

Validação: emendas dos loops com deslocamento 0; o ataque volta exatamente à pose de
repouso; nenhum vértice abaixo do chão; as quatro patas nos alvos (< 1e-6 m); nenhum
cruzamento novo de superfície (cabeça/mandíbula/bochechas × pernas dianteiras e ruff,
pernas entre si, cauda × coxas). Verificado no Godot 4.7.1
(`tools/art_pipeline/verify_warg_import.gd`) e textura importada idêntica ao atlas.

## Rig

Skin rígido por bloco: cada peça segue o único osso guardado em `rig_bone` (também em
`warg_v1_report.json` → `rig_bone_map`): `chest`, `hips`, `neck`, `head`, `jaw`,
`front_upper/lower/paw_{l,r}`, `hind_thigh/lower/paw_{l,r}`, `tail_01`, `tail_02`.
Orelhas, nariz, sobrancelhas, presas e tufos das bochechas seguem `head`; juba segue
`neck`; ruff do peito segue `chest`; mechas do ombro/coxa seguem a perna; garras seguem a pata. IK analítico nas quatro pernas, gravado
nos ossos (sem IK em runtime); cada perna dobra para o mesmo lado da pose aprovada.

## Organização no Blender

Coleções `01_BODY`, `02_HEAD`, `03_LEGS`, `04_FUR`, `05_STUDIO`; todas as peças são
filhas de `Warg_V1_ROOT`.

## Reprodução via MCP

`python tools/art_pipeline/blender_mcp_client.py <script>`, em sequência:

1. `warg_model.py`: geometria + UV métrica (recusa sobrescrever; prefixe `REBUILD=True`).
2. `warg_paint_save.py`: pintura pixel art (sempre um datablock de imagem novo).
3. `warg_previews.py`: renders de revisão.
4. `warg_finalize.py`: salva o `.blend`, exporta e reimporta o `.glb`
   (falha se a textura embutida divergir do atlas em disco).
5. `warg_animate.py` (`warg_unrig.py` remove um rig gerado) → `warg_animation_validate.py` →
   `warg_animation_previews.py` (`FRAMES_DIR=...`) + `python tools/art_pipeline/encode_warg_previews.py <FRAMES_DIR>`
   → `warg_animation_save.py`.

## Integração

Integrado ao jogo em 2026-10-03: kind "worg" (`MonsterDatabase.HANDMADE_MODELS`), escala 1,0, yaw 0,
crossfade de 0,2 s entre Idle/Walk/Attack (`animation_blend_time`).

## Escala (2026-10-04)

O nó `Warg_V1_ROOT` (pai do rig) tem escala uniforme **0,65** no `.blend` e no `.glb`.
Malha, UVs, texturas, rig e animações não mudaram: só esse nó. Medidas em jogo:
**1,71 m de comprimento, 0,57 m de largura, 0,77 m de altura** (o resto deste README descreve o modelo em escala 1,0). A escala foi
gravada direto no nó raiz do GLB, sem re-export, e copiada para o `.blend`. Um
re-export mantém a escala porque o `_ROOT` vai junto.
