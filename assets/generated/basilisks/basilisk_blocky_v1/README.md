# Basilisco Blocky V1 — Aetherlands

Basilisco na leitura mítica original (galo + serpente), criado no Blender 5.2.2
exclusivamente pelo MCP em localhost:9876. Mesma construção dos modelos aprovados
(Troll, Goblin, Minotauro, Esqueleto, Warg): volumes retangulares, Shade Flat,
transições duras e pixel art em escala métrica. Inclui rig e as ações Idle, Walk e Attack.

## Arquivos

- `basilisk_blocky_v1.blend`: fonte editável (cena `Basilisk_Blocky_V1`, atlas packed).
- `basilisk_blocky_v1.glb`: export para o jogo (armature de 20 ossos, malha skinned `Model`,
  1 material, textura embutida, 3 clips).
- `basilisk_import.gd` / `.glb.import`: importação Godot a 24 fps; Idle/Walk em loop, Attack sem loop.
- `basilisk_blocky_v1_animation_validation.json`: conferência de todos os frames.
- `previews/animations/Basilisk_{Idle,Walk,Attack}.{mp4,gif}`: prévias EEVEE 640×640.
- `basilisk_blocky_v1_atlas.png`: atlas único 512×512.
- `basilisk_blocky_v1_report.json`: medições, UV, conferência do GLB reimportado e mapa peça→osso.
- `previews/{three_quarter,front,side,back,game_top}.png`: renders Cycles 1000×1000
  (`game_top` aproxima a câmera alta do jogo).

## Forma e identidade (V2, revisado após feedback)

A V1 tinha leitura confusa (olhos/sobrancelhas sem enquadramento, textura ambígua,
asa como placa, cauda "acoplada"). A V2 corrige:

- **Rosto**: crânio de víbora inclinado para o alvo, com articulações da mandíbula largas
  (de frente lembra o capuz de uma naja). Olhos em geometria, voltados 30° para frente,
  brilhando amarelo-venenoso com aro laranja e pupila em fenda; **uma crista óssea por
  olho, diretamente acima dele**, inclinada para o bico (expressão de ataque). Bico em
  gancho de chifre escuro, boca aberta com presas longas e língua bifurcada. A crista e a
  barbela de galo continuam, vermelho-sangue.
- **Materiais separados à primeira vista**: **plumagem** marrom-negra com brilho cobre
  (corpo, peito com ruff, coxas, asas, colar de penas do pescoço, plumas iridescentes),
  pintada como penas de verdade (ponta arredondada, haste clara, camadas sobrepostas);
  **réptil** verde-veneno (cabeça, pescoço alto, garganta com escudos ventrais, cauda com
  faixas escuras e escudos amarelados embaixo, pernas amarelas escamosas), pintado como
  escamas em arco.
- **Asas**: dobradas em três camadas sobrepostas (coberteiras, secundárias, primárias
  longas), cada uma com borda de penas recortada.
- **Transição**: um quadril afunilado liga o corpo à cauda; as penas terminam nele numa
  borda irregular e as escamas começam ali; as plumas de galo saem de cima dele.
- Não é dragão, wyvern nem lagarto: não há patas dianteiras reptilianas; as armas vêm do
  próprio corpo (bico, presas, garras, esporões).

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 920 |
| Altura | 2,31 m (topo da crista) |
| Comprimento | 3,17 m (bico à ponta da cauda) |
| Peças editáveis no .blend | 52 |
| Materiais | 1 |
| Textura | 512×512, sRGB, nearest |
| Densidade | 64 px/m nos dois eixos (medido 63,9992–64,0006), igual aos demais |
| Geometria | Fechada (0 arestas non-manifold), faces sem área zero, flat, sem faces coplanares sobrepostas |
| Pivot / frente | Origem no chão (0,0,0); frente -Y no Blender / +Z no glTF |

## Animações

| Action / clip | Frames locais a 24 fps | Duração | Loop | NLA |
| --- | --- | --- | --- | --- |
| `Basilisk_Idle` | 1–49 | 2,00 s | Sim | 1–49 |
| `Basilisk_Walk` | 1–29 | 1,1667 s | Sim | 61–89 |
| `Basilisk_Attack` | 1–33 | 1,3333 s | Não | 101–133 |

- **Idle**: pescoço oscilando como serpente, cabeça inclinando aos trancos como ave,
  língua entrando e saindo, onda de serpente na cauda, asas se ajeitando, respiração.
  Pés plantados.
- **Walk**: passo de galo **no lugar**, com a cabeça puxando para trás e projetando
  para frente a cada passo, onda de serpente correndo pela cauda, 60% de apoio.
  Velocidade sugerida ao controlador: **0,486 m/s**.
- **Attack**: bote de cobra. Pescoço recua em S e asas abrem em ameaça (1–10), bote
  para frente e para baixo com a boca escancarada (10–13), **mordida no impacto,
  frame 14** (0,542 s no clip exportado), volta ao repouso até 33.

Validação: emendas dos loops com deslocamento 0; o ataque volta ao repouso; nenhum
vértice abaixo do chão; pés nos alvos (< 1e-6 m); nenhum cruzamento novo de superfície
(cabeça × corpo/asas/colar, pescoço × colar/asas, asas × pernas, pernas entre si,
cauda × pernas e entre segmentos, plumas × asas). Verificado no Godot 4.7.1
(`tools/art_pipeline/verify_basilisk_import.gd`) e textura importada idêntica ao atlas.

## Rig

Skin rígido por bloco: cada peça segue o único osso guardado em `rig_bone` (também em
`basilisk_blocky_v1_report.json` → `rig_bone_map`): `body`, `neck_01`, `neck_02`,
`head`, `jaw`, `wing_{l,r}`, `thigh_{l,r}`, `tarsus_{l,r}`, `foot_{l,r}`,
`tail_01` (quadril) … `tail_06`. Crista, bico, olhos, sobrancelhas e presas seguem `head`;
barbela e língua seguem `jaw`; colar de penas segue `neck_01`; plumas seguem `tail_01`;
as três camadas de cada asa seguem `wing_{l,r}`; esporões seguem o tarso; dedos seguem o pé. Pernas com IK analítico gravado nos ossos
(sem IK em runtime), dobrando como na pose aprovada.

## Organização no Blender

Coleções `01_BODY`, `02_HEAD`, `03_LEGS`, `04_FEATHERS`, `05_TAIL`, `06_STUDIO`; todas
as peças são filhas de `Basilisk_Blocky_V1_ROOT`.

## Reprodução via MCP

`python tools/art_pipeline/blender_mcp_client.py <script>`, em sequência:

1. `basilisk_model.py`: geometria + UV métrica (recusa sobrescrever; prefixe `REBUILD=True`).
2. `basilisk_paint_save.py`: pintura pixel art (sempre um datablock de imagem novo).
3. `basilisk_previews.py`: renders de revisão.
4. `basilisk_finalize.py`: salva o `.blend`, exporta e reimporta o `.glb`
   (falha se a textura embutida divergir do atlas em disco).
5. `basilisk_animate.py` (`basilisk_unrig.py` remove um rig gerado) → `basilisk_animation_validate.py` →
   `basilisk_animation_previews.py` (`FRAMES_DIR=...`) + `python tools/art_pipeline/encode_basilisk_previews.py <FRAMES_DIR>`
   → `basilisk_animation_save.py`.

## Integração

Integrado ao jogo em 2026-10-03: kind "basilisk" (`MonsterDatabase.HANDMADE_MODELS`), escala 1,0, yaw 0,
crossfade de 0,2 s entre Idle/Walk/Attack (`animation_blend_time`).
