# Asset Factory — Guia da Pipeline de Modelos 3D

Documento vivo (mesma convenção do `GAME_DESIGN_BIBLE.md`): registra como a
pipeline funciona HOJE e o porquê das decisões não óbvias no código. Quando a
pipeline mudar de verdade (novo campo de estilo, novo bug de escala, novo
fluxo), atualize este arquivo no mesmo commit.

**Objetivo deste documento**: qualquer sessão nova do Claude Code (ou você
mesmo, relendo depois de meses) deve conseguir ler isto e já saber criar,
editar e importar um personagem sem repetir descobertas já feitas.

---

## 0. O que é e o que NÃO é

A "Asset Factory" (`tools/asset_factory/`) gera personagens/monstros 3D
**proceduralmente via script Python (bpy) dentro do Blender** — malha, rig
(esqueleto), skin (peso de vértices), animações (Idle/Walk/Attack/Death) e
export para `.glb`, tudo determinístico a partir de um preset JSON + seed.

**Não é IA generativa de modelos 3D.** Não há geração por difusão nem
importação de assets de terceiros nesta pipeline — é geometria construída por
código (caixas, cunhas, "loft" de anéis), decisão explícita do projeto.

Existem hoje **dois consumidores de modelo 3D** no jogo, com regras de escala
diferentes (ver seção 4):
- **KayKit** (pacote de terceiros): Guerreiro/Cavaleiro/etc. antigos, escala
  "real" inconsistente entre personagens do pacote.
- **Asset Factory** (`res://assets/generated/`): tudo gerado por esta
  pipeline — Guarda, Colono, Goblin, Esqueleto, Troll (2026-09). É para ONDE
  o projeto está migrando; todo personagem novo deveria nascer aqui.

---

## 1. Mapa de diretórios

```
tools/asset_factory/
  generate_character.py   # entry point CLI (roda dentro do Blender headless)
  editor_addon.py          # addon interativo p/ rodar DENTRO da UI do Blender
  style/
    definitions.py         # HumanoidStyle/HumanStyle — TODO campo de proporção/silhueta, cada um comentado no próprio arquivo
    palette.py              # MaterialLibrary — cores fixas vs. cores por civilização, texturas de pele/couro/músculo
    textures.py              # geração de imagens (rosto, unha, pele, músculo) — pixels crus, ver bug de colorspace na seção 6
  character/
    builder_blocky.py        # engine ATUAL ("blocky") — monta corpo+equipamento a partir de style+preset["equipment"]
    builder.py / builder_v2.py / builder_v3.py  # engines antigas (organic) — só mantidas por compat, não usar em personagem novo
    params.py                # compute_measurements() — converte style (frações de altura) em medidas absolutas
  geometry/
    body_blocky.py            # corpo do engine blocky: torso/braços/pernas/mãos/pés/cabeça
    equipment_blocky.py       # armas, capacete, cinto, saia, mochila, etc. do engine blocky
    primitives.py              # box/wedge/sloped_wall/strap/uv_sphere — os "tijolos" de toda a geometria
  rig/
    skeleton.py               # 18 ossos compartilhados por TODO personagem humanoide (qualquer engine)
    skinning.py                # bind da malha à armature (grupos de vértice por nome de osso)
  animation/
    clips.py                   # Idle/Walk/Attack/Death — compartilhadas, com pequenos overrides (ex.: staff_side)
  export/exporter.py           # export_glb() — único ponto que grava o .glb
  preview/render.py            # renderiza 4 PNGs (front/back/side/top) ortográficos p/ conferência rápida
  presets/*.json               # DADOS — um arquivo por personagem, é aqui que 90% do trabalho do dia a dia acontece

assets/generated/<categoria>/<nome>/
  <nome>.glb                   # resultado final, referenciado por MonsterDatabase.gd / UnitDatabase.gd
  <nome>_report.json           # relatório da última geração (stats de malha, ossos, animações, altura alvo)
  preview_<nome>_{front,back,side,top}.png
  <nome>_tex_*.png              # texturas geradas (uma por região/material que precisou de imagem própria)
```

---

## 2. Dois jeitos de trabalhar

### 2a. CLI headless (`generate_character.py`) — regeneração determinística

Reconstrói um personagem do ZERO a partir só do preset JSON. Use quando você
editou o preset JSON diretamente (ou o código do engine) e quer o `.glb`
atualizado sem abrir a UI do Blender.

```
"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe" --background --factory-startup --python tools/asset_factory/generate_character.py -- \
    --preset tools/asset_factory/presets/troll_blocky.json --seed 21
```

- `--seed` sobrescreve o `seed` do preset (determinismo: mesmo preset + mesma
  seed = mesmo resultado sempre).
- `--out` sobrescreve `output.directory` do preset.
- `--no-preview` pula a renderização dos 4 PNGs de conferência (mais rápido
  em iteração).
- Escreve `<nome>_report.json` no diretório de saída — útil pra conferir
  altura alvo, contagem de ossos/materiais e nomes das animações sem abrir o
  Blender.

### 2b. Editor interativo dentro do Blender (`editor_addon.py`) — ajuste visual + pintura

Existe porque sliders nativos do Blender e o Texture Paint nativo são muito
melhores que reinventar isso do zero. **Roda DENTRO da UI do Blender**, não é
um app separado.

**Como abrir**: no Blender, aba *Scripting* → **Open** este arquivo (não
"New" + colar — "Open" é o que permite o script achar seu próprio diretório)
→ **Run Script**. O painel aparece na **viewport 3D → sidebar (tecla N) → aba
"Asset Factory"** — não na aba Scripting.

**Fluxo (documentado também no docstring do próprio arquivo)**:
1. Escolher um preset no dropdown → **Carregar Modelo**.
2. Arrastar os sliders de dimensão (braços, pernas, mãos, torso, cabeça) →
   **Aplicar Dimensões** para reconstruir. Barato, tudo em memória, repita
   quantas vezes quiser.
3. **Remover Partes**: desmarcar caixas de qualquer osso apaga aquela parte
   do personagem (ex.: tirar um braço).
4. **Preparar para Pintar**: cria uma textura única com as cores atuais já
   assadas nela (não começa em branco) e entra em Texture Paint. **Atenção**:
   mexer nos sliders de novo DEPOIS disso reconstrói a malha do zero e joga a
   pintura fora — termine de moldar antes de pintar.
5. **Salvar Modelo**: exporta o `.glb` exatamente como está (malha + esqueleto
   + animações + textura pintada) para o diretório de saída do preset, grava
   a textura pintada como PNG solto ao lado, e **reescreve o JSON do preset**
   com as dimensões atuais — isso vira a nova linha de base determinística
   pra esse personagem (próxima geração via CLI parte daqui).

Reabrir o script (Run Script de novo) depois de editar qualquer módulo que
ele importa é seguro — ele força reload dos próprios módulos toda vez.

**Depois de "Salvar Modelo": o `.glb` já está atualizado no disco, mas o
Godot ainda não sabe disso.** É preciso reimportar (seção 3).

---

## 3. Levar uma mudança para dentro do jogo (lado Godot)

### 3.1 Sempre que o `.glb` mudar (seja via editor addon ou via CLI)

```
"C:\Users\felipe campos\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
```

Sem isso, o Godot continua usando o cache antigo do `.import` — é fácil achar
que "não mudou nada" quando na real só faltou reimportar. Regra prática:
compare o timestamp do `.glb` com o do `.glb.import` (`ls -la`) se tiver
dúvida se o import está em dia.

### 3.2 Cadastrando um personagem novo (ou apontando pra um `.glb` novo)

Ver `scripts/data/MonsterDatabase.gd` (monstros neutros) ou
`scripts/data/UnitDatabase.gd` (unidades de civilização) — cada entrada
define, no mínimo:

```gdscript
data.model_scene_path = "res://assets/generated/<categoria>/<nome>/<nome>.glb"
data.animation_scene_path = "res://assets/generated/<categoria>/<nome>/<nome>.glb"  # mesmo arquivo, o .glb já carrega as clips
data.merge_shared_walk_animation = false
data.idle_animation_override = "Idle"
data.walk_animation_override = "Walk"
data.attack_animation_override = "Attack"
data.model_scale_multiplier = 1.0   # ver seção 4 -- NÃO copiar de outro personagem
data.model_yaw_offset_degrees = 180.0  # a maioria dos personagens da Asset Factory nasce virada 180° do que o jogo espera
```

### 3.3 Testes de regressão depois de mexer nisso

`test/unit/test_monsters.gd` e `test/unit/test_selection_manager.gd` cobrem
esse território. Rodar via GUT:

```
"...\Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_monsters.gd -gexit
```

**Atenção**: o `-gtest=<arquivo>` às vezes não restringe a suíte inteira (já
aconteceu de rodar os 46 scripts/1286 testes mesmo passando um único
arquivo) — não estranhar um tempo de execução de ~4 minutos, e ler o bloco
"Run Summary" no fim do output (não confiar só no exit code — há falhas
pré-existentes e "flaky"/dependentes de ordem nesta suíte, não
necessariamente causadas pela sua mudança; se suspeitar disso, isole com
`git stash` só dos arquivos que você tocou e rode de novo pra comparar).

---

## 4. O sistema de escala — ARQUITETURA ATUAL (não repetir o bug antigo)

**Regra de ouro: para qualquer personagem da Asset Factory, a altura final
em jogo é literalmente o campo `"height"` (em metros) do preset JSON.**
`model_scale_multiplier` deve ficar em `1.0` — é só um ajuste fino manual
opcional, NUNCA o mecanismo principal de tamanho.

Por quê isso existe (`scripts/units/Unit.gd`, `_build_model_body()`):

- **KayKit** (terceiros): cada personagem do pacote vem numa escala "real"
  ligeiramente diferente e num bind pose mais aberto que a pose de pé normal
  — por isso o código normaliza pela altura do bounding box
  (`MODEL_TARGET_HEIGHT / aabb.size.y`). Necessário e correto PRA ELES.
- **Asset Factory** (`res://assets/generated/`): a altura já é um parâmetro
  explícito e controlado no preset, na MESMA convenção de unidade do resto
  do jogo (`hex_size = 1.0`), com bind pose de pé de verdade. Normalizar de
  novo pelo bounding box é **redundante e ativamente prejudicial**: o
  bounding box inclui qualquer arma/prop erguido, cada personagem tem uma
  silhueta bem diferente, e foi exatamente essa conta que fez Goblin/
  Esqueleto/Troll renderizarem visivelmente MAIORES em jogo do que qualquer
  fórmula previa — investigado a fundo (bounding box em várias formas
  diferentes, ângulo de câmera, timing de animação) sem causa raiz
  encontrada, porque a causa raiz era a normalização em si, não uma conta
  errada.

Por isso `Unit.gd` detecta o prefixo `res://assets/generated/` e pula a
normalização inteira pra esses casos:

```gdscript
const ASSET_FACTORY_PATH_PREFIX := "res://assets/generated/"

if unit_data.model_scene_path.begins_with(ASSET_FACTORY_PATH_PREFIX):
    model.scale = Vector3.ONE * unit_data.model_scale_multiplier   # 1:1, sem normalização
else:
    var aabb = _model_aabb(model)
    if aabb != null and aabb.size.y > 0.0:
        model.scale = Vector3.ONE * (MODEL_TARGET_HEIGHT / aabb.size.y * unit_data.model_scale_multiplier)
```

**Se um personagem novo da Asset Factory parecer grande/pequeno demais em
jogo: NÃO mexa em `model_scale_multiplier`.** Ajuste `"height"` no preset,
resalve/reexporte (seção 2/3), e reimporte. `model_scale_multiplier` só
existe pra um ajuste manual fino que não caiba em mudar a altura (raro).

### Ferramenta de comparação de tamanho em jogo (debug)

Com `GameManager.debug_mode` ligado (botão "Debug" na HUD, só aparece em
build de debug), clicar num tile vazio com "Mover" armado **teleporta** a
unidade selecionada pra lá instantaneamente (sem custo de `movement_left`,
sem animação) — feito especificamente pra facilitar posicionar duas unidades
lado a lado e comparar tamanho real em jogo, sem as regras normais de
movimento atrapalhando. Ver `HexGrid.gd::teleport_unit` e
`SelectionManager.gd::_debug_teleport_selected_to`. Fora do modo debug, esse
caminho nunca é avaliado — comportamento normal de movimento intacto.

---

## 5. Metodologia de verificação — "confirme, não adivinhe"

Padrão usado (e recomendado) em toda a pipeline, reforçado várias vezes por
bugs que uma inspeção visual sozinha não pegaria:

1. **Bounding box em espaço mundial**, não local — pra saber se uma peça
   nova realmente está onde deveria (`obj.matrix_world @ v.co` min/max por
   eixo, comparado contra os extremos já conhecidos das peças vizinhas).
   Pegou pelo menos 3 bugs reais nesta pipeline: arma pendurada pro lado
   errado (escondida dentro do antebraço), geometria de detrito
   invisível (embutida na superfície ou atrás da cabeça), UV degenerada do
   `smart_project` (ilha de largura zero em 4 de 6 faces de toda caixa).
2. **Renderizar do ângulo de câmera REAL do jogo** (`scenes/main/Main.tscn`:
   rig `rotation_degrees (-45,35,0)` + câmera `(-50,0,0)`, pitch top-down
   íngreme) antes de aprovar qualquer coisa que "aparenta" estar boa nos
   previews ortográficos padrão (`preview/render.py`) — uma peça que parece
   certa de frente pode ler como "um anel"/"uma prateleira" vista de cima.
3. **Screenshot único, não-headless, descartável** — procedimento padrão
   pra qualquer conferência visual final:
   - Escrever uma cena/script `_xxx.tscn`/`_xxx.gd` (Node3D manual: câmera +
     luz + ambiente igual ao `Main.tscn`, spawna a(s) unidade(s) via
     `UnitDatabase.create_unit(...)` / `MonsterDatabase.create_monster(...)`).
   - Rodar UMA VEZ, **não-headless**: `godot --path . scene.tscn` (nunca em
     loop, nunca repetidamente pro mesmo check — custo real de tempo).
   - Screenshot: `get_viewport().get_texture().get_image().save_png(...)` e
     `get_tree().quit()`.
   - **Apagar os arquivos temporários imediatamente** depois de olhar o
     resultado, e confirmar com `git status --porcelain` que não sobrou
     nada — eles não são parte do jogo, só uma ferramenta de inspeção.
4. **Quando até a verificação programática concordar consigo mesma e ainda
   assim discordar do pixel renderizado**: o bug pode estar na PREMISSA
   (uma camada de normalização/correção que não deveria existir pra esse
   caso), não na aritmética — foi exatamente o que aconteceu com o sistema
   de escala (seção 4). Se motor/formula "provam" um resultado que a
   imagem real contradiz repetidamente, questione a arquitetura antes de
   insistir em mais uma correção numérica.

---

## 6. Catálogo de bugs/lições já resolvidos (não redescobrir)

Resumo — detalhes completos na memória do Claude Code deste projeto
(`feedback_blocky_humanoid_baseline`, `feedback_dragon_3d_model_iteration`) e
no histórico de commits/comentários dos arquivos citados.

- **Colorspace (sRGB vs Non-Color)**: `bpy.data.images.new()` nasce sRGB por
  padrão. Escrever valores lineares crus (pra bater exatamente com números de
  material flat BSDF) nessa textura faz o shader decodificar como sRGB e
  escurecer/distorcer a cor — bug real de material, não de iluminação/ângulo.
  Fix: `img.colorspace_settings.name = 'Non-Color'` em qualquer imagem nova
  usada como paleta de cor (`style/textures.py::_new_image`).
- **`smart_project` gera UV degenerada em malha só de caixas alinhadas aos
  eixos**: 4 de 6 faces de toda caixa (paredes laterais) ficavam com uma
  ilha de UV de largura ZERO — impossível de pintar ali. Reduzir
  `island_margin` não resolvia (não era pressão de empacotamento). Fix:
  `editor_addon.py::_grid_unwrap_paint_uv` — unwrap determinístico em grade,
  uma célula por polígono, nunca degenerada.
- **Campos `*_radius_ratio` mortos no engine "blocky"**: existem no preset e
  no `HumanoidStyle`, mas `body_blocky.py` deriva a grossura de
  bicep/antebraço/coxa/panturrilha só de `chest_hw`/`torso_hw` × um
  coeficiente fixo escolhido por `slim_build`/`thin_arms` — mexer nesses
  campos não fazia NADA no engine atual (só os engines organic v1/v2/v3
  antigos os leem). Fix: campo novo `limb_slenderness` (multiplicador
  contínuo de verdade, aplicado DEPOIS de calcular tamanho de
  mão/pé, pra eles não encolherem junto). Lição: sempre grep pelo uso real
  de um campo de preset antes de assumir que ele afeta o engine atual.
- **Arma "pendurada" pro lado errado**: `build_club_parts`/
  `build_sword_parts` cresciam PRA CIMA a partir do grip, ocupando a mesma
  coluna vertical que o antebraço (que não se dobra neste rig) — arma ficava
  escondida atrás/dentro do antebraço. Achado via bounding box em espaço
  mundial (o cabo caía exatamente dentro do range Z do antebraço), não por
  adivinhação visual. Fix: pendurar a arma PRA BAIXO a partir de um ponto de
  grip logo acima do centro da mão.
- **Sistema de escala (KayKit vs Asset Factory)**: ver seção 4 inteira —
  o bug mais caro desta pipeline em tempo de investigação, e a lição mais
  importante (questionar a premissa, não só a conta).
- **Baseline de proporção do corpo humanoide está travada**: `body_blocky.py`
  hoje reflete muitas rodadas de ajuste fino aprovadas pelo usuário (V-taper
  peito/cintura, coxa mais fina que panturrilha, etc.) — é o ponto de
  partida padrão pra QUALQUER personagem humanoide novo. Só desviar quando
  pedido explicitamente pra aquele personagem específico (`slim_build`,
  `thin_arms`, `belly_width_mult`, etc. — todos opt-in, default preserva o
  Guarda pixel-a-pixel).

---

## 7. Onde NÃO duplicar — referências vivas

Em vez de copiar listas exaustivas de campos aqui (que ficariam desatualizadas
na hora que alguém adicionar um campo novo), consulte direto:

- **Todo campo de proporção/silhueta** (com comentário explicando o porquê):
  `tools/asset_factory/style/definitions.py`.
- **Toda flag de equipamento aceita no preset** (`"equipment": {...}`): grep
  por `equipment_cfg.get(` em `tools/asset_factory/character/builder_blocky.py`.
- **Exemplo de preset real e comentado** (espécie não-humana, arma custom,
  paleta própria): `tools/asset_factory/presets/troll_blocky.json` +
  o comentário correspondente em `scripts/data/MonsterDatabase.gd` (procure
  `elif kind == "troll":`).
- **Por que cada escolha de escala/wiring de um personagem específico foi
  feita**: comentário logo acima de cada entrada em `MonsterDatabase.gd` /
  `UnitDatabase.gd` — cada personagem tem o histórico da própria decisão ali.

---

## 8. Checklist rápido — "quero criar um personagem novo"

1. Copiar o preset humanoide mais parecido (`presets/*.json`) como ponto de
   partida — não reinventar proporções do zero (seção 6, baseline travada).
2. Ajustar `body.height` (metros, convenção real do jogo) e qualquer flag de
   silhueta específica da espécie (`slim_build`, `thin_arms`,
   `limb_slenderness`, `pointy_ears`, `belly_width_mult`, ...).
3. Ajustar `equipment` (arma, cabelo, roupa, `bare_skin`/`textured_skin` pra
   pele exposta) e `palette` (cor de pele/cabelo/olho).
4. Gerar via CLI (seção 2a) ou abrir no editor addon pra ajustar visualmente
   e pintar (seção 2b) — terminar sempre com "Salvar Modelo" se usou o
   editor.
5. `godot --headless --path . --import` (seção 3.1).
6. Cadastrar/atualizar a entrada em `MonsterDatabase.gd` ou `UnitDatabase.gd`
   (seção 3.2), com `model_scale_multiplier = 1.0`.
7. Verificar visualmente (seção 5): screenshot único descartável, de
   preferência ao lado de um personagem de altura já conhecida (ex.: o
   Guarda, 1.8m) pra calibrar a impressão de tamanho a olho — ou usar o
   teleporte de debug (seção 4) direto em uma partida real.
8. Rodar os testes de regressão relevantes (seção 3.3) antes de considerar
   pronto.
