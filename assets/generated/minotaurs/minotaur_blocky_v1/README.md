# Minotauro Blocky V1 — Aetherlands

Modelo original, criado e animado no Blender 5.2.2 exclusivamente pelo MCP em
localhost:9876. Mantém a construção blocky aprovada no Troll e no Goblin V3:
volumes retangulares, Shade Flat, transições duras e pixel art em escala métrica.
Inclui rig e as ações Idle, Walk e Attack.

## Arquivos

- `minotaur_blocky_v1.blend`: fonte editável final (cena `Minotaur_Blocky_V1`, rig, 3 actions na NLA, atlas packed).
- `minotaur_blocky_v1_static.blend`: modelo estático final (edições do usuário + labrys corrigido), sem rig.
- `minotaur_blocky_v1.glb`: export para o jogo (armature de 24 ossos, malhas skinned `Body` + `Labrys`,
  1 material, textura embutida, 3 clips).
- `minotaur_blocky_import.gd` / `.glb.import`: importação Godot a 24 fps; Idle/Walk em loop, Attack sem loop.
- `minotaur_blocky_v1_atlas.png`: atlas único 512×512.
- `minotaur_blocky_v1_report.json`: medições, UV, rig, clips e conferência do GLB reimportado.
- `minotaur_blocky_v1_animation_validation.json`: conferência de todos os frames.
- `previews/{three_quarter,front,side,back,game_top}.png`: renders Cycles 1000×1000 em pose de repouso
  (`game_top` aproxima a câmera alta do jogo).
- `previews/animations/Minotaur_{Idle,Walk,Attack}.{mp4,gif}`: prévias EEVEE 640×640.

## Forma e identidade

- Brutamontes curvado para frente: peito largo inclinado, ombros e antebraços pesados.
- Cabeça bovina projetada à frente; focinho e mandíbula em blocos próprios,
  argola de ferro quadrada, olhos vermelhos sob sobrancelhas inclinadas.
- Chifres grandes em 4 segmentos afunilados, com anéis pintados e pontas escuras.
- Cascos fendidos; cauda com tufo.
- Tanga carmesim presa sob o cinto, fivela e braceletes de ferro.
- Arma: labrys (machado de duas lâminas) com canal real no punho direito. As lâminas ficam no
  plano do golpe (frente/trás), então o **fio** lidera a machadada, não a face chata.

Edições manuais do usuário (versão final): removidos a corcova (`Hump`), os cotovelos
(`Elbow_l/r`), os joelhos (`Knee_l/r`) e as tornozeleiras (`AnkleBand_l/r`); abdômen, pelve e cinto
alargados. As escalas foram aplicadas na malha e as UVs/pintura refeitas a 64 px/m
(`minotaur_blocky_rework.py`), sem textura esticada.

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 744 |
| Altura total / topo da cabeça | 2,79 m (com chifres) / 2,42 m |
| Peças editáveis no .blend | 55 |
| Materiais | 1 |
| Textura | 512×512, sRGB, nearest |
| Densidade | 64 px/m nos dois eixos, igual à do Troll e do Goblin |
| Geometria | Fechada, faces sem área zero, flat |
| Rig / skin | 24 ossos; skin rígido por bloco (cada peça segue 1 osso) |
| Pivot / frente | Origem no chão (0,0,0); frente -Y no Blender / +Z no glTF |

## Animações

| Action / clip | Frames locais a 24 fps | Duração | Loop | NLA |
| --- | --- | --- | --- | --- |
| `Minotaur_Idle` | 1–49 | 2,00 s | Sim | 1–49 |
| `Minotaur_Walk` | 1–29 | 1,1667 s | Sim | 61–89 |
| `Minotaur_Attack` | 1–37 | 1,50 s | Não | 101–137 |

- **Idle**: respiração pesada (peito e ombros sobem), bufada lenta da cabeça com a
  mandíbula entreaberta, cauda balançando; o labrys é carregado com o cotovelo dobrado
  (mesma pose base da caminhada e do início/fim do ataque); cascos plantados.
- **Walk**: passada pesada e curvada **no lugar**, 60% de apoio; o braço livre balança
  amplo e o braço do machado carrega o labrys com o cotovelo dobrado. Velocidade de
  deslocamento sugerida ao controlador: **0,486 m/s** (igual ao Troll).
- **Attack**: machadada por cima da cabeça com urro. Preparação até o frame 13
  (labrys erguido, tronco torcido para trás, mandíbula aberta), descida rápida,
  **impacto no frame 19** (0,75 s no clip exportado), continuação até 23 e
  recuperação até 37. Cada action tem marcadores (`WINDUP`, `IMPACT`...).
  Medido: durante a descida, o movimento da cabeça do machado fica 96–99% alinhado
  com a direção do fio (golpe com o fio, não com a face).

Loops terminam num frame igual ao primeiro; os vídeos não repetem esse frame.
Os cascos são resolvidos com IK analítico e gravados nos ossos (sem IK em runtime).

## Validação

- Emendas de Idle/Walk: deslocamento máximo de vértice 0.
- Nenhum vértice abaixo do chão em nenhum frame dos 3 clips.
- Erro dos alvos dos cascos < 0,000001 m; labrys rigidamente preso à mão.
- Nenhum cruzamento novo de superfície (labrys × cabeça/chifres/corpo/pernas,
  tanga/cauda × coxas, mandíbula × peito) em todos os frames.
- GLB reimportado no Blender e verificado no Godot 4.7.1
  (`tools/art_pipeline/verify_minotaur_import.gd`): 24 ossos, 2 malhas skinned,
  altura 2,79 m com base em y=0, durações e loops corretos, poses finitas em todos os frames.

## Reprodução via MCP

Executar com `python tools/art_pipeline/blender_mcp_client.py <script>`:

1. `minotaur_blocky_model.py`, `minotaur_blocky_paint_save.py`, `minotaur_blocky_previews.py`,
   `minotaur_blocky_finalize.py`: modelo original (antes da edição manual).
   Depois das edições manuais: `minotaur_blocky_rework.py` (com `BACKUP=...`) e de novo
   `minotaur_blocky_paint_save.py`. **A versão final é o `minotaur_blocky_v1_static.blend`**;
   para reanimar, abra-o no Blender e siga daqui.
2. `minotaur_blocky_animate.py`: rig e três actions/NLA (recusa sobrescrever um rig existente).
3. `minotaur_blocky_animation_validate.py`: auditoria de todos os frames.
4. `minotaur_blocky_animation_previews.py` (com `FRAMES_DIR=...`) e
   `python tools/art_pipeline/encode_minotaur_previews.py <FRAMES_DIR>`: MP4/GIF.
5. `minotaur_blocky_animation_save.py`: stills, `.blend` final, GLB e conferência.

Depois de editar e salvar o `.blend` à mão (sem sessão MCP), reexportar em background:
`blender -b --factory-startup assets/generated/minotaurs/minotaur_blocky_v1/minotaur_blocky_v1.blend
--python tools/art_pipeline/minotaur_blocky_export.py -- [--previews <FRAMES_DIR>]`
(não regrava o `.blend`; falha se o atlas embutido divergir de `minotaur_blocky_v1_atlas.png`;
nesse caso rodar `minotaur_blocky_repack_atlas.py` no `.blend`).

## Integração

Integrado ao jogo em 2026-10-03: kind "minotaur" (`MonsterDatabase.HANDMADE_MODELS`), escala 1,0, yaw 0,
crossfade de 0,2 s entre Idle/Walk/Attack (`animation_blend_time`).
