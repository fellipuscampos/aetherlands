# Verme de Areia V1 (Verme Colossal) — Aetherlands

Verme-lacraia de areia para o kind `colossal_worm` ("Verme Colossal"). Criado no Blender
5.2, exclusivamente pelo MCP em localhost:9876, na linguagem do bestiário: cuboides, Shade
Flat, pixel art métrica de 64 px/m. Rig rígido de 35 ossos e quatro animações: **Idle, Attack,
Burrow (entrar na terra) e Emerge (sair da terra)**. Não tem Walk.

## Arquivos

- `sand_worm_v1.blend`: fonte editável. Cena `Sand_Worm_V1`, 79 peças separadas, atlas packed.
- `sand_worm_v1_atlas.png`: atlas único 1024×1024, nearest.
- `sand_worm_v1_report.json`: medições, UV, caminho do corpo (pontos, comprimento,
  espaçamento, centro de cada segmento) e o osso planejado de cada peça (`rig_bone_map`).
- `previews/{three_quarter,front,side,back,game_top}.png`: renders Cycles 1000×1000.
  `game_top` aproxima a câmera alta do jogo.
- `sand_worm_v1.glb`: export para o jogo.
  - Uma malha `Model` com skin de 35 ossos e 1 material.
  - Atlas embutido.
  - Os 4 clipes, com canais de posição, rotação e escala em todos os ossos.
- `sand_worm_import.gd`: pós-import do Godot (`Worm_Idle` em loop, o resto não).
- `previews/animations/Worm_{Idle,Attack,Burrow,Emerge}.{mp4,gif}`: prévia das animações.
- `art_source/sand_worm_v1/`: quadros das prévias e backup estático antes do rig.

## Forma

- **Pose de repouso inteira acima do solo, em pé, perto de 1 tile** (formato "J"). Uma
  coluna alta, quase vertical, se ergue como uma naja sobre o tile de origem, com a cabeça
  a ~2,8 m, a barriga voltada para a presa e as patas abertas. Só um rabo curto fica
  deitado sobre as patas atrás dela, com uma leve curva para o lado. O tamanho de
  "colossal" vem da altura e da grossura, não do comprimento.
- Pose anterior, deitada em S até o 3º tile, foi trocada a pedido do usuário. Também foi
  testado um enrolado em volta da base, descartado porque ficava confuso visto de cima.
- **9 segmentos** iguais que afinam da frente para a cauda. Cada um tem um núcleo e uma
  placa dorsal (tergito) mais larga, meio afundada no topo, o que faz cada anel ler de
  longe. Há **um par de patas por segmento** (coxa abrindo para fora e para cima, canela
  descendo até a garra preta), e nos segmentos deitados a ponta da garra toca o chão.
- **Cauda**: segmento final com dois cercos longos para trás.
- **Cabeça**: bloco preto inclinado para frente e para baixo, com:
  - placa dorsal com sutura;
  - clípeo vermelho escuro e boca com 4 dentes;
  - **forcípulas** (as presas de veneno) curvando para dentro até a ponta preta;
  - antenas âmbar com anéis;
  - **um olho âmbar de cada lado no topo**, com uma sobrancelha logo atrás, legível da
    câmera do jogo.

## Cores (lacraia *Scolopendra*)

| Parte | Cor |
| --- | --- |
| Cabeça, colar (1º segmento), base das presas | Preto levemente azulado, bordas claras |
| Corpo | Vermelho-ferrugem: faixa escura no fim de cada tergito, borda dianteira clara, linha mediana escura |
| Barriga | Creme com juntas |
| Patas, antenas, cercos | Âmbar com pontas pretas; antenas anelada |
| Presas | Vermelho-escuro até a ponta preta |

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 948 |
| Altura | 3,41 m (cabeça erguida com antenas; articulação da cabeça a 2,8 m) |
| Comprimento | da frente (presas/antenas) em y = −1,31 m até os cercos em y = +1,56 m |
| Largura | 1,78 m (patas abertas) |
| Peças editáveis | 79 |
| Densidade | 64 px/m (medido 63,999–64,002) |
| Geometria | Fechada (0 arestas non-manifold), flat |
| Pivot / frente | Origem no chão no tile lógico (sob a frente erguida); frente −Y no Blender / +Z no glTF |

O hex tem 1,73 m de lado a lado (2,0 m de ponta a ponta). O tile atacável é o da
origem. No chão o verme fica quase todo nele: só a cabeça inclinada passa um pouco para
frente e o rabo curto para trás. A lógica continua sendo 1 hex.

## Rig (35 ossos, skin rígido, hierarquia plana)

`root` e, todos filhos diretos dele:
- `head`, `jaw` (boca e dentes);
- `claw_l/r` (forcípulas) e `antenna_l/r`;
- `seg_01`…`seg_09` e `tail` (com os cercos);
- `leg_NN_l/r`: um osso por pata.

Cada pose é calculada a partir do **caminho do corpo**. O segmento i fica na coordenada
b_i (arco desde a articulação da cabeça) de algum trilho, com referencial
*rotation-minimizing*, então a corrente nunca se separa. A hierarquia é plana para a escala
de um osso não herdar nos outros. Partes a mais de ~0,3–0,7 m abaixo do chão encolhem até
escala ~0, ficando escondidas mesmo perto de água ou desnível. Os 4 clipes gravam posição,
rotação **e escala** em todos os ossos, então o crossfade fica limpo.

## Animações (24 fps)

| Clip | Frames | Duração | Loop | Movimento |
| --- | --- | --- | --- | --- |
| `Worm_Idle` | 1–73 | 3,0 s | Sim | Balanço de naja da coluna (frente/trás e lados); cabeça olhando em volta; antenas, presas e boca se mexendo; onda nas patas da coluna; patas do chão plantadas |
| `Worm_Attack` | 1–37 | 1,5 s | Não | Ergue-se para trás com boca e presas abertas, dá o bote para frente e para baixo, as presas fecham no impacto (quadro 16) e volta |
| `Worm_Burrow` | 1–49 | 2,0 s | Não | A coluna se curva num arco para frente e a cabeça mergulha na areia dentro do tile, ~0,74 m à frente do centro. O corpo escorre pelo arco atrás dela, com o rabo por último. Termina 100% escondido |
| `Worm_Emerge` | 1–49 | 2,0 s | Não | Começa 100% escondido. A cabeça irrompe de um buraco no centro do tile virada para cima, a coluna sobe e assenta (ease-out) e a cabeça baixa para a pose. A parte de trás aflora da areia em sequência, e ele ruge com as presas abertas |

Marcadores: Attack `WINDUP` 12, `IMPACT` 16, `RECOVERED` 37. Burrow `ARCHED` 14, `HIDDEN` 49.
Emerge `HIDDEN` 1, `SURFACE` 8, `ROAR` 34, `RECOVERED` 49.

O que a validação conferiu:
- o loop do Idle fecha;
- Attack começa e termina na pose de repouso, Burrow começa nela e Emerge termina nela;
- Idle e Attack nunca descem abaixo do chão (mínimo −1 mm, a base das patas);
- no Godot (`verify_sand_worm_import.gd`, PASS): 35 ossos, durações e loops corretos, poses
  finitas, escala máxima 0,02 no fim do Burrow e no começo do Emerge, e 1,0 no fim do
  Emerge.

A poeira/areia na entrada e na saída fica para o Godot (partículas no tile), se quiser.

## Reprodução via MCP

`python tools/art_pipeline/blender_mcp_client.py <script>`, em sequência:

1. `sand_worm_model.py`: geometria + UV métrica. O script se recusa a sobrescrever uma
   cena existente; prefixe `REBUILD=True` para forçar.
2. `sand_worm_paint_save.py`: pintura pixel art (sempre um datablock de imagem novo),
   report e `.blend` isolado.
3. `sand_worm_previews.py`: renders estáticos.
4. `sand_worm_animate.py`: rig + 4 clipes + validação. Use `REBAKE=True` para refazer.
5. `sand_worm_animation_previews.py`, depois `python tools/art_pipeline/encode_sand_worm_previews.py`
   (Python local, ffmpeg).
6. `sand_worm_export.py`: `.blend` e GLB, com inspeção do binário.

Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_sand_worm_import.gd`.

## Integração

Integrado em 2026-10-04 como kind `colossal_worm` (Verme Colossal) em
`MonsterDatabase.HANDMADE_MODELS`, substituindo a silhueta provisória de
`MonsterPlaceholderVisuals`. Configuração: escala 1,0, yaw 0, crossfade 0,2 s,
`Worm_Idle` / `Worm_Attack`, e `"burrow": true` preenche
`UnitData.burrow_animation_override` / `emerge_animation_override`.

- **Sem Walk**: no movimento comum ele desliza no Idle. Se um Ataque termina durante o
  movimento, a Unit cai no Idle em vez de congelar.
- **Escavar** (`MonsterAbilitySystem`), só visual, sem mudar nenhuma regra:
  - **Mergulho** (`_try_burrow`): a lógica continua tirando a Unit do mapa e escondendo
    na hora. `Unit.play_burrow_visual()` deixa no mesmo lugar uma cópia do modelo
    (`BurrowGhost`) tocando `Worm_Burrow`, que se apaga sozinha no fim. Isso só acontece
    se o jogador estava vendo o Verme.
  - **Emersão** (`_emerge`): `Unit.play_emerge_visual()` toca `Worm_Emerge` sem crossfade
    (o primeiro frame já é o corpo escondido) e, no fim, volta ao Idle com crossfade.
