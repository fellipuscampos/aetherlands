# Arqueiro V1 (Archer) — Aetherlands

Tropa básica da linha **à distância** humana (`v2_unit_archer`). Criado no Blender 5.2,
exclusivamente pelo MCP em localhost:9876, a partir de **uma cópia do Guerreiro**: mesmas peças,
juntas e proporções (1,80 m). Tem rig e animações: Idle, Walk, Attack à distância e o **Disparo Preciso**. Está no jogo (ver "No jogo").

## Visual

- **Capuz verde PINTADO na cabeça**: verde no topo, na nuca e nas laterais, emoldurando o rosto
  com uma borda mais escura e uma franja de cabelo aparecendo. O usuário apagou no Blender os
  blocos de capuz e gola da primeira versão e pediu o capuz desenhado.
- **Gibão de couro** com abertura laçada na frente e a **alça da aljava** na diagonal; barriga e
  ombros de gibão acolchoado (tropa leve, sem armadura).
- Cinto com a **faixa azul** do time, protetores de antebraço e luvas de couro **lisas** (sem as linhas escuras), calça de lã,
  botas.
- Outro rosto jovem, de cabelo castanho-claro.
- **Arco** feito de blocos escalonados, alinhados aos eixos e segurado em pé na mão esquerda:
  - empunhadura com couro enrolado;
  - três segmentos de madeira de teixo para cima e três para baixo, que recuam em degraus na
    direção da corda e afinam até as pontas;
  - corda fina atrás, em **duas metades** que se encontram no ponto de encaixe, para poder ser
    puxada;
  - uma **flecha encaixada** no arco, com osso próprio.
- **Aljava** de couro nas costas, à direita, com penas **vermelhas e brancas** aparecendo sobre o
  ombro direito, inclusive de frente.
- **Pose pronta**: arco à frente, à esquerda, e o braço direito (o que puxa a corda) relaxado.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **1,80 m** |
| Triângulos | 396 |
| Peças editáveis | 33 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`; os segmentos do arco se tocam ponta com ponta, sem sobreposição) |
| Atlas | 512×512, 64 px/m, albedo + emissão (preta), nearest |

## Rig: 19 ossos

São os 16 do Guerreiro mais 3 do arco:
- `string_u` e `string_d`: cada metade da corda gira na ponta do arco e **estica** ao longo do
  comprimento, formando o V até a mão que puxa;
- `arrow`: a flecha. Fica encaixada no arco em repouso, voa no disparo e se esconde com escala
  ~0 dentro da aljava enquanto uma nova é sacada.

O arco segue `hand_l`; a aljava segue o peito. Os clipes têm canais de posição, rotação **e
escala**.

## Animações

| Clipe | Duração | Descrição |
| --- | --- | --- |
| `Archer_Idle` | 3 s, loop | Pronto, com a flecha encaixada: passa o peso de uma perna para a outra e respira |
| `Archer_Walk` | 1,17 s, loop | Passo leve, braços balançando, flecha encaixada |
| `Archer_Attack` | 2 s | **Disparo à distância**, descrito abaixo |
| `Archer_PreciseShot` | 2,33 s | **Disparo Preciso** (técnica: Ataque ×1,40, +1 de alcance), descrito abaixo |

O disparo, passo a passo:
1. A mão direita pega a corda no ponto de encaixe.
2. **O corpo inteiro gira de lado**, com pés, quadril e tronco juntos e o ombro esquerdo para o
   alvo. Só a cabeça vira para mirar. Ele empurra o arco à frente e **puxa a corda até o lado do
   rosto** (puxada completa no frame 18), com o cotovelo para trás. A corda forma o V, e a linha
   da flecha passa acima do braço do arco.

   A primeira versão girava só o tronco, com quadril e pernas de frente e a cabeça voltada ao
   contrário, e o usuário achou "todo contorcido". A flecha é encaixada com o arco **perto do
   corpo**, porque, de lado, a mão direita não alcança o arco estendido; o arco só vai à frente
   durante a puxada.
3. Mira, com um leve tremor.
4. **Solta** no frame 27: a corda volta com uma pequena vibração e a flecha sai voando.
5. Pega uma flecha nova na aljava, por cima do ombro, encaixa no arco e volta à pose pronta.

**Disparo Preciso**: a versão lenta e deliberada do mesmo tiro.
- Postura mais baixa e larga, com o corpo inclinado um pouco para trás.
- O arco sobe **apontado para cima** (~14°, para o alcance maior) e a corda vem **até a orelha**
  (puxada completa no frame 22).
- Mira longa com uma respiração lenta; o tremor diminui até ele firmar.
- **Disparo mais forte** no frame 35: a corda vibra mais, a flecha sai mais rápida numa linha
  subindo, o arco dá um tranco à frente e a mão que puxa voa para trás da orelha.
- Depois, a recarga normal.

Os dois tiros saem da mesma função `shot()`, com tabelas de pose e tempo; o Attack manteve os
mesmos valores.

Os braços usam IK nos tiros, com mistura FK/IK na entrada e na saída. Na validação: loops
fechados, os dois tiros começam e terminam na pose BASE e nada fica abaixo do chão. Não houve nenhum
clamp de IK. No Godot
(`verify_archer_import.gd`): **PASS**, 19 ossos, 1,80 m, 4 clipes.

Arquivos: `archer_v1.glb`, `archer_import.gd` (Idle e Walk em loop) e
`previews/animations/Archer_*.{mp4,gif}`.

## Reprodução via MCP

`archer_model.py` (gerado a partir do `warrior_model.py`) → `archer_paint_save.py` →
`archer_previews.py` → `archer_animate.py` → `archer_animation_previews.py` →
`python tools/art_pipeline/encode_archer_previews.py` → `archer_export.py`. Depois:
`godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_archer_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_unit_archer")` via `_apply_human_troop_model`, no lugar do KayKit
provisório:
- GLB próprio, escala 1:1 (a escala do provisório saiu) e yaw 0.
- Clipes `Archer_Idle/_Walk/_Attack` com **crossfade de 0,2 s**.
- **Técnicas com clipe próprio** (`UnitData.technique_animation_overrides`):
  - `Archer_PreciseShot` para Disparo Preciso
- Ao usar uma dessas técnicas, `V2TechniqueRuntime.perform_strike` avisa a unidade
  (`begin_technique_animation`), e o combate toca o clipe dela **uma vez por uso**, virado para o
  primeiro alvo (`Unit.play_attack_visual`), mesmo quando o golpe resolve vários alvos.
- No fim do clipe, volta ao Idle com crossfade. Uma técnica sem clipe próprio toca o Attack comum.
