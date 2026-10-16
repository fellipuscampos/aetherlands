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

**Texturas de modelo em BC7 (regra desde 2026-10-14).** Toda textura usada por material 3D é importada como
*VRAM Compressed* em alta qualidade (`compress/mode=2`, `compress/high_quality=true` = BC7 no desktop): 4× menos
memória de vídeo que *Lossless* e visualmente idêntica (PSNR ~50 dB nos atlas do projeto). O Godot headless cria as
texturas extraídas de um `.glb` novo como *Lossless*, então depois de exportar arte nova rode:

```
godot --headless --path . -s tools/perf/texture_import_audit.gd -- --fix
godot --headless --path . --import
```

Sem `--fix` a auditoria só lista (sai com código 1 se houver textura fora da regra). UI/ícones (`assets/ui`,
`assets/icons`) e o terreno ficam de fora. Detalhes em `docs/PERFORMANCE_GUIDE.md` §6.

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

**Tropas por raça (2026-10-08):** `UnitDatabase` declara só a arte humana (padrão).
A versão de anões/elfos/orcs de um kind fica em `scripts/data/UnitArtCatalog.gd`,
aplicada em `Unit.setup()`/`apply_form()` pela raça do dono (cópia própria do
`UnitData`; stats nunca mudam). Registradas hoje: linhas completas do Guardião
e do Guerreiro (escolta inicial `UnitDatabase.STARTING_ESCORT_KINDS` + evoluções
e lendários, para o upgrade não trocar de raça). Cada entrada declara os nomes
REAIS dos clipes: anões exportam `idle/walk/attack` sem Muralha/técnicas; elfos e
orcs repetem os prefixos humanos (`Squire_Idle`, `Warrior_PowerStrike`...).
Modelos 1:1, frente +Z (yaw 0), altura da raça no próprio GLB (anão 1,35 m,
elfo 1,80 m, orc 2,00 m). `test_unit_art_catalog.gd` carrega cada GLB e confere
cada clipe declarado. Um `model_scene_path` ausente cai no corpo procedural com
aviso, em vez de quebrar o turno (`Unit._build_model_body`).

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

### Construções com fonte em metros

**Arte por raça (2026-10-08):** prédios e centros urbanos são resolvidos por
`scripts/data/BuildingArtCatalog.gd`, fonte única para humanos, anões, elfos e
orcs (`assets/generated/<raça>/buildings/`). `BUILDING_ART` mapeia cada id de
`BuildingData` → raça → stem do asset; `CITY_ART` mapeia raça → City Level →
stem. O visual segue a raça do **dono atual** (captura e load recriam prédio e
centro). Fallback: prédio sem arte da raça → arte humana → `model_scene_path`
(KayKit dos cinco econômicos); nível de cidade sem arte da raça → maior nível
próprio já feito (nunca um castelo humano numa cidade orc). Malhas `*_Faction`
recebem a cor do dono por instância em prédios e centros. As notas "sem
integração no jogo" abaixo são históricas: os 24 prédios de Doutrina/Magia e a
Cidade I das quatro raças estão integrados. `City.CITY_MODELS_BY_LEVEL` e
`BuildingDatabase.GENERATED_MODELS`, citados abaixo, foram substituídos pelo
catálogo.

**Ao exportar arte nova de prédio/centro** (ex.: `orc_city_level_2_hex_v1`):
adicionar o stem em `BUILDING_ART`/`CITY_ART`, rodar `godot --headless --path .
--import` e `test/unit/test_building_art_catalog.gd`. O teste cruza cada caminho
com o `gameplay_building_id` do `*_report.json`, mede o encaixe no tile e falha
se um relatório de prédio exportado não estiver registrado.

`BuildingDatabase` mantém em `model_scene_path` a versão humana (padrão sem
dono) e reaplica o catálogo em recursos retidos no cache após recarga do
script, sem substituir dados de treino, custos e manutenção.

`BuildingData.model_scale_multiplier` define o ajuste uniforme de construções.
`Building.gd` usa escala-base **1,0** para `res://assets/generated/` e mantém a
calibração **KAYKIT_SCALE** para os modelos antigos. Nenhum prédio é normalizado
por altura. O Salão dos Guardiões usa **`guardian_hall_hex_v2.glb`**, uma peça
4X criada diretamente nas unidades do mapa, com multiplicador **1,0**. Sua base
hexagonal pointy-top tem raio 0,92 para o tile de raio 1; salão, telhado, quinas
e pátio foram compostos para esse formato. Dimensões: 1,5935 × 1,84 × 1,4965
(largura × profundidade × altura). V1 era uma planta retangular reduzida a 0,14
e foi rejeitada pelo usuário. Conferir os seis limites do hex por vértices e
renderizar com a câmera 4X; apenas caber no bounding box não basta.

O **Salão de Armas** usa `warrior_hall_hex_v1.glb`, também com base pointy-top
de raio 0,92 e multiplicador 1,0. Duas alas traseiras seguem as diagonais do
hex; o pátio hexagonal aberto ocupa a frente. Espadas cruzadas, manequins,
racks de machados/espadas e uma pequena forja identificam a linha do Guerreiro.
Dimensões: 1,5935 × 1,84 × 1,301 (largura × profundidade × altura), 2.068
triângulos, 8 malhas, 1 material e atlas 2048² nearest. Telhados oblíquos
adjacentes devem ser recortados na junção: caixas sobrepostas na mesma altura
produziram manchas pretas de faces coplanares no render. Fontes/scripts e
verificação estão descritos no README de `warrior_hall_hex_v1`.

O **Campo dos Patrulheiros** usa `ranger_camp_hex_v1.glb` em escala 1,0,
com a mesma base hexadecimal de raio 0,92. Cabana lateral de madeira,
três alvos e pistas paralelas na diagonal traseira, portal com arco/flecha,
toldos verdes e área aberta identificam a linha à distância. Dimensões:
1,5935 × 1,84 × 1,1995 (largura × profundidade × altura), 3.076 triângulos,
8 malhas, 1 material e atlas 1024² nearest. A paleta adicional é armazenada
na cena Blender em `palette_overrides`, consumida pelo helper de pintura.
Fontes, prévias e scripts estão em `ranger_camp_hex_v1` e `tools/art_pipeline/`.
Na conferência de prédios colocados via `HexGrid`, medir a base em relação à
posição do prédio/tile, não ao Y=0 mundial: grama tem `base_height = 0,02`.

O **Estábulo de Guerra** usa `war_stable_hex_v1.glb`, escala 1,0 e base de raio
0,92. Celeiro com três baias abertas, telhado recortado a cada camada pelos
limites do hex, pátio em cunha, ferradura e cavalos identificam a cavalaria.
Dimensões: 1,5935 × 1,84 × 1,2615; 2.252 triângulos, 8 malhas, 1 material e
atlas 2048² nearest. Os cavalos reutilizam apenas as malhas da montaria de
`cavalier_v1.blend`, sem cavaleiro ou rig. O helper de pintura reprojeta os
UVs/textura dessas peças para o atlas único do prédio, preservando a pintura
aprovada; o export remove os metadados internos `source_paint_*` das cópias.

A **Guilda dos Ladinos** usa `rogue_guild_hex_v1.glb`, escala 1,0 e base de
raio 0,92. Sede pentagonal com torre hexagonal de observação, telhados escuros
recortados pelo hex e detalhes violetas. Capuz/adagas, manequins com marcas
de golpe preciso e alvo de arremesso identificam a linha de assassinato.
Dimensões: 1,5935 × 1,84 × 1,4215; 2.536 triângulos, 8 malhas, 1 material e
atlas 2048² nearest. Toda a geometria foi criada sem referência de personagem;
a paleta é armazenada na cena em `palette_overrides`.

O **Arsenal de Cerco** (Arsenal de Guerra) usa `siege_arsenal_hex_v1.glb`,
escala 1,0 e base de raio 0,92. Oficina pentagonal com vão amplo aberto,
catapulta de quatro rodas, guindaste de montagem e engrenagem na fachada.
Rodas, madeira, munição e bancada identificam a produção de máquinas de cerco.
Dimensões: 1,5935 × 1,84 × 1,3005; 3.244 triângulos, 8 malhas, 1 material e
atlas 2048² nearest. Os adereços são geometria original estática e não dependem
de modelos de unidade. A placa fica no centro do portal, livre do guindaste.

O **centro da Cidade I** usa `city_level_1_hex_v1.glb` via
`City.CITY_MODELS_BY_LEVEL`. A base tem raio **0,84**, menor que a dos prédios,
para caber dentro da face interna da Fortificação (apotema interno ≈ 0,7671).
Castelo compacto de um piso, uma torre com ameias, porta dupla e coroa; novos
andares/torres ficam para os próximos níveis. Dimensões: 1,4549 × 1,68 × 1,215;
1.496 triângulos, 8 malhas, 1 material fonte e atlas 1024² nearest. A instância
escala por `tile_radius`. A malha `Faction` contém só tecidos/placa neutros:
material duplicado por cidade recebe a cor do dono, sem tintar pedra/telhas ou
mutar recursos compartilhados. Muralha, HP, nome e escudo permanecem separados
do GLB. Níveis sem fonte própria continuam usando o visual procedural.

O **centro da Cidade II** usa `city_level_2_hex_v1.glb` pelo mesmo mapa de
níveis: evolução do castelo I com salão de dois pisos (+0,24), torre esquerda
elevada, nova torre direita mais baixa e janelas superiores. Mantém base
hexagonal de raio 0,84 e não contém muralhas ao redor. Os três níveis de
Fortificação são independentes e ficam reservados a modelos próprios;
o jogo continua desenhando a fortificação existente somente quando comprada.
Dimensões: 1,4549 × 1,68 × 1,315; 2.088 triângulos, 157 peças editáveis,
8 malhas e atlas 1024² nearest. Bandeira, placa e estandartes recebem a cor
da civilização por instância. Os quatro níveis agora têm fontes próprias.

O **centro da Cidade III** usa `city_level_3_hex_v1.glb`: torre central sobre
o telhado, varanda real acima da entrada e torres laterais elevadas. Mesma
base hexagonal de raio 0,84, sem muralhas ao redor, com folga para as
fortificações independentes. Dimensões: 1,4549 × 1,68 × 1,7425;
2.520 triângulos, 193 peças editáveis, 8 malhas e atlas 2048² nearest.
`City.gd` mede os limites locais das malhas na reconstrução para posicionar
nome, HP e escudo acima dos modelos mais altos; mantém as distâncias entre
elementos e acompanha a escala do tile. Tecidos neutros recebem a cor do
dono sem modificar pedra, telhas ou recursos compartilhados. Upgrade II→III,
captura, escala e fortificação separada cobertos por 117 testes/630 assertivas.

O **centro da Cidade IV** completa a família em `city_level_4_hex_v1.glb`:
torre central ampliada, três coberturas azuis em degraus, frisos/coroas dourados
e bandeira no ponto mais alto. Mesma base de raio 0,84, sem muralhas ao redor,
com borda livre para fortificações. Dimensões: 1,4549 × 1,68 × 2,185;
2.944 triângulos, 223 peças editáveis, 8 malhas, 1 material fonte e atlas
2048² nearest. Tecidos e tapete recebem a cor do dono por instância.
`City.CITY_MODELS_BY_LEVEL` tem os quatro modelos; o procedural fica como
fallback de carregamento. Upgrade III→IV, captura, escala, fortificação
separada e altura da interface conferidos: 117 testes/639 assertivas.

O **centro da Cidade Orc I** está preparado em
`assets/generated/orcs/buildings/orc_city_level_1_hex_v1/`, **sem integração
no jogo**, por decisão do usuário. Salão do chefe em madeira/pedra escura,
telhado avermelhado, ferro, presas e totem do clã; base hexagonal de raio 0,84,
sem muralha ao redor. São 128 peças editáveis, 1.656 triângulos, 8 malhas de
exportação e atlas 1024² nearest. Os níveis II–IV ainda serão criados.
Scripts `orc_city_level_1_hex_v1_model.py` e `_finish.py`, executados via MCP
no Blender aberto; fontes, relatório e quatro prévias ficam junto ao GLB.
O helper compartilhado resolve `asset_output_relative` salvo na cena para
exportar a civilização correta, com fallback para a pasta humana nas cenas
anteriores. A verificação de integração usa o caminho real de saída do GLB.
`City.CITY_MODELS_BY_LEVEL` e os catálogos continuam como estavam.

O **centro da Cidade Élfica I** está preparado em
`assets/generated/elves/buildings/elf_city_level_1_hex_v1/`, também **sem
integração no jogo**. Pavilhão de conselho em pedra clara/madeira, telhado
verde com folhas douradas, portal pontudo, árvore de copa em blocos e
espelho d'água. Base hexagonal de raio 0,84, sem muralhas; um volume principal
para reservar crescimento aos níveis II–IV. São 133 peças editáveis,
2.028 triângulos, 8 malhas e atlas 1024² nearest. Os scripts
`elf_city_level_1_hex_v1_model.py` e `_finish.py` usam o Blender MCP e os
helpers compartilhados; fonte `.blend`, GLB com texturas embutidas, relatório
e quatro prévias estão na pasta do asset. Nenhuma seleção de modelo em
runtime foi alterada.

O **centro da Cidade Anã I** está preparado em
`assets/generated/dwarves/buildings/dwarf_city_level_1_hex_v1/`, **sem
integração no jogo**. Salão baixo e largo em granito, pilares monumentais,
telhado escuro com cintas de cobre, martelo cívico e lanternim baixo.
Pátio com monumento à bigorna, banco e cisterna; base hexagonal de raio 0,84,
sem muralhas. São 143 peças editáveis, 1.848 triângulos, 8 malhas e atlas
1024² nearest. Scripts `dwarf_city_level_1_hex_v1_model.py` e `_finish.py`
via Blender MCP; fonte `.blend`, GLB com texturas embutidas, relatório e
quatro prévias ficam na pasta do asset. Nenhum catálogo ou seletor de
modelos em runtime foi alterado. Os níveis II–IV ficam para depois.

O **Salão dos Guardiões Orcs** está preparado em
`assets/generated/orcs/buildings/orc_guardian_hall_hex_v1/`, **sem integração
no jogo**. É a versão visual orc da mesma construção de tanks dos humanos:
basalto, madeira pesada, ferro e telhado vermelho, emblema de escudo com
presas, torre lateral e pátio aberto com dois manequins e escudos.
Mantém a base militar pointy-top de raio 0,92, diferente do raio 0,84 dos
centros de cidade. São 166 peças editáveis, 2.492 triângulos, 8 malhas e
atlas 2048² nearest. Os scripts `orc_guardian_hall_hex_v1_model.py` e
`_finish.py` usam o Blender MCP; fonte, GLB, relatório e quatro prévias ficam
na pasta do asset. IDs da linha comum de tanks são apenas metadados;
o guardião supremo segue excluído, com prédio próprio. Nenhum catálogo,
regra de treinamento ou seletor de modelo em runtime foi alterado.

O **Salão de Armas dos Orcs** está preparado em
`assets/generated/orcs/buildings/orc_warrior_hall_hex_v1/`, **sem integração
no jogo**. Versão visual orc da construção da linha guerreiro: salão baixo
e largo em basalto/madeira, telhado vermelho transversal, machados cruzados,
abrigo lateral com armas e pátio com dois alvos de combate. Base militar
pointy-top de raio 0,92, sem anel de muralhas; 164 peças editáveis,
2.244 triângulos, 8 malhas e atlas 2048² nearest. Scripts
`orc_warrior_hall_hex_v1_model.py` e `_finish.py` via Blender MCP;
fonte `.blend`, GLB com texturas embutidas, relatório e quatro prévias junto
ao modelo. Os IDs da linha comum de guerreiros são metadados; o herói
supremo permanece no prédio separado de maestria. Nenhum catálogo,
regra de treino ou seleção de modelo em runtime foi alterado.

O **Campo dos Patrulheiros Orcs** está preparado em
`assets/generated/orcs/buildings/orc_ranger_camp_hex_v1/`, **sem integração
no jogo**. Versão visual orc do campo da linha ranged: cabana lateral com
telhado vermelho/presas, emblema de arco e flecha, três alvos vermelhos e
marfim seguindo a borda traseira do hex sob cobertura, pistas de tiro,
suporte de arcos e caixa de munição. Base militar pointy-top de raio 0,92;
181 peças editáveis, 3.532 triângulos, 8 malhas e atlas 2048² nearest.
Scripts `orc_ranger_camp_hex_v1_model.py` e `_finish.py` via Blender MCP;
fonte `.blend`, GLB com texturas embutidas, relatório e quatro prévias
junto ao modelo. A linha comum e o lendário em prédio separado são
metadados; nenhum catálogo, treinamento ou seletor de modelo foi alterado.

O **Estábulo de Guerra dos Orcs** está preparado em
`assets/generated/orcs/buildings/orc_war_stable_hex_v1/`, **sem integração
no jogo**. Duas baias abertas em madeira/basalto, telhado vermelho com ferro
e presas, ferradura do clã e pátio com cercas baixas oblíquas, feno, lanças,
sela e bebedouro. Dois cavalos genéricos estáticos usam somente as malhas
de cavalo/sela/manta de `humans/cavalier_v1`, com pelagem repintada no atlas
e mantas superiores/laterais vermelhas; sem cavaleiro, rig ou animação.
Base militar pointy-top de raio 0,92; 185 peças editáveis, 2.492 triângulos,
8 malhas e atlas 2048² nearest. Scripts `orc_war_stable_hex_v1_model.py`
e `_finish.py` via Blender MCP; fonte, GLB, relatório e quatro prévias
na pasta do modelo. Linha comum de cavaleiros e lendário em prédio separado
são metadados; nenhuma regra de treino ou seleção de modelo foi alterada.

A **Guilda dos Ladinos Orcs** está preparada em
`assets/generated/orcs/buildings/orc_rogue_guild_hex_v1/`, **sem integração
no jogo**. Salão assimétrico em basalto/madeira escura, telhado vermelho-ferrugem em
degraus com presas curtas e cintas vermelhas; emblema de capuz com pequenas
presas e adagas cruzadas. Anexo baixo com toldo e barra vermelha recortada,
alvo de facas, manequim de golpes precisos, bancada com frascos e alçapão
fechado. Base militar pointy-top de raio 0,92; 191 peças editáveis,
2.652 triângulos, 8 malhas e atlas 2048² nearest. Scripts
`orc_rogue_guild_hex_v1_model.py` e `_finish.py` via Blender MCP; fonte,
GLB, relatório e quatro prévias na pasta. Linha comum de ladinos e
lendário em prédio separado são metadados; nenhuma regra de treino,
catálogo ou seleção de modelo em runtime foi alterada.

O **Arsenal de Guerra dos Orcs** está preparado em
`assets/generated/orcs/buildings/orc_siege_arsenal_hex_v1/`, **sem integração
no jogo**. Galpão de montagem aberto em basalto/madeira pesada, telhado
vermelho-ferrugem com presas, engrenagem do clã e pequena chaminé de forja.
Pátio com catapulta reforçada de quatro rodas e colher carregada, guindaste
com eixo suspenso, madeira, roda sobressalente e munição. Base militar
pointy-top de raio 0,92; 223 peças editáveis, 3.576 triângulos, 8 malhas e
atlas 2048² nearest. Scripts `orc_siege_arsenal_hex_v1_model.py` e `_finish.py`
via Blender MCP; fonte, GLB, relatório e quatro prévias na pasta.
Catapulta e guindaste são adereços estáticos. Linha comum de cerco e
lendário em prédio separado são metadados; nenhum catálogo, treinamento
ou seletor de modelo em runtime foi alterado.

O **Salão dos Guardiões dos Anões** está preparado em
`assets/generated/dwarves/buildings/dwarf_guardian_hall_hex_v1/`, **sem
integração no jogo**. Granito com pilares/runa de cobre, telhado de ardósia
escura com cintas de cobre, escudo angular de aço/cobre e centro azul.
Paleta igual à Cidade Anã I. Torre baixa de pedra com merlões quadrados,
estandarte, dois manequins de treino de escudos, marcas de postura e dois
escudos de reserva em suporte lateral. Base militar pointy-top de raio
0,92; 194 peças editáveis, 2.684 triângulos, 8 malhas e atlas 2048² nearest.
Scripts `dwarf_guardian_hall_hex_v1_model.py` e `_finish.py` via Blender MCP;
fonte, GLB, relatório e quatro prévias na pasta. Linha comum de tanks e
herói supremo em prédio separado são metadados; nenhum catálogo,
treinamento ou seletor de modelo em runtime foi alterado.

O **Salão de Armas dos Anões** está preparado em
`assets/generated/dwarves/buildings/dwarf_warrior_hall_hex_v1/`, **sem
integração no jogo**. Salão baixo/largo em granito, telhado transversal
de ardósia escura com cintas de cobre e emblema de machado/martelo cruzados
sobre tecido azul. Paleta igual à Cidade Anã I e ao salão de tanks. Abrigo
lateral com armas, dois manequins de combate com marcas de golpes, pátio
de treino, bigorna de manutenção e estandarte. Base militar pointy-top de
raio 0,92; 193 peças editáveis, 2.520 triângulos, 8 malhas e atlas 2048² nearest.
Scripts `dwarf_warrior_hall_hex_v1_model.py` e `_finish.py` via Blender MCP;
fonte, GLB, relatório e quatro prévias na pasta. Linha comum de guerreiros
e herói supremo em prédio separado são metadados; nenhum catálogo,
treinamento ou seletor de modelo em runtime foi alterado.

As **famílias militares de Anões e Elfos** têm as seis construções comuns:
tanks, guerreiros, patrulheiros, cavaleiros, ladinos e máquinas de guerra.
O [catálogo com prévias](TRAINING_BUILDINGS_CATALOG.md) reúne as pastas,
READMEs e contagens de geometria. Nesta sequência foram acrescentados os
quatro prédios restantes dos anões e os seis dos elfos, mantendo **somente
assets, sem integração no jogo**. Cada pasta inclui fonte `.blend` isolada,
GLB estático, atlas albedo/emissão e quatro prévias.

Os novos layouts de treino adaptam a disposição funcional validada dos
prédios orcs, preservando as fontes anteriores. Anões usam granito,
ardósia escura, cobre, runas quadradas e tecido azul; seus patrulheiros têm
bestas. Elfos usam pedra clara, madeira, verde esmeralda, folhas douradas e
vegetação; o salão de tanks tem um mirante em árvore e o de guerreiros,
espadas esguias. Os cavalos dos estábulos são adereços estáticos genéricos,
sem cavaleiro ou rig; não definem as futuras unidades das civilizações.

Geração sequencial via Blender MCP aberto:
`tools/art_pipeline/run_civilization_training_batch.py`, com helpers
`civilization_training_batch_model.py` e `_finish.py` e wrappers por asset.
O runner recusa cenas existentes para evitar sobrescrever edições.
`verify_civilization_training_batch.py` verifica os doze prédios, todos os
vértices exportados nas seis bordas do tile, transforms identidade,
atlas embutidos iguais aos PNGs, nearest, malhas e ausência de rig/animação;
também confere que os novos nomes não aparecem nos scripts do jogo.

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

- **Face sem UV vira chuvisco no jogo (2026-10-12, "a textura dos orcs tá bugada")**:
  peça acrescentada depois do atlas (presas, olhos, espinhos, argola de arma)
  fica com todas as UVs em (0, 0) do Blender = canto exato da textura. No
  Blender o canto cai sempre no mesmo pixel (a cor de base do atlas) e o
  preview parece certo; no Godot a amostragem `nearest` com repetição oscila
  entre os quatro pixels do canto e a peça vira ruído bege/preto. Atingia as
  20 tropas marciais dos orcs e as 20 dos elfos. Fix sem reexportar:
  `python tools/art_pipeline/fix_unmapped_uv_faces.py --apply` (move essas
  UVs para o centro do maior quadrado liso da mesma cor, só os floats de
  TEXCOORD_0) + `--import`. Os `.blend` de origem NÃO foram alterados: rodar
  a ferramenta de novo depois de qualquer reexportação — o teste
  `test_unit_art_catalog.gd::test_no_troop_model_has_faces_stuck_on_an_atlas_corner`
  falha se o defeito voltar.
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

- **Modelos V3 feitos à mão no Blender (Goblin/Troll, 2026-10)**: não vêm
  da Asset Factory — fontes em `art_source/<nome>/` (com `.gdignore`),
  scripts em `tools/art_pipeline/`, GLB em `assets/generated/<cat>/<nome>_v3/`.
  Diferenças que importam no cadastro: clipes com prefixo
  (`Goblin_Idle`, `Troll_Walk`...), frente já em +Z no glTF →
  `model_yaw_offset_degrees = 0.0` (não 180), e
  `animation_blend_time` (crossfade entre clipes, ver `UnitData.gd`) —
  só funciona limpo porque os 3 clipes animam o MESMO conjunto de ossos;
  conferir isso antes de ligar em outro modelo. Goblin re-exportado com
  `blender 5.2 -b art_source/goblin_raider_v3/goblin_raider_v3.blend
  --python tools/art_pipeline/goblin_raider_export.py` (+ `--import`).
  Mesma receita, já em jogo: Esqueleto (`skeleton_warrior_v1`, também nas
  Hostes), Worg (`warg_v1`), Minotauro e Basilisco (`*_blocky_v1`) — espécies
  novas entram em `MonsterDatabase.HANDMADE_MODELS` (kind → GLB + prefixo dos
  clipes), sem bloco `elif` próprio. Depois: Wyvern, Aranha Gigante,
  Devorador de Mana, Golem (Ancião Arbóreo), Colmeia e Verme de Areia (Verme
  Colossal: sem Walk; `"burrow": true` liga `Worm_Burrow`/`Worm_Emerge` à
  habilidade Escavar via `Unit.play_burrow_visual`/`play_emerge_visual`). **Antes de cadastrar, confira que o `.glb` tem os clipes**
  (`.blend` mais novo que o `.glb` = export desatualizado): a Aranha chegou
  com GLB estático e atlas antigo — re-exportada por
  `tools/art_pipeline/spider_export.py`.
- **Atlas embutido (packed) desatualizado ao repintar no Blender**: mudar os
  pixels de uma imagem que JÁ está packed (`image.pixels.foreach_set`) e chamar
  `image.pack()` de novo mantém os bytes ANTIGOS no pacote. A sessão renderiza
  certo (usa o buffer em memória), mas `.blend` salvo e `.glb` exportado levam o
  atlas velho, que não bate mais com as UVs (textura "embaralhada"). Fix: ao
  repintar, remover a imagem e criar um datablock novo
  (`minotaur_blocky_paint_save.py`); conferir atlas embutido == PNG em disco antes
  de exportar (`minotaur_blocky_export.py`). Checagem de ossos/clipes no Godot não
  pega isso; comparar a textura extraída pelo import com o PNG.
- **Monstro feito à mão grande demais no tabuleiro (2026-10-04)**: a escala vai
  no nó `<NOME>_ROOT` (pai do rig), nunca em `model_scale_multiplier` e nunca
  aplicada na malha. Aplicar escala num armature não escala as keyframes de
  location dos ossos, e a animação quebra. Com o ROOT, malha/UV/rig/clipes
  ficam idênticos: grava-se `"scale"` no nó raiz do JSON do GLB (sem
  re-export) e a mesma escala no `_ROOT` do `.blend`. Valores atuais: Aranha
  0,60, Worg 0,65, Wyvern 0,50, Devorador 0,65, Golem 0,72, Colmeia 0,70.
  Referências aprovadas em 1,0: Minotauro, Troll, Basilisco, Goblin, Esqueleto.
  Hex = 1,73 m de lado a lado: monstro "de 1 tile" ≈ 1,7–1,9 m de pegada.
  **Não exporte com o `_ROOT` escalado**: o exportador glTF do Blender embute a escala
  do pai nos vértices skinned e nas matrizes de bind, e no Godot o modelo sai escalado DUAS
  vezes (o Herói mediu 1,42 m em vez de 1,95 m). Exporte com o `_ROOT` em 1,0 e grave a
  escala só no nó raiz do JSON do GLB, como faz `corrupted_hero_export.py`. Herói Corrompido:
  0,73 → 1,95 m, menor que o Troll.
- **`.blend` dentro de `res://` quebra o `--import` headless** ("Blender
  path is invalid"), abortando o import de TUDO. O projeto só consome
  `.glb`, então `project.godot` tem `filesystem/import/blender/enabled=false`.

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
5. `godot --headless --path . --import` e a auditoria de texturas BC7 (seção 3.1).
6. Cadastrar/atualizar a entrada em `MonsterDatabase.gd` ou `UnitDatabase.gd`
   (seção 3.2), com `model_scale_multiplier = 1.0`.
7. Verificar visualmente (seção 5): screenshot único descartável, de
   preferência ao lado de um personagem de altura já conhecida (ex.: o
   Guarda, 1.8m) pra calibrar a impressão de tamanho a olho — ou usar o
   teleporte de debug (seção 4) direto em uma partida real.
8. Rodar os testes de regressão relevantes (seção 3.3) antes de considerar
   pronto.

## Dragão do evento: modelo com posturas (2026-10-13)

`assets/generated/dragons/dark_red_dragon_v5_animated/` — o Dragão (`MonsterDatabase` kind `dragon`, usado pelo
`DragonEvent`). Não segue a receita `HANDMADE_MODELS` (um Idle/Walk/Attack com prefixo): tem **dois conjuntos** de
clipes, `Dragon_{Idle,Walk,Attack}_{Flying,Ground}`, declarados como posturas em `MonsterDatabase.DRAGON_POSTURES`
(`UnitData.posture_animations`). `Unit.set_posture("flying" | "ground")` troca os três clipes de uma vez e leva o
que está tocando para o equivalente; um golpe em curso termina e cai no parado da postura nova. Outra criatura
com mais de um conjunto de clipes (nadar, escavar...) usa o mesmo mecanismo: só declarar as posturas.

- Escala nativa de 3 m (multiplicador 1,0), frente +Z, transição por captura de pose (as seis animam os mesmos
  159 canais).
- `UnitData.marker_min_height`: a barra de vida e o selo ficam acima das asas no voo (o modelo voando passa da
  altura da caixa em repouso, que é de onde a altura dos marcadores normalmente sai).
- `UnitData.fire_breath_bone` / `fire_breath_start` / `fire_breath_end`: sopro de fogo preso a um osso (eixo +Y
  do osso = para a frente), com a janela em segundos a partir do começo do clipe de ataque.
- O corpo procedural antigo (`_build_dragon_body`, ~650 linhas de caixas e pivôs em `Unit.gd`) foi removido; se o
  GLB sumir, o Dragão cai no corpo genérico com aviso, como qualquer modelo ausente.

## Grandes Manifestações: os seis modelos animados em jogo

`assets/generated/grand_manifestations/<nome>/<nome>.glb`, um por Manifestação, o mesmo para as quatro raças.
Cadastro em um lugar só: `UnitDatabase.MANIFESTATION_MODELS` (kind → pasta) + `_apply_manifestation_model`.
Escala nativa de 3 m (não normalizar: asas e faixas abertas dobram a caixa), frente +Z, quatro clipes
(`Idle`/`Walk`/`Attack`/`Spell`; o Primordial exporta em minúsculas) sobre o mesmo conjunto de ossos.

As trocas de estado usam captura de pose (`UnitData.pose_transition_time`,
`scripts/units/PoseCaptureTransition.gd`), não o crossfade das tropas. Ao trocar um desses modelos, confira que
os quatro clipes continuam animando os MESMOS ossos — `test_grand_manifestations_in_game.gd` falha se não, e
mede se algum osso salta na troca. Para ver em jogo: painel de Debug → "Invocar Grande Manifestação" (quantas
quiser, sem custo) e "Animação da unidade selecionada" (inclui o Attack, que nenhuma regra dispara).

## Magos das escolas: animações dos modelos aprovados

Os 24 magos em `assets/generated/{humans,elves,dwarves,orcs}/` possuem
`idle` (3 s, loop), `walk` (1,5 s, loop no lugar) e `spell` (3 s, execução
única). Cada raça compartilha o casting entre suas seis escolas. As malhas,
UVs, normais e texturas aprovadas foram preservadas; o rig usa 16 ossos com
pesos rígidos para manter as formas blocky. O GLB continua com uma malha,
uma superfície e um material. Escala nativa em metros, multiplicador 1,0;
não normalizar pela altura do chapéu ou do cajado.

As fontes Blender usam 48 fps e trilhas NLA `idle`, `walk`, `spell` nos
intervalos 1–145, 161–233 e 241–385. A liberação está marcada em
`SPELL_RELEASE` e registrada em `animation.spell_release_seconds` no
relatório: humano 1,68 s, elfo 1,74 s, anão 1,62 s, orc 1,80 s. O post-import
`tools/art_pipeline/school_mage_animation_import.gd` configura os loops e
nearest com mipmaps. Preserve os arquivos `.glb.import` ao reutilizar.

A revisão completa fica em `art_source/school_mages_animation_review/`,
com uma cena Blender dos 24, galeria animada e backup anterior à animação.
As cenas raciais de revisão também estão animadas. Os scripts
`animate_school_mage_mcp.py`, `school_mage_motion.py` e
`finish_school_mage_animation_mcp.py` trabalham pelo MCP do Blender aberto,
um modelo por vez. `docs/school_mages_animation_*_validation.json` registra
geometria, texturas, poses, continuidade, pés e contato mão/cetro, além da
conferência dos 72 clips no Godot. O cadastro de unidades não é alterado
por essa etapa de produção dos assets.

A revisão 3 dos movimentos corrige a torção dos antebraços dos magos. No
casting, ambos os braços usam ombro articulado e cotovelo de eixo fixo; a
mão segue o antebraço, com pequeno movimento de punho na mão livre. O eixo
do cotovelo é perpendicular ao antebraço original. Continuidade de matrizes
e checksum de malha não garantem um movimento anatômico: a revisão também
mede torção axial, rotação relativa do punho, velocidade/aceleração angular
entre frames e cruzamentos de mão/antebraço com o torso. Confira as prévias
de frente e de lado, especialmente nos antebraços largos dos anões.
