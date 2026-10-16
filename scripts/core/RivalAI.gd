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
## Fase 24/25: pesquisa, economia, filas, Técnicas/Magia e objetivos de vitória são de V2StrategicAI/
## V2AITacticalAI; este arquivo guarda a camada COMPARTILHADA de execução no mapa (movimento, combate
## comum, colonos, defesa contra o Dragão) e a diplomacia (decide_war/decide_campaign/decide_peace).
## decide_war() pode iniciar guerra sozinha contra o oponente quando uma avaliacao de oportunidade
## justificar (ver WAR_WEIGHT_*).

const PERCEPTION_RANGE := 5
const RETREAT_HP_FRACTION := 0.35 # abaixo disso, foge pra curar em vez de brigar
const ESCORT_RANGE := 2 # distancia maxima pra um aliado corpo-a-corpo contar como escolta

## Roadmap "Parte C", C1 — conta unidades vivas por papel (ArmyComposition.
## roles_for_kind), usado pela escolha de alvo de guerra. Estado DERIVADO, nunca persistido. Unidade multi-papel (ex.
## cavalry=[melee,cavalry]) conta pros DOIS balaios — nao ha "papel
## principal".
static func _role_counts(player: PlayerData) -> Dictionary:
	var counts := {}
	for role in ArmyComposition.ROLES:
		counts[role] = 0
	for unit in player.units:
		for role in ArmyComposition.roles_for_kind(unit.unit_data.visual_kind):
			counts[role] += 1
	return counts

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
## Roadmap "Parte D" D4.4 -- desde a divisao semantica promovida a
## producao (ver WAR_OBJECTIVE_TERM_WEIGHTS), CONQUER deixou de
## considerar recursos (motivo puramente militar) e este peso ficou SEM
## CONSUMIDOR no perfil default -- preservado nomeado, nao apagado, pra
## um experimento futuro que queira reintroduzir alguma sensibilidade a
## recurso em conquer sem inventar um numero novo.
const WAR_WEIGHT_RESOURCES := 1.0
const WAR_RESOURCE_RICHNESS_NORM := 4.0
const WAR_SCORE_THRESHOLD := 1.5
## HISTÓRICO: até 2026-10-15 a guerra pronta ainda passava por este sorteio (20%/turno). Substituído pela preparação
## determinística (WAR_PREPARATION_TURNS, ver decide_war) — mesma função de "não declarar no instante exato em que
## a vantagem cruza o limiar", sem sorteio. Nenhum código lê mais esta constante.
const WAR_DECLARE_CHANCE_WHEN_READY := 0.2
const WAR_PROXIMITY_RANGE := 10 # cidade conhecida alem disso nao conta como "perto o bastante" pra abrir guerra
## Roadmap "Parte C" C2 — 2+ unidades do papel certo ja conta como "tenho o
## suficiente" (fit=1.0), mesma normalizacao de WAR_RESOURCE_RICHNESS_NORM
## pro eixo de composicao (ver _role_fit_bonus). RESSALVA: ponto de partida
## calibravel, nao invariante de dominio — ver comentario de WAR_WEIGHT_
## ROLE_FIT em _best_war_objective.
const WAR_ROLE_FIT_NORM := 2.0

## Todas as cidades do oponente ja escoutadas (nao so a mais perto, ver
## _nearest_known_enemy_city — continua existindo intacta, ainda usada por
## decide_trade). Mesma nocao de "conhecida" de sempre (known_enemy_cities),
## filtrando cidade que sumiu ou trocou de dono (recapturada).
static func _known_enemy_cities_of(player: PlayerData, opponent: PlayerData, hex_grid: HexGrid) -> Array[City]:
	var result: Array[City] = []
	for coord in player.known_enemy_cities.keys():
		var city := hex_grid.get_city_at(coord)
		if city and city.owner_player == opponent:
			result.append(city)
	return result

## Papel que ESTE alvo exige: muralha de pe -> cerco (preciso furar defesa);
## sem muralha -> cavalaria (mobilidade converte janela de oportunidade
## aberta em ataque de verdade antes que feche). Mesmo papel pros DOIS tipos
## de objetivo de proposito (ver _best_war_objective) -- a acao militar e
## identica nos dois, so o MOTIVO da guerra difere. HEURISTICA de C2, nao
## verdade estrutural do dominio (ao contrario de ArmyComposition.roles_
## for_kind, que deriva de propriedades ja existentes de UnitData) — tratar
## como hipotese de balanceamento sujeita a revisao pelo harness, nao como
## invariante.
static func _role_fit_bonus(target_city: City, role_counts: Dictionary) -> float:
	var needed_role: String = ArmyComposition.ROLE_SIEGE if target_city.has_fortification() else ArmyComposition.ROLE_CAVALRY
	var have: float = role_counts.get(needed_role, 0)
	return clamp(have / WAR_ROLE_FIT_NORM, 0.0, 1.0)

const WAR_OBJECTIVE_CONQUER := "conquer"
const WAR_OBJECTIVE_SECURE_RESOURCES := "secure_resources"
## Ordem importa pro desempate deterministico em _best_war_objective (CONQUER
## primeiro): quando os dois objetivos empatam pro MESMO alvo (sempre que
## resource_richness == 0), CONQUER vence -- "sem recurso pra proteger, e so
## uma conquista".
const WAR_OBJECTIVES: Array[String] = [WAR_OBJECTIVE_CONQUER, WAR_OBJECTIVE_SECURE_RESOURCES]
## Recurso pesa o DOBRO quando o objetivo E "garantir recursos" -- motivo
## primario, nao mais um sinal entre outros (WAR_WEIGHT_RESOURCES continua
## valendo pra CONQUER, onde recurso e so bonus de oportunidade). Valor
## DEFAULT consultado por WAR_OBJECTIVE_TERM_WEIGHTS abaixo -- permanece
## const de proposito (D4.2 sobrescrevia isto direto; desde D4.4 quem
## precisar de override sobrescreve WAR_OBJECTIVE_TERM_WEIGHTS, mecanismo
## generalizado que substitui o D4.2 antigo).
const WAR_WEIGHT_RESOURCES_SECURE := 2.0

## Roadmap "Parte C" C2 -- conecta ArmyComposition (C1) a decide_war como
## sinal SEPARADO de _total_military_strength: forca total = quanto poder
## tenho; role_fit = se tenho o TIPO certo de poder pro que ESTE alvo exige
## (muralha -> cerco; alvo aberto -> mobilidade). Pequeno de proposito (ver
## hierarquia numerica no plano) -- nunca cruza o limiar sozinho nem vira a
## escolha entre dois alvos que ja divergem num termo binario primario.
## RESSALVA (pedido explicito do usuario): "muralha->cerco / sem muralha->
## cavalaria" e uma HEURISTICA ESTRATEGICA nova desta fatia, nao uma
## propriedade de dominio ja existente como attack_range/movement_points
## sao pra ArmyComposition -- e este peso (0.3) e WAR_ROLE_FIT_NORM (2.0)
## sao pontos de partida CALIBRAVEIS, nao valores corretos por definicao. O
## harness decide se fazem sentido, nunca calibrar dentro desta fatia.
const WAR_WEIGHT_ROLE_FIT := 0.3

## Roadmap "Parte D" D4.2->D4.4 (PROMOVIDO A PRODUCAO) -- vetor de pesos
## completo POR OBJETIVO. Ate D4.4, os dois objetivos compartilhavam
## strength/proximity/vulnerability/role_fit e so o peso de resources
## diferia -- D4.1 mediu que isso fazia secure_resources vencer 113/113
## (peso maior, nunca "acha cidade melhor"); D4.2 confirmou que reduzir o
## peso (2.0->1.25) nao mudava a decisao, so a margem, e que igualar
## (1.0) tambem cortava guerras declaradas quase pela metade (efeito
## colateral indesejado). D4.4 resolveu na raiz: os dois objetivos agora
## tem TERMOS diferentes, nao so pesos diferentes --
##   conquer          = qualidade MILITAR do alvo (strength, proximity,
##                       vulnerability, role_fit) -- SEM resources.
##   secure_resources = valor ECONOMICO do alvo (strength, proximity,
##                       vulnerability, resources) -- SEM role_fit
##                       (role_fit era 0/221 na amostra medida em D4.3,
##                       gargalo de C1 -- composicao militar 100% corpo-a-
##                       corpo -- nao usado como justificativa pra mudar
##                       C2, ver D4.4).
## WAR_WEIGHT_RESOURCES_SECURE continua 2.0 (nunca foi o problema, D4.2
## ja provou isso) e WAR_WEIGHT_RESOURCES (peso antigo de conquer pra
## recursos) fica sem consumidor no default -- preservado como constante
## nomeada pra referencia historica/experimentos futuros, nunca lido pelo
## perfil padrao. static var (nao const) preservado de proposito: e o
## MECANISMO (nao so o numero) que D4.2/D4.4/D4.5 validaram, e mante-lo
## sobrescrivel permite um proximo experimento sem editar codigo -- ver
## test_simulation_balance.gd pros usos ja existentes (D4.2 ainda varia
## SO o peso de recursos de secure_resources; D4.4/D4.5 usam este MESMO
## vetor, que agora e o baseline real em vez de uma copia experimental).
static var WAR_OBJECTIVE_TERM_WEIGHTS := {
	WAR_OBJECTIVE_CONQUER: {
		"strength": WAR_WEIGHT_STRENGTH,
		"proximity": WAR_WEIGHT_PROXIMITY,
		"vulnerability": WAR_WEIGHT_VULNERABILITY,
		"resources": 0.0,
		"role_fit": WAR_WEIGHT_ROLE_FIT,
	},
	WAR_OBJECTIVE_SECURE_RESOURCES: {
		"strength": WAR_WEIGHT_STRENGTH,
		"proximity": WAR_WEIGHT_PROXIMITY,
		"vulnerability": WAR_WEIGHT_VULNERABILITY,
		"resources": WAR_WEIGHT_RESOURCES_SECURE,
		"role_fit": 0.0,
	},
}

## Roadmap "Parte D" D4.3 -- os 4 fatores CRUS (pre-peso) que dependem so
## de `city` (objective-independentes -- o PESO de cada termo muda por
## objetivo via WAR_OBJECTIVE_TERM_WEIGHTS acima, nunca o fator cru em
## si). Extraido pra o harness poder medir a DISTRIBUICAO real de cada
## fator (resources perto do teto? proximity quase sempre 1.0? role_fit
## quase sempre 0.0?) sem repetir nenhum calculo -- _war_target_score_
## components abaixo passa a chamar esta funcao em vez de recalcular os
## mesmos 4 fatores inline. strength_advantage fica de fora de proposito:
## e por PLAYER/OPONENTE, nao por `city`, ja calculado 1x pelo chamador
## (mesmo padrao de sempre).
static func _war_target_raw_factors(player: PlayerData, hex_grid: HexGrid, city: City, role_counts: Dictionary) -> Dictionary:
	return {
		"proximity": 1.0 if _distance_to_nearest_own_city(player, city.coord) <= WAR_PROXIMITY_RANGE else 0.0,
		"vulnerability": 1.0 if not city.has_fortification() else 0.0,
		"resource_richness": _city_resource_richness(city, hex_grid),
		"role_fit": _role_fit_bonus(city, role_counts),
	}

## Roadmap "Parte D" D4.1 -- extraido de dentro de _score_war_target (que
## so somava os termos inline ate aqui) pra o harness poder inspecionar
## CADA termo separadamente (diagnostico "secure_resources vence por peso
## maior, ou por achar cidade melhor?") sem duplicar a formula: harness
## chama esta funcao E _score_war_target diretamente, nunca reimplementa
## nenhum termo. De proposito NAO um contrato estrutural novo de RivalAI --
## so um passo intermediario do calculo ja existente, exposto pra quem
## precisar dos termos (hoje: so o harness). _score_war_target continua
## sendo a UNICA fonte de verdade do SCORE (soma destes termos); nenhum
## chamador de producao (_best_war_objective, _campaign_still_viable)
## muda.
static func _war_target_score_components(player: PlayerData, hex_grid: HexGrid, city: City, objective: String, strength_advantage: float, role_counts: Dictionary) -> Dictionary:
	var raw := _war_target_raw_factors(player, hex_grid, city, role_counts)
	var weights: Dictionary = WAR_OBJECTIVE_TERM_WEIGHTS[objective]
	return {
		"strength": weights.strength * strength_advantage,
		"proximity": weights.proximity * raw.proximity,
		"vulnerability": weights.vulnerability * raw.vulnerability,
		"resources": weights.resources * raw.resource_richness,
		"role_fit": weights.role_fit * raw.role_fit,
	}

## Roadmap "Parte C" C3 — extraido de dentro do loop de _best_war_objective
## pra ser reusado tambem por _campaign_still_viable, MESMA formula, nunca
## duas. strength_advantage/role_counts continuam calculados UMA vez pelo
## CHAMADOR (nao aqui dentro), mesma razao de performance de sempre.
static func _score_war_target(player: PlayerData, hex_grid: HexGrid, city: City, objective: String, strength_advantage: float, role_counts: Dictionary) -> float:
	var components := _war_target_score_components(player, hex_grid, city, objective, strength_advantage, role_counts)
	return components.strength + components.proximity + components.vulnerability + components.resources + components.role_fit

## Roadmap "Parte D" D4.5 (PROMOVIDO A PRODUCAO) -- MODO de comparacao
## entre os melhores candidatos de CADA objetivo (Etapa 2 de
## _best_war_objective abaixo), pluggavel pelo MESMO motivo/padrao de
## WAR_OBJECTIVE_TERM_WEIGHTS. D4.4 provou que conquer/secure_resources
## ja tem semantica distinta (92% dos casos apontam pra cidades
## diferentes), mas comparar SCORE BRUTO entre objetivos com tetos
## diferentes (conquer sem o termo de recursos = teto menor) e enviesado
## pra quem tem o teto mais alto -- "raw" (o UNICO modo que existiu ate
## D4.5) e essa comparacao antiga. "normalized_max" e o vencedor
## experimental: score/teto proprio de cada objetivo, deixando conquer
## vencer 6/113 decisoes (0 antes) SEM alterar guerras_declaradas (45,
## identico) -- ver D4.5. "relative_margin" foi descartado (rejeitado
## pra producao): rendia mais vitorias de conquer (8/113) mas cortava
## guerras_declaradas quase pela metade, contaminando indiretamente
## WAR_SCORE_THRESHOLD -- preservado como modo disponivel (nunca
## deletado, ver "nao promoveria... salvo se quiser manter como
## ferramenta de debug"), nunca o default.
const WAR_OBJECTIVE_COMPARISON_RAW := "raw"
## score / teto TEORICO do objetivo (soma de peso*1.0 por termo -- todo
## fator cru e 0.0-1.0, exceto strength_advantage que vai ate -1.0, mas o
## teto usa o melhor caso 1.0 pros dois objetivos por igual). Denominador
## DERIVADO do proprio WAR_OBJECTIVE_TERM_WEIGHTS (ver
## _war_objective_theoretical_max abaixo) -- nunca uma constante
## calibrada a parte, nunca ajustada empiricamente pra favorecer
## nenhum objetivo.
const WAR_OBJECTIVE_COMPARISON_NORMALIZED_MAX := "normalized_max"
## score - MEDIA do score daquele objetivo entre TODOS os candidatos desta
## decisao -- "o quanto este candidato se destaca dentro do proprio pool",
## em vez de um teto fixo. Disponivel, NAO promovido -- ver D4.5.
const WAR_OBJECTIVE_COMPARISON_RELATIVE_MARGIN := "relative_margin"
static var WAR_OBJECTIVE_COMPARISON_MODE := WAR_OBJECTIVE_COMPARISON_NORMALIZED_MAX

## D4.5 -- teto teorico de um objetivo, so usado pelo modo
## "normalized_max" (ver WAR_OBJECTIVE_COMPARISON_MODE acima).
static func _war_objective_theoretical_max(objective: String) -> float:
	var weights: Dictionary = WAR_OBJECTIVE_TERM_WEIGHTS[objective]
	return weights.strength + weights.proximity + weights.vulnerability + weights.resources + weights.role_fit

## D4.5 -- traduz um score bruto em "qualidade" comparavel ENTRE
## objetivos, conforme WAR_OBJECTIVE_COMPARISON_MODE. `avg_score` (so
## usado pelo modo relative_margin) e a media do score DAQUELE objetivo
## entre todos os candidatos avaliados nesta decisao (calculada pelo
## chamador, ver _best_war_objective).
static func _war_objective_quality(score: float, objective: String, avg_score: float) -> float:
	match WAR_OBJECTIVE_COMPARISON_MODE:
		WAR_OBJECTIVE_COMPARISON_NORMALIZED_MAX:
			var theoretical_max := _war_objective_theoretical_max(objective)
			return score / theoretical_max if theoretical_max > 0.0 else 0.0
		WAR_OBJECTIVE_COMPARISON_RELATIVE_MARGIN:
			return score - avg_score
		_:
			return score

## Melhor par (cidade conhecida, tipo de objetivo) contra `opponent`, ou null
## se nao ha nenhuma cidade conhecida. strength_advantage e role_counts sao
## calculados UMA vez (nivel-jogador, mesma simplificacao de _military_
## deficit), depois repassados pra _score_war_target por CIDADE, reusados
## pelos dois objetivos. Retorna {"city","coord","objective","score"} --
## valor TRANSIENTE, nunca guardado (recomputado sempre que alguem precisa
## saber "qual seria o objetivo agora": decide_war e o log do harness).
## `score` no retorno e SEMPRE o score BRUTO do vencedor (nunca "quality"),
## de proposito: decide_war compara isso contra WAR_SCORE_THRESHOLD, um
## limiar calibrado na mesma escala de score de sempre -- so QUEM vence
## entre os dois objetivos passa a poder ser decidido por uma medida
## diferente (D4.5), nao a escala em que o limiar de guerra opera.
##
## Roadmap "Parte D" D4.5 -- reestruturado em DUAS etapas explicitas
## (pedido do usuario): Etapa 1, cada objetivo acha seu proprio melhor
## candidato dentro da sua propria semantica (MESMO loop de sempre, so
## agora guardando o melhor POR OBJETIVO em vez de um unico "melhor
## geral" correndo); Etapa 2, compara os dois melhores por "qualidade"
## (pluggavel, ver _war_objective_quality; default de producao e
## "normalized_max" desde D4.5, ver WAR_OBJECTIVE_COMPARISON_MODE). No
## modo "raw" (o unico que existia ANTES de D4.5) esta reestruturacao e
## matematicamente equivalente ao algoritmo antigo de passada unica pra
## QUALQUER decisao ja coberta pelos testes existentes (verificado
## rodando a suite inteira) -- a unica divergencia teorica possivel e um
## empate de score EXATO entre CIDADES DIFERENTES de objetivos diferentes,
## caso em que o antigo desempatava pela ordem de iteracao das cidades e
## este desempata sempre a favor de CONQUER (MESMA direcao do desempate ja
## documentado pra empate na MESMA cidade) -- nunca observado nos dados
## reais de D4.1-D4.4 (resource_richness nunca foi 0 na amostra).
static func _best_war_objective(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData):
	var candidates := _known_enemy_cities_of(player, opponent, hex_grid)
	if candidates.is_empty():
		return null

	var own_strength := _total_military_strength(player)
	var enemy_strength := _total_military_strength(opponent)
	var strength_advantage: float = clamp((own_strength - enemy_strength) / max(own_strength + enemy_strength, 1.0), -1.0, 1.0)
	var role_counts := _role_counts(player)

	var best_by_objective := {}
	var score_sum_by_objective := {}
	var score_count_by_objective := {}
	for city in candidates:
		for objective in WAR_OBJECTIVES:
			var score := _score_war_target(player, hex_grid, city, objective, strength_advantage, role_counts)
			score_sum_by_objective[objective] = score_sum_by_objective.get(objective, 0.0) + score
			score_count_by_objective[objective] = score_count_by_objective.get(objective, 0) + 1
			if not best_by_objective.has(objective) or score > best_by_objective[objective].score:
				best_by_objective[objective] = {"city": city, "coord": city.coord, "objective": objective, "score": score}

	var best = null
	var best_quality := -INF
	for objective in WAR_OBJECTIVES:
		if not best_by_objective.has(objective):
			continue
		var candidate_best: Dictionary = best_by_objective[objective]
		var avg_score: float = score_sum_by_objective[objective] / float(score_count_by_objective[objective])
		var quality := _war_objective_quality(candidate_best.score, objective, avg_score)
		if best == null or quality > best_quality:
			best = candidate_best
			best_quality = quality
	return best

## Avalia se vale abrir guerra contra `opponent` — so roda enquanto AINDA
## em paz (guerra ja em andamento nao precisa ser "decidida" de novo,
## ver Fase 2 do roadmap pra cansaco/encerramento) e so olha o MESMO
## oponente fixo que o resto de RivalAI usa (arquitetura de hoje: 1
## oponente por chamada — ver comentario de take_turn). Sem cidade
## inimiga JA CONHECIDA (PlayerData.known_enemy_cities), nao ha decisao
## nenhuma a tomar: um rival nunca declara guerra as cegas contra alguem
## que nunca viu.
##
## Roadmap "Parte C" C2 — antes escolhia so a cidade conhecida MAIS PERTO
## (_nearest_known_enemy_city, ainda existe, ainda usada por decide_trade);
## agora delega em _best_war_objective, que avalia TODAS as cidades
## conhecidas do oponente contra os dois tipos de objetivo (CONQUER,
## SECURE_RESOURCES) e escolhe o melhor par — "existe um objetivo concreto
## que justifica guerra e que eu tenho capacidade razoavel de perseguir?",
## nao mais so "tenho vontade de guerra?". Objetivo e sempre TRANSIENTE
## (recalculado aqui, nunca guardado em PlayerData/Diplomacy) — a unica
## visibilidade externa e o log do harness (test_simulation_balance.gd).
## O que acontece DEPOIS da guerra declarada (_choose_target/_engage) nao
## muda nada — o objetivo so afeta QUAL guerra e declarada e POR QUE, nunca
## a execucao militar em si (isso fica pra C3, ver decide_campaign abaixo,
## chamado sempre logo em seguida no mesmo loop de GameManager).
## Roadmap "Parte D" D2 — feedback de UI puramente aditivo: eventos de
## guerra/campanha/paz do rival so chegam ao jogador HUMANO. Checagem
## explicita (nao so uma suposicao de "opponent e sempre humano") de
## proposito — preserva a possibilidade futura de C2 ganhar rival-vs-rival
## sem a UI humana "ouvir" uma guerra que nao e dela. sfx_kind="" sempre:
## nao existe som dedicado pra diplomacia/campanha ainda (ver AudioManager.
## SFX_PATHS, so 6 kinds fixos) — inventar um sairia do escopo aditivo
## desta fatia.
static func _notify_human(opponent: PlayerData, text: String) -> void:
	if opponent != GameManager.human_player:
		return
	EventBus.notify.emit(text, "")

## --- Decisão de guerra (2026-10-15) ---------------------------------------------------------------------------------
## Pedido do usuário: "parecem tomar decisões aleatórias, como declarar guerra e um tempo depois pedir paz". O sorteio
## (WAR_DECLARE_CHANCE_WHEN_READY) saiu da decisão: a guerra agora segue um PLANO determinístico em três passos.
##   1. desejo = melhor objetivo (_best_war_objective, mesma fórmula de sempre) + pressão de Ritual público + memória
##      diplomática (DiplomaticMemory.hostility: rancor soma até +1, boa vontade tira até −1);
##   2. prontidão = desejo ≥ WAR_SCORE_THRESHOLD, exército mínimo (WAR_MIN_COMBAT_UNITS), força própria ≥
##      WAR_MIN_STRENGTH_RATIO da dele, não amistoso, e fora da espera depois da última paz com o MESMO reino
##      (WAR_RENEWAL_COOLDOWN_TURNS — rancor Hostil ou pior pula a espera);
##   3. preparação: pronto por WAR_PREPARATION_TURNS turnos seguidos (Hostil: WAR_PREPARATION_TURNS_HOSTILE). Nesse
##      meio-tempo a produção prioriza tropas (V2StrategicAI.war_production_pressure) e só então a guerra é declarada.
## O contador vive em DiplomaticMemory ("war_plan"), salvo com a memória. decide_war roda UMA vez por par por turno
## (GameManager._on_turn_changed), então cada chamada pronta conta um turno de preparação.
const WAR_PREPARATION_TURNS := 4
const WAR_PREPARATION_TURNS_HOSTILE := 2
const WAR_MIN_COMBAT_UNITS := 3
const WAR_RITUAL_MIN_COMBAT_UNITS := 2
const WAR_MIN_STRENGTH_RATIO := 0.75
const WAR_RENEWAL_COOLDOWN_TURNS := 25
## O aviso "estão reunindo tropas" sai no máximo uma vez a cada tantos turnos por par (a prontidão pode oscilar).
const WAR_WARNING_COOLDOWN_TURNS := 15

## {score, best, ritual, hostility, ready, block} — o que decide_war enxerga contra `opponent` agora. `block` = por que
## não está pronto ("" = pronto). Sem efeito colateral (exceto criar o registro de memória vazio).
## Supremacia (2026-10-15 — gargalo medido: "mediana de 0 capturas qualificadas" depois do Exército Supremo): com o
## acesso pesquisado e foco de Supremacia, todo rival ainda PENDENTE vira motivo de guerra — a condição exige tomar
## uma cidade de nível máximo de cada um. Soma SUPREMACY_WAR_PRESSURE ao desejo e passa por cima da amizade e da
## espera pós-paz (os outros freios — exército, força, preparação — continuam valendo).
const SUPREMACY_WAR_PRESSURE := 1.0

static func supremacy_target_against(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> Variant:
	if player.v2_ai_strategy.victory_focus != V2AIStrategyState.VictoryFocus.MILITARY_SUPREMACY:
		return null
	if not player.has_unlocked(V2VictoryConditions.MILITARY_SUPREMACY_ACCESS) or V2VictoryConditions.is_eliminated(opponent) or V2VictoryConditions.rival_satisfied_by_conquest(player, opponent):
		return null
	var targets := V2VictoryConditions.known_supremacy_targets(player, opponent, hex_grid)
	return targets[0].coord if not targets.is_empty() else null

static func war_readiness(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> Dictionary:
	var best = _best_war_objective(player, hex_grid, opponent)
	var ritual := V2StrategicAI.public_ritual_info_for(opponent)
	var hostility := DiplomaticMemory.hostility(player, opponent)
	var supremacy := supremacy_target_against(player, hex_grid, opponent) != null
	var score := (float(best.score) if best != null else 0.0) + V2StrategicAI.public_ritual_war_pressure(opponent) + hostility + (SUPREMACY_WAR_PRESSURE if supremacy else 0.0)
	var result := {"score": score, "best": best, "ritual": ritual, "hostility": hostility, "supremacy": supremacy, "ready": false, "block": ""}
	var level := DiplomaticMemory.level(player, opponent)
	var hostile := level == DiplomaticMemory.LEVEL_HOSTILE or level == DiplomaticMemory.LEVEL_SWORN
	if best == null and ritual.is_empty():
		result.block = "no_known_target"
	elif score < WAR_SCORE_THRESHOLD:
		result.block = "low_desire"
	elif V2StrategicAI.relevant_unit_count(player) < (WAR_RITUAL_MIN_COMBAT_UNITS if not ritual.is_empty() else WAR_MIN_COMBAT_UNITS):
		result.block = "small_army"
	elif ritual.is_empty() and _total_military_strength(player) < _total_military_strength(opponent) * WAR_MIN_STRENGTH_RATIO:
		result.block = "weaker"
	elif ritual.is_empty() and not supremacy and level == DiplomaticMemory.LEVEL_FRIENDLY:
		result.block = "friendly"
	elif ritual.is_empty() and not supremacy and not hostile and DiplomaticMemory.turns_since_peace(player, opponent) < WAR_RENEWAL_COOLDOWN_TURNS:
		result.block = "recent_peace"
	else:
		result.ready = true
	return result

## A IA está se preparando para guerra contra alguém (V2StrategicAI usa isso para priorizar tropas)?
static func is_preparing_war(player: PlayerData) -> bool:
	for other in player.diplomatic_memory:
		if int(player.diplomatic_memory[other].get("war_plan", 0)) > 0 and not player.is_at_war_with(other):
			return true
	return false

static func decide_war(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> void:
	if player.is_at_war_with(opponent) or not Diplomacy.can_declare_war(player, opponent):
		return
	var readiness := war_readiness(player, hex_grid, opponent)
	var plan := DiplomaticMemory.record(player, opponent)
	if not bool(readiness.ready):
		plan.war_plan = maxi(0, int(plan.war_plan) - 1)
		return
	plan.war_plan = int(plan.war_plan) + 1
	var level := DiplomaticMemory.level(player, opponent)
	var needed := WAR_PREPARATION_TURNS_HOSTILE if level in [DiplomaticMemory.LEVEL_HOSTILE, DiplomaticMemory.LEVEL_SWORN] else WAR_PREPARATION_TURNS
	if not readiness.ritual.is_empty():
		needed = 1 # Ritual público: cada rodada conta, não há tempo de preparar
	if int(plan.war_plan) == 1 and needed > 1 and TurnManager.turn_number - int(plan.get("war_warned", -999)) >= WAR_WARNING_COOLDOWN_TURNS:
		plan.war_warned = TurnManager.turn_number
		_notify_human(opponent, "%s está reunindo tropas e parece se preparar para uma guerra contra você." % player.civ.civ_name)
	if int(plan.war_plan) < needed:
		return
	var reason := _war_reason(player, opponent, readiness)
	if not readiness.ritual.is_empty():
		var ritual_site: Vector2i = readiness.ritual.site_coord
		player.known_enemy_cities[ritual_site] = true
	Diplomacy.declare_war(player, opponent, reason)
	_notify_human(opponent, "%s declarou guerra! Motivo: %s." % [player.civ.civ_name, reason])

## Motivo público da guerra, do fato mais forte para o mais fraco (aparece na Diplomacia e na notificação).
static func _war_reason(player: PlayerData, opponent: PlayerData, readiness: Dictionary) -> String:
	if not readiness.ritual.is_empty():
		return "Interromper ritual estratégico"
	if bool(readiness.get("supremacy", false)):
		return "Provar a supremacia militar"
	if DiplomaticMemory.value(player, opponent, DiplomaticMemory.CONQUEST) >= 20.0:
		return "Retomar as cidades perdidas"
	if DiplomaticMemory.value(player, opponent, DiplomaticMemory.AGGRESSION) + DiplomaticMemory.value(player, opponent, DiplomaticMemory.BETRAYAL) >= 20.0:
		return "Vingança por guerras passadas"
	if DiplomaticMemory.value(player, opponent, DiplomaticMemory.WARMONGER) >= 15.0:
		return "Conter um reino belicista"
	var best = readiness.best
	if best != null and best.objective == WAR_OBJECTIVE_SECURE_RESOURCES:
		return "Controlar os recursos de %s" % best.city.city_name
	return "Expansão territorial e recursos"

const CAMPAIGN_STATUS_ACTIVE := "active"
const CAMPAIGN_STATUS_COMPLETED := "completed"
const CAMPAIGN_STATUS_ABANDONED := "abandoned"
## Limiar de ABANDONO, deliberadamente MENOR que WAR_SCORE_THRESHOLD (limiar
## de DECLARACAO) -- metade exata, ponto de partida CALIBRAVEL (mesmo
## espirito de WAR_WEIGHT_ROLE_FIT), harness-validate-later.
##
## INVARIANTE PROVADA: 0.75 < 1.5 por construcao. _campaign_still_viable usa
## a MESMA formula ponderada (_score_war_target) que _best_war_objective/
## decide_war ja usam pra decidir declarar guerra -- logo, qualquer alvo cujo
## score ATUAL ainda bateria o limiar de declaracao (>=1.5) necessariamente
## bate o de abandono tambem (1.5 > 0.75): uma campanha NUNCA e abandonada
## enquanto seu alvo continuar tao atraente quanto no dia em que a guerra
## foi declarada por causa dele.
##
## RESSALVA: a margem (0.75) amortiza flutuacao PEQUENA (role_fit sozinho
## nunca swinga mais que WAR_WEIGHT_ROLE_FIT*1.0=0.3), mas NAO blinda contra
## reviravolta GRANDE e legitima (colapso do proprio exercito:
## strength_advantage pode swingar ate 2.0; alvo levantar Muralha:
## vulnerability swinga 1.0 sozinho) -- intencional, sao razoes REAIS pra
## reconsiderar uma campanha, nao ruido a esconder.
const CAMPAIGN_ABANDON_SCORE_THRESHOLD := WAR_SCORE_THRESHOLD * 0.5 # 0.75

## Cria/mantem/encerra a campanha de guerra contra `opponent` — memoria
## PERSISTENTE (PlayerData.war_campaigns), ao contrario de
## _best_war_objective (C2, sempre transiente). Chamado 1x por rival por
## turno, logo apos decide_war, no mesmo loop de GameManager.
## _on_turn_changed — assim uma guerra recem-declarada ja tem campanha
## antes de qualquer unidade agir no mesmo turno. Defasagem de UM turno pra
## observar captura de combate (mesma defasagem que ja existe entre
## decide_war e _choose_target/_engage): uma captura que acontece no
## combate DESTE turno so e vista por _advance_campaign no PROXIMO.
static func decide_campaign(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> void:
	var campaign: Dictionary = player.war_campaigns.get(opponent, {})
	if campaign.get("status", "") == CAMPAIGN_STATUS_ACTIVE:
		_advance_campaign(player, hex_grid, opponent)
	elif player.is_at_war_with(opponent):
		_start_campaign(player, hex_grid, opponent)

## MESMO limiar de decide_war (WAR_SCORE_THRESHOLD) -- nunca cria campanha
## mais fraca do que o que justificaria declarar guerra do zero hoje. Chamada
## tanto pra abrir a PRIMEIRA campanha quanto pra iniciar uma nova INSTANCIA
## independente depois de uma anterior terminar (COMPLETED ou ABANDONED,
## ver decide_campaign) — objetivo cumprido nao implica fim de guerra (esta
## fatia nao mexe em Diplomacy.gd), entao a guerra pode continuar e uma nova
## campanha nascer contra outro alvo no turno seguinte.
static func _start_campaign(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> void:
	# Supremacia (2026-10-15): a campanha mira a cidade que FECHA a condição (maior nível conhecido do rival), não a
	# mais conveniente — senão a IA conquistava a cidade errada e a Supremacia nunca saía.
	var supremacy_coord = supremacy_target_against(player, hex_grid, opponent)
	if supremacy_coord != null:
		var city := hex_grid.get_city_at(supremacy_coord)
		player.war_campaigns[opponent] = {"objective": WAR_OBJECTIVE_CONQUER, "target_coord": supremacy_coord, "status": CAMPAIGN_STATUS_ACTIVE}
		_notify_human(opponent, _campaign_start_message(player, WAR_OBJECTIVE_CONQUER, city))
		return
	var best = _best_war_objective(player, hex_grid, opponent)
	if best == null or best.score < WAR_SCORE_THRESHOLD:
		return
	player.war_campaigns[opponent] = {
		"objective": best.objective,
		"target_coord": best.coord,
		"status": CAMPAIGN_STATUS_ACTIVE,
	}
	_notify_human(opponent, _campaign_start_message(player, best.objective, best.city))

## Roadmap "Parte D" D2 — traduz objetivo tecnico (WAR_OBJECTIVE_*) pra
## linguagem de jogo, sem expor "secure_resources"/target_coord ao jogador.
static func _campaign_start_message(player: PlayerData, objective: String, target_city: City) -> String:
	if objective == WAR_OBJECTIVE_SECURE_RESOURCES:
		return "%s iniciou uma campanha para controlar os recursos de %s." % [player.civ.civ_name, target_city.city_name]
	return "%s iniciou uma campanha para conquistar %s." % [player.civ.civ_name, target_city.city_name]

## Roadmap "Parte D" D2 — um so lugar pro texto de abandono, chamado dos
## DOIS pontos de _advance_campaign que levam a CAMPAIGN_STATUS_ABANDONED
## (invalidado sem substituto, ou inviavel) — o toast nao distingue qual
## dos dois motivos foi, detalhe de implementacao que nao interessa ao
## jogador.
static func _notify_campaign_abandoned(player: PlayerData, opponent: PlayerData) -> void:
	_notify_human(opponent, "%s abandonou sua campanha contra %s." % [player.civ.civ_name, opponent.civ.civ_name])

## Roadmap "Parte E" E1 -- ponte entre Diplomacy (paz) e war_campaigns
## (C3/C4), fechando a LACUNA CONHECIDA documentada em
## _choose_campaign_target e em decide_peace (ver abaixo): paz resolvida
## agora invalida QUALQUER campanha ACTIVE entre as duas civs, nas DUAS
## direcoes. Transicao EXPLICITA ACTIVE -> ABANDONED -- nunca passa por
## _advance_campaign (sem reavaliar objetivo, sem RNG, sem retarget: a paz
## sozinha ja e motivo suficiente pra abandonar, independente de qualquer
## pontuacao de guerra). Chamada de Diplomacy.propose_peace() logo apos a
## paz ser efetivada -- UNICO ponto de entrada, cobre humano->rival (HUD)
## e rival->humano (decide_peace) sem duplicar esta logica em nenhum
## chamador.
static func end_campaigns_on_peace(a: PlayerData, b: PlayerData) -> void:
	_abandon_campaign_if_active(a, b)
	_abandon_campaign_if_active(b, a)

static func _abandon_campaign_if_active(player: PlayerData, opponent: PlayerData) -> void:
	var campaign: Dictionary = player.war_campaigns.get(opponent, {})
	if campaign.get("status", "") != CAMPAIGN_STATUS_ACTIVE:
		return
	campaign.status = CAMPAIGN_STATUS_ABANDONED
	_notify_campaign_abandoned(player, opponent)

## Persistencia e o padrao -- nenhum ramo troca de alvo so porque outro
## candidato parece melhor agora (isso seria troca oportunista, proibida).
## So reavalia quando o alvo em si fica invalido (capturado por QUALQUER UM,
## ou sumiu) ou deixa de ser viavel (_campaign_still_viable).
static func _advance_campaign(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> void:
	var campaign: Dictionary = player.war_campaigns[opponent]
	var target_coord: Vector2i = campaign.target_coord
	var target_city := hex_grid.get_city_at(target_coord)
	var owner: PlayerData = target_city.owner_player if target_city else null

	if owner == player:
		campaign.status = CAMPAIGN_STATUS_COMPLETED
		_notify_human(opponent, "%s concluiu sua campanha contra %s." % [player.civ.civ_name, opponent.civ.civ_name])
		return

	if owner != opponent:
		# Alvo invalidado -- cidade sumiu, ou capturada por um TERCEIRO (nem
		# player nem opponent -- so pode acontecer se outro rival tambem em
		# guerra com opponent chegou primeiro, ver Diplomacy.gd: rivais
		# nunca guerreiam entre si). Reavalia do zero, MESMO limiar de
		# _start_campaign.
		var best = _best_war_objective(player, hex_grid, opponent)
		if best == null or best.score < WAR_SCORE_THRESHOLD:
			campaign.status = CAMPAIGN_STATUS_ABANDONED
			_notify_campaign_abandoned(player, opponent)
		else:
			campaign.objective = best.objective
			campaign.target_coord = best.coord
		return

	# Alvo de Supremacia não é "abandonável" por pontuação: é a cidade que a vitória exige (sem isto, abandonar e
	# recriar a mesma campanha a cada turno).
	if supremacy_target_against(player, hex_grid, opponent) == target_coord:
		return
	if not _campaign_still_viable(player, hex_grid, opponent, target_city, campaign.objective):
		campaign.status = CAMPAIGN_STATUS_ABANDONED
		_notify_campaign_abandoned(player, opponent)
	# senao: nada muda -- mantem alvo/objetivo.

## "Ainda vale perseguir?" -- reusa a MESMA formula ponderada de
## _score_war_target (nao inventa uma paralela), avaliada so pro alvo/
## objetivo JA escolhido (nunca varre outros candidatos -- isso seria troca
## oportunista). Ver prova numerica no comentario de
## CAMPAIGN_ABANDON_SCORE_THRESHOLD.
static func _campaign_still_viable(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData, target_city: City, objective: String) -> bool:
	var own_strength := _total_military_strength(player)
	var enemy_strength := _total_military_strength(opponent)
	var strength_advantage: float = clamp((own_strength - enemy_strength) / max(own_strength + enemy_strength, 1.0), -1.0, 1.0)
	var role_counts := _role_counts(player)
	var score := _score_war_target(player, hex_grid, target_city, objective, strength_advantage, role_counts)
	return score >= CAMPAIGN_ABANDON_SCORE_THRESHOLD

## "Existe uma preferencia ESTRATEGICA pra este oponente agora?" Retorna o
## target_coord da campanha ATIVA, ou null. Consumida taticamente desde
## Roadmap "Parte C" C4 via _campaign_attack_target (que soma a checagem de
## frescor que esta funcao nao faz sozinha) — ver _handle_attacker.
##
## RESOLVIDO no Roadmap "Parte E" E1 (Diplomacy.propose_peace chama
## RivalAI.end_campaigns_on_peace logo apos aplicar a paz): uma paz aceita
## agora forca ACTIVE -> ABANDONED nas duas direcoes ANTES do proximo
## decide_campaign/_campaign_attack_target rodar, entao esta funcao nunca
## mais devolve o target_coord de uma campanha contra um oponente em paz.
## Ficava documentado aqui como LACUNA CONHECIDA desde C4 -- historico
## mantido pra quem vier depois entender POR QUE end_campaigns_on_peace
## existe.
static func _choose_campaign_target(player: PlayerData, opponent: PlayerData):
	var campaign: Dictionary = player.war_campaigns.get(opponent, {})
	if campaign.get("status", "") != CAMPAIGN_STATUS_ACTIVE:
		return null
	return campaign.target_coord

## Roadmap "Parte C" C4 — resolve o target_coord da campanha ATIVA pra uso
## TATICO. Diferente de _choose_campaign_target, que so devolve o coord cru:
## aqui confirma que o coord AINDA corresponde a uma cidade de verdade do
## `opponent` agora mesmo -- o status da campanha so e reavaliado 1x por
## turno em decide_campaign/_advance_campaign, mas o mundo pode ja ter
## mudado dentro do MESMO turno (ex: outra unidade capturou o alvo mais
## cedo na mesma passada de execucao, especialmente no caminho escalonado —
## ver GameManager._process()/stagger_ai_turns, que drena uma unidade por
## vez). Devolve null se nao ha campanha ativa OU se o alvo guardado ja nao
## e uma cidade do oponente.
static func _campaign_attack_target(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData):
	var target_coord = _choose_campaign_target(player, opponent)
	if target_coord == null:
		return null
	var target_city := hex_grid.get_city_at(target_coord)
	if target_city == null or target_city.owner_player != opponent:
		return null
	return target_coord

## FRONTEIRAS ABERTAS — a IA também pede (Diplomacy.request_open_borders): a `other` que já tem cidade de fronteira
## fechada, de tempos em tempos, e só o que ela mesma concederia (a mesma regra com que responde). Cadência fixa por
## par, sem RNG (não perturba a sequência de sorteios da IA). Devolve o resultado do pedido, ou "" se nem pediu.
const OPEN_BORDERS_REQUEST_INTERVAL := 12

static func decide_open_borders(player: PlayerData, other: PlayerData) -> String:
	if player == null or other == null or player == other or player.cities.is_empty():
		return ""
	var a := GameManager.players.find(player)
	var b := GameManager.players.find(other)
	if a < 0 or b < 0 or posmod(TurnManager.turn_number + a * 5 + b * 3, OPEN_BORDERS_REQUEST_INTERVAL) != 0:
		return ""
	var has_closed_city := false
	for city in other.cities:
		if city.city_level >= HexGrid.CLOSED_BORDERS_FROM_LEVEL:
			has_closed_city = true
			break
	if not has_closed_city or not Diplomacy.can_request_open_borders(player, other):
		return ""
	if Diplomacy.open_borders_refusal_reason(player, other) != "":
		return ""
	return Diplomacy.request_open_borders(player, other)

const PEACE_DECISION_NOT_AT_WAR := "not_at_war"
const PEACE_DECISION_BELOW_THRESHOLD := "below_threshold"
const PEACE_DECISION_ACCEPTED := "accepted"
const PEACE_DECISION_REFUSED := "refused"
## O oponente e o jogador humano: a proposta ficou PENDENTE da resposta dele (Diplomacy.offer_peace) — a guerra
## continua ate ele aceitar no modal.
const PEACE_DECISION_OFFERED := "offered"
## Quer paz, mas nao pode propor agora: ja ha uma proposta sem resposta, ou o humano recusou ha pouco
## (Diplomacy.PEACE_OFFER_COOLDOWN_TURNS).
const PEACE_DECISION_WAITING := "waiting"
## Limiar de OFERTA de paz (Roadmap "Parte D", D1) — distinto de Diplomacy.
## WAR_WEARINESS_ACCEPTS_PEACE_THRESHOLD (40.0, "aceito SE me propuserem").
## Deliberadamente MAIOR: "estou cansado o bastante pra tomar a iniciativa"
## e uma barra mais alta que "aceito se pedirem" — sem essa assimetria, uma
## guerra entraria num ciclo de proposta/aceite assim que os dois lados
## cruzassem o MESMO limiar. Ponto de partida observavel via harness, nao
## calibrado (mesmo espirito de WAR_WEIGHT_ROLE_FIT/CAMPAIGN_ABANDON_
## SCORE_THRESHOLD).
const WAR_WEARINESS_OFFER_PEACE_THRESHOLD := 60.0

## Roadmap "Parte D" D1 — encerramento autonomo de guerra. So considera o
## humano como oponente (mesmo escopo de decide_war/decide_campaign: rivais
## nunca guerreiam entre si, ver Diplomacy.gd). Deliberadamente simples
## nesta fatia: so desgaste de guerra (war_weariness, ja existente e ja
## atualizado por Diplomacy.process_war_weariness_and_upkeep), sem segunda
## dimensao de "incapaz estrategicamente" ainda.
##
## Diplomacy._accepts_peace() NUNCA e tocado — continua significando so
## "aceito uma proposta que recebi", nunca "eu decido propor".
##
## Entre IAs, a recusa da proposta (Diplomacy.propose_peace -> _accepts_peace)
## e um resultado NORMAL, nao um erro: guerra continua, nenhum estado novo
## criado, tenta de novo no proximo turno se o desgaste continuar alto.
##
## Contra o JOGADOR HUMANO (2026-10-10) ninguem responde por ele: a proposta
## fica PENDENTE (Diplomacy.offer_peace, PEACE_DECISION_OFFERED) ate ele
## aceitar ou recusar no modal (PeaceOfferPresenter). Enquanto ela esta sem
## resposta, ou durante a espera depois de uma recusa
## (Diplomacy.PEACE_OFFER_COOLDOWN_TURNS), isto devolve PEACE_DECISION_WAITING
## em vez de propor de novo.
##
## Ate o Roadmap "Parte E" E1, esta funcao NUNCA mexia em war_campaigns por
## conta propria (campanha e guerra eram conceitos separados desde C3).
## Desde E1, decide_peace herda esse efeito de graca via
## Diplomacy.propose_peace() (que agora chama RivalAI.end_campaigns_on_peace
## internamente): uma paz aceita aqui TAMBEM abandona qualquer campanha
## ACTIVE entre os dois lados, sem decide_peace precisar saber disso -- um
## so ponto de verdade, ver end_campaigns_on_peace. Uma campanha ja
## COMPLETED/ABANDONED continua sem impedir nem exigir a decisao de paz.
##
## Retorna um dos PEACE_DECISION_* acima — valor TRANSIENTE (nunca guardado
## em PlayerData), so pra quem chamou (harness/testes) poder observar o que
## aconteceu sem precisar reconstruir isso a partir de efeito colateral.
## 2026-10-15 — oferecer paz deixou de ser "cansaço ≥ 60" (que fazia a IA pedir paz pouco depois de declarar, ganhando
## ou perdendo). Agora oferece quando wants_peace: ela mesma aceitaria a paz (Diplomacy.peace_outlook do PRÓPRIO lado:
## cansaço, força, rancor) e a guerra já durou PEACE_OFFER_MIN_WAR_TURNS — ou está perdendo feio (força abaixo de
## PEACE_LOSING_STRENGTH_RATIO da dele). Uma campanha ativa e ainda viável segura a oferta até o cansaço chegar a
## WAR_WEARINESS_OFFER_PEACE_THRESHOLD: ninguém pede paz no meio de um cerco que está dando certo.
const PEACE_OFFER_MIN_WAR_TURNS := 12
const PEACE_LOSING_STRENGTH_RATIO := 0.5

static func wants_peace(player: PlayerData, opponent: PlayerData) -> bool:
	var own := _total_military_strength(player)
	var theirs := _total_military_strength(opponent)
	if theirs > 0.0 and own < theirs * PEACE_LOSING_STRENGTH_RATIO:
		return true
	if player.cities.is_empty() and V2VictoryConditions.has_fallen(player):
		return true # perdeu todas as cidades: continuar a guerra só termina em eliminação
	if DiplomaticMemory.record(player, opponent).get("war_start", -1) >= 0 and DiplomaticMemory.turns_at_war(player, opponent) < PEACE_OFFER_MIN_WAR_TURNS:
		return false
	if not bool(Diplomacy.peace_outlook(player, opponent).accept):
		return false
	var campaign: Dictionary = player.war_campaigns.get(opponent, {})
	if campaign.get("status", "") == CAMPAIGN_STATUS_ACTIVE and player.war_weariness < WAR_WEARINESS_OFFER_PEACE_THRESHOLD and GameManager.hex_grid != null:
		var target := GameManager.hex_grid.get_city_at(campaign.target_coord)
		if target != null and target.owner_player == opponent and _campaign_still_viable(player, GameManager.hex_grid, opponent, target, campaign.objective):
			return false
	return true

static func decide_peace(player: PlayerData, opponent: PlayerData) -> String:
	if not player.is_at_war_with(opponent):
		return PEACE_DECISION_NOT_AT_WAR
	if not wants_peace(player, opponent):
		return PEACE_DECISION_BELOW_THRESHOLD
	# O jogador humano responde por conta propria (modal Aceitar/Recusar): nada de heuristica decidindo por ele.
	if GameManager.is_human_controlled(opponent):
		return PEACE_DECISION_OFFERED if Diplomacy.offer_peace(player, opponent) else PEACE_DECISION_WAITING
	if Diplomacy.propose_peace(player, opponent):
		_notify_human(opponent, "%s propôs paz e ela foi aceita." % player.civ.civ_name)
		return PEACE_DECISION_ACCEPTED
	_notify_human(opponent, "%s propôs paz, mas ela foi recusada." % player.civ.civ_name)
	return PEACE_DECISION_REFUSED

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
		if unit == null or not is_instance_valid(unit):
			continue
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

## Roadmap "Fase Macro" 5B.2 -- decisao MINIMA/provisoria de participacao
## em eventos mundiais (docs/DRAGON_EVENT_DESIGN.md): SEMPRE participa,
## uma unica vez por evento, assim que ele entra em Preparation. Regra de
## verdade (avaliar risco, forca militar propria, recompensa esperada)
## fica pra depois de jogarmos com o vertical slice minimo -- decisao
## explicita do usuario: nao calibrar antes de existir algo jogavel.
## Generica por proposito (opera sobre WorldEvent/participants, nunca sabe
## que "event" e' especificamente um DragonEvent) -- contrato, principio
## "eventos operam sobre civilizacoes", nao sobre um tipo de evento so.
static func decide_world_event_participation(player: PlayerData, civ_index: int, event: WorldEvent) -> void:
	if event.phase != WorldEvent.PHASE_PREPARATION:
		return
	if event.participants.has(civ_index):
		return
	# Fase 33D3: a civ-alvo do Dragão sempre entra em defesa; as outras DECIDEM (V2StrategicAI.dragon_participation).
	if event is DragonEvent:
		var view := V2AITacticalAI.view_for(player, GameManager.hex_grid)
		var decision := V2StrategicAI.dragon_participation(player, civ_index, event as DragonEvent, view)
		event.participants[civ_index] = {"decision": bool(decision.join), "reason": String(decision.reason)}
		return
	event.participants[civ_index] = {"decision": true}

## Fase 33D3 — civ participante (não-alvo) com o Dragão ativo: até DRAGON_HUNT_MAX_UNITS unidades aptas mais
## próximas dele (dentro de DRAGON_HUNT_RADIUS) vão caçá-lo por movimento normal; guarnição em guerra fica.
const DRAGON_HUNT_MAX_UNITS := 3
const DRAGON_HUNT_RADIUS := 16

static func join_dragon_hunt(player: PlayerData, hex_grid: HexGrid, dragon_unit: Unit) -> void:
	if dragon_unit == null or not is_instance_valid(dragon_unit):
		return
	var hunters: Array[Unit] = []
	for unit in player.units:
		if V2StrategicAI.is_lair_responder(unit) and HexMetrics.axial_distance(unit.coord, dragon_unit.coord) <= DRAGON_HUNT_RADIUS and not StrategicAI._is_needed_garrison(unit, player):
			hunters.append(unit)
	hunters.sort_custom(func(a: Unit, b: Unit) -> bool:
		var da := HexMetrics.axial_distance(a.coord, dragon_unit.coord)
		var db := HexMetrics.axial_distance(b.coord, dragon_unit.coord)
		return da < db if da != db else a.serial_id < b.serial_id)
	for unit in hunters.slice(0, DRAGON_HUNT_MAX_UNITS):
		if is_instance_valid(unit) and is_instance_valid(dragon_unit) and dragon_unit.hp > 0.0:
			react_to_dragon(unit, hex_grid, dragon_unit)

## Roadmap "Fase Macro" 5B.3-G, "interceptacao real" -- Unit -> CombatResolver
## -> Dragon Unit, reusando move_unit_toward/is_favorable_attack EXATAMENTE
## como _handle_attacker/_engage ja fazem contra `opponent` (o Dragao nao e'
## "outro opponent" pro sistema de guerra -- Diplomacy/is_at_war_with nunca
## soube de monstro nenhum, entao isto fica deliberadamente FORA de
## act_for_unit/_handle_attacker, nunca misturado com a logica de guerra
## contra o jogador humano). Mesma regra de retirada (RETREAT_HP_FRACTION)
## de sempre -- o Dragao continua podendo matar o defensor. 5B.3-G v2: o
## corte por PERCEPTION_RANGE foi removido -- quem chama (defend_against_
## dragon) ja decidiu que a CIDADE deste defensor esta sob ataque antes de
## chamar esta funcao, entao redundar essa checagem aqui so' fazia o
## defensor desistir de perseguir o Dragao quando ele estava perto da
## cidade mas longe da unidade especifica (exatamente o "toma 0 de dano"
## relatado).
##
## is_favorable_attack REMOVIDO tambem (pedido explicito do usuario apos
## novo playtest: "as tropas nao conseguem causar dano... ficam ao redor
## do dragao mas nao atacam"). Causa real: um Guarda basico (attack 4,
## defense 3) contra o Dragao (attack 16, defense 8) SEMPRE reprova em
## is_favorable_attack (perde ~25% do proprio HP de contra-ataque contra
## so' ~2% de dano causado) -- a mesma regra que evita um rival desperdicar
## tropas numa guerra normal contra o jogador aqui simplesmente BLOQUEAVA
## todo ataque, sempre, pra sempre (o defensor chegava ao alcance e so'
## ficava parado). Uma guarnicao defendendo a propria cidade do Dragao
## precisa lutar mesmo em desvantagem -- e' o proprio ponto de "forcar
## reacao militar" (docs/DRAGON_EVENT_DESIGN.md) -- RETREAT_HP_FRACTION
## continua sendo o unico limite (foge quando malferido, nunca luta ate' a
## morte certa repetidamente).
static func react_to_dragon(unit: Unit, hex_grid: HexGrid, dragon_unit: Unit) -> void:
	if V2ManifestationOrders.is_bound(unit):
		V2ManifestationOrders.assign(unit, V2ManifestationOrders.ATTACK_UNIT, dragon_unit.coord, hex_grid)
		return
	if unit.unit_data.attack <= 0.0 or unit.hp < unit.unit_data.max_hp * RETREAT_HP_FRACTION:
		return
	if dragon_unit.coord in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range):
		CombatResolver.resolve(unit, dragon_unit, hex_grid)
		return
	move_unit_toward(unit, hex_grid, dragon_unit.coord)

## PROVISORIO/NAO CALIBRADO -- distancia (cidade -> Dragao) abaixo da qual
## uma cidade e' considerada "sob ataque" pro proposito de mobilizar a
## propria guarnicao (pedido explicito do usuario apos playtest: "quando a
## cidade esta sob ataque do dragao, ela direciona suas tropas pro
## dragao"). Acima disso, tropas voltam a guarnecer a cidade (garrison).
const DRAGON_CITY_AGGRO_RADIUS := 5
## PROVISORIO/NAO CALIBRADO -- distancia (unidade -> cidade) considerada
## "ja de volta guarnecendo" -- nao precisa terminar EXATAMENTE em cima da
## cidade, so' perto o suficiente pra reagir rapido na proxima aproximacao.
const GARRISON_RETURN_RADIUS := 2

## Roadmap 5B.3-G v2 -- pedido explicito do usuario apos o playtest dele
## proprio: "as tropas ficam apenas paradas, no maximo uma que tiver do
## lado do dragao ataca, mas as outras ficam paradas tomando de longe...
## quando a cidade esta sob ataque, direcione TODAS as tropas pro
## dragao... quando o dragao sai do agro as tropas retornam pra guarnecer
## a cidade". Substitui a v1 (so' 1 unidade GLOBAL mais proxima por turno)
## por uma decisao POR CIDADE: toda unidade militar reage ou guarnece
## baseada na cidade mais proxima DELA (nao ha um campo "unidade pertence a
## cidade X" no jogo -- "mais proxima agora" e' a mesma aproximacao
## deterministica-por-distancia ja usada no resto do arquivo). Cidade
## dentro de DRAGON_CITY_AGGRO_RADIUS do Dragao -> toda unidade daquela
## vizinhanca ataca; caso contrario, volta a guarnecer (GARRISON_RETURN_
## RADIUS) se ainda nao estiver perto o suficiente.
static func defend_against_dragon(player: PlayerData, hex_grid: HexGrid, dragon_unit: Unit) -> void:
	if dragon_unit == null or not is_instance_valid(dragon_unit):
		return
	for unit in player.units:
		if V2ManifestationOrders.is_bound(unit):
			var ward := _nearest_own_city(player, unit.coord)
			if ward != null: V2ManifestationOrders.assign(unit, V2ManifestationOrders.PROTECT_CITY, ward.coord, hex_grid)
			continue
		if unit.unit_data.attack <= 0.0 or unit.hp < unit.unit_data.max_hp * RETREAT_HP_FRACTION:
			continue
		var nearest_city := _nearest_own_city(player, unit.coord)
		if nearest_city == null:
			continue
		if HexMetrics.axial_distance(nearest_city.coord, dragon_unit.coord) <= DRAGON_CITY_AGGRO_RADIUS:
			react_to_dragon(unit, hex_grid, dragon_unit)
		elif HexMetrics.axial_distance(unit.coord, nearest_city.coord) > GARRISON_RETURN_RADIUS:
			move_unit_toward(unit, hex_grid, nearest_city.coord)

static func _nearest_own_city(player: PlayerData, from: Vector2i) -> City:
	var best: City = null
	var best_dist := INF
	for city in player.cities:
		var distance: float = HexMetrics.axial_distance(from, city.coord)
		if distance < best_dist:
			best_dist = distance
			best = city
	return best

## So a parte de "preparar" o turno da IA (visibilidade atual + atualizar
## cidades inimigas escoutadas), SEM mover nenhuma unidade ainda — extraido
## de take_turn() pra GameManager poder chamar isto UMA VEZ por rival e
## depois processar as unidades dela aos poucos, em frames diferentes (ver
## GameManager._build_rival_turn_items/stagger_ai_turns, pedido do
## usuario: "civilization nao faz tudo acontecer no mapa ao mesmo
## tempo... em pequenos grupos... diminui o lag na passada de turnos").
static func begin_turn(player: PlayerData, hex_grid: HexGrid, opponent: PlayerData) -> Dictionary:
	var visible := hex_grid.compute_visible_tiles(player)
	player.explored_tiles.merge(visible, true)
	for other in GameManager.players:
		if other != player:
			_scout_enemy_cities(player, other, visible)
	_scout_enemy_cities(player, opponent, visible)
	V2AITacticalAI.prepare_turn(player, hex_grid)
	return visible

## Acao de UMA unidade rival — extraida de take_turn() pelo mesmo motivo de
## begin_turn() acima, pra poder ser chamada unidade-por-unidade em frames
## diferentes.
static func act_for_unit(unit: Unit, hex_grid: HexGrid, player: PlayerData, opponent: PlayerData, visible: Dictionary) -> void:
	if V2ManifestationOrders.is_bound(unit):
		V2ManifestationOrders.choose_ai_order(unit, hex_grid, visible)
		V2ManifestationOrders.act(unit, hex_grid, visible)
		return
	if unit.movement_left <= 0.0 or unit.hp <= 0.0:
		return
	# V3 / Etapa 2: perigo de criatura CONHECIDO (infecção/raiz explorada, Rastro Subterrâneo visível) — sai antes de agir.
	if MonsterHazardSystem.ai_evade(unit, hex_grid, visible):
		return
	# Técnicas, feitiços, Portais, Construtor e movimento especial (V2AITacticalAI) antes da ação comum.
	if V2AITacticalAI.take_special_action(unit, player, hex_grid):
		return
	if unit.unit_data.can_found_city:
		_handle_settler(unit, hex_grid, player)
	elif unit.unit_data.attack <= 0.0:
		StrategicAI.move_support(unit, player, hex_grid)
	elif unit.unit_data.attack > 0.0:
		AIWarTactics.update_recovery(unit)
		if StrategicAI.engage_nearby_monster(unit, player, hex_grid, visible):
			return
		# 2026-10-15 — exército de OUTRA civilização perto de uma cidade própria: quem está perto volta e luta
		# (CityDefense só cobria monstros). Antes da defesa contra monstro: um cerco tira cidades, um goblin não.
		if AIWarTactics.defend_against_invaders(unit, player, hex_grid, visible):
			return
		# Task 21 -- monstro ameacando uma cidade propria: guarnicao sai ao
		# encontro / reforco proporcional (ver CityDefense.defend_turn).
		if CityDefense.defend_turn(unit, player, hex_grid, visible):
			return
		# Fase 33D2 — covil conhecido perto do reino (ameaça regional/Guardião) com força local suficiente.
		if StrategicAI.respond_to_lair(unit, player, hex_grid):
			return
		opponent = StrategicAI.choose_opponent(player, hex_grid, opponent)
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
			player.remember_enemy_city(city)

## Roadmap "Parte C" C4 — uma campanha ATIVA (ver _campaign_attack_target)
## vira a prioridade tatica: tenta o alvo estrategico primeiro, so cai pro
## _choose_target generico (intocado, nunca sabe que campanha existe) se
## nao ha campanha, ela esta terminal, ou o alvo guardado ja nao e uma
## cidade do oponente. Alvo de campanha valido mas fora de PERCEPTION_RANGE
## desta unidade especifica NAO cai pro _choose_target como segunda
## tentativa -- decisao deliberada (aprovada): o resto da funcao (checagem
## de alcance/escolta/movimento abaixo) e identico ao caminho sem campanha,
## entao a unidade so fica parada esse turno, exatamente como ja acontecia
## quando _choose_target sozinho escolhia algo longe demais.
## 2026-10-15 (AIWarTactics): recuo com histerese, melhor golpe do tile atual (foco de fogo), exército que espera o
## grupo em campanha, unidade à distância que se posiciona no alcance (sem escolta, recua até a linha) e ataque
## depois de andar. A ESCOLHA do alvo de marcha continua a mesma de sempre (Ritual → campanha → _choose_target).
static func _handle_attacker(unit: Unit, hex_grid: HexGrid, player: PlayerData, opponent: PlayerData, visible: Dictionary) -> void:
	if AIWarTactics.update_recovery(unit):
		var start := unit.coord
		if not AIWarTactics.retreat(unit, player, hex_grid, visible):
			_retreat(unit, hex_grid, player)
		if is_instance_valid(unit) and unit.coord == start:
			_hold_position(unit, hex_grid)
		return

	# Um Ritual Final público de rival tem prioridade sobre a campanha (substitui o antigo
	# contra-ritual da magia V1); depois a campanha validada e, por fim, o alvo tático.
	var target_coord = V2StrategicAI.public_ritual_target_coord(V2AITacticalAI.view_for(player, hex_grid))
	var strategic := target_coord != null
	if target_coord == null:
		target_coord = _campaign_attack_target(player, hex_grid, opponent)
		strategic = target_coord != null
	if target_coord == null:
		target_coord = _choose_target(unit, hex_grid, player, opponent, visible)

	# O golpe mais útil daqui (pode não ser o alvo de marcha: um inimigo ferido ao lado vale mais); empate fica com ele.
	if AIWarTactics.try_strike(unit, player, hex_grid, visible, target_coord):
		return
	if target_coord == null:
		# Sem alvo: os batedores designados exploram, o resto guarnece as cidades (AIWarTactics.take_post).
		if AIWarTactics.is_designated_scout(unit, player) or not AIWarTactics.take_post(unit, player, hex_grid):
			unit.fortified = false # Explorar não anda fortificado (StrategicAI.explore)
			StrategicAI.explore(unit, player, hex_grid)
		return
	# Já no alcance do alvo e nenhum golpe valeu a pena (troca ruim): segura a posição em vez de dançar ao redor.
	if target_coord in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range) and not unit.embarked:
		_hold_position(unit, hex_grid)
		return
	if strategic and AIWarTactics.should_hold_for_group(unit, player, target_coord):
		_hold_position(unit, hex_grid)
		return

	if unit.unit_data.attack_range > 1:
		if not _has_melee_escort_nearby(unit, player):
			AIWarTactics.fall_back_to_line(unit, player, hex_grid)
			return
		AIWarTactics.move_ranged(unit, player, hex_grid, visible, target_coord)
	else:
		move_unit_toward(unit, hex_grid, target_coord)
	AIWarTactics.strike_after_move(unit, player, hex_grid, visible, target_coord)

## Parada de propósito (esperando o grupo, curando fora da cidade, guarnição): Fortificar — a mesma ordem do jogador,
## que dá Defesa e cura passiva fora da cidade. A IA nunca fortificava, então tropa ferida fora de cidade nunca curava.
static func _hold_position(unit: Unit, _hex_grid: HexGrid) -> void:
	if not is_instance_valid(unit) or unit.embarked or unit.fortified:
		return
	unit.fortified = true
	unit.exploring = false

## Ataca so se o combate parecer favoravel; cidade indefesa e sempre um
## alvo valido pra ATACAR (sem risco pro atacante — cidade nao contra-
## ataca) — mas nao captura mais num unico golpe, ver CombatResolver.
## resolve_city_attack (desconta do escudo/vida da cidade, pode levar
## varios turnos ate a vida zerar e capturar de verdade).
static func _engage(unit: Unit, hex_grid: HexGrid, target_coord: Vector2i) -> void:
	var defender = hex_grid.get_unit_at(target_coord)
	var city = hex_grid.get_city_at(target_coord)
	# Tropa em cima de uma cidade (guarnição): a IA escolhe o alvo como o jogador (2026-10-13). Toma a cidade se este
	# golpe a captura; senão luta com a guarnição quando o combate é favorável; senão bate na cidade, que não revida —
	# uma guarnição forte não serve mais de escudo para a cidade.
	var city_is_target: bool = city != null and CombatResolver.can_attack_city(unit, city)
	if defender:
		if city_is_target and bool(CombatResolver.predict_city_attack(unit, city).captures):
			CombatResolver.resolve_city_attack(unit, city, hex_grid)
		elif is_favorable_attack(unit, defender, hex_grid):
			CombatResolver.resolve(unit, defender, hex_grid)
		elif city_is_target:
			CombatResolver.resolve_city_attack(unit, city, hex_grid)
		return
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
	if unit.movement_left <= 0 or unit.coord == target_coord:
		return
	# Sair do lugar desfaz o Fortificar (mesma regra das ordens de movimento do jogador, SelectionManager).
	unit.fortified = false
	var destinations: Array[Vector2i] = [target_coord]
	if hex_grid.get_unit_at(target_coord) != null or (hex_grid.get_city_at(target_coord) != null and hex_grid.get_city_at(target_coord).owner_player != unit.owner_player):
		destinations = hex_grid.get_neighbors(target_coord)
	# Embarque automático: para se aproximar de um alvo ocupado, a casa vizinha em TERRA vem antes da água (embarcado não
	# ataca), e só depois a distância.
	destinations.sort_custom(func(a, b):
		var water_a := _ends_embarked(unit, hex_grid, a)
		var water_b := _ends_embarked(unit, hex_grid, b)
		if water_a != water_b:
			return water_b
		return HexMetrics.axial_distance(unit.coord, a) < HexMetrics.axial_distance(unit.coord, b))
	for destination in destinations:
		var path := hex_grid.unit_path(unit, destination)
		if path.is_empty():
			continue
		var first_step := true
		for step in path:
			# Fase 20: custo central do terreno (base + modificação V2) e a mesma regra do primeiro passo do HexGrid.
			var cost := HexGrid.affordable_step_cost(1.0 if unit.unit_data.flies else hex_grid.terrain_step_cost(step, null, unit.owner_player != null), unit.movement_left, first_step)
			if cost < 0.0:
				break
			first_step = false
			hex_grid.move_unit(unit, step, cost)
		return
	var reachable = hex_grid.unit_landing_reachable(unit) if unit.owner_player != null else hex_grid.compute_reachable(unit.coord, unit.movement_left, unit.owner_player, unit.unit_data.flies)
	var best_coord = null
	var best_dist = HexMetrics.axial_distance(unit.coord, target_coord)
	for coord in reachable.keys():
		var d = HexMetrics.axial_distance(coord, target_coord)
		if d < best_dist:
			best_dist = d
			best_coord = coord
	if best_coord != null:
		hex_grid.move_unit(unit, best_coord, reachable[best_coord])

static func _ends_embarked(unit: Unit, hex_grid: HexGrid, coord: Vector2i) -> bool:
	var tile := hex_grid.get_tile(coord)
	return unit.can_embark() and tile != null and tile.can_be_embarked_on()

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

## Task 22 -- so' vale gastar producao num colonizador se existe algum local
## aceitavel (CitySite.has_acceptable_site); depois de uma busca sem
## resultado, nao repete por CitySite.NO_SITE_RETRY_TURNS turnos (a busca custa
## alguns ms). "Conhecido" = explorado + o que a IA ve agora (no primeiro
## turno, `explored_tiles` ainda esta vazio: begin_turn roda depois).
static func _has_settle_site(player: PlayerData, hex_grid: HexGrid) -> bool:
	if TurnManager.turn_number < player.settle_search_blocked_until:
		return false
	if CitySite.has_acceptable_site(hex_grid, player):
		return true
	player.settle_search_blocked_until = TurnManager.turn_number + CitySite.NO_SITE_RETRY_TURNS
	return false

## Task 22 -- o local vem de CitySite.choose_site (valor local + espaco +
## coesao + seguranca + estrategia, ver CitySite.gd), nao mais do primeiro
## tile a 3 de distancia. O alvo fica guardado no colonizador (histerese).
## Sem nenhum local aceitavel, explora (revela mais mapa) por
## CitySite.SETTLE_PATIENCE_TURNS turnos e so' entao aceita o melhor valido.
static func _handle_settler(unit: Unit, hex_grid: HexGrid, player: PlayerData) -> void:
	var site := CitySite.choose_site(hex_grid, player, unit, unit.settle_wait_turns >= CitySite.SETTLE_PATIENCE_TURNS)
	if site.is_empty():
		unit.settle_wait_turns += 1
		unit.settle_target = Unit.NO_SETTLE_TARGET
		StrategicAI.explore(unit, player, hex_grid)
		return
	unit.settle_target = site.coord
	if site.coord != unit.coord:
		move_unit_toward(unit, hex_grid, site.coord)
	if unit.coord == site.coord:
		# Fase 33D2 (Bug #6): o local veio só do que a IA conhece; a regra real decide. Recusa = o tile sai
		# da busca deste Colonizador (sem revelar o motivo) e ele replaneja no próximo turno.
		if WorldSetup.found_city_from_settler(hex_grid, unit) == null:
			unit.settle_rejected_sites[site.coord] = true
			unit.settle_target = Unit.NO_SETTLE_TARGET
