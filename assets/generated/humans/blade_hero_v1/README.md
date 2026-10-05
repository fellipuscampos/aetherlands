# Herói da Lâmina V1 (Blade Hero) — Aetherlands

Unidade **lendária** da linha do Guerreiro humano (`v2_legendary_blade_hero`): a evolução suprema
da classe, única por civilização, como o Campeão Guardião é para a linha do Guardião. Criado no
Blender 5.2, exclusivamente pelo MCP em localhost:9876, a partir de **uma cópia do Mestre de
Armas** (mesmas peças e juntas), com **2,00 m de corpo**. Faz **todas as animações da linha**.
Está no jogo (ver "No jogo").

## Escada da linha do Guerreiro

| Tropa | Visual |
| --- | --- |
| Guerreiro | Gibão com talabarte, gorro de couro, machadinha |
| Espadachim | Brigantina rebitada, faixa azul na cabeça, barba, espada reta |
| Mestre de Armas | Aço enegrecido sobre malha, **sem dourado**, veterano grisalho, espada longa pesada |
| **Herói da Lâmina** | **As placas do Mestre enobrecidas com dourado**, capa azul num ombro, herói jovem com diadema, lâmina de guarda dourada |

## Visual

- **Armadura**: as placas enegrecidas do Mestre com **frisos de ouro** em todas as bordas
  (peitoral, ombreiras, braçadeiras, grevas), sobre a cota de malha. O peitoral é **liso, sem
  símbolo**.
- **Capa azul curta** jogada sobre o **ombro esquerdo**, descendo pelas costas desse lado, com
  barra dourada. É assimétrica, para não repetir a capa do Campeão.
- **Cabeça**: herói mais jovem, sem barba, de cabelo escuro preso num **rabo** atrás e um
  **diadema de ouro** com uma pedra azul na testa.
- **Luvas e braçadeiras lisas** (sem as listras marrons).
- **A lâmina**: lâmina de aço larga e lisa, de fios claros, sulco escuro e ponta escalonada;
  **guarda de ouro** com blocos que sobem ao longo da lâmina; ricasso; pomo de ouro com uma pedra
  azul. Bainha com boca e ponteira douradas.
- **Nada mágico**, por pedido do usuário: sem runas e sem brilho. As pedras são azuis, mas não
  emitem luz; o atlas de emissão é todo preto.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **2,00 m de corpo** (lendário; as tropas têm 1,80 m); a ponta da lâmina erguida chega a 2,51 m |
| Triângulos | 396 |
| Peças editáveis | 33 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Atlas | 512×512, 64 px/m, albedo + emissão (preta), nearest |

## Animações (todas as da linha, prefixo `BladeHero_`)

`BladeHero_Idle` (3 s, loop), `BladeHero_Walk` (1,17 s, loop), `BladeHero_Attack` (corte de cima,
1,33 s), `BladeHero_PowerStrike` (Golpe Poderoso, 2 s, impacto no frame 26) e
`BladeHero_ArcAttack` (Ataque em Arco com o braço estendido, 1,67 s, cruza a frente no frame 19).

As distâncias absolutas dos clipes foram feitas para o corpo de 1,80 m. Aqui elas são escaladas
por S = altura do corpo / 1,80 = 1,11: deslocamentos do corpo, passos e o caminho da empunhadura
do Golpe Poderoso. Assim as poses mantêm as proporções. Na validação: nada abaixo do chão, sem
falha de IK, e os golpes começam e terminam na pose BASE. No Godot
(`verify_blade_hero_import.gd`): **PASS**, 16 ossos, 5 clipes.

Arquivos: `blade_hero_v1.glb`, `blade_hero_import.gd` (Idle e Walk em loop) e
`previews/animations/BladeHero_*.{mp4,gif}`.

## Reprodução via MCP

`blade_hero_model.py` (gerado a partir do `weapon_master_model.py`; o fit é 2,00 m de corpo) →
`blade_hero_paint_save.py` → `blade_hero_previews.py` → `blade_hero_animate.py` →
`blade_hero_animation_previews.py` → `python tools/art_pipeline/encode_blade_hero_previews.py` →
`blade_hero_export.py`. Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_blade_hero_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_legendary_blade_hero")` via `_apply_human_troop_model`, no lugar do KayKit
provisório:
- GLB próprio, escala 1:1 (a escala do provisório saiu) e yaw 0.
- Clipes `BladeHero_Idle/_Walk/_Attack` com **crossfade de 0,2 s**.
- **Técnicas com clipe próprio** (`UnitData.technique_animation_overrides`):
  - `BladeHero_PowerStrike` para Golpe Poderoso
  - `BladeHero_ArcAttack` para Ataque em Arco
- Ao usar uma dessas técnicas, `V2TechniqueRuntime.perform_strike` avisa a unidade
  (`begin_technique_animation`), e o combate toca o clipe dela **uma vez por uso**, virado para o
  primeiro alvo (`Unit.play_attack_visual`), mesmo quando o golpe resolve vários alvos.
- No fim do clipe, volta ao Idle com crossfade. Uma técnica sem clipe próprio toca o Attack comum.
