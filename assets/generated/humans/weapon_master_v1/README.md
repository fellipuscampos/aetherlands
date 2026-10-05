# Mestre de Armas V1 (Weapon Master) — Aetherlands

Última evolução **básica** da linha do Guerreiro humano (`v2_unit_weapon_master`, a forma Elite
convencional: Guerreiro → Espadachim → Mestre de Armas). Criado no Blender 5.2, exclusivamente
pelo MCP em localhost:9876, a partir de **uma cópia do Espadachim**: mesmas peças, juntas e
proporções. Por isso faz **todas as animações da linha**. Está no jogo (ver "No jogo").

## Escada da linha do Guerreiro

| Tropa | Visual |
| --- | --- |
| Guerreiro | Gibão com talabarte, gorro de couro, machadinha |
| Espadachim | Brigantina de couro rebitada, faixa azul na cabeça, barba, espada reta |
| **Mestre de Armas** | **Aço enegrecido sobre cota de malha**, calota de aço, veterano grisalho com cicatriz, **espada longa pesada**, bainha e adaga |
| Unidade suprema da classe (a fazer) | Fica com o **dourado** |

**Sem dourado, por pedido do usuário**: o ouro fica reservado para a unidade suprema da
classe. Todo detalhe que seria de latão aqui é de ferro (rebites, fivela, adaga).

## Visual

- **Armadura**: peitoral de aço enegrecido com nervura central e rebites; ombreiras em lâminas
  sobrepostas nos dois ombros (a da espada é maior); braçadeiras com tiras de couro; grevas com
  borda de couro. Todas com um bisel claro nas bordas.
- **Cota de malha** na barriga, nos braços e na saia, com o cinto e a faixa azul do time.
- **Cabeça**: calota de aço com faixa rebitada na testa; veterano de cabelo e barba
  grisalhos, com uma **cicatriz** sobre o olho esquerdo.
- **Espada longa pesada**: lâmina larga e grossa (10 × 3 cm), núcleo escuro com fios
  claros e sulco central, e ponta escalonada. Tem ainda um ricasso com marca de ferreiro, uma
  guarda pesada com blocos de quillon nas pontas, empunhadura longa de couro e um pomo grande
  com tampa. Mede cerca de 1 m a partir da empunhadura.
- **Bainha longa** no quadril esquerdo e **adaga embainhada** atrás do cinto.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **1,80 m de corpo**; a ponta da espada erguida chega a 2,25 m |
| Triângulos | 372 |
| Peças editáveis | 31 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`; ricasso, lâmina e ponta têm espessuras afastadas ≥ 8 mm) |
| Atlas | 256×256, 64 px/m, albedo + emissão (preta), nearest |

## Animações (todas as da linha, prefixo `WeaponMaster_`)

| Clipe | Duração | Descrição |
| --- | --- | --- |
| `WeaponMaster_Idle` | 3 s, loop | Pronto para lutar |
| `WeaponMaster_Walk` | 1,17 s, loop | Passo leve |
| `WeaponMaster_Attack` | 1,33 s | Corte de cima (impacto no frame 15) |
| `WeaponMaster_PowerStrike` | 2 s | Golpe Poderoso (impacto no frame 26) |
| `WeaponMaster_ArcAttack` | 1,67 s | Ataque em Arco, braço estendido (cruza a frente no frame 19) |

A espada longa é mais comprida, então no impacto do Golpe Poderoso a lâmina desce a 130° (no
Espadachim são 135°) para a ponta não entrar no chão. Na validação: nada abaixo do chão, sem
falha de IK, e todos os golpes começam e terminam na pose BASE. No Godot
(`verify_weapon_master_import.gd`): **PASS**, 16 ossos, 5 clipes.

Arquivos: `weapon_master_v1.glb`, `weapon_master_import.gd` (Idle e Walk em loop) e
`previews/animations/WeaponMaster_*.{mp4,gif}`.

## Reprodução via MCP

`weapon_master_model.py` (gerado a partir do `swordsman_model.py`) → `weapon_master_paint_save.py` →
`weapon_master_previews.py` → `weapon_master_animate.py` → `weapon_master_animation_previews.py` →
`python tools/art_pipeline/encode_weapon_master_previews.py` → `weapon_master_export.py`. Depois:
`godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_weapon_master_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_unit_weapon_master")` via `_apply_human_troop_model`, no lugar do KayKit
provisório:
- GLB próprio, escala 1:1 (a escala do provisório saiu) e yaw 0.
- Clipes `WeaponMaster_Idle/_Walk/_Attack` com **crossfade de 0,2 s**.
- **Técnicas com clipe próprio** (`UnitData.technique_animation_overrides`):
  - `WeaponMaster_PowerStrike` para Golpe Poderoso
  - `WeaponMaster_ArcAttack` para Ataque em Arco
- Ao usar uma dessas técnicas, `V2TechniqueRuntime.perform_strike` avisa a unidade
  (`begin_technique_animation`), e o combate toca o clipe dela **uma vez por uso**, virado para o
  primeiro alvo (`Unit.play_attack_visual`), mesmo quando o golpe resolve vários alvos.
- No fim do clipe, volta ao Idle com crossfade. Uma técnica sem clipe próprio toca o Attack comum.
