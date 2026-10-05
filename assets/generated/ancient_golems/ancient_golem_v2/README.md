# Ancient Golem V2 (Ancião da Floresta, versão golem) — Aetherlands

Golem de pedra da natureza, baseado na referência de golem voxel do usuário (sem a
espada). É inteiro de pedra e anda como gorila, apoiado nos punhos. Foi criado no Blender
5.2, exclusivamente pelo MCP em localhost:9876, e passou por cortes manuais do usuário.
Tem rig rígido e três animações.

## Arquivos

- `ancient_golem_v2.blend`: cena `Ancient_Golem_V2`, 21 peças editáveis, rig de 17 ossos,
  ações `Golem_Idle`, `Golem_Walk` e `Golem_Attack` em faixas NLA, texturas embutidas.
- `ancient_golem_v2.glb`: export para o jogo.
  - Uma malha `Model` com skin de 17 ossos e 1 material.
  - Albedo e emissão embutidos.
  - Os 3 clips.
- `ancient_golem_import.gd`: script de pós-import do Godot (Idle e Walk em loop, Attack
  não).
- `ancient_golem_v2_albedo.png` / `ancient_golem_v2_emission.png`: atlas 1024×1024,
  64 px/m.
- `ancient_golem_v2_report.json`: medições, UV, rig, animações, validação, GLB e `.blend`.
- `previews/{three_quarter,front,side,back,game_top}.png`: pose de repouso.
- `previews/animations/Golem_{Idle,Walk,Attack}.{mp4,gif}`: prévia das animações.
- `art_source/ancient_golem_v2/`: quadros das prévias e backup estático antes do rig.

## Forma e materiais

- **Pose**: postura de gorila. O tronco tomba para a frente a partir do quadril, os braços
  longos apoiam os punhos de pedra no chão à frente e as pernas ficam dobradas atrás.
- **Cabeça**: baixa entre os ombros, com testa de pedra e olhos verdes brilhando em
  órbitas escuras.
- **Pedra clara**: placas com espiral entalhada só nas placas grandes (nunca no rosto) e
  rachaduras.
- **Pedra escura**: o núcleo (tronco, pelve e braços superiores), com fissuras verdes
  luminosas.
- **Musgo**: cobre parte dos topos, com borda orgânica.
- A base da canela foi recortada até 18,5 cm. Era um volume escondido dentro do pé que
  atravessava o chão quando a canela inclinava.

## Animações (24 fps)

| Clip | Frames | Duração | Loop | Movimento |
| --- | --- | --- | --- | --- |
| `Golem_Idle` | 1–73 | 3,0 s | Sim | Respiração pesada curvando o peito, leve balanço, olhar lento em volta; punhos e pés plantados |
| `Golem_Walk` | 1–33 | 1,33 s | Sim | Andar de gorila nos punhos, no lugar, em pares diagonais (punho esq. + pé dir.); corpo agachado com balanço e giro do peito para o braço que avança |
| `Golem_Attack` | 1–41 | 1,67 s | Não | Ergue o corpo com os dois punhos acima da cabeça e ruge, avança e martela o chão à frente |

- **Walk**: vale **0,30 m/s** para a frente (-Y), com o root parado.
- **Attack**: impacto no quadro **20**. Marcadores: `WINDUP` (12), `IMPACT` (20),
  `RECOVERED` (41).

Punhos e pés são posicionados por IK analítico de 2 ossos, gravado nos ossos (nada de IK
em tempo de execução). A validação conferiu:
- loops fechados (erro 0);
- nada abaixo do chão em nenhum quadro;
- no Idle, punhos e pés sempre no chão;
- no Walk, pelo menos um punho e um pé no chão em todo quadro;
- no impacto do Attack, os dois punhos no chão.

## Rig (17 ossos, skin rígido)

`root`, `hips` (pelve), `chest` (tronco e ombreiras), `head` (cabeça, testa e olhos),
`jaw`, e de cada lado: `upper_arm`, `forearm` (manopla), `fist`, `thigh`, `shin`, `foot`.

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 252 |
| Altura (repouso) | 2,34 m |
| Geometria | Fechada, flat, nada abaixo do chão |
| Frente | -Y no Blender / +Z no glTF |

## Reprodução via MCP (sobre a cena salva)

1. `ancient_golem_v2_animate.py`: rig e ações. Use `REBAKE=True` para refazer.
2. `ancient_golem_v2_animation_validate.py` e `ancient_golem_v2_animation_previews.py`.
3. `python tools/art_pipeline/encode_ancient_golem_v2_previews.py` (Python local, ffmpeg).
4. `ancient_golem_v2_export.py`: `.blend` e GLB, com inspeção do binário.

Etapas anteriores, já aplicadas na cena:
- geometria: `ancient_golem_v2_model.py`, os cortes manuais, `ancient_golem_v2_mirror_arms.py`,
  `ancient_golem_v2_gorilla_pose.py`, `ancient_golem_v2_gorilla_adjust.py`;
- canela e textura: `ancient_golem_v2_trim_shins.py` e `ancient_golem_v2_paint_save.py`.

Verificação no Godot:
`godot --headless --path . -s tools/art_pipeline/verify_ancient_golem_import.gd` (PASS).
Os PNGs que o Godot extraiu são idênticos aos atlas.

## Integração

Integrado em 2026-10-04 como kind `arboreal_ancient` (Ancião Arbóreo) em
`MonsterDatabase.HANDMADE_MODELS`: escala 1,0, yaw 0, crossfade de 0,2 s entre
Golem_Idle/Golem_Walk/Golem_Attack (os 3 clipes animam os mesmos 17 ossos).

## Escala (2026-10-04)

O nó `Ancient_Golem_V2_ROOT` (pai do rig) tem escala uniforme **0,72** no `.blend` e no `.glb`.
Malha, UVs, texturas, rig e animações não mudaram: só esse nó. Medidas em jogo:
**2,00 × 1,72 m de pegada, 1,68 m de altura** (o resto deste README descreve o modelo em escala 1,0). A escala foi
gravada direto no nó raiz do GLB, sem re-export, e copiada para o `.blend`. Um
re-export mantém a escala porque o `_ROOT` vai junto.
