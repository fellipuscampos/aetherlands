class_name V2DoctrineTechniqueDatabase
extends RefCounted

## Registro das Técnicas Militares de Doutrina do V2 (Fase 4) — dirigido por dados,
## mesmo padrão de BuildingDatabase/UnitDatabase (cache montado uma vez por sessão).
##
## Existem a Muralha de Escudos (ATIVA, Fase 4), Preparar Lanças (PASSIVA, Fase 5) e, Fase 7, o
## Golpe Poderoso e o Ataque em Arco (ATIVAS de ATAQUE, do Guerreiro). As demais técnicas
## continuam metadata em V2DoctrineContent até uma fase conectá-las: entrar aqui é o que faz uma
## técnica existir no jogo, e o id também precisa entrar em V2DoctrineContent.CONNECTED_UNLOCK_IDS.

## Rótulo (plural, já com "unidades"/substantivo próprio) de cada traço de UnitData usado nos textos de bônus "contra ...".
const TRAIT_PLURAL_LABELS := {"mounted": "unidades montadas", "caster": "conjuradores", "siege": "unidades de Cerco"}

const SHIELD_WALL := "v2_technique_shield_wall"
const BRACE_SPEARS := "v2_technique_brace_spears"
const POWER_STRIKE := "v2_technique_power_strike"
const CLEAVE := "v2_technique_cleave"
const PRECISE_SHOT := "v2_technique_precise_shot"
const VOLLEY := "v2_technique_volley"
const CHARGE := "v2_technique_charge"
const TACTICAL_RETREAT := "v2_technique_tactical_retreat"
const SNEAK_ATTACK := "v2_technique_sneak_attack"
const DISMANTLE := "v2_technique_dismantle"
const DEMOLITION_AMMO := "v2_technique_demolition_ammo"
const PREPARED_BOMBARDMENT := "v2_technique_prepared_bombardment"

static var _cache: Dictionary = {} # id -> V2DoctrineTechniqueData

static func _build_all() -> Dictionary:
	var techniques := {}

	# MURALHA DE ESCUDOS (nó v2_doctrine_guardian_4) — BALANCE PLACEHOLDER.
	# Ativação manual, zero Mana/Ouro, gasta a ação e zera o movimento restante.
	# Até o início do próximo turno do dono: +35% Defesa na própria unidade e +15%
	# nos aliados adjacentes (por formação, ver V2TechniqueRuntime.defense_multiplier;
	# nunca acumula: vale só o maior bônus da mesma técnica). Recarga de 3 turnos.
	var shield_wall := V2DoctrineTechniqueData.new()
	shield_wall.id = SHIELD_WALL
	shield_wall.doctrine_branch = "guardian"
	shield_wall.cooldown_turns = 3
	shield_wall.self_defense_bonus = 0.35
	shield_wall.adjacent_ally_defense_bonus = 0.15
	shield_wall.adjacent_radius = 1
	techniques[shield_wall.id] = shield_wall

	# PREPARAR LANÇAS (nó v2_doctrine_guardian_6) — PASSIVA, BALANCE PLACEHOLDER. Treinamento
	# permanente contra tropas montadas: +50% de dano de ATAQUE BÁSICO contra alvos com o traço
	# `mounted`, pra toda unidade da linha (Escudeiro, Guardião, Sentinela) de uma civilização
	# com o nó pesquisado. Sem botão, custo, recarga, duração nem estado guardado.
	var brace_spears := V2DoctrineTechniqueData.new()
	brace_spears.id = BRACE_SPEARS
	brace_spears.doctrine_branch = "guardian"
	brace_spears.activation_mode = V2DoctrineTechniqueData.ActivationMode.PASSIVE
	brace_spears.cooldown_turns = 0
	brace_spears.consumes_action = false
	brace_spears.basic_attack_bonus = 0.5
	brace_spears.basic_attack_target_traits = [UnitData.TRAIT_MOUNTED]
	techniques[brace_spears.id] = brace_spears

	# GOLPE PODEROSO (nó v2_doctrine_warrior_4) — ATIVA de ATAQUE, BALANCE PLACEHOLDER. Um ataque melee
	# ESPECIAL contra UM inimigo adjacente escolhido pelo jogador, resolvido na hora pelo combate normal com
	# 1,60x o Ataque. Gasta a ação e zera o movimento restante; recarga de 3 turnos; zero Mana/Ouro.
	var power_strike := V2DoctrineTechniqueData.new()
	power_strike.id = POWER_STRIKE
	power_strike.doctrine_branch = "warrior"
	power_strike.cooldown_turns = 3
	power_strike.strike_multiplier = 1.6
	power_strike.strike_targeting = V2DoctrineTechniqueData.StrikeTargeting.SINGLE_TARGET
	power_strike.strike_max_targets = 1
	techniques[power_strike.id] = power_strike

	# ATAQUE EM ARCO (nó v2_doctrine_warrior_6, unlock `cleave`) — ATIVA de ATAQUE, BALANCE PLACEHOLDER. Sem
	# mira: atinge até 3 inimigos ADJACENTES, cada um com uma resolução de combate normal a 0,75x o Ataque.
	# Gasta a ação; recarga de 4 turnos; zero Mana/Ouro. Com mais de 3 alvos: menor HP% primeiro, desempate
	# pelo menor serial_id.
	var cleave := V2DoctrineTechniqueData.new()
	cleave.id = CLEAVE
	cleave.doctrine_branch = "warrior"
	cleave.cooldown_turns = 4
	cleave.strike_multiplier = 0.75
	cleave.strike_targeting = V2DoctrineTechniqueData.StrikeTargeting.ADJACENT_ENEMIES
	cleave.strike_max_targets = 3
	techniques[cleave.id] = cleave

	# DISPARO PRECISO (nó v2_doctrine_ranger_4) — ATIVA de ataque à distância, BALANCE PLACEHOLDER. Um ataque de UM alvo à
	# escolha do jogador com alcance BÁSICO + 1 (Arqueiro 3, Atirador de Elite 4), 1,40x o Ataque, pelo combate normal. Gasta
	# a ação e zera o movimento; recarga de 3 turnos; zero Mana/Ouro. Alcance por DADO (ATTACK_RANGE_PLUS), não por id.
	var precise_shot := V2DoctrineTechniqueData.new()
	precise_shot.id = PRECISE_SHOT
	precise_shot.doctrine_branch = "ranger"
	precise_shot.cooldown_turns = 3
	precise_shot.strike_multiplier = 1.4
	precise_shot.strike_targeting = V2DoctrineTechniqueData.StrikeTargeting.SINGLE_TARGET
	precise_shot.strike_max_targets = 1
	precise_shot.strike_range_mode = V2DoctrineTechniqueData.StrikeRangeMode.ATTACK_RANGE_PLUS
	precise_shot.strike_range = 1
	techniques[precise_shot.id] = precise_shot

	# SARAIVADA (nó v2_doctrine_ranger_6, unlock `volley`) — ATIVA de ataque à distância em AGRUPAMENTO, BALANCE PLACEHOLDER.
	# O jogador escolhe um alvo PRIMÁRIO dentro do alcance BÁSICO (sem o +1 do Disparo Preciso); ele sempre entra e o golpe
	# atinge também os inimigos a 1 tile dele, no máximo 3 no total, cada um com 0,70x o Ataque e a própria resolução de
	# combate. Anti-unidade. Gasta a ação; recarga de 4 turnos; zero Mana/Ouro.
	var volley := V2DoctrineTechniqueData.new()
	volley.id = VOLLEY
	volley.doctrine_branch = "ranger"
	volley.cooldown_turns = 4
	volley.strike_multiplier = 0.7
	volley.strike_targeting = V2DoctrineTechniqueData.StrikeTargeting.TARGET_AND_NEIGHBORS
	volley.strike_max_targets = 3
	volley.strike_range_mode = V2DoctrineTechniqueData.StrikeRangeMode.ATTACK_RANGE_PLUS
	volley.strike_range = 0
	volley.strike_splash_radius = 1
	techniques[volley.id] = volley

	# CARGA (nó v2_doctrine_cavalry_4) — ATIVA de MOVER-E-ATACAR, BALANCE PLACEHOLDER. O jogador escolhe um inimigo a 2..4 tiles; a unidade percorre a rota real
	# (terreno, bloqueios e ocupação do perfil dela) até um tile livre adjacente e o ataca na mesma ação com 1,50x o Ataque, pelo combate normal (revide incluso).
	# Não pode ser usada contra um inimigo já adjacente (precisa de espaço). Gasta a ação e zera o movimento; recarga de 3 turnos; zero Mana/Ouro.
	var charge := V2DoctrineTechniqueData.new()
	charge.id = CHARGE
	charge.doctrine_branch = "cavalry"
	charge.cooldown_turns = 3
	charge.strike_multiplier = 1.5
	charge.strike_targeting = V2DoctrineTechniqueData.StrikeTargeting.SINGLE_TARGET
	charge.strike_max_targets = 1
	charge.strike_range_mode = V2DoctrineTechniqueData.StrikeRangeMode.FIXED
	charge.strike_range = 4
	charge.strike_min_range = 2
	charge.strike_reposition = V2DoctrineTechniqueData.StrikeReposition.MOVE_ADJACENT_TO_TARGET
	techniques[charge.id] = charge

	# RETIRADA TÁTICA (nó v2_doctrine_cavalry_6) — ATIVA de REPOSICIONAMENTO por TILE, BALANCE PLACEHOLDER. O jogador escolhe um tile livre a até 3 passos (cada passo
	# conta 1: o custo do terreno não reduz o alcance; o impassável e a ocupação valem); a unidade se desloca de verdade e, ao chegar, recebe +20% de Defesa até o
	# início do próximo turno do dono (o mesmo estado temporário da Muralha). Gasta a ação; recarga de 4 turnos; zero Mana/Ouro. Sem Zona de Controle (não existe).
	var retreat := V2DoctrineTechniqueData.new()
	retreat.id = TACTICAL_RETREAT
	retreat.doctrine_branch = "cavalry"
	retreat.cooldown_turns = 4
	retreat.target_mode = V2DoctrineTechniqueData.TargetMode.TILE
	retreat.relocate_range = 3
	retreat.relocate_flat_cost = true
	retreat.self_defense_bonus = 0.2
	techniques[retreat.id] = retreat

	# ATAQUE FURTIVO (nó v2_doctrine_rogue_4) — ATIVA de ATAQUE, BALANCE PLACEHOLDER. Ataque melee de assassinato contra UM inimigo ADJACENTE à escolha
	# do jogador: 1,35x o Ataque, com 40% de PENETRAÇÃO DE DEFESA (só 60% da Defesa do alvo conta NESTE golpe — campo genérico, ver
	# V2DoctrineTechniqueData.strike_defense_penetration/CombatResolver.predict) e SEM REVIDE desta resolução (strike_prevents_counterattack: o alvo,
	# se sobreviver, continua sem nenhum status, livre pra agir no próprio turno). Gasta a ação e zera o movimento; recarga de 3 turnos; zero Mana/Ouro.
	var sneak_attack := V2DoctrineTechniqueData.new()
	sneak_attack.id = SNEAK_ATTACK
	sneak_attack.doctrine_branch = "rogue"
	sneak_attack.cooldown_turns = 3
	sneak_attack.strike_multiplier = 1.35
	sneak_attack.strike_targeting = V2DoctrineTechniqueData.StrikeTargeting.SINGLE_TARGET
	sneak_attack.strike_max_targets = 1
	sneak_attack.strike_defense_penetration = 0.4
	sneak_attack.strike_prevents_counterattack = true
	techniques[sneak_attack.id] = sneak_attack

	# DESMANTELAR (nó v2_doctrine_rogue_6) — PASSIVA, BALANCE PLACEHOLDER. Treinamento especializado contra alvos técnicos: +50% de dano de ATAQUE
	# BÁSICO (e de qualquer golpe físico da linha, ex.: Ataque Furtivo — mesma cadeia de UnitAbilities.attack_multiplier) contra alvos com QUALQUER um
	# dos traços `caster` ou `siege` (uma vez, mesmo com os dois: basic_attack_target_traits é uma LISTA, generalização da Fase 10 — ver
	# V2TechniqueRuntime._has_any_trait), pra toda unidade da linha do Ladino de uma civilização com o nó pesquisado. Sem botão, custo, recarga,
	# duração nem estado guardado. Quando existirem conjuradores/máquinas de Cerco V2, basta declararem o traço — nada aqui os conhece.
	var dismantle := V2DoctrineTechniqueData.new()
	dismantle.id = DISMANTLE
	dismantle.doctrine_branch = "rogue"
	dismantle.activation_mode = V2DoctrineTechniqueData.ActivationMode.PASSIVE
	dismantle.cooldown_turns = 0
	dismantle.consumes_action = false
	dismantle.basic_attack_bonus = 0.5
	dismantle.basic_attack_target_traits = [UnitData.TRAIT_CASTER, UnitData.TRAIT_SIEGE]
	techniques[dismantle.id] = dismantle

	# MUNIÇÃO DEMOLIDORA (nó v2_doctrine_siege_4) — PASSIVA, BALANCE PLACEHOLDER. Treinamento especializado contra fortificações:
	# +40% de dano de ATAQUE DE CERCO (ataque básico de Cerco contra cidade E Bombardeio Preparado — mesma cadeia de
	# V2TechniqueRuntime.city_attack_multiplier, entra dentro da MESMA fórmula de CombatResolver.resolve_city_attack) pra toda
	# unidade da linha de Cerco de uma civilização com o nó pesquisado. Sem botão, custo, recarga, duração nem estado guardado.
	# NUNCA vale contra unidade, monstro, covil, feitiço nem dano ambiental — só ataque de Cerco contra cidade/fortificação.
	var demolition_ammo := V2DoctrineTechniqueData.new()
	demolition_ammo.id = DEMOLITION_AMMO
	demolition_ammo.doctrine_branch = "siege"
	demolition_ammo.activation_mode = V2DoctrineTechniqueData.ActivationMode.PASSIVE
	demolition_ammo.cooldown_turns = 0
	demolition_ammo.consumes_action = false
	demolition_ammo.city_attack_bonus = 0.4
	techniques[demolition_ammo.id] = demolition_ammo

	# BOMBARDEIO PREPARADO (nó v2_doctrine_siege_6) — ATIVA de ATAQUE DE CERCO CONTRA CIDADE/FORTIFICAÇÃO, BALANCE PLACEHOLDER.
	# O jogador escolhe uma cidade hostil à sua escolha, ao alcance BÁSICO + 1 (Catapulta/Trebuchet 3, Bombarda/Colosso 4),
	# resolvida pelo MESMO CombatResolver.resolve_city_attack de sempre com 1,50x o Ataque (strike_multiplier — Munição
	# Demolidora, se pesquisada, multiplica por cima, nunca uma segunda fórmula). EXIGE PREPARAÇÃO: a unidade não pode ter se
	# movido neste turno (strike_requires_undisturbed — derivado de movement_left == movement_points, nada salvo); o Colosso
	# de Cerco ignora ESTE requisito específico por dado (UnitData.ignores_technique_stationary_requirement — Artilharia
	# Andante), sem ganhar ação extra. Gasta a ação e zera o movimento; recarga de 4 turnos; zero Mana/Ouro. NUNCA mira
	# unidade nem monstro — só cidade/fortificação hostil (target_mode CITY).
	var prepared_bombardment := V2DoctrineTechniqueData.new()
	prepared_bombardment.id = PREPARED_BOMBARDMENT
	prepared_bombardment.doctrine_branch = "siege"
	prepared_bombardment.cooldown_turns = 4
	prepared_bombardment.strike_multiplier = 1.5
	prepared_bombardment.strike_targeting = V2DoctrineTechniqueData.StrikeTargeting.SINGLE_TARGET
	prepared_bombardment.strike_max_targets = 1
	prepared_bombardment.strike_range_mode = V2DoctrineTechniqueData.StrikeRangeMode.ATTACK_RANGE_PLUS
	prepared_bombardment.strike_range = 1
	prepared_bombardment.target_mode = V2DoctrineTechniqueData.TargetMode.CITY
	prepared_bombardment.strike_requires_undisturbed = true
	techniques[prepared_bombardment.id] = prepared_bombardment

	# Nome vindo do nó de pesquisa (fonte única do conteúdo canônico).
	for technique in techniques.values():
		var node := V2ResearchDatabase.node_for_unlock_id(technique.id)
		technique.display_name = node.display_name if node != null else technique.id
		technique.description = _describe(technique)
	return techniques

static func _all() -> Dictionary:
	if _cache.is_empty():
		_cache = _build_all()
	return _cache

static func get_technique(id: String) -> V2DoctrineTechniqueData:
	return _all().get(id, null)

static func all_techniques() -> Array:
	return _all().values()

## As técnicas de uma linha de Doutrina (ex.: "guardian").
static func for_branch(branch: String) -> Array[V2DoctrineTechniqueData]:
	var result: Array[V2DoctrineTechniqueData] = []
	for technique in _all().values():
		if technique.doctrine_branch == branch:
			result.append(technique)
	return result

static var _attack_cache: Array[V2DoctrineTechniqueData] = []

## Técnicas PASSIVAS com bônus de ataque básico (as consultadas por UnitAbilities.attack_multiplier).
## Lista em cache (caminho quente de combate) — não modifique o resultado.
static func attack_bonus_techniques() -> Array[V2DoctrineTechniqueData]:
	if _attack_cache.is_empty():
		for technique in _all().values():
			if technique.is_passive() and technique.has_attack_effect():
				_attack_cache.append(technique)
	return _attack_cache

static var _city_attack_cache: Array[V2DoctrineTechniqueData] = []

## Técnicas PASSIVAS com bônus de ataque de CERCO contra cidade/fortificação (as consultadas por
## V2TechniqueRuntime.city_attack_multiplier — Fase 11, Munição Demolidora). Lista em cache, mesmo padrão de
## attack_bonus_techniques(); NUNCA a mesma lista de attack_bonus_techniques (campos diferentes: city_attack_bonus vs.
## basic_attack_bonus — uma passiva de Cerco nunca conta como bônus de ataque unidade-contra-unidade e vice-versa).
static func city_attack_bonus_techniques() -> Array[V2DoctrineTechniqueData]:
	if _city_attack_cache.is_empty():
		for technique in _all().values():
			if technique.is_passive() and technique.has_city_attack_effect():
				_city_attack_cache.append(technique)
	return _city_attack_cache

static var _defensive_cache: Array[V2DoctrineTechniqueData] = []

## Técnicas com efeito na Defesa (as consultadas em CombatResolver.predict). Lista em cache
## (quente: roda a cada previsão de combate) — não modifique o resultado.
static func defensive_techniques() -> Array[V2DoctrineTechniqueData]:
	if _defensive_cache.is_empty():
		for technique in _all().values():
			if technique.has_defense_effect():
				_defensive_cache.append(technique)
	return _defensive_cache

## Efeito de uma técnica PASSIVA, sem prefixo ("+50% de dano de ataque básico contra unidades montadas", ou "... contra conjuradores ou unidades de
## Cerco" com mais de um traço na lista — Fase 10).
static func passive_effect_text(technique: V2DoctrineTechniqueData) -> String:
	var parts: Array[String] = []
	if technique.has_attack_effect():
		var labels: Array[String] = []
		for trait_id in technique.basic_attack_target_traits:
			labels.append(TRAIT_PLURAL_LABELS.get(trait_id, trait_id))
		parts.append("+%d%% de dano de ataque básico contra %s" % [int(round(technique.basic_attack_bonus * 100.0)), " ou ".join(labels)])
	if technique.has_city_attack_effect():
		parts.append("+%d%% de dano de ataque contra cidades e fortificações" % int(round(technique.city_attack_bonus * 100.0)))
	return ", ".join(parts)

static func _describe_passive(technique: V2DoctrineTechniqueData) -> String:
	return "Passiva: %s. Sem botão, custo nem recarga." % passive_effect_text(technique)

## "1.6", "0.75": o multiplicador de ataque de uma técnica de ataque, sem zeros à direita.
static func multiplier_text(value: float) -> String:
	return str(snappedf(value, 0.01))

## Sufixo do botão de uma técnica de ATAQUE ("×1.6"); "" para as demais.
static func button_suffix(technique: V2DoctrineTechniqueData) -> String:
	return "×%s" % multiplier_text(technique.strike_multiplier) if technique.is_strike() else ""

## "alcance básico", "alcance básico +1" ou "até 2 tiles" — o alcance da técnica, escrito a partir do dado.
static func range_text(technique: V2DoctrineTechniqueData) -> String:
	if technique.strike_range_mode == V2DoctrineTechniqueData.StrikeRangeMode.ATTACK_RANGE_PLUS:
		return "alcance básico" if technique.strike_range <= 0 else "alcance básico +%d" % technique.strike_range
	return "até %d tiles" % technique.strike_range

static func _describe_relocation(technique: V2DoctrineTechniqueData) -> String:
	var text := "Reposiciona a unidade em um tile livre à sua escolha, a até %d tiles" % technique.relocate_range
	text += " (o custo do terreno não conta; terreno impassável e tiles ocupados continuam bloqueando)" if technique.relocate_flat_cost else ""
	if technique.self_defense_bonus > 0.0:
		text += "; ao chegar, +%d%% de Defesa até o início do seu próximo turno" % int(round(technique.self_defense_bonus * 100.0))
	return text + ". Consome a ação e o movimento da unidade; recarga de %d turnos." % technique.cooldown_turns

static func _describe_strike(technique: V2DoctrineTechniqueData) -> String:
	var text := ""
	var multiplier := multiplier_text(technique.strike_multiplier)
	if technique.is_city_strike():
		text = "Ataque de Cerco contra uma cidade ou fortificação hostil à sua escolha (%s): Ataque ×%s." % [range_text(technique), multiplier]
	else:
		match technique.strike_targeting:
			V2DoctrineTechniqueData.StrikeTargeting.SINGLE_TARGET:
				if technique.repositions():
					text = "Avanço e ataque corpo a corpo: a unidade percorre a rota até um tile adjacente a um inimigo à sua escolha (a %d a %d tiles de distância) e o ataca na mesma ação: Ataque ×%s." % [technique.strike_min_range, technique.strike_range, multiplier]
				elif technique.strike_range_mode == V2DoctrineTechniqueData.StrikeRangeMode.FIXED and technique.strike_range <= 1:
					text = "Ataque corpo a corpo especial contra um inimigo adjacente à sua escolha: Ataque ×%s." % multiplier
				else:
					text = "Ataque à distância contra um inimigo à sua escolha (%s): Ataque ×%s." % [range_text(technique), multiplier]
			V2DoctrineTechniqueData.StrikeTargeting.TARGET_AND_NEIGHBORS:
				text = "Ataque à distância contra um alvo à sua escolha (%s) e os inimigos a %d tile dele, até %d no total, cada um com Ataque ×%s." % [range_text(technique), technique.strike_splash_radius, technique.strike_max_targets, multiplier]
			_:
				text = "Golpe em arco: atinge até %d inimigos adjacentes, cada um com Ataque ×%s." % [technique.strike_max_targets, multiplier]
	# Preparação / penetração de Defesa / sem revide (Fases 10-11): frases adicionais construídas do dado — nenhum
	# campo marcado (0.0/false, todas as técnicas anteriores a cada fase) muda o texto em nada.
	if technique.strike_requires_undisturbed:
		text += " Exige que a unidade não tenha se movido neste turno."
	if technique.strike_defense_penetration > 0.0:
		text += " Ignora %d%% da Defesa do alvo." % int(round(technique.strike_defense_penetration * 100.0))
	if technique.strike_prevents_counterattack:
		text += " O alvo não revida este golpe."
	return text + " Consome a ação e o movimento da unidade; recarga de %d turnos." % technique.cooldown_turns

## Resumo de UMA frase pra botão/tooltip, montado a partir dos números do dado —
## nenhum percentual escrito à mão na UI.
static func _describe(technique: V2DoctrineTechniqueData) -> String:
	if technique.is_passive():
		return _describe_passive(technique)
	if technique.is_strike():
		return _describe_strike(technique)
	if technique.is_relocation():
		return _describe_relocation(technique)
	var parts: Array[String] = []
	if technique.self_defense_bonus > 0.0:
		parts.append("+%d%% de Defesa na própria unidade" % int(round(technique.self_defense_bonus * 100.0)))
	if technique.adjacent_ally_defense_bonus > 0.0:
		parts.append("+%d%% nos aliados adjacentes" % int(round(technique.adjacent_ally_defense_bonus * 100.0)))
	var text := "Postura defensiva: %s, até o início do seu próximo turno." % ", ".join(parts)
	text += " Consome a ação e o movimento da unidade; recarga de %d turnos." % technique.cooldown_turns
	return text
