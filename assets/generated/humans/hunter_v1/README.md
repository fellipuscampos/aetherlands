# Caçador V1 (Hunter) — Aetherlands

Primeira evolução da linha **à distância** humana (`v2_unit_hunter`; Arqueiro → Caçador → ...).
Criado no Blender 5.2, exclusivamente pelo MCP em localhost:9876, a partir de **uma cópia do
Arqueiro**: mesmas peças, juntas, rig do arco e proporções (1,80 m). Por isso herda todas as
animações dele, inclusive o **Disparo Preciso**, e ganha a **Saraivada**. Está no jogo (ver "No jogo").

## O que muda em relação ao Arqueiro (um degrau acima: caçador da floresta)

| Parte | Arqueiro | Caçador |
| --- | --- | --- |
| Capuz (pintado na cabeça) | Verde | **Verde-escuro com borda de pele** em volta do rosto |
| Rosto | Jovem, cabelo castanho-claro | **Mais experiente**, cabelo escuro e **barba curta** |
| Peito | Gibão de couro laçado | **Couro escuro com tachas**, **gola de pele** desgrenhada e a alça da aljava |
| Barriga | Gibão acolchoado | Couro escuro com tiras |
| Ombros | Pano acolchoado | **Ombreiras de couro com pele por cima** |
| Botas | Couro | Couro com **barra de pele** |
| Arco | Teixo claro | **Arco recurvo escuro** com **pontas de chifre** curvando para a frente |
| Flechas | Penas vermelhas e brancas | Penas **listradas de marrom e branco** |
| Extra | — | **Faca de caça** embainhada atrás do cinto |

Ficam iguais: faixa azul do time no cinto, protetores de antebraço, luvas lisas, calça e a
aljava.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **1,80 m** |
| Triângulos | 432 |
| Peças editáveis | 36 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Rig | 19 ossos (16 + `string_u`, `string_d`, `arrow`), como o Arqueiro |
| Atlas | 512×512, 64 px/m, albedo + emissão (preta), nearest |

## Animações (as do Arqueiro + a Saraivada, prefixo `Hunter_`)

| Clipe | Duração | Descrição |
| --- | --- | --- |
| `Hunter_Idle` | 3 s, loop | Pronto, com a flecha encaixada |
| `Hunter_Walk` | 1,17 s, loop | Passo leve, com a flecha encaixada |
| `Hunter_Attack` | 2 s | Tiro de lado: puxa a corda até o rosto e solta no frame 27; depois recarrega da aljava |
| `Hunter_PreciseShot` | 2,33 s | **Disparo Preciso**: mira para cima, puxa a corda até a orelha, mira longa e solta mais forte no frame 35 |
| `Hunter_Volley` | 2,88 s | **Saraivada**, descrita abaixo |

**Saraivada** (técnica: o alvo principal e os inimigos a 1 tile em volta dele, no máximo 3,
cada um com 0,70× o Ataque):
- **Três disparos rápidos apontados para o alto** (~17°), para as flechas choverem sobre o
  alvo e os tiles ao redor dele.
- Leque estreito: o primeiro sai ~9° para a esquerda (frame 15), o segundo no centro (34) e o
  terceiro ~9° para a direita (53).
- Entre os disparos, ele saca uma flecha da aljava e encaixa rápido. No fim, recarrega e volta à
  pose pronta.
- Os pés ficam de lado e plantados; só o tronco varre ±9°, então o corpo não torce.
- Feita pela função `volley()` em `hunter_animate.py`, que as próximas evoluções da linha herdam.

Na validação: nada abaixo do chão e loops fechados. Houve um único clamp de IK, de 0,1 mm. No
Godot (`verify_hunter_import.gd`): **PASS**, 19 ossos, 1,80 m, 5 clipes.

Arquivos: `hunter_v1.glb`, `hunter_import.gd` (Idle e Walk em loop) e
`previews/animations/Hunter_*.{mp4,gif}`.

## Reprodução via MCP

`hunter_model.py` (gerado a partir do `archer_model.py`) → `hunter_paint_save.py` →
`hunter_previews.py` → `hunter_animate.py` (o `archer_animate.py` com os nomes `Hunter_`) →
`hunter_animation_previews.py` → `python tools/art_pipeline/encode_hunter_previews.py` →
`hunter_export.py`. Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_hunter_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_unit_hunter")` via `_apply_human_troop_model`, no lugar do KayKit
provisório:
- GLB próprio, escala 1:1 (a escala do provisório saiu) e yaw 0.
- Clipes `Hunter_Idle/_Walk/_Attack` com **crossfade de 0,2 s**.
- **Técnicas com clipe próprio** (`UnitData.technique_animation_overrides`):
  - `Hunter_PreciseShot` para Disparo Preciso
  - `Hunter_Volley` para Saraivada
- Ao usar uma dessas técnicas, `V2TechniqueRuntime.perform_strike` avisa a unidade
  (`begin_technique_animation`), e o combate toca o clipe dela **uma vez por uso**, virado para o
  primeiro alvo (`Unit.play_attack_visual`), mesmo quando o golpe resolve vários alvos.
- No fim do clipe, volta ao Idle com crossfade. Uma técnica sem clipe próprio toca o Attack comum.
