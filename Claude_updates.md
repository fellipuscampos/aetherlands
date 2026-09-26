# Claude Updates

Changelog compacto de sessões do Claude Code — mais recente no topo. Entradas
curtas de proposito (varias tasks por documento); detalhe fica no código/git,
não aqui.

---

## Lag: redesenho total por movimento/frame/turno (2026-09-19)

- **Estado herdado**: o Codex parou no meio (créditos) com `HexGrid.gd` sem
  compilar — corpo de um `if` sem indentação em `_land_route_possible`, então o
  jogo nem abria. Corrigido; o resto do trabalho dele foi mantido e medido.
- **Causas e correções** (números em `docs/PERFORMANCE_GUIDE.md`): minimapa
  redesenhava ~27 mil tiles por frame de câmera (63 → 4,75 ms) e por passo de
  unidade (agora `Image` persistente + delta `HexGrid.last_fog_changed`); fog
  recriava texturas inteiras sem mudança (agora por delta, com teste byte a
  byte); `compute_path` varria o continente para destinos inalcançáveis —
  outra ilha (componentes conexos) e cidade emparedada pelas próprias unidades
  (`_destination_walled_in`, 49 buscas > 30 ms → 0); painel de Magia/Tecnologia
  reconstruía as duas árvores a cada abertura.
- **Validado**: GUT 1492/1492 (52 scripts; +17 testes: delta de fog, textura
  incremental == reconstrução completa, bolso/emparedado/corredor estreito,
  invalidação de componentes, minimapa incremental, painel de tecnologia);
  benchmark de janela real e campanha headless antes/depois.

## Inspeção de Tiles, Unidades, Monstros e Estruturas (2026-09-18)

- **Causa raiz**: `HUD._on_tile_selected` montava só o TERRENO (+ cidade): unidade
  rival/feiticeiro, boss, covil (estrutura), prédio, área/ritual mágico e recurso
  isolado não apareciam; TODO monstro neutro era rotulado "Covil de Monstro"; a
  névoa era ignorada (tile nunca visto mostrava o terreno) e o painel mostrava
  "Produzindo: …" até de cidade **rival** (vazamento).
- **Novo `scripts/ui/TileInspector.gd`** (modelo único, testável sem cena):
  `inspect(grid, coord, viewer)` → entidades em ordem cidade > unidade >
  monstro/boss > covil > prédio/obra > mágica/ritual > recurso, com o TERRENO
  sempre como seção separada. Segredo: tile UNSEEN não revela nada; entidade
  alheia só com tile visível e sem véu (`MagicRuntime.concealed`); cidade rival
  sem produção/estoque/prédios; unidade rival sem recarga/ação/movimento
  restante; obra rival sem revelar o que é; defensores de covil só os visíveis.
- **HUD**: painel de tile com **abas** (uma por entidade, só com 2+), texto em
  ScrollContainer, painel mais largo/alto (480×310); guarda só coord+chave (nunca
  referência) e refaz a consulta em `fog_updated` (entidade morta/cidade
  capturada/mapa trocado não deixam painel inválido). Painel de unidade própria
  ganha classe/escola, efeitos, ação/recarga do conjurador e "Neste tile: …".
  `MagicOverlay.region_title` extraído pra rótulo do mapa == painel.
- **Validado**: GUT 1475/1475 (52 scripts; +48 testes: 29 de modelo + 19 de HUD)
  (unidade própria/inimiga, conjurador próprio/inimigo, monstro, boss, cidade
  própria/rival, covil, construção, área mágica, recurso, tile vazio, múltiplas
  entidades, névoa, destruição, troca de mapa, clique = seleciona só unidade
  própria e inspeciona o resto sem atacar). 2 rodadas visuais (cena descartável):
  aba de feiticeiro inimigo, covil, conjurador próprio, cidade própria.
- **Limitações**: sem hover-tooltip (inspeção é por clique; clicar inimigo
  atacável com unidade selecionada ainda ataca, como antes); "melhoria" = prédio
  (não há sistema separado de melhorias de tile); descrição de unidade é derivada
  de traços (sem campo de texto novo).

---

## Expansão e Fundação de Cidades (2026-09-18)

- **Causa raiz**: humano sem regra nenhuma de distância; IA com `SETTLE_MIN_DISTANCE=3`
  só no código dela e local escolhido por "vizinhos imediatos com recurso"
  (sem coesão/espaço/segurança; com ≥2 cidades varria o mapa explorado todo,
  0.15/tile de distância). Medido: 55–74% das cidades fundadas a <5 tiles,
  20–30% do território sobreposto, e ainda cidades a 14–28 tiles do império.
- **Novo `scripts/core/CitySite.gd`** (sem `if ai`): **regra estrutural**
  `rejection_reason()` (distância mínima **4** entre centros, de qualquer dono;
  terreno, covil, construção, território alheio) aplicada em
  `WorldSetup.found_city_from_settler` — vale pra humano (botão da HUD
  desabilitado + motivo no tooltip/toast) e IA. **Avaliação**
  `evaluate/choose_site`: rendimento do território real (raio 2), recursos com
  raridade e retorno decrescente, Nódulo Arcano (+ extra p/ estratégia
  Arcana), terreno/defesa/gargalo natural, espaço p/ crescer, coesão (faixa
  5–7; apertado −2.5/tile, esticado −1/tile, enclave extra), covil vivo
  (−14×perigo), monstros, pressão rival, bônus de bloqueio. Coesão é
  penalidade, não regra: cluster de Nódulos paga a distância (teste). IA só
  usa tiles explorados, guarda o alvo (histerese), explora até 10 turnos se
  não há local aceitável e não produz colonizador sem local aceitável.
- **Por que 4**: território raio 1→~2 (1 tile/pop); 3 já encosta na fundação,
  5 zera sobreposição mas desperdiça mapa. Matriz (3 tamanhos × 6 seeds ×
  mín 3/4/5): 4 dá 0–27% apertadas conforme a densidade do mapa e a
  pontuação prefere ≥5 quando há espaço.
- **Validado** (IA×IA, 120 turnos, seeds não usadas na calibração, legado →
  novo): apertadas 74/72/60% → 16/5/3% (mapas 33/41/61); sobreposição
  29/26/25% → 7/3.5/0.6%; média até a vizinha 4.2/4.0/4.5 → 5.5/5.6/6.3;
  enclaves (>10) na fundação 3/6/10% → 1/2/0%; cidades fundadas +1..+3 por
  partida; sobrevivência das distantes 100%; recursos controlados por civ
  iguais no mapa 41 (16.7 vs 15.3) e ~-1 Nódulo no 61 (4.8 vs 5.8). Locais
  ruins restantes são só "covil vivo ≤4 tiles" (0% água/terreno pobre).
  Mapas renderizados em PNG (legado × novo, 2 seeds): impérios compactos, sem
  cachos colados nem cidades soltas. GUT unit + `test/integration/
  test_city_placement.gd` (harness + métricas, roda com `-gdir=res://test/integration`).
- **Limitações**: compactação custa ~1 Nódulo/partida em mapa grande;
  captura de cidade infla a métrica "isoladas (final)"; sem passe de
  "gargalo/passagem" além do bônus de barreira natural; só existe mapa Grande
  no jogo real (320×84) — validado em 33/41/61 por custo de simulação.
- **Arquivos**: `CitySite.gd` (novo), `WorldSetup.gd`, `RivalAI.gd`,
  `StrategicAI.gd` (−`settle_toward_resources`), `SelectionManager.gd`, `HUD.gd`,
  `Unit.gd`, `PlayerData.gd`, testes `test_city_site.gd`, `test_rival_ai.gd`,
  `test_naval.gd`.

---

## Cidades — Reação e Defesa contra Monstros (2026-09-18)

- **Causa raiz**: `RivalAI._city_under_threat`/`_military_deficit` só contavam
  unidades de OUTRO jogador (monstro = invisível pra produção); unidades só
  reagiam a monstro já no alcance de ataque; a cidade em si (jogador ou IA)
  não tinha defesa nenhuma.
- **Novo `scripts/core/CityDefense.gd`** (3 camadas, todas proporcionais):
  1. `assess(city)`: nível de ameaça 0..1 do poder (atk+def+15% HP, × HP atual)
     de cada monstro visível ≤6 tiles, × peso de comportamento (Invasor 1.0,
     Saqueador/Caçador 0.8, Guardião 0.3) × proximidade, × fragilidade/
     população da cidade, + pressão de covil vivo perto, − guarnição própria.
     Goblin solitário a 5 tiles ≈0.17 (ignora); 3 esqueletos a 4 tiles ≈0.9.
  2. **IA**: `decide_production` usa o nível (empurra ameaça/déficit); nível
     ≥0.6 = emergência (só TROPA, troca obra <50% pronta, compra rápida com
     Mercado). `defend_turn` (em `act_for_unit`): guarnição sai a monstros
     ≤4 tiles da cidade; reforço de fora só se a guarnição não cobre a
     ameaça; guerra eleva o limiar (0.25→0.5); nunca persegue longe.
  3. **Milícia** (jogador e IA, `GameManager`): golpe automático por turno no
     monstro ADJACENTE (1.5+0.25×pop, máx 3, +1 muralha), sem recompensa
     (sem farm); troll (20 HP) não cai sozinho. `warn_player`: toast ao
     jogador (cooldown 5 turnos).
- **Arquivos**: `CityDefense.gd` (novo), `RivalAI.gd`, `GameManager.gd`,
  `City.gd` (`last_monster_warning_turn`), `test/unit/test_city_defense.gd`.
- **Validado**: GUT 1406/1406, 49 scripts (+47 testes). Cenários ponta a
  ponta: 3 esqueletos vs 2 guardas (repelidos, 6 turnos), vs cidade sem
  tropa (só milícia, 14), 2 goblins, vivern, 2 cidades IA, cidade humana.
  Troll invasor vs 3 guardas: ferido a 4.6/20 mas custou as 3 guardas.
  Harness de simulação (15 seeds×200 turnos) sem crash. Sem checagem visual
  (lógica; usa popup/toast já existentes).
- **Limitações**: sem expedição contra covil defendido (boss ×2.5 HP, exigiria
  coordenar grupo); unidades chegam uma a uma (turnos sequenciais) e a IA só
  reage ao que enxerga (visão de cidade = 4 tiles); Dragão fica no sistema
  próprio.

---

## Aggro / Território de Ameaça (2026-09-18)

- **Investigado antes**: dos 4 gatilhos pedidos, 2 já estavam cobertos pela
  Task 19 — "unidade entra na região" (raio de Guardião/Saqueador) e "cidade
  fundada perto" (ambos reavaliam ameaça TODO turno, então uma cidade nova
  dentro do raio é detectada no turno seguinte, sem precisar de um "evento
  de fundação" dedicado). Os 2 que faltavam eram genuinamente novos.
- **Gatilho 3 — melhorias próximas**: `_nearest_settlement_within` (cidade
  OU prédio de `buildings_by_coord`, o mais perto) agora alimenta tanto o
  Guardião (`_nearest_threat_within`) quanto o fallback do Saqueador. Igual
  a cidade: monstro só se aproxima/ameaça, nunca ataca a estrutura (nenhum
  monstro tem essa capacidade no jogo).
- **Gatilho 4 — jogador ataca membro do covil**: `HexGrid.alert_lair_near`
  (chamado em `CombatResolver._resolve_primary` sempre que jogador/rival
  acerta monstro neutro, matando ou não) marca o covil como ALERTADO por 8
  turnos (`LAIR_ALERT_DURATION_TURNS`); enquanto durar, `_guard_radius_for`/
  `_raider_radius_for` somam `ALERT_RADIUS_BONUS=3` ao raio — o território
  INTEIRO fica vigilante depois que UM membro apanha (Troll 5→8, Goblin
  4→7), não só quem foi atacado.
- **Calibração**: usei o "5 tiles" do pedido como referência — Troll já
  estava em 5 (Task 19), Goblin em 4; o bônus de alerta (+3) leva ambos a
  7-8 sem virar detector de mapa inteiro. `turn` é passado por parâmetro
  (`_take_guardian_turn` ganhou o parâmetro), mesmo padrão de Invasor/
  Saqueador, em vez de ler `TurnManager.turn_number` direto.
- **Persistência**: `lair_alerts` novo no save (mesmo padrão de
  `lair_structure_hp`/`pillaged_tiles`), com validação; `destroy_lair`
  limpa a entrada.
- **Arquivos**: `scripts/world/HexGrid.gd`, `scripts/core/MonsterAI.gd`,
  `scripts/core/CombatResolver.gd`, `scripts/autoload/SaveManager.gd`,
  `test/unit/test_monster_ai.gd` (+5), `test/unit/test_save_manager.gd` (+1).
- **Validado**: GUT 1359/1359, 48 scripts. Simulação headless real de 30
  turnos sem crash, alerta liga/expira nos turnos certos (5→13). Save/load
  do alerta confirmado por teste GUT dedicado (o script avulso que tentei
  antes reportou "não preservou" por um artefato do próprio script, não do
  código — descartado depois de confirmar o JSON salvo correto e o teste
  GUT passando). NÃO fiz screenshot visual desta task: é lógica de IA sem
  mudança de renderização, e a cobertura por teste é direta.
- **Limitações**: Invasor/Caçador não ganham bônus de alerta (já têm
  alcance grande/sem território, nenhum ganho claro). Alerta é por covil,
  não por atacante — provocar um covil o alerta contra QUALQUER civilização
  no raio, não só contra quem atacou.

## Comportamento dos Monstros (2026-09-18)

- **Causa raiz**: Guardião (Goblin/Troll default) só reagia a quem entrava
  num raio minúsculo (2 tiles) do próprio covil — passivo demais, exatamente
  o "só atacam se uma unidade passar adjacente" reportado. Esqueleto
  (Invasor) já funcionava bem (marcha sobre cidade, tema morto-vivo
  agressivo) — mantido sem mudança.
- **Fix — Goblin ganha comportamento próprio (Saqueador, `BEHAVIOR_RAIDER`
  novo)**: busca ATIVAMENTE presa fraca/isolada (mesmo critério do Caçador,
  reusado) num raio maior (4, vs 2 do Guardião) mas ainda preso ao próprio
  território — nunca atravessa o mapa como Invasor sozinho. Sem presa à
  vista, se aproxima da cidade mais próxima DENTRO do raio (nunca ataca a
  cidade em si, nenhum monstro tem essa capacidade) e sempre tenta saquear
  o tile onde termina o turno (reusa `_maybe_pillage_tile` do Invasor) —
  "ameaçar melhorias" na prática. Pondera risco antes de atacar
  (`is_favorable_attack`, não incondicional como Guardião) — "oportunista"
  de verdade. Um GRUPO que cresce o bastante continua virando Invasor real
  (mecanismo já existente, inalterado) — bando pequeno incomoda localmente,
  bando grande vira invasão.
- **Fix — Troll defende uma região maior**: continua Guardião (ataque
  incondicional, nunca sai do território), mas com raio configurável por
  tipo (`KIND_DATA.guard_radius=5` só pro Troll, resto cai no padrão 2) —
  E agora reage também a CIDADE inimiga se aproximando do território, não
  só unidade (pedido explícito do usuário).
- **Escolha deliberada**: evitei "todo monstro corre pra cidade mais
  próxima" — Saqueador e Guardião-regional continuam ANCORADOS no próprio
  covil (nunca abandonam o território), só o Invasor (Esqueleto, ou um
  bando de Goblin promovido) tem alcance de mapa inteiro. Caçador (Vivern/
  Dragão) já era suficientemente distinto (patrulha livre, pondera risco) —
  mantido sem mudança.
- **Arquivos**: `scripts/data/MonsterDatabase.gd`, `scripts/core/
  MonsterAI.gd`, `test/unit/test_monster_ai.gd` (5 testes antigos ajustados
  pra forçar Guardião explicitamente onde era o comportamento genuinamente
  testado — Goblin default mudou de kind, não a mecânica do Guardião em si
  — +9 testes novos).
- **Validado**: 1353/1353 testes GUT (48 scripts) cobrindo cada
  característica isoladamente (raio maior, nunca sai do território, só
  ataca alvo fraco/isolado, pilhagem, aproximação de cidade, raio do Troll,
  Troll reagindo a cidade). Simulação real de 40 turnos num mapa gerado
  (headless) sem nenhum crash; confirmado que reforços de verdade (o
  chefão original tem `movement_points=0` por design pré-existente, nunca
  se move) exercitam a busca ativa corretamente. Screenshot in-game real
  confirma Goblins renderizando/posicionando corretamente numa sessão real.
- **Limitações**: nenhuma técnica. Não toquei Wyvern/Dragão (Caçador) por
  não haver reclamação específica sobre eles, e a mecânica já lia como
  distinta o suficiente.

## Respawn de Covis — análise e decisão (2026-09-18)

**Pedido**: analisar se covis deveriam reaparecer ao longo da partida —
explicitamente "não implemente automaticamente só porque estou
sugerindo", avaliar impacto em exploração/pressão de monstros/mid game/
late game/micromanagement/economia/IA, e documentar a decisão final.

**Decisão: NÃO implementar respawn de covis.** O sistema já tem uma
resposta deliberada, documentada no próprio código, pro problema real
que respawn tentaria resolver ("o mundo fica mais perigoso com o
tempo") — `HexGrid._reinforce_chance(turn)`/`THREAT_TURN_RAMP_TURNS`
(60 turnos) já faz os covis QUE JÁ EXISTEM reforçarem mais depressa
conforme a partida avança, com o comentário do próprio autor original
explicando a escolha: "sem precisar inventar covil novo do zero". Task
18 confirma essa escolha em vez de revertê-la.

**Avaliação por dimensão pedida**:
- **Exploração**: mapa ficar "pacificado" depois de limpo é o arco
  normal de um 4X (early/mid game = fronteira perigosa, late game = foco
  muda pra diplomacia/guerra/rituais) — não é um problema a corrigir.
- **Pressão de monstros**: já escalada pelo reforço mais rápido em covis
  não limpos (mecanismo acima); um jogador que NEGLIGENCIA limpeza já
  sofre consequência crescente, sem precisar de covil novo nenhum.
- **Mid/late game**: o jogo já tem 3 condições de vitória (Dominação,
  Supremacia Militar, Transcendência) inteiramente sobre conflito
  jogador-vs-rival, não sobre monstro — o foco natural de late game já é
  esse, monstro persistente até o fim diluiria esse foco em vez de somar.
- **Micromanagement**: agravante DIRETO nesta sessão — Task 16/17 acabou
  de tornar destruir um covil uma ação deliberada de verdade (limpar
  defensor + atacar a estrutura até zerar HP). Respawn multiplicaria
  esse trabalho o jogo inteiro; o próprio pedido do usuário ("sem virar
  tarefa repetitiva irritante") pesa contra.
- **Economia**: covil novo = suprimento infinito de ouro/mana/experiência
  (Task 17) se o jogador simplesmente re-visitar regiões periodicamente —
  exatamente a "máquina de farm" que a Task 17 já tomou cuidado explícito
  pra evitar no design de recompensa por-covil.
- **IA**: `RivalAI._score_settle_candidate` só avalia `get_lair_danger_at`
  UMA VEZ, no momento de fundar uma cidade nova — nunca re-avalia depois.
  Um covil nascendo mais tarde perto de uma cidade JÁ fundada (rival ou
  do jogador) ignoraria essa cidade por completo, criando uma ameaça
  "surgida do nada" que nenhuma decisão anterior poderia ter evitado —
  mitigável com uma regra de distância mínima de cidade, mas é
  complexidade nova só pra reintroduzir um risco que o sistema atual não
  tem.
- **Alternativa considerada e também descartada**: "reduzir gradualmente
  a aparição conforme o mundo se civiliza" (a segunda sugestão do
  usuário) — tecnicamente viável (bastaria pesar `_threat_level` pela
  fração do mapa já colonizada), mas não há evidência de um problema
  atual que isso resolveria (nenhum relato, nada em docs/
  DEVELOPMENT_STATUS.md), e adicionaria complexidade nova a um sistema
  que já funciona pro objetivo declarado.

**Nenhuma mudança de código nesta tarefa** — decisão é preservar o
sistema atual como está. Se no futuro um playtest de verdade mostrar
mapas "mortos"/sem tensão no late game, a alavanca mais barata e menos
arriscada já existe: ajustar `THREAT_TURN_RAMP_TURNS`/
`LAIR_SPAWN_CHANCE_TURN_BONUS` (fazer os covis restantes ficarem MAIS
agressivos, não inventar covil novo) antes de considerar respawn de
verdade.

## Recompensas de Covis (2026-09-18)

- **Causa raiz**: destruir um covil (task anterior) só pagava ouro —
  válido, mas não usava nenhum outro sistema já existente do jogo, e o
  usuário pediu explicitamente para reavaliar "ouro; recurso; mana;
  experiência; combinação; recompensa específica por tipo".
- **Escolha deliberada**: combinação de TRÊS sistemas que já existem
  (nenhum novo) — ouro (inalterado), Mana (`PlayerData.mana`, campo já
  gasto em feitiços) e experiência (`Unit.register_kill()`, o mesmo
  sistema de veterania que combate normal já usa). "Recurso" (Ferro/
  Gemas/Seda/Cavalos) ficou de fora conscientemente: eles só existem como
  YIELD de tile trabalhado, sem estoque nenhum pra depositar — inventar
  um banco de recurso novo só pra isso contradiria "coerente com os
  sistemas atuais".
- **Recompensa específica por tipo**: `clear_reward_mana` novo em
  `MonsterDatabase.KIND_DATA` — 0 pra Goblin/Troll (mundanos, sem ligação
  arcana), 10 pra Esqueleto (morto-vivo, resíduo de necromancia), 20 pra
  Vivern e 35 pra Dragão (guardiões dos continentes Vulcânico/de Cristal,
  identidade arcana já estabelecida no próprio jogo). O crédito de abate
  (`register_kill()`) é universal — qualquer tipo de covil destruído
  conta como vitória de combate de verdade pro atacante.
- **Nunca vira farm infinita**: cada covil só paga isto UMA VEZ — a
  estrutura nunca respawna depois de destruída (mesma garantia da task
  anterior). O `gold_reward` por abate individual (repetível via reforço)
  é um sistema PRÉ-EXISTENTE e separado, fora do escopo desta tarefa.
- **Arquivos**: `scripts/data/MonsterDatabase.gd`, `scripts/world/
  HexGrid.gd`, `test/unit/test_selection_manager.gd` (+2 testes).
- **Validado**: screenshot in-game real de um covil de Vivern mostra a
  notificação real "...saqueou 130 ouro e 20 de mana!", HUD atualizando
  Mana corretamente, e o atacante ganhando veterania (2 abates: guardião
  em combate normal + a estrutura). Pego e corrigido no caminho: um erro
  de inferência de tipo (`var x := ...`) que fazia o GUT ignorar o
  arquivo de teste inteiro silenciosamente (48→47 scripts) — mesma
  categoria de bug já documentada em sessões anteriores, resolvido com
  anotação de tipo explícita. GUT: 1344/1344, 48 scripts.
- **Limitações**: nenhuma técnica; os valores de Mana (10/20/35) foram
  calibrados olhando o custo típico de feitiço (25-60 de Mana) pra dar
  uma fração relevante mas não gratuita — não uma fórmula analítica.

## Covis de Monstros — destruição (2026-09-18)

- **Causa raiz**: matar o(s) defensor(es) já era combate de verdade, mas
  a ESTRUTURA (`LairStructure`) não tinha stat nenhum — bastava "visitar"
  o tile vazio (`move_unit` → `_grant_lair_clear_reward`) pra destruir e
  ganhar a recompensa, sem ação deliberada.
- **Fix**: `LairStructure` ganhou HP/defesa reais, derivados do próprio
  `MonsterDatabase.KIND_DATA` do monstro guardião (0.3× o max_hp do kind
  como HP de estrutura, defesa igual à do kind) — reusa números já
  balanceados em vez de uma tabela nova. `CombatResolver.
  resolve_lair_attack` (mesma arquitetura de `resolve_city_attack`) só
  fica disponível depois que a área do covil está genuinamente indefesa;
  dano reduz HP, HP≤0 destrói e paga a recompensa de sempre
  (`lair_clear_reward`, inalterada). `SelectionManager` agora trata a
  estrutura indefesa como alvo de **ataque** real (não mais de
  movimento) — removido o antigo gatilho em `move_unit`.
  `compute_reachable`/`compute_path` bloqueiam o tile enquanto a
  estrutura existir (não só enquanto defendida), então não dá mais pra
  simplesmente andar até lá.
- **Calibrado contra a fórmula real de dano** (não um chute): Goblin/
  Esqueleto (comuns) caem num único golpe extra de um Guerreiro comum;
  Troll/Vivern pedem 2-3 golpes de verdade; Dragão é deliberadamente
  quase imune a um Guerreiro básico (precisa de cerco/unidade forte) —
  "tipo do monstro" e "força do covil" ficam embutidos no próprio kind,
  sem tabela paralela. "Estágio da partida" já era coberto pelo mecanismo
  existente de reforço crescer com o turno (`_reinforce_chance`) — não
  duplicado aqui de propósito, pra não inflar complexidade.
- **Persistência**: HP parcial da estrutura agora sobrevive save/load
  (`lair_structure_hp`, mesmo padrão de `pillaged_tiles`) — sem isso o
  progresso de um cerco em andamento se perderia ao recarregar.
- **Arquivos**: `scripts/world/LairStructure.gd`, `scripts/core/
  CombatResolver.gd`, `scripts/autoload/SelectionManager.gd`,
  `scripts/world/HexGrid.gd`, `scripts/autoload/SaveManager.gd`,
  `test/unit/test_selection_manager.gd` (+2 testes),
  `test/unit/test_hex_grid_movement.gd`, `test/unit/test_save_manager.gd`,
  `test/unit/test_monsters.gd` (3 testes obsoletos do mecanismo antigo
  removidos/substituídos).
- **Validado**: fluxo completo num mapa real (headless) — bloqueado
  enquanto defendido, ainda bloqueado (mas agora atacável) quando
  indefeso, dano parcial confirmado numericamente, save/load preserva o
  HP parcial exato, recompensa exata na destruição, tile volta a andar
  livre só depois. Screenshot in-game real mostra as duas notificações
  reais em sequência ("derrotou Vivern... 70 ouro" + "destruiu covil
  abandonado... 130 ouro"). GUT: 1342/1342, 48 scripts.
- **Limitações**: RivalAI não foi ensinado a buscar/atacar covis
  indefesos deliberadamente (comportamento novo de IA, fora do escopo
  pedido) — só o jogador humano se beneficia do fluxo completo por
  enquanto.

## Covis de Monstros — sobreposição (2026-09-18)

- **Causa raiz**: o guardião ORIGINAL sempre nascia exatamente em
  `lair_coord`, o mesmo tile da `LairStructure` (duas malhas no mesmo
  lugar, by design). Reforços podiam "reocupar o covil" no mesmo tile
  depois do guardião morrer, e a patrulha podia mover um morador de volta
  pra lá também — três pontos diferentes causando a mesma sobreposição.
- **Fix**: `_find_free_tile_for_lair_spawn` agora exclui `lair_coord` dos
  candidatos (reforço/patrulha só usam os 6 vizinhos); o guardião original
  em `_spawn_monster_lairs` reusa essa mesma função pra nascer AO REDOR,
  só caindo de volta pro próprio tile no caso limite de área inteira
  bloqueada (ilha de 1 tile).
- **Regressão séria pega ANTES de fechar a task**: sem o guardião
  fisicamente em cima de `lair_coord`, esse tile ficava sempre "livre"
  pra `compute_reachable`/`compute_path` — qualquer unidade podia andar
  até um covil AINDA DEFENDIDO e receber a recompensa de limpeza sem
  nunca lutar contra o guardião (guardião só bloqueava por acidente de
  ocupar o tile fisicamente antes). Corrigido com `_is_lair_coord_still_
  defended()`: o tile do covil continua intransponível enquanto houver
  qualquer monstro vivo na área (mesmo critério de `_count_live_monsters_
  near_lair`), restaurando o mecanismo de "precisa vencer o guardião"
  exatamente como antes. `get_lair_danger_at` (heurística de IA "é
  perigoso morar perto deste covil") tinha o mesmo problema — também
  corrigido pra checar a área inteira, não só a célula exata.
- **Arquivos**: `scripts/world/HexGrid.gd`, `test/unit/test_monsters.gd`
  (+3 testes), `test/unit/test_save_manager.gd` (3 testes ajustados pra
  achar o guardião pela flag `is_camp_boss` na área, não mais por
  coordenada exata), `test/unit/test_hex_grid_movement.gd` (+2 testes).
- **Validado**: screenshot in-game real confirma guardião (wyvern) e
  estrutura em tiles adjacentes separados, sem sobreposição. Timing de
  `compute_reachable` (movimento=20, mapa Grande, 13 covis) ~23ms/chamada
  — checagem extra é uma comparação O(13) short-circuited antes do custo
  real, sobrecarga desprezível. GUT: 1343/1343, 48 scripts.
- **Limitações**: fallback de sobreposição ainda existe pro caso
  geometricamente impossível (covil numa ilha de 1 tile sem vizinho
  compatível) — preferido a não ter guardião nenhum, deve ser raríssimo
  na prática.

## Altura dos tiles e posição das unidades (2026-09-18)

- **Causa raiz**: `world_for_coord()` só devolve `base_height` (a base
  crua/plana do prisma) — Colina/Montanha (e variantes Vulcânica/Cristal)
  ganham um domo/pico VISUAL por cima disso só no `terrain.gdshader`, que
  o GDScript nunca via. Todo posicionamento de unidade (`spawn_unit`,
  `spawn_monster_at`, `move_unit`, `_animation_waypoints`,
  `teleport_unit`, patrulha de covil) usava `world_for_coord` puro —
  mesma causa raiz já corrigida antes só pra props de recurso
  (`ResourcePropsManager._tile_surface_height`), nunca estendida pra
  unidade.
- **Fix**: `world_surface_for_coord()` novo (mesma posição, Y por
  `_tile_surface_height`) substituindo `world_for_coord` em TODO ponto
  que posiciona unidade/monstro/invocação/boss — solução única e
  genérica, não um ajuste por modelo (o pivô "pés na origem" já era
  consistente entre modelo procedural e externo, não precisou mexer
  ali). "Mudanças temporárias de terreno": `transform_tile_terrain`
  agora reposiciona na hora qualquer unidade já parada no tile afetado,
  cobrindo o caso de uma unidade ficar parada num tile transformado por
  magia até o efeito expirar. Cidade/Prédio/covil deliberadamente FORA
  do escopo (não pedido — só "personagem/unidade"), continuam em
  `world_for_coord` puro.
- **Arquivos**: `scripts/world/HexGrid.gd`, `test/unit/
  test_hex_grid_movement.gd` (4 testes novos).
- **Validado**: 4 testes numéricos novos confirmam a altura exata
  (Colina = base+0.35, Montanha = base+0.9, terreno plano sem bônus,
  reposicionamento após transformação) — mais direto e confiável que
  julgar visualmente uma diferença sutil de altura numa screenshot.
  Screenshot in-game complementar (monstro numa Montanha, invocação numa
  Colina vizinha) não mostrou nenhum pé visivelmente afundado. GUT:
  1339/1339, 48 scripts.
- **Limitações**: Cidade/Prédio/covil (LairStructure) têm a MESMA causa
  raiz em teoria (também usam `world_for_coord` puro) mas não foram
  tocados — fora do escopo pedido (só unidades/personagens); se isso for
  um problema observado depois, é a mesma solução (`world_surface_for_
  coord`) aplicada a esses 3 pontos.

## Magias, Spawns e Árvores (2026-09-18)

- **Investigado primeiro**: auditei todo caminho de criação de unidade —
  `HexGrid.spawn_unit`/`spawn_monster_at`, `MagicRuntime.summon`/
  `valid_target` (skeleton/guardian/beast/legion), `add_region` — nenhum
  deles jamais checou árvore pra decidir se um spawn/invocação é válido,
  só `blocks_land_units()` (água/lava/montanha) e "já tem unidade aqui".
  Um "não consigo conjurar aqui" nunca foi uma falha de verdade — é a
  criatura nascendo visualmente enterrada numa árvore, mesma causa raiz
  da task anterior, agora pra UNIDADE em vez de ESTRUTURA.
- **Fix**: `_clear_tile_decor_at()` (já existente, ver task anterior)
  agora também roda dentro de `HexGrid.spawn_unit()` e `spawn_monster_at
  ()` — os DOIS pontos únicos por onde qualquer unidade nova passa a
  existir (treino de cidade, invocação mágica, reforço/guardião de
  covil). Política deliberadamente uniforme (não só invocação) — uma
  regra que valesse só pra magia recriaria a mesma inconsistência pro
  treino normal de cidade, o oposto do "política coerente" pedido.
  Removida a chamada duplicada que existia em `_spawn_monster_lairs`
  (agora redundante, `spawn_monster_at` já cobre).
- **Arquivos**: `scripts/world/HexGrid.gd`, `test/unit/test_monsters.gd`
  e `test/unit/test_magic_v1.gd` (1 teste novo cada).
- **Validado**: screenshot in-game real — invocação forçada
  (`bound_skeleton`) num tile de Floresta real do mapa Grande nasce
  visivelmente limpa, sem árvore encostada, vizinhança segue arborizada
  normalmente. GUT: 1335/1335, 48 scripts.
- **Limitações**: nenhuma técnica; efeitos de área (aurora/storm/
  consecrate/etc, via `MagicOverlay`) não precisaram de mudança — já
  renderizam acima do topo das árvores ou rente ao chão, sem
  sobreposição real observada.

## Construções sobre tiles com árvores (2026-09-18)

- **Investigado antes de mexer, nenhum código alterado nesta task**:
  auditei `City.is_valid_building_tile`, `found_city`/`found_city_with_
  selected`, `HexTileData.blocks_land_units` e todos os campos de
  `BuildingData` — nenhum bloqueio por Floresta/Taiga/Selva existe ou
  jamais existiu (só água/lava/montanha bloqueiam construção/unidade
  terrestre). O "bloqueio artificial" percebido era visual: antes do fix
  da task anterior ("Árvores e Recursos"), construir num tile arborizado
  deixava a árvore visualmente encostada/por cima da estrutura, parecendo
  que a construção não "pegou" direito.
- **Conclusão**: o pedido desta task — remoção automática e integrada da
  vegetação ao construir, sem etapa manual, sem quebrar mecânica real —
  já é exatamente o que `HexGrid._clear_tile_decor_at()` (implementado na
  task anterior) faz em `found_city`/`place_building`/`_spawn_monster_
  lairs`. Nenhuma mudança nova foi necessária.
- **Verificação extra feita nesta task**: conferi a direção oposta
  (magia transformando terreno EM Floresta) — `MagicRuntime.valid_
  terrain()` já exclui qualquer tile com cidade/prédio (`grid.get_city_at
  ()`/`get_building_at()`), então um efeito mágico nunca planta árvore
  em cima de uma estrutura existente.
- **Validado**: script headless dedicado — Floresta já era alvo válido
  de construção ANTES do fix; após `place_building`, terrain_type/food_
  yield/production_yield/defense_bonus do tile continuam idênticos (a
  mecânica real de Floresta, ligada só ao terreno, nunca foi tocada); o
  prop de árvore foi removido automaticamente. Nenhuma mudança de código
  nesta task, então a suíte GUT (1333/1333) permanece a mesma da task
  anterior — não foi re-executada por não haver diff nenhum pra validar.
- **Limitações**: nenhuma — se no futuro surgir um prédio cuja função
  dependa de floresta INTACTA (ex: um posto madeireiro temático), esse
  caso precisaria de uma exceção explícita, mas nada assim existe hoje
  no jogo.

## Árvores e Recursos — sobreposição com estruturas (2026-09-18)

- **Causa raiz investigada primeiro**: recurso-vs-árvore já era coerente
  (tile com recurso nunca ganha árvore, preservado sem mudança). O que
  faltava era o inverso: quando uma cidade/prédio/covil de monstro passa
  a ocupar um tile DEPOIS que a árvore/prop de recurso já foi plantada
  ali, nada removia o prop antigo. Confirmei com screenshot antes de
  mexer: capital real, cidade de teste e covil natural apareciam com
  árvore encostada ou por cima do próprio modelo; cidade fundada sobre
  recurso deixava o cristal/minério flutuando dentro do pátio.
- **Fix**: `HexGrid._clear_tile_decor_at(coord)` (novo, reaproveitando a
  remoção de árvore que já existia em `_refresh_changed_terrain_visuals`,
  agora extraída pra `_clear_tree_props_at`) + `ResourcePropsManager.
  clear_prop_at`/`ResourceIconManager.clear_icon_at` novos. Chamado em
  `found_city`, `place_building` e `_spawn_monster_lairs` — as 3
  estruturas permanentes que nascem depois da geração inicial de
  árvores/recursos. Não mexe em `.resource` do tile (yield continua
  valendo), só no objeto 3D decorativo.
- **Avaliado e propositalmente NÃO alterado**: unidades (inclusive
  Dragão, que é uma Unit) — são ocupantes transitórios, não donas
  exclusivas do tile; screenshot confirmou que continuam legíveis ao
  lado de árvores, sem "enterrar". Efeitos de magia (`MagicOverlay`) já
  ficam acima do topo das árvores ou rente ao chão, sem conflito
  observado.
- **Arquivos**: `scripts/world/HexGrid.gd`, `scripts/world/
  ResourcePropsManager.gd`, `scripts/world/ResourceIconManager.gd`,
  `test/unit/test_city.gd` (2 testes novos).
- **Validado**: mesmos 3 cenários refeitos visualmente após o fix —
  covil/cidade agora nascem em tile limpo, vizinhança continua
  arborizada normalmente. GUT: 1333/1333, 48 scripts.
- **Limitações**: nenhuma limitação técnica identificada nos 3 casos
  corrigidos; escopo deliberadamente não estendido a unidades/efeitos
  por não haver problema visual real observado ali.

## Árvores/Florestas — densidade visual (2026-09-18)

- **Causa raiz**: `_rebuild_props()` dava 3-5 árvores a TODO tile de
  Floresta/Taiga/Selva sem recurso, sem exceção — cobertura 100%, sem
  clareira nenhuma, no mapa Grande isso é ~1126 tiles elegíveis, todos
  cobertos.
- **Fix**: `TREE_TILE_COVERAGE_CHANCE := 0.6` — por tile elegível, chance
  de receber árvores (mesma contagem 3-5 de antes) ou ficar como
  clareira. Aplicado só na geração de mapa (`_rebuild_props`); o caminho
  de UM tile por vez do efeito mágico "Metamorfose de Gaia"
  (`_refresh_changed_terrain_visuals`) foi deliberadamente deixado FORA
  — é um evento raro/único, não o "mapa carregado" da geração em massa,
  e mexer lá quebraria o teste determinístico existente
  (`test_magic_v1.gd`) sem ganho nenhum.
- **0.6 não foi aceito de olhos fechados**: testado visualmente (Selva e
  Floresta, mapa Grande, screenshot in-game real) antes de fixar —
  clareiras ficaram legíveis nos dois biomas sem perder cara de
  floresta/selva.
- **Arquivo**: `scripts/world/HexGrid.gd` (`TREE_TILE_COVERAGE_CHANCE` +
  filtro em `_rebuild_props`).
- **Validado**: mapa Grande real — 1126 tiles elegíveis, 673 cobertos
  (59.8%, bate com o alvo), ~2710 instâncias de árvore no total (era
  ~4500 com cobertura 100%, redução de ~40% nos objetos renderizados).
  Timing `generate_map(320,84)` = 2932ms, dentro do baseline. GUT:
  1331/1331, 48 scripts.
- **Limitações**: valor único para os 3 biomas (Floresta/Taiga/Selva),
  não calibrado por bioma individualmente — o usuário pediu para não
  tratar como lei fixa, então se algum bioma específico parecer
  denso/vazio demais num mapa real, é só reajustar a constante e
  reavaliar visualmente.

## Anti-cluster de recursos (2026-09-18)

- **Investigado antes de mexer**: medi o mapa Grande real (3 seeds,
  script descartável) antes de assumir causa — `RESOURCE_SAME_TYPE_
  MIN_DISTANCE` (Task 6) já garantia `min_dist_real=3` em TODO par do
  mesmo recurso, ou seja, "grudado" (distância 1-2) já era IMPOSSÍVEL.
  O que faltava: nada limitava quantos exemplares do MESMO recurso se
  acumulavam numa região MAIOR — medi até 6 do mesmo tipo dentro de um
  raio 5 num único tile, formando um "veio" perceptível mesmo sem
  nenhum par realmente encostado.
- **Fix**: `_resource_cluster_reject()` nova — penalidade de
  probabilidade PROGRESSIVA (não corte binário) por vizinhança: cada
  exemplar do mesmo recurso já dentro de `RESOURCE_CLUSTER_RADIUS=5`
  soma `0.35` de chance de rejeição (teto `0.9`, nunca proibição
  absoluta). 1 vizinho quase nunca rejeita (preserva "proximidade
  interessante" pedida); 3+ vizinhos vira raro por design. Chamada
  depois do corte duro de sempre, mesmo canal de RNG determinístico
  (`map_seed+8000`).
- **Arquivos**: `scripts/world/HexGrid.gd` (`_resource_cluster_reject`
  + 3 constantes novas, comentário completo da causa raiz e do porquê
  da abordagem escolhida vs. as outras listadas pelo usuário),
  `test/unit/test_resources.gd` (teste novo isolado, sem gerar mapa
  inteiro, valida que a taxa de rejeição sobe com o nº de vizinhos).
- **Validado**: re-medindo o mesmo mapa/seeds — máximo de vizinhos no
  raio 5 caiu de 6 para 4, contagem TOTAL de cada recurso permaneceu
  IDÊNTICA antes/depois (orçamento da Task 8 preservado, só a
  distribuição espacial mudou). GUT: 1331/1331 (48 scripts, +1 teste
  novo). Timing `generate_map(320,84)` ~2.8s, sem regressão.
  Screenshot in-game confirma região de Gemas na Selva com ícones bem
  espalhados, sem bloco grudado.
- **Limitações**: constantes (raio 5, incremento 0.35, teto 0.9) foram
  calibradas observando os números, não derivadas analiticamente —
  mesmo espírito das densidades da Task 8; cluster de 5-6 ainda pode
  ocorrer em teoria (nunca é 100% proibido, por pedido explícito do
  usuário de manter "raro e justificado" em vez de impossível).

## Orçamento global de recursos (2026-09-18)

- **Causa raiz**: `_maybe_assign_resource` aplicava uma chance INDEPENDENTE
  por tile (via ruído), sem noção de escala — mapa grande e pequeno usavam
  a mesma probabilidade absoluta, então a contagem total só crescia (ou
  não) por acaso, sem alvo nenhum por recurso.
- **Fix**: substituído por `_assign_resources()`, orçamento por recurso
  calculado do total de tiles do mapa: `min_per_type`/`max_per_type` via
  divisores de escala (`RESOURCE_MIN_DIVISOR`/`RESOURCE_MAX_DIVISOR`),
  alvo = `candidatos_elegiveis × densidade_base` (clampado no min/max), com
  piso extra proporcional ao nº de jogadores (`player_count * 0.5`).
  Candidatos ordenados por sorteio ponderado (Efraimidis-Spirakis, mesma
  técnica de `weight_for`) determinístico pela seed, respeitando ainda a
  distância mínima entre recursos iguais (Task 6).
- **Densidades tunadas** (`RESOURCE_BASE_DENSITY`) após medir 10 seeds no
  mapa Grande: gemas 0.06→0.04 e seda 0.07→0.06, porque ambas bateram
  EXATAMENTE no teto em 10/10 seeds — usuário pediu variância real, não
  limite rígido disfarçado.
- **Arquivos**: `scripts/world/HexGrid.gd` (`_assign_resources`,
  `_weighted_shuffle`, remoção de `_maybe_assign_resource` e do canal de
  ruído `_resource_noise`), `test/unit/test_resources.gd` (doc-comment).
- **Validado**: estatística multi-seed/multi-tamanho/multi-jogadores —
  Grande 320×84 (10 seeds): ferro 30.0±3.5, gemas 49.3±3.9, seda 40.5±6.4,
  nódulo 44.5±2.5, cavalos 30.6±4.0, zero clusters em todas; Pequeno 21×21
  (5 seeds): 2-4 de cada; Gigante 500×150 (3 seeds): densidade continua
  abaixo do teto (não é o teto que domina). Timing `generate_map(320,84)`
  = 2790ms, dentro do baseline ~2.5-2.8s. GUT: 1330/1330, 48 scripts.
  Screenshot in-game (mapa real, região mais densa) confirma ícones e
  props renderizando certo, sem glitch.
- **Limitações**: piso por nº de jogadores nunca chega a ativar no único
  tamanho de mapa hoje shippado (o piso de tamanho de mapa sempre domina)
  — só teria efeito relevante em mapas bem pequenos; ferro escala pouco no
  mapa Gigante porque está preso à proporção de Colina/Tundra do bioma,
  não é falha do orçamento; densidades e divisores foram calibrados
  empiricamente (observando os números), não derivados de uma fórmula.

## Recursos x Biomas — preferência ponderada (2026-09-18)

- **Avaliação por recurso** (função, raridade, bioma temático — ver
  comentário completo em `ResourceDatabase.gd`): Ferro (produção + desconto
  unidade pesada) → Colina seguia fazendo sentido, Montanha já excluída
  antes. Cavalos (comida+produção+desconto Cavalaria) → 3 biomas com peso
  IGUAL era a causa raiz de "abundante demais". Gemas (ouro+desconto
  rush-buy) → Selva/Floresta/Taiga sem nenhum encaixe óbvio de "cristal no
  deserto" (exemplo do próprio usuário). Seda (ouro+rotas) → já fazia
  sentido. Nódulo Arcano (mana+desconto feitiço) → faltava o encaixe
  temático ÓBVIO: Campos de Cristal (`TerrainType.CRYSTAL`, bioma arcano
  dedicado, comentário do próprio arquivo: "combina com Torre Arcana/
  Mago") nunca estava na lista de elegibilidade.
- **Mudança estrutural**: `ELIGIBILITY` (lista binária elegível/não) virou
  `BIOME_WEIGHTS` (peso 0.0-1.0 por bioma). `HexGrid._maybe_assign_resource`
  agora sorteia PROPORCIONAL ao peso (determinístico pela seed, sem ruído
  extra) em vez de peso igual entre elegíveis — pedido explícito do
  usuário: "deserto aumenta significativamente a chance", nunca "deserto =
  garantido". `eligible_resources()` (usado por testes existentes) deriva
  de `BIOME_WEIGHTS`, mesma assinatura, sem quebrar nada.
- **Adições**: Cristal vira preferencial de Nódulo Arcano (bioma já raro
  por design — mesma raridade da Lava — recurso raro em bioma raro, não
  virou onipresente); Deserto vira secundário forte de Gemas (o próprio
  exemplo do usuário, "cristal no deserto"); Tundra vira secundário de
  Ferro. As três eram biomas 100% sem recurso antes.
- **Limitação técnica constatada e reportada, não escondida**: o peso só
  tem efeito MECÂNICO quando 2+ recursos disputam o MESMO bioma (Colina:
  Ferro×Nódulo; Floresta: Gemas×Seda×Nódulo; Selva: Gemas×Seda) — nesses
  casos o peso maior realmente ganha mais vezes (confirmado medindo).
  Para biomas com um ÚNICO recurso elegível (Planície/Campina/Savana só
  têm Cavalos; Deserto/Taiga só têm Gemas; Tundra só tem Ferro), o valor
  exato do peso não muda a densidade — o recurso aparece sempre que o
  limiar de ruído já existente permite, independente do peso escolhido.
  Considerei um segundo estágio (peso também filtrar a presença) mas
  descartei: invertia a ordem esperada entre biomas concorrentes (Deserto
  passava a ter MAIS Gemas que Selva, o oposto do pretendido) — decidido
  não perseguir essa correção por ser complexidade desproporcional ao
  pedido, e a mudança já central (Cristal/Deserto/Tundra deixarem de ser
  vazios; competição ponderada nos biomas com disputa real) já entrega o
  essencial pedido.
- **Arquivos**: `scripts/data/ResourceDatabase.gd`, `scripts/world/HexGrid.gd`.
- **Validado**: suíte GUT 1330/1330; medição em 5 seeds (mapa Grande) —
  Deserto/Tundra/Cristal passaram a ter 5-25 tiles com recurso cada
  (~8-12% de densidade, igual ao resto do mapa); 0 pares grudados mantido
  em todas; custo de `generate_map` ~2,5s, igual à faixa já documentada.
  Confirmado visualmente: Nódulo Arcano renderizando corretamente sobre
  Campos de Cristal (screenshot real, mapa Grande).

---

## Distribuição de Recursos — clusters (2026-09-18)

- **Causa raiz (confirmada matematicamente)**: `_maybe_assign_resource`
  escolhia QUAL recurso via hash linear `(x*31 + y*17) % N`. Pra Colina (2
  elegíveis: Ferro/Nódulo Arcano) isso vira `(x+y) % 2` — um tabuleiro de
  xadrez puro por paridade, sem nada de seed/aleatório. Pior: as direções
  de vizinho (1,-1)/(-1,1) PRESERVAM essa paridade, então uma fileira
  diagonal inteira de Colinas cai sempre no MESMO recurso. "Cavalos" e'
  o ÚNICO recurso elegível em 3 biomas comuns (Campina/Planície/Savana,
  `eligible.size()==1` → índice sempre 0) — explica sozinho a
  abundância de Cavalos no mapa inteiro.
- **Fix**: `hash(Vector3i(coord, map_seed))` no lugar da fórmula linear
  (quebra o padrão geométrico fixo, continua determinístico/barato, sem
  ruído extra) + `RESOURCE_SAME_TYPE_MIN_DISTANCE = 2`: antes de aceitar
  um recurso, checa se já existe o MESMO tipo a até 2 tiles (varredura de
  `generate_map` sempre na mesma ordem, então "já gerado" cobre a
  vizinhança real) e tenta a próxima opção elegível; se todas colidem,
  o tile fica sem recurso (reduz densidade local em vez de empilhar).
  Não mexe em `ResourceDatabase.ELIGIBILITY`/thresholds (balanço de jogo,
  fora do escopo de "revisar o algoritmo").
- **Medido em 4 seeds** (mapa Grande, comparando com a fórmula antiga
  recalculada sobre o mesmo mapa): pares "grudados" (mesmo recurso a
  distância ≤1) caíram de 39-48 pra **0** em todas; Cavalos caiu ~30-39%;
  total de recursos caiu ~22-24% (~200-230 em vez de ~255-308, ainda uma
  quantidade relevante); maior região conectada sem recurso nenhum
  praticamente não mudou (+3-5%, já era grande antes — não é regressão
  introduzida, é característica do ruído de presença, que não foi tocado).
  Custo de `generate_map` (320×84): 2,49s, dentro da faixa já documentada.
- **Arquivos**: `scripts/world/HexGrid.gd` (só `_maybe_assign_resource` +
  novo helper `_resource_nearby`).
- **Validado**: suíte GUT 1330/1330; screenshot de mapa Grande real
  mostrando a região mais rica em recursos (11 recursos num raio de 4) —
  boa variedade, nenhum par do mesmo tipo a menos de 3 tiles de distância.
- **Não feito**: não mexi na densidade macro (ruído de presença) nem em
  ELIGIBILITY — regiões "boas"/"ruins" continuam existindo por design,
  só sem empilhamento do mesmo tipo dentro delas.

---

## Minimapa — redesenho visual/funcional (2026-09-18)

- **Causa dos problemas visuais**: `Minimap.gd` desenhava um `draw_rect`
  preto chapado sem moldura nenhuma (não reusava `UITheme`, único widget do
  HUD assim) e `HUD.tscn` posicionava o Control com um offset_bottom de
  -128 sem motivo aparente (nenhum outro elemento por perto justificava),
  deixando um vão vazio até o canto — daí o "não alinhado"/"borda preta".
- **Fix visual**: painel agora usa `UITheme.panel_style` (mesma moldura
  bronze arredondada de qualquer outro painel do jogo) com padding interno
  pro conteúdo nunca vazar por cima do canto arredondado. Reposicionado
  pra encostar no canto (8px de margem, mesma convenção do `ActionBar` no
  canto oposto) e redimensionado de 200×180 (quase quadrado) pra 260×64,
  proporção bem mais fiel à do mapa real (~4,9:1 num mapa Grande) — antes
  o mapa aparecia espremido verticalmente.
- **Indicador de câmera (novo)**: retângulo pedido virou um TRAPÉZIO de
  verdade — a câmera é inclinada, então a área do chão visível não é um
  retângulo, é um trapézio; calculado via raycast dos 4 cantos da tela
  contra o plano Y=0 (mesma referência que a própria câmera já usa pro
  pan), só contorno (nunca esconde o mapa por baixo). `GameManager.
  camera_rig` (novo, mesmo padrão já usado por `hex_grid`) dá ao Minimap
  acesso à câmera sem acoplar HUD/Main diretamente.
- **Performance do indicador**: `_process()` só pede redraw quando a
  câmera realmente mudou (comparação de posição/rotação/zoom, 3
  comparações por frame) — o redraw caro (todos os tiles, ~27 mil num mapa
  Grande) continua só em eventos de fog, nunca por frame.
- **Arrastar pra navegar (opcional, implementado)**: clicar já funcionava;
  adicionado arrasto contínuo (`InputEventMouseMotion` enquanto o botão
  está segurado) — natural e de baixo risco, mesmo `EventBus.
  minimap_clicked` de sempre.
- **Arquivos**: `scripts/ui/Minimap.gd`, `scenes/ui/HUD.tscn`,
  `scripts/autoload/GameManager.gd`, `scripts/main/Main.gd` (1 linha).
- **Validado**: suíte GUT 1330/1330; screenshot real (mapa Grande) confirma
  moldura/proporção/posição corretas; clique/arrasto testados chamando
  `_gui_input` direto (coordenadas de mundo simétricas e corretas,
  movimento pós-soltar não gera clique fantasma); trapézio testado em
  zoom mínimo/máximo + pan extremo, tamanho e posição acompanham
  corretamente.
- **Não feito**: sem indicador separado pra "cliques recentes"/animação de
  transição ao clicar (não pedido); sem correção de aspecto quando a
  janela é redimensionada em tempo real (Control já reancora via anchors,
  não testado especificamente em resoluções não-padrão).

---

## Névoa de Guerra — estética/performance (2026-09-18)

- **Profiling primeiro**: custo de GPU do shader de nevoa é desprezível
  (~0,13ms/frame de diferença entre tela cheia de nuvem animada vs sem
  nevoa nenhuma, medido não-headless com V-Sync off). Decisão: não
  redesenhar shader/efeito nenhum — já é barato, trocar por algo mais
  "bonito" seria puro risco sem ganho (pedido explícito do usuário).
- **Transições/diferenciação do TERRENO**: já eram suaves e bem
  diferenciadas (nuvem animada = Nunca-explorado, tom sépia estático =
  Explorado, cor plena = Visível, blend suave via textura de baixa
  resolução + smoothstep) — nada mudado aqui, já atendia o pedido.
- **Bug real encontrado**: PROPS (árvore, cavalo, ícone de recurso) quase
  não mudavam de aparência entre Visível e Explorado — pareciam sempre em
  cor plena, quebrando a diferenciação e lendo como "artificial". Causa:
  o tom sépia desses props é aplicado como MULTIPLICADOR de cor de
  instância (`vertex_color_use_as_albedo`/`modulate`/`albedo_color`), e
  multiplicação não muda matiz de uma textura verde saturada — só escurece
  um pouco (confirmado isolando o material numa cena à parte: instância
  branca vs a cor sépia calculada, quase idênticas). O terreno sólido não
  tem esse problema porque usa `mix()` de verdade no shader.
- **Fix**: `PROP_SEPIA_DARKEN` (`HexGrid.gd`) de 0.4 para 0.72 — a única
  alavanca real dentro de um esquema de multiplicação. Não vira sépia de
  verdade, mas fica visivelmente sombrio/apagado, nitidamente diferente de
  Visível (cor plena) e de Não-explorado (alfa 0, some). Reescrever pra
  blend de verdade exigiria shader próprio por tipo de prop — refatoração
  ampla desproporcional, não feita.
- **Arquivos**: `scripts/world/HexGrid.gd` (só a constante + comentário).
- **Validado**: suíte GUT 1330/1330; comparação visual isolada (2 árvores,
  branca vs sépia) e em floresta real (mapa Grande, Visível/Explorado/
  Não-explorado lado a lado) confirmando diferenciação clara antes/depois.
- **Não feito**: nenhum redesenho do padrão de nuvem (já é barato e
  visualmente aceitável); não convertido o sistema de props pra shader
  próprio (ganho marginal vs. risco/escopo).

---

## Névoa de Guerra — vazamento de costa (2026-09-17)

- **Bug**: linhas escuras finas seguiam o contorno EXATO da costa por baixo
  da nevoa, denunciando o formato do continente (confirmado por screenshot
  isolado, GUT nao cobre visual de shader).
- **Causa raiz** (isolada testando com luz direcional zerada — a linha
  sumia): a "parede"/saia do prisma de terreno (desce ate abaixo do nivel
  da agua) so fica exposta na costa, e `terrain.gdshader` achatava o
  NORMAL da nevoa so no TOPO do tile (`is_top_face`) — a parede mantinha o
  normal horizontal original mesmo com a COR ja correta (cinza uniforme).
  Mesma cor, N·L diferente sob luz direcional = linha visivel tracando a
  costa real.
- **Fix**: 1 linha nova em `terrain.gdshader` (`vertex()`) — acha tambem o
  normal da parede pra (0,1,0) quando o tile nao esta VISIVEL agora (mesma
  mascara `shape_mask` ja usada pro topo). Nao mexe em nada quando
  visivel/explorado normalmente.
- **Arquivos**: `shaders/terrain.gdshader` (so isso).
- **Validado**: suíte GUT 1330/1330 (shader nao e coberto por teste, so
  confere que nada mais quebrou); comparação visual antes/depois isolando
  luz ambiente vs direcional confirmou a causa; teste em mapa Grande via
  fluxo real de "Novo Jogo" confirmou nenhuma regressão no visual normal
  (relevo/costa visiveis continuam corretos) e nenhuma forma vazando na
  area nao-explorada ao redor.
- **Não verificado a fundo**: água como um todo (o vazamento era
  especificamente a parede de terra exposta na costa; `water_shader.gdshader`
  ja teve varias rodadas de fix documentadas no proprio arquivo e nao
  mostrou vazamento equivalente nos testes feitos); praias/relevo/recursos/
  árvores/construções/unidades/sombras dinâmicas já eram tratados
  corretamente antes desta sessão (confirmado lendo os shaders e testes
  existentes) — só a parede exposta na costa era o vazamento real.

## Névoa de Guerra — raio de visão (2026-09-17)

- **Causa**: `HexGrid.compute_visible_tiles()` — unidades usavam
  `UnitData.vision_range` (maioria 2, algumas 3, batedor/voadoras 4);
  cidade tinha alcance **fixo em 2** (literal solto no código, igual à
  unidade mais fraca, sem diferenciação nenhuma por ser assentamento fixo).
- **Fix**: +1 uniforme em todo `vision_range` (`UnitDatabase.gd`,
  `MagicContent.gd`, default de `UnitData.gd`) → 2/3/4 viram 3/4/5,
  preservando a hierarquia (batedor/voador continua vendo mais longe).
  Cidade virou constante `HexGrid.CITY_VISION_RANGE = 4` (entre unidade
  base e batedor — cobre o território inicial de sobra + margem de alerta).
- **Custo medido** (benchmark descartável, mapa Grande, ~40 unid./6
  cidades): `compute_visible_tiles` isolado ~1ms; `recompute_fog` inteiro
  ~42-46ms, dominado quase todo pelo scan de fog/entidades sobre as 26880
  tiles (já otimizado antes) — o aumento de raio é custo desprezível.
- **Arquivos**: `HexGrid.gd`, `UnitDatabase.gd`, `MagicContent.gd`,
  `UnitData.gd`, `test_hexgrid_fog.gd` (2 testes de fronteira + 1 distância
  de teste ajustados pro novo raio). Monstros (`MonsterDatabase.gd`) e
  visão pra combate/detecção de covil NÃO foram tocados (fora de escopo).
- **Validado**: suíte GUT 1330/1330 (1 teste ajustado por depender da
  distância antiga); comparação visual antes/depois no jogo real (Novo
  Jogo real via `Main.tscn`) confirmando território revelado bem maior
  tanto por unidade quanto — mais ainda — por cidade fundada.

---

## Tela de Loading (2026-09-17)

- **Causa do "congelamento"**: `HexGrid.generate_map()` é 100% síncrono
  (~2,5-2,8s em mapa Grande) — nenhum frame renderiza nesse meio-tempo,
  spinner parava e Windows podia marcar a janela como "Not Responding".
- **Fix**: `generate_map()` ganhou `progress_callback` opcional (default
  inerte — zero mudança pra testes/benchmark/SaveManager) que cede `await
  get_tree().process_frame` em 7 pontos entre etapas já existentes. Usado
  por `Main._start_game()` (Novo Jogo/Reiniciar).
- **Limitação**: Carregar Partida (`SaveManager.load_game`) NÃO ganhou o
  fix — propagar o callback ali quebrou (silenciosamente) a suíte de
  testes: ~80 chamadas sem `await` em `test_save_manager.gd`/
  `test_magic_v1.gd` viram erro de parse quando a função vira coroutine com
  retorno `bool`. Revertido; Carregar Partida continua síncrono/congelando
  durante o load em si (só o visual novo aparece antes/depois).
- **Visual**: redesenho 100% procedural (gradiente, glow radial, poeira
  mágica via `CPUParticles2D`, emblema arcano com aneis girando +
  runas + núcleo pulsante, barra de progresso real por fase, fade de saída
  0,35s) — paleta `UITheme` reaproveitada, sem asset novo.
- **Arquivos**: `HexGrid.gd`, `Main.gd`, `LoadingScreen.gd/.tscn`,
  `LoadingSpinner.gd` (`SaveManager.gd` revertido, sem mudança líquida).
- **Validado**: suíte GUT 1330/1330 (48 scripts, 0 erros) após o revert;
  integração real via `Main.tscn` (mapa Grande) confirmou mapa completo
  (26880 tiles) e progresso renderizando corretamente no jogo de verdade.
