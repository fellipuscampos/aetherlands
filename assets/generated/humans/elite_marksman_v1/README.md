# Atirador de Elite V1 (Elite Marksman) — Aetherlands

Última evolução **básica** da linha **à distância** humana (`v2_unit_elite_marksman`; Arqueiro →
Caçador → Atirador de Elite; o herói da linha vem depois). Criado no Blender 5.2, exclusivamente
pelo MCP em localhost:9876, a partir de **uma cópia do Caçador**: mesmas peças, juntas, rig do
arco e proporções. Por isso faz **todas as animações da linha**. Está no jogo (ver "No jogo").

## Escada da linha à distância

| Tropa | Visual |
| --- | --- |
| Arqueiro | Capuz verde pintado, gibão de couro, arco de teixo |
| Caçador | Capuz verde-escuro com borda de pele, barba, couro com tachas e pele, arco recurvo com chifre |
| **Atirador de Elite** | **Capuz carvão e máscara de pano** pintados, **cota de malha sob um peitoral de ferro liso**, **arco longo** |

**Sem dourado**: o ouro fica reservado para o herói da classe.

## Visual

- **Cabeça (pintada, nunca em blocos)**: capuz cor de carvão com borda de couro escuro e uma
  **máscara de pano escuro** cobrindo nariz, boca e queixo; só os olhos aparecem.
- **Cota de malha** no peito, na barriga, nos braços e na saia (com o cinto e a faixa azul), sob
  **um único peitoral de ferro liso** na frente e nas costas; a alça da aljava passa por cima.
- **Ombreiras e braçadeiras de ferro lisas**, sem rebites nem listras.
- **Botas de couro escuro lisas.**
- Revisão do usuário: a primeira versão era só couro, com duas plaquinhas no peito que pareciam
  um sutiã, listras brancas nas braçadeiras e uma placa cinza na bota. A tropa básica do topo usa
  malha e ferro leve.
- **Arco longo**: alto e reto, com membros mais longos e **ponteiras de ferro** (no lugar do
  chifre do recurvo).
- Flechas com penas **pretas e brancas**, aljava, faca atrás do cinto e a faixa azul do time.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | **1,80 m de corpo**; o arco longo chega a 1,96 m (o ajuste mede só o corpo) |
| Triângulos | 432 |
| Peças editáveis | 36 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Rig | 19 ossos (16 + `string_u`, `string_d`, `arrow`) |
| Atlas | 512×512, 64 px/m, albedo + emissão (preta), nearest |

## Animações (todas as da linha, prefixo `EliteMarksman_`)

| Clipe | Duração | Descrição |
| --- | --- | --- |
| `EliteMarksman_Idle` | 3 s, loop | Pronto, com a flecha encaixada |
| `EliteMarksman_Walk` | 1,17 s, loop | Passo leve |
| `EliteMarksman_Attack` | 2 s | Tiro de lado, solta no frame 27 e recarrega |
| `EliteMarksman_PreciseShot` | 2,33 s | **Disparo Preciso**: mira para cima, corda até a orelha, solta no frame 35 |
| `EliteMarksman_Volley` | 2,88 s | **Saraivada**: 3 disparos rápidos para o alto, num leque estreito em volta do alvo (frames 15, 34 e 53) |

Na validação: nada abaixo do chão (a ponta do arco longo inclusive), sem nenhum clamp de IK, e
todos os tiros começam e terminam na pose BASE. No Godot (`verify_elite_marksman_import.gd`):
**PASS**, 19 ossos, 5 clipes.

Arquivos: `elite_marksman_v1.glb`, `elite_marksman_import.gd` (Idle e Walk em loop) e
`previews/animations/EliteMarksman_*.{mp4,gif}`.

## Reprodução via MCP

`elite_marksman_model.py` (gerado a partir do `hunter_model.py`) → `elite_marksman_paint_save.py` →
`elite_marksman_previews.py` → `elite_marksman_animate.py` → `elite_marksman_animation_previews.py` →
`python tools/art_pipeline/encode_elite_marksman_previews.py` → `elite_marksman_export.py`. Depois:
`godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_elite_marksman_import.gd`.

## No jogo (2026-10-04)

Integrado em `UnitDatabase.create_unit("v2_unit_elite_marksman")` via `_apply_human_troop_model`, no lugar do KayKit
provisório:
- GLB próprio, escala 1:1 (a escala do provisório saiu) e yaw 0.
- Clipes `EliteMarksman_Idle/_Walk/_Attack` com **crossfade de 0,2 s**.
- **Técnicas com clipe próprio** (`UnitData.technique_animation_overrides`):
  - `EliteMarksman_PreciseShot` para Disparo Preciso
  - `EliteMarksman_Volley` para Saraivada
- Ao usar uma dessas técnicas, `V2TechniqueRuntime.perform_strike` avisa a unidade
  (`begin_technique_animation`), e o combate toca o clipe dela **uma vez por uso**, virado para o
  primeiro alvo (`Unit.play_attack_visual`), mesmo quando o golpe resolve vários alvos.
- No fim do clipe, volta ao Idle com crossfade. Uma técnica sem clipe próprio toca o Attack comum.
