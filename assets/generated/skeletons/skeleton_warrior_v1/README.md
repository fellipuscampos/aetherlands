# Esqueleto Guerreiro V1 — Aetherlands

Modelo original, criado no Blender 5.2.2 exclusivamente pelo MCP em localhost:9876.
Mesma construção do Troll, Goblin e Minotauro: volumes retangulares, Shade Flat,
transições duras e pixel art em escala métrica. Inclui rig e as ações Idle, Walk e Attack.

## Arquivos

- `skeleton_warrior_v1.blend`: fonte editável final (cena `Skeleton_Warrior_V1`, rig, 3 actions na NLA, atlas packed).
- `skeleton_warrior_v1_static.blend`: modelo estático final (com as edições do usuário), sem rig.
- `skeleton_warrior_v1.glb`: export para o jogo (armature de 23 ossos, malhas skinned `Body` + `Sword`,
  1 material, textura embutida, 3 clips).
- `skeleton_warrior_import.gd` / `.glb.import`: importação Godot a 24 fps; Idle/Walk em loop, Attack sem loop.
- `skeleton_warrior_v1_animation_validation.json`: conferência de todos os frames.
- `previews/animations/Skeleton_{Idle,Walk,Attack}.{mp4,gif}`: prévias EEVEE 640×640.
- `skeleton_warrior_v1_atlas.png`: atlas único 256×256.
- `skeleton_warrior_v1_report.json`: medições, UV, conferência do GLB reimportado e mapa peça→osso.
- `previews/{three_quarter,front,side,back,game_top}.png`: renders Cycles 1000×1000
  (`game_top` aproxima a câmera alta do jogo).

## Forma e identidade

Soldado morto-vivo antigo, mais esguio que os outros humanoides.

- Caveira grande para leitura à distância: órbitas escuras com brilho frio, cavidade nasal,
  dentes; mandíbula em bloco próprio.
- Caixa torácica com esterno e costelas pintadas, coluna lombar segmentada (a "barriga"),
  pelve com forames.
- Braço, antebraço, mão; coxa, canela, pé. **Sem joelhos e sem volume nas costas.**
- Armadura enferrujada, parcial e assimétrica: elmo torto com crista curta e um furo,
  ombreira quebrada só no ombro esquerdo, braçadeira no antebraço da espada, caneleira
  na canela esquerda.
- Tabardo azul desbotado e rasgado (frente com brasão de torre apagado, e costas), preso sob o cinto.
- Espada enferrujada e lascada, com canal real no punho direito. A largura da lâmina
  fica no plano do golpe: o **fio** lidera um golpe frente/trás, não a face chata.

Edições manuais do usuário (versão final): pelve alargada (escala aplicada; só as ilhas
UV da pelve refeitas a 64 px/m por `skeleton_warrior_patch_uv.py`, resto do atlas
idêntico) e clavículas removidas.

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 508 |
| Altura | 1,85 m (com elmo); o esqueleto antigo da Asset Factory tem 1,75 m |
| Peças editáveis no .blend | 35 |
| Materiais | 1 |
| Textura | 256×256, sRGB, nearest |
| Densidade | 64 px/m nos dois eixos, igual à do Troll, Goblin e Minotauro |
| Geometria | Fechada (0 arestas non-manifold), faces sem área zero, flat |
| Pivot / frente | Origem no chão (0,0,0); frente -Y no Blender / +Z no glTF |

## Animações

| Action / clip | Frames locais a 24 fps | Duração | Loop | NLA |
| --- | --- | --- | --- | --- |
| `Skeleton_Idle` | 1–49 | 2,00 s | Sim | 1–49 |
| `Skeleton_Walk` | 1–29 | 1,1667 s | Sim | 61–89 |
| `Skeleton_Attack` | 1–29 | 1,1667 s | Não | 101–129 |

- **Idle**: balanço de morto-vivo, cabeça acenando, mandíbula batendo duas vezes, braços
  pendentes; espada carregada com o cotovelo meio dobrado; pés plantados.
- **Walk**: passada rígida e levemente curvada **no lugar**, 60% de apoio, crânio balançando.
  Velocidade sugerida ao controlador: **0,341 m/s**.
- **Attack**: golpe de espada por cima do ombro. Preparação até o frame 9, **impacto no
  frame 13** (0,5 s no clip exportado), continuação até 16, recuperação até 29.
  Medido: na descida o movimento fica 95–99,7% alinhado com o **fio** da lâmina.
- Sem giro lateral da cabeça em nenhum clip: os cantos do crânio quadrado varreriam a
  ombreira esquerda, que fica rente a ele.

Validação: emendas dos loops com deslocamento 0, nenhum vértice abaixo do chão, pés nos
alvos (< 1e-6 m), espada rígida na mão, nenhum cruzamento novo de superfície (espada ×
corpo/armadura/próprio braço, tabardo × coxas, ombreira × crânio/elmo/braço). Verificado
no Godot 4.7.1 (`tools/art_pipeline/verify_skeleton_import.gd`) e textura importada
idêntica ao atlas.

## Rig

Skin rígido por bloco: cada peça segue o único osso guardado em `rig_bone` (também em
`skeleton_warrior_v1_report.json` → `rig_bone_map`): elmo/caveira → `head`,
mandíbula → `jaw`, ombreira → `shoulder_l`, braçadeira → `forearm_r`,
caneleira → `shin_l`, cinto/fivela/pelve → `pelvis`, tabardo → `tabard_front`/`tabard_back`,
espada → `weapon` (filho de `hand_r`). Nenhuma peça de armadura precisa de peso dividido.

## Organização no Blender

Coleções `01_BONES`, `02_SKULL`, `03_ARMOUR_CLOTH`, `04_SWORD`, `05_STUDIO`; todas as
peças são filhas de `Skeleton_Warrior_V1_ROOT`.

## Reprodução via MCP

`python tools/art_pipeline/blender_mcp_client.py <script>`, em sequência:

1. `skeleton_warrior_model.py`: geometria + UV métrica (recusa sobrescrever; prefixe `REBUILD=True`).
2. `skeleton_warrior_paint_save.py`: pintura pixel art (sempre um datablock de imagem novo).
3. `skeleton_warrior_previews.py`: renders de revisão.
4. `skeleton_warrior_finalize.py`: salva o `.blend`, exporta e reimporta o `.glb`
   (falha se a textura embutida divergir do atlas em disco).
5. Após edições manuais: `skeleton_warrior_patch_uv.py` (com `BACKUP=...`) corrige só as peças
   com textura esticada; `skeleton_warrior_unrig.py` remove um rig gerado mantendo as malhas.
6. `skeleton_warrior_animate.py` → `skeleton_warrior_animation_validate.py` →
   `skeleton_warrior_animation_previews.py` (`FRAMES_DIR=...`) +
   `python tools/art_pipeline/encode_skeleton_previews.py <FRAMES_DIR>` →
   `skeleton_warrior_animation_save.py`.

## Integração

Integrado ao jogo em 2026-10-03: kind "skeleton" (`MonsterDatabase.SKELETON_V1_MODEL`) e nas Hostes de esqueletos (`UnitDatabase._apply_skeleton_formation`), escala 1,0, yaw 0,
crossfade de 0,2 s entre Idle/Walk/Attack (`animation_blend_time`).
