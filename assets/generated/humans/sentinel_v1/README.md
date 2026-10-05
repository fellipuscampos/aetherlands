# Sentinela V1 (Sentinel) — Aetherlands

Evolução do Guardião (`v2_unit_sentinel`, linha do Guardião humano). Criado no Blender 5.2,
exclusivamente pelo MCP em localhost:9876. Está no jogo (ver "No jogo").

É o **mesmo personagem do Escudeiro e do Guardião**: mesmas peças, mesmas juntas e mesmas
proporções (1,80 m). Herda todas as animações, Muralha de Escudos inclusa.

## Escada de armadura da linha

| Tropa | Armadura |
| --- | --- |
| Escudeiro | Couro e gibão, chapéu de ferro, escudo redondo de madeira |
| Guardião | Malha sob sobreveste azul com a torre, elmo normando, escudo redondo reforçado |
| **Sentinela** | **Placas completas, funcionais e sem enfeite**, elmo fechado, escudo de cavaleiro |
| Campeão Guardião (único, lendário) | Reservado: **ornamento** (frisos dourados, capa, penacho ou crista, heráldica própria, escudo único) |

A diferença entre o Sentinela e o Campeão é de **nobreza**, não de quantidade de aço. Por
isso o Sentinela é aço liso.

## O que muda em relação ao Guardião

- **Placas de aço**:
  - peitoral com nervura central e rebites;
  - ombreiras em lâminas, um pouco maiores;
  - braçadeiras;
  - **manoplas** com placas nos dedos;
  - grevas com nervura e dobra de couro;
  - botas de aço.
- **Malha nas juntas**: braço, barriga, coxa e saia sob o cinto.
- **Elmo fechado**: o **próprio elmo é o bloco da cabeça** (não há cabeça escondida dentro;
  pedido do usuário). A peça se chama `Head` para o rig compartilhado medir o pescoço nela.
  Tem faixa de fendas nos olhos, respiros dos dois lados, nervura central e rebite lateral.
  O rosto fica escondido: ele virou soldado de elite.
- **Escudo de cavaleiro** (topo largo, ponta em degraus) com o campo azul, a torre prateada e
  o aro de aço.
- O tabardo azul com a torre continua abaixo do cinto.
- **Sem gorjal**: o usuário removeu no Blender porque batia com o elmo fechado; a remoção
  está gravada no `sentinel_model.py`.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **1,80 m** |
| Triângulos | 312 |
| Peças editáveis | 26 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Atlas | 256×256, 64 px/m, albedo + emissão (preta), nearest |

## Animações (as mesmas do Escudeiro, prefixo `Sentinel_`)

`Sentinel_Idle` (3 s, loop), `Sentinel_Walk` (1,17 s, loop), `Sentinel_Attack` (investida
de escudo, 1,25 s), `Sentinel_ShieldWall` (ativação da Muralha, 1 s) e
`Sentinel_ShieldWallHold` (postura mantida, 2 s, loop). A validação passou: loops fechados,
a Muralha termina na pose do Hold, nada abaixo do chão, sem falha de IK. No Godot
(`verify_sentinel_import.gd`): PASS, 1,80 m, 5 clipes.

Arquivos: `sentinel_v1.glb`, `sentinel_import.gd` (Idle, Walk e ShieldWallHold em loop) e
`previews/animations/Sentinel_*.{mp4,gif}`.

## Reprodução via MCP

`sentinel_model.py` (gerado a partir do `guardian_model.py`) → `sentinel_paint_save.py` →
`sentinel_previews.py` → `sentinel_animate.py` → `sentinel_animation_previews.py` →
`python tools/art_pipeline/encode_sentinel_previews.py` → `sentinel_export.py`. Depois:
`godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_sentinel_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_unit_sentinel")` via `_apply_guardian_line_model` (que substitui
o KayKit provisório):
- GLB próprio, escala 1:1 (a escala 1,4 do provisório saiu), yaw 0;
- clipes `Sentinel_Idle/_Walk/_Attack` com **crossfade de 0,2 s**;
- **Muralha de Escudos**: ao ativar a técnica toca `Sentinel_ShieldWall` (erguer) e emenda no loop
  `Sentinel_ShieldWallHold`, que substitui o Idle enquanto o efeito dura. Ao expirar, volta ao Idle
  com crossfade. No load de save com a Muralha ativa, entra direto na postura
  (`Unit._refresh_brace_visual`, chamado por `refresh_technique_marker`).
