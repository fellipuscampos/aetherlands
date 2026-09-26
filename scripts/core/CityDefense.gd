class_name CityDefense
extends RefCounted

## CIDADES -- REACAO E DEFESA CONTRA MONSTROS (Task 21).
##
## CAUSA RAIZ: nenhum monstro consegue atacar uma cidade (ver nota de
## arquitetura no topo de MonsterAI.gd), entao uma cidade so "sofre" por
## saque de tiles e cerco (City._is_enemy_adjacent suspende a regeneracao) --
## mas TODA a inteligencia de defesa da IA (RivalAI._city_under_threat/
## _military_deficit) so contava unidades de OUTRO JOGADOR: monstros eram
## invisiveis pra producao. As unidades so reagiam a monstros ja dentro do
## proprio alcance de ataque (StrategicAI.engage_nearby_monster) -- sem nunca
## se aproximar, sem nunca mobilizar reforco, sem nunca produzir tropa por
## causa disso. E a propria cidade (nao so as unidades) nao tinha NENHUMA
## defesa: nem a do jogador humano.
##
## Tres camadas, todas PROPORCIONAIS a ameaca real (nunca "toda a IA corre
## pra cidade"):
##  1. assess() -- nivel de ameaca 0..1 de UMA cidade, derivado das mesmas
##     estatisticas de unidade que o combate usa (ataque/defesa/vida atual),
##     ponderado por distancia, tipo de comportamento do monstro, vida da
##     cidade, importancia (Nivel de Cidade), covil proximo e tropas proprias ja
##     guarnecendo. Um goblin solitario a 5 tiles rende ~0.17; 3 esqueletos a
##     4 tiles rendem ~0.9 (prioridade defensiva). Usado por defend_turn abaixo
##     (a producao da IA V2 pesa a ameaca local em V2StrategicAI).
##  2. defend_turn() -- mobilizacao de UNIDADES da IA: quem ja guarnece a
##     cidade sai pra encontrar o monstro dentro de ENGAGE_RADIUS; unidades
##     mais longe so' vem (MOBILIZE_RADIUS) se a guarnicao atual NAO cobre a
##     ameaca. Guerra em andamento eleva o limiar (a guerra tem prioridade,
##     ver LEVEL_MOBILIZE_AT_WAR).
##  3. Ataque da Cidade (Aetherlands V2, Fase 16) -- substituiu a antiga
##     militia_strike() AUTOMATICA (golpe fixo por turno no monstro adjacente,
##     disparado sozinho em GameManager). Agora e' uma ACAO EXPLICITA com alvo,
##     uma vez por turno do dono, so' em cidade fortificada (V2FortificationData);
##     o jogador escolhe pela mira, a IA usa ai_city_defense_turn (paridade
##     tatica minima). Mesma semantica de dano da milicia: dano FIXO (o poder),
##     sem reducao pela Defesa do alvo, sem revide, sem XP/abate/recompensa.
## Tambem warn_player(): aviso ao jogador humano (a "cidade reconhece").
##
## Nao ha ataque a covil aqui (decisao consciente): o guardiao do covil tem
## HP x2.5 e nunca sai de la' (movement_points == 0), entao uma expedicao
## punitiva exigiria coordenar um grupo -- fora do escopo desta rodada.

## Raio (tiles, a partir da cidade) em que um monstro visivel conta como
## ameaca -- mesmo valor de RivalAI.PRODUCTION_THREAT_RADIUS (esqueleto anda
## 2 tiles/turno: ~3 turnos de aviso).
const THREAT_RADIUS := 6
## Raio em que uma unidade propria conta como GUARNICAO da cidade (poder
## somado em own_power) e e' considerada "de servico" em defend_turn.
const GARRISON_RADIUS := 3
## So' monstros a ate' ENGAGE_RADIUS da cidade viram alvo de saida; alem
## disso a guarnicao espera a chegada (nunca persegue longe da cidade).
const ENGAGE_RADIUS := 4
## Unidade fora do GARRISON_RADIUS so' e' convocada como reforco dentro
## deste raio (ate' MOBILIZE_RADIUS da cidade).
const MOBILIZE_RADIUS := 8
## Distancia (cidade -> covil vivo) que soma LAIR_PRESSURE_POWER a' ameaca
## enquanto houver algum monstro por perto (o covil repoe monstros).
const LAIR_NEAR_RADIUS := 5
const LAIR_PRESSURE_POWER := 1.5
## Poder efetivo (ver assess) em que o nivel satura em 1.0.
const LEVEL_SATURATION_POWER := 12.0
## Niveis (0..1): consciente = leve empurrao na producao; mobilizar =
## unidades reagem; emergencia = producao so' de tropa + compra rapida +
## aceita trocas de golpes menos favoraveis.
const LEVEL_AWARE := 0.15
const LEVEL_MOBILIZE := 0.25
const LEVEL_MOBILIZE_AT_WAR := 0.5
const LEVEL_EMERGENCY := 0.6
## A guarnicao "cobre" a ameaca quando own_power >= threat_power *
## OVERMATCH; so' entao unidades de fora deixam de ser convocadas.
const OVERMATCH := 1.2
## Fracao do poder proprio que abate o nivel de ameaca (cautela: soma
## linear de poder superestima um grupo pequeno).
const OWN_POWER_CREDIT := 0.75
const GARRISON_RETURN_RADIUS := 2

## Turnos minimos entre dois avisos ao jogador pela MESMA cidade.
const WARNING_COOLDOWN_TURNS := 5

## Quao diretamente cada comportamento de monstro ameaca uma CIDADE: o
## Invasor marcha na cidade mais proxima do mapa inteiro; Saqueador/Cacador
## aparecem mas nao marcham; Guardiao so' briga dentro do proprio territorio.
const APPROACH_WEIGHT := {
	MonsterDatabase.BEHAVIOR_INVADER: 1.0,
	MonsterDatabase.BEHAVIOR_RAIDER: 0.8,
	MonsterDatabase.BEHAVIOR_HUNTER: 0.8,
	MonsterDatabase.BEHAVIOR_GUARDIAN: 0.3,
}

## Poder bruto de uma unidade -- mesma soma que StrategicAI.production_score
## usa pra "forca" (ataque + defesa + 15% da vida), escalada pela vida atual
## (piso 25%: um ferido ainda incomoda).
static func unit_power(unit: Unit) -> float:
	var data := unit.unit_data
	var raw := data.attack + data.defense + data.max_hp * 0.15
	return raw * clampf(unit.hp / maxf(data.max_hp, 1.0), 0.25, 1.0)

## 1.0 ate 2 tiles, cai 0.2 por tile (0.2 a 6 tiles).
static func proximity_weight(distance: int) -> float:
	return clampf(1.0 - 0.2 * float(distance - 2), 0.2, 1.0)

## Monstro que REALMENTE pode chegar numa cidade: neutro, nao gerenciado por
## evento mundial (o Dragao tem sistema proprio, ver DragonEvent) e capaz de
## andar (o boss do covil tem movement_points == 0 e nunca sai de la').
static func is_mobile_threat(monster: Unit) -> bool:
	return monster.owner_player == null and not monster.world_event_managed and monster.unit_data.movement_points > 0.0

static func _approach_weight(monster: Unit) -> float:
	return APPROACH_WEIGHT.get(MonsterAI._effective_behavior(monster), 0.3)

## `visible == null` = sem filtro de nevoa (testes/diagnostico); do contrario
## so' conta monstro em tile visivel (mesma nocao de "conhecido" do resto da
## IA).
static func assess(city: City, hex_grid: HexGrid, visible: Variant = null) -> Dictionary:
	var monsters: Array[Unit] = []
	var raw_threat := 0.0
	var nearest: Unit = null
	var nearest_distance := 999999
	for monster in hex_grid.neutral_units():
		if not is_instance_valid(monster) or not is_mobile_threat(monster):
			continue
		var distance := HexMetrics.axial_distance(monster.coord, city.coord)
		if distance > THREAT_RADIUS:
			continue
		if visible != null and not (visible as Dictionary).has(monster.coord):
			continue
		monsters.append(monster)
		raw_threat += unit_power(monster) * _approach_weight(monster) * proximity_weight(distance)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = monster
	if raw_threat > 0.0 and _live_lair_near(city, hex_grid):
		raw_threat += LAIR_PRESSURE_POWER

	# Importancia estrategica (City Level — Fase 25, era a populacao) e fragilidade (vida+escudo) da
	# cidade ampliam o peso da MESMA ameaca -- nunca criam ameaca do nada.
	var durability := city.max_hp() + city.max_shield()
	var health_fraction := clampf((city.hp + city.shield) / maxf(durability, 1.0), 0.0, 1.0)
	var stakes := (1.0 + 0.5 * (1.0 - health_fraction)) * (1.0 + 0.12 * float(V2CityLevelData.clamp_level(city.city_level) - 1))
	var effective_threat := raw_threat * stakes

	var own_power := 0.0
	if city.owner_player != null:
		for unit in city.owner_player.units:
			if unit.unit_data.attack > 0.0 and HexMetrics.axial_distance(unit.coord, city.coord) <= GARRISON_RADIUS:
				own_power += unit_power(unit)

	var credited := own_power * OWN_POWER_CREDIT
	# level = urgencia LIQUIDA (ja abatida pela guarnicao propria): guia
	# producao/aviso -- uma cidade bem guarnecida nao precisa produzir nem
	# incomodar o jogador. gross_level = a ameaca EM SI: guia se a guarnicao
	# sai pra enfrentar o monstro (guarnicao que "cobre" a ameaca ainda deve
	# expulsar o esqueleto que saqueia os tiles, senao a cidade continuaria
	# parecendo ignora-lo).
	var level := clampf((effective_threat - credited) / LEVEL_SATURATION_POWER, 0.0, 1.0)
	var deficit := 0.0 if effective_threat <= 0.0 else clampf(1.0 - credited / effective_threat, 0.0, 1.0)
	return {
		"monsters": monsters,
		"nearest": nearest,
		"threat_power": effective_threat,
		"own_power": own_power,
		"gross_level": clampf(effective_threat / LEVEL_SATURATION_POWER, 0.0, 1.0),
		"level": level,
		"deficit": deficit,
		"needs_reinforcement": own_power < effective_threat * OVERMATCH,
	}

static func is_emergency(assessment: Dictionary) -> bool:
	return assessment.level >= LEVEL_EMERGENCY and assessment.deficit > 0.0

static func _live_lair_near(city: City, hex_grid: HexGrid) -> bool:
	for lair_coord in hex_grid.lairs_by_coord.keys():
		if HexMetrics.axial_distance(lair_coord, city.coord) <= LAIR_NEAR_RADIUS and hex_grid._count_live_monsters_near_lair(lair_coord) > 0:
			return true
	return false

## Um turno de UMA unidade de IA rival quando alguma cidade propria esta
## ameacada por monstros. `true` = a unidade ja usou o turno (defendendo ou
## segurando posicao na guarnicao) e NAO deve seguir a logica de guerra/
## exploracao; `false` = nada a fazer aqui (ou ferida demais: a retirada
## normal de RivalAI._handle_attacker assume).
static func defend_turn(unit: Unit, player: PlayerData, hex_grid: HexGrid, visible: Dictionary) -> bool:
	if unit.unit_data.attack <= 0.0 or unit.hp < unit.unit_data.max_hp * RivalAI.RETREAT_HP_FRACTION:
		return false
	var threshold := LEVEL_MOBILIZE if player.enemies.is_empty() else LEVEL_MOBILIZE_AT_WAR
	var chosen: City = null
	var chosen_assessment: Dictionary = {}
	var chosen_score := -INF
	for city in player.cities:
		var distance := HexMetrics.axial_distance(unit.coord, city.coord)
		if distance > MOBILIZE_RADIUS:
			continue
		var assessment := assess(city, hex_grid, visible)
		if assessment.gross_level < threshold:
			continue
		if distance > GARRISON_RADIUS and not assessment.needs_reinforcement:
			continue
		var score: float = assessment.gross_level - 0.05 * float(distance)
		if score > chosen_score:
			chosen_score = score
			chosen = city
			chosen_assessment = assessment
	if chosen == null:
		return false

	var target: Unit = _pick_target(unit, chosen, chosen_assessment)
	if target == null:
		# Ameaca ainda longe demais pra sair ao encontro: garante presenca na
		# cidade (guarnicao) em vez de seguir a guerra/exploracao.
		if HexMetrics.axial_distance(unit.coord, chosen.coord) > GARRISON_RETURN_RADIUS:
			RivalAI.move_unit_toward(unit, hex_grid, chosen.coord)
		return true

	var level: float = chosen_assessment.level
	if _in_reach(unit, target, hex_grid):
		if _acceptable_attack(unit, target, hex_grid, level):
			CombatResolver.resolve(unit, target, hex_grid)
		return true
	# Sem chance razoavel nem sob emergencia: nao se aproxima (evita suicidio).
	if level < LEVEL_EMERGENCY and unit_power(unit) < 0.5 * unit_power(target):
		if HexMetrics.axial_distance(unit.coord, chosen.coord) > GARRISON_RETURN_RADIUS:
			RivalAI.move_unit_toward(unit, hex_grid, chosen.coord)
		return true
	RivalAI.move_unit_toward(unit, hex_grid, target.coord)
	if is_instance_valid(unit) and is_instance_valid(target) and unit.movement_left > 0.0 and _in_reach(unit, target, hex_grid) and _acceptable_attack(unit, target, hex_grid, level):
		CombatResolver.resolve(unit, target, hex_grid)
	return true

## Monstro mais proximo DA UNIDADE dentre os que estao a ate ENGAGE_RADIUS da
## cidade (empate: o mais ferido).
static func _pick_target(unit: Unit, city: City, assessment: Dictionary) -> Unit:
	var best: Unit = null
	var best_distance := 999999
	for monster in assessment.monsters:
		if not is_instance_valid(monster) or HexMetrics.axial_distance(monster.coord, city.coord) > ENGAGE_RADIUS:
			continue
		var distance := HexMetrics.axial_distance(unit.coord, monster.coord)
		if distance < best_distance or (distance == best_distance and best != null and monster.hp < best.hp):
			best_distance = distance
			best = monster
	return best

static func _in_reach(unit: Unit, target: Unit, hex_grid: HexGrid) -> bool:
	return target.coord in hex_grid.tiles_in_range(unit.coord, unit.unit_data.attack_range)

## Nunca morre no proprio ataque; luta quando favoravel (mesma regra do resto
## da IA) e, sob emergencia, aceita tambem trocas desfavoraveis -- a cidade
## esta em jogo (RETREAT_HP_FRACTION continua sendo o limite, ver defend_turn).
static func _acceptable_attack(unit: Unit, target: Unit, hex_grid: HexGrid, level: float) -> bool:
	if CombatResolver.predict(unit, target, hex_grid).attacker_dies:
		return false
	return RivalAI.is_favorable_attack(unit, target, hex_grid) or level >= LEVEL_EMERGENCY

## --- Ataque da Cidade (Aetherlands V2, Fase 16) -------------------------------------------------
## Números em V2FortificationData; Déficit reduz SÓ este componente ativo
## (V2EconomyRuntime.operational_multiplier) — escudo e bônus de defesa continuam 100%. Tensão
## Logística não entra (cidade não tem supply_cost).

## Poder EFETIVO do disparo agora (0 sem fortificação).
static func city_attack_power(city: City) -> float:
	if city == null or not V2FortificationData.has_city_attack(city.fortification_level):
		return 0.0
	return V2FortificationData.city_attack_power(city.fortification_level) * V2EconomyRuntime.operational_multiplier(city.owner_player)

static func city_attack_range(city: City) -> int:
	return V2FortificationData.city_attack_range(city.fortification_level) if city != null else 0

## "" se a cidade pode disparar agora (independente de alvo); senão o motivo.
static func city_attack_unavailable_reason(city: City) -> String:
	if city == null or city.owner_player == null:
		return "Cidade sem dono."
	if not V2FortificationData.has_city_attack(city.fortification_level):
		return "Requer fortificação (Muralhas I ou superior)."
	if city.last_city_attack_turn == TurnManager.turn_number:
		return "Ataque da Cidade já usado neste turno."
	return ""

## Regra de hostilidade da cidade: mesma semântica de CombatResolver.can_attack_unit (dono diferente,
## em guerra, ou monstro neutro hostil a todos), sem precisar de uma Unit atacante. Monstro gerido por
## evento mundial (Dragão) tem sistema próprio e continua fora, como já era na milícia.
static func can_city_target(city: City, target: Unit) -> bool:
	if city == null or target == null or not is_instance_valid(target) or target.hp <= 0.0 or city.owner_player == null:
		return false
	if target.owner_player == city.owner_player:
		return false
	if target.owner_player == null:
		return not target.world_event_managed
	return city.owner_player.is_at_war_with(target.owner_player)

## Alvos válidos AGORA: só os tiles dentro do alcance (HexMetrics.coords_within, nunca o mapa todo);
## pro humano, só unidades visíveis (sem atirar através da neblina, ver _visible_to_owner). `visible`
## opcional: filtro EXTRA explícito (testes). Ordem estável: menor HP%, depois menor serial_id.
static func city_attack_targets(city: City, hex_grid: HexGrid, visible: Variant = null) -> Array[Unit]:
	var result: Array[Unit] = []
	if city_attack_unavailable_reason(city) != "":
		return result
	for coord in HexMetrics.coords_within(city.coord, city_attack_range(city)):
		var unit: Unit = hex_grid.get_unit_at(coord)
		if unit == null or not can_city_target(city, unit):
			continue
		if not _visible_to_owner(city, coord, hex_grid):
			continue
		if visible != null and not (visible as Dictionary).has(coord):
			continue
		result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool:
		var fa := a.hp / maxf(a.unit_data.max_hp, 0.001)
		var fb := b.hp / maxf(b.unit_data.max_hp, 0.001)
		if not is_equal_approx(fa, fb):
			return fa < fb
		return a.serial_id < b.serial_id)
	return result

## O tile pode ser mirado pela cidade? A MESMA regra de V2TechniqueRuntime._visible_to_owner: só o
## HUMANO com neblina já calculada precisa do tile VISÍVEL agora (lê HexGrid.visibility, O(1) —
## nunca recalcula a neblina: compute_visible_tiles custava ~3 ms no mapa Grande a cada refresh do
## botão). IA / partida sem neblina: sem restrição.
static func _visible_to_owner(city: City, coord: Vector2i, hex_grid: HexGrid) -> bool:
	if city.owner_player != GameManager.human_player or hex_grid.visibility.is_empty():
		return true
	return hex_grid.visibility.get(coord, HexGrid.Visibility.UNSEEN) == HexGrid.Visibility.VISIBLE

## Dano previsto (a MESMA conta que resolve usa): poder efetivo, fixo — sem Defesa do alvo (semântica
## herdada da milícia V1), sem vulnerabilidade de alvo voador (+25% da Fase 9 é só pra Unit atacante).
static func predict_city_defense_attack(city: City, target: Unit) -> float:
	if city == null or target == null:
		return 0.0
	return city_attack_power(city)

## Dispara uma vez em `target`. false (nada muda) se a cidade não pode disparar ou o alvo é inválido
## (fora de alcance, não hostil, invisível pro humano). Sucesso consome o disparo do turno.
static func resolve_city_defense_attack(city: City, target: Unit, hex_grid: HexGrid) -> bool:
	if not (target in city_attack_targets(city, hex_grid)):
		return false
	var damage := predict_city_defense_attack(city, target)
	city.last_city_attack_turn = TurnManager.turn_number
	var coord := target.coord
	var target_name := target.unit_data.unit_name
	var target_owner := target.owner_player
	CombatResolver._record_damage_from_player(city.owner_player, target, minf(target.hp, damage))
	target.hp -= damage
	hex_grid.spawn_damage_popup(coord, damage)
	if target_owner == null:
		hex_grid.alert_lair_near(coord, TurnManager.turn_number)
	var city_is_human := city.owner_player == GameManager.human_player
	var target_is_human := target_owner != null and target_owner == GameManager.human_player
	if target.hp <= 0.0:
		hex_grid.remove_unit(target)
		if city_is_human:
			EventBus.notify.emit("O Ataque da Cidade de %s abateu %s!" % [city.city_name, target_name], "combat")
		elif target_is_human:
			EventBus.notify.emit("Seu %s foi abatido pelo Ataque da Cidade de %s!" % [target_name, city.city_name], "combat")
	elif city_is_human:
		EventBus.notify.emit("O Ataque da Cidade de %s atingiu %s." % [city.city_name, target_name], "combat")
	elif target_is_human:
		EventBus.notify.emit("Seu %s foi atingido pelo Ataque da Cidade de %s." % [target_name, city.city_name], "combat")
	return true

## Paridade tática mínima da IA (§58 do pedido): cidade fortificada com o disparo disponível atira
## uma vez no primeiro alvo da ordem estável (menor HP%, depois menor serial). Sem estratégia.
static func ai_city_defense_turn(city: City, hex_grid: HexGrid) -> Unit:
	var targets := city_attack_targets(city, hex_grid)
	if targets.is_empty():
		return null
	var target: Unit = targets[0]
	return target if resolve_city_defense_attack(city, target, hex_grid) else null

## Aviso ao jogador humano: cidade propria ameacada pelo menos no nivel de
## mobilizacao, no maximo um aviso por cidade a cada WARNING_COOLDOWN_TURNS.
static func warn_player(player: PlayerData, hex_grid: HexGrid, visible: Dictionary, turn: int) -> void:
	for city in player.cities:
		if turn - city.last_monster_warning_turn < WARNING_COOLDOWN_TURNS:
			continue
		var assessment := assess(city, hex_grid, visible)
		if assessment.level < LEVEL_MOBILIZE:
			continue
		city.last_monster_warning_turn = turn
		var nearest: Unit = assessment.nearest
		var count: int = assessment.monsters.size()
		var label: String = nearest.unit_data.unit_name if count == 1 else "%s e mais %d monstro(s)" % [nearest.unit_data.unit_name, count - 1]
		EventBus.notify.emit("%s esta ameacada: %s se aproximam!" % [city.city_name, label], "combat")
