# Aetherlands — Release Balance Baseline (Fase 33B)

**Baseline:** `RELEASE_BALANCE_BASELINE_PRE_TUNING` · **seed set:** `phase33b-v2` · **data:** 2026-09-28

Documento vivo da Etapa B da Fase 33. Mede o jogo **como ele é**, com quatro civilizações automatizadas pelas
mesmas regras do jogo normal. **Nenhum custo, rendimento, peso de IA, regra de vitória ou schema de save foi
alterado.** As propostas de tuning (seção 17) são só candidatas para a F33C.

> **Nota F33D1:** esta é a baseline **pré-objetivos** e continua registro histórico. A D1 mudou a semântica das
> posições iniciais (distância mínima de 12 tiles entre capitais; 14/192 capitais mudaram de tile nas 48 seeds) e a
> exploração da IA (só covis descobertos). Comparações seed a seed com estes resultados exigem a nova baseline F33E.
>
> **Nota F33D2:** a D2 adiciona **conteúdo real** ao jogo (ameaça regional garantida por civilização, Guardiões Troll
> na Ascensão, IA atacando covis, recompensas de papel) e move 5/192 capitais (regra de massa de terra mínima). A F33B
> permanece a baseline **PRE-OBJECTIVES**: nenhum resultado de partida pós-D2 deve ser agregado aos dados F33B. Os
> smokes da D2 (`docs/balance/F33D2_smoke_summary.json`) não são baseline; a F33E mede de novo.
>
> **Nota F33D3:** a D3 muda a regra territorial da Supremacia (captura da cidade de maior nível do rival no instante
> da captura), o pacing/recompensa/participação do Dragão, adiciona o Relicário, marcos públicos e imperativos. A F33B
> continua PRE-OBJECTIVES; vitórias e durações pós-D3 (`docs/balance/F33D3_smoke_summary.json`) não se comparam nem se
> agregam aos dados F33B.

Dados brutos: `user://balance/final/` (não versionados). Resumo versionado: `docs/balance/F33B_aggregate_summary.json`,
`docs/balance/F33B_matches.csv`, `docs/balance/F33B_civs.csv` e `docs/balance/F33B_representative_outliers.json`.

---

## 1. Product Pacing Goal

- Sessão desejada: **2–3 horas humanas** por partida normal.
- Conversão turno → tempo: **desconhecida**, pendente da medição humana da F33D (seção 18). Nenhum número de
  turnos deste documento deve ser lido como "horas".
- Hipóteses de turno usadas **só como referência diagnóstica** (nunca assert): 1º N9 ~80–115; 2º N9 relevante
  ~115–145; capstone da rota ~130–160; victory-ready ~145–165; vitória normal ~155–180; p90 ≤ 190; p95 ≤ 200;
  200+ investigar; 230+ preocupação forte.

## 2. Methodology

### Harness

| Peça | Arquivo | Papel |
|---|---|---|
| Seed set versionado | `tools/balance/BalanceSeedSet.gd` | 48 seeds + 16 reservas, raça/orientação por assento, cap |
| Runner | `tools/balance/BalanceMatchRunner.gd` | monta o mundo real, roda `TurnManager.end_turn()` até vitória/cap, desmonta |
| Observador | `tools/balance/BalanceTelemetry.gd` | TELEMETRY OBSERVER: lê o `GameManager` inteiro, nunca escreve gameplay nem alimenta a IA |
| Relatório | `tools/balance/BalanceReport.gd` | baseline numérica lida do código + agregação + CSV/JSON/markdown |
| CLI | `tools/balance/BalanceLab.tscn` + `balance_lab.gd` | batch headless, paralelizável por faixas de partidas |
| Testes | `test/unit/test_balance_lab_phase33b.gd` | fixture, no-cheat, visão, marcos, fim, rotação, reset, smoke determinístico |

Comandos (Godot 4.7.1, headless, sem UI/render/áudio):

```
godot --headless --path . res://tools/balance/BalanceLab.tscn -- --run=final --tag=baseline --matches=0-47
godot --headless --path . res://tools/balance/BalanceLab.tscn -- --run=final --tag=extension --cap=300 --matches=4,7
godot --headless --path . res://tools/balance/BalanceLab.tscn -- --run=final --tag=saveload --save-load-turn=60 --matches=1
godot --headless --path . res://tools/balance/BalanceLab.tscn -- --run=final --tag=baseline --report
godot --headless --path . res://tools/balance/BalanceLab.tscn -- --run=final --dump-baseline
```

Faixas disjuntas podem rodar em processos paralelos (cada partida grava o próprio JSON). A validação de 100+
partidas da F33C usa as 16 reservas (`--matches=48-63`) mais novas seeds acrescentadas à lista.

### Quatro IAs pelas mesmas regras

- **Mapa real** 320×84 (`TitleScreen.MAP_SIZES.large`, o único tamanho do jogo), 3 rivais, geração real por seed.
- **Pipeline real de turno**: economia, pesquisa (1 slot), Produção (1 fila por cidade), Supply/Tensão/Déficit,
  diplomacia, combate, IA estratégica (`V2StrategicAI`) e tática (`RivalAI`/`V2AITacticalAI`), eventos de mundo,
  Ritual e `check_victories` — tudo por `TurnManager.end_turn()`, síncrono (como todo teste GUT).
- **Assento humano automatizado** pela flag de fixture `GameManager.ai_controls_human_seat` (desligada por
  padrão, nunca salva). Ligada, o `human_player` formal entra no **mesmo loop** dos rivais
  (`GameManager.ai_controlled_players()`): planejamento V2, guerra/campanha/paz, participação em eventos,
  defesa de cidade da IA e ações táticas. As regras de mira "alvo precisa estar VISÍVEL na neblina do humano"
  (UI) passam a usar `GameManager.is_human_controlled()` e valem só para o humano real. A eliminação do assento
  0 conta para a Dominação dos outros, mas não encerra a partida sozinha. Não existe IA simplificada de teste.
- **Capital do assento 0**: criada pelo **mesmo mecanismo de spawn dos rivais** (`HexGrid.found_city` no tile
  de `WorldSetup.find_start_tile`, no lugar do Colonizador inicial). Os quatro assentos começam idênticos:
  capital + Guarda, 0 Ouro, 0 Mana, 0 pesquisa.
- **Observador × entrada da IA**: o observador escuta sinais e lê estado depois de cada turno; a IA continua
  decidindo só por `V2AIWorldView`. Os únicos acréscimos no runtime são **sinais de observabilidade pura**
  (`EventBus.city_production_processed`, `unit_removed`, `combat_engagement`) que nenhum sistema do jogo escuta.

### Rotação e determinismo

- Cada partida tem humano, elfo, anão e orc. Raças giram pelos assentos com período 4 (cada raça ocupa cada
  assento 12 vezes em 48). Assento = índice de spawn (0 = centro do continente Principal; 1–3 em ângulos iguais).
- Orientações MILITARY/ARCANE/BALANCED por **tabela congelada de 12 templates** (busca exaustiva): em cada ciclo
  cada assento e cada raça recebem cada orientação 4×, a orientação repetida varia e o par de assentos que a
  repete varia. Nunca derivada da raça. Nenhum peso por raça.
- Paridade das seeds balanceada por configuração (ver "Execuções invalidadas").
- `seed(match_seed)` global + RNGs do jogo já derivados da seed (IA, monstros, eventos). Mesma configuração →
  mesma partida (seção "Determinismo").
- Cap **240**; sem vitória = **TIMEOUT** (sem vencedor artificial). Timeouts reexecutados até **300** como dataset
  separado de diagnóstico.

### Execuções invalidadas (não agregadas)

| Execução | Problema (harness, não gameplay) | Ação |
|---|---|---|
| Stage 1 v0 (12 partidas) | a capital do assento 0 vinha do Colonizador e foi rejeitada por `CitySite` em 2/12 mapas (covil/prédio/distância), atrasando só esse assento 1–2 turnos | capital pelo mecanismo de spawn dos rivais; tudo reexecutado |
| Baseline v1 (48 partidas + apoio) | todas as seeds ímpares. `V2AIStrategyState._stable_seed(seed, índice)` + `posmod(strategy_seed, 2)` decide o foco-reserva do BALANCED no T45 → assentos 0/2 sempre Supremacia, 1/3 sempre Transcendência. Resultado espúrio: assentos 1/3 com 22 das 23 vitórias, assento 2 com zero | seed set v2 com paridade balanceada por configuração/estágio + teste; dataset v1 arquivado em `user://balance/invalidated/` |

Nenhum número abaixo mistura dados pré e pós correção.

### Amostra

Stage 1 (12) → Stage 2 (24) → Stage 3 (**48 partidas completas**, a meta), todas com o harness final. O custo não
justificou reduzir: 48 partidas em **~15 min de relógio** (883 s) com 4 processos (seção "Performance").

## 3. Numeric Baseline (`RELEASE_BALANCE_BASELINE_PRE_TUNING`)

Lido das fontes centrais por `BalanceReport.numeric_baseline()` (JSON completo em
`user://balance/final/numeric_baseline.json`).

### Pesquisa

| Tier | N1 | N2 | N3 | N4 | N5 | N6 | N7 | N8 | N9 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Custo | 8 | 16 | 24 | 28 | 40 | 80 | 128 | 196 | 268 |
| Acumulado | 8 | 24 | 48 | 76 | 116 | 196 | 324 | 520 | 788 |

Infraestrutura I/II/III: 16/48/120 (184 por linha, 6 linhas = 1.104). Exército Supremo e Transcendência: 400 cada,
exigem 2 linhas N9 da própria árvore. 55 nós militares + 55 mágicos + 18 de Infraestrutura; total 11.360.
Slot único de pesquisa; Conhecimento sem projeto ativo vai para overflow (não se perde).

### Economia

| Base por cidade | Ouro 2 · Supply 4 · Produção 4 · Conhecimento 2 · Mana 1 |
|---|---|
| Mercado | 20 PP, upkeep 0, +4/6/8 Ouro |
| Fazenda | 20 PP, upkeep 1, +4/6/8 Supply |
| Oficina | 24 PP, upkeep 1, +2/3/4 Produção |
| Academia | 24 PP, upkeep 1, +3/4/5 Conhecimento |
| Santuário Arcano | 24 PP, upkeep 1, +2/3/4 Mana |
| Déficit / Tensão | prédios operacionais ×0,5 / combate ×0,85 |
| Guerra | 0,5 Ouro por unidade militar por turno |
| Upgrade de forma | 2 Ouro por PP de diferença |

### Cidade e fortificação

| Nível | Slots | Cópias repetíveis | Raio | Anexação | HP | Projeto (PP + Ouro) | Pesquisa |
|---|---:|---:|---:|---:|---:|---|---|
| I | 4 | 1 | 1 | 0 | 24 | — | — |
| II | 7 | 2 | 2 | 4 | 30 | 60 + 30 | Urbanização I |
| III | 10 | 3 | 3 | 5 | 36 | 120 + 70 | Urbanização II |
| IV | 13 | 4 | 4 | 6 | 44 | 220 + 140 | Urbanização III |

Muralhas I/II e Fortaleza: 40/70/110 PP, upkeep 1/2/3, escudo 8/14/22, defesa +10/20/30%, ataque 3/5/7
(alcance 2/2/3), exigem Cidade II/III/IV. "Desenvolvida" (Supremacia) = Cidade III+.

### Unidades (linha do Guardião como referência; as seis Doutrinas seguem o mesmo padrão)

| Item | PP | Supply | Observação |
|---|---:|---:|---|
| Colonizador | 25 | 0 | — |
| Construtor | 16 | 0 | cargas por tier de Indústria |
| N2 Salão de treino | 22 | — | upkeep 1 |
| N3 / N5 / N7 (Escudeiro/Guardião/Sentinela) | 20 / 32 / 48 | 1 / 2 / 3 | upgrade 24 e 32 Ouro |
| N8 Maestria | 55 | — | upkeep 2 |
| N9 Lendária | 90–110 | 5 | 1 ativa por civilização |
| Cerco N3/N5/N7 | 28 / 44 / 64 | 1 / 2 / 3 | upgrade 32 e 40 Ouro |
| Cavalaria N3/N5/N7 | 24 / 38 / 56 | 1 / 2 / 3 | upgrade 28 e 36 Ouro |

Tokens da IA: alvo `clamp(5 + 2·cidades + linhas completas + nível máx., 8, 20)`, teto duro 24.

### Magia

| Item | Valor |
|---|---|
| N2 prédio da Escola | 24 PP, upkeep 1 |
| N3 conjurador | 24 PP, Supply 2 |
| N8 Estrutura Ritual (treina a Manifestação e é o local do Ritual) | 60 PP, upkeep 2 |
| N9 Grande Manifestação | 100–110 PP + 60–75 Mana, Supply 0, 1 por Escola |
| Feitiços (24) | 4–20 Mana, recarga 0–5 |
| Técnicas (12) | recarga 0–4 |
| Ritual Final | 120 Mana, 4 rodadas, 2 Manifestações ativas + Estrutura Ritual utilizável |

### Raças (dois bônus cada)

| Raça | Bônus |
|---|---|
| Humano | +1 carga de Construtor; +1 ponto de Anexação por nível de cidade |
| Elfo | Conhecimento ×1,10; Mana ×1,10 |
| Anão | Ouro ×1,10; Produção ×1,10 |
| Orc | Supply ×1,10; Ataque ×1,05 |

### IA (tuning estratégico relevante)

| Peso | Valor |
|---|---|
| Pesquisa por orientação (militar/magia/infra) | MILITARY 34/8/18 · ARCANE 8/34/20 · BALANCED 22/22/24 |
| Urgência de Conhecimento / fundação de Infra | 32 / +55 (2 primeiras linhas) |
| Troca de pesquisa | só se < 50% de progresso e margem ≥ 18 |
| Reserva de Ouro | 20 + 10 por cidade |
| Colonizadores desejados | `min(6, 1 + turno/30)` |
| Foco do BALANCED | por progresso de árvore (±5); senão paridade do `strategy_seed` no T45 |
| Guerra | score ≥ 1,5 e 20% de chance por turno; paz com cansaço ≥ 60 (aceita com ≥ 40) |
| Pressão pública de Ritual | +0,25 / 0,75 / 1,25 / 2,0 por rodada restante 4/3/2/1 |

## 4. Research Mathematics

| Grandeza | Conhecimento |
|---|---:|
| Uma linha N1–N9 | 788 |
| Duas linhas N9 | 1.576 |
| **Lower bound Supremacia** (2 Doutrinas N9 + Exército Supremo) | **1.976** |
| **Lower bound Transcendência** (2 Escolas N9 + Transcendência) | **1.976** |
| Urbanização para Cidade III / IV | 64 / 184 |
| Infraestrutura completa | 1.104 |

As duas Escolas N9 já incluem a Estrutura Ritual (N8) e a Manifestação (N9) de cada uma: nenhum nó extra é
exigido para o Ritual. O lower bound é um limite matemático, não previsão de turno.

**Throughput observado** (Conhecimento acumulado gerado por civ viva, mediana [p25–p75]):

| Turno | 30 | 50 | 75 | 100 | 150 | 200 |
|---|---:|---:|---:|---:|---:|---:|
| Acumulado | 82 | 189 | 430 [380–642] | 790 [684–1.240] | 1.938 [1.507–2.942] | 3.637 [2.586–5.233] |
| Renda/turno | 5 | 7 | 12 | 17 [13–25] | 26 [18–40] | 40 [20–67] |

- O acumulado mediano cruza **1.976 no T146** (156/192 civs chegam lá; p25 122, p75 167).
- Pesquisa pronta de vitória − turno em que o acumulado cruzou 1.976: Supremacia **14** turnos (mediana, n=79),
  Transcendência **26** (n=72). Eficiência de alocação (1.976 ÷ Conhecimento investido até o pronto): **81%**
  (Supremacia) e **79%** (Transcendência). Ou seja, ~20% do Conhecimento vai para desvios (Infraestrutura e a
  outra árvore) antes do capstone; a pesquisa não é o que empurra as partidas para 200+.
- Pesquisa ociosa com algo disponível: **0 turnos em 192 civs**. Trocas de projeto: mediana 1 por civ na partida inteira.

## 5. Match Distribution

**Amostra:** 48 partidas completas, 192 observações de civilização, cap 240, **24 TIMEOUT** (50%), 0 fins
desconhecidos, 0 Dominação. Estendidas até 300: os 24 timeouts (seção 13).

| Tipo | N | Mediana | P25 | P75 | P90 | P95 | Mín | Máx |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| MILITARY_SUPREMACY | 6 | 201 | 190 | 208 | 212 | 213 | 154 | 214 |
| TRANSCENDENCE | 18 | 200 | 192 | 213 | 227 | 232 | 157 | 238 |
| DOMINATION | 0 | — | — | — | — | — | — | — |
| **Vitórias válidas** | **24** | **200** | 191 | 210 | 224 | 230 | 154 | 238 |
| TIMEOUT (censurado) | 24 | — | — | — | — | — | — | — |

Timeouts **não** entram como 240 nas estatísticas acima. Curva de término (partidas encerradas por vitória):

| Até o turno | 150 | 160 | 180 | 200 | 220 | 240 |
|---|---:|---:|---:|---:|---:|---:|
| Encerradas | 0/48 | 2/48 | 3/48 | 13/48 | 20/48 | 24/48 |

Leitura: a vitória normal mediana (~200) está ~20–45 turnos além da hipótese (155–180), e metade das partidas
não fecha até 240. A cauda, não a mediana das vitórias, é o problema dominante de pacing.

## 6. Research Milestones

Turno do marco (mediana [p25–p75]; reached/192):

| Marco | Mediana | P25–P75 | P90 | Reached |
|---|---:|---|---:|---:|
| N1 / N3 / N5 / N7 | 21 / 33 / 70 / 85 | — | 68 / 70 / 79 / 101 | 186 / 184 / 181 / 177 |
| 1º N9 | 113 | 100–122 | 135 | 167 |
| 2º N9 | 148 | 126–167 | 185 | 154 |
| Infra I / II / III | 9 / 45 / 62 | — | 9 / 48 / 67 | 192 / 186 / 183 |
| Exército Supremo (= Supremacy research-ready) | 153 | 135–171 | 181 | 79 |
| Transcendência (= Transcendence research-ready) | 180 | 166–194 | 223 | 72 |

Contexto no marco (mediana): 1º N9 com 4 cidades, 23 Conhecimento/turno, 4 Academias, 1.068 investidos;
2º N9 com 5 cidades, 30/turno, 5 Academias; research-ready com 5–6 cidades, 30–36/turno, 6 Academias,
~2.450–2.510 investidos.

## 7. Economy

| Checkpoint (mediana, civs vivas) | T30 | T50 | T75 | T100 | T150 | T200 |
|---|---:|---:|---:|---:|---:|---:|
| Cidades | 1 | 2 | 3 | 3 | 5 | 6 |
| Ouro em caixa | 48 | 46 | 48 | 51 | 187 | 437 |
| Ouro líquido/turno | 0 | 1 | 1 | 2 | 4,4 | 6,9 |
| Upkeep/turno | 2 | 3 | 6 | 9 | 18 | 27 |
| Supply usado / capacidade | 0/4 | 2/8 | 6/12 | 10/16 | 18/26 | 25/44 |
| Mana em estoque | 30 | 66 | 148 | 251 | 586 | 917 |
| Mana/turno | 1 | 2,2 | 5 | 6 | 8 | 10 |
| Conhecimento/turno | 5 | 7 | 12 | 17 | 26 | 40 |
| Produção total / média por cidade | 6 / 6 | 10 / 5 | 14 / 5,3 | 18 / 5,5 | 22 / 5,4 | 26 / 6 |

- **Déficit** (regra real `is_gold_deficit`): 117/192 civs entram em algum momento; mediana do 1º Déficit T121;
  maior sequência mediana 3 turnos (p90 11, máx 70). Renda líquida negativa financiada pelo caixa: mediana 46
  turnos por civ.
- **Tensão**: 78/192 civs; 1ª mediana T125; maior sequência mediana 0 (p90 26); razão máx. de Supply mediana 1,0.
- **Mana** acumula: mediana de 662 em estoque na 1ª Manifestação e 696 no Ritual pronto; zero city-turns
  "aguardando Mana". Turnos abaixo da reserva estratégica da própria IA: mediana 11 (todos na abertura).
- **Produção**: base 4 + Oficinas mantém a média por cidade em ~5–6 PP a partida inteira.

## 8. Opening / Expansion

- **Primeira produção: T17** (mediana; p25 16, p90 17). Todas as IAs passam **~15 turnos com a capital ociosa**:
  até o T30 o Colonizador pontua −100 (`min(6, 1 + turno/30)` = 1) e prédios com upkeep pontuam −100 enquanto
  o Ouro está abaixo da reserva (20 + 10/cidade). A Academia I sai no T9, mas só entra em produção quando o
  caixa passa de 30.
- Primeiro item: Academia 125/192, Santuário Arcano 62/192, Colonizador 3/192, prédio de Escola 1/192
  (grupo: prédio econômico 187, Colonizador 3, treino 1).
- **1º Colonizador produzido T45** (p25 34, p75 48); 2ª cidade **T47**, 3ª **T73**, 4ª **T100** (139/192).
- Cidades por checkpoint (mediana): T30 1 · T50 2 · T75 3 · T100 3 · T150 5.
- Colonizadores: 4 por civ (mediana), conversão em cidade 100% (p25 100%), 0 sobrando no fim (máx 5), 0 perdidos
  (máx 8). Sem expansão (máx. 1 cidade): 9 civs. 10+ cidades: 25 civs. Acúmulo de colono morto (≥ 60
  colono-turnos): 11 civs. 2ª cidade depois do T80: 2 civs.
- **Cidade ociosa**: 19% dos city-turns (mediana por civ; p90 47%). Em 27.394 city-turns ociosos,
  **24.664 tinham opção iniciável e a IA não escolheu** (nenhum candidato com score > 0), 2.730 só tinham o
  Colonizador e 0 não tinham opção nenhuma. É decisão de IA, não gate de catálogo.

## 9. Military / Supremacy

**Exército.** Tokens relevantes (mediana): T50 2 · T75 4 · T100 5 · T150 6 · T200 11; máximo por civ 11
(p90 20). 94/192 civs chegam a 12 tokens em algum momento e 39/192 a 20. A intenção conceitual (força
principal 12–20) só aparece no fim da partida. Composição média no T200: conjurador 2,5 · guardião 1,6 ·
patrulheiro 1,5 · guerreiro 1,3 · ladino 1,2 · cavalaria 1,0 · cerco 0,6 · retinue 0,5 · Lendária 0,3 ·
Manifestação 0,3. Formas: N7 domina a partir do T150 (mediana 3 no T150, 5 no T200) — a IA converte pesquisa em
densidade por upgrade.

**Guerras.** 693 guerras (mediana 12,5 por partida); 1ª guerra da partida no T52; civs em guerra 49% dos turnos;
partidas com alguma guerra em 66% dos turnos. Duração das encerradas: mediana 14 (p90 56). Fim: paz 569,
eliminação 29, em curso no fim 95. Capturas por guerra: mediana 0 (p90 3). **71 guerras `possible_stalemate`**
(≥ 20 turnos seguidos sem captura nem morte). Perdas por guerra: mediana 2.

**Supremacia.**

| Medida | Valor |
|---|---|
| `supremacy_research_ready` | mediana 153 [135–171], 79/192 civs |
| Vitórias | 6 (4 MILITARY, 2 BALANCED) |
| **Execution lag** (vitória − research-ready) | mediana **43** [10–62], máx 90 (n=6) |
| Civs com acesso que **não** venceram: turnos do acesso ao fim | mediana **77** [54–97] (n=73) |
| Turnos pós-acesso em guerra com rival pendente | mediana 64% |
| Capturas qualificadas por civ com acesso (n=79) | 0: 35 · 1: 22 · 2: 13 · 3+: 9 — **44% nunca capturam** uma Cidade III+ |
| Rivais satisfeitos no fim (civs com acesso) | 0: 33 · 1: 24 · 2: 15 · 3: 7 |
| Rivais pendentes **sem nenhuma Cidade III+** no fim (não vencedoras) | **43 de 157 (27%)** — só eliminação resolve |
| Condição de rival perdida depois de satisfeita | 5 eventos |

**Todas as 6 vitórias** usaram ao menos uma eliminação para satisfazer um rival (11 eliminações × 7 capturas qualificadas).

## 10. Arcane / Transcendence

| Medida | Valor |
|---|---|
| `transcendence_research_ready` | mediana 180 [166–194], 72/192 |
| 1ª Manifestação | mediana 178 [159–204], 82/192 |
| 2ª Manifestação distinta / duas ativas | mediana 195 / 200, 23/192 |
| `transcendence_ritual_ready` (runtime canônico) | mediana 200 [188–220], 22/192 |
| 1º Ritual iniciado | mediana 201, 21/192 (20 BALANCED, 1 ARCANE) |
| **Manifestation lag** (duas ativas − research-ready) | mediana **39** [27–48], p90 68 |
| Ritual pronto − research-ready | mediana 39 [27–48] |
| **Execution lag** (vitória − ritual pronto / − 1º Ritual) | **5 / 4** (fixo: 4 rodadas) |
| Civs com acesso que não venceram: turnos até o fim | mediana 39 [17–53] (n=54) |
| Tentativas por civ que tentou | 1 (21 civs) |
| Interrupções | 0: 20 · 1: 1 · 2+: 0; motivo: `manifestation_lost` 1; loops: 0 |

**Onde a Transcendência trava** (turnos pós-acesso por gate, somados em todas as civs; fonte: gates reais):

| Gate | Turnos | Leitura |
|---|---:|---|
| Estrutura Ritual construível, cidades todas ocupadas | 976 | fila local ocupada |
| Estrutura Ritual construível numa cidade **ociosa** e não escolhida | 594 | decisão de IA |
| Manifestação em produção | 588 | tempo de produção (100–110 PP a ~6 PP/cidade ≈ 17 turnos) |
| Estrutura Ritual em produção | 246 | tempo de produção (60 PP) |
| Sem slot livre / falta prédio-escola | 86 / 56 | gate de conteúdo |
| Treinável e não escolhida (cidade ociosa / ocupada) | 47 / 71 | IA / fila |
| Ritual pronto e não iniciado | 25 | IA (foco ≠ Transcendência) |
| Bloqueado por Mana | 2 | praticamente nunca |

O gargalo após a pesquisa é **a Estrutura Ritual N8 não ser construída** (1.570 turnos construível e não
construída) e a fila local ocupada com projetos de cidade, não Mana e não interrupções.

## 11. Domination

Nenhuma vitória por Dominação. Eliminações: 18 primeiras (mediana T108 [54–157]), 5 segundas (T177), nenhuma
terceira. Assento 0 (centro) sofre 14 das 23 eliminações. Eliminação funciona como atalho da Supremacia (69
satisfações de rival por eliminação × 49 por captura qualificada), não como rota própria.

## 12. Race / Orientation

**Descritivo e NÃO CAUSAL**: assento, vizinhança, orientação e guerras variam.

| Orientação | 1º N9 | 2º N9 | Exército Supremo | Transcendência | Ritual pronto | Cidade III | Vitórias | Conh./t T100 | Tokens máx. | Eliminadas |
|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|
| MILITARY | 113 (58/64) | 149 (53) | 163 (53) | 229 (1) | — (0) | 154 (53) | 4 Supremacia (med. 201) | 17,0 | 14 | 5 |
| ARCANE | 126 (53/64) | 170 (46) | — (0) | 186 (40) | 233 (1) | 187 (32) | 1 Transcendência (238) | 13,2 | 8 | 11 |
| BALANCED | 99 (56/64) | 124 (55) | 134 (26) | 160 (31) | 200 (21) | 103 (57) | 17 Transc. + 2 Supr. (med. 199) | 28,8 | 14 | 7 |

- Orientação ≠ tipo de vitória: BALANCED decide o foco no T45 (32 Supremacia, 32 Transcendência). Com foco
  Transcendência vence 17/32; com foco Supremacia, 2/32. MILITARY vence 4/64; ARCANE 1/64.
- Participação em pesquisa (mediana): MILITARY 68% militar; ARCANE 68% magia e 0% militar; BALANCED 50/31/19.
- BALANCED gera **~2× o Conhecimento** das outras no T100 (28,8 vs 13–17/turno) e chega à Cidade III 50–80 turnos
  antes; é a única orientação que atinge as bandas-hipótese de pesquisa (1º N9 T99, 2º N9 T124, capstone
  134–160).

| Raça | 1º N9 | 2º N9 | Vitórias | Cidades finais | Conh./t T100 | Eliminadas |
|---|---:|---:|---|---:|---:|---:|
| Humano | 114 | 147 | 5 (1 S, 4 T) | 5 | 17,0 | 4 |
| Elfo | 112 | 150 | 7 (2 S, 5 T) | 4 | 17,6 | 9 |
| Anão | 113 | 144 | 8 (2 S, 6 T) | 6 | 18,0 | 2 |
| Orc | 115 | 154 | 4 (1 S, 3 T) | 5 | 14,0 | 8 |

| Assento | Vitórias | Eliminadas | Conh./t T100 |
|---|---|---:|---:|
| 0 (centro) | 4 | 14 | 12,0 |
| 1 | 7 | 3 | 17,9 |
| 2 | 8 | 5 | 20,4 |
| 3 | 5 | 1 | 17,5 |

Com n = 48 por raça, diferenças de 4–8 vitórias estão dentro do ruído; nenhuma raça se destaca de forma
consistente em todos os marcos. O **assento 0 (centro do continente)** é mais exposto (vizinho de todos) e é o
efeito geográfico mais forte da amostra — não é raça.

**Validação racial controlada (F26):** `test_v2_race_bonuses.gd` **23/23, 660 asserts** — Construtor e Anexação
humanos, Conhecimento/Mana élficos, Ouro/Produção anões, Supply/Ataque orcs, aplicados uma vez, derivados do
dono atual. Baseline racial íntegra.

## 13. Outliers

- **EARLY (< 120):** nenhuma. A vitória mais rápida foi uma Supremacia no T154 (F33B-002, anão MILITARY), que
  eliminou o assento 0 no T17 e o orc no T141.
- **Colapso precoce (não é vitória, mas explica partidas curtas):** o assento 0 (centro) é eliminado antes do
  T60 em **5/48** partidas (T17, T17, T37, T51, T52) — guerra declarada nos primeiros turnos (F33B-002: T8) e a
  capital cai para as forças iniciais de um vizinho.
- **LATE (> 200):** 11 partidas. **TIMEOUT (240):** 24 partidas.

Classificação (heurística documentada em `BalanceReport._late_diagnosis`: só civs candidatas — com acesso de
pesquisa a uma rota — e a evidência dominante da própria telemetria):

| Categoria primária | Late (> 200) | Timeout | Total |
|---|---:|---:|---:|
| MILITARY_STALEMATE | 1 | 17 | 18 |
| PRODUCTION_LATE (fila/Estrutura Ritual) | 6 | 1 | 7 |
| NO_VICTORY_PURSUIT | 1 | 4 | 5 |
| RESEARCH_LATE | 3 | 0 | 3 |
| MAP_ACCESS | 0 | 2 | 2 |

Qualquer evidência (primária ou secundária): PRODUCTION_LATE 29 · MILITARY_STALEMATE 26 · NO_VICTORY_PURSUIT 17 ·
MAP_ACCESS 3 · RESEARCH_LATE 3 · MANA_LATE 1 · RITUAL_INTERRUPTION_LOOP 0. ECONOMIC_COLLAPSE (Déficit ≥ 20 seguidos
ou Tensão ≥ 30) aparece em 5 de 109 civs candidatas e nunca como causa primária.

Padrão dos 24 timeouts: sempre existe pelo menos uma civ com Exército Supremo (acesso mediano ~T150) que passa a
maior parte do tempo em guerra com rivais pendentes sem fechar a última captura qualificada, enquanto as candidatas
de Transcendência (quando existem) ficam paradas na Estrutura Ritual/fila. Nenhum timeout foi causado por Mana,
loop de Ritual ou pesquisa ociosa. Diagnóstico por partida (primária, secundárias, candidatas, trace a cada 10
turnos e timeout report com caminho mais próximo e requisitos faltantes) está em `aggregate.json` (user://) e,
compacto, em `docs/balance/F33B_aggregate_summary.json`; três casos representativos em
`docs/balance/F33B_representative_outliers.json`.

### Extensão até T300 (dataset separado, só diagnóstico)

As 24 partidas TIMEOUT foram reexecutadas do zero com cap 300. As 24 reproduziram a baseline **exatamente** até o
T240 (marcos e séries), então a extensão é a continuação da mesma partida.

| Resultado até T300 | Partidas | Turnos |
|---|---:|---|
| TRANSCENDENCE | 9 | 241, 242, 250, 264, 268, 280, 282, 282, 296 |
| MILITARY_SUPREMACY | 6 | 251, 256, 281, 286, 287, 292 |
| Ainda sem vencedor no T300 | **9** | — |

- 15/24 fecham entre T241 e T296 (mediana ~281); 5 das 9 Transcendências são de civs ARCANE — a rota arcana
  converte, só que 60–100 turnos depois do BALANCED.
- Os 9 que nem no T300 terminam: MILITARY_STALEMATE 4, MAP_ACCESS 3, NO_VICTORY_PURSUIT 2. Não há stalemate de
  Ritual (0 loops), colapso econômico nem pesquisa ociosa.
- Padrão novo na cauda: **6 civs ficam com o Ritual pronto (7/8 gates da Transcendência) e nunca o iniciam porque o
  foco está travado em Supremacia desde o T45** (4 delas em partidas que não fecham no T300). No cap 240 isso só
  acontece 1 vez. É decisão de IA (`V2StrategicAI._start_ritual_if_ready` exige foco Transcendência).

## 14. Confirmed Bottlenecks

Cada item tem pelo menos dois sinais independentes.

1. **Execução da Supremacia (militar), não pesquisa.** (a) 79 civs com Exército Supremo, 6 vitórias; acesso →
   fim sem vitória em mediana 77 turnos; (b) 18/35 partidas tardias/timeout têm MILITARY_STALEMATE como causa
   primária; (c) 27% dos rivais pendentes não têm nenhuma Cidade III+ capturável e 44% das civs com acesso
   nunca fizeram captura qualificada; todas as 6 vitórias precisaram de eliminação; (d) guerras longas e rasas: capturas por guerra mediana 0, 71 guerras
   `possible_stalemate`, exército mediano 11 tokens no T200.
2. **Conversão pós-pesquisa da Transcendência (Estrutura Ritual/fila), não Mana.** (a) research-ready → Ritual
   pronto mediana 39 turnos; (b) 1.570 turnos com a Estrutura Ritual construível e não construída, 976 deles com
   as cidades todas ocupadas; (c) Mana: 2 turnos de bloqueio em toda a amostra, estoque ~660–700 na hora H;
   (d) interrupções: 1 em 21 Rituais — a execução depois de iniciado é de 4–5 turnos.
3. **Economia de Conhecimento das orientações MILITARY e ARCANE (alocação da IA).** (a) BALANCED produz ~2× o
   Conhecimento no T100 com os mesmos custos; (b) BALANCED chega ao 2º N9 no T124 contra 149 (MILITARY) e 170
   (ARCANE), e à Cidade III 50–80 turnos antes; (c) ARCANE: 0% de pesquisa militar, 8 tokens máximos, 11/64
   eliminadas e Ritual pronto em 1/64.

## 15. Probable Bottlenecks

- **Ociosidade das cidades por score ≤ 0 da IA** (19% dos city-turns, quase todos com opção disponível). Sinal
  forte, mas o efeito no pacing de vitória é indireto.
- **Abertura de ~15 turnos sem produção** (Colonizador bloqueado até T30 pela fórmula de desejados; prédios com
  upkeep bloqueados pela reserva de Ouro). Afeta todas as IAs igualmente; efeito sobre a vitória não isolado.
- **Foco de vitória travado**: o foco-reserva do BALANCED é decidido no T45 e nunca revisto; na cauda (extensão
  até T300) 6 civs com Ritual pronto nunca o iniciam porque o foco é Supremacia. Pouco relevante até T240 (1 caso),
  relevante para os timeouts longos.
- **Projetos de cidade consomem 33% dos city-turns de produção**; competem diretamente com a Estrutura Ritual e o
  exército. Provável contribuinte dos itens 1 e 2 acima; falta um cenário controlado.
- **Assento central** (assento 0: 14/48 eliminações, 5 delas antes do T60 por guerra nos primeiros turnos contra
  a capital defendida só pelo Guarda inicial). No jogo normal esse é o assento do **jogador humano**: risco de
  rush precoce de IA a confirmar com partidas humanas (F33D). Geografia do spawn + decisão de guerra da IA; não é
  número de balanceamento.

## 16. Systems With No Evidence for Change

- **Custos de pesquisa e slot único**: pesquisa nunca fica ociosa com algo disponível; o acumulado mediano cruza o
  lower bound no T146 e a research-ready vem 14–26 turnos depois; BALANCED atinge as bandas-hipótese com os
  custos atuais.
- **Mana e custos mágicos** (Manifestação, Ritual, feitiços): Mana sobra; 2 turnos bloqueados em 48 partidas.
- **Ritual (duração, custo, interrupção)**: 1 interrupção em 21 tentativas; nenhum loop.
- **Ouro/Déficit**: Déficit é episódico (sequência mediana 3); o caixa financia renda negativa; nenhum colapso
  econômico foi causa primária de outlier.
- **Supply/Tensão**: razão mediana 1,0; Tensão rara e curta.
- **Colonizador/expansão**: conversão 100%, colonos sobrando ~0, 3 cidades no T75 e 5 no T150.
- **Bônus raciais**: sem sinal consistente em 48 partidas; controlados íntegros (23/23).
- **Payback de prédios econômicos** (paridade 1 PP = 1 unidade = 1 Ouro): Mercado 5,0/3,3/2,5 turnos; Fazenda
  6,7/4,0/2,9; Academia 12/8/6; Oficina e Santuário 24/12/8 (T1/T2/T3). Os primeiros saem no T16–17 e mesmo um
  prédio concluído no T200 se paga antes do cap. Nenhum candidato.
- **Custos de Produção por item** (seção 4 do JSON; a 6 PP: Academia 4 turnos, N3 4, N7 8, Maestria 10,
  Estrutura Ritual 10, Manifestação 17, Cidade III 20, Cidade IV 37). O tempo de produção pesa no gargalo 2
  somado à fila ocupada; o número isolado não é a causa.

## 17. Candidate Tuning Axes (F33C — nenhum implementado)

Ordem sugerida pelo tamanho do efeito medido:

1. **Execução da Supremacia**: urgência militar da IA após o Exército Supremo (alvo explícito de cidades
   desenvolvidas dos rivais pendentes, tamanho do exército de campanha) **e/ou** revisão da semântica "Cidade III+
   de cada rival" quando o rival não tem cidade desenvolvida (hoje só a eliminação resolve). Decisão de design, não
   só número.
2. **Prioridade da Estrutura Ritual/Manifestação** quando a Transcendência já está pesquisada (score da IA e
   interação com projetos de cidade na fila local), e início do Ritual quando o runtime diz que está pronto mesmo
   com foco em Supremacia (cauda T240–300).
3. **Alocação de Conhecimento das orientações MILITARY e ARCANE** (peso de Infraestrutura/Academia nos primeiros
   100 turnos), sem tocar custos de pesquisa.
4. **Abertura**: colonos desejados antes do T30 e a reserva de Ouro que segura a primeira Academia.
5. **Ociosidade de cidade** (score mínimo aceitável quando há opção iniciável).

Fora da lista por falta de evidência: custos de pesquisa, segundo slot, Mana, Ritual, Supply, raças, Colonizador.

## 18. Human Timing Plan

Ferramenta criada: `scripts/core/HumanTimingTelemetry.gd`.

- **DEV-ONLY, desligada por padrão**: `Main` só cria o nó quando `HumanTimingTelemetry.is_enabled()` — build de
  desenvolvimento **e** `-- --human-timing` na linha de comando ou `debug/balance_human_timing = true`. Release ou
  jogo normal: nenhum nó, nenhum arquivo, nenhuma UI.
- **Local**: grava só `user://balance/human_timing/session_<unix>.json`; sem rede, sem upload.
- **Campos**: `session_start_unix`; por turno `turn`, `active_seconds`, `ai_wait_seconds`, `paused_seconds`,
  `unfocused_seconds`, `match`; resumo `final_turn`, `final_active_seconds` e segundos/turno por faixa
  T1–30, 31–80, 81–130, 131+.
- **Tempo ativo** = partida em andamento, árvore não pausada, janela com foco (inclui olhar o mapa e pensar, e a
  espera da IA, registrada também à parte). Excluídos: Pause, Menu Principal/Game Over, Loading, janela sem foco.
- **Privacidade**: só números; nada de texto digitado, nome do reino, caminhos, dados do SO ou hardware.

Uso na F33D: 3–5 partidas humanas completas com a flag, cruzando segundos/turno por faixa com a curva de turnos
desta baseline (vitória mediana ~200, metade das partidas > 240) para converter turnos em horas. Até lá, a
conversão para 2–3 h continua **indeterminada**.

---

## Determinismo, save/load e reset

| Verificação | Resultado |
|---|---|
| Mesma seed reexecutada (F33B-001, 010, 031, 046) | **4/4 idênticas**: tipo e turno de vitória, todos os marcos e a série de Conhecimento por turno |
| Extensão (24 partidas relançadas do zero) | **24/24 idênticas** à baseline até o T240 |
| Save no T60 → load → continua (F33B-002, 006, 013, 037) | **4/4 idênticas** à execução sem save: mesmo fim, mesmos marcos, mesma série |
| Não-determinismo legítimo observado | nenhum |
| Reset entre partidas (48 em sequência por processo) | objetos 2.179 em platô após a 1ª partida (mín. 2.048, máx. 2.187), 16 nós, **0 órfãos**, memória estática 73–77 MB sem crescimento; `test_batch_reset_leaves_no_state_for_the_next_match` |

O save do jogo não guarda a raça dos rivais (fixa por índice no jogo normal) nem a estratégia do assento humano; no
subconjunto save/load o harness reaplica a identidade do assento e a estratégia do assento 0 depois do load
(fixture, sem mudar o schema). Telemetria nunca entra no save.

**No-cheat / anti-onisciência** (testes em `test_balance_lab_phase33b.gd`):

- setup: cada assento começa com capital + Guarda, 0 Ouro, 0 Mana, 0 pesquisa, fila vazia;
- primeiro turno: Ouro = caixa + bruto − upkeep, Mana = estoque + renda, Conhecimento gerado = renda, nos quatro
  assentos, calculados antes do turno pelo runtime;
- `V2AIWorldView` do assento automatizado não vê unidade escondida nem cidade nunca escoteada; o observador vê o
  estado completo; rodar o observador não altera `known_enemy_cities`, `explored_tiles` nem a visão da IA;
- regra de visibilidade de mira do humano real preservada com a flag desligada; flag desligada = semântica do jogo
  normal (`ai_controlled_players() == rival_players`, `is_enabled_for(human) == false`).

## Testes

| Suíte | Resultado |
|---|---|
| `test/unit/test_balance_lab_phase33b.gd` | 15/15 — boot 4 civs, assento humano no mesmo stack, flag desligada = jogo normal, no-cheat, WorldView/observador, marcos one-shot, research-ready exato (Supremacia/Transcendência), ritual-ready pelo runtime, fins (Dominação/Supremacia/Transcendência/timeout/desconhecido), rotação de raça/orientação, paridade de seeds, reset entre partidas, smoke 4-IA determinístico de 8 turnos |
| `test/unit/test_human_timing_telemetry.gd` | 3/3 — desligado por padrão, ativo exclui pausa/menu/foco, arquivo só numérico |
| `test/unit/test_v2_race_bonuses.gd` (F26, controle racial) | 23/23, 660 asserts |
| **Suíte GUT completa** | **3442/3442, 168 scripts, 371.274 asserts, código 0** (antes: 3424/166/370.779) |

O batch de 48 partidas fica fora da suíte padrão (≈ 15 min); o smoke curto roda nela em segundos.

## Performance do harness

| Medida | Valor |
|---|---|
| Setup (geração do mapa 320×84 + spawn) | 3,3 s isolado; 4,3 s mediana com 4 processos |
| Turno completo (4 IAs, isolado) | T1–100 média 110 ms (p95 218); T1–200 média 217 ms (p95 505) |
| Partida de 100 / 200 turnos (isolada) | **14,4 s / 47,2 s** |
| Partida completa na amostra (4 processos em paralelo) | mediana 69 s, p95 101 s, máx 192 s |
| Pior turno observado | 8,0 s (partida com 23 guerras e exércitos cheios); p95 dos piores turnos por partida 2,2 s |
| Batch de 12 partidas | ~4 min de relógio (4 processos) |
| Batch de 48 partidas | **883 s ≈ 15 min** de relógio (4 processos, i5-9600K 6 núcleos) |
| Extensão de 24 partidas até T300 | 835 s |
| Memória/órfãos | ver tabela acima: sem crescimento entre partidas |

Custo projetado para a validação de 100+ partidas da F33C: ~30–35 min de relógio com 4 processos. O pior turno de
vários segundos é do planner em guerra pesada (caminhos/decisões por unidade), não do harness; não afeta a medição e
fica registrado para a `docs/PERFORMANCE_GUIDE.md` se aparecer em partidas humanas.

## Bug encontrado (documentado, não corrigido)

**Captura de cidade preserva a fila de produção do dono anterior sem revalidar o novo dono.**
`HexGrid.capture_city` → `City.change_owner` mantém `production_item` e `stored_production` (de propósito para o
progresso), mas nada verifica `City.can_train`/`can_build` para o novo dono. A cidade capturada pode concluir uma
unidade que o novo dono não pesquisou ou que viola um slot; os guardas de nascimento (`V2LegendarySystem`/
`V2ManifestationSystem.spawn_allowed`) seguram só o caso de slot. Sinal em runtime: um único
`ERROR: V2ManifestationSystem: 'v2_manifestation_veil_archon' não nasceu ...` em 48 partidas (fail-closed
funcionou, PP devolvidos). Frequência baixa; **não invalida a amostra**. Candidato a correção mínima fora do
tuning (limpar/validar a fila na troca de dono), com rerun desta baseline se corrigido.
