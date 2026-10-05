# Guardião V1 (Guardian) — Aetherlands

Evolução do Escudeiro (`v2_unit_guardian`, linha do Guardião humano). Criado no Blender 5.2,
exclusivamente pelo MCP em localhost:9876. Está no jogo (ver "No jogo").

É **o mesmo personagem do Escudeiro**: mesmas peças, mesmas juntas e mesmas proporções
(1,80 m). Por isso herda todas as animações, incluindo a **Muralha de Escudos**, porque as
habilidades se acumulam a cada evolução.

## Escada de armadura da linha

| Tropa | Armadura |
| --- | --- |
| Escudeiro | Couro e gibão, chapéu de ferro, escudo redondo de madeira |
| **Guardião** | **Cota de malha sob uma sobreveste azul com a torre**, elmo normando com proteção de nariz, escudo redondo reforçado e pintado |
| Sentinela (a fazer) | Armadura de placas completa, elmo fechado, escudo de cavaleiro |

Uma primeira versão do Guardião saiu com aço da cabeça aos pés e o usuário apontou que
ficava "tank demais" e sem espaço para o Sentinela. Ela foi rebaixada para este passo
intermediário.

## O que muda em relação ao Escudeiro

- **Peito**: cota de malha com **sobreveste azul** por cima, com a torre prateada (símbolo
  da linha) na frente; a malha aparece nas laterais.
- **Barriga, braços e pélvis**: cota de malha (a pélvis tem cinto de couro em cima).
- **Tabardo azul** em faixas na frente e atrás, abaixo do cinto, com a torre.
- **Cabeça**: o **mesmo rosto, agora com barba rala** e bigode. **Elmo normando** de aço: a
  copa desce até a sobrancelha, cobrindo testa e laterais, com proteção de nariz.
- **Escudo**: o mesmo escudo redondo, agora **reforçado** (aro e umbo de aço) e **pintado**
  de azul com a torre.
- **Mantém do Escudeiro**: ombreiras de couro endurecido, braçadeiras de couro, calça de lã e
  botas de couro.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **1,80 m** |
| Triângulos | 360 |
| Peças editáveis | 30 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Atlas | 256×256, 64 px/m, albedo + emissão (preta), nearest |

## Animações (as mesmas do Escudeiro, prefixo `Guardian_`)

`Guardian_Idle` (3 s, loop), `Guardian_Walk` (1,17 s, loop), `Guardian_Attack` (investida de
escudo, 1,25 s), `Guardian_ShieldWall` (ativação da Muralha, 1 s) e `Guardian_ShieldWallHold`
(postura mantida, 2 s, loop). A validação passou: loops fechados, a Muralha termina na pose
do Hold, nada abaixo do chão, sem falha de IK. No Godot (`verify_guardian_import.gd`): PASS,
1,80 m, 5 clipes.

Arquivos: `guardian_v1.glb`, `guardian_import.gd` (Idle, Walk e ShieldWallHold em loop) e
`previews/animations/Guardian_*.{mp4,gif}`.

## Reprodução via MCP

1. `guardian_model.py` (gerado a partir do `squire_model.py`; `REBUILD=True` para refazer).
2. `guardian_paint_save.py` → `guardian_previews.py`.
3. `guardian_animate.py` (mesma máquina do Escudeiro) → `guardian_animation_previews.py` →
   `python tools/art_pipeline/encode_guardian_previews.py` → `guardian_export.py`.

Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_guardian_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_unit_guardian")` via `_apply_guardian_line_model` (que substitui
o KayKit provisório):
- GLB próprio, escala 1:1 (a escala 1,2 do provisório saiu), yaw 0;
- clipes `Guardian_Idle/_Walk/_Attack` com **crossfade de 0,2 s**;
- **Muralha de Escudos**: ao ativar a técnica toca `Guardian_ShieldWall` (erguer) e emenda no loop
  `Guardian_ShieldWallHold`, que substitui o Idle enquanto o efeito dura. Ao expirar, volta ao Idle
  com crossfade. No load de save com a Muralha ativa, entra direto na postura
  (`Unit._refresh_brace_visual`, chamado por `refresh_technique_marker`).
