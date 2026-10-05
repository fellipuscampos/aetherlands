# Cavaleiro V1 (Cavalier) — Aetherlands

Tropa básica da linha de **cavalaria** humana (`v2_unit_cavalier`): um cavaleiro **montado num
cavalo**. Criado no Blender 5.2, exclusivamente pelo MCP em localhost:9876. Tem rig e animações
(Idle, Walk = galope, Attack = carga de lança, Charge = Investida). Ainda não está no jogo: o `v2_unit_cavalier` segue com
o corpo procedural "cavalry" do V1.

## Cavalo (construção de mob do Minecraft)

Poucos blocos grandes, alinhados aos eixos e espelhados; o detalhe fica no pixel art.
- **Corpo** (barril) e, na frente, **pescoço e cabeça num grupo inclinado 32° para a frente**
  (referência do usuário: o cavalo do Minecraft):
  - **pescoço grosso** com a **crina** num bloco elevado nas costas, subindo até a nuca;
  - o pescoço entra numa **cabeça de UM retângulo só**, longo, que fica EM CIMA dele, da nuca
    (alinhada à crina, com as **orelhas** no topo) até o nariz;
  - **a cara é pintada nesse retângulo**: nariz escuro com narinas na ponta, linha da boca, olho,
    lista branca e cabresto;
  - as **argolas do freio** ficam nas laterais da cabeça, perto da boca.
- Histórico de revisões do usuário:
  1. pescoço reto e cabeça chata: "tenebroso" (ele pediu para manter as proporções e as pernas
     longas);
  2. cabeça fina colada na FRENTE do pescoço, que subia por trás dela: "sem cérebro";
  3. focinho num bloco separado, como um bico: "cavalo não tem focinho assim; a cara é um grande
     retângulo".
- **Cauda** pendurada atrás.
- **Quatro pernas** em três blocos cada: coxa, canela e casco. Cada bloco tem um tamanho
  diferente para não haver faces coplanares, e há ossos planejados por coxa e por canela para o
  galope.
- **Pintura**:
  - pelagem castanha com pintas sutis e barriga mais clara;
  - **crina e cauda escuras**;
  - **lista branca** no topo da cabeça;
  - **focinho escuro** com narinas;
  - olho com brilho;
  - cabresto de couro (focinheira, testeira e faceira);
  - **meias brancas** nas patas da frente e cascos escuros.
- **Arreios**: manta azul do time com borda branca (topo e laterais), sela de couro com arção e
  patilha, estribos de ferro e **rédeas**.
  - Cada rédea sai da argola do freio, corre **pela lateral do pescoço**, por fora e abaixo da
    mandíbula, passa por trás da crina e só então chega à mão do cavaleiro.
  - São três segmentos finos por rédea. Conferido por amostragem (60 pontos por segmento): nenhum
    entra no focinho, no crânio, no pescoço, na crina ou no corpo; o único contato é com a argola
    do freio.
  - Revisão do usuário: as rédeas retas atravessavam a cabeça do cavalo.
- **Compacto para caber num hex**: 2,16 m do focinho à cauda, 0,86 m de largura.

## Cavaleiro

É a base humana das tropas (mesmos blocos e proporções de 1,80 m em pé), **sentado na sela**:
- pernas abraçando o cavalo, com os pés nos estribos;
- equipamento leve: gibão acolchoado, colete e ombreiras de couro, braçadeiras, calça, botas de
  montaria e o **elmo de nasal pintado na cabeça**;
- **lança** em pé na mão direita, com ponta de ferro e **flâmula azul e branca**;
- a mão esquerda segura as rédeas.

## Especificações

| Item | Valor |
| --- | --- |
| Altura | cabeça do cavaleiro a 2,31 m; ponta da lança a 3,24 m (construído em escala real, sem ajuste) |
| Tamanho no chão | 2,16 m × 0,86 m |
| Peças editáveis | 58 |
| Faces coplanares sobrepostas | 0 (`check_coplanar`) |
| Atlas | 64 px/m, albedo + emissão (preta), nearest |

## Rig: 28 ossos

- **Cavalo (12)**: `horse_body`, `horse_neck`, `horse_head`, `horse_tail`, e `horse_thigh_*` +
  `horse_cannon_*` em cada perna (fl, fr, bl, br).
- **Cavaleiro (16)**: os ossos humanos das tropas, **compostos sobre o corpo do cavalo**, então
  ele acompanha o galope. Sentado, as pernas seguem o quadril.
- **Rédeas** divididas: o trecho do freio vai na cabeça, o do pescoço no pescoço, e o da mão na
  mão esquerda.
- Uma **trava no chão** levanta a pose inteira sempre que um casco desceria abaixo do piso.

## Animações

| Clipe | Duração | Descrição |
| --- | --- | --- |
| `Cavalier_Idle` | 3 s, loop | O cavalo respira, balança a cabeça e abana a cauda; o cavaleiro respira e olha em volta |
| `Cavalier_Walk` | 0,75 s, loop (no lugar) | **Galope**, descrito abaixo |
| `Cavalier_Attack` | 1,33 s | **Carga de lança**, descrita abaixo |
| `Cavalier_Charge` | 1,5 s | **Investida** (técnica Carga), descrita abaixo |

**Galope**: sequência transversa (traseira esquerda e direita, depois dianteira esquerda e
direita), com os joelhos dobrando na passada. O corpo balança e quica, a cabeça acompanha, a cauda
vai esvoaçando para trás e o cavaleiro mantém o tronco reto contra o balanço.

**Carga de lança**:
1. O cavalo **meio que empina**, com as patas da frente recolhidas, girando nas patas de trás
   plantadas, enquanto o cavaleiro levanta a lança para trás.
2. Depois **avança** enquanto a lança desce e é cravada à frente (impacto no frame 15).
3. Segura a pose e volta.

**Investida** (técnica Carga: avança até 4 tiles e ataca com 1,5× o Ataque). No jogo, a unidade
galopa pelo caminho e só então ataca. Por isso este clipe é a **chegada**:
1. Começa no meio do galope, para emendar na corrida, e a lança desce até ficar **deitada sob o
   braço** nas últimas passadas.
2. Acerta com o embalo no frame 11: o cavalo **freia**, com as patas da frente firmadas e a
   traseira baixando, e o cavaleiro é jogado para a frente e **crava a lança**.
3. Segura o empurrão, levanta a lança e volta à pose de descanso.

É diferente do Attack comum, em que o cavalo meio que empina parado.

O braço da lança usa IK, com mistura FK/IK na entrada e na saída.

Na validação: loops fechados, o ataque começa e termina na pose BASE e nada fica abaixo do chão.
Há 2 clamps de alcance no braço da lança, sem efeito visível nas prévias de lado. No Godot
(`verify_cavalier_import.gd`): **PASS**, 28 ossos, 4 clipes.

Arquivos: `cavalier_v1.glb`, `cavalier_import.gd` (Idle e Walk em loop) e
`previews/animations/Cavalier_*.{mp4,gif}`.

## Reprodução via MCP

`cavalier_model.py` (o maquinário do `warrior_model.py` com as peças do cavalo e do cavaleiro
sentado) → `cavalier_paint_save.py` → `cavalier_previews.py` → `cavalier_animate.py` (rig novo) →
`cavalier_animation_previews.py` → `python tools/art_pipeline/encode_cavalier_previews.py` →
`cavalier_export.py`. Depois: `godot --headless --path . --import` e
`godot --headless --path . -s tools/art_pipeline/verify_cavalier_import.gd`.

## Para entrar no jogo

Hoje `perform_strike` move a unidade (galope pelo caminho) e resolve o ataque **no mesmo frame**,
então o clipe de ataque começaria durante o deslize e seria cortado na chegada pelo Idle. Ao
integrar o Cavaleiro, o `Unit.play_attack_visual` precisa **adiar o clipe até o fim do
`walk_path`** e tocá-lo virado para o alvo. O mapa de técnicas fica
`v2_technique_charge -> Cavalier_Charge`.
