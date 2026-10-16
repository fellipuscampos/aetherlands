# Guia de Performance

> **Rodada mais recente: §6 (14/10/2026, otimização geral).** Benchmark permanente em `tools/perf/PerfBench.tscn`,
> animação pausada fora da tela, sombras do tamanho da vista, vegetação sob névoa sem draw call, `recompute_fog` por
> delta, texturas de modelo em BC7 (VRAM do fim de jogo 705 → 432 MB), exportação sem material de desenvolvimento e
> opções de vídeo para máquina fraca. Leia a §6.5 antes de procurar o próximo gargalo.

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
- **2026-10-10 — rota canônica (`HexGrid._find_route`)**: `compute_path`
  virou fachada de `_find_route`, o roteador único (prévia, marcha, IA e
  animação). Motivo não foi performance, foi um bug visual ("rodopios"):
  com todo terreno custando 1 há muitas rotas de mesmo custo e o desempate
  era a ordem do heap — rota em zigue-zague, corpo virando 60° a cada tile.
  Agora o estado do A* é (tile, direção de chegada) e cada curva soma
  `ROUTE_TURN_COST` (1/1024) ao `g`: entre as rotas de menor custo sai a de
  menos curvas, e o custo devolvido não muda. Três coisas mantêm a busca
  barata — **não remova nenhuma sem medir**: (1) o heap desempata `f` igual
  pelo menor `h` (segue a rota em vez de inundar o paralelogramo de
  empates); (2) um estado que chega num tile com uma curva a mais que o
  melhor já expandido ali é descartado (dominado); (3) o custo de entrar em
  cada tile (`_route_enter_cost`) é avaliado uma vez por busca. Benchmark
  sintético (campo de raio 40, 150 rotas de ~33 passos, ms por rota):

  | Montanhas | Antes | Depois | Curvas antes → depois |
  |---|---|---|---|
  | 0% | 8,8 | 2,3 | 1272 → 145 |
  | 12% | 8,1 | 7,1 | 1416 → 500 |
  | 25% | 7,7 | 6,4 | 1806 → 1176 |

  `compute_reachable`/`infiltrate_reachable` não guardam mais árvore de
  predecessores (`_last_came_from`/`reconstruct_path` saíram: era estado
  global que qualquer outra busca de alcance sobrescrevia); a rota de um
  destino do alcance vem de `unit_route`, um A* curto, só quando alguém
  precisa dela (hover de um tile novo, unidade visível andando).

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

### 2.11 Vegetação composta por bioma (kit `temperate_forest_v1`) — 09/10/2026

A árvore KayKit única (um `MultiMeshInstance3D` com ~1,9–2,5 mil cópias) deu
lugar a `NatureDecorManager` + `NatureComposer` (10 assets, composição por
bioma; desenho em `docs/TEMPERATE_FOREST_KIT.md`). Mapa padrão 144×76:

| Medida | Seed 101 | Seed 202 |
|---|---|---|
| Instâncias | 7.282 | 5.580 |
| Grupos `MultiMeshInstance3D` (asset × região 12×12 tiles) | 327 | 298 |
| `rebuild` (tela de carregamento, uma vez; antes da otimização abaixo) | ~467 ms | ~380 ms |
| Névoa completa (primeira aplicação) | 26,5 ms | 20,9 ms |
| Névoa por passo de unidade | **1,75 ms** | **0,92 ms** |

- **Névoa incremental** (`NatureDecorManager.apply_fog`): guarda a última
  visibilidade aplicada por tile (`_fog_state`) e só repinta os tiles cuja
  visibilidade mudou. A primeira versão repintava tudo a cada `recompute_fog`
  (todo passo do humano) e custava **14–21 ms por passo** — não volte a ela.
  Tile limpo/recomposto (`clear_at`/`refresh_tile`) perde o estado e sempre
  recebe a névoa na próxima aplicação.
- **Regiões 12×12**: um MultiMesh do mapa inteiro nunca sai do frustum; por
  região o culling por AABB funciona. Mais grupos = mais draw calls, mas cada
  um só é desenhado quando a região está em vista.
- **`rebuild`** é custo único da tela de carregamento (ver seção 5). No mapa
  Grande 320×84 (seed 999, 6.480 instâncias) caiu de **438 ms para 325 ms**:
  `NatureDecorManager.context_for` refazia `world_for_coord` + `get_neighbors`
  por tile (~41 µs/tile) só para obter a direção de cada vizinho, que é
  constante da malha axial. Agora são 6 direções pré-calculadas
  (`_neighbor_dirs`); o contexto de todos os tiles caiu de 1.107 ms para
  350 ms. O resultado é idêntico (mesmas 6.480 instâncias). O que sobra é a
  composição (~250 ms, amostragem por dardo em `NatureComposer._try_place`)
  mais o preenchimento dos MultiMesh (~75 ms). O teste de tempo do mapa Grande
  (`test_generate_map_at_large_radius_completes_quickly`, < 5 s) passa.
- O RenderingServer headless não devolve cor nem transform de MultiMesh. Os
  testes (`test/unit/test_nature_composition.gd`) verificam `fog_state()`,
  `fog_color()` e `compose()`, nunca a leitura do buffer.

---

### 2.12 Ciclo de dia e noite (`DayNightController`) — 09/10/2026

Partida real (mapa padrão), V-Sync desligado, 300 quadros por medida, 1600×900, Blender aberto em segundo plano
(ruído de ±5 FPS entre rodadas):

| Versão | Desligado | Ligado | Custo |
|---|---|---|---|
| Sol reaplicado em todo quadro, céu a cada 0,25 s | ~248 | ~230 | ~7% (~0,3 ms/quadro) |
| Sol em passos de 0,1 s, céu a cada 2 s (atual) | ~243–252 | ~235–241 | ~2–4% (~0,1–0,2 ms/quadro) |

- O custo era o **update** do sol, não o estado de luz: com o ciclo congelado na manhã o FPS era igual ao desligado.
  Espaçar o céu de 0,25 s para 2 s quase não mudou nada; espaçar o sol para 10 Hz foi o que reduziu.
- Num ciclo de 20 min o sol anda no máximo ~1°/s (à noite, sombra fraca) e ~0,1°/s de dia: passos de 0,1 s são
  invisíveis. Não vale baixar mais: o restante está dentro do ruído da medição.

### 2.13 Chuva e neve (`WeatherController`) — 09–10/10/2026

- Até 6.000 gotas (`GPUParticles3D`, `amount_ratio` = intensidade × área coberta, então de perto há menos gotas com a
  mesma densidade). Sem colisão nem respingos. CPU por quadro: avançar a agenda e ajustar 3 valores; o parâmetro global
  do chão molhado só é enviado quando muda.
- Primeira medição (09/10) com o Blender usando 92% da GPU: inválida (variação maior que o efeito).
- **Medição com a GPU livre (10/10)**, mapa padrão, V-Sync desligado, 400 quadros por medida, 2 rodadas, ruído de
  ±20 FPS entre rodadas:

| Cena | Zoom padrão | Zoom máximo |
|---|---|---|
| Seco, vegetação com o material antigo | 244–270 | 249–266 |
| Seco, vegetação com `nature_kit.gdshader` (neve) | 201*–271 | 263–266 |
| Chuva no pico (até 6.000 gotas) | 239–246 | 214–248 |
| Neve no pico (até 3.000 flocos + chão e copas esbranquiçados) | 225–240 | 261–263 |

  \* um ponto fora da curva na 2ª rodada; na 1ª, o shader novo e o material antigo empataram (270,8 × 269,6 e
  266,0 × 265,9). Conclusão: o shader da vegetação não tem custo mensurável; chuva e neve no pico custam algo entre
  0 e ~10%, só enquanto acontecem (alguns minutos a cada ~25 min / ~1 h 30).

### 2.14 Embarque automático (rotas anfíbias) — 10/10/2026

- Toda tropa de civilização atravessa água, então o atalho de rejeição rápida de `compute_path` (componentes conexos
  de terra, `_land_route_possible`) ganhou a variante anfíbia: `_amphibious_components` (terra + água embarcável),
  calculada sob demanda uma vez e invalidada junto com os componentes de terra (geração, `transform_tile_terrain`
  quando a passagem do tile muda). Mesma ideia, nenhum A* pelo mapa inteiro para um destino impossível (lago fechado,
  ilha cercada de lava/montanha).
- A regra antiga "embarcado não expande a partir de terra" saiu das duas buscas (menos um teste por nó).
- Medido no laboratório 4-IA (12 partidas, mesmas seeds, A/B): turno p95 485 → 503 ms (ruído), pior turno 1,49 → 1,13 s.
- Visual: o barco é montado só na primeira entrada na água; terminada a troca, o lado escondido fica invisível e com o
  `AnimationPlayer` parado (`active = false`) — custo zero de skinning da tropa enquanto navega.

### 2.15 Brilho do mundo (`WorldGlow`) — 12/10/2026

- Um `OmniLight3D` sem sombra por recurso que brilha (Gemas, Nódulo Arcano): 36 no mapa padrão 128×72 (18 + 18).
  Forward+ agrupa luzes por cluster; sem sombra, cada uma só pesa nos pixels que alcança (alcance 2,6–3,0).
- Nada por quadro: a energia das luzes só é reenviada quando a escuridão da cena muda mais de 0,01 (o anoitecer
  inteiro vira ~100 passos), e a névoa só reenvia o brilho dos tiles que mudaram de estado. Luz apagada pela névoa ou
  de energia desprezível fica `visible = false`.
- **Medição** (partida real, mapa padrão, 3 rivais, névoa desligada = as 36 luzes acesas, V-Sync desligado, 300
  quadros por medida, 1920×1017; havia outro processo do Godot usando a GPU, por isso o FPS absoluto baixo):

| Cena | Zoom padrão (19) | Zoom máximo (30) |
|---|---|---|
| Meio-dia, brilho ligado | 96,5 | 91,0 |
| Noite, brilho ligado | 96,3 / 95,8 | 92,1 / 93,1 |
| Noite, luzes desligadas | 95,4 | 91,7 |

  Diferença dentro do ruído (±1 FPS). Se o número de fontes crescer muito (dezenas de prédios iluminados por cidade),
  medir de novo: o primeiro limite a olhar é o de elementos por cluster do Forward+ (512 por quadro).
- **Núcleos das Grandes Manifestações (13/10/2026):** uma luz sem sombra por Manifestação, presa ao osso do núcleo
  (alcance 4,2–4,6, maior que o dos recursos). No máximo 24 numa partida (6 por reino × 4). Medição do pior caso —
  as 24 juntas na tela, noite profunda, mapa padrão 128×72 com 3 rivais, névoa desligada (36 luzes de recurso
  acesas), V-Sync desligado, 400 quadros por medida, 1920×1080:

| Luzes das criaturas | 1ª medida | 2ª medida |
|---|---|---|
| Ligadas | 100,5 FPS | 92,6 FPS |
| Desligadas | 99,5 FPS | 95,4 FPS |

  A variação entre as duas rodadas (±4 FPS) é maior que a diferença ligado/desligado: sem custo mensurável. As
  opções de vídeo "Luzes do mapa" e "Luzes das criaturas" existem por preferência visual e para máquinas fracas, não
  porque a medição pediu. Nada por quadro em GDScript: a luz segue o osso pelo `BoneAttachment3D` do motor.

### 2.16 Névoa de guerra como camada física (`FogLayer`) — 12/10/2026

- **O que desenha:** um bloco hexagonal (18 triângulos) por tile nunca visto, em pedaços de 16×16 tiles (48 pedaços
  no mapa padrão 128×72). Só os pedaços na câmera são enviados; pedaço sem tile nunca visto fica `visible = false`.
  Em compensação, o terreno nunca visto deixou de ser desenhado (prisma recolhido no vértice) e a água embaixo da
  camada é rejeitada pelo teste de profundidade — antes os dois rodavam o shader completo só para pintar a cor da névoa.
- **CPU do recálculo (`recompute_fog`, mapa padrão, headless, melhor de 25):** 11,3 ms sem mudança de visão, 12,6 ms
  ao mover 1 tile — o mesmo de antes dentro do ruído (8–10 ms na medição anterior, com a máquina livre). Do total, a
  parte nova custa ~0,13 ms (`_apply_fog_to_entities` com a regra única) e ~0,001 ms (`_rebuild_fog_state` sem
  mudança). O resto é o que já existia: varrer todos os tiles (5,6 ms), devolver a cor crua do terreno
  (`_apply_terrain_fog`, 2,5 ms), névoa dos props (2,1 ms) e contorno de território (1,3 ms). Se um dia o recálculo
  pesar, é aí que há ganho (varrer só os tiles que eram ou passaram a ser visíveis) — não mexido nesta rodada porque
  40 arquivos de teste escrevem em `visibility` direto.
- **Geração do mapa:** montar os blocos (`FogLayer.rebuild`) custa ~80 ms no mapa de 320×84 (26.880 tiles, 120
  pedaços), uma vez por partida. O passe por tile do estado é pulado em mapa recém-gerado (tudo nunca visto = buffer
  zerado); antes desse atalho eram mais ~100 ms. Para comparar: `generate_map` inteiro levou ~6,0 s nessa mesma
  medição, com a máquina ocupada (o normal documentado é 2,7–2,9 s) — por isso o teste de tempo
  `test_terrain_generation` (limite de 5 s) falhou nesta rodada; a camada responde por ~1–3% disso.
- **FPS (partida real, 1920×1017, V-Sync desligado, 300 quadros por medida, zoom máximo sobre o início da partida):**

| Medição | Com névoa (quase tudo nunca visto) | Mapa inteiro visível (controle) |
|---|---|---|
| Névoa antiga, máquina livre | 196,7 FPS (5,08 ms) | 89,9 FPS (11,12 ms) |
| Névoa nova, Blender usando 64–100% da CPU, 3 rodadas intercaladas | 129–132 FPS (7,6 ms) | 69,5–71,9 FPS (14,2 ms) |

  As duas medições não são comparáveis em valor absoluto: na segunda o Blender estava ocupando a CPU. O controle
  (sem névoa nenhuma) piorou ~3,1 ms por quadro pela carga da máquina e a vista com névoa ~2,6 ms — a mesma ordem, ou
  seja, nenhum custo próprio da camada aparece acima do ruído. **Falta repetir com a máquina livre** para ter o número
  limpo (cena descartável: instanciar `Main.tscn`, medir a vista inicial no zoom máximo com e sem
  `set_debug_fog_disabled`).

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
  desenho. Desde a 2.11 a vegetação sozinha tem ~300 grupos regionais
  (com culling por região), o primeiro candidato se o custo de GPU for medido.
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

---

## 6. Rodada de otimização geral — 14/10/2026 ("jogo leve em qualquer máquina")

Pedido: deixar o jogo o mais leve possível **sem mudar conteúdo, gameplay, balanceamento nem visual**. Regra seguida em
todo item: o resultado na tela e no estado do jogo é idêntico ao anterior (verificado por comparação com o algoritmo
antigo ou por medição de erro), ou a mudança só existe como opção nova com padrão igual ao de sempre.

### 6.1 Ferramenta de medição (permanente): `tools/perf/PerfBench.tscn`

Não é referenciada pelo jogo e fica fora da exportação (`tools/*` no `exclude_filter`).

```
# janela (GPU + CPU por quadro, VRAM, draw calls, triângulos, censo de texturas/malhas/animadores)
godot --path . res://tools/perf/PerfBench.tscn -- --out=user://perf.json
# headless (só CPU: geração, névoa, turnos)
godot --headless --path . res://tools/perf/PerfBench.tscn -- --out=user://perf_cpu.json
```

Opções depois de `--`: `--seed=4242 --size=large --rivals=3 --late_turns=40 --frames=300`,
`--scenarios=start_default,start_zoom_max,start_zoom_min,revealed_zoom_max,features,late_default,late_revealed,late_night,turn_spikes`
(padrão: todos), `--feat_zoom=default|max --feat_reveal=1|0` (cenário `features`: desliga um efeito de cada vez —
SSAO, SSR, glow, névoa do ambiente, sombras, MSAA, sombras da vegetação, vegetação, HUD, animações — e mede de novo).
O cenário "late" joga N turnos com a IA em todos os assentos (`GameManager.ai_controls_human_seat`) antes de medir.
`turn_spikes` mede o que o jogador sente no Encerrar Turno com a IA espalhada (`stagger_ai_turns`): o quadro do clique
e os quadros da fila de IA. Saída: JSON em `user://` (`%APPDATA%/Godot/app_userdata/Aetherlands/`) + resumo no console.
O campo `process_ms` (monitor `TIME_PROCESS`) não é confiável nessa leitura por quadro — use `frame_ms`.

**Ruído:** com outro processo do Godot ou o Blender aberto, a mesma cena varia ±1 ms entre rodadas. Compare sempre
A/B **dentro da mesma rodada** (o cenário `features` existe para isso), nunca entre rodadas em horários diferentes.
Rode o headless antes: erro de script na janela deixa a janela aberta até o watchdog (900 s).

### 6.2 Linha de base (antes desta rodada)

RTX 3060 + i5-9600K, 1600×900, V-Sync desligado, mapa Grande 128×72, seed 4242, 3 rivais.

| Cenário | FPS | Quadro | GPU | CPU de render | Draw calls | Triângulos/quadro | VRAM |
|---|---|---|---|---|---|---|---|
| Início, zoom padrão | 263 | 3,80 ms | 2,34 ms | 0,92 ms | 708 | 2,53 M | 405 MB |
| Mapa revelado, zoom padrão | 101 | 9,88 ms | 3,16 ms | 4,28 ms | 2.628 | 2,66 M | 407 MB |
| Mapa revelado, zoom máximo | 122 | 8,20 ms | 3,09 ms | 3,59 ms | 2.721 | 2,37 M | 407 MB |
| Turno 40, revelado | 108 | 9,29 ms | 3,25 ms | 4,35 ms | 3.131 | 2,49 M | **705 MB** |

Custo de cada efeito (mapa revelado, zoom padrão, desligando um de cada vez): sombras **−4,2 ms de quadro** (2.628 →
452 draw calls; 2,66 M → 0,50 M triângulos), animações **−4,0 ms** de CPU, vegetação −1,3 ms, sombras da vegetação
−1,0 ms; SSAO/SSR/glow/MSAA/névoa ≈ −0,1 a −0,4 ms de GPU cada. Conclusão: o quadro era limitado por CPU (draw calls
das cascatas de sombra + esqueletos animados), não por pós-processamento.

### 6.3 O que mudou

**a) Animação só onde alguém vê** (`Unit._build_animation_culling`). Censo no início da partida: 208 `AnimationPlayer`
de unidades ativos, 10 visíveis — o resto na névoa ou fora da câmera, avançando esqueleto todo quadro. Agora cada
unidade animada tem um `VisibleOnScreenNotifier3D` com a caixa do modelo + 4 de folga (a sombra de quem está logo fora
da borda continua animando); fora da tela ou escondida pela névoa, o player fica com `process_mode = DISABLED` (não
`active = false`, que limpa caches) e volta a `INHERIT` ao entrar na tela, continuando de onde parou. Um clipe de uma
vez (golpe, feitiço, trabalho, pouso) nunca é pausado: termina e só então a unidade, já em repouso, para — inclusive
quando ele começa com a unidade já pausada (`current_animation_changed` é emitido pelo `play()` mesmo com o player
desligado; conferido no motor). Headless (testes, laboratório de balanceamento) não cria o notifier: comportamento
antigo. Custo das animações no cenário revelado: ~4 ms → indistinguível de zero.

**b) Sombras do tamanho da vista** (`GraphicsQuality.fit_shadows_to_view`, chamado a cada zoom). Ver
`docs/GRAPHICS_SETTINGS.md`: cascatas próximas com as mesmas distâncias absolutas (8/16/40 na Média), só a última
encolhe até o chão visível + folga, com o esmaecimento além da borda. No zoom padrão o alcance cai de 80 para ~46.
Mapa revelado, zoom padrão, mesma rodada: 3.527 → 2.120 draw calls quando comparado ao alcance fixo.
**Conferência visual** (uma vez, janela, capturas apagadas): não é bit a bit idêntico — o Godot estabiliza cada
cascata pela faixa de profundidade da luz, então bordas de sombra deslocam menos de 1 texel. Pixels com diferença
> 8/255 contra o alcance fixo: 4,5 % no zoom padrão e 9,9 % no máximo, contra 1,9 % e 6,3 % entre dois quadros
seguidos com a MESMA configuração (animação e reflexo da água); lado a lado, indistinguível. O excesso fica em
contornos de sombra de 1 px espalhados, sem sombra a mais ou a menos (diferença média com sinal ≈ 0).

**c) Vegetação sob névoa total não é desenhada** (`NatureDecorManager.apply_fog`). Um grupo (asset × região 12×12) com
todas as instâncias em tile nunca visto já era invisível (alfa 0, recortado em todos os passes), mas gastava draw call
no pré-passe, na cor e em cada cascata. Agora o grupo conta as instâncias aparentes e fica `visible = false` em zero.
No teste de equivalência, até 217 dos 343 grupos ficaram desligados. A névoa da vegetação também passou a repintar só
os tiles do `changed` (+ os ainda sem névoa) em vez dos ~5 mil tiles decorados a cada passo.

**d) `recompute_fog` por delta** (`HexGrid.recompute_fog`, a cada passo de unidade do jogador): 11,1 → ~4 ms no mapa
padrão (headless, melhor de 7).
- Laço de visibilidade: depois de um recálculo os tiles VISÍVEIS são exatamente os vistos naquele recálculo
  (`_fog_visible_coords`); se `visibility == _last_fog_visibility` (comparação nativa — pega escrita externa de load,
  Debug e dos ~40 testes que escrevem em `visibility`), só esses e os vistos agora podem mudar. Senão, o laço completo
  antigo. A cópia `_last_fog_visibility` é atualizada só nos tiles mudados nesse caminho (sem `duplicate()` do mapa).
- `_apply_terrain_fog` repintava as ~5 mil instâncias do terreno só para desfazer o destaque de movimento; agora desfaz
  só os tiles registrados em `_last_highlighted_land_coords` (mesmo buffer: a cor do terreno só sai da cor crua por
  `_highlight_coords`, e `transform_tile_terrain` grava a cor nova na hora).
- Contorno de território: assinatura por cidade (tiles, tipo de cada aresta, névoa de cada tile, cor) guardada no meta
  da malha; igual = a malha continua valendo e o `SurfaceTool` não roda. `transform_tile_terrain` (muda alturas) apaga
  as assinaturas. 1,4 → 0,1 ms com 4 cidades (cresce com o número de cidades).
- **Verificação** (script descartável, apagado): 325 recálculos (150 passos de unidades antes e depois de 25 turnos de
  IA, escrita externa em `visibility`, Debug liga/desliga) comparando com uma reimplementação literal do algoritmo
  antigo: 0 divergências em `visibility`, `last_fog_changed` e `_last_fog_visibility`; 975 malhas de contorno idênticas à
  reconstruída do zero; estado de névoa de cada tile decorado e visibilidade de cada grupo de vegetação corretos.

**e) Texturas de modelo em BC7** (580 texturas, `tools/perf/texture_import_audit.gd`). Todas estavam em *Lossless*, que
na GPU é RGBA8 descomprimido (um atlas 2048² com mipmaps = 21 MB). BC7 (*VRAM Compressed* + alta qualidade) = 1 byte por
pixel: 4× menos VRAM. Erro medido contra o original (`Image.compress(BPTC)` + `decompress`): PSNR 49–51 dB (81 dB nos
mapas de emissão), pixels com diferença > 8/255: 0,004–0,05 %. BC1/BC3 (o *VRAM Compressed* sem alta qualidade) foi
descartado: 34–36 dB e 3–15 % dos pixels com erro visível nas bordas da pixel art. UI, ícones e terreno ficam de fora
(não são materiais de modelo; o terreno é `Texture2DArray` montado em código). Regra para arte nova em
`docs/ASSET_FACTORY_GUIDE.md` §3.1. A reimportação das 580 levou 20,5 min (BC7 é lento de codificar; custo só da importação, não do jogo). Auditoria
depois: 580 texturas, 0 fora da regra.

**f) Exportação sem material de desenvolvimento** (`export_presets.cfg`, `exclude_filter`): `art_source/` (12 GB, 5.477
arquivos importados), `test/`, `tools/`, `addons/gut/`, `scenes/art_review/`, cenas `_*` da raiz, previews de arte,
`*_report.json`, `*.md`, `*.log`, `*.blend`. Conferido que o jogo não carrega nada disso (`scripts/art_review/` fica:
os canteiros de obra usam scripts de lá).

**g) Spawn de unidade sem instanciar o modelo duas vezes** (`Unit._copy_animations_into`): cada unidade instanciava a
cena de animação inteira só para ler as bibliotecas. Agora os clipes ficam em cache por cena (as mesmas `Animation`
compartilhadas). Trabalho a menos em todo spawn; no `start_new_game` o ganho fica no ruído (o custo dominante é outro,
ver 6.5).

**h) Opções novas para máquina fraca** (padrão = visual de sempre): Resolução 3D com FSR 1.0 (100/85/75/67/50 %) e
"Oclusão de ambiente e reflexos". Ver `docs/GRAPHICS_SETTINGS.md`.

### 6.4 Resultado final

Mesma máquina, mesma cena e semente da 6.2 (havia um Blender aberto na rodada final; o ruído é ±1 ms).

| Cenário | FPS | Quadro | GPU | CPU de render | Draw calls | Triângulos/quadro | VRAM |
|---|---|---|---|---|---|---|---|
| Início, zoom padrão | 263 → **408** | 3,80 → 2,45 ms | 2,34 → 1,90 | 0,92 → 0,42 | 708 → **170** | 2,53 M → **0,91 M** | 405 → 333 MB |
| Início, zoom máximo | 251 → **402** | 3,98 → 2,49 ms | 2,35 → 1,92 | 0,94 → 0,41 | 655 → 161 | 2,25 M → 0,86 M | 405 → 333 MB |
| Mapa revelado, zoom padrão¹ | 101 → **217** | 9,88 → 4,61 ms | 3,16 → 2,88 | 4,28 → 2,41 | 2.628 → 2.120 | 2,66 M → 2,53 M | 407 → 335 MB |
| Mapa revelado, zoom máximo | 122 → **170** | 8,20 → 5,89 ms | 3,09 → 3,00 | 3,59 → 3,02 | 2.721 → 2.624 | igual | 406 → 335 MB |
| Turno 40, zoom padrão | 197 → **299** | 5,07 → 3,35 ms | 2,74 → 2,82 | 1,72 → 1,49 | 1.315 → 1.194 | 2,67 M → 2,56 M | **705 → 432 MB** |
| Turno 40, revelado, zoom máximo | 108 → **148** | 9,29 → 6,78 ms | 3,25 → 3,08 | 4,35 → 3,72 | 3.130 → 3.048 | igual | 705 → 432 MB |
| Turno 40, noite, revelado | 108 → **151** | 9,27 → 6,62 ms | 3,28 → 3,05 | 4,29 → 3,58 | 3.009 → 2.877 | igual | 705 → 432 MB |

¹ cenário `features` (`--feat_zoom=default`), comparado dentro da mesma rodada.

Memória de texturas na GPU: 331 → 262 MB no início e **605 → 334 MB** no turno 40 (o resto do total é alvo de
render: atlas de sombra 4096², buffers de SSAO/SSR/glow/MSAA, que não mudaram). Se todos os 580 modelos fossem
carregados, seriam ~3,4 GB em RGBA8 contra ~0,84 GB em BC7. RAM estática no headless (onde as texturas ficam na CPU):
600 → 318 MB.

CPU (headless, mesma semente; `tools/perf/PerfBench.tscn --late_turns=40`):

| Medida | Antes | Depois |
|---|---|---|
| `recompute_fog` (a cada passo de unidade), início | 9,2 ms | **3,0 ms** |
| `recompute_fog`, turno 40 | 13,0 ms | **4,1 ms** |
| `start_new_game` (tela de carregamento) | 1.032 ms | 723 ms |
| Turno síncrono completo (média / p95, IA em todos os assentos) | 123 / 199 ms | 99 / 167 ms |
| Abertura (`Main.tscn`) | 2,9 s | 2,7–3,0 s (ruído; ver 6.5) |

Encerrar Turno no jogo real (IA espalhada, janela, turnos 41–45): quadro do clique média 46 ms (máx. 112 ms), quadros
da fila de IA p95 3,7 ms (máx. 51 ms). Sem linha de base (cenário criado nesta rodada) — é a referência para a próxima.

### 6.5 Medido e NÃO mexido (candidatos para a próxima rodada)

- **Abertura do jogo ~2,9 s** (`Main.tscn`): é compilação de GDScript (HexGrid.gd + dependências 486 ms, HUD.gd 547 ms,
  UIShell/Minimap/GlobalBar 100–170 ms cada). Custo único atrás da tela de título; reduzir exigiria reestruturar
  dependências de classe.
- **`start_new_game` ~1,0 s** (tela de carregamento): `MonsterEcologySystem.populate_new_match` ~630 ms (planejamento de
  habitat + criação dos covis), capitais rivais ~290 ms (`found_city` ~37 ms cada), primeira névoa ~85 ms.
- **Quadro do Encerrar Turno**: `V2StrategicAI.plan_turn` ~8 ms por rival (escolha de pesquisa e captura do WorldView),
  mais economia/cidades. Engasgo único por turno, já sob o estado "processando" da HUD. Mexer exigiria provar que a IA
  toma as mesmas decisões (risco de balanceamento).
- **`GlobalBarPresenter.refresh`** ~1,2 ms, chamado em cada `fog_updated`/`notify`/evento estruturado. Agrupar por quadro
  não ajuda o caso comum (1 passo = 1 refresh) e um teste espera a atualização imediata nos sinais de pesquisa.
- **HUD** (~0,2–0,4 ms por quadro no cenário `features`): não mexido nesta rodada porque outro agente estava editando
  `HUD.gd` ao mesmo tempo.
- **Terreno em um MultiMesh só** (nunca recortado pela câmera): ~90 mil triângulos × cada passe. Dividir em regiões
  cortaria vértices e somaria draw calls — não compensa enquanto o gargalo for draw call.
- **Faces internas dos modelos de blocos** (vegetação ~780 mil triângulos no mapa inteiro): remover faces escondidas
  entre cubos encostados reduziria triângulos sem mudar a silhueta; precisa de um passo no pipeline do Blender.

### 6.6 Covis regionais unificados — 15/10/2026

Feature de gameplay, sem mexer nas otimizações da §6.3. `MonsterEcologySystem` controla as 12 espécies e os
covis da abertura/recursos num registro só. Nenhum `_process`; contagem por origem uma vez por rodada,
índices para consultas de líder/covil, visão por civilização somente quando há reposição pendente,
candidatos/habitat em cache e até 96 amostras para uma origem nova. Reposição limitada a 3 nascimentos/rodada.
Modelos novos: uma malha/material por covil, estáticos, 24 texturas em BC7, compartilhando malhas/texturas.

Benchmark permanente isolado (CPU, sem IA/render):

```
godot --headless --path . res://tools/perf/MonsterLairBench.tscn
```

Grande 128×72, seed 33102, 100 rodadas com conquista/reposição no meio: controlador média 0,85 ms,
p95 0,81 ms, máximo 8,95 ms; 50 covis e 86 criaturas no fim. Saída `user://lair_round_bench.json`.
PerfBench seed 4242 / 3 rivais / 12 turnos: média 105 → 101 ms, p95 159 → 168 ms, setup 719 → 807 ms,
RAM estática headless 239 → 268 MB. O acréscimo é arte/carregamento. A comparação é curta, com gameplay
diferente e outros Godot abertos; não demonstra ganho estatístico nem FPS. Duas campanhas 4-IA até T120,
com save/load em T60, completaram sem erros (média de turno 94/100 ms, p95 170/188 ms).
Contrato, compatibilidade e resultados de testes em [UNIFIED_MONSTER_LAIRS.md](UNIFIED_MONSTER_LAIRS.md).

### 6.7 Acabamento da reação dos monstros — 15/10/2026

Reação ao dano é um evento; auxiliares do mesmo covil são consultados no raio 2. O agressor é mantido por
serial/coordenada em busca local. Os desvios de defesa ficam dentro do raio fixo 4–6 do confronto, usando
os custos canônicos do HexGrid e no máximo a arena de 127 tiles; não procuram uma volta pelo continente.
Movimento zero retorna antes de qualquer cálculo de desvio. Nenhum `_process` novo nem recomputação de
visão por criatura. Vegetação/props verificam ocupação nos índices durante composição/rebuild/refresh.

PerfBench headless, seed 4242, Grande, 3 rivais e 40 turnos, cenários padrão: média 131,89 → 99,06 ms,
p95 214,07 → 204,98 ms, máximo 219,91 → 247,46 ms. Controlador isolado, 100 rodadas, média 1,00 ms,
p95 0,95 ms, máximo 9,90 ms (50 covis/86 criaturas). São smokes com gameplay diferente e caches/processos
não isolados; não provam ganho estatístico nem FPS. A campanha final T140 com save/load em T60 completou
sem erros. Método, limitações, 369 testes e artefato numérico em
[MONSTER_SYSTEM_REFINEMENT_2026-10-15.md](MONSTER_SYSTEM_REFINEMENT_2026-10-15.md).

### 6.8 Contato das animações e feedback — 15/10/2026

`CombatFeedback.gd` mantém regras síncronas e agenda somente os sinais visuais de ações visíveis. Não espera
animação na IA nem adiciona `_process`. Tabela gerada com 59 pontos de impacto, um timer principal por ação,
máximo de 12 agendas por mapa, referências fracas, cancelamento na troca de mapa e modelo existente reaproveitado
na morte. O headless não cria agendas. Culling, caches de animação, malhas/texturas e limites do VFX foram mantidos.
RNG dos números continua consumido na chamada original, antes da publicação visual.

Benchmark da camada nova: 1.000 amostras, 3 callbacks por ação → média 0,084 ms, p95 0,113 ms;
21 callbacks → 0,313 ms / 0,494 ms. Não inclui GPU/efeitos existentes; não equivale a FPS. Ferramenta:
`tools/perf/CombatFeedbackBench.tscn`. Decisão, limites, capturas reais e testes em
[COMBAT_VISUAL_SYNC.md](COMBAT_VISUAL_SYNC.md).

### 6.9 Explorar com voo e infiltração — 15/10/2026

`ExplorationPlanner.gd` corrige a navegação automática dos perfis especiais sem alterar a seleção terrestre
habitual (heap de 24 candidatos + A*). Só se os candidatos terrestres falharem entra uma busca complementar;
o limite não é mais confundido com “nenhuma fronteira acessível”. Voo planeja pousos válidos por turno;
infiltração nunca termina sobre outro ocupante. Sem movimento disponível não há busca.

Caches locais de passagem, heap e rejeição reversa de pequenos bolsões isolados; nenhum `_process`, timer ou
estado novo de save. Reutiliza `unit_route` para executar/animação. CPU de planejamento, mapa 320×84, 30 amostras:
voo aberto média 3,08 ms / p95 3,22 ms; infiltração 1,80 ms / p95 1,89 ms. Somente planejamento, com outros
processos ativos e caches aquecendo; não mede GPU/FPS nem o custo de movimento/névoa.
Benchmark: `tools/perf/ExplorationBench.tscn` (`-- --large` para 320×84).
Método, cobertura e limitações em [EXPLORATION_FIX_2026-10-15.md](EXPLORATION_FIX_2026-10-15.md).

### 6.10 Grandes Manifestações por objetivos — 15/10/2026

`V2ManifestationOrders.gd` decide uma vez por entidade/rodada, usando a fila gradual existente
(dois itens a cada 0,12 s). Nenhum novo trabalho contínuo por frame. Visão de dono uma vez por rodada;
movimento acrescenta somente o raio local. Candidatos de feitiços são locais, com validação final canônica;
a consulta preliminar de disponibilidade evita recalcular a mesma lista de alvos.

Avanço usa alcançáveis; contorno terrestre consulta uma rota A* e conserva seu restante entre rodadas,
revalidando o trecho alcançável. Mudança de alvo/obstrução invalida o cache transitório. Falhas alternam
aproximações e recuam para uma tentativa a cada terceira rodada. Selecionar a entidade não calcula
alcance de movimento manual, pois oferece somente quatro objetivos.

`tools/balance/BoundManifestationProbe.tscn`: 6 entidades, repertórios completos, proteção ociosa,
128×72, 20 rodadas: mediana **9,31 ms**, p95 **10,99 ms**, maior rodada **69,65 ms**.
A amostra inclui inicialização de rotas/alocações e uma varredura de visão do dono por rodada.
Nas arenas, 71 decisões de combate: mediana **2,45 ms**, p95 **15,30 ms**, incluindo os efeitos existentes.
São tempos locais de CPU headless, sem equivalência a FPS ou custo de GPU. Não extrapolar para todos
os cenários. Regras, método, testes, três partidas completas e dados brutos:
[BOUND_MANIFESTATIONS.md](BOUND_MANIFESTATIONS.md).

Tuning de 16/10: alvo por identidade consulta o último ocupante ou o índice esparso de unidades,
sem varrer todos os tiles visíveis; Passo Arcano ocioso não enumera destinos; a UI das habilidades
automáticas valida custo/recarga sem procurar alvos manuais. Navegação compara perigo por consultas
O(1) nos estados esparsos existentes. Nenhum `_process`, timer ou mapa de perigo novo.
O probe ampliado (30 arenas; lote ocioso com 20 rodadas de aquecimento e 200 medidas) passou de
**8,675/8,951 ms** para **7,683/7,917 ms** de mediana/p95 por lote de seis entidades. Os números são
CPU headless local, não FPS. Dados, ressalvas e método A/B sem substituir fontes em uso estão na
seção de tuning de [BOUND_MANIFESTATIONS.md](BOUND_MANIFESTATIONS.md).
