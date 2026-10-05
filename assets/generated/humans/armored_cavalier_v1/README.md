# Cavaleiro Blindado V1 (Armored Cavalier) — Aetherlands

Forma **Elite** convencional da linha de **cavalaria** humana (`v2_unit_armored_cavalier`), a
última evolução básica; a lendária da linha vem depois. Criado no Blender 5.2, exclusivamente pelo
MCP em localhost:9876, a partir de **uma cópia do Cavaleiro de Choque** (mesmas peças e o mesmo rig
de cavalo e cavaleiro). Por isso faz **todas as animações da linha**. Ainda não está no jogo.

**Sem dourado**: o ouro fica para a unidade lendária da classe.

## Escada da linha de cavalaria

| Tropa | Cavaleiro | Cavalo |
| --- | --- | --- |
| Cavaleiro | Gibão e couro, elmo de nasal pintado, lança | Castanho, manta azul |
| Cavaleiro de Choque | Cota de malha, elmo e capuz de malha pintados, lança pesada | Preto, caparazão azul, testeira de aço |
| **Cavaleiro Blindado** | **Armadura de placas lisa**, **elmo fechado** pintado, **escudo**, lança pesada | **Cinza rodado** com caparazão azul |

## Visual

- **Cavaleiro**:
  - armadura de placas de **aço liso**: **um peitoral único**, ombreiras grandes, braços e
    braçadeiras de placa, coxotes, grevas e escarpes;
  - só há borda escura e flancos levemente sombreados, **sem listras e sem placas separadas no
    peito** (regras do usuário);
  - **elmo fechado pintado na cabeça**, só com a fenda dos olhos (o usuário pediu para tirar os
    furinhos de respiração).
- **Escudo heater** preso por fora do antebraço esquerdo, azul com aro de aço e **banda branca na
  diagonal**. A mão esquerda continua segurando as rédeas.
- **Lança pesada** com a guarda quadrada (vamplate) e a flâmula azul.
- **Cavalo**:
  - **cinza rodado**, com o caparazão azul nos flancos;
  - **sem placas de aço**: crinet, testeira e peitoral foram removidos porque o usuário achou
    feio.
- **Mantém**: as proporções do cavalo, a cabeça de um retângulo só com a cara pintada e as
  rédeas por fora.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | cabeça do cavaleiro a 2,31 m; ponta da lança pesada a 3,30 m (escala real) |
| Tamanho no chão | 2,16 m × 0,86 m |
| Peças editáveis | 60 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Rig | 28 ossos (cavalo 12 + cavaleiro 16); o escudo segue o antebraço esquerdo |

## Animações (as da linha, prefixo `ArmoredCavalier_`)

`ArmoredCavalier_Idle` (3 s, loop), `ArmoredCavalier_Walk` (galope, 0,75 s, loop),
`ArmoredCavalier_Attack` (meio empinado e depois avanço com a lança cravada, impacto no frame 15) e
`ArmoredCavalier_Charge` (**Investida**: chega galopando, deita a lança, freia e crava no frame 11).

Na validação: loops fechados e nada abaixo do chão. Há 2 clamps de alcance no Attack, herdados da
linha. No Godot (`verify_armored_cavalier_import.gd`): **PASS**, 28 ossos, 4 clipes.

Arquivos: `armored_cavalier_v1.glb`, `armored_cavalier_import.gd` (Idle e Walk em loop) e
`previews/animations/ArmoredCavalier_*.{mp4,gif}`.

## Reprodução via MCP

`armored_cavalier_model.py` (gerado a partir do `shock_cavalier_model.py`) →
`armored_cavalier_paint_save.py` → `armored_cavalier_previews.py` → `armored_cavalier_animate.py` →
`armored_cavalier_animation_previews.py` → `python tools/art_pipeline/encode_armored_cavalier_previews.py` →
`armored_cavalier_export.py`. Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_armored_cavalier_import.gd`.

Atenção: para repintar um modelo que já tem rig, rode a cadeia inteira (modelo com REBUILD →
pintura → prévias → animação → exportação). O script de pintura exige o modelo sem rig.
