# Guerreiro V1 (Warrior) — Aetherlands

Unidade básica de **dano corpo a corpo** dos humanos (`v2_unit_warrior`, base da linha do
Guerreiro; evolui para Espadachim). Criado no Blender 5.2, exclusivamente pelo MCP em
localhost:9876, a partir de **uma cópia do Escudeiro**: mesmas peças, juntas e proporções
(1,80 m). Rig e animações prontos (Idle, Walk, Attack e o Golpe Poderoso). Está no jogo (ver "No jogo").

## Leitura de "linha de dano" (contra o Escudeiro, que é a linha do tanque)

| Parte | Escudeiro | Guerreiro |
| --- | --- | --- |
| Peito | Colete de couro laçado | **Gibão acolchoado à mostra com talabarte de couro na diagonal** e fivela |
| Ombros | Couro endurecido nos dois | **Couro só no braço da arma**; o outro ombro é de gibão |
| Pélvis | Cinto + saia de gibão | Cinto com uma **faixa azul** de time |
| Cabeça | Chapéu de ferro, cabelo castanho | **Gorro de couro costurado**, outro rapaz de **cabelo escuro** |
| Equipamento | Escudo redondo | **Machadinha de lenhador** |
| Pose | Muralha de escudos | **Pose de luta**: machadinha erguida na direita, punho esquerdo em guarda |

Ficam iguais: braçadeiras de couro, calça de lã e botas.

**Arma modesta de propósito**: a espada fica reservada para o Espadachim (a evolução). A
machadinha tem cabo de madeira com empunhadura de couro, cabeça de ferro escuro e fio claro,
grande o bastante para ler na câmera do jogo.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **1,80 m** |
| Peças editáveis | 23 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`; cabo, cabeça e fio do machado têm espessuras afastadas) |
| Atlas | 256×256, 64 px/m, albedo + emissão (preta), nearest |

Ossos: os mesmos 16 do Escudeiro. A machadinha segue `hand_r` e o gorro segue `head`.

## Animações (prefixo `Warrior_`)

| Clipe | Duração | Descrição |
| --- | --- | --- |
| `Warrior_Idle` | 3 s, loop | Pronto para lutar: passa o peso de uma perna para a outra, a machadinha balança, o punho esquerdo fica em guarda, a cabeça vigia e ele respira |
| `Warrior_Walk` | 1,17 s, loop (no lugar) | Passo leve, braços balançando ao contrário das pernas |
| `Warrior_Attack` | 1,33 s | Golpe de cima: ergue a machadinha acima da cabeça girando o tronco, avança o pé esquerdo e desce o golpe para a frente (impacto no frame 15), depois recupera |
| `Warrior_PowerStrike` | 2 s | **Golpe Poderoso** (técnica `v2_technique_power_strike`): carrega a arma atrás da cabeça com o punho esquerdo apontando o alvo, segura a tensão, salta num arco completo por cima e esmaga a arma baixo à frente com uma investida (impacto no frame 26, segurado até o 32, com tremor), depois recupera |

**O Golpe Poderoso vale para as próximas skins da linha** (Espadachim etc.):
- É de **uma mão**: o braço esquerdo fica livre, então serve mesmo se uma skin futura usar escudo. Uma versão de duas mãos foi testada e descartada, porque os braços curtos do personagem cruzavam o rosto no golpe.
- A arma é dirigida por **ponto de empunhadura + ângulo do arco**, e o braço da arma a segue por IK de dois ossos, com mistura FK/IK na entrada e na saída para começar e terminar na pose BASE.
- A direção da arma vem da geometria da peça `WEAPON_PART` (hoje `AxeHaft`). Para uma espada, basta apontar para o cabo dela.
- No impacto, uma lâmina de 0,9 m ainda fica acima do chão.

Todos os clipes começam e terminam na mesma pose BASE, então o crossfade entre eles é limpo.
A validação passou: loops fechados, o ataque começa e termina na base, nada abaixo do chão e
sem falha de IK. No Godot (`verify_warrior_import.gd`): **PASS**, 1,80 m, 16 ossos, 4 clipes.

Arquivos: `warrior_v1.glb`, `warrior_import.gd` (Idle e Walk em loop) e
`previews/animations/Warrior_*.{mp4,gif}`.

## Reprodução via MCP

`warrior_model.py` (gerado a partir do `squire_model.py`) → `warrior_paint_save.py` →
`warrior_previews.py` → `warrior_animate.py` → `warrior_animation_previews.py` →
`python tools/art_pipeline/encode_warrior_previews.py` → `warrior_export.py`. Depois:
`godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_warrior_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_unit_warrior")` via `_apply_human_troop_model`, no lugar do KayKit
provisório:
- GLB próprio, escala 1:1 (a escala do provisório saiu) e yaw 0.
- Clipes `Warrior_Idle/_Walk/_Attack` com **crossfade de 0,2 s**.
- **Técnicas com clipe próprio** (`UnitData.technique_animation_overrides`):
  - `Warrior_PowerStrike` para Golpe Poderoso
- Ao usar uma dessas técnicas, `V2TechniqueRuntime.perform_strike` avisa a unidade
  (`begin_technique_animation`), e o combate toca o clipe dela **uma vez por uso**, virado para o
  primeiro alvo (`Unit.play_attack_visual`), mesmo quando o golpe resolve vários alvos.
- No fim do clipe, volta ao Idle com crossfade. Uma técnica sem clipe próprio toca o Attack comum.
