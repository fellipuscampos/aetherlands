# Caçador de Lendas V1 (Legend Hunter) — Aetherlands

Unidade **lendária** da linha **à distância** humana (`v2_legendary_legend_hunter`): a forma suprema
da classe, única por civilização, como o Herói da Lâmina é para a linha do Guerreiro e o Campeão
Guardião para a do Guardião. Criado no Blender 5.2, exclusivamente pelo MCP em localhost:9876, a
partir de **uma cópia do Atirador de Elite** (mesmas peças, juntas e rig do arco), com **2,00 m de
corpo**. Faz **todas as animações da linha**. Está no jogo (ver "No jogo").

## Escada da linha à distância

| Tropa | Visual |
| --- | --- |
| Arqueiro | Capuz verde pintado, gibão de couro, arco de teixo |
| Caçador | Capuz verde-escuro com borda de pele, couro com tachas e pele, arco recurvo |
| Atirador de Elite | Capuz carvão e máscara, cota de malha com peitoral de ferro liso, arco longo, **sem dourado** |
| **Caçador de Lendas** | **Pele branca de uma fera lendária** (capuz e capa), **frisos de ouro**, arco longo com pontas de ouro |

## Visual

- **Troféu**: a **pele branca de uma fera lendária**.
  - Capuz de pele branca **pintado na cabeça**, emoldurando o rosto, com um **friso fino de
    ouro**. Uma primeira versão tinha a borda dourada grossa e parecia o toucado de um faraó.
  - **Capa de pele** nas costas, com fios de pelo e a barra desfiada; a aljava fica por cima.
- **Rosto à mostra** (sem máscara): o caçador de cabelo escuro e barba.
- **Armadura**:
  - cota de malha sob **um único peitoral de ferro liso** com **borda de ouro**, sem emblema e
    sem placas separadas;
  - ombreiras e braçadeiras de ferro com só **a borda de ouro**, sem listras;
  - botas de couro escuro com **barra de pele branca**.
- **Arco longo** com **ponteiras de ouro**, **aljava com faixas douradas** e penas **brancas e
  douradas** nas flechas.
- A faixa azul do time continua no cinto.
- **Nada mágico**: nada emite luz, e o atlas de emissão é todo preto.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **2,00 m de corpo** (lendário); o arco longo chega a 2,18 m |
| Triângulos | 444 |
| Peças editáveis | 37 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`; a faca fica 1 cm fora do plano da capa) |
| Rig | 19 ossos (16 + `string_u`, `string_d`, `arrow`) |
| Atlas | 512×512, 64 px/m, albedo + emissão (preta), nearest |

## Animações (todas as da linha, prefixo `LegendHunter_`)

`LegendHunter_Idle` (3 s, loop), `LegendHunter_Walk` (1,17 s, loop), `LegendHunter_Attack` (tiro de
lado, solta no frame 27), `LegendHunter_PreciseShot` (**Disparo Preciso**, mira para cima, solta no
frame 35) e `LegendHunter_Volley` (**Saraivada**: 3 disparos rápidos para o alto em volta do alvo,
nos frames 15, 34 e 53).

As distâncias dos clipes foram feitas para 1,80 m e aqui são escaladas por S = 1,11: o caminho da
empunhadura do arco, a mão que puxa a corda, os deslocamentos do corpo e os passos. Assim as poses
mantêm as proporções. Na validação: nada abaixo do chão, sem nenhum clamp de IK, e os tiros começam
e terminam na pose BASE. No Godot (`verify_legend_hunter_import.gd`): **PASS**, 19 ossos, 5 clipes.

Arquivos: `legend_hunter_v1.glb`, `legend_hunter_import.gd` (Idle e Walk em loop) e
`previews/animations/LegendHunter_*.{mp4,gif}`.

## Reprodução via MCP

`legend_hunter_model.py` (gerado a partir do `elite_marksman_model.py`; o fit é 2,00 m de corpo) →
`legend_hunter_paint_save.py` → `legend_hunter_previews.py` → `legend_hunter_animate.py` →
`legend_hunter_animation_previews.py` → `python tools/art_pipeline/encode_legend_hunter_previews.py` →
`legend_hunter_export.py`. Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_legend_hunter_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_legendary_legend_hunter")` via `_apply_human_troop_model`, no lugar do KayKit
provisório:
- GLB próprio, escala 1:1 (a escala do provisório saiu) e yaw 0.
- Clipes `LegendHunter_Idle/_Walk/_Attack` com **crossfade de 0,2 s**.
- **Técnicas com clipe próprio** (`UnitData.technique_animation_overrides`):
  - `LegendHunter_PreciseShot` para Disparo Preciso
  - `LegendHunter_Volley` para Saraivada
- Ao usar uma dessas técnicas, `V2TechniqueRuntime.perform_strike` avisa a unidade
  (`begin_technique_animation`), e o combate toca o clipe dela **uma vez por uso**, virado para o
  primeiro alvo (`Unit.play_attack_visual`), mesmo quando o golpe resolve vários alvos.
- No fim do clipe, volta ao Idle com crossfade. Uma técnica sem clipe próprio toca o Attack comum.
