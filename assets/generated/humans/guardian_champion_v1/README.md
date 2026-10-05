# Campeão Guardião V1 (Guardian Champion) — Aetherlands

Unidade **lendária** da linha do Guardião humano (`v2_legendary_guardian_champion`): única por
civilização, o tanque supremo da classe. Criado no Blender 5.2, exclusivamente pelo MCP em
localhost:9876. Está no jogo (ver "No jogo").

É o **mesmo personagem da linha** (mesmas peças e juntas do Escudeiro, Guardião e Sentinela),
escalado para **2,00 m** (o usuário achou 1,90 m pequeno), acima dos 1,95 m do Herói Corrompido. Herda todas as animações,
Muralha de Escudos inclusa.

## Escada da linha

| Tropa | Visual |
| --- | --- |
| Escudeiro | Couro e gibão, chapéu de ferro, escudo redondo de madeira |
| Guardião | Malha sob sobreveste azul com a torre, elmo normando, escudo redondo reforçado |
| Sentinela | Placas completas de aço liso, elmo fechado, escudo de cavaleiro |
| **Campeão Guardião** | **As placas do Sentinela enobrecidas**: frisos de ouro, sobreveste real, capa, crista e penacho, escudo único |

A diferença para o Sentinela é de **nobreza**, não de quantidade de aço.

## O que muda em relação ao Sentinela

- **Placas douradas**: cada peça de aço (elmo, ombreiras, braçadeiras, manoplas, grevas,
  botas) ganha uma borda interna de **ouro**.
- **Ombreiras maiores** (0,20 × 0,27 × 0,21).
- **Sobreveste real** sobre o peitoral: painel azul com borda dourada e a **torre em ouro**;
  as laterais de aço aparecem.
- **Capa azul** com dobras e **bainha dourada**, presa ao peito, até o quadril. É curta de
  propósito: conferido por trás em toda a passada do Walk, as coxas balançam embaixo dela sem
  atravessar.
- **Elmo fechado** (o elmo é o bloco da cabeça) com **crista dourada** e **penacho azul**.
- **Escudo único**: o escudo de cavaleiro maior (0,58 m de largura), com **aro de ouro**,
  rebites dourados e a torre em ouro no campo azul.
- O tabardo real azul abaixo do cinto fica na frente; nas costas está a capa.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **2,00 m** (unidade lendária; as tropas normais têm 1,80 m) |
| Triângulos | 336 |
| Peças editáveis | 28 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Atlas | 256×256, 64 px/m, albedo + emissão (preta), nearest |

## Animações (as da linha, prefixo `Champion_`)

`Champion_Idle` (3 s, loop), `Champion_Walk` (1,17 s, loop), `Champion_Attack` (investida de
escudo, 1,25 s), `Champion_ShieldWall` (ativação da Muralha, 1 s) e `Champion_ShieldWallHold`
(postura mantida, 2 s, loop). A validação passou: loops fechados, a Muralha termina na pose
do Hold, nada abaixo do chão, sem falha de IK. No Godot
(`verify_guardian_champion_import.gd`): PASS, **2,00 m**, 5 clipes.

Arquivos: `guardian_champion_v1.glb`, `guardian_champion_import.gd` (Idle, Walk e
ShieldWallHold em loop) e `previews/animations/Champion_*.{mp4,gif}`.

## Reprodução via MCP

`guardian_champion_model.py` (gerado a partir do `sentinel_model.py`; o fit é 2,00 m) →
`guardian_champion_paint_save.py` → `guardian_champion_previews.py` →
`guardian_champion_animate.py` → `guardian_champion_animation_previews.py` →
`python tools/art_pipeline/encode_guardian_champion_previews.py` →
`guardian_champion_export.py`. Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_guardian_champion_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_legendary_guardian_champion")` via `_apply_guardian_line_model` (que substitui
o KayKit provisório):
- GLB próprio, escala 1:1 (a escala 1,5 do provisório saiu), yaw 0;
- clipes `Champion_Idle/_Walk/_Attack` com **crossfade de 0,2 s**;
- **Muralha de Escudos**: ao ativar a técnica toca `Champion_ShieldWall` (erguer) e emenda no loop
  `Champion_ShieldWallHold`, que substitui o Idle enquanto o efeito dura. Ao expirar, volta ao Idle
  com crossfade. No load de save com a Muralha ativa, entra direto na postura
  (`Unit._refresh_brace_visual`, chamado por `refresh_technique_marker`).
