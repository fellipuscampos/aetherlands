class_name RivalAI
extends RefCounted

## IA da civilizacao rival — GDScript puro, sem depender de nenhum plugin
## externo (o jogo precisa funcionar 100% offline). Unidades ofensivas
## avaliam o resultado PROVAVEL do combate antes de atacar
## (CombatResolver.predict(), a mesma formula que realmente vai rodar) em
## vez de brigar as cegas, recuam pra perto da propria cidade quando estao
## fracas (onde curam — ver GameManager._heal_if_garrisoned), e priorizam
## capturar uma cidade indefesa sobre uma escaramuca.
##
## Fog of war propria: a cada turno calcula o que realmente enxerga agora
## (HexGrid.compute_visible_tiles) e so mira em unidades inimigas
## ATUALMENTE visiveis; cidades inimigas (que nao andam) ficam guardadas em
## PlayerData.known_enemy_cities assim que escoutadas, continuando alvo
## valido mesmo fora de visao — nao "enxerga" mais o mapa inteiro de
## graca. Limitacao conhecida: o check de "cidade esta indefesa" usa o
## estado real do jogo mesmo pra cidades so lembradas (nao fica com uma
## foto antiga do que viu da ultima vez) — rastrear isso tambem seria a
## proxima melhoria, mas o ganho de realismo e pequeno pro custo extra.
##
## Coordenacao tatica basica: unidade a distancia (arqueiro) sem nenhum
## aliado corpo-a-corpo por perto nao avanca sozinha pra cima de um alvo —
## fica esperando escolta em vez de virar alvo facil isolado na linha de
## frente. Ainda assim revida normalmente se algo entrar no alcance dela.
##
## Roadmap de gameplay Fase 1: decide_production() escolhe o que cada
## cidade produz por PONTUACAO (ver SCORE_WEIGHT_* e decide_production),
## respeitando os mesmos City.can_build()/can_train() do jogador humano —
## antes disso a IA nunca conseguia CONSTRUIR predio nenhum (bypass
## documentado em BuildingDatabase.gd) mas ainda assim treinava tropa
## avancada de graca. decide_war() pode iniciar guerra sozinha contra o
## oponente quando uma avaliacao de oportunidade justificar (ver
## WAR_WEIGHT_*) — antes disso so o jogador humano jamais declarava
## guerra primeiro.

const PERCEPTION_RANGE := 5
const SETTLE_MIN_DISTANCE := 3
const RETREAT_HP_FRACTION := 0.35 # abaixo disso, foge pra curar em vez de brigar
const ESCORT_RANGE := 2 # distancia maxima pra um aliado corpo-a-corpo contar como escolta
const MILITARY_KINDS := ["warrior", "warrior", "archer", "cavalry", "catapult", "mage", "griffin", "treant"] # pesos simples

## Pesos da pontuacao de producao (ver decide_production) — nomeados e
## comentados de proposito (pedido do usuario, roadmap Fase 1: "o score
## precisa ser simples e deterministico o bastante pra eu conseguir
## explicar em uma frase por que uma cidade escolheu Muralha em vez de
## Quartel"). Cada peso corresponde a UMA frase de explicacao:
## - DEFENSE: "esta cidade nao tem Muralha" (maior peso — perder uma
##   cidade e a pior consequencia possivel).
## - THREAT: "ha inimigo conhecido perto desta cidade agora".
## - ECONOMY_GAP: "falta um predio basico de economia que ja da pra
##   construir" (pontuacao fixa: a propria existencia do candidato ja E
##   o sinal de deficit, nao precisa de mais calculo).
## - MILITARY_DEFICIT: "meu exercito e pequeno perto da ameaca que eu
##   conheco" — vale tanto pra treinar mais uma tropa quanto pra construir
##   o predio de treino que ainda falta, de propósito (fazem parte do
##   mesmo objetivo "ter mais exercito").
const SCORE_WEIGHT_DEFENSE := 3.0
const SCORE_WEIGHT_THREAT := 2.0
const SCORE_WEIGHT_ECONOMY_GAP := 1.5
## >= ECONOMY_GAP de proposito: um rival com deficit militar MAXIMO (zero
## unidade propria) precisa poder vencer "so mais um predio de economia"
## pelo menos uma vez — senao, encadeando predio de economia atras de
## predio de economia, uma cidade sem ameaca visivel nunca treinaria
## exercito nenhum ate esgotar toda a lista de predios de rendimento.
const SCORE_WEIGHT_MILITARY_DEFICIT := 2.0
const PRODUCTION_THREAT_RADIUS := 6 # raio (em tiles) pra um inimigo visivel contar como "perto" de uma cidade
## Empate entre a tropa unica da propria raca e uma tropa comum (mesma
## pontuacao de deficit militar, ver _score_production_candidate): a
## exclusiva ganha por uma margem minima — regra explicavel numa frase
## ("tudo mais igual, treina sua tropa de elite, nao mais um recruta
## generico"), nao um numero escolhido pra fazer teste passar.
const SCORE_RACIAL_UNIT_TIE_BREAK := 0.01

## MILITARY_KINDS + a tropa racial (pesada igual "warrior", duas entradas)
## quando o jogador tem uma raca com tropa propria (UnitDatabase.
## RACE_UNIQUE_KIND — pedido do usuario: "insira outras civilizacoes de
## fantasia... voce cria tropas especificas pra essas civilizacoes",
## depois estendido pro jogador humano tambem poder escolher raca na tela
## de titulo) — civ sem raca reconhecida so usa o elenco comum, sem
## nenhuma tropa exclusiva aparecer no sorteio.
static func _military_kinds_for(player: PlayerData) -> Array:
	var kinds := MILITARY_KINDS.duplicate()
	var race: String = player.civ.race if player.civ else ""
	if UnitDatabase.RACE_UNIQUE_KIND.has(race):
		var unique: String = UnitDatabase.RACE_UNIQUE_KIND[race]
		kinds.append(unique)
		kinds.append(unique)
	return kinds

## Decide o que cada cidade produz por PONTUACAO (ver pesos SCORE_WEIGHT_*
## acima), nao mais um sorteio cego nem uma fila fixa de construcao —
## pedido do usuario (roadmap Fase 1): "eu nao usaria uma ordem fixa de
## construcao... rapidamente vira uma IA previsivel". Corrige tambem a
## assimetria documentada em City.can_train()/BuildingDatabase.gd: antes
## este metodo chamava set_production() direto, pulando can_build()/
## can_train() (o mesmo gate que o jogador humano e obrigado a respeitar)
## — uma cidade rival nunca tinha como CONSTRUIR o predio de treino que a
## tropa avancada exige, entao a tropa saia "de graca". Agora so entram na
## pontuacao os candidatos que ja passam nesses dois gates, exatamente
## como o jogador ve na propria UI (HUD._on_produce_pressed).
static func decide_production(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> void:
	var visible := hex_grid.compute_visible_tiles(player)
	var military_deficit := _military_deficit(player, opponent, visible)
	var race: String = player.civ.race if player.civ else ""
	var racial_unique_kind: String = UnitDatabase.RACE_UNIQUE_KIND.get(race, "")
	for city in player.cities:
		if player.cities.size() < 2:
			city.set_production("settler")
			continue
		var defense_need := 0.0 if city.buildings.has("walls") else 1.0
		var threat := 1.0 if _city_under_threat(city, opponent, visible) else 0.0

		var best_id := ""
		var best_score := -INF
		for candidate_id in _production_candidates(player, city):
			var score := _score_production_candidate(candidate_id, defense_need, threat, military_deficit)
			if candidate_id == racial_unique_kind:
				score += SCORE_RACIAL_UNIT_TIE_BREAK
			if score > best_score:
				best_score = score
				best_id = candidate_id
		if best_id != "":
			city.set_production(best_id)

## Todo predio que a cidade ja pode CONSTRUIR (City.can_build — tech +
## pre-requisito de predio + slot livre, mesmo gate do jogador) mais toda
## unidade militar que ela ja pode TREINAR (City.can_train — predio de
## treino presente — E com tech propria pesquisada, player.has_unlocked).
static func _production_candidates(player: PlayerData, city: City) -> Array:
	var candidates: Array = []
	for building in BuildingDatabase.all_buildings():
		if city.can_build(building.id):
			candidates.append(building.id)
	for kind in _military_kinds_for(player):
		if not (kind in candidates) and player.has_unlocked(kind) and city.can_train(kind):
			candidates.append(kind)
	return candidates

## Uma frase por peso (ver comentario dos SCORE_WEIGHT_* acima). Muralhas
## sempre usa DEFENSE+THREAT (protege a cidade em si); predio de
## economia pura (sem trains_unit, ex Celeiro/Oficina/Mercado/Torre dos
## Sabios) usa so ECONOMY_GAP (a propria falta do predio ja e o sinal);
## predio de TREINO (com trains_unit, ex Quartel/Estabulo) e qualquer
## unidade militar competem pela MESMA pontuacao de deficit militar —
## de proposito, pra construir o predio de treino faltante concorrer de
## igual pra igual com so treinar mais uma tropa da que ja existe.
static func _score_production_candidate(candidate_id: String, defense_need: float, threat: float, military_deficit: float) -> float:
	if candidate_id == "walls":
		return SCORE_WEIGHT_DEFENSE * defense_need + SCORE_WEIGHT_THREAT * threat
	var building: BuildingData = BuildingDatabase.get_building(candidate_id)
	if building and building.trains_unit == "":
		return SCORE_WEIGHT_ECONOMY_GAP
	return SCORE_WEIGHT_MILITARY_DEFICIT * military_deficit + SCORE_WEIGHT_THREAT * threat * 0.5

## Cidade "sob ameaca" = HP abaixo de 75% (ja levou dano) OU unidade do
## oponente visivel dentro de PRODUCTION_THREAT_RADIUS tiles dela.
static func _city_under_threat(city: City, opponent: PlayerData, visible: Dictionary) -> bool:
	if city.hp < city.max_hp() * 0.75:
		return true
	for unit in opponent.units:
		if visible.has(unit.coord) and HexMetrics.axial_distance(unit.coord, city.coord) <= PRODUCTION_THREAT_RADIUS:
			return true
	return false

## Proporcao entre unidades militares proprias e ameaca CONHECIDA (unidade
## do oponente atualmente visivel — mesma nocao de "conhecido" que
## _choose_target usa pra combate) — 0.0 = exercito proprio ja cobre (ou
## sobra pra) a ameaca vista, 1.0 = nenhuma unidade militar propria pra
## nenhuma ameaca vista. Calculado uma vez por PLAYER (nao por cidade) de
## proposito — simplificacao deliberada pra manter o score explicavel;
## "perto de qual cidade" ficaria mais fiel mas exigiria contar unidades
## proprias por raio de cada cidade, complexidade nao justificada agora.
static func _military_deficit(player: PlayerData, opponent: PlayerData, visible: Dictionary) -> float:
	var own_military := 0
	for unit in player.units:
		if unit.unit_data.attack > 0.0:
			own_military += 1
	var known_threat := 0
	for unit in opponent.units:
		if visible.has(unit.coord):
			known_threat += 1
	# known_threat minimo de 1 (mesmo em paz/sem nada visivel): um rival
	# ainda deveria querer ALGUM exercito, nao zerar a necessidade so
	# porque nao ha ameaca vista no momento.
	var ratio := float(own_military) / float(max(known_threat, 1))
	return clamp(1.0 - ratio, 0.0, 1.0)

## Pesos da avaliacao de guerra oportunista (ver decide_war) — pedido do
## usuario (roadmap Fase 1): "guerra e decidida por uma avaliacao de
## oportunidade (forca relativa + proximidade + vulnerabilidade + custo
## esperado), nao so uma chance aleatoria isolada". FORCA RELATIVA e
## CUSTO ESPERADO viram UM SO termo aqui (WAR_WEIGHT_STRENGTH) porque
## medem a mesma coisa nesta escala simples: quanto mais forte eu sou
## perto do oponente, menor o custo esperado de atacar — rodar
## CombatResolver.predict() pra cada par de unidades possivel seria
## precisao alem do que uma decisao "vale abrir guerra" (nao "vale ESTE
## ataque") justifica.
const WAR_WEIGHT_STRENGTH := 1.0
const WAR_WEIGHT_PROXIMITY := 1.0
const WAR_WEIGHT_VULNERABILITY := 1.0
## Roadmap 2.0 Parte 1 (B2) — pedido do usuario: "ataco o anao porque
## aquela cidade controla 4 fontes de Ferro". Riqueza de recursos normalizada
## em cima de WAR_RESOURCE_RICHNESS_NORM (4+ recursos controlados = 1.0),
## somada aditivamente aos outros 3 termos, sem tocar no limiar/jitter
## abaixo — guerra passa a ter tambem um motivo economico/geografico, nao
## so forca relativa/proximidade/vulnerabilidade.
const WAR_WEIGHT_RESOURCES := 1.0
const WAR_RESOURCE_RICHNESS_NORM := 4.0
const WAR_SCORE_THRESHOLD := 1.5
## So verificado DEPOIS do limiar acima passar — jitter pequeno, nunca o
## unico fator (pedido explicito do usuario) — evita guerra "no instante
## exato" em que a vantagem cruza o limiar, sem tornar a decisao um
## sorteio disfarcado de avaliacao.
const WAR_DECLARE_CHANCE_WHEN_READY := 0.2
const WAR_PROXIMITY_RANGE := 10 # cidade conhecida alem disso nao conta como "perto o bastante" pra abrir guerra

## Avalia se vale abrir guerra contra `opponent` — so roda enquanto AINDA
## em paz (guerra ja em andamento nao precisa ser "decidida" de novo,
## ver Fase 2 do roadmap pra cansaco/encerramento) e so olha o MESMO
## oponente fixo que o resto de RivalAI usa (arquitetura de hoje: 1
## oponente por chamada — ver comentario de take_turn). Sem cidade
## inimiga JA CONHECIDA (PlayerData.known_enemy_cities), nao ha decisao
## nenhuma a tomar: um rival nunca declara guerra as cegas contra alguem
## que nunca viu.
static func decide_war(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> void:
	if player.is_at_war_with(opponent):
		return
	var target_coord = _nearest_known_enemy_city(player, opponent, hex_grid)
	if target_coord == null:
		return

	var own_strength := _total_military_strength(player)
	var enemy_strength := _total_military_strength(opponent)
	var strength_advantage: float = clamp((own_strength - enemy_strength) / max(own_strength + enemy_strength, 1.0), -1.0, 1.0)

	var proximity := 1.0 if _distance_to_nearest_own_city(player, target_coord) <= WAR_PROXIMITY_RANGE else 0.0

	var target_city := hex_grid.get_city_at(target_coord)
	var vulnerability := 1.0 if (target_city and not target_city.buildings.has("walls")) else 0.0
	var resource_richness := _city_resource_richness(target_city, hex_grid) if target_city else 0.0

	var score := WAR_WEIGHT_STRENGTH * strength_advantage + WAR_WEIGHT_PROXIMITY * proximity + WAR_WEIGHT_VULNERABILITY * vulnerability + WAR_WEIGHT_RESOURCES * resource_richness
	if score >= WAR_SCORE_THRESHOLD and randf() < WAR_DECLARE_CHANCE_WHEN_READY:
		Diplomacy.declare_war(player, opponent)

## Roadmap 2.0 Parte 1 (B2) — quantos recursos estrategicos DIFERENTES
## `city` controla (proprio tile + owned_tiles), normalizado 0.0-1.0 por
## WAR_RESOURCE_RICHNESS_NORM. Ressalva conhecida (nao resolvida agora, ver
## plano): correlaciona com territorio (owned_tiles.size()) — uma cidade
## grande tende a parecer "rica" mesmo com recursos espalhados. O harness
## de simulacao (test_simulation_balance.gd) imprime cidade-alvo/recursos/
## territorio/score a cada guerra decidida pra permitir medir isso depois
## com dado real, em vez de sofisticar a formula sem medicao.
static func _city_resource_richness(city: City, hex_grid: HexGrid) -> float:
	var seen := {}
	seen[city.coord] = true
	for c in city.owned_tiles:
		seen[c] = true
	var count := 0
	for coord in seen.keys():
		var data: HexTileData = hex_grid.get_tile(coord)
		if data and data.resource != "":
			count += 1
	return clamp(count / WAR_RESOURCE_RICHNESS_NORM, 0.0, 1.0)

## Soma do ataque de cada unidade militar, ponderado pela fracao de HP
## atual (uma unidade na metade da vida vale metade da forca) — proxy
## simples do "poder de fogo de verdade" de um exercito, sem precisar
## rodar combate nenhum de teste.
static func _total_military_strength(player: PlayerData) -> float:
	var total := 0.0
	for unit in player.units:
		if unit.unit_data.attack > 0.0 and unit.unit_data.max_hp > 0.0:
			total += unit.unit_data.attack * (unit.hp / unit.unit_data.max_hp)
	return total

## Cidade do oponente ja escoutada (PlayerData.known_enemy_cities) mais
## perto de QUALQUER cidade propria — mesma nocao de "conhecido" que
## _choose_target usa pra combate, aqui pra decidir SE vale abrir guerra
## em vez de contra quem atacar.
static func _nearest_known_enemy_city(player: PlayerData, opponent: PlayerData, hex_grid: HexGrid):
	var best_coord = null
	var best_dist = 999999
	for coord in player.known_enemy_cities.keys():
		var city = hex_grid.get_city_at(coord)
		if city == null or city.owner_player != opponent:
			continue
		var d = _distance_to_nearest_own_city(player, coord)
		if d < best_dist:
			best_dist = d
			best_coord = coord
	return best_coord

static func _distance_to_nearest_own_city(player: PlayerData, coord: Vector2i) -> int:
	var best = 999999
	for city in player.cities:
		var d = HexMetrics.axial_distance(city.coord, coord)
		if d < best:
			best = d
	return best

## Roadmap de gameplay Fase 4A — pequeno acrescimo ao escopo original do
## plano (TradeManager.propose_route por si so nunca teria como comecar
## sozinho: hoje so existe UI humana pra guerra/paz, nenhuma pra
## comercio ainda). Sem isto, o mecanismo de rota nunca seria exercitado
## de verdade no harness de simulacao (Fase 0) nem numa partida real
## contra a IA — ficaria testado so no nivel de unidade. Chance baixa por
## turno, so entre cidade JA conhecida (reusa _nearest_known_enemy_city —
## "conhecida", nao necessariamente hostil, mesma nocao de decide_war) e
## em paz.
const TRADE_PROPOSE_CHANCE_PER_TURN := 0.1

static func decide_trade(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> void:
	if player.is_at_war_with(opponent):
		return
	if randf() >= TRADE_PROPOSE_CHANCE_PER_TURN:
		return
	var target_coord = _nearest_known_enemy_city(player, opponent, hex_grid)
	if target_coord == null:
		return
	var target_city := hex_grid.get_city_at(target_coord)
	if target_city == null:
		return
	for city in player.cities:
		if TradeManager.active_route_count(city) < city.max_trade_routes(hex_grid):
			TradeManager.propose_route(city, target_city, hex_grid)
			return

## Roadmap "Parte B" B3 — pesos da pontuacao de PESQUISA (mesmo estilo
## nomeado/comentado de SCORE_WEIGHT_*/WAR_WEIGHT_* acima, ver decide_
## production/decide_war). CONTINUATION preserva o comportamento ja
## validado de Fase 4A ("tech cujo pre-requisito ja foi cumprido ganha
## prioridade sobre tech de raiz") — antes era um pool de DOIS grupos
## (continuations if not empty else available) com sorteio aleatorio
## DENTRO do grupo escolhido; agora e um TERMO pontuado, o que permite o
## termo de identidade (abaixo) somar por cima sem reintroduzir randi().
const RESEARCH_WEIGHT_CONTINUATION := 1.0
## Pequeno de proposito — nunca deveria, sozinho, superar uma continuacao
## de cadeia real (ver teste "nunca sobrepoe"). Harness-validate-later,
## mesma disciplina de todo o resto do sistema ("variavel sistemica
## pequena -> decisao existente -> formula aditiva -> teste comportamental
## -> harness antes de calibrar", ver AGRICOLA_FOOD_BONUS_MAX etc em
## CityIdentity.gd). civilization_axis_strength() e 0.0-1.0, entao o termo
## de identidade sozinho nunca ultrapassa RESEARCH_WEIGHT_IDENTITY — bem
## abaixo de RESEARCH_WEIGHT_CONTINUATION=1.0, pra uma continuacao de
## cadeia SEMPRE vencer um match de identidade PERFEITO sozinho. Risco de
## loop de reforco (Celeiro cedo -> agricola dominante no achado de B1/B2
## -> se isto favorecer tech agricola -> economia melhor -> mais
## capacidade de construcao -> MAIS agricola dominante) e exatamente por
## isso que NAO tentamos "corrigir" o vies de agricola aqui, so evitar
## agrava-lo sem medir primeiro (ver metrica research_choices_matching_
## identity em test_simulation_balance.gd).
const RESEARCH_WEIGHT_IDENTITY := 0.2
## Roadmap "Parte B" B4.2 — personalidade (CivilizationPersonality,
## PROSPECTIVA) soma como um TERCEIRO termo aditivo, ao lado de
## RESEARCH_WEIGHT_IDENTITY (CityIdentity.civilization_axis_strength,
## RETROSPECTIVA) — os dois convivem, nenhum substitui o outro (mandato do
## usuario: "personalidade e uma intencao persistente; identidade e
## evidencia historica"). Peso MENOR que RESEARCH_WEIGHT_IDENTITY de
## proposito: personalidade e uma intencao sorteada sem nenhuma evidencia
## de jogo por tras (identidade pelo menos reflete predios de verdade
## construidos) — harness-validate-later, mesma disciplina de todo o
## resto. IDENTITY + PERSONALITY somados (0.2 + 0.15 = 0.35) continuam bem
## abaixo de CONTINUATION (1.0), entao uma continuacao de cadeia real
## SEMPRE vence os dois combinados no maximo (ver teste "nunca sobrepoe").
## INVARIANTE PROTEGIDA: personalidade NUNCA deve ser alterada pela
## identidade (nunca "personality += civilization_axis_strength" nem
## aprendizado/deriva nenhum) — as duas sao entradas INDEPENDENTES aqui,
## nunca uma alimentando a outra.
const RESEARCH_WEIGHT_PERSONALITY := 0.15

## Eixo de identidade de UMA tecnologia, DERIVADO (nunca uma tabela nova
## hand-authored — mesmo espirito de CityIdentity inteira e do lair-danger
## de Parte A: "predios nunca encolhem, nao armazene, derive"). Regra:
## - se a tech desbloqueia um PREDIO (unlocks_building != ""), o eixo e o
##   balde de CityIdentity.AXIS_BUILDINGS que contem esse predio;
## - senao, se desbloqueia uma UNIDADE (unlocks_unit != ""), resolve o
##   predio que treina essa unidade (BuildingDatabase.building_that_trains
##   — MESMO mecanismo que CityIdentity.militar_unit_cost_multiplier ja usa
##   pra ir de unidade -> predio treinador -> eixo, inclusive o fallback
##   scout/human_knight -> Estabulo) e usa o balde DESSE predio;
## - senao (feitico puro, bonus de bioma puro, terrain_transform puro, ou
##   standalone sem desbloqueio nenhum) -> "" (sem sinal de identidade).
## bonus_terrain_types e IGNORADO de proposito mesmo quando presente —
## misturar "sabor de rendimento" com "arvore de predios" como dois tipos
## diferentes de sinal tornaria a regra ambigua; so building/unit unlocks
## contam, uma regra so, mecanicamente fundamentada.
##
## Invariante verificada (nao assumida): checa unlocks_building ANTES de
## unlocks_unit, o que so e seguro se nenhuma tech tiver os dois setados
## ao mesmo tempo — conferido direto em TechDatabase.gd (14 atribuicoes de
## unlocks_building/unlocks_unit, 14 variaveis de tech DISTINTAS, nenhuma
## repetida). Se isso mudar no futuro, a funcao continua funcionando (so
## ignora unlocks_unit nesse caso), mas os testes de derivacao servem de
## sentinela caso essa prioridade precise ser revisitada.
##
## Mora aqui (RivalAI.gd), NAO em CityIdentity.gd (que fica cega pra
## tecnologia de proposito, nunca aprende sobre TechData) nem em
## TechDatabase.gd/TechData.gd (que ficam cegos pra identidade de
## proposito, nenhum campo novo) — esta e a UNICA peca do sistema com
## permissao de conhecer os dois lados, porque e a UNICA que decide
## pesquisa (jogador humano escolhe livre pela HUD/TechTree, sem
## pontuacao nenhuma envolvida, sem gating de identidade).
static func _tech_identity_axis(tech: TechData) -> String:
	if tech.unlocks_building != "":
		return _axis_for_building(tech.unlocks_building)
	if tech.unlocks_unit != "":
		var trainer: BuildingData = BuildingDatabase.building_that_trains(tech.unlocks_unit)
		if trainer != null:
			return _axis_for_building(trainer.id)
	return ""

static func _axis_for_building(building_id: String) -> String:
	for axis in CityIdentity.AXES:
		if building_id in CityIdentity.AXIS_BUILDINGS[axis]:
			return axis
	return ""

## Pontuacao de UM candidato de pesquisa (ver RESEARCH_WEIGHT_* acima).
static func _score_research_candidate(tech: TechData, player: PlayerData) -> float:
	var continues_chain := false
	for prereq_id in tech.prerequisites:
		if player.researched_techs.has(prereq_id):
			continues_chain = true
			break
	var axis := _tech_identity_axis(tech)
	var identity_strength := 0.0 if axis == "" else CityIdentity.civilization_axis_strength(player, axis)
	var personality_strength: float = 0.0 if axis == "" else player.personality.get(axis, 0.0)
	return (
		RESEARCH_WEIGHT_CONTINUATION * (1.0 if continues_chain else 0.0)
		+ RESEARCH_WEIGHT_IDENTITY * identity_strength
		+ RESEARCH_WEIGHT_PERSONALITY * personality_strength
	)

## Sem nenhuma pesquisa em andamento, escolhe a tecnologia disponivel de
## MAIOR pontuacao (ver _score_research_candidate) — nao mais um sorteio
## cego. Empate resolvido pela ordem de iteracao de `available` (que segue
## TechDatabase.all_techs(), ordem de insercao estavel — deterministico,
## nao randi(), mesmo padrao de _score_settle_candidate/_score_production_
## candidate). Roadmap de gameplay Fase 4A — achado do harness de simulacao
## (Fase 0): sorteio uniforme entre TODAS as disponiveis fazia Mercado
## (Celeiro -> Oficina -> Mercado, 3 pesquisas especificas em sequencia)
## nunca ser alcancado nem em 200 turnos — o termo RESEARCH_WEIGHT_
## CONTINUATION preserva exatamente esse fix (continuar uma cadeia em
## andamento ganha prioridade sobre tech de raiz). Roadmap "Parte B" B3
## acrescenta o termo RESEARCH_WEIGHT_IDENTITY por cima, na MESMA formula —
## nunca um pool separado, nunca um bloqueio (preferencia, nunca
## exclusividade).
static func decide_research(player: PlayerData) -> void:
	if player.current_research != "":
		return
	var available = TechDatabase.available_techs(player.researched_techs)
	if available.is_empty():
		return
	var best_tech: TechData = null
	var best_score := -INF
	for tech in available:
		var score := _score_research_candidate(tech, player)
		if score > best_score:
			best_score = score
			best_tech = tech
	player.current_research = best_tech.id

## So a parte de "preparar" o turno da IA (visibilidade atual + atualizar
## cidades inimigas escoutadas), SEM mover nenhuma unidade ainda — extraido
## de take_turn() pra GameManager poder chamar isto UMA VEZ por rival e
## depois processar as unidades dela aos poucos, em frames diferentes (ver
## GameManager._build_rival_turn_items/stagger_ai_turns, pedido do
## usuario: "civilization nao faz tudo acontecer no mapa ao mesmo
## tempo... em pequenos grupos... diminui o lag na passada de turnos").
static func begin_turn(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> Dictionary:
	var visible := hex_grid.compute_visible_tiles(player)
	_scout_enemy_cities(player, opponent, visible)
	return visible

## Acao de UMA unidade rival — extraida de take_turn() pelo mesmo motivo de
## begin_turn() acima, pra poder ser chamada unidade-por-unidade em frames
## diferentes.
static func act_for_unit(unit: Unit, hex_grid: HexGrid, player: PlayerData, opponent: PlayerData, visible: Dictionary) -> void:
	if unit.unit_data.can_found_city:
		_handle_settler(unit, hex_grid, player)
	elif unit.unit_data.attack > 0.0:
		_handle_attacker(unit, hex_grid, player, opponent, visible)

## Turno da IA rival inteiro DE UMA VEZ, no MESMO frame — continua sendo o
## caminho usado quando GameManager.stagger_ai_turns esta desligado (o
## padrao, inclusive em TODO teste GUT, que nunca liga esse flag), agora so
## delegando pra begin_turn()/act_for_unit() acima em vez de duplicar a
## logica.
static func take_turn(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> void:
	var visible := begin_turn(player, hex_grid, opponent)
	for unit in player.units.duplicate():
		if not is_instance_valid(unit):
			continue
		act_for_unit(unit, hex_grid, player, opponent, visible)

## Cidade inimiga entra na memoria permanente assim que fica visivel — nao
## precisa continuar visivel depois disso (ela nao anda).
static func _scout_enemy_cities(player: PlayerData, opponent: PlayerData, visible: Dictionary) -> void:
	for city in opponent.cities:
		if visible.has(city.coord):
			player.known_enemy_cities[city.coord] = true

static func _handle_attacker(unit: Unit, hex_grid: HexGrid, player: PlayerData, opponent: PlayerData, visible: Dictionary) -> void:
	if unit.hp < unit.unit_data.max_hp * RETREAT_HP_FRACTION:
		_retreat(unit, hex_grid, player)
		return

	var target_coord = _choose_target(unit, hex_grid, player, opponent, visible)
	if target_coord == null:
		return

	if target_coord in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
		_engage(unit, hex_grid, target_coord)
		return

	if HexMetrics.axial_distance(unit.coord, target_coord) > PERCEPTION_RANGE:
		return

	if unit.unit_data.attack_range > 1 and not _has_melee_escort_nearby(unit, player):
		return

	move_unit_toward(unit, hex_grid, target_coord)

## Ataca so se o combate parecer favoravel; cidade indefesa e sempre um
## alvo valido pra ATACAR (sem risco pro atacante — cidade nao contra-
## ataca) — mas nao captura mais num unico golpe, ver CombatResolver.
## resolve_city_attack (desconta do escudo/vida da cidade, pode levar
## varios turnos ate a vida zerar e capturar de verdade).
static func _engage(unit: Unit, hex_grid: HexGrid, target_coord: Vector2i) -> void:
	var defender = hex_grid.get_unit_at(target_coord)
	if defender:
		if is_favorable_attack(unit, defender, hex_grid):
			CombatResolver.resolve(unit, defender, hex_grid)
		return
	var city = hex_grid.get_city_at(target_coord)
	if city:
		CombatResolver.resolve_city_attack(unit, city, hex_grid)

## Nao ataca se for morrer no proprio ataque. Se o defensor tambem
## sobrevive, so vale a pena se a unidade causar proporcionalmente mais
## dano do que leva (comparado em % do HP maximo de cada um, pra nao
## favorecer injustamente unidades com HP maximo diferente). Publica (sem
## `_`) porque MonsterAI.gd tambem chama, pro comportamento Cacador
## (Vivern/Dragao) so atacar quando favoravel — o resto de RivalAI
## continua privado de proposito (especifico de PlayerData/captura de
## cidade, fora do escopo de monstro neutro).
static func is_favorable_attack(attacker: Unit, defender: Unit, hex_grid: HexGrid) -> bool:
	var result = CombatResolver.predict(attacker, defender, hex_grid)
	if result.attacker_dies:
		return false
	if result.defender_dies:
		return true
	var defender_loss_pct = result.damage_to_defender / defender.unit_data.max_hp
	var attacker_loss_pct = result.damage_to_attacker / attacker.unit_data.max_hp
	return defender_loss_pct >= attacker_loss_pct

## Existe algum aliado corpo-a-corpo (attack_range 1) a ate ESCORT_RANGE
## tiles de distancia de `unit`? Usado pra decidir se uma unidade a
## distancia pode avancar sozinha sem virar alvo facil isolado.
static func _has_melee_escort_nearby(unit: Unit, player: PlayerData) -> bool:
	for ally in player.units:
		if ally == unit or ally.unit_data.attack <= 0.0:
			continue
		if ally.unit_data.attack_range <= 1 and HexMetrics.axial_distance(ally.coord, unit.coord) <= ESCORT_RANGE:
			return true
	return false

## Cidade inimiga indefesa e ja escoutada (nao precisa estar visivel agora,
## so conhecida — ver PlayerData.known_enemy_cities) dentro do alcance de
## percepcao e sempre prioridade sobre uma escaramuca; senao mira no alvo
## mais proximo dentre o que a IA realmente enxerga agora (unidades) ou ja
## escoutou (cidades). Em paz com `opponent` (ver Diplomacy.gd/
## PlayerData.is_at_war_with) nunca mira nele — so o jogador humano
## negocia paz/guerra ativamente, mas a IA sempre respeita o resultado.
static func _choose_target(unit: Unit, hex_grid: HexGrid, player: PlayerData, opponent: PlayerData, visible: Dictionary):
	if not player.is_at_war_with(opponent):
		return null
	for coord in player.known_enemy_cities.keys():
		var city = hex_grid.get_city_at(coord)
		if city and city.owner_player == opponent and hex_grid.get_unit_at(coord) == null:
			if HexMetrics.axial_distance(unit.coord, coord) <= PERCEPTION_RANGE:
				return coord
	return _nearest_known_target(unit.coord, hex_grid, player, opponent, visible)

static func _nearest_known_target(from: Vector2i, hex_grid: HexGrid, player: PlayerData, opponent: PlayerData, visible: Dictionary):
	var best = null
	var best_dist = 999999
	for unit in opponent.units:
		if not visible.has(unit.coord):
			continue
		var d = HexMetrics.axial_distance(from, unit.coord)
		if d < best_dist:
			best_dist = d
			best = unit.coord
	for coord in player.known_enemy_cities.keys():
		var city = hex_grid.get_city_at(coord)
		if city == null or city.owner_player != opponent:
			continue
		var d = HexMetrics.axial_distance(from, coord)
		if d < best_dist:
			best_dist = d
			best = coord
	return best

## Movimento guloso por distancia hexagonal (nao e A* de verdade — so pega,
## entre os tiles alcancaveis neste turno, o que mais reduz distancia ate
## `target_coord`). Publica (sem `_`) porque MonsterAI.gd reusa exatamente
## este primitivo pro comportamento Invasor/Cacador — o unico "conhecimento
## de dono" que ele usa e `unit.owner_player` (repassado como `owner` pro
## compute_reachable, que ja trata `null` corretamente: nenhuma cidade
## nunca conta como do "dono null", entao um monstro nunca consegue sequer
## pisar em tile de cidade, ver HexGrid.compute_reachable).
static func move_unit_toward(unit: Unit, hex_grid: HexGrid, target_coord: Vector2i) -> void:
	var reachable = hex_grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player, unit.unit_data.flies)
	var best_coord = null
	var best_dist = HexMetrics.axial_distance(unit.coord, target_coord)
	for coord in reachable.keys():
		var d = HexMetrics.axial_distance(coord, target_coord)
		if d < best_dist:
			best_dist = d
			best_coord = coord
	if best_coord != null:
		hex_grid.move_unit(unit, best_coord, reachable[best_coord])

## Foge pra perto da cidade mais proxima em vez de continuar brigando
## fraca — la ela cura (GameManager._heal_if_garrisoned).
static func _retreat(unit: Unit, hex_grid: HexGrid, player: PlayerData) -> void:
	if player.cities.is_empty():
		return
	var nearest_city_coord = null
	var best_dist = 999999
	for city in player.cities:
		var d = HexMetrics.axial_distance(unit.coord, city.coord)
		if d < best_dist:
			best_dist = d
			nearest_city_coord = city.coord
	if nearest_city_coord == null or nearest_city_coord == unit.coord:
		return
	move_unit_toward(unit, hex_grid, nearest_city_coord)

static func _handle_settler(unit: Unit, hex_grid: HexGrid, player: PlayerData) -> void:
	if hex_grid.get_city_at(unit.coord) == null and _far_enough_from_cities(unit.coord, hex_grid):
		WorldSetup.found_city_from_settler(hex_grid, unit)
		return

	var reachable = hex_grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player)
	if reachable.size() > 0:
		var best_coord = null
		var best_score := -INF
		for candidate in reachable.keys():
			var score := _score_settle_candidate(candidate, hex_grid, player)
			if score > best_score:
				best_score = score
				best_coord = candidate
		hex_grid.move_unit(unit, best_coord, reachable[best_coord])

## Roadmap 2.0 Parte 1 (B3) — antes escolhia um destino ALEATORIO entre os
## tiles alcancaveis (options[randi() % options.size()]) quando ainda nao
## estava pronto pra fundar. Agora prefere um destino com vizinhos de
## recurso (+1 por vizinho com recurso), e evita levemente um tile sob
## pressao de cidade rival (A2, is_under_rival_pressure) — nunca bloqueio,
## so preferencia, mesmo espirito do resto do sistema. Empate resolvido
## pela ordem de iteracao de Dictionary.keys() (determinístico, nao
## randi()), pra manter os testes previsiveis.
const SETTLE_RIVAL_PRESSURE_PENALTY := 2.0
## Roadmap 2.0 (fecha Parte A) — constante PROPRIA, nao reusa SETTLE_RIVAL_
## PRESSURE_PENALTY: sao fenomenos diferentes (unidade neutra hostil vs.
## civ rival), mesmo que a FORMA da penalidade seja identica (aditiva,
## nunca bloqueio, ver HexGrid.get_lair_danger_at).
const SETTLE_LAIR_DANGER_WEIGHT := 3.0

static func _score_settle_candidate(coord: Vector2i, hex_grid: HexGrid, player: PlayerData) -> float:
	var score := 0.0
	for n in hex_grid.get_neighbors(coord):
		var data: HexTileData = hex_grid.get_tile(n)
		if data and data.resource != "":
			score += 1.0
	if hex_grid.is_under_rival_pressure(coord, player):
		score -= SETTLE_RIVAL_PRESSURE_PENALTY
	score -= hex_grid.get_lair_danger_at(coord) * SETTLE_LAIR_DANGER_WEIGHT
	return score

## Roadmap 2.0 Parte 1 (A3) — corrigido pra olhar TODAS as cidades do mapa
## (agora via hex_grid.cities_by_coord, nao mais player.cities): antes um
## assentador de IA podia fundar colado numa cidade RIVAL, inclusive do
## jogador humano, porque o check so enxergava as cidades do proprio
## `player`. A fundacao do jogador HUMANO continua sem nenhuma restricao de
## distancia (nao existe check equivalente do lado dele) — essa correcao e
## so pro lado da IA, por pedido explicito do usuario de nao transformar
## uma correcao de IA numa mudanca de regra global.
static func _far_enough_from_cities(coord: Vector2i, hex_grid: HexGrid) -> bool:
	for city in hex_grid.cities_by_coord.values():
		if HexMetrics.axial_distance(coord, city.coord) < SETTLE_MIN_DISTANCE:
			return false
	return true
