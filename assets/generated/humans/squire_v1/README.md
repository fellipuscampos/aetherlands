# Escudeiro V1 (Squire) — Aetherlands

Primeira tropa militar humana (`v2_unit_shieldbearer`, base da linha do Guardião). Criado no
Blender 5.2, exclusivamente pelo MCP em localhost:9876. Rig rígido de 16 ossos e cinco
animações: **Squire_Idle, Squire_Walk, Squire_Attack** (investida de escudo),
**Squire_ShieldWall** e **Squire_ShieldWallHold** (técnica Muralha de Escudos). Ainda não está
no jogo; o Escudeiro segue com o Knight provisório do KayKit.

**Base da linha do Guardião humano**: as próximas tropas da linha (Guardião, Sentinela...)
serão versões modificadas deste mesmo personagem.

Abre a série de tropas humanas. Todas as tropas humanas seguem a composição aprovada do
Herói Corrompido e medem **1,80 m**. A classe muda a pose e o equipamento.

## Revisão 1 (pedido do usuário)

- **Encaixe limpo, sem pisca-pisca**: os blocos agora ficam **empilhados**, só encostando
  face com face, em vez de enterrados uns nos outros. Nenhuma peça tem face visível no mesmo
  plano que outra. O pisca-pisca era z-fighting: o topo do ombro estava a 5 mm do topo do
  peito, a lateral da coxa coincidia com a da pélvis e as tábuas cruzadas do escudo tinham a
  mesma espessura. O `squire_model.py` roda `check_coplanar()` e reporta
  `coplanar_overlaps`, que precisa sair `[]`.
- **Canela mais grossa que a coxa**: a canela é cano de bota (0,16 × 0,18 m) e a coxa é a
  calça (0,13 × 0,15 m).
- **Rosto simétrico e sério**: colunas espelhadas em volta do centro, sobrancelhas retas,
  olhos escuros estreitos, sombra de nariz centralizada e boca em linha única. O primeiro
  rosto saiu torto.

- **Pernas retas** (ajuste do usuário no Blender): canela e pé alinhados embaixo da coxa
  de cada perna; só sobra o pequeno recuo de base entre as duas pernas. Está gravado no
  `squire_model.py`.

## Composição (um bloco por parte do corpo)

| Parte | Bloco | Leitura |
| --- | --- | --- |
| Cabeça | 1 cubo | Rosto jovem (olhos, sobrancelhas, nariz, boca), cabelo na nuca e nas laterais |
| Chapéu de ferro | aba + copa + cúpula em degraus | Assentado na cabeça, aba na altura da testa |
| Ombro | cubo encostado no peito | Couro endurecido em lâminas, com rebites |
| Braço | fino | Manga do gibão acolchoado (costura em losango) |
| Antebraço | grosso | Braçadeira de couro com duas tiras e fivelas de latão |
| Mão | média | Luva de couro |
| Peito | 1 bloco | Colete de couro com abertura laçada sobre o gibão, rebites nas bordas |
| Barriga | mais estreita | Gibão acolchoado |
| Pélvis | 1 bloco | Cinto de couro em cima, saia de gibão em painéis embaixo, fivela de latão |
| Coxa | fina (0,13 × 0,15) | Calça de lã |
| Canela | grossa (0,16 × 0,18) | Cano da bota de couro, dobra e duas tiras |
| Pé | 1 bloco | Bota de couro com sola escura |

- **Equipamento**: só o **escudo redondo de madeira**, com tábuas, aro de ferro, pregos,
  umbo de ferro e uma **faixa azul** no centro (cor de time provisória). O redondo é feito
  com três blocos cruzados em degraus, como pede o estilo voxel.
- **Pose de muralha de escudos**: os dois antebraços vão para frente; o punho esquerdo segura
  a alça no centro das costas do escudo e a mão direita firma a borda. Pé esquerdo à frente.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **1,80 m** (o script ajusta a escala final para isso) |
| Triângulos | 324 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Peças editáveis | 27 |
| Atlas | 256×256, 64 px/m, albedo + emissão (preta), nearest |
| Pegada | x −0,35…+0,39 m, y −0,53…+0,18 m |
| Pivot / frente | Origem no chão entre os pés; frente −Y no Blender / +Z no glTF |

Ossos planejados (`obj['rig_bone']`): `hips`, `chest`, `head` (inclui o chapéu), e de cada
lado `upper_arm` (inclui o ombro), `forearm`, `hand`, `thigh`, `shin` e `foot`. O escudo e a
alça seguem `hand_l`.

## Rig e animações (24 fps)

Mesma máquina do Herói Corrompido (`squire_animate.py`):
- rig plano de 16 ossos (`root`, `hips`, `chest`, `head`, e de cada lado `upper_arm`,
  `forearm`, `hand`, `thigh`, `shin`, `foot`), skin rígido;
- os cubos dos ombros andam com o peito;
- pernas por IK de dois ossos, com os pés plantados ou deslizando;
- uma pose BASE comum (quadril 2 cm abaixo) abre e fecha todos os clipes, que animam os
  mesmos ossos, então o crossfade fica limpo.

| Clip | Frames | Duração | Loop | Movimento |
| --- | --- | --- | --- | --- |
| `Squire_Idle` | 1–73 | 3,0 s | Sim | Guarda atenta atrás do escudo: respiração, troca de peso de uma perna para a outra, cabeça vigiando de um lado para o outro, escudo balançando de leve |
| `Squire_Walk` | 1–29 | 1,17 s | Sim | Passo mais leve e rápido que o do Herói (0,29 m/s), escudo erguido à frente, quadril sobe e desce, pequeno giro do tronco |
| `Squire_Attack` | 1–31 | 1,25 s | Não | **Investida de escudo**: recolhe o escudo e o corpo, dá um passo à frente com o pé esquerdo e empurra o escudo com os dois braços (impacto no frame 13), volta à guarda |
| `Squire_ShieldWall` | 1–25 | 1,0 s | Não | **Ativação da Muralha de Escudos**: firma a base (pé esquerdo à frente, direito atrás), agacha e ergue o escudo até a altura do rosto com os dois braços; o escudo assenta com um tranco (frame 12) e ele fica olhando por cima da borda. O último frame é o primeiro do Hold |
| `Squire_ShieldWallHold` | 1–49 | 2,0 s | Sim | Postura mantida enquanto o bônus de defesa dura: agachado atrás do escudo erguido, respiração tensa, leve tremor no escudo |

Marcadores do Attack: `WINDUP` 7, `IMPACT` 13, `RECOVERED` 31. ShieldWall: `SHIELD_UP` 12, `BRACED` 25.

O que a validação conferiu:
- os loops fecham;
- o Attack começa na base do Idle e termina onde começa;
- o ShieldWall começa na base do Idle e termina **exatamente** na pose do frame 1 do Hold, e o Hold fecha o loop;
- nada abaixo do chão;
- sem falha de IK;
- no Godot (`verify_squire_import.gd`): PASS, com 16 ossos, **1,80 m**, 5 clipes e loops corretos.

Arquivos: `squire_v1.glb` (malha skinned + 5 clipes + atlas embutido), `squire_import.gd`
(Idle, Walk e ShieldWallHold em loop) e
`previews/animations/Squire_{Idle,Walk,Attack,ShieldWall,ShieldWallHold}.{mp4,gif}`.

No jogo (quando integrar), a técnica `v2_technique_shield_wall` (+35% de defesa própria,
+15% nos adjacentes, recarga de 3) deve tocar `Squire_ShieldWall` ao ativar e manter
`Squire_ShieldWallHold` no lugar do Idle enquanto o efeito durar; ao expirar, o crossfade
normal leva de volta ao Idle.

## Reprodução via MCP

1. `squire_model.py` (prefixe `REBUILD=True` para refazer).
2. `squire_paint_save.py`: pintura, report e `.blend` isolado.
3. `squire_previews.py`.
4. `squire_animate.py`: rig + 5 clipes + validação. Use `REBAKE=True` para refazer.
5. `squire_animation_previews.py`, depois `python tools/art_pipeline/encode_squire_previews.py`.
6. `squire_export.py`: `.blend` e GLB.

Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_squire_import.gd`.

A faixa azul é a cor de time provisória. Ainda não existe máscara de cor por civilização.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_unit_shieldbearer")` via `_apply_guardian_line_model` (que substitui
o KayKit provisório):
- GLB próprio, escala 1:1 (a escala 1,0 do provisório saiu), yaw 0;
- clipes `Squire_Idle/_Walk/_Attack` com **crossfade de 0,2 s**;
- **Muralha de Escudos**: ao ativar a técnica toca `Squire_ShieldWall` (erguer) e emenda no loop
  `Squire_ShieldWallHold`, que substitui o Idle enquanto o efeito dura. Ao expirar, volta ao Idle
  com crossfade. No load de save com a Muralha ativa, entra direto na postura
  (`Unit._refresh_brace_visual`, chamado por `refresh_technique_marker`).
