# Espadachim V1 (Swordsman) — Aetherlands

Primeira evolução da linha do **Guerreiro** humano (`v2_unit_swordsman`; Guerreiro →
Espadachim → Mestre). Criado no Blender 5.2, exclusivamente pelo MCP em localhost:9876, a partir
de **uma cópia do Guerreiro**: mesmas peças, juntas e proporções. Por isso herda todas as
animações, inclusive o **Golpe Poderoso**. Está no jogo (ver "No jogo").

## Escada da linha do Guerreiro

| Tropa | Visual |
| --- | --- |
| Guerreiro | Gibão com talabarte, couro só no ombro da arma, gorro de couro, machadinha |
| **Espadachim** | **Brigantina de couro rebitada**, ombreiras nos **dois** ombros (a do braço da espada com placa de ferro), cabeça descoberta com **faixa azul**, barba, **espada** e bainha |
| Mestre (a fazer) | Espaço para malha/placas e uma arma melhor |

Um degrau acima do Guerreiro, deixando espaço para o Mestre.

## O que muda em relação ao Guerreiro

- **Peito e barriga**: brigantina de couro escuro com fileiras de rebites de latão e o fecho
  na frente (o gibão aparece nos braços e na saia).
- **Ombros**: ombreiras de couro endurecido nos dois lados; a da direita é maior e tem uma
  **placa de ferro**.
- **Cabeça**: outro homem, mais experiente: cabelo ruivo-castanho (um bloco de cabelo), uma
  **faixa azul** na testa com nó atrás e **barba curta**; o rosto é sério (boca fechada dentro
  da barba).
- **Arma**: **espada de lâmina reta** (empunhadura de couro, pomo de latão, guarda de ferro,
  lâmina de aço com sulco), apontada para a frente, na mesma pose de luta.
- **Bainha** vazia no quadril esquerdo, por fora da coxa (segue o quadril).
- **Mantém**: braçadeiras e luvas de couro, calça de lã, botas e a faixa azul no cinto.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **1,80 m de corpo**; a ponta da espada erguida chega a 2,12 m |
| Triângulos | 324 |
| Peças editáveis | 27 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Atlas | 256×256, 64 px/m, albedo + emissão (preta), nearest |

O ajuste de 1,80 m mede **só o corpo** (as peças de `05_GEAR` ficam de fora), porque a espada
erguida passa da cabeça. `verify_swordsman_import.gd` confere a caixa total, que é 2,117 m.

## Animações (prefixo `Swordsman_`: as 4 do Guerreiro + o Ataque em Arco)

| Clipe | Duração | Descrição |
| --- | --- | --- |
| `Swordsman_Idle` | 3 s, loop | Pronto para lutar |
| `Swordsman_Walk` | 1,17 s, loop | Passo leve, braços balançando |
| `Swordsman_Attack` | 1,33 s | Corte de cima (impacto no frame 15) |
| `Swordsman_PowerStrike` | 2 s | **Golpe Poderoso**: carrega a espada atrás da cabeça, salta num arco completo e crava a lâmina baixo à frente (impacto no frame 26, segurado) |
| `Swordsman_ArcAttack` | 1,67 s | **Ataque em Arco** (técnica `cleave`, até 3 inimigos adjacentes): torce o tronco para a direita com a espada nivelada apontando para trás e o **braço da espada estendido**, gira o corpo e varre a lâmina com o braço esticado em linha com a espada ~250° na horizontal, da direita para a esquerda, na altura do peito/cintura (cruza a frente no frame 19), segura o fim do movimento à esquerda e recupera |

**O Ataque em Arco vale também para as 2 evoluções seguintes** (Mestre e a unidade lendária da linha):
- Mesmo rig e mesmo `WEAPON_PART`.
- A espada é posicionada por **empunhadura + direção** (qualquer orientação, não só no plano vertical), com o fio da lâmina na frente da varredura, e o braço a segue por IK.

Na validação: nada abaixo do chão, incluindo a ponta da espada no impacto; sem falha de IK; e
o ataque, o Golpe Poderoso e o Ataque em Arco começam e terminam na pose BASE. No Godot:
**PASS**, 16 ossos, 5 clipes.

Arquivos: `swordsman_v1.glb`, `swordsman_import.gd` (Idle e Walk em loop) e
`previews/animations/Swordsman_*.{mp4,gif}`.

## Reprodução via MCP

`swordsman_model.py` (gerado a partir do `warrior_model.py`) → `swordsman_paint_save.py` →
`swordsman_previews.py` → `swordsman_animate.py` (o `warrior_animate.py` com
`WEAPON_PART='SwordGrip'`) → `swordsman_animation_previews.py` →
`python tools/art_pipeline/encode_swordsman_previews.py` → `swordsman_export.py`. Depois:
`godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_swordsman_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_unit_swordsman")` via `_apply_human_troop_model`, no lugar do KayKit
provisório:
- GLB próprio, escala 1:1 (a escala do provisório saiu) e yaw 0.
- Clipes `Swordsman_Idle/_Walk/_Attack` com **crossfade de 0,2 s**.
- **Técnicas com clipe próprio** (`UnitData.technique_animation_overrides`):
  - `Swordsman_PowerStrike` para Golpe Poderoso
  - `Swordsman_ArcAttack` para Ataque em Arco
- Ao usar uma dessas técnicas, `V2TechniqueRuntime.perform_strike` avisa a unidade
  (`begin_technique_animation`), e o combate toca o clipe dela **uma vez por uso**, virado para o
  primeiro alvo (`Unit.play_attack_visual`), mesmo quando o golpe resolve vários alvos.
- No fim do clipe, volta ao Idle com crossfade. Uma técnica sem clipe próprio toca o Attack comum.
