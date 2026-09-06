extends GutTest

## Fase 0 do roadmap de gameplay (ver plano aprovado em .claude/plans) —
## harness de simulacao IA-vs-IA. Reaproveita GameManager._on_turn_changed
## de verdade (nao uma reimplementacao paralela do loop de turno) pra
## qualquer mudanca futura em RivalAI/City/CombatResolver/Diplomacy ser
## automaticamente exercitada aqui, sem precisar manter duas copias do
## mesmo fluxo sincronizadas. So 2 lacunas nao existem no GameManager real
## (porque la o "jogador humano" decide por UI, nunca por IA) e sao
## cobertas manualmente logo abaixo: producao/pesquisa do `primary` (o
## "assento humano" desta simulacao, mas 100% IA aqui) e o combate dele
## contra rivais com quem esteja em guerra.
##
## Este arquivo fica em test/integration/, DE PROPOSITO fora de
## test/unit/ (ver .gutconfig.json — so escaneia test/unit), porque e mais
## pesado que a suite rapida (gera mapa + roda N turnos x M seeds) e nao
## deve rodar em todo `-gdir=res://test/unit -gexit`. Rodar ISOLADO (sem
## carregar .gutconfig.json, que listaria test/unit por cima) com:
##   godot --headless -s addons/gut/gut_cmdln.gd -gconfig=
##     -gtest=res://test/integration/test_simulation_balance.gd -gexit
## (sem -gconfig= aqui, -gtest SOMA ao .gutconfig.json em vez de
## substituir — foi assim que a 1a rodada desta suite acabou executando os
## 590 testes de test/unit tambem, sem nenhum mal mas bem mais lento).
##
## ACHADO da Fase 4A, decisao ja tomada com o usuario (nao mexer): rotas
## de comercio (rotas_criadas nas metricas abaixo) ficam raras/zeradas na
## pratica numa partida com conflito ativo. Investigado a fundo: NAO e bug
## — Mercado (a cadeia celeiro->oficina->mercado, 3 predios) sai
## normalmente numa civ isolada sem ameaca (testado ate turno 300).
## O que acontece aqui e a PONTUACAO de producao da Fase 1
## (RivalAI.SCORE_WEIGHT_MILITARY_DEFICIT=2.0 > SCORE_WEIGHT_ECONOMY_GAP=
## 1.5 fixo) fazendo exercito ganhar quase sempre que ha ameaca visivel —
## e com 4 civs e guerra acontecendo, ha ameaca boa parte do tempo. Decisao
## do usuario: manter os pesos da Fase 1 como estao (ja aprovados/
## testados), aceitar comercio como algo raro/oportunista em partida com
## conflito, mais comum em trechos de paz — revisitar SO se isso incomodar
## na pratica.
##
## Linha de base ANTES de qualquer fix de gameplay (Fase 1 em diante): hoje
## a IA rival nao constroi predio nenhum e nunca inicia guerra sozinha (ver
## RivalAI.decide_production/_choose_target) — os numeros que este harness
## imprime agora SAO o "antes" pra comparar com cada fase seguinte, nao uma
## regressao a corrigir aqui. Por pedido explicito do usuario: nesta fase
## sao so METRICAS OBSERVADAS (impressas no stdout), nao asserts de
## comportamento/balanceamento que quebrem a suite — travar em "deve haver
## guerra" ou "ninguem pode dominar todas as seeds" agora faria a suite
## nascer vermelha so por descrever o estado atual. O UNICO assert daqui e
## sobre CORRECAO (yield/ouro negativo ou NaN), nunca sobre balanceamento —
## fases seguintes acrescentam asserts de comportamento quando prometerem
## aquele comportamento especificamente (ver plano, secao "Decisoes ja
## validadas").

const TURN_COUNT := 200
const SEEDS := [1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010,
	1011, 1012, 1013, 1014, 1015]
## Roadmap "Parte D" D4.0 -- ANTES desta fatia, este harness NAO era
## reproduzivel: SEEDS so controlava HexGrid.generate_map (terreno/recursos/
## covis/personalidade, tudo via RNG seedado local) mas RivalAI.decide_war
## (WAR_DECLARE_CHANCE_WHEN_READY) e RivalAI.decide_trade
## (TRADE_PROPOSE_CHANCE_PER_TURN) -- os UNICOS dois pontos de decisao de IA
## que consultam o RNG global (randf() sem seed proprio, auditado em toda
## RivalAI.gd) -- rodavam com o RNG global do Godot, que varia a cada
## execucao do processo. Resultado pratico: comparar "config A" vs "config
## B" na mesma seed_value dava trajetorias DIFERENTES desde o primeiro
## randf(), contaminando qualquer diff com ruido de sorte em vez de isolar
## o efeito da mudanca de peso/threshold (ver D3, "existe uma questao de
## determinismo do RNG pra comparacoes A/B").
##
## Fix: `seed(ai_rng_seed)` global (Godot @GlobalScope.seed(), reseeda O
## MESMO RNG global que decide_war/decide_trade consultam) chamado em
## _run_seed logo ANTES do loop de turnos comecar -- ver comentario la.
## AI_RNG_SEEDS fica PAREADO 1:1 com SEEDS de proposito (mesmo indice):
## simples o bastante pra baseline (map + comportamento variam juntos,
## imitando "15 partidas diferentes"), mas _run_seed aceita os dois eixos
## SEPARADOS -- um experimento futuro que queira isolar "quanto do
## resultado e sorte de dado, mesmo mapa" so precisa variar AI_RNG_SEEDS
## sozinho contra o MESMO SEEDS.
const AI_RNG_SEEDS := SEEDS
const STAGNATION_WINDOW := 35 # M do plano: turnos sem guerra/territorio mudando pra considerar estagnado
const MAP_SIZE := 41 # bem menor que TitleScreen.MAP_SIZES.large (320x84) de proposito — harness precisa rodar 15 seeds x 200 turnos em tempo razoavel, nao precisa dos continentes especiais (Vulcanico/Cristal) pra medir IA/economia/guerra
const RIVAL_COUNT := 3 # + o "primary" = 4 civs, mesmo teto pratico de GameManager.rival_count hoje
const RIVAL_RACES := ["elf", "dwarf", "orc"]

var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_rival_players: Array[PlayerData]
var _original_players: Array[PlayerData]
var _original_state
var _original_stagger: bool
var _original_debug_mode: bool
var _original_turn_number: int
var _original_player_count: int
var _original_war_weight_resources_secure: float # Roadmap "Parte D" D4.2 -- RivalAI.WAR_WEIGHT_RESOURCES_SECURE virou static var so pra este experimento poder sobrescreve-la; salvar/restaurar aqui (mesmo padrao dos autoloads acima) garante que volta a 2.0 mesmo se o teste falhar no meio

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_rival_players = GameManager.rival_players
	_original_players = GameManager.players
	_original_state = GameManager.state
	_original_stagger = GameManager.stagger_ai_turns
	_original_debug_mode = GameManager.debug_mode
	_original_turn_number = TurnManager.turn_number
	_original_player_count = TurnManager.player_count
	_original_war_weight_resources_secure = RivalAI.WAR_WEIGHT_RESOURCES_SECURE

func after_each():
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	GameManager.rival_players = _original_rival_players
	GameManager.players = _original_players
	GameManager.state = _original_state
	GameManager.stagger_ai_turns = _original_stagger
	RivalAI.WAR_WEIGHT_RESOURCES_SECURE = _original_war_weight_resources_secure
	GameManager.debug_mode = _original_debug_mode
	TurnManager.turn_number = _original_turn_number
	TurnManager.player_count = _original_player_count
	randomize() # D4.0 -- _run_seed fixa o RNG global (seed()) pra reprodutibilidade; devolve ao acaso pra nao vazar determinismo pra qualquer coisa que rode DEPOIS deste arquivo no mesmo processo

func test_simulate_baseline_multi_seed_metrics():
	var all_results: Array = []
	for i in range(SEEDS.size()):
		var seed_value: int = SEEDS[i]
		var result := _run_seed(seed_value, AI_RNG_SEEDS[i])
		all_results.append(result)
		print("[sim seed=%d] fim=T%d 1a_guerra=%s guerras=%d dur_media_guerra=%.1f estagnado=%s eliminados=%s predios=%s cidades_finais=%s ouro_medio=%s rotas_criadas=%d rotas_ativas_fim=%d rotas_canceladas=%d fronteira_com_recurso=%s fronteira_perto_de_covil=%s eixo_dominante=%s pesquisas_identity_match=%d/%d(%.0f%%) composicao_rivais=%s campanhas_iniciadas=%d campanhas_concluidas=%d campanhas_abandonadas=%d campanhas_redirecionadas=%d campanha_status_final=%s paz_primary=%s guerras_encerradas_por_paz=%d weariness_na_paz=%s" % [
			seed_value,
			result.ended_turn if result.ended_turn != -1 else TURN_COUNT,
			("T%d" % result.first_war_turn) if result.first_war_turn != -1 else "nenhuma",
			result.war_count,
			_avg(result.war_durations),
			result.stagnant,
			result.eliminated,
			result.buildings_built,
			result.final_cities,
			result.avg_gold,
			result.routes_created,
			result.routes_active_at_end,
			result.routes_cancelled,
			result.frontier_claim_resource_pct,
			result.frontier_claim_lair_danger_pct,
			result.dominant_axis_counts,
			result.research_choices_matching_identity,
			result.research_choices_total,
			result.research_choice_identity_match_pct * 100.0,
			result.rival_role_counts,
			result.campaigns_started,
			result.campaigns_completed,
			result.campaigns_abandoned,
			result.campaigns_retargeted,
			result.final_campaign_status,
			result.peace_proposals_by_primary,
			result.wars_ended_by_peace,
			result.war_weariness_at_peace,
		])

	var seeds_with_war := 0
	var stagnant_seeds := 0
	var seeds_with_elimination := 0
	for r in all_results:
		if r.first_war_turn != -1:
			seeds_with_war += 1
		if r.stagnant:
			stagnant_seeds += 1
		if not r.eliminated.is_empty():
			seeds_with_elimination += 1
	print("[sim agregado] seeds=%d com_guerra=%d estagnados=%d com_eliminacao=%d" % [
		all_results.size(), seeds_with_war, stagnant_seeds, seeds_with_elimination,
	])

	# Roadmap "Parte C" (composicao de exercito), C1 — mesma disciplina
	# observacional do resto deste harness: nenhum assert de composicao
	# "certa", so instrumentacao. Contagem de PAPEL (nao de unidade -- um
	# cavalry conta pra melee E cavalry, mesmo _role_counts usado pelo
	# score) agregada so sobre os RIVAIS (nao o "Principal", que tem o
	# ponto cego documentado acima de 1-oponente-por-chamada) em toda seed,
	# pra responder: a IA rival esta produzindo exercitos com mais de um
	# papel, ou continua puramente corpo-a-corpo como antes de C1?
	var role_totals := {ArmyComposition.ROLE_MELEE: 0, ArmyComposition.ROLE_RANGED: 0, ArmyComposition.ROLE_CAVALRY: 0, ArmyComposition.ROLE_SIEGE: 0}
	var distinct_roles_sum := 0
	var rival_army_samples := 0
	var melee_only_armies := 0
	var ranged_only_armies := 0
	for r in all_results:
		for label in r.rival_role_counts.keys():
			var counts: Dictionary = r.rival_role_counts[label]
			rival_army_samples += 1
			var distinct := 0
			for role in ArmyComposition.ROLES:
				var c: int = counts.get(role, 0)
				role_totals[role] += c
				if c > 0:
					distinct += 1
			distinct_roles_sum += distinct
			var has_melee: bool = counts.get(ArmyComposition.ROLE_MELEE, 0) > 0
			var has_ranged: bool = counts.get(ArmyComposition.ROLE_RANGED, 0) > 0
			var has_cavalry: bool = counts.get(ArmyComposition.ROLE_CAVALRY, 0) > 0
			var has_siege: bool = counts.get(ArmyComposition.ROLE_SIEGE, 0) > 0
			if has_melee and not has_ranged and not has_cavalry and not has_siege:
				melee_only_armies += 1
			if has_ranged and not has_melee and not has_cavalry and not has_siege:
				ranged_only_armies += 1
	var role_total_units: int = role_totals[ArmyComposition.ROLE_MELEE] + role_totals[ArmyComposition.ROLE_RANGED] + role_totals[ArmyComposition.ROLE_CAVALRY] + role_totals[ArmyComposition.ROLE_SIEGE]
	print("[sim agregado composicao] amostras_rival=%d papeis_distintos_medio=%.2f exercitos_so_melee=%d exercitos_so_ranged=%d distrib_melee=%s distrib_ranged=%s distrib_cavalry=%s distrib_siege=%s" % [
		rival_army_samples,
		(float(distinct_roles_sum) / float(rival_army_samples)) if rival_army_samples > 0 else 0.0,
		melee_only_armies,
		ranged_only_armies,
		("%.0f%%" % (100.0 * float(role_totals[ArmyComposition.ROLE_MELEE]) / float(role_total_units))) if role_total_units > 0 else "n/a",
		("%.0f%%" % (100.0 * float(role_totals[ArmyComposition.ROLE_RANGED]) / float(role_total_units))) if role_total_units > 0 else "n/a",
		("%.0f%%" % (100.0 * float(role_totals[ArmyComposition.ROLE_CAVALRY]) / float(role_total_units))) if role_total_units > 0 else "n/a",
		("%.0f%%" % (100.0 * float(role_totals[ArmyComposition.ROLE_SIEGE]) / float(role_total_units))) if role_total_units > 0 else "n/a",
	])

	# Roadmap "Parte C" C3 — agregado dos 4 contadores de ciclo de vida de
	# campanha + distribuicao final ACTIVE/COMPLETED/ABANDONED/sem_campanha
	# somada entre todas as seeds. So observacao (mesma disciplina de C1/C2:
	# nao decidir a priori qual distribuicao e "certa", nem calibrar
	# CAMPAIGN_ABANDON_SCORE_THRESHOLD com base nisso agora).
	var total_started := 0
	var total_completed := 0
	var total_abandoned := 0
	var total_retargeted := 0
	var final_status_totals := {}
	for r in all_results:
		total_started += r.campaigns_started
		total_completed += r.campaigns_completed
		total_abandoned += r.campaigns_abandoned
		total_retargeted += r.campaigns_retargeted
		for status in r.final_campaign_status.keys():
			final_status_totals[status] = final_status_totals.get(status, 0) + r.final_campaign_status[status]
	print("[sim agregado campanhas] iniciadas=%d concluidas=%d abandonadas=%d redirecionadas=%d status_final=%s" % [
		total_started, total_completed, total_abandoned, total_retargeted, final_status_totals,
	])

	# Roadmap "Parte D" D1 -- pergunta central nao e "60.0 e o numero certo?"
	# e sim "o mecanismo produz guerras que terminam sozinhas, sem
	# intervencao humana?". Sem assert de balanceamento, mesma disciplina.
	var total_accepted := 0
	var total_refused := 0
	var total_below_threshold := 0
	var total_wars_ended := 0
	var all_weariness_at_peace: Array = []
	for r in all_results:
		total_accepted += r.peace_proposals_by_primary.accepted
		total_refused += r.peace_proposals_by_primary.refused
		total_below_threshold += r.peace_proposals_by_primary.below_threshold
		total_wars_ended += r.wars_ended_by_peace
		all_weariness_at_peace.append_array(r.war_weariness_at_peace)
	print("[sim agregado paz] primary_aceitas=%d primary_recusadas=%d primary_abaixo_limiar=%d guerras_encerradas_por_paz_total=%d weariness_media_na_paz=%.1f" % [
		total_accepted, total_refused, total_below_threshold, total_wars_ended,
		_avg(all_weariness_at_peace),
	])

	# Roadmap "Parte D" D3 -- baseline pedida pelo usuario: so medir, nao
	# calibrar nenhum peso/threshold ainda com base num unico cenario. As
	# quatro impressoes abaixo (weariness na OFERTA, objetivo de guerra,
	# duracao de campanha, personalidade x pesquisa) fecham a lista de
	# metricas combinada com o usuario nesta fatia.
	var all_weariness_accepted: Array = []
	var all_weariness_refused: Array = []
	var all_weariness_below_threshold: Array = []
	for r in all_results:
		all_weariness_accepted.append_array(r.war_weariness_at_offer.accepted)
		all_weariness_refused.append_array(r.war_weariness_at_offer.refused)
		all_weariness_below_threshold.append_array(r.war_weariness_at_offer.below_threshold)
	print("[sim agregado paz oferta] weariness_media_aceita=%.1f(n=%d) weariness_media_recusada=%.1f(n=%d) weariness_media_abaixo_limiar=%.1f(n=%d)" % [
		_avg(all_weariness_accepted), all_weariness_accepted.size(),
		_avg(all_weariness_refused), all_weariness_refused.size(),
		_avg(all_weariness_below_threshold), all_weariness_below_threshold.size(),
	])

	# D3 (revisao) -- weariness de quem RECEBE a oferta (rivals[0]), o dado
	# que Diplomacy._accepts_peace realmente usa (ver comentario em
	# _record_peace_decision). Verificacao direta da mecanica documentada
	# em _accepts_peace: aceita se units.size() <= proposer OU
	# war_weariness >= WAR_WEARINESS_ACCEPTS_PEACE_THRESHOLD (40.0) -- e um
	# OR, entao receiver_weariness>=40 DEVERIA aparecer SO do lado aceito
	# (nunca do lado recusado, ja que >=40 sozinho ja garante aceite
	# independente de contagem de unidades). refusadas_com_weariness_alto
	# != 0 seria sinal de bug na mecanica (ou na leitura deste harness dela),
	# nao uma questao de calibracao.
	var all_receiver_weariness_accepted: Array = []
	var all_receiver_weariness_refused: Array = []
	var all_receiver_weariness_below_threshold: Array = []
	for r in all_results:
		all_receiver_weariness_accepted.append_array(r.receiver_weariness_at_offer.accepted)
		all_receiver_weariness_refused.append_array(r.receiver_weariness_at_offer.refused)
		all_receiver_weariness_below_threshold.append_array(r.receiver_weariness_at_offer.below_threshold)
	var refused_with_high_receiver_weariness := 0
	for w in all_receiver_weariness_refused:
		if w >= Diplomacy.WAR_WEARINESS_ACCEPTS_PEACE_THRESHOLD:
			refused_with_high_receiver_weariness += 1
	print("[sim agregado paz oferta (receptor)] weariness_media_aceita=%.1f(n=%d) weariness_media_recusada=%.1f(n=%d) weariness_media_abaixo_limiar=%.1f(n=%d) recusadas_com_weariness_alto=%d" % [
		_avg(all_receiver_weariness_accepted), all_receiver_weariness_accepted.size(),
		_avg(all_receiver_weariness_refused), all_receiver_weariness_refused.size(),
		_avg(all_receiver_weariness_below_threshold), all_receiver_weariness_below_threshold.size(),
		refused_with_high_receiver_weariness,
	])

	# D3 -- suspeita ja levantada pelo usuario (secure_resources dominando
	# conquer): agregado aqui responde com numero real em vez de impressao
	# seed-a-seed espalhada. Ver ressalva de aproximacao em _log_war_target.
	var war_objective_totals := {}
	for r in all_results:
		for objective in r.war_objective_counts.keys():
			war_objective_totals[objective] = war_objective_totals.get(objective, 0) + r.war_objective_counts[objective]
	print("[sim agregado objetivo de guerra] %s" % [war_objective_totals])

	# Roadmap "Parte D" D4.1 -- amostra bem maior que a de cima (TODO turno
	# em paz avaliado, nao so guerras que de fato comecaram, ver
	# _record_war_objective_decision) -- responde empiricamente "secure_
	# resources vence por PESO (WAR_WEIGHT_RESOURCES_SECURE=2.0) ou por achar
	# cidade melhor?": media dos componentes por objetivo separa os dois.
	# NENHUMA constante mudada nesta fatia -- so medicao, mesma disciplina
	# de sempre. Bins de delta sao um PONTO DE PARTIDA (pedido do usuario:
	# "nao precisamos decidir bins definitivos ainda"), nao um contrato.
	var total_objective_decisions := 0
	var total_conquer_wins := 0
	var total_secure_wins := 0
	var total_objective_ties := 0
	var all_objective_deltas: Array = []
	var objective_selected_totals := {}
	var objective_components_sum := {RivalAI.WAR_OBJECTIVE_CONQUER: {}, RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES: {}}
	for r in all_results:
		total_objective_decisions += r.war_objective_decisions
		total_conquer_wins += r.war_objective_conquer_wins
		total_secure_wins += r.war_objective_secure_wins
		total_objective_ties += r.war_objective_ties
		all_objective_deltas.append_array(r.war_objective_deltas)
		for objective in r.war_objective_selected.keys():
			objective_selected_totals[objective] = objective_selected_totals.get(objective, 0) + r.war_objective_selected[objective]
		for objective in r.war_objective_components_sum.keys():
			for component_key in r.war_objective_components_sum[objective].keys():
				objective_components_sum[objective][component_key] = objective_components_sum[objective].get(component_key, 0.0) + r.war_objective_components_sum[objective][component_key]

	var objective_delta_bins := {"< -1": 0, "[-1, 0)": 0, "[0, 1)": 0, ">= 1": 0}
	for delta in all_objective_deltas:
		if delta < -1.0:
			objective_delta_bins["< -1"] += 1
		elif delta < 0.0:
			objective_delta_bins["[-1, 0)"] += 1
		elif delta < 1.0:
			objective_delta_bins["[0, 1)"] += 1
		else:
			objective_delta_bins[">= 1"] += 1

	var conquer_avg_components := {}
	var secure_avg_components := {}
	if total_objective_decisions > 0:
		for component_key in objective_components_sum[RivalAI.WAR_OBJECTIVE_CONQUER].keys():
			conquer_avg_components[component_key] = objective_components_sum[RivalAI.WAR_OBJECTIVE_CONQUER][component_key] / float(total_objective_decisions)
		for component_key in objective_components_sum[RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES].keys():
			secure_avg_components[component_key] = objective_components_sum[RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES][component_key] / float(total_objective_decisions)

	print("[sim agregado D4.1 objetivo] decisoes=%d conquer_venceu=%d secure_venceu=%d empates=%d delta_medio(secure-conquer)=%.2f delta_mediano=%.2f selecionado=%s delta_bins=%s" % [
		total_objective_decisions, total_conquer_wins, total_secure_wins, total_objective_ties,
		_avg(all_objective_deltas), _median(all_objective_deltas), objective_selected_totals, objective_delta_bins,
	])
	print("[sim agregado D4.1 componentes] conquer_media=%s secure_media=%s" % [conquer_avg_components, secure_avg_components])

	# Roadmap "Parte D" D4.3 -- diagnostico dos fatores CRUS, sem nenhuma
	# mudanca de gameplay: "o vies vem de resources dominante, role_fit
	# raramente aplicavel, binarizacao de proximity/vulnerability, ou da
	# natureza dos alvos disponiveis?" (pergunta combinada com o usuario).
	# resource_richness/role_fit usam histograma por VALOR EXATO (nao bins)
	# porque os dois sao discretos por construcao (count/NORM clampado --
	# ver _city_resource_richness/_role_fit_bonus), nao continuos de
	# verdade; proximity/vulnerability sao BINARIOS por construcao, entao
	# "distribuicao" e so a fracao que deu 1.0. strength_advantage e o
	# unico genuinamente continuo, por isso ganha bins de range.
	var all_strength_advantage: Array = []
	var all_candidate_resource_richness: Array = []
	var all_candidate_role_fit: Array = []
	var total_candidate_samples := 0
	var total_proximity_true := 0
	var total_vulnerability_true := 0
	var selected_raw_totals := {
		RivalAI.WAR_OBJECTIVE_CONQUER: {"resource_richness": [], "proximity": [], "vulnerability": [], "role_fit": []},
		RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES: {"resource_richness": [], "proximity": [], "vulnerability": [], "role_fit": []},
	}
	for r in all_results:
		all_strength_advantage.append_array(r.war_objective_strength_advantage)
		all_candidate_resource_richness.append_array(r.war_objective_candidate_resource_richness)
		all_candidate_role_fit.append_array(r.war_objective_candidate_role_fit)
		total_candidate_samples += r.war_objective_candidate_samples
		total_proximity_true += r.war_objective_candidate_proximity_true
		total_vulnerability_true += r.war_objective_candidate_vulnerability_true
		for objective in r.war_objective_selected_raw.keys():
			for factor_key in r.war_objective_selected_raw[objective].keys():
				selected_raw_totals[objective][factor_key].append_array(r.war_objective_selected_raw[objective][factor_key])

	var resource_richness_hist := _histogram(all_candidate_resource_richness)
	var role_fit_hist := _histogram(all_candidate_role_fit)
	var role_fit_positive := 0
	for v in all_candidate_role_fit:
		if v > 0.0:
			role_fit_positive += 1

	var strength_bins := {"[-1.0, -0.5)": 0, "[-0.5, 0.0)": 0, "[0.0, 0.5)": 0, "[0.5, 1.0]": 0}
	for v in all_strength_advantage:
		if v < -0.5:
			strength_bins["[-1.0, -0.5)"] += 1
		elif v < 0.0:
			strength_bins["[-0.5, 0.0)"] += 1
		elif v < 0.5:
			strength_bins["[0.0, 0.5)"] += 1
		else:
			strength_bins["[0.5, 1.0]"] += 1

	print("[sim agregado D4.3 fatores] amostras_candidato=%d strength_media=%.2f strength_mediana=%.2f strength_bins=%s proximity_verdadeiro=%d/%d(%.0f%%) vulnerability_verdadeiro=%d/%d(%.0f%%) resource_richness_hist=%s role_fit_hist=%s role_fit_positivo=%d/%d(%.0f%%)" % [
		total_candidate_samples,
		_avg(all_strength_advantage), _median(all_strength_advantage), strength_bins,
		total_proximity_true, total_candidate_samples, (100.0 * float(total_proximity_true) / float(total_candidate_samples)) if total_candidate_samples > 0 else 0.0,
		total_vulnerability_true, total_candidate_samples, (100.0 * float(total_vulnerability_true) / float(total_candidate_samples)) if total_candidate_samples > 0 else 0.0,
		resource_richness_hist, role_fit_hist,
		role_fit_positive, all_candidate_role_fit.size(), (100.0 * float(role_fit_positive) / float(all_candidate_role_fit.size())) if not all_candidate_role_fit.is_empty() else 0.0,
	])

	# D4.3 -- correlacao fator x objetivo EFETIVAMENTE selecionado (nao so
	# o "melhor por objetivo" de D4.1 acima) -- responde "quando conquer
	# de fato venceu (empate/desempate), o que era diferente daquela
	# decisao?".
	for objective in selected_raw_totals.keys():
		var bucket: Dictionary = selected_raw_totals[objective]
		var n: int = bucket.resource_richness.size()
		print("[sim agregado D4.3 selecionado=%s] n=%d resource_richness_media=%.2f proximity_media=%.2f vulnerability_media=%.2f role_fit_media=%.2f" % [
			objective, n,
			_avg(bucket.resource_richness), _avg(bucket.proximity), _avg(bucket.vulnerability), _avg(bucket.role_fit),
		])

	# D3 -- duracao de campanha (turnos entre ACTIVE e o desfecho terminal),
	# agregada entre todas as seeds, todas as campanhas encerradas.
	var all_campaign_durations: Array = []
	for r in all_results:
		all_campaign_durations.append_array(r.campaign_durations)
	print("[sim agregado duracao de campanha] media=%.1f(n=%d)" % [_avg(all_campaign_durations), all_campaign_durations.size()])

	# D3 -- personalidade (intencao fixa) vs identidade (evidencia
	# historica) como preditores de escolha de pesquisa, lado a lado.
	var total_matching_personality := 0
	var total_research_choices := 0
	for r in all_results:
		total_matching_personality += r.research_choices_matching_personality
		total_research_choices += r.research_choices_total
	print("[sim agregado pesquisa x personalidade] personalidade_match=%d/%d(%.0f%%)" % [
		total_matching_personality, total_research_choices,
		(100.0 * float(total_matching_personality) / float(total_research_choices)) if total_research_choices > 0 else 0.0,
	])

	# Unico assert desta fase: correcao (numero invalido), nunca balanceamento
	# ou comportamento esperado — ver comentario de topo do arquivo.
	for r in all_results:
		assert_false(r.nan_or_negative_yield, "yield/ouro negativo ou NaN detectado numa das seeds — bug de correcao, nao questao de balanceamento")

## Roadmap "Parte D" D4.2 -- variantes do experimento A/B/C/D combinado com
## o usuario. "A" repete o baseline (2.0) DE PROPOSITO -- serve de controle
## interno: com o RNG deterministico de D4.0, os numeros de A aqui devem
## bater com os que D4.1 ja reportou (mesma SEEDS/AI_RNG_SEEDS, mesmo peso).
## "D" (1.0) e o controle SEM vantagem alguma entre os dois objetivos.
## Nenhum valor aqui e proposto como definitivo -- ver "regra de ouro"
## combinada com o usuario: o objetivo e mapear a faixa, nao escolher um
## numero ainda.
const WAR_OBJECTIVE_EXPERIMENT_VARIANTS := [
	{"label": "A_baseline_2.00", "weight": 2.0},
	{"label": "B_1.50", "weight": 1.5},
	{"label": "C_1.25", "weight": 1.25},
	{"label": "D_1.00_controle", "weight": 1.0},
]

## D4.2 -- roda a MESMA matriz SEEDS/AI_RNG_SEEDS (D4.0) uma vez por
## variante, sobrescrevendo SO RivalAI.WAR_WEIGHT_RESOURCES_SECURE entre
## execucoes (restaurado em after_each mesmo se este teste falhar no meio).
## Reusa _run_seed sem nenhuma modificacao -- a variante nao muda NADA na
## montagem da partida, so o peso que a formula ja calibravel consulta.
func test_war_objective_weight_experiment_A_B_C_D():
	var any_nan_or_negative := false
	for variant in WAR_OBJECTIVE_EXPERIMENT_VARIANTS:
		RivalAI.WAR_WEIGHT_RESOURCES_SECURE = variant.weight
		var variant_results: Array = []
		for i in range(SEEDS.size()):
			var result := _run_seed(SEEDS[i], AI_RNG_SEEDS[i])
			variant_results.append(result)
			if result.nan_or_negative_yield:
				any_nan_or_negative = true
		_print_war_objective_experiment_variant(variant.label, variant.weight, variant_results)

	# Mesmo assert de correcao do teste de baseline acima (nunca
	# balanceamento) -- se uma variante de peso produzisse NaN/negativo,
	# seria bug de correcao na formula, nao uma questao de calibracao.
	assert_false(any_nan_or_negative, "yield/ouro negativo ou NaN detectado numa das seeds/variantes -- bug de correcao, nao questao de balanceamento")

## D4.2 -- agregado por VARIANTE (nao por seed, ao contrario do baseline
## acima) com exatamente os campos combinados com o usuario: decisoes,
## vitorias/empates por objetivo, distribuicao de delta (media+mediana+
## bins), objetivo efetivamente selecionado, e o "comportamento macro"
## (guerras declaradas, ciclo de vida de campanha) -- pra responder as
## DUAS perguntas separadas (a formula deixa de ser enviesada? isso muda o
## comportamento observavel?), nao so a primeira.
func _print_war_objective_experiment_variant(label: String, weight: float, results: Array) -> void:
	var total_decisions := 0
	var conquer_wins := 0
	var secure_wins := 0
	var ties := 0
	var deltas: Array = []
	var selected_totals := {}
	var total_wars := 0
	var campaigns_started := 0
	var campaigns_completed := 0
	var campaigns_abandoned := 0
	var campaign_durations: Array = []
	for r in results:
		total_decisions += r.war_objective_decisions
		conquer_wins += r.war_objective_conquer_wins
		secure_wins += r.war_objective_secure_wins
		ties += r.war_objective_ties
		deltas.append_array(r.war_objective_deltas)
		for objective in r.war_objective_selected.keys():
			selected_totals[objective] = selected_totals.get(objective, 0) + r.war_objective_selected[objective]
		total_wars += r.war_count
		campaigns_started += r.campaigns_started
		campaigns_completed += r.campaigns_completed
		campaigns_abandoned += r.campaigns_abandoned
		campaign_durations.append_array(r.campaign_durations)

	var delta_bins := {"< -1": 0, "[-1, 0)": 0, "[0, 1)": 0, ">= 1": 0}
	for delta in deltas:
		if delta < -1.0:
			delta_bins["< -1"] += 1
		elif delta < 0.0:
			delta_bins["[-1, 0)"] += 1
		elif delta < 1.0:
			delta_bins["[0, 1)"] += 1
		else:
			delta_bins[">= 1"] += 1

	print("[sim D4.2 experimento %s peso=%.2f] decisoes=%d conquer_venceu=%d secure_venceu=%d empates=%d delta_medio(secure-conquer)=%.2f delta_mediano=%.2f delta_bins=%s selecionado=%s guerras_declaradas=%d campanhas_iniciadas=%d campanhas_concluidas=%d campanhas_abandonadas=%d duracao_media_campanha=%.1f(n=%d)" % [
		label, weight,
		total_decisions, conquer_wins, secure_wins, ties,
		_avg(deltas), _median(deltas), delta_bins, selected_totals,
		total_wars, campaigns_started, campaigns_completed, campaigns_abandoned,
		_avg(campaign_durations), campaign_durations.size(),
	])

## --- Montagem de uma partida simulada ---------------------------------

## D4.0 -- `seed_value` continua controlando SO o cenario (mapa/recursos/
## covis/personalidade, via HexGrid.generate_map + CivilizationPersonality,
## nenhum dos dois toca o RNG global). `ai_rng_seed` e o eixo NOVO e
## SEPARADO: reseeda o RNG global (ver chamada a seed() abaixo) que
## RivalAI.decide_war/decide_trade consultam -- os dois UNICOS pontos de
## decisao de IA que usam randf() sem RNG proprio. Nenhuma chamada entre
## a criacao do grid e o loop de turnos consome RNG global (auditado:
## WorldSetup.find_start_tile/find_spawn_tile, _spawn_capital,
## CivilizationPersonality.generate usam so RNG local/seedado), entao
## reseedar bem antes do loop comecar e seguro e determina 100% da
## sequencia de decisoes de IA dali em diante.
func _run_seed(seed_value: int, ai_rng_seed: int) -> Dictionary:
	var grid := HexGrid.new()
	grid._ready()
	grid.generate_map(MAP_SIZE, MAP_SIZE, seed_value)

	var primary := _make_player("Principal", "human")
	var rivals: Array[PlayerData] = []
	for i in range(RIVAL_COUNT):
		rivals.append(_make_player("Rival %d" % (i + 1), RIVAL_RACES[i % RIVAL_RACES.size()]))

	# Roadmap "Parte D" D3 -- ACHADO DE INSTRUMENTACAO: PlayerData.personality
	# comeca "{}" (ver comentario em PlayerData.gd, "nunca acontece em jogo
	# real pos-setup_players, mas e o estado de todo PlayerData de teste
	# construido direto via PlayerData.new(...)") e este harness SEMPRE
	# construiu jogadores direto via PlayerData.new (_make_player abaixo),
	# NUNCA passando por GameManager.setup_players(). Resultado: ate esta
	# fatia, TODA metrica deste harness (inclusive B3, antes de D3 existir)
	# rodou com personality vazia em TODOS os jogadores -- RESEARCH_WEIGHT_
	# PERSONALITY (RivalAI.gd) nunca teve efeito nenhum aqui, mesmo a
	# feature existindo e sendo exercitada normalmente no jogo de verdade.
	# Fix: mesma formula EXATA de GameManager.setup_players() (map_seed +
	# PERSONALITY_SEED_OFFSET pro humano, +i+1 por rival, na ordem de
	# `rivals`) -- reproduz o jogo real em vez de inventar uma convencao
	# nova so pro harness.
	primary.personality = CivilizationPersonality.generate(primary.civ.race, grid.map_seed + CivilizationPersonality.PERSONALITY_SEED_OFFSET)
	for i in range(rivals.size()):
		rivals[i].personality = CivilizationPersonality.generate(rivals[i].civ.race, grid.map_seed + CivilizationPersonality.PERSONALITY_SEED_OFFSET + i + 1)

	var claimed: Array[Vector2i] = []
	_spawn_capital(grid, primary, Vector2i(0, 0), claimed)
	var half := float(MAP_SIZE) / 2.0
	for i in range(rivals.size()):
		var angle := TAU * float(i) / float(rivals.size())
		var origin := Vector2i(int(round(cos(angle) * half * 0.6)), int(round(sin(angle) * half * 0.6)))
		_spawn_capital(grid, rivals[i], origin, claimed)

	GameManager.hex_grid = grid
	GameManager.human_player = primary
	GameManager.rival_players = rivals
	GameManager.players = ([primary] as Array[PlayerData]) + rivals
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.stagger_ai_turns = false
	GameManager.debug_mode = false
	TurnManager.turn_number = 1
	TurnManager.player_count = 1

	seed(ai_rng_seed) # D4.0 -- ver docstring desta funcao; PRECISA vir depois de todo o setup de cenario acima (que nao toca RNG global) e ANTES do loop de turnos abaixo (que toca, via decide_war/decide_trade)
	var m := _new_metrics()
	for turn_index in range(TURN_COUNT):
		var war_before := _war_pairs(primary, rivals)
		var cities_before := _city_counts(primary, rivals)
		var research_before := _research_before(primary, rivals)
		var campaigns_before := _campaign_status_pairs(primary, rivals)

		# GameManager._on_turn_changed so decide producao/pesquisa/ataque pra
		# rival_players (o jogador humano decide isso via UI de verdade) —
		# aqui nao ha UI nenhuma, entao o "primary" tambem precisa de uma
		# decisao de producao/pesquisa pra nao ficar uma cidade eternamente
		# parada (o que enviesaria toda metrica de economia/guerra). Isto e
		# a UNICA duplicacao de logica do harness — o resto (regen/cura,
		# pesquisa, producao de cidade, turno de cada rival contra o
		# primary, covis de monstro, fog, check_game_over) vem 100% de
		# _on_turn_changed real, sem reimplementar nada.
		# So primary precisa de chamada manual aqui — cada rival ja recebe
		# decide_production/decide_research/decide_war de dentro do proprio
		# GameManager._on_turn_changed (mesmo loop `for rival in
		# rival_players` do jogo de verdade, ver GameManager.gd). Chamar de
		# novo aqui pros rivais duplicaria a rolagem de dado do jitter de
		# guerra (WAR_DECLARE_CHANCE_WHEN_READY seria testado 2x por turno
		# por engano).
		RivalAI.decide_production(primary, grid, rivals[0])
		RivalAI.decide_research(primary)
		# Roadmap "Parte D" D4.1 -- MESMA pre-condicao de decide_war (so em
		# paz: ver "if player.is_at_war_with(opponent): return" no topo dele)
		# porque queremos observar exatamente o que decide_war esta prestes a
		# consultar, sem alterar nada -- puramente uma leitura, ANTES de
		# decide_war rodar (se ele declarar guerra agora, o proximo turno ja
		# nao teria mais candidato pra este par).
		if not primary.is_at_war_with(rivals[0]):
			_record_war_objective_decision(m, grid, primary, rivals[0])
		RivalAI.decide_war(primary, grid, rivals[0])
		RivalAI.decide_campaign(primary, grid, rivals[0]) # Roadmap "Parte C" C3 -- mesmo lugar/ordem de GameManager.gd (logo apos decide_war)
		# Roadmap "Parte D" D1 -- mesmo lugar/ordem de GameManager.gd (logo
		# apos decide_campaign). So pro "primary" de proposito, mesmo motivo
		# de decide_war/decide_campaign acima -- cada rival ja recebe sua
		# propria chamada de dentro de GameManager._on_turn_changed. So a
		# direcao primary->rivals[0] fica com contagem PRECISA de tentativa/
		# aceite/recusa (capturamos o retorno aqui); a direcao rival->primary
		# so aparece indiretamente via _record_peace_outcome (guerra
		# encerrada = alguma decide_peace autonoma teve sucesso, ja que
		# nenhum outro caminho deste harness chama Diplomacy.propose_peace).
		# D3 -- os dois lados capturados no MESMO instante, antes de
		# decide_peace/propose_peace rodarem: `weariness_at_offer` (primary)
		# so decide SE a oferta acontece (gate em decide_peace contra
		# WAR_WEARINESS_OFFER_PEACE_THRESHOLD); `receiver_weariness_at_offer`
		# (rivals[0]) e o dado que de fato entra em Diplomacy._accepts_peace
		# (aceita se ai_player.units.size() <= proposer.units.size() OU
		# ai_player.war_weariness >= WAR_WEARINESS_ACCEPTS_PEACE_THRESHOLD) --
		# confundir os dois foi o erro apontado na revisao do D3 (weariness
		# do PROPONENTE nao tem por que prever aceite/recusa).
		var weariness_at_offer: float = primary.war_weariness
		var receiver_weariness_at_offer: float = rivals[0].war_weariness
		var peace_result := RivalAI.decide_peace(primary, rivals[0])
		_record_peace_decision(m, peace_result, weariness_at_offer, receiver_weariness_at_offer)
		RivalAI.decide_trade(primary, grid, rivals[0])

		GameManager._on_turn_changed(TurnManager.turn_number, 0)

		# Turno do "primary": chamado SEMPRE, nao so quando em guerra —
		# RivalAI.act_for_unit ja separa isso sozinho internamente
		# (colonizador sempre tenta assentar/vagar, so o braco de ATAQUE
		# passa por _choose_target, que retorna null e vira no-op quando em
		# paz). Um gate externo por is_at_war_with aqui foi tentado antes e
		# acabou travando TAMBEM o assentamento (bug do harness, nao do
		# jogo) — Principal nunca passava de 1 cidade em nenhuma seed.
		# rivals[0] serve so de referencia obrigatoria pro parametro
		# `opponent` (usada por _scout_enemy_cities/choose_target); com
		# RIVAL_COUNT rivais e a API de hoje suportando 1 oponente por
		# chamada, Principal so ataca/prioriza defesa CONTRA rivals[0] —
		# CONFIRMADO como um caso real a partir da Fase 2 (metricas mostram
		# Principal eliminado em boa parte das seeds, NUNCA um rival).
		#
		# LEITURA IMPORTANTE pra quem for usar os numeros deste harness:
		# isso e um ponto cego do HARNESS, nao evidencia de que o jogo de
		# verdade e injusto com o humano. No jogo real, RivalAI.take_turn
		# so precisa de 1 oponente porque so existe UMA relacao por rival
		# (cada rival so luta contra o humano, nunca entre si — ver
		# Diplomacy.gd) e o HUMANO DE VERDADE joga ativamente contra
		# QUALQUER rival visivel via SelectionManager, sem essa limitacao.
		# Aqui, "Principal" e 100% IA e so decide_production/decide_war/
		# take_turn "enxergam" rivals[0] como ameaca — se rivals[1] ou
		# rivals[2] declararem guerra e atacarem, Principal ainda REVIDA
		# (contra-ataque e automatico dentro de CombatResolver.resolve,
		# nao depende do turno do defensor) mas NUNCA prioriza Muralha/
		# exercito em resposta a essa ameaca especifica nem parte pro
		# ataque contra ela. Conclusao pratica: taxa de eliminacao do
		# "Principal" especificamente NAO e uma metrica confiavel de
		# balanceamento enquanto RivalAI continuar sendo 1-oponente-por-
		# chamada; as metricas do lado RIVAL (predios construidos, guerras
		# iniciadas, cidades ganhas) continuam validas, ja que cada rival
		# aqui usa exatamente a mesma chamada 1-pra-1 que o jogo real usa.
		if not rivals.is_empty():
			RivalAI.take_turn(primary, grid, rivals[0])

		_record_turn(m, grid, turn_index, primary, rivals, war_before, cities_before, research_before, campaigns_before)

		if GameManager.state == GameManager.GameState.GAME_OVER:
			m.ended_turn = turn_index + 1
			break
		TurnManager.turn_number += 1

	_finalize_metrics(m, primary, rivals)
	grid.queue_free()
	return m

func _make_player(civ_name: String, race: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = civ_name
	civ.leader_name = civ_name
	civ.race = race
	return PlayerData.new(civ)

func _spawn_capital(grid: HexGrid, player: PlayerData, origin: Vector2i, claimed: Array[Vector2i]) -> void:
	var start := WorldSetup.find_start_tile(grid, origin, claimed)
	claimed.append(start)
	grid.found_city(start, player, player.civ.civ_name + " - Capital")
	var guard := WorldSetup.find_spawn_tile(grid, start)
	grid.spawn_unit(guard, UnitDatabase.create_unit("warrior"), player)

## --- Metricas -----------------------------------------------------------

## Roadmap "Parte D" D1 -- contagem PRECISA da direcao primary->rivals[0]
## (unica onde temos o retorno direto de RivalAI.decide_peace neste
## harness). PEACE_DECISION_NOT_AT_WAR nao conta nada -- e o estado normal
## fora de guerra, nao um evento.
## D3 -- `weariness_at_offer` e o valor de primary.war_weariness capturado
## pelo chamador ANTES de decide_peace rodar (mesmo instante que decide_peace
## le internamente pra comparar com WAR_WEARINESS_OFFER_PEACE_THRESHOLD),
## pra distinguir "recusado com weariness alto" de "recusado com weariness
## baixo" -- weariness_at_peace (acima) so existe quando a guerra JA
## terminou, nao serve pra olhar recusas.
## D3 (revisao) -- `receiver_weariness_at_offer` e rivals[0].war_weariness no
## MESMO instante, o valor que de fato alimenta Diplomacy._accepts_peace do
## lado de quem recebe a oferta (ver comentario no ponto de chamada) --
## weariness_at_offer sozinho nao serve pra checar a mecanica de aceite.
func _record_peace_decision(m: Dictionary, result: String, weariness_at_offer: float, receiver_weariness_at_offer: float) -> void:
	match result:
		RivalAI.PEACE_DECISION_ACCEPTED:
			m.peace_proposals_by_primary.accepted += 1
			m.war_weariness_at_offer.accepted.append(weariness_at_offer)
			m.receiver_weariness_at_offer.accepted.append(receiver_weariness_at_offer)
		RivalAI.PEACE_DECISION_REFUSED:
			m.peace_proposals_by_primary.refused += 1
			m.war_weariness_at_offer.refused.append(weariness_at_offer)
			m.receiver_weariness_at_offer.refused.append(receiver_weariness_at_offer)
		RivalAI.PEACE_DECISION_BELOW_THRESHOLD:
			m.peace_proposals_by_primary.below_threshold += 1
			m.war_weariness_at_offer.below_threshold.append(weariness_at_offer)
			m.receiver_weariness_at_offer.below_threshold.append(receiver_weariness_at_offer)

func _war_pairs(primary: PlayerData, rivals: Array[PlayerData]) -> Dictionary:
	var pairs := {}
	for rival in rivals:
		pairs[rival] = primary.is_at_war_with(rival)
	return pairs

## Roadmap "Parte C" C3 — snapshot PRE-turno do status/alvo da campanha nas
## duas direcoes (primary->rival, rival->primary), mesmo padrao de
## _war_pairs, pra _record_campaign_changes diffar contra o pos-turno.
## target_coord so importa quando status != "" (sem campanha nenhuma).
func _campaign_snapshot(player: PlayerData, opponent: PlayerData) -> Dictionary:
	var campaign: Dictionary = player.war_campaigns.get(opponent, {})
	return {"status": campaign.get("status", ""), "target_coord": campaign.get("target_coord", Vector2i.ZERO)}

func _campaign_status_pairs(primary: PlayerData, rivals: Array[PlayerData]) -> Dictionary:
	var out := {}
	for rival in rivals:
		out[rival] = [_campaign_snapshot(primary, rival), _campaign_snapshot(rival, primary)]
	return out

func _city_counts(primary: PlayerData, rivals: Array[PlayerData]) -> Dictionary:
	var counts := {}
	counts[primary] = primary.cities.size()
	for rival in rivals:
		counts[rival] = rival.cities.size()
	return counts

## Roadmap "Parte B" B3 — snapshot de current_research ANTES do turno, mesmo
## padrao de war_before/cities_before acima. current_research so transiciona
## "" -> tech_id (escolha nova) ou tech_id -> "" (pesquisa completou) — nunca
## pula de uma tech pra outra direto (ver GameManager._process_research/
## RivalAI.decide_research) — entao comparar antes/depois basta pra detectar
## uma escolha nova.
func _research_before(primary: PlayerData, rivals: Array[PlayerData]) -> Dictionary:
	var before := {}
	before[primary] = primary.current_research
	for rival in rivals:
		before[rival] = rival.current_research
	return before

func _new_metrics() -> Dictionary:
	return {
		"first_war_turn": -1,
		"open_wars": {}, # PlayerData(rival) -> turno em que a guerra comecou
		"war_durations": [],
		"last_change_turn": 0, # ultimo turno com guerra nova/terminada OU numero de cidades mudando
		"gold_sum": {}, # PlayerData -> soma acumulada, vira media em _finalize_metrics
		"nan_or_negative_yield": false,
		"ended_turn": -1,
		"known_route_ids": {}, # TradeRoute -> true, so pra contar CRIACAO uma vez (Fase 4A)
		"routes_created": 0,
		"prev_owned_tiles": {}, # City -> Dictionary(coord->true), snapshot do turno anterior (Roadmap 2.0 Parte 1, A1)
		"frontier_claims_total": 0, # A1: tiles NOVOS de territorio por turno (exclui o anel inicial de found_city)
		"frontier_claims_with_resource": 0, # A1: quantos desses tinham recurso
		"frontier_claims_near_lair_danger": 0, # Roadmap 2.0 (fecha Parte A): quantos desses estavam perto de covil perigoso ativo
		"research_choices_total": 0, # Roadmap "Parte B" B3: quantas vezes current_research foi de "" pra uma tech nova nesse turno, qualquer civ
		"research_choices_matching_identity": 0, # B3: dessas, quantas tem eixo derivado com civilization_axis_strength > 0 pra aquela civ
		"campaigns_started": 0, # Roadmap "Parte C" C3: "" -> ACTIVE
		"campaigns_completed": 0, # ACTIVE -> COMPLETED
		"campaigns_abandoned": 0, # ACTIVE -> ABANDONED
		"campaigns_retargeted": 0, # ACTIVE -> ACTIVE com target_coord diferente (invalidacao com substituto)
		"peace_proposals_by_primary": {"accepted": 0, "refused": 0, "below_threshold": 0}, # Roadmap "Parte D" D1 -- so direcao primary->rivals[0], contagem PRECISA (retorno direto de decide_peace)
		"wars_ended_by_peace": 0, # D1 -- diff-based, cobre as DUAS direcoes (ver comentario em _record_turn)
		"war_weariness_at_peace": [], # D1 -- um valor por guerra encerrada
		"war_weariness_at_offer": {"accepted": [], "refused": [], "below_threshold": []}, # Roadmap "Parte D" D3 -- weariness do PRIMARY no momento exato da chamada a decide_peace (antes de qualquer efeito), separado por desfecho -- mesma direcao PRECISA de peace_proposals_by_primary acima
		"receiver_weariness_at_offer": {"accepted": [], "refused": [], "below_threshold": []}, # D3 (revisao) -- weariness de rivals[0] (quem RECEBE a oferta) no mesmo instante -- este, nao o do primary acima, e o valor que Diplomacy._accepts_peace realmente compara contra WAR_WEARINESS_ACCEPTS_PEACE_THRESHOLD
		"war_objective_counts": {}, # D3 -- objetivo (WAR_OBJECTIVE_*) de toda guerra que comeca, contado nas DUAS direcoes por _log_war_target (mesma aproximacao ja aceita ali -- ver comentario da funcao)
		"campaign_start_turn": {}, # D3 -- attacker -> opponent -> turno de inicio, so pra calcular duracao (nao serializado nem lido em nenhum outro lugar)
		"campaign_durations": [], # D3 -- turnos entre ACTIVE e COMPLETED/ABANDONED, uma entrada por campanha encerrada (retargeting NAO reinicia a contagem -- mede o ciclo de vida inteiro ate o desfecho terminal)
		"research_choices_matching_personality": 0, # D3 -- mesmo padrao de research_choices_matching_identity, mas contra o eixo DOMINANTE de player.personality (intencao fixa da partida) em vez de CityIdentity (evidencia historica) -- ver CivilizationPersonality.gd
		"war_objective_decisions": 0, # Roadmap "Parte D" D4.1 -- quantas vezes best_conquer E best_secure_resources existiam os dois (>=1 candidato), primary->rivals[0], TODO turno em paz (nao so quando uma guerra de fato comecava, ao contrario de war_objective_counts acima)
		"war_objective_conquer_wins": 0, # D4.1 -- best_conquer.score > best_secure.score
		"war_objective_secure_wins": 0, # D4.1 -- best_secure.score > best_conquer.score
		"war_objective_ties": 0, # D4.1 -- scores iguais (so acontece quando resource_richness==0 pros dois, ver WAR_OBJECTIVES sobre o desempate de _best_war_objective)
		"war_objective_deltas": [], # D4.1 -- best_secure.score - best_conquer.score, uma entrada por decisao
		"war_objective_selected": {}, # D4.1 -- objective -> quantas vezes RivalAI._best_war_objective (chamado de verdade, nao reimplementado) escolheu aquele objetivo nesta decisao
		"war_objective_components_sum": {RivalAI.WAR_OBJECTIVE_CONQUER: {}, RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES: {}}, # D4.1 -- soma dos componentes (RivalAI._war_target_score_components) do MELHOR candidato de cada objetivo, por decisao -- vira media so no agregado final entre todas as seeds (ver test_simulate_baseline_multi_seed_metrics)
		"war_objective_strength_advantage": [], # Roadmap "Parte D" D4.3 -- um valor por DECISAO (nao por candidato -- e o mesmo pra toda cidade na mesma decisao)
		"war_objective_candidate_samples": 0, # D4.3 -- total de (decisao, candidato) avaliados, denominador de proximity_true/vulnerability_true abaixo
		"war_objective_candidate_resource_richness": [], # D4.3 -- um valor por (decisao, candidato) -- TODOS os candidatos avaliados, nao so o melhor
		"war_objective_candidate_role_fit": [], # D4.3 -- idem
		"war_objective_candidate_proximity_true": 0, # D4.3 -- proximity e BINARIO por construcao (1.0 se <= WAR_PROXIMITY_RANGE, senao 0.0) -- contagem substitui histograma
		"war_objective_candidate_vulnerability_true": 0, # D4.3 -- idem (1.0 se sem muralha)
		"war_objective_selected_raw": {
			RivalAI.WAR_OBJECTIVE_CONQUER: {"resource_richness": [], "proximity": [], "vulnerability": [], "role_fit": []},
			RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES: {"resource_richness": [], "proximity": [], "vulnerability": [], "role_fit": []},
		}, # D4.3 -- fatores crus da cidade EFETIVAMENTE selecionada (RivalAI._best_war_objective), bucketado por qual objetivo venceu -- correlacao fator x objetivo escolhido pedida pelo usuario
	}

## Roadmap 2.0 Parte 1 (A1) — benchmark do bonus de recurso na pontuacao de
## fronteira (FRONTIER_RESOURCE_SCORE_BONUS): quantos dos tiles NOVOS de
## territorio, turno a turno, tinham recurso. Diff contra o snapshot do
## turno anterior por cidade — a primeira vez que uma cidade aparece
## (fundacao, sem snapshot previo) e IGNORADA de proposito, pra nao contar
## o anel inicial de found_city (que nao passa pela pontuacao de
## _claim_frontier_tile) como se fosse uma "escolha" da fronteira.
func _record_frontier_claims(m: Dictionary, grid: HexGrid, primary: PlayerData, rivals: Array[PlayerData]) -> void:
	for player in ([primary] as Array[PlayerData]) + rivals:
		for city in player.cities:
			if m.prev_owned_tiles.has(city):
				var prev: Dictionary = m.prev_owned_tiles[city]
				for coord in city.owned_tiles:
					if not prev.has(coord):
						m.frontier_claims_total += 1
						var data := grid.get_tile(coord)
						if data and data.resource != "":
							m.frontier_claims_with_resource += 1
						if grid.get_lair_danger_at(coord) > 0.0:
							m.frontier_claims_near_lair_danger += 1
			var snapshot := {}
			for coord in city.owned_tiles:
				snapshot[coord] = true
			m.prev_owned_tiles[city] = snapshot

## Roadmap 2.0 Parte 1 (B2) — a cada guerra DECLARADA, imprime cidade-alvo/
## territorio/recursos controlados, pra distinguir depois "IA guerreia por
## causa do recurso" de "IA guerreia porque a cidade e grande" (ressalva
## conhecida do plano — score correlaciona com owned_tiles.size()). So
## impressao no stdout, mesmo padrao observacional do resto deste harness,
## nenhum assert novo. Tenta as DUAS direcoes (attacker->opponent e
## opponent->attacker) porque a transicao pra guerra detectada aqui pode
## ter vindo do lado do `primary` (decide_war manual do harness) OU do
## lado do `rival` (decide_war interno de GameManager._on_turn_changed).
## Roadmap "Parte C" C2 — troca (nao so acrescenta) a busca de alvo por
## RivalAI._best_war_objective: pos-C2, a guerra declarada pode nao mais ser
## contra a cidade mais PROXIMA (pontuacao deixou de ser distancia-
## primaria) — usar _nearest_known_enemy_city aqui de novo mostraria o alvo
## errado. So impressao (objetivo/score), nenhum assert novo, mesmo
## contrato observacional do resto do harness.
## D3 -- alem da impressao, agora tambem tabula best.objective em
## m.war_objective_counts. Herda a MESMA aproximacao ja documentada acima
## (checa as duas direcoes sem saber qual das duas de fato declarou) --
## nao existe hoje um jeito barato de atribuir com precisao, entao o
## agregado conta como "objetivo observado quando uma guerra comeca",
## nao "objetivo que causou aquela guerra especifica".
func _log_war_target(m: Dictionary, grid: HexGrid, primary: PlayerData, rival: PlayerData, turn_number: int) -> void:
	for pair in [[primary, rival], [rival, primary]]:
		var attacker: PlayerData = pair[0]
		var opponent: PlayerData = pair[1]
		var best = RivalAI._best_war_objective(attacker, grid, opponent)
		if best == null:
			continue
		m.war_objective_counts[best.objective] = m.war_objective_counts.get(best.objective, 0) + 1
		var target_city: City = best.city
		var seen := {}
		seen[target_city.coord] = true
		for c in target_city.owned_tiles:
			seen[c] = true
		var resource_count := 0
		for coord in seen.keys():
			var data := grid.get_tile(coord)
			if data and data.resource != "":
				resource_count += 1
		print("[sim guerra T%d] %s -> alvo=%s objetivo=%s territorio=%d recursos_controlados=%d score=%.2f" % [
			turn_number, _label(attacker, primary), target_city.city_name, best.objective, target_city.owned_tiles.size(), resource_count, best.score
		])

## Roadmap "Parte D" D4.1 -- diferente de _log_war_target acima (que so
## dispara quando uma guerra de fato COMECA, amostra pequena e rara),
## esta funcao roda TODO turno em que primary->rivals[0] ainda esta em paz
## (mesma pre-condicao de decide_war, ver ponto de chamada), pra construir
## uma amostra grande o bastante de "o que a formula preferiria agora" e
## responder empiricamente se secure_resources domina por PESO
## (WAR_WEIGHT_RESOURCES_SECURE=2.0) ou por achar cidades melhores.
##
## NUNCA reimplementa a formula: chama RivalAI._score_war_target (score
## autoritativo) e RivalAI._war_target_score_components (termos) direto,
## so duplica a iteracao trivial candidato x objetivo (MESMA estrutura de
## _best_war_objective) pra conseguir o melhor candidato de CADA objetivo
## separadamente -- _best_war_objective de producao so devolve o vencedor
## geral, e mudar seu contrato de retorno so pra telemetria criaria
## acoplamento desnecessario (pedido explicito do usuario). "selected" usa
## RivalAI._best_war_objective DE VERDADE (nunca reimplementa o desempate)
## pra garantir que bate exatamente com o que decide_war usaria.
##
## De proposito SO chamada daqui (contexto de decisao de GUERRA) -- nunca
## de _campaign_still_viable/_advance_campaign, pra nao confundir
## telemetria de manutencao de campanha com uma nova decisao de objetivo
## (pedido explicito do usuario).
func _record_war_objective_decision(m: Dictionary, hex_grid: HexGrid, player: PlayerData, opponent: PlayerData) -> void:
	var candidates := RivalAI._known_enemy_cities_of(player, opponent, hex_grid)
	if candidates.is_empty():
		return

	var own_strength := RivalAI._total_military_strength(player)
	var enemy_strength := RivalAI._total_military_strength(opponent)
	var strength_advantage: float = clamp((own_strength - enemy_strength) / max(own_strength + enemy_strength, 1.0), -1.0, 1.0)
	var role_counts := RivalAI._role_counts(player)

	var best_score_by_objective := {}
	var best_city_by_objective := {}
	for city in candidates:
		for objective in RivalAI.WAR_OBJECTIVES:
			var score: float = RivalAI._score_war_target(player, hex_grid, city, objective, strength_advantage, role_counts)
			if not best_score_by_objective.has(objective) or score > best_score_by_objective[objective]:
				best_score_by_objective[objective] = score
				best_city_by_objective[objective] = city

	# Nunca deveria disparar -- WAR_OBJECTIVES sempre tem os dois e todo
	# candidato e avaliado nos dois -- guarda so por seguranca.
	if not best_score_by_objective.has(RivalAI.WAR_OBJECTIVE_CONQUER) or not best_score_by_objective.has(RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES):
		return

	var conquer_score: float = best_score_by_objective[RivalAI.WAR_OBJECTIVE_CONQUER]
	var secure_score: float = best_score_by_objective[RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES]
	var conquer_components := RivalAI._war_target_score_components(player, hex_grid, best_city_by_objective[RivalAI.WAR_OBJECTIVE_CONQUER], RivalAI.WAR_OBJECTIVE_CONQUER, strength_advantage, role_counts)
	var secure_components := RivalAI._war_target_score_components(player, hex_grid, best_city_by_objective[RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES], RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES, strength_advantage, role_counts)
	var selected = RivalAI._best_war_objective(player, hex_grid, opponent)

	m.war_objective_decisions += 1
	var delta: float = secure_score - conquer_score
	m.war_objective_deltas.append(delta)
	if delta > 0.0:
		m.war_objective_secure_wins += 1
	elif delta < 0.0:
		m.war_objective_conquer_wins += 1
	else:
		m.war_objective_ties += 1
	m.war_objective_selected[selected.objective] = m.war_objective_selected.get(selected.objective, 0) + 1
	_accumulate_components(m.war_objective_components_sum[RivalAI.WAR_OBJECTIVE_CONQUER], conquer_components)
	_accumulate_components(m.war_objective_components_sum[RivalAI.WAR_OBJECTIVE_SECURE_RESOURCES], secure_components)

	# Roadmap "Parte D" D4.3 -- diagnostico dos fatores CRUS (pre-peso),
	# pedido explicito do usuario: "o problema e resources excessivamente
	# dominante, role_fit raramente aplicavel, binarizacao de proximity/
	# vulnerability, ou a natureza dos alvos disponiveis?". strength_
	# advantage e por DECISAO (player vs opponent, nao muda por cidade);
	# os outros 4 sao por CANDIDATO (RivalAI._war_target_raw_factors, MESMA
	# funcao que _war_target_score_components agora reusa -- nunca
	# reimplementa nenhum termo). Amostra TODOS os candidatos avaliados
	# nesta decisao, nao so os dois melhores, pra descrever o pool real de
	# alvos -- e separadamente a cidade que FOI selecionada, pra
	# correlacionar fator x objetivo escolhido.
	m.war_objective_strength_advantage.append(strength_advantage)
	for city in candidates:
		var raw := RivalAI._war_target_raw_factors(player, hex_grid, city, role_counts)
		m.war_objective_candidate_samples += 1
		m.war_objective_candidate_resource_richness.append(raw.resource_richness)
		m.war_objective_candidate_role_fit.append(raw.role_fit)
		if raw.proximity > 0.0:
			m.war_objective_candidate_proximity_true += 1
		if raw.vulnerability > 0.0:
			m.war_objective_candidate_vulnerability_true += 1
	var selected_raw := RivalAI._war_target_raw_factors(player, hex_grid, selected.city, role_counts)
	var selected_bucket: Dictionary = m.war_objective_selected_raw[selected.objective]
	selected_bucket.resource_richness.append(selected_raw.resource_richness)
	selected_bucket.proximity.append(selected_raw.proximity)
	selected_bucket.vulnerability.append(selected_raw.vulnerability)
	selected_bucket.role_fit.append(selected_raw.role_fit)

func _accumulate_components(sum: Dictionary, components: Dictionary) -> void:
	for key in components.keys():
		sum[key] = sum.get(key, 0.0) + components[key]

## Roadmap "Parte B" B3 — deteccao da transicao "" -> tech_id por civ por
## turno (current_research so transiciona assim, ou de volta pra "" quando
## a pesquisa completa — nunca pula de uma tech pra outra direto), MESMO
## padrao de diff turno-a-turno de _record_frontier_claims (snapshot do
## turno anterior, aqui research_before em vez de prev_owned_tiles). So
## observacional (research_choices_total/matching_identity), nenhum assert
## de comportamento — mesma disciplina do resto deste harness.
## D3 — acrescenta matching_personality NA MESMA passada, mesmo contrato
## (transicao "" -> tech_id), pra comparar os dois termos independentes que
## RivalAI._score_research_candidate soma (RESEARCH_WEIGHT_IDENTITY vs
## RESEARCH_WEIGHT_PERSONALITY): identidade e "o que a cidade ja construiu"
## (CityIdentity, retrospectivo), personalidade e "a intencao sorteada pra
## partida inteira" (CivilizationPersonality, ver _dominant_personality_axis
## abaixo). Os dois podem divergir por civ (ex.: um Anao com personalidade
## comercial que build errou pro industrial por pressao de guerra).
func _record_research_choices(m: Dictionary, research_before: Dictionary, primary: PlayerData, rivals: Array[PlayerData]) -> void:
	for player in ([primary] as Array[PlayerData]) + rivals:
		var before: String = research_before.get(player, "")
		if before == "" and player.current_research != "":
			m.research_choices_total += 1
			var tech := TechDatabase.get_tech(player.current_research)
			if tech:
				var axis := RivalAI._tech_identity_axis(tech)
				if axis != "" and CityIdentity.civilization_axis_strength(player, axis) > 0.0:
					m.research_choices_matching_identity += 1
				if axis != "" and axis == _dominant_personality_axis(player):
					m.research_choices_matching_personality += 1

## D3 — eixo de MAIOR player.personality (CivilizationPersonality.generate,
## intencao fixa sorteada uma vez por partida), "" se todos os eixos
## ficarem em 0.0 (na pratica quase nunca, ver JITTER_RANGE). Desempate
## IDENTICO a CityIdentity.dominant_axis: primeiro de AXES na ordem
## declarada, comparacao ESTRITA ">" (nao ">=").
func _dominant_personality_axis(player: PlayerData) -> String:
	var best_axis := ""
	var best_strength := 0.0
	for axis in CityIdentity.AXES:
		var strength: float = player.personality.get(axis, 0.0)
		if strength > best_strength:
			best_strength = strength
			best_axis = axis
	return best_axis

## Roadmap "Parte C" C3 — diff PRE/POS-turno do status/alvo de campanha nas
## duas direcoes (primary->rival, rival->primary), mesmo padrao dual-direcao
## de _log_war_target. So impressao/contagem, nenhum assert novo (contrato
## observacional de sempre).
## D3 — duracao em turnos entre o inicio registrado em m.campaign_start_turn
## (por _record_campaign_changes, no exato turno em que virou ACTIVE) e o
## turno terminal atual (COMPLETED ou ABANDONED). Silenciosamente no-op se
## nao houver inicio registrado (nao deveria acontecer no fluxo normal, mas
## harness nao deve travar/assertar em cima de um buraco de instrumentacao).
func _record_campaign_duration(m: Dictionary, attacker: PlayerData, opponent: PlayerData, turn_number: int) -> void:
	var by_opponent: Dictionary = m.campaign_start_turn.get(attacker, {})
	if not by_opponent.has(opponent):
		return
	m.campaign_durations.append(turn_number - by_opponent[opponent])

func _record_campaign_changes(m: Dictionary, primary: PlayerData, rivals: Array[PlayerData], campaigns_before: Dictionary, turn_number: int) -> void:
	for rival in rivals:
		var directions = [[primary, rival, campaigns_before[rival][0]], [rival, primary, campaigns_before[rival][1]]]
		for entry in directions:
			var attacker: PlayerData = entry[0]
			var opponent: PlayerData = entry[1]
			var before: Dictionary = entry[2]
			var before_status: String = before.status
			var now := _campaign_snapshot(attacker, opponent)
			var now_status: String = now.status
			if before_status != RivalAI.CAMPAIGN_STATUS_ACTIVE and now_status == RivalAI.CAMPAIGN_STATUS_ACTIVE:
				# Cobre tanto a PRIMEIRA campanha (before_status=="") quanto
				# uma NOVA instancia nascendo depois de uma terminal
				# (COMPLETED/ABANDONED, ver contrato de decide_campaign) --
				# sem isso, campanhas reiniciadas ficavam silenciosamente de
				# fora da contagem de "iniciada" (achado real do harness:
				# concluidas > iniciadas antes deste fix).
				m.campaigns_started += 1
				if not m.campaign_start_turn.has(attacker):
					m.campaign_start_turn[attacker] = {}
				m.campaign_start_turn[attacker][opponent] = turn_number # D3 -- pra _record_campaign_duration medir o ciclo de vida inteiro ate o desfecho terminal
				print("[sim campanha T%d] %s -> alvo=%s status=iniciada" % [turn_number, _label(attacker, primary), now.target_coord])
			elif before_status == RivalAI.CAMPAIGN_STATUS_ACTIVE and now_status == RivalAI.CAMPAIGN_STATUS_COMPLETED:
				m.campaigns_completed += 1
				_record_campaign_duration(m, attacker, opponent, turn_number)
				print("[sim campanha T%d] %s -> alvo=%s status=concluida" % [turn_number, _label(attacker, primary), now.target_coord])
			elif before_status == RivalAI.CAMPAIGN_STATUS_ACTIVE and now_status == RivalAI.CAMPAIGN_STATUS_ABANDONED:
				m.campaigns_abandoned += 1
				_record_campaign_duration(m, attacker, opponent, turn_number)
				print("[sim campanha T%d] %s -> alvo=%s status=abandonada" % [turn_number, _label(attacker, primary), before.target_coord])
			elif before_status == RivalAI.CAMPAIGN_STATUS_ACTIVE and now_status == RivalAI.CAMPAIGN_STATUS_ACTIVE and before.target_coord != now.target_coord:
				m.campaigns_retargeted += 1
				print("[sim campanha T%d] %s -> alvo=%s status=redirecionada" % [turn_number, _label(attacker, primary), now.target_coord])

func _record_turn(m: Dictionary, grid: HexGrid, turn_index: int, primary: PlayerData, rivals: Array[PlayerData], war_before: Dictionary, cities_before: Dictionary, research_before: Dictionary, campaigns_before: Dictionary) -> void:
	var turn_number := turn_index + 1
	var any_change := false

	for rival in rivals:
		var now_at_war: bool = primary.is_at_war_with(rival)
		var was_at_war: bool = war_before[rival]
		if now_at_war and not was_at_war:
			any_change = true
			if m.first_war_turn == -1:
				m.first_war_turn = turn_number
			m.open_wars[rival] = turn_number
			_log_war_target(m, grid, primary, rival, turn_number)
		elif was_at_war and not now_at_war:
			any_change = true
			var started: int = m.open_wars.get(rival, turn_number)
			m.war_durations.append(turn_number - started)
			m.open_wars.erase(rival)
			# Roadmap "Parte D" D1 -- neste harness, NENHUM outro caminho
			# alem de RivalAI.decide_peace chama Diplomacy.propose_peace
			# (nao ha UI/clique humano aqui), entao toda guerra que termina
			# e por construcao um encerramento AUTONOMO -- cobre as duas
			# direcoes (primary->rival E rival->primary), diferente de
			# peace_proposals_by_primary acima (so uma direcao, contagem
			# precisa). Weariness capturada AQUI ja reflete o upkeep deste
			# MESMO turno (GameManager._on_turn_changed ja rodou antes de
			# _record_turn) -- proxy aproximado do momento da decisao, nao
			# o valor exato que decide_peace viu (que era o de T-1).
			m.wars_ended_by_peace += 1
			m.war_weariness_at_peace.append(max(primary.war_weariness, rival.war_weariness))

	if primary.cities.size() != cities_before[primary]:
		any_change = true
	for rival in rivals:
		if rival.cities.size() != cities_before[rival]:
			any_change = true

	_record_frontier_claims(m, grid, primary, rivals)
	_record_research_choices(m, research_before, primary, rivals)
	_record_campaign_changes(m, primary, rivals, campaigns_before, turn_number)

	# Comercio (Fase 4A) — so conta CRIACAO uma vez por rota (a mesma
	# TradeRoute aparece na lista dos 2 lados, ver Dictionary como set).
	var all_routes := {}
	for player in ([primary] as Array[PlayerData]) + rivals:
		for route in player.trade_routes:
			all_routes[route] = true
	for route in all_routes.keys():
		if not m.known_route_ids.has(route):
			m.known_route_ids[route] = true
			m.routes_created += 1

	for player in ([primary] as Array[PlayerData]) + rivals:
		if not m.gold_sum.has(player):
			m.gold_sum[player] = 0.0
		m.gold_sum[player] += player.gold
		if is_nan(player.gold) or player.gold < 0.0:
			m.nan_or_negative_yield = true
		if is_nan(player.mana) or player.mana < 0.0:
			m.nan_or_negative_yield = true
		for city in player.cities:
			if is_nan(city.stored_production) or city.stored_production < 0.0:
				m.nan_or_negative_yield = true
			if is_nan(city.stored_food) or city.stored_food < 0.0:
				m.nan_or_negative_yield = true

	if any_change:
		m.last_change_turn = turn_number

func _finalize_metrics(m: Dictionary, primary: PlayerData, rivals: Array[PlayerData]) -> void:
	var final_turn: int = m.ended_turn if m.ended_turn != -1 else TURN_COUNT
	# Guerra ainda aberta no fim da simulacao conta com duracao ate o
	# ultimo turno rodado, em vez de ficar de fora da media.
	for rival in m.open_wars.keys():
		m.war_durations.append(final_turn - m.open_wars[rival])
	m.war_count = m.war_durations.size()

	m.buildings_built = {}
	m.final_cities = {}
	m.avg_gold = {}
	m.eliminated = []
	# Roadmap "Parte B" (B1/B2) — distribuicao observacional de dominant_
	# axis entre TODAS as cidades finais (humano + rivais juntos), mesmo
	# padrao "so pra olhar" das metricas de fronteira/comercio acima — nao
	# ha comportamento "certo" prometido ainda pra travar um assert em
	# cima. Interessa em particular ver se arcana (balde de 6 predios)
	# fica estruturalmente rara perto de agricola/industrial/comercial
	# (baldes de 1 predio cada, chegam a dominante com um unico predio).
	m.dominant_axis_counts = {}
	for player in ([primary] as Array[PlayerData]) + rivals:
		var label := _label(player, primary)
		var total_buildings := 0
		for city in player.cities:
			total_buildings += city.buildings.size()
			var axis := CityIdentity.dominant_axis(city)
			var key: String = axis if axis != "" else "generalista"
			m.dominant_axis_counts[key] = m.dominant_axis_counts.get(key, 0) + 1
		m.buildings_built[label] = total_buildings
		m.final_cities[label] = player.cities.size()
		m.avg_gold[label] = m.gold_sum.get(player, 0.0) / float(final_turn)
		if player.units.is_empty() and player.cities.is_empty():
			m.eliminated.append(label)

	m.stagnant = m.eliminated.is_empty() and (final_turn - m.last_change_turn) >= STAGNATION_WINDOW

	# Roadmap "Parte C" (composicao de exercito), C1 — RivalAI._role_counts
	# no exercito FINAL de cada rival (estado derivado, mesmo helper usado
	# de verdade por decide_production — nao uma reimplementacao paralela).
	# So dos rivais de proposito, ver comentario do bloco agregado abaixo.
	m.rival_role_counts = {}
	for rival in rivals:
		m.rival_role_counts[_label(rival, primary)] = RivalAI._role_counts(rival)

	# Roadmap "Parte C" C3 — distribuicao FINAL de status de campanha (rival
	# -> human, so dos rivais, mesmo motivo de rival_role_counts acima: o
	# "Principal" tem o ponto cego documentado de 1-oponente-por-chamada) —
	# so observacao, nenhuma distribuicao "certa" decidida a priori (ver
	# bloco agregado em test_simulate_baseline_multi_seed_metrics).
	m.final_campaign_status = {}
	for rival in rivals:
		var status: String = rival.war_campaigns.get(primary, {}).get("status", "sem_campanha")
		m.final_campaign_status[status] = m.final_campaign_status.get(status, 0) + 1

	# Roadmap 2.0 Parte 1 (A1) — "n/a" quando nenhum tile de fronteira foi
	# reivindicado na simulacao inteira (nada pra medir), em vez de dividir
	# por zero.
	if m.frontier_claims_total > 0:
		m.frontier_claim_resource_pct = "%.0f%%" % (100.0 * float(m.frontier_claims_with_resource) / float(m.frontier_claims_total))
		m.frontier_claim_lair_danger_pct = "%.0f%%" % (100.0 * float(m.frontier_claims_near_lair_danger) / float(m.frontier_claims_total))
	else:
		m.frontier_claim_resource_pct = "n/a"
		m.frontier_claim_lair_danger_pct = "n/a"

	# Roadmap "Parte B" B3 — responde empiricamente "com o peso inicial
	# (RESEARCH_WEIGHT_IDENTITY=0.2), quanto a identidade realmente
	# influencia a pesquisa?": ~0% seria irrelevante, ~90% seria trilho
	# disfarcado. Teto estrutural real fica abaixo de 100% de qualquer
	# forma (7 das 21 techs nao tem eixo de identidade nenhum).
	m.research_choice_identity_match_pct = (float(m.research_choices_matching_identity) / float(m.research_choices_total)) if m.research_choices_total > 0 else 0.0

	# Comercio (Fase 4A) — "rotas ativas no fim" + "canceladas" (criadas
	# menos ainda-ativas, proxy simples: nao distingue guerra de outra
	# causa de cancelamento, mas basta pra observacao desta fase).
	var final_routes := {}
	for player in ([primary] as Array[PlayerData]) + rivals:
		for route in player.trade_routes:
			final_routes[route] = true
	m.routes_active_at_end = final_routes.size()
	m.routes_cancelled = m.routes_created - m.routes_active_at_end

func _label(player: PlayerData, primary: PlayerData) -> String:
	if player == primary:
		return "Principal(%s)" % player.civ.race
	return "%s(%s)" % [player.civ.civ_name, player.civ.race]

func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / float(values.size())

## Roadmap "Parte D" D4.1 -- media sozinha esconde distribuicao bimodal
## (pedido explicito do usuario: "nao somente a media"); mediana complementa
## sem precisar decidir bins definitivos antecipadamente.
func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var count := sorted_values.size()
	if count % 2 == 1:
		return sorted_values[count / 2]
	return (sorted_values[count / 2 - 1] + sorted_values[count / 2]) / 2.0

## Roadmap "Parte D" D4.3 -- histograma por VALOR EXATO (chave formatada
## "%.2f", nao faixa), pra fatores DISCRETOS por construcao (resource_
## richness/role_fit sao count/NORM clampado -- um punhado de valores
## possiveis, nao um continuo de verdade). Bins de faixa (ver strength_
## bins em test_simulate_baseline_multi_seed_metrics) so fazem sentido pra
## fator genuinamente continuo.
func _histogram(values: Array) -> Dictionary:
	var hist := {}
	for v in values:
		var key := "%.2f" % v
		hist[key] = hist.get(key, 0) + 1
	return hist
