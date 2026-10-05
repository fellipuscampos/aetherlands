# Herói Corrompido V1 — Aetherlands

Monstro avançado que vai substituir a Colmeia Micótica. Criado no Blender 5.2,
exclusivamente pelo MCP em localhost:9876. Visual aprovado; rig rígido de 16 ossos e quatro
animações: **Hero_Idle, Hero_Walk, Hero_Attack e Hero_Block**. Está no jogo como
`corrupted_hero` (ver Integração).

**Escala (2026-10-04)**: o usuário achou o Herói grande demais (2,67 m, maior que o Troll).
O nó `Corrupted_Hero_V1_ROOT` tem escala **0,73** no `.blend` e no GLB, e o Herói mede
**1,95 m** em jogo (o Troll mede 2,5 m). As medidas abaixo são do modelo em escala 1,0.
`corrupted_hero_export.py` exporta com o `_ROOT` em 1,0 e grava a escala só no nó raiz do
GLB. Exportar com o `_ROOT` escalado faz o Blender embutir a escala nos vértices skinned e
escalar duas vezes.

Histórico de direção:
1. Cavaleiro preto com brilho violeta, chifres e dourado: rejeitado.
2. Cavaleiro "mountain" cinza, curvado, com manto de placas: rejeitado ("geladeira",
   amontoado de quadrados).
3. Proporções da referência com ombreiras de placas empilhadas: "bem melhor, mas ainda não
   perfeito".
4. Composição descrita pelo usuário, **um bloco por parte do corpo** como no Troll e no
   Minotauro. A armadura vem da **grossura** de cada bloco e da **pintura**.
5. **Atual**:
   - herói **velho, cansado e maltrapilho**: tronco curvado progressivamente (barriga 7°,
     peito 14°, cabeça +5°) e braços pendendo retos;
   - **maça** com cabo de madeira e **bloco quadrado de ferro** apoiado no chão;
   - rosto só com **duas faixas largas** de abertura;
   - sem joelheiras (o usuário as removeu para não bugar no andar);
   - braço esquerdo estendido segurando o escudo pela alça (antes o escudo parecia flutuar).

## Arquivos

- `corrupted_hero_v1.blend`: fonte editável. Cena `Corrupted_Hero_V1`, 28 peças, atlases
  packed.
- `corrupted_hero_v1_albedo.png` / `corrupted_hero_v1_emission.png`: atlas 512×512,
  64 px/m. A emissão está preta, reservada para um eventual detalhe de corrupção.
- `corrupted_hero_v1_report.json`: medições, UV e o osso planejado de cada peça.
- `corrupted_hero_v1.glb`: export para o jogo.
  - Uma malha `Model` com skin de 16 ossos e 1 material.
  - Albedo e emissão embutidos.
  - Os 4 clipes.
- `corrupted_hero_import.gd`: pós-import do Godot (Idle e Walk em loop, Attack e Block não).
- `previews/{three_quarter,front,side,back,game_top}.png`.
- `previews/animations/Hero_{Idle,Walk,Attack,Block}.{mp4,gif}`: prévia das animações.
- `art_source/corrupted_hero_v1/`: quadros das prévias e backup estático antes do rig.

## Forma

| Parte | Bloco | Leitura |
| --- | --- | --- |
| Cabeça | 1 cubo | Elmo pintado: duas faixas largas de abertura, crista no topo, anel de rebite nas laterais |
| Ombro | cubo encostado no peito | Liga o braço ao corpo; lâminas de ombreira e rebites pintados |
| Braço | fino | Cota de malha |
| Antebraço | grosso | Lâminas e punho claro pintados |
| Mão | média | Luva de couro |
| Peito | 1 bloco | Peitoral pintado: placa interna, nervura central e rebites |
| Barriga | mais estreita | Pano azul-ardósia |
| Cintura | 1 bloco | Cinto de couro em cima, saia de placas embaixo, fivela dourada |
| Coxa | fina | Malha |
| Canela | grossa | Greva com nervura (sem joelheira) |
| Pé | 1 bloco | Bota de placa |

- Tabardo azul-ardósia em faixas estreitas na frente e atrás.
- **Maça** na mão direita: empunhadura de couro, cabo comprido de madeira e bloco quadrado de
  ferro (borda chanfrada pintada, rebites, ferrugem) **apoiado no chão**, arrastando de
  cansaço.
- **Escudo-torre em guarda**: o braço esquerdo se estende para frente (braço descendo um pouco à
  frente, antebraço quase horizontal) e o punho fecha numa alça de couro no centro das costas
  do escudo, que fica erguido logo à frente da mão, virado para a frente-esquerda. Faixa
  heráldica azul.
- Pintura: placa cinza-pedra com manchas suaves, contorno escuro e friso claro; **desgaste**
  (sujeira, pontos de ferrugem, mossas), tabardo com **barra esfiapada** e **remendo**. Sem
  brilho.

## Especificações

| Item | Valor |
| --- | --- |
| Triângulos | 336 |
| Altura | 2,67 m (curvado) |
| Pegada | x −0,89…+0,93 m (maça e escudo), y −0,94…+0,25 m |
| Peças editáveis | 28 |
| Densidade | 64 px/m |
| Geometria | Fechada (0 arestas non-manifold), flat, nada abaixo do chão |
| Pivot / frente | Origem no chão entre os pés; frente −Y no Blender / +Z no glTF |

## Rig (16 ossos, skin rígido, hierarquia plana)

`root` e, todos filhos diretos dele:
- `hips` (cintura, fivela e tabardos);
- `chest` (peito, barriga e os **cubos dos ombros**, que andam com o peito para o braço girar
  embaixo deles sem o cubo rodar);
- `head`;
- de cada lado: `upper_arm`, `forearm`, `hand` (a maça segue `hand_r`; o escudo e a alça
  seguem `hand_l`), `thigh`, `shin` e `foot`.

As poses são calculadas por cinemática direta em volta das juntas medidas nas malhas.
As **pernas usam IK de dois ossos**, com o joelho dobrando para frente e os pés plantados ou
deslizando no chão. Uma **trava de chão** gira o pulso direito sempre que o bloco de ferro da
maça entraria no piso, então a maça fica apoiada ou arrastando. Uma pose BASE comum (quadril
3 cm abaixo, joelhos levemente dobrados) abre e fecha todos os clipes, e todos animam os
mesmos ossos, então o crossfade no Godot fica limpo.

## Animações (24 fps)

| Clip | Frames | Duração | Loop | Movimento |
| --- | --- | --- | --- | --- |
| `Hero_Idle` | 1–73 | 3,0 s | Sim | Respiração pesada e cansada; a cabeça pende e oscila; o braço do escudo cede e volta; a maça fica no chão |
| `Hero_Walk` | 1–33 | 1,33 s | Sim | Passo pesado no lugar (0,30 m/s); quadril sobe, desce e rola; o tronco gira contra as pernas; a maça vai arrastando |
| `Hero_Attack` | 1–41 | 1,67 s | Não | Ergue a maça pela frente até acima e atrás da cabeça girando o tronco, desce num golpe que bate o ferro no chão à frente (impacto no frame 22) e volta à pose cansada |
| `Hero_Block` | 1–19 | 0,75 s | Não | Bloqueio com Escudo: se encolhe atrás do escudo-torre, empurra o escudo para frente e para cima, os joelhos cedem e o corpo recua com o impacto (frame 6), e volta à pose cansada |

Marcadores do Attack: `WINDUP` 16, `IMPACT` 22, `RECOVERED` 41. Block: `IMPACT` 6, `RECOVERED` 19.

O que a validação conferiu:
- os loops do Idle e do Walk fecham;
- o Attack e o Block começam na mesma pose base do Idle e terminam onde começam;
- nada abaixo do chão em nenhum frame dos 4 clipes;
- sem falha de IK;
- no Godot (`verify_corrupted_hero_import.gd`): PASS.

## Reprodução via MCP

`python tools/art_pipeline/blender_mcp_client.py <script>`, em sequência:

1. `corrupted_hero_model.py`: geometria + UV métrica. Prefixe `REBUILD=True` para refazer.
2. `corrupted_hero_paint_save.py`: pintura (albedo + emissão), report e `.blend` isolado.
3. `corrupted_hero_previews.py`: renders estáticos.
4. `corrupted_hero_animate.py`: rig + 4 clipes + validação. Use `REBAKE=True` para refazer.
5. `corrupted_hero_animation_previews.py`, depois
   `python tools/art_pipeline/encode_corrupted_hero_previews.py` (Python local, ffmpeg).
6. `corrupted_hero_export.py`: `.blend` e GLB, com inspeção do binário.

Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_corrupted_hero_import.gd`.

## Integração

Integrado em 2026-10-04 como kind `corrupted_hero`, que **substitui a Colmeia Micótica**.
Configuração:
- `MonsterDatabase.HANDMADE_MODELS`: prefixo `Hero`, `"block": true` (liga
  `block_animation_override = Hero_Block`), escala 1,0, yaw 0, crossfade 0,2 s.
- Stats: ataque 8, defesa 6 e vida 34, iguais aos da Colmeia; **movimento 2**, como os outros
  ADVANCED móveis.
- Comportamento ADVANCED padrão, sem o teto de raio da Colmeia:
  - Despertar: territorial, só reage a quem encosta;
  - Ascensão: reage a 2 tiles e patrulha até 4;
  - Convergência (a era dele): reage a 4 e patrulha até 7.
- **Habilidade: Bloqueio com Escudo** (passiva, `MonsterAbilityData.SHIELD_BLOCK`).
  - **20%** de chance de negar todo o dano de um ataque comum recebido. O revide continua
    normal. Feitiços, habilidades e dano de ambiente não são bloqueados.
  - Rolagem determinística (`MonsterAbilitySystem.block_roll`: hash de defensor, atacante,
    turno e Vida). Não consome o RNG da ecologia, e recarregar o save não "rerola".
  - Ao bloquear: `Unit.play_block_visual` vira o Herói para o atacante e toca `Hero_Block`,
    e o feedback mostra um aro e "Bloqueou!" no tile.
- Habitat herdado da Colmeia (fértil, floresta, água), provisório. Território: "Ruínas do Herói".
- Saves antigos: `MonsterDatabase.LEGACY_KINDS` faz `mycotic_hive` carregar como `corrupted_hero`.
- A Contaminação Micótica ficou **dormente** no código, com os testes mantidos.
