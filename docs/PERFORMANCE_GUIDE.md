# Guia de Performance

## Rodada de lag pós-monstros/defesa/cidades — 19/09/2026

Sintoma reportado: lag em jogo depois das features de monstros, defesa de
cidade, escolha de sítio e inspeção de tile. Padrão em todos os achados:
**algo refeito por inteiro a cada movimento, frame ou turno**. Medido com o
benchmark da seção 1 (mapa Grande 320×84, seed 4242, 3 rivais; janela real,
V-Sync off, GPU ≈ 4 ms/frame → o teto de FPS é GPU, ~215 fps) e com uma
campanha headless de 100 turnos (encerra por vitória/derrota por volta do
turno 80). O profiler foi um wrapper temporário (script que renomeia
`func x` → `_perf_original_x` e acumula `Time.get_ticks_usec()` num dicionário
estático; **restaurar do backup logo depois de cada rodada** e conferir com
`grep _perf_original_ scripts`) — apagado no fim.

| Gargalo | Antes | Depois | Técnica |
|---|---|---|---|
| Minimapa: `_draw` redesenhava os ~27 mil tiles a cada frame com a câmera em movimento | ~63 ms/frame (mapa revelado; 5,1 ms sem o minimapa) | 4,75 ms/frame (`revealed_pan`, mesmo cenário) | Tiles numa `Image` persistente; indicador/unidades desenhados ao vivo (`Minimap.gd`) |
| Minimapa: cada `fog_updated` (= cada passo de unidade) re-rasterizava todos os tiles (versão intermediária com SubViewport tinha o mesmo custo, ~60 ms com o mapa revelado — inferido do loop, não medido isolado) | proporcional aos tiles explorados | só os tiles do delta (`HexGrid.last_fog_changed`); imagem inteira só quando `last_fog_was_full` (mapa novo/carregado), redimensionar ou reiniciar | Delta explícito exposto pelo `HexGrid` |
| Fog: `_rebuild_liquid_type_texture`/`_rebuild_biome_overlay` recriavam a textura inteira mesmo sem mudança de visão | ~46 ms/chamada (medição do Codex) | sem mudança: retorna cedo; com mudança: reescreve só os pixels dos tiles alterados e faz `ImageTexture.update` | `_last_fog_visibility` + `changed`; teste byte a byte contra a reconstrução completa (`test_incremental_fog_textures_match_a_full_rebuild`) |
| `compute_path` para destino em outra ilha varria o continente inteiro | ~77 ms | ~0 | Componentes conexos por `blocks_land_units()` (`_ensure_land_components`), calculados no `generate_map` (tela de loading) e invalidados só quando uma transformação muda se o tile bloqueia terra |
| `compute_path` para destino **emparedado** (cidade cercada pelas próprias unidades, que o A* trata como parede; `defend_against_dragon` → `move_unit_toward`, por unidade, por turno) | 49 buscas falhas > 30 ms, até 83 ms cada; turnos 41–60: 2,0 s em `compute_path` | 0 buscas > 30 ms; 0,63 s | BFS reverso limitado a partir do destino (`_destination_walled_in`: limite 16 antes do A*, 256 depois de 150 nós expandidos). Bolsos medidos: 1–59 tiles. É superestimativa do alcance — nunca dá falso "inalcançável" |
| Pior turno da campanha (`_on_turn_changed`) | 807 ms | 303 ms | (efeito dos dois itens acima) |
| Primeiro turno: componentes terrestres montados no primeiro `compute_path` | frame de 52 ms | 27 ms | Movido pro `generate_map` |
| Abrir Magia/Tecnologia reconstruía as DUAS árvores (~60 cards cada) | pico de ~80 ms | ~49 ms na 1ª abertura; reabrir sem mudança não reconstrói | `HUD._refresh_tech_panel` só reconstrói a árvore do painel aberto e só se a assinatura (`hash` de pesquisados/pesquisa atual/progresso/raça/debug) mudou |

**Ainda não tocado (candidatos, na ordem do que mais custa):**
- `recompute_fog` ≈ 17 ms por chamada, um frame por turno (e por passo do
  humano): as texturas já são por delta, mas `_apply_terrain_fog`,
  `_apply_prop_fog` (~4,5 ms) e `_update_city_tint` (mesh de todas as cidades)
  ainda rodam inteiros. Cuidado: pular quando `changed` está vazio vaza props
  recém-criados sem névoa e ignora crescimento de território.
- `RivalAI.defend_against_dragon` manda toda unidade longe da cidade "voltar"
  a cada turno; unidades que não conseguem entrar repetem a tentativa (agora
  barata, mas ainda ~0,7 ms/chamada nos turnos 41–60).
- `SaveManager.load_game` ≈ 2,9 s (é o `generate_map`; fora de escopo, seção 5).

---

## Revisão de integração — 17/09/2026

- `HexGrid.compute_path` rejeita destinos ocupados, inexistentes, cidades
  estrangeiras e terreno incompatível antes de iniciar A*. Um destino ocupado
  no mapa 320×84, seed 4242, caiu de 77,394 ms para 0,008 ms; o resultado vazio
  permaneceu igual. Isso mede esse caso específico, não todo movimento.
- A campanha real seed 4242 chegou a executar 100 turnos em 63,741 s, com pior
  turno de 5,160 s, após a correção de caminhos. Uma execução anterior levou
  449,950 s; pesquisa/decisões também mudaram entre as duas, portanto essa
  diferença de campanha não isola o ganho do A*.
- A preparação contra o Dragão usava outro caminho de produção e ignorava o
  limite militar normal. Foi limitada a uma reserva proporcional às cidades,
  preservando produção militar já iniciada. Resultados finais das campanhas
  estão em `DEVELOPMENT_STATUS.md`.
- Transformações mágicas atualizam árvores e altura de recursos somente nos
  hexágonos alterados, em uma atualização adiada por lote. Não regeneram a
  decoração inteira do mapa.
- Vazamentos reais corrigidos: referências circulares entre jogadores e
  fixtures que não liberavam mapas, unidades e painéis. A suíte de 1.325 testes
  após essa correção encerrou sem aviso final de ObjectDB/recursos e sem órfãos
  no resumo. Contagens transitórias do GUT antes do processamento de `queue_free`
  não são, isoladamente, vazamentos.
- Estas medições são de CPU em execução headless. Não medem FPS de uma partida
  renderizada nem comprovam a duração humana pretendida de 3–4 horas.

### Encerramento do áudio

Uma campanha com vitória humana deixou quatro objetos e dois recursos. O log
`--verbose` identificou exclusivamente `AudioStreamPlaybackOggVorbis`,
`OggPacketSequencePlayback`, `OggPacketSequence` e `victory.ogg`. Reproduzido em
processo pequeno, sem mapa; unidades e edifícios foram descartados separadamente
sem vazamentos.

O caso corresponde ao [problema de encerramento de áudio #76745](https://github.com/godotengine/godot/issues/76745).
O mixer retira playbacks em uma atualização posterior; chamar `stop()` durante
a destruição da árvore não basta, conforme a [investigação do motor](https://github.com/godotengine/godot/pull/122742).

`AudioManager.request_quit()` encerra a partida, impede novos sons, para os
players e concede ao mixer pelo menos 100 ms reais (ou duas latências de saída)
antes de fechar. Vale para Sair no título, pausa e fechamento da janela. O prazo
usa relógio real porque o delta do primeiro frame pode incluir o carregamento e
expirar um timer imediatamente. Não foram desligados áudio nem avisos do motor.

Regressão reproduzível, incluindo saída em pausa:

```powershell
& $godot --headless --verbose --path . -s tools/verify_audio_shutdown.gd
```

Reprodutor antes: exit 1, quatro objetos/dois recursos. Após a correção: exit 0,
sem avisos de vazamento. `GameManager.end_match()` também para os sons ao voltar
ao menu. O harness de campanhas usa `drain_audio()` antes de fechar a execução.

---

Documento vivo (mesma convenção do `GAME_DESIGN_BIBLE.md`): registra o que
já foi otimizado, COMO foi medido, e o que ainda não foi tocado — pra uma
próxima rodada de performance não redescobrir os mesmos gargalos nem gastar
tempo remedindo o que já tem número. Quando otimizar algo novo, adicione
aqui no mesmo commit (nome do gargalo, custo antes/depois, técnica usada).

---

## 0. A distinção mais importante: dois problemas diferentes

Antes de mexer em qualquer coisa, separe qual dos dois você está de fato
atacando — são gargalos completamente diferentes, com ferramentas e
sintomas diferentes, e uma otimização de um **nunca** move o número do
outro:

1. **Travadela/soluço num evento discreto** (passar o turno, passar o mouse
   sobre um tile novo, abrir um painel) — isto é **CPU**, um pico de tempo
   num único frame. Sintoma: o jogo "engasga" por um instante especificamente
   quando você faz aquela ação. Se perfila com `Time.get_ticks_usec()` em
   volta da função suspeita (seção 2).
2. **Teto de FPS constante olhando o mapa parado** (ex.: sempre ~140fps,
   não importa o que aconteça) — isto é **V-Sync ou GPU**, não CPU. Reduzir
   custo de CPU aqui **não muda o número no canto da tela** — só libera
   folga que o V-Sync já estava jogando fora. Ver seção 4.

**Confundir os dois desperdiça a rodada inteira**: otimizar CPU esperando
o contador de FPS subir (não vai subir, se o teto for V-Sync) ou desligar
V-Sync esperando resolver uma travadela de fim de turno (não resolve, o
frame ainda vai levar 190ms pra processar, só sem sincronizar com a tela).

---

## 1. Como medir (headless, sem depender de "parece mais fluido")

Toda otimização deste documento foi validada com um benchmark descartável
rodado **headless** (sem GPU/janela, só CPU) — mesma disciplina de
"confirme, não adivinhe" usada no resto do projeto. Roteiro pra recriar:

1. Escrever um `Node` (`scripts/_perf_bench.gd` + `scenes/_perf_bench.tscn`,
   prefixo `_` = descartável, apagar no fim — mesma convenção de qualquer
   script de verificação deste projeto) que:
   - Cria um `HexGrid` real, gera um mapa **Grande de verdade** (320x84 —
     ver `TitleScreen.MAP_SIZES.large`) com 3 rivais — o pior caso real do
     jogo, não um mapa de teste pequeno que esconde custo O(n).
   - Cronometra cada função suspeita com `Time.get_ticks_usec()` antes/depois,
     em `reps` repetições pegando o **menor** tempo (evita ruído de
     GC/scheduler do SO inflando a primeira leitura).
2. Rodar: `godot --headless --path . scenes/_perf_bench.tscn`.
3. Depois de qualquer otimização: **reimplementar o algoritmo ANTIGO num
   script à parte** e comparar byte-a-byte a saída contra o novo (ex.:
   `PackedByteArray` de uma textura, `Dictionary` de um resultado) —
   não confie em "parece igual", confirme que é **idêntico**. Esse
   script de equivalência também é descartável.
4. Rodar a bateria de testes GUT relevante (fog, movimento, geração de
   terreno, condições de vitória, etc.) antes de considerar terminado.
5. Apagar os scripts `_perf_bench.gd`/`_overlay_equiv.gd`/etc. e confirmar
   com `git status --porcelain` que não sobrou nada — são ferramentas de
   diagnóstico, não fazem parte do jogo.

Esqueleto reaproveitável do benchmark (cole, adapte a lista de funções
cronometradas ao que você está investigando desta vez):

```gdscript
extends Node

func _t(label: String, f: Callable, reps: int = 1) -> void:
    var best := 1e18
    for i in range(reps):
        var t0 = Time.get_ticks_usec()
        f.call()
        best = min(best, Time.get_ticks_usec() - t0)
    print("%-42s %8.2f ms" % [label, best / 1000.0])

func _ready() -> void:
    var hex_grid := HexGrid.new()
    add_child(hex_grid)
    hex_grid._ready()
    GameManager.hex_grid = hex_grid
    GameManager.map_width = 320
    GameManager.map_height = 84
    GameManager.rival_count = 3
    GameManager.stagger_ai_turns = false

    _t("generate_map 320x84", func(): hex_grid.generate_map(320, 84, 4242))
    _t("start_new_game", func(): GameManager.start_new_game(hex_grid))
    _t("recompute_fog", func(): hex_grid.recompute_fog(GameManager.human_player), 3)
    _t("TurnManager.end_turn (sync, all AI)", func(): TurnManager.end_turn())
    # ... adicione aqui a funcao especifica que voce suspeita, chamando
    # direto (nao so via end_turn) pra isolar o custo dela sozinha.
    get_tree().quit()
```

Pra medir FPS de teto/V-Sync (categoria 2, não CPU) — precisa de janela de
verdade, **não headless**:

```gdscript
extends Node
func _ready() -> void:
    print("vsync_mode=%s" % DisplayServer.window_get_vsync_mode())
    var main = load("res://scenes/main/Main.tscn").instantiate()
    add_child(main)
    await get_tree().create_timer(2.0).timeout
    for i in range(5):
        await get_tree().create_timer(0.5).timeout
        print("fps=%d" % Engine.get_frames_per_second())
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    await get_tree().create_timer(1.0).timeout
    for i in range(5):
        await get_tree().create_timer(0.5).timeout
        print("fps=%d (vsync off)" % Engine.get_frames_per_second())
    get_tree().quit()
```
Rodar com `godot --path . scene.tscn` (sem `--headless`).

---

## 2. O que já foi otimizado (CPU, eventos discretos)

Todos medidos no cenário do benchmark acima (Grande 320x84, 3 rivais,
`stagger_ai_turns = false`, caminho síncrono). Números "antes" são do
estado do código ANTES desta rodada — já incluíam otimizações de rodadas
anteriores (ver os comentários "perfilamento real" espalhados no código,
alguns datam de "usuário reportou 140→15/20fps na troca de turno").

### 2.1 `HexGrid.compute_path` — Dijkstra puro → A* (`scripts/world/HexGrid.gd:740`)

- **Custo antes**: ~43ms por chamada (destino a ~30 tiles de distância
  num mapa Grande).
- **Quando roda**: a cada tile NOVO sob o mouse fora do alcance do turno
  atual (`SelectionManager.handle_world_hover`, prévia "MOVER (N
  hexágonos)"), e uma vez por unidade com ordem de movimento pendente ou
  explorando a cada troca de turno (`continue_move_order`/`explore_step`).
- **Causa**: Dijkstra sem heurística nenhuma — expande o grafo inteiro até
  achar o destino, mesmo pra um destino "na direção óbvia".
- **Fix**: A* de verdade. Heurística = `HexMetrics.axial_distance(coord, end)`
  — **admissível e consistente** porque todo passo custa `>= 1`
  (`movement_cost` é `int >= 1`, `flies` paga `1.0` fixo — nunca existe um
  passo de custo fracionário menor que a heurística subestimaria). Isso
  significa: o heap guarda `[g + h, coord]` em vez de só `[g, coord]`, e um
  `closed` set descarta pops repetidos — com heurística consistente, a
  PRIMEIRA vez que um nó sai do heap já é definitiva, sem precisar
  relaxar de novo. Mesmo caminho de custo mínimo de sempre, só visita uma
  fração dos nós.
- **Custo depois**: ~2.5ms.
- **Lição pra próxima vez**: qualquer busca em grafo neste projeto que
  tenha uma heurística barata e admissível óbvia (distância em linha
  reta/hexagonal até o alvo) deveria ser A*, não Dijkstra puro — o padrão
  "heap com custo puro" foi copiado outras vezes no código
  (`compute_reachable` não precisa, já que não tem UM destino só; mas
  qualquer future busca ponto-a-ponto deveria nascer já como A*).

### 2.2 `HexGrid._rebuild_water_overlay` — reconstrução completa a cada hover → só os pixels destacados (`scripts/world/HexGrid.gd:4031`)

- **Custo antes**: ~99ms por chamada (mapa Grande, hover com unidade
  selecionada).
- **Quando roda**: a cada tile novo sob o mouse enquanto uma unidade está
  selecionada (`SelectionManager.handle_world_hover` → `set_highlight` →
  `_rebuild_water_overlay`) — ou seja, **potencialmente a cada poucos
  frames** enquanto o jogador move o mouse sobre o mapa, não só em eventos
  raros.
- **Causa**: a função reconstruía DUAS coisas juntas a cada chamada —
  (a) o canal de neblina de guerra (`liquid_type_texture`, que só muda
  quando `visibility` muda de verdade — fim de turno, Debug) e (b) o
  destaque de movimento/ataque/construção (que muda a cada hover) — ambas
  varrendo os `WATER_OVERLAY_RESOLUTION²` = 50176 pixels da textura
  inteira, mesmo quando (a) não tinha mudado NADA desde a última chamada.
- **Fix, duas partes**:
  1. Separou as duas responsabilidades: `_rebuild_liquid_type_texture()`
     (nova função, canal de neblina) só é chamada de `_apply_fog_colors()`
     (fim de turno/Debug) — nunca mais do hover. `_rebuild_water_overlay()`
     ficou responsável SÓ pelo destaque.
  2. `_rebuild_water_overlay` agora escreve só os pixels dos tiles
     REALMENTE destacados, em cima de um **baseline cacheado**
     (`_water_overlay_baseline_bytes`, que já existia) — usando um mapa
     inverso novo, `_water_overlay_pixels_by_coord: Dictionary` (coord ->
     `PackedInt32Array` de índices de pixel, construído uma vez em
     `_ensure_water_overlay_coord_cache`), em vez de varrer os 50176
     pixels perguntando "esse pixel está destacado?" um por um.
- **Custo depois**: ~0.3ms.
- **Lição pra próxima vez**: **"mapa inverso coord → pixels" é o padrão
  geral** pra qualquer textura-por-tile onde só um SUBCONJUNTO pequeno de
  tiles muda por chamada — construa o mapa inverso uma vez (junto do coord
  cache que já existe) e escreva só os pixels que mudaram, nunca reprocesse
  a textura inteira pra uma mudança pontual.

### 2.3 `HexGrid._rebuild_liquid_type_texture` / `_rebuild_biome_overlay` — pixel-a-pixel → guiado por coordenada (`scripts/world/HexGrid.gd:4076` e `:4140`)

- **Custo antes**: `_rebuild_liquid_type_texture` ~37.5ms, `_rebuild_biome_overlay`
  ~12ms (chamadas 1x por fim de turno, não mais a cada hover depois do
  fix 2.2).
- **Causa**: mesmo padrão de sempre — loop sobre TODOS os pixels da
  textura (`WATER_OVERLAY_RESOLUTION²`/`BIOME_OVERLAY_RESOLUTION²`)
  chamando `_fog_level_for(coord)` uma vez por PIXEL, quando várias
  centenas de pixels mapeiam pro MESMO tile (a água tem ~1.87 pixels por
  tile nessa resolução).
- **Fix**: mesmo mapa inverso coord→pixels de 2.2, agora também pro canal
  de bioma (`_biome_overlay_pixels_by_coord`, novo). `_fog_level_for(coord)`
  chamado **uma vez por coordenada única**, replicado pros pixels daquele
  tile — não uma vez por pixel.
- **Custo depois**: `_rebuild_liquid_type_texture` ~18ms, `_rebuild_biome_overlay`
  ~10ms. (Ganho menor no bioma porque `BIOME_OVERLAY_RESOLUTION` = 128 já
  é baixa de propósito — poucos pixels por tile pra começo de conversa,
  ver o comentário da própria constante.)
- **Verificação**: comparação byte-a-byte contra uma reimplementação
  literal do loop antigo (pixel-a-pixel) — resultado idêntico nos três
  canais (água/destaque, água/neblina, bioma/neblina) antes de aceitar
  como correto.
- **Se for otimizar mais**: `_apply_prop_fog`/`_apply_terrain_fog` ainda
  não usam esse padrão (varrem os próprios `coord_to_index`/instâncias,
  já são O(tiles do tipo) em vez de O(resolução²), então o ganho relativo
  seria bem menor — não valeu a pena nesta rodada, ~4ms e ~2ms
  respectivamente).

### 2.4 `GameManager._update_victory_state` — varredura do mapa inteiro por jogador → cache (`scripts/world/HexGrid.gd:212`, `scripts/core/VictoryConditions.gd:112`)

- **Custo antes**: ~135ms por fim de turno (mapa Grande, 4 jogadores) —
  **a maior fatia isolada de todo `_on_turn_changed`**, maior até que a
  soma de todas as fases de IA/produção/pesquisa juntas.
- **Causa**: `VictoryConditions.total_habitable_tiles(hex_grid)` varre os
  26880 tiles do mapa inteiro chamando `blocks_land_units()` em cada um —
  e é chamada **uma vez por jogador** (`_update_territorial_streak`, para
  humano + 3 rivais) dentro do MESMO `_update_victory_state()`, sempre
  devolvendo **exatamente o mesmo número** (é uma propriedade do MAPA, não
  do jogador) — ou seja, 4 varreduras completas idênticas por turno.
- **Fix**: cache memoizado em `HexGrid` (`_cached_total_habitable_tiles`,
  `-1` = "precisa recalcular"), lido via `hex_grid.total_habitable_tiles_cached()`.
  `VictoryConditions.territorial_percentage()` (usada tanto pelo streak
  quanto pela barra de progresso na UI) passou a chamar essa versão
  cacheada em vez de `total_habitable_tiles()` direto. Invalidado em
  `generate_map()` (mapa novo) e em `transform_tile_terrain()` (um tile
  pode cruzar a fronteira habitável/intransponível — nenhuma transformação
  hoje cruza essa fronteira de verdade, mas invalidar é O(1) e evita cache
  desatualizado silencioso se isso mudar).
- **Custo depois**: ~0.1ms.
- **Lição pra próxima vez**: **qualquer função que recebe `hex_grid` como
  parâmetro e devolve um número que só depende do MAPA (não do jogador,
  não do turno) é candidata a cache em `HexGrid`** — o padrão "chamada
  repetida devolvendo o mesmo resultado" é fácil de não perceber quando a
  função em si parece rápida isolada (uma varredura de 26880 tiles não
  "parece" lenta até multiplicar pelo número de chamadores).

### 2.5 `HUD._process` — texto/estado de botão reescritos todo frame (`scripts/ui/HUD.gd:420`)

- **Causa**: `end_turn_button.text`/`.disabled` eram reatribuídos **todo
  frame**, mesmo quando o valor não mudava — `Control.text`/`.disabled`
  disparam invalidação de layout/redraw internos do Godot mesmo
  reatribuindo o MESMO valor.
- **Fix**: só escreve quando o valor calculado difere do atual (`if
  end_turn_button.disabled != should_disable: ...`). `fps_label.text`
  ficou de fora de propósito — FPS muda genuinamente todo frame (ou perto
  disso), não há nada a ganhar comparando antes de escrever ali.
- **Escala**: pequeno isolado (não cronometrado em ms — o custo é de
  invalidação de layout, não fácil de medir com `Time.get_ticks_usec()`),
  mas é **todo frame, o jogo inteiro**, não só durante troca de turno —
  categoria diferente dos itens acima (throughput constante, não pico
  pontual).
- **Se for otimizar mais**: procure esse padrão (`Control.propriedade =
  valor_recalculado` dentro de `_process`/`_physics_process` sem
  comparação antes) em outras telas — `RTSCamera._process` e
  `GameManager._process` já são gateados por early-return quando não há
  trabalho (ver seção 3), mas não foi feita uma varredura exaustiva de
  TODA UI por esse padrão especificamente.

### 2.6 `V2EconomyRuntime` — Déficit recalculado por cidade → uma vez por consulta (Aetherlands V2, Fase 15)

- **Causa**: com o Déficit de Ouro (Fase 15), a renda de cada cidade passou
  a checar `is_gold_deficit(dono)` pra saber se desconta os prédios com
  upkeep — e `is_gold_deficit` soma TODAS as cidades do dono. Toda
  agregação por jogador (`player_supply_capacity`, `player_gold_income`...)
  virou O(cidades²) quando o caixa está zerado (sem o atalho `gold > 0`).
  Como a Tensão Logística consulta a capacidade, isso chegava em cada
  `CombatResolver.predict` com unidade que tem Suprimentos.
- **Fix**: `_player_branch_income` decide o Déficit UMA vez e passa o
  booleano pra `_city_branch_income(city, branch, base, deficit)`; as
  consultas de uma cidade só (`city_*_income`) calculam o do próprio dono.
  Sem cache, sem estado — o resultado é idêntico (coberto pela suíte).
- **Escala** (6 cidades, caixa zerado, mapa Grande): `player_supply_capacity`
  0,77 → 0,17 ms; `CombatResolver.predict` com atacante com Suprimentos
  0,93 → 0,33 ms (caminho rápido, sem custo: 0,048 ms). Tabela completa
  (20/40/60 unidades) em `docs/AETHERLANDS_V2_IMPLEMENTATION.md`, Fase 15.
- **Se for otimizar mais**: o que sobra é `player_supply_used` (percorre as
  unidades do jogador, ~0,1 ms com 60) + o próprio `is_gold_deficit`
  (~0,2 ms com caixa zerado). Um cache transitório só se justifica se a IA
  passar a fazer centenas de previsões por turno — e, se criado, nunca
  salvo, invalidado em evento discreto e comparado contra o cálculo bruto
  em teste (regra do §120 da Fase 15).

### 2.7 `CityDefense.city_attack_targets` — neblina recalculada → neblina já calculada (Aetherlands V2, Fase 16)

- **Causa**: a primeira versão do Ataque da Cidade filtrava os alvos do
  humano com `HexGrid.compute_visible_tiles` (união do raio de visão de
  TODAS as unidades/cidades) — 3,3 ms no mapa Grande, pago a cada refresh
  do botão da cidade, início de mira e disparo.
- **Fix**: `CityDefense._visible_to_owner` usa a MESMA regra de
  `V2TechniqueRuntime._visible_to_owner`: lê `HexGrid.visibility` (o dict
  que `recompute_fog` já mantém), O(1) por tile, só pros tiles do alcance
  (`HexMetrics.coords_within`). IA/partida sem neblina: sem filtro.
- **Escala**: `city_attack_targets` da Fortaleza humana (alcance 3) 0,047 ms;
  IA 0,016 ms. Regra geral: **nunca** chame `compute_visible_tiles` em
  caminho de UI/clique — use `HexGrid.visibility`.
- Custo novo por turno da Fase 16: só a regeneração de escudo (caminho
  pré-existente) em mais cidades, ~0,12 ms por cidade fortificada. Tabela
  completa em `docs/AETHERLANDS_V2_IMPLEMENTATION.md`, Fase 16.

### 2.8 Custo de terreno variável (modificações de terreno V2, Fase 20) — o que muda no pathfinding

- **O que mudou**: todo custo de passo terrestre passa por
  `HexGrid.terrain_step_cost(coord)` = custo-base + modificação V2
  (`HexGrid.v2_terrain_modifications`, dicionário por coordenada). Caminho
  rápido: mapa sem modificação = custo-base puro (0,7 µs); com modificações,
  lookup O(1) (2,7 µs). Nada é recalculado ao criar/remover uma modificação
  (não há cache de caminho) e nenhum `_process`.
- **O efeito real não é o lookup, é o A***: `compute_path` usa heurística de
  1 por passo (admissível porque todo passo custa ≥ 1). Enquanto todo terreno
  custava 1, a heurística era exata e o A* expandia quase só a rota. Uma rota
  longa **inteiramente** coberta por Bosque (custo 2) passou de 0,51 ms para
  3,8 ms no mapa Grande (320×84, seed 4242): com custos > 1 a heurística fica
  folgada e o A* explora os desvios de mesmo custo. `unit_reachable`
  (Movimento 4) subiu só 17% (1,27 → 1,49 ms). Não subir a heurística: ela
  deixaria de ser admissível (caminhos subótimos).
- **Se um dia virar gargalo** (muitas modificações + IA pedindo muitas rotas
  longas): o próximo passo seria limitar a busca da IA, não mexer no custo.
  Turno completo sync com 3 IAs e 76 tiles modificados: 38,6 ms (patamar das
  fases anteriores). Tabela em `docs/AETHERLANDS_V2_IMPLEMENTATION.md`, Fase 20.

### 2.9 IA V2 orientada a eventos (Fase 24)

- `V2StrategicAI` roda uma vez por rival/turno; `V2AITacticalAI` só é consultada
  quando a unidade age. Nenhum `_process`, `Timer` ou varredura global por frame.
- `V2AIWorldView` calcula visibilidade uma vez no início do turno tático e é
  reutilizada pelas unidades desse rival. A camada expõe só unidades visíveis,
  cidades conhecidas e eventos públicos, nunca economia/pesquisa inimiga.
- Benchmark headless controlado: WorldView/12 inimigos **0,231 ms**; score dos
  128 nós **1,419 ms**; alvo estratégico **0,047 ms**; tentativa tática vazia
  **0,010 ms**; plano estratégico de 1 rival **1,227 ms** e de 3 rivais
  **3,910 ms**.
- Long-run real de 150 turnos (3 rivais, save/load no 60): **13,2 s** totais,
  máximo de 7 fichas militares relevantes por rival, cidades até nível IV e
  nenhum crescimento explosivo. O limite normal é 20 e o hard stop é 24;
  unidades já em fila contam antes de uma nova decisão de produção.
- Benchmark reproduzível: `test/integration/benchmark_v2_ai.gd`; estabilidade:
  `test/integration/test_v2_ai_long_run.gd`.

### 2.10 Migração final V1→V2 (Fase 25) — só remoção, nada otimizado

- A fase removeu caminhos (Ciência, população/comida/tiles trabalhados, decisores V1
  da IA, magia/comércio V1); nenhum `_process`, polling ou cache novo.
- Mesmo benchmark de IA da 2.9, igual ou melhor: WorldView **0,213 ms**; score
  dos 128 nós **1,169 ms**; plano de 1 rival **1,082 ms**, de 3 rivais **3,464 ms**.
  Long-run de 151 turnos: **10,6 s** (antes 13,2 s).
- Novo `test/integration/benchmark_v2_phase25.gd` (mapa real 61×61): turno real
  mediano **22–24 ms** com 0/1/3 rivais; refresh da HUD **0,06 ms**; clique no
  painel de cidade **11,6 ms** (custo pontual, sem baseline anterior); quadro de
  pesquisa abrir+fechar **1,8 ms**; save **4,1 ms**; load **665 ms** (regenera o
  mapa pela semente).

---

## 3. `_process`/`_physics_process` já auditados (nenhuma mudança feita, documentando pra não re-auditar)

- **`RTSCamera._process`**: pan/rotação só fazem trabalho se alguma tecla
  relevante está pressionada (`if input_dir == Vector3.ZERO: return`)
  — já correto.
- **`GameManager._process`**: só faz algo quando `is_turn_processing`
  (drenando a fila de IA em lotes, `stagger_ai_turns`) — já correto,
  vazio (`if not is_turn_processing: return`) no caso comum.
- **`LoadingSpinner._process`**: só anima quando `is_visible_in_tree()`
  — já correto.
- **`HexGrid._process`**: só faz trabalho se o marcador de seleção está
  visível ou há marcador de construção ativo — escala com o número de
  OBRAS em andamento (`_construction_markers.size()`), não com o mapa
  inteiro; não investigado a fundo (número de obras simultâneas costuma
  ser pequeno), candidato a olhar numa partida tardia com muitas cidades
  construindo ao mesmo tempo.

---

## 4. Categoria 2: teto de FPS / V-Sync (medido, NÃO otimizado ainda)

Medido uma vez (ver seção 1, script de FPS) no estado do jogo depois de
TODAS as otimizações da seção 2:

| Config | FPS |
|---|---|
| V-Sync ligado (padrão do projeto) | ~142 |
| V-Sync desligado | ~177-179 |

**Conclusão**: o teto de ~140fps relatado pelo usuário ("achei que ia
subir pra uns 200") é **inteiramente V-Sync**, sincronizado com a taxa de
atualização do monitor — nenhuma otimização de CPU muda esse número
enquanto V-Sync está ligado, não importa quanto tempo de frame seja
economizado (o motor só apresenta o frame no próximo pulso de vertical
sync de qualquer forma). As otimizações da seção 2 resolvem
**travadelas/soluços** (frames que estouram o orçamento e derrubam FPS
temporariamente), não o teto de regime permanente.

**O que foi feito**: adicionado toggle de V-Sync em Configurações
(`Settings.gd::vsync_enabled` + `SettingsScreen.tscn`, ver
`scripts/autoload/Settings.gd`) — jogador pode desligar pra ver o teto
real (~178fps medido), ciente do trade-off de *tearing*.

**O que NÃO foi feito** (categoria em aberto pra próxima rodada, se o
pedido for "quero mais que 178fps de teto de verdade, não só destravar o
V-Sync"): essa é uma investigação de **GPU/renderização**, ferramentas e
lugares completamente diferentes da seção 2:
- `scenes/main/Main.tscn`'s `Environment` (`Env1`): SSAO ligado
  (`ssao_intensity=1.4`), SSR ligado (`ssr_max_steps=32`), Glow ligado,
  fog volumétrico ligado, sombra direcional com filtro suave — cada um
  tem custo de GPU real, nenhum foi perfilado ainda (precisa de um
  profiler de GPU de verdade, ex.: RenderDoc, ou desligar um de cada vez
  e comparar FPS sem V-Sync — `Time.get_ticks_usec()` no CPU não vê
  custo de GPU).
- Contagem de instâncias `MultiMeshInstance3D` (terreno + árvores/pedras/
  props por tipo de recurso) — não medida quanto cada uma custa de
  desenho.
- Complexidade dos shaders (`shaders/terrain.gdshader` 650 linhas,
  `shaders/water_shader.gdshader` 743 linhas) — não perfilada.
- `config/features` do projeto usa `"Forward Plus"` (o método de
  renderização mais caro/completo do Godot 4) — não avaliado se
  `Mobile` seria visualmente aceitável e mais barato (provavelmente
  perderia SSR/parte do SSAO).

## 5. Deliberadamente fora de escopo (custo único, não "lag" de jogo)

- **`HexGrid.generate_map()`**: ~2.5-2.8s pra um mapa Grande 320x84. É
  custo de **criar uma partida nova**, não algo que se repete durante o
  jogo — já coberto por uma tela de carregamento (`Main._show_loading_screen`,
  `LoadingScreen.gd`, pedido de sessão anterior: "ta tendo um certo delay
  ao dar play... vamos colocar uma tela de loading"). Reescrever o
  algoritmo de geração (várias passadas de suavização de bioma, cada uma
  com casos de borda já resolvidos a duras penas, ver comentários em
  `generate_map`) é um projeto próprio, bem mais arriscado que os fixes
  desta rodada, pra resolver um problema que já tem solução de UX
  aceitável. Só vale revisitar se o pedido for especificamente "carregar
  partida nova está demorando demais", não "o jogo está com lag".
