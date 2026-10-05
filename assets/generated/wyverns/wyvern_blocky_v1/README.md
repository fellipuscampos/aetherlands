# Wyvern Blocky V1 — Aetherlands

Wyvern criado no Blender 5.2.2 exclusivamente pelo MCP em localhost:9876. Mesma
construção do bestiário aprovado (Troll, Goblin, Minotauro, Esqueleto, Warg,
Basilisco): volumes retangulares, Shade Flat, transições duras e pixel art em escala
métrica. Inclui rig e as ações Idle, Walk e Attack.

Não confundir com o Dragão do evento mundial, que é um modelo procedural em
`scripts/units/Unit.gd` (`_build_dragon_body`) e não foi alterado.

## Arquivos

- `wyvern_blocky_v1.blend`: fonte editável (cena `Wyvern_Blocky_V1`, atlas packed).
- `wyvern_blocky_v1.glb`: export para o jogo (armature de 25 ossos, malha skinned `Model`,
  1 material, textura embutida, 3 clips).
- `wyvern_import.gd` / `.glb.import`: importação Godot a 24 fps; Idle/Walk em loop, Attack sem loop.
- `wyvern_blocky_v1_animation_validation.json`: conferência de todos os frames.
- `previews/animations/Wyvern_{Idle,Walk,Attack}.{mp4,gif}`: prévias EEVEE 640×640.
- `wyvern_blocky_v1_atlas.png`: atlas único 1024×1024.
- `wyvern_blocky_v1_report.json`: medições, UV, conferência do GLB reimportado e mapa peça→osso.
- `previews/{three_quarter,front,side,back,game_top}.png`: renders Cycles 1000×1000
  (`game_top` aproxima a câmera alta do jogo).

## Anatomia e identidade (V3, refeito pelas referências do usuário)

A V1 (asas de três triângulos, corpo compacto) foi rejeitada; a V2 seguiu as referências
enviadas (wyverns voxel vermelho/laranja/gelo) e a V3 corrigiu o que faltava: corpo bem
mais baixo e o membro dianteiro lendo como asa, não como uma pata separada.

- **Wyvern correto**: só **duas pernas traseiras**; **cada asa é o membro dianteiro**:
  braço e antebraço finos em osso de asa (mesma cor dos dedos), e o que toca o chão é o
  **nó do pulso da asa** com duas garras de polegar claras. Não existe pata dianteira.
- **Asas em leque** nascendo desse nó do pulso: cinco dedos ósseos escuros erguidos e
  dobrados para trás, gomos de membrana de borda recortada entre eles, pontas de osso
  claras; membrana também liga o braço ao corpo (cotovelo e ombro → pulso → flanco).
- Corpo **rente ao chão**, longo e baixo, pernas traseiras bem dobradas, pescoço comprido em três segmentos, cauda muito longa saindo do
  quadril por uma raiz afunilada.
- **Fileira de espinhos claros** do pescoço até a ponta da cauda, diminuindo para trás.
- Cabeça em bloco com a **boca escancarada**: interior vermelho-sangue, **dentes brancos em
  bloco nas duas mandíbulas**, nariz com narinas, olhos amarelos com pupila em fenda e
  **uma crista acima de cada olho**, **dois pares de chifres** de osso para trás.

## Materiais

- **Escamas** vermelhas em ruído pixelado de 3 tons, dorso mais escuro, pernas e cauda
  escurecendo; **placas de couro creme** na barriga, garganta, sob a cauda e na mandíbula.
- **Membrana** vermelha manchada, mais viva, com borda de fuga escura; **dedos** vermelho-escuro.
- **Osso** claro nos chifres, espinhos, garras e pontas dos dedos, escurecendo na ponta.

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 1316 |
| Altura | 2,07 m (pontas das asas) |
| Comprimento | 6,04 m (focinho à ponta da cauda) |
| Envergadura pousado | 2,58 m |
| Peças editáveis no .blend | 111 (inclui 16 dentes e 18 espinhos dorsais) |
| Materiais | 1 |
| Textura | 1024×1024, sRGB, nearest (1024 só pela área das membranas; densidade igual) |
| Densidade | 64 px/m nos dois eixos (medido 63,995–64,002), igual aos demais |
| Geometria | Fechada (0 arestas non-manifold), faces sem área zero, flat |
| Pivot / frente | Origem no chão (0,0,0); frente -Y no Blender / +Z no glTF |

## Animações

| Action / clip | Frames locais a 24 fps | Duração | Loop | NLA |
| --- | --- | --- | --- | --- |
| `Wyvern_Idle` | 1–49 | 2,00 s | Sim | 1–49 |
| `Wyvern_Walk` | 1–29 | 1,1667 s | Sim | 61–89 |
| `Wyvern_Attack` | 1–33 | 1,3333 s | Não | 101–133 |

- **Idle**: rente ao chão; respiração, cabeça baixa oscilando, rosnado, leques das asas
  flexionando, cauda balançando. Pés e pulsos das asas plantados.
- **Walk**: espreita baixa **no lugar** apoiada nos pés e nos **pulsos das asas**, sequência
  lateral (traseira E, asa E, traseira D, asa D), 62% de apoio; o leque abre levemente ao
  erguer cada asa; cauda ondulando. Velocidade sugerida ao controlador: **0,442 m/s**.
- **Attack**: pescoço recua em S com as asas abertas em ameaça (1–10), bote à frente na
  altura da cabeça com a boca escancarada (10–13), **mordida no impacto, frame 14**
  (0,542 s no clip exportado), volta ao repouso até 33.
- A boca do modelo já é aberta em repouso; os dentes se tocam após ~0,09 rad de
  fechamento, então a mordida vai de bem aberta até quase encostar os dentes.

Validação: emendas dos loops com deslocamento 0; o ataque volta ao repouso; nenhum
vértice abaixo do chão; pés e pulsos nos alvos (< 1e-6 m); nenhum cruzamento novo de
superfície (cabeça/pescoço × asas, asas entre si e × pernas, pernas entre si, cauda ×
pernas e entre segmentos, mandíbula × focinho, dentes de cima × de baixo). Verificado
no Godot 4.7.1 (`tools/art_pipeline/verify_wyvern_import.gd`) e textura importada
idêntica ao atlas.

## Rig

Cada peça guarda em `rig_bone` o único osso que deve seguir (também em
`wyvern_blocky_v1_report.json` → `rig_bone_map`): `chest`, `hips`, `neck_01`, `neck_02`,
`neck_03`, `head`, `jaw`, `upper_arm_{l,r}`, `forearm_{l,r}`, `hand_{l,r}` (nó do pulso), `thigh_{l,r}`,
`shin_{l,r}`, `foot_{l,r}`, `tail_01`…`tail_05`. Dentes seguem `head`/`jaw`; espinhos seguem o
segmento onde nascem. Skin rígido por bloco, **exceto as membranas que ligam a asa ao corpo**
(`Membrane5`, `MembraneElbow`, `MembraneArm`): cada canto segue o osso onde está ancorado
(ombro → braço, cotovelo → antebraço, pulso → mão, flanco → peito), então a pele estica
entre os ossos em vez de rasgar ou atravessar o corpo. Os gomos do leque seguem `hand_{l,r}`
(um bater de asas com cada dedo independente exigiria ossos por dedo numa etapa futura).
IK analítico gravado nos ossos para os 4 apoios (sem IK em runtime).

## Organização no Blender

Coleções `01_BODY`, `02_HEAD`, `03_LEGS`, `04_WINGS`, `05_TAIL`, `06_STUDIO`; todas as
peças são filhas de `Wyvern_Blocky_V1_ROOT`.

## Reprodução via MCP

`python tools/art_pipeline/blender_mcp_client.py <script>`, em sequência:

1. `wyvern_model.py`: geometria + UV métrica (recusa sobrescrever; prefixe `REBUILD=True`).
2. `wyvern_paint_save.py`: pintura pixel art (sempre um datablock de imagem novo).
3. `wyvern_previews.py`: renders de revisão.
4. `wyvern_finalize.py`: salva o `.blend`, exporta e reimporta o `.glb`
   (falha se a textura embutida divergir do atlas em disco).
5. `wyvern_animate.py` (`wyvern_unrig.py` remove um rig gerado) → `wyvern_animation_validate.py` →
   `wyvern_animation_previews.py` (`FRAMES_DIR=...`) + `python tools/art_pipeline/encode_wyvern_previews.py <FRAMES_DIR>`
   → `wyvern_animation_save.py`.

## Integração

Integrado ao jogo em 2026-10-03: kind "wyvern" (`MonsterDatabase.HANDMADE_MODELS`), escala 1,0, yaw 0,
crossfade de 0,2 s entre Wyvern_Idle/Wyvern_Walk/Wyvern_Attack (`animation_blend_time`).

## Escala (2026-10-04)

O nó `Wyvern_Blocky_V1_ROOT` (pai do rig) tem escala uniforme **0,50** no `.blend` e no `.glb`.
Malha, UVs, texturas, rig e animações não mudaram: só esse nó. Medidas em jogo:
**3,02 m de comprimento (com a cauda), 1,29 m de largura, 1,03 m de altura** (o resto deste README descreve o modelo em escala 1,0). A escala foi
gravada direto no nó raiz do GLB, sem re-export, e copiada para o `.blend`. Um
re-export mantém a escala porque o `_ROOT` vai junto.
