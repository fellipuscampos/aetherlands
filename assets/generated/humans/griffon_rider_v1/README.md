# Cavaleiro de Grifo V1 (Griffon Rider) — Aetherlands

Unidade **lendária** da linha de **cavalaria** humana (`v2_legendary_griffon_rider`): a forma
suprema da classe, como o Campeão Guardião, o Herói da Lâmina e o Caçador de Lendas são das
outras linhas. Criado no Blender 5.2, exclusivamente pelo MCP em localhost:9876. Ainda não está no
jogo.

**Sem grifo, por decisão do usuário**: ele é o **Cavaleiro Blindado enobrecido**, construído a
partir de uma cópia dele (mesmas peças e o mesmo rig de cavalo e cavaleiro), com a **montaria
inteira escalada em 2,00/1,80**. Assim o cavaleiro chega a **2,00 m**, como as outras lendárias, e
o cavalo cresce na mesma proporção.

## Visual

- **Peças lendárias próprias**, acrescentadas depois que o usuário achou a primeira versão simples
  demais ("só deixou do mesmo jeito com detalhes dourados"):
  - **capa real** azul com barra e bordas de ouro, caindo dos ombros pelas costas (sem encostar na
    patilha da sela);
  - **ombreiras em camadas**, com uma segunda placa por cima e bordas de ouro;
  - **gorjal** de aço e ouro protegendo o pescoço, entre o peitoral e o elmo;
  - **crista de ouro** no alto do elmo fechado;
  - **manoplas de aço** com punhos de ouro no lugar das luvas de couro.
- **Dourado** (permitido só nas unidades supremas):
  - armadura de placas de aço liso com **bordas de ouro**: peitoral único, sem emblema, sem
    listras e sem placas separadas;
  - **elmo fechado** pintado na cabeça, com bordas de ouro e só a fenda dos olhos;
  - **escudo** azul com **aro e banda diagonal de ouro**;
  - **flâmula azul e dourada** na lança pesada (com a guarda quadrada).
- **Cavalo branco** (crina clara, focinho cinza-rosado) com um **caparazão azul real com borda de
  ouro**, **sem placas de ferro** (regra do usuário).
- **Nada mágico**: o atlas de emissão é todo preto.

## Especificações

| Item | Valor |
| --- | --- |
| Escala | montaria inteira × 1,111 (2,00/1,80); cavaleiro de 2,00 m |
| Altura total | 3,66 m até a ponta da lança |
| Tamanho no chão | 2,40 m × 0,96 m (maior que um hex, por ser lendário) |
| Peças editáveis | 65 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Rig | 28 ossos (cavalo 12 + cavaleiro 16) |

## Animações (as da linha, prefixo `GriffonRider_`)

`GriffonRider_Idle` (3 s, loop), `GriffonRider_Walk` (galope, 0,75 s, loop), `GriffonRider_Attack`
(meio empinado e depois avanço com a lança cravada, impacto no frame 15) e `GriffonRider_Charge`
(**Investida**: chega galopando, deita a lança, freia e crava no frame 11).

As distâncias absolutas dos clipes foram feitas para a montaria normal e aqui são escaladas por
S = 1,111, medido no corpo do cavalo: pivôs do pescoço e da empinada, deslocamentos, o quique do
galope e o caminho da empunhadura da lança. Assim as poses mantêm as proporções.

Na validação: loops fechados e nada abaixo do chão. Há 3 clamps de alcance no Attack, de até 7 mm.
No Godot (`verify_griffon_rider_import.gd`): **PASS**, 28 ossos, 4 clipes, 3,66 m.

Arquivos: `griffon_rider_v1.glb`, `griffon_rider_import.gd` (Idle e Walk em loop) e
`previews/animations/GriffonRider_*.{mp4,gif}`.

## Para entrar no jogo

No `UnitDatabase`, o `v2_legendary_griffon_rider` tem `movement_profile = FLYING` e
`visual_template = "griffin"`. O visual agora é um cavalo, então ao integrar é preciso decidir se ele
continua voando. Isso é regra de jogo e cabe ao usuário decidir.

## Reprodução via MCP

`griffon_rider_model.py` (gerado a partir do `armored_cavalier_model.py`; FIT = 2,00/1,80) →
`griffon_rider_paint_save.py` → `griffon_rider_previews.py` → `griffon_rider_animate.py` →
`griffon_rider_animation_previews.py` → `python tools/art_pipeline/encode_griffon_rider_previews.py` →
`griffon_rider_export.py`. Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_griffon_rider_import.gd`.
