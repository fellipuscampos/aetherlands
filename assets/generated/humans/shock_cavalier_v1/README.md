# Cavaleiro de Choque V1 (Shock Cavalier) — Aetherlands

Primeira evolução da linha de **cavalaria** humana (`v2_unit_shock_cavalier`): a especialização
mais agressiva do Cavaleiro. Criado no Blender 5.2, exclusivamente pelo MCP em localhost:9876, a
partir de **uma cópia do Cavaleiro**: mesmas peças, o mesmo cavalo e o mesmo rig de cavaleiro.
Por isso faz **todas as animações dele**, inclusive a **Investida**. Ainda não está no jogo.

## O que muda em relação ao Cavaleiro (um degrau acima, mais pesado)

| Parte | Cavaleiro | Cavaleiro de Choque |
| --- | --- | --- |
| Corpo do cavaleiro | Gibão e colete de couro | **Cota de malha** (peito com a alça de couro do apoio da lança, barriga e braços) |
| Cabeça (pintada) | Elmo de nasal | Elmo de ferro com **capuz de malha** emoldurando o rosto e cobrindo o pescoço |
| Lança | Haste leve | **Lança pesada**: haste mais grossa, ponta maior e **guarda quadrada** (vamplate) acima da mão |
| Cavalo | Castanho | **Preto** (lista branca e meias brancas mantidas) |
| Arreios | Manta azul sob a sela | **Caparazão azul** cobrindo os dois flancos |
| Cabeça do cavalo | Lista branca | **Testeira de aço** (chanfron) pintada sobre a cara |

Ficam iguais:
- as proporções do cavalo e a cabeça de um retângulo só com a cara pintada;
- as rédeas por fora da cabeça e do pescoço;
- as ombreiras de couro, a flâmula azul e a faixa azul no cinto.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | cabeça do cavaleiro a 2,31 m; ponta da lança pesada a 3,30 m (escala real) |
| Tamanho no chão | 2,16 m × 0,86 m |
| Peças editáveis | 59 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Rig | 28 ossos (cavalo 12 + cavaleiro 16), como o Cavaleiro |

## Animações (as do Cavaleiro, prefixo `ShockCavalier_`)

`ShockCavalier_Idle` (3 s, loop), `ShockCavalier_Walk` (galope, 0,75 s, loop),
`ShockCavalier_Attack` (meio empinado e depois avanço com a lança cravada, impacto no frame 15) e
`ShockCavalier_Charge` (**Investida**: chega galopando, deita a lança, freia e crava no frame 11).

Na validação: loops fechados e nada abaixo do chão. Há 2 clamps de alcance no Attack, herdados do
Cavaleiro. No Godot (`verify_shock_cavalier_import.gd`): **PASS**, 28 ossos, 4 clipes.

Arquivos: `shock_cavalier_v1.glb`, `shock_cavalier_import.gd` (Idle e Walk em loop) e
`previews/animations/ShockCavalier_*.{mp4,gif}`.

## Reprodução via MCP

`shock_cavalier_model.py` (gerado a partir do `cavalier_model.py`) → `shock_cavalier_paint_save.py` →
`shock_cavalier_previews.py` → `shock_cavalier_animate.py` → `shock_cavalier_animation_previews.py` →
`python tools/art_pipeline/encode_shock_cavalier_previews.py` → `shock_cavalier_export.py`. Depois:
`godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_shock_cavalier_import.gd`.
