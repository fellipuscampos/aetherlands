class_name MonsterEcologySystem
extends RefCounted

## Controlador único dos covis hostis: distribuição por habitat, abertura regional, líderes,
## população por origem, reforços, reocupação, trégua regional, atividade por era e persistência.
## RegionalThreatSystem mantém somente os objetivos/descobertas e o planejamento especial da abertura
## e dos recursos. Seus covis entram NESTE registro e orçamento; não têm outro loop de população.
## O Dragão continua um evento mundial. Combate, habilidades e atributos mantêm suas fontes atuais.
##
## Cada sítio novo tem uma estrutura e um líder (uma designação, sem bônus de atributos).
## Estrutura sem líder é vulnerável; destruí-la silencia a região por 20 rodadas. Sobreviventes
## não desaparecem. A reocupação usa amostragem limitada, fora de visão/presença/território de civs.
## Sítios sem estrutura só existem como compatibilidade de saves anteriores à unificação.
##
## O mundo não sabe quem é humano: âncoras e alvos são por assento/posição, nunca por identidade.
## Determinismo: RNG próprio (map_seed + MonsterEcologyData.RNG_SALT), estado salvo; varreduras em ordem
## de coordenada. Nada roda por frame: setup uma vez, reposição/esvaziamento uma vez por rodada global
## (HexGrid.process_monster_lairs), atividade dentro do loop normal da MonsterAI.

const SOURCE_INITIAL := "initial"
const SOURCE_ADOPTED := "adopted"
const SOURCE_REFILL := "refill"

## Estado da partida (resetado por WorldEventManager.reset_for_new_match; salvo em "combat_ecology").
static var enabled := false
static var sites: Array[Dictionary] = []
static var next_site_id := 1
static var targets: Dictionary = {}
static var eligible_count := 0
static var depleted: Array[Dictionary] = []
static var next_refill_turn := 0
static var rng := RandomNumberGenerator.new()
## true = save anterior à V3 carregado: nenhuma população retroativa no load; a reposição normal começa
## na próxima fronteira de rodada.
static var migrated := false
## Resumo da colocação inicial (telemetria/survey). Não salvo.
static var initial_stats: Dictionary = {}

static var _eligible_cache: Array[Vector2i] = []
static var _eligible_key := ""
## Etapa 4: sinais estáticos de habitat (Nódulos Arcanos + composição local por coordenada) do mapa atual.
static var _habitat_cache: Dictionary = {}
static var _habitat_key := ""
## DEV/laboratório (A/B `--no-habitat`): false = habitat neutro (todo candidato com o mesmo peso, a seleção vira o
## sorteio uniforme). Nunca salvo nem exposto na UI; o jogo sempre usa true.
static var habitat_enabled := true
static var last_processed_turn := -1
## Índices transitórios; referências não são serializadas. Consultas de IA/UI não varrem o mapa.
static var _sites_by_id: Dictionary = {}
static var _sites_by_lair: Dictionary = {}
static var _leaders: Dictionary = {}
static var _needs_lair_migration := false

static func reset() -> void:
	enabled = false
	sites = []
	next_site_id = 1
	targets = {}
	eligible_count = 0
	depleted = []
	next_refill_turn = 0
	rng = RandomNumberGenerator.new()
	migrated = false
	initial_stats = {}
	_eligible_cache = []
	_eligible_key = ""
	_habitat_cache = {}
	_habitat_key = ""
	last_processed_turn = -1
	_sites_by_id = {}
	_sites_by_lair = {}
	_leaders = {}
	_needs_lair_migration = false
	MonsterHazardSystem.reset() # V3 / Etapa 2: raízes, infecção, marcadores
	MonsterAbilitySystem.reset() # V3 / Etapa 2: Vermes subterrâneos

# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

static func site_by_id(site_id: int) -> Dictionary:
	if _sites_by_id.has(site_id):
		return _sites_by_id[site_id]
	for site in sites:
		if int(site.id) == site_id:
			_sites_by_id[site_id] = site
			return site
	return {}

static func site_for_lair(coord: Vector2i) -> Dictionary:
	return _sites_by_lair.get(coord, {})

static func is_lair_leader(unit: Unit) -> bool:
	return unit != null and is_instance_valid(unit) and (unit.is_camp_boss or bool(unit.ability_state.get("lair_leader", false)))

## Também inclui líder subterrâneo: sair da porta ou enterrar-se não torna a estrutura vulnerável.
static func leader_for_lair(coord: Vector2i) -> Unit:
	var site := site_for_lair(coord)
	if site.is_empty():
		return null
	var leader: Unit = _leaders.get(int(site.id))
	return leader if leader != null and is_instance_valid(leader) and not leader.is_queued_for_deletion() and leader.hp > 0.0 else null

static func _index_site(site: Dictionary) -> void:
	_sites_by_id[int(site.id)] = site
	if site.lair != HexGrid.NO_LAIR:
		_sites_by_lair[site.lair] = site

static func _set_leader(site: Dictionary, unit: Unit) -> void:
	var previous: Unit = _leaders.get(int(site.id))
	if previous != null and is_instance_valid(previous) and previous != unit:
		previous.ability_state.erase("lair_leader")
	unit.ability_state.lair_leader = true
	# Chefes de saves/covis legados eram imóveis: precisam poder reagir como os líderes novos.
	# Preserva Vida/dano/defesa históricos e não afeta o Dragão do evento (fora da ecologia).
	if unit.is_camp_boss and unit.unit_data.movement_points <= 0.0:
		unit.unit_data.movement_points = float(MonsterDatabase.KIND_DATA.get(String(site.species), {}).get("movement_points", 0.0))
	site.leader_lost_turn = -1
	_leaders[int(site.id)] = unit

static func on_unit_removed(unit: Unit, turn: int) -> void:
	if not is_ecology_unit(unit):
		return
	var site := site_by_id(unit.ecology_site_id)
	if not site.is_empty() and _leaders.get(int(site.id)) == unit:
		site.leader_lost_turn = turn
		_leaders.erase(int(site.id))

static func site_for_unit(unit: Unit) -> Dictionary:
	if unit == null or unit.ecology_site_id < 0:
		return {}
	return site_by_id(unit.ecology_site_id)

static func is_ecology_unit(unit: Unit) -> bool:
	return unit != null and is_instance_valid(unit) and unit.owner_player == null and unit.ecology_site_id >= 0

## Âncora de fairness de cada civilização (por assento): a capital da ameaça regional já planejada, a
## primeira cidade ou, antes de fundar, o Colonizador inicial.
static func capital_anchors() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in GameManager.players.size():
		var player: PlayerData = GameManager.players[index]
		var record := RegionalThreatSystem.record_for_index(index)
		if not record.is_empty():
			result.append(record.anchor)
		elif not player.cities.is_empty():
			result.append(player.cities[0].coord)
		else:
			for unit in player.units:
				if is_instance_valid(unit) and unit.unit_data.can_found_city:
					result.append(unit.coord)
					break
	return result

## Terra elegível (cache por grid/tamanho; recalculada após load ou em outro mapa).
static func eligible(grid: HexGrid) -> Array[Vector2i]:
	var key := "%d:%d:%d" % [grid.get_instance_id(), grid.tiles.size(), grid.map_seed]
	if key != _eligible_key:
		_eligible_cache = MonsterEcologyPlanner.eligible_tiles(grid)
		_eligible_key = key
	return _eligible_cache

## Cache de habitat do mapa atual (refeito após load ou em outro mapa; nunca por turno de monstro).
static func habitat_cache(grid: HexGrid) -> Dictionary:
	var key := "%d:%d:%d" % [grid.get_instance_id(), grid.tiles.size(), grid.map_seed]
	if key != _habitat_key:
		_habitat_cache = MonsterEcologyPlanner.new_habitat_cache(grid)
		_habitat_key = key
	return _habitat_cache

# ---------------------------------------------------------------------------
# População inicial (partida nova)
# ---------------------------------------------------------------------------

## GameManager._spawn_starting_forces, depois das capitais/tiles iniciais e da ameaça regional das capitais
## do setup, antes do primeiro turno. `on` = GameManager.combat_ecology_on_new_match.
static func populate_new_match(grid: HexGrid, on: bool) -> void:
	reset()
	enabled = on
	if not enabled or grid == null:
		return
	var started := Time.get_ticks_usec()
	var turn := TurnManager.turn_number
	rng.seed = grid.map_seed + MonsterEcologyData.RNG_SALT
	var anchors := capital_anchors()
	var land := eligible(grid)
	eligible_count = land.size()
	targets = MonsterEcologyData.targets_for(eligible_count)
	var stats := {"adopted": 0, "legacy_removed": 0, "shortfall": {}, "eligible": eligible_count, "targets": targets.duplicate(), "habitat": {}}
	var habitat := habitat_cache(grid)
	var count_by_tier := {}
	for tier in MonsterEcologyData.TIERS:
		count_by_tier[tier] = 0
	_adopt_legacy_lairs(grid, anchors, turn, count_by_tier, stats)
	for tier in [MonsterEcologyData.TIER_ADVANCED, MonsterEcologyData.TIER_INTERMEDIATE, MonsterEcologyData.TIER_BASIC]:
		var quotas := MonsterEcologyPlanner.species_quotas(tier, int(targets[tier]), rng)
		for site in sites:
			var kind := String(site.species)
			if quotas.has(kind):
				quotas[kind] = maxi(0, int(quotas[kind]) - 1)
		var queue := MonsterEcologyPlanner.round_robin_queue(tier, quotas)
		# Adoção acima da cota de UMA espécie não pode estourar o alvo do tier.
		var reserve := _opening_reserve() if tier == MonsterEcologyData.TIER_BASIC else 0
		var room := maxi(0, int(targets[tier]) - int(count_by_tier[tier]) - reserve)
		if queue.size() > room:
			queue = queue.slice(0, room)
		var candidates := MonsterEcologyPlanner.shuffled(land, rng)
		var placed := 0
		for kind in queue:
			var group := MonsterEcologyData.group_size(kind)
			# Etapa 4: âncora sorteada pelo habitat da espécie entre candidatos válidos (fallback progressivo).
			var pick := MonsterEcologyPlanner.habitat_anchor(grid, kind, tier, group, anchors, sites, candidates, habitat, rng)
			if pick.is_empty():
				break
			var anchor: Vector2i = pick.anchor
			_create_lair_site(grid, kind, anchor, SOURCE_INITIAL, turn, anchors)
			if not stats.habitat.has(kind):
				stats.habitat[kind] = {"sites": 0, "score_sum": 0.0, "fallback": 0}
			stats.habitat[kind].sites += 1
			stats.habitat[kind].score_sum += float(pick.score)
			stats.habitat[kind].fallback += 1 if bool(pick.fallback) else 0
			placed += 1
		if placed < queue.size():
			stats.shortfall[tier] = queue.size() - placed
	next_refill_turn = turn + MonsterEcologyData.REFILL_INTERVAL
	stats.placement_ms = snappedf((Time.get_ticks_usec() - started) / 1000.0, 0.01)
	stats.merge(population_snapshot(grid), true)
	initial_stats = stats

## Covis selvagens da seed no continente principal (Goblin/Esqueleto/Troll/Vivern): o que respeita a zona
## de segurança/espaçamento do tier e cabe no alvo vira sítio ecológico (papel ECOLOGY, mesmos monstros +
## complemento até o grupo); o resto é removido (partida nova, nada foi tocado). Nunca duplica um covil
## existente com um sítio novo ao lado. Encontros das 12 espécies fora de MAIN são registrados sem
## remoção/recolocação; Dragão dos perfis opcionais mantém o tratamento próprio.
static func _adopt_legacy_lairs(grid: HexGrid, anchors: Array[Vector2i], turn: int, count_by_tier: Dictionary, stats: Dictionary) -> void:
	for lair_coord in MonsterEcologyPlanner.sorted_coords(grid.lair_coords.duplicate()):
		if grid.lair_role(lair_coord) in [HexGrid.LAIR_ROLE_REGIONAL, HexGrid.LAIR_ROLE_GUARDIAN]:
			var registered := register_lair(grid, lair_coord, turn)
			if not registered.is_empty():
				var registered_tier := MonsterEcologyData.tier_of(String(registered.species))
				count_by_tier[registered_tier] = int(count_by_tier[registered_tier]) + 1
			continue
		if grid.lair_role(lair_coord) == HexGrid.LAIR_ROLE_WILD and grid._zone_for(lair_coord) != HexGrid._Zone.MAIN:
			# Perfis opcionais com continentes especiais: preserva o encontro existente e unifica
			# seu ciclo de vida também. Não espalha a população inicial do continente principal lá.
			var special := register_lair(grid, lair_coord, turn)
			if not special.is_empty():
				grid.set_lair_role(lair_coord, HexGrid.LAIR_ROLE_ECOLOGY)
				var special_tier := MonsterEcologyData.tier_of(String(special.species))
				count_by_tier[special_tier] = int(count_by_tier[special_tier]) + 1
			continue
		if grid.lair_role(lair_coord) != HexGrid.LAIR_ROLE_WILD or grid._zone_for(lair_coord) != HexGrid._Zone.MAIN:
			continue
		var kind := String(grid.lair_kind_by_coord.get(lair_coord, ""))
		var tier := MonsterEcologyData.tier_of(kind)
		if tier == "":
			# V3 / Etapa 3: o sorteio legado da seed pode cair no fallback "ignora bioma" e criar um covil de Dragão em
			# terreno comum. Sem os continentes especiais (padrão 1.0) ele ficaria no continente principal, fora da
			# ecologia e do evento mundial — sai no setup (partida nova, nada tocado). O Dragão Ancião é só o evento.
			grid.remove_lair_silently(lair_coord)
			stats.legacy_removed = int(stats.legacy_removed) + 1
			continue
		var adoptable := int(count_by_tier[tier]) < int(targets[tier]) \
			and MonsterEcologyPlanner.capital_distance_ok(lair_coord, tier, anchors) \
			and MonsterEcologyPlanner.spacing_ok(lair_coord, tier, sites) \
			and grid.land_component_size(lair_coord) >= MonsterEcologyData.MIN_LANDMASS
		var members: Array[Unit] = []
		for area_coord in grid._lair_area(lair_coord):
			var occupant: Unit = grid.get_unit_at(area_coord)
			if occupant != null and occupant.owner_player == null and not occupant.world_event_managed and occupant.source_lair_coord in [lair_coord, HexGrid.NO_LAIR]:
				members.append(occupant)
		# O chefe legado nasce num VIZINHO do covil: a zona de segurança vale para cada membro, não só para a estrutura.
		for member in members:
			adoptable = adoptable and MonsterEcologyPlanner.capital_distance_ok(member.coord, tier, anchors)
		if not adoptable:
			grid.remove_lair_silently(lair_coord)
			stats.legacy_removed = int(stats.legacy_removed) + 1
			continue
		grid.set_lair_role(lair_coord, HexGrid.LAIR_ROLE_ECOLOGY)
		var missing := maxi(0, MonsterEcologyData.group_size(kind) - members.size())
		var extra := MonsterEcologyPlanner.group_tiles(grid, lair_coord, missing, tier, anchors, false)
		var site := _create_site(grid, kind, lair_coord, lair_coord, SOURCE_ADOPTED, turn, extra)
		for member in members:
			member.ecology_site_id = int(site.id)
			member.source_lair_coord = lair_coord
			if member.is_camp_boss:
				_set_leader(site, member)
		count_by_tier[tier] = int(count_by_tier[tier]) + 1
		stats.adopted = int(stats.adopted) + 1

static func _create_site(grid: HexGrid, kind: String, anchor: Vector2i, lair: Vector2i, source: String, turn: int, members: Array[Vector2i]) -> Dictionary:
	var site := {"id": next_site_id, "species": kind, "anchor": anchor, "lair": lair, "created_turn": turn, "source": source,
		"leader_lost_turn": -1, "wake_turn": turn, "next_reinforce_turn": turn + MonsterEcologyData.REINFORCE_INTERVAL}
	next_site_id += 1
	sites.append(site)
	_index_site(site)
	for coord in members:
		var unit := grid.spawn_monster_at(coord, kind)
		unit.ecology_site_id = int(site.id)
		if lair != HexGrid.NO_LAIR:
			unit.source_lair_coord = lair
			if not _leaders.has(int(site.id)):
				_set_leader(site, unit)
	return site

## A porta pertence à estrutura; criaturas nascem SOMENTE nos vizinhos legais.
static func _create_lair_site(grid: HexGrid, kind: String, anchor: Vector2i, source: String, turn: int, anchors: Array[Vector2i]) -> Dictionary:
	var members := MonsterEcologyPlanner.group_tiles(grid, anchor, MonsterEcologyData.group_size(kind), MonsterEcologyData.tier_of(kind), anchors, false)
	grid.create_lair(anchor, kind, HexGrid.LAIR_ROLE_ECOLOGY)
	var site := _create_site(grid, kind, anchor, anchor, source, turn, members)
	if source == SOURCE_REFILL:
		site.wake_turn = turn + MonsterEcologyData.NEW_LAIR_WAKE_DELAY
	return site

## Abertura e guardiões são políticas do mesmo sistema; sem spawn nem alteração de Vida/dano/defesa na adoção.
static func register_lair(grid: HexGrid, coord: Vector2i, turn: int) -> Dictionary:
	if not enabled or grid == null or not grid.lairs_by_coord.has(coord):
		return {}
	var existing := site_for_lair(coord)
	if not existing.is_empty():
		return existing
	var kind := String(grid.lair_kind_by_coord.get(coord, ""))
	if not MonsterEcologyData.is_ecology_species(kind):
		return {}
	var site := _create_site(grid, kind, coord, coord, SOURCE_ADOPTED, turn, [] as Array[Vector2i])
	var record := RegionalThreatSystem.record_for_lair(coord)
	if not record.is_empty() and String(record.state) == RegionalThreatSystem.STATE_DORMANT:
		site.wake_turn = int(record.wake_turn)
	for member in grid.lair_members(coord):
		member.ecology_site_id = int(site.id)
		if not _leaders.has(int(site.id)) or member.is_camp_boss:
			_set_leader(site, member)
	return site

## Reserva de orçamento para a primeira capital ainda não fundada (inclusive a do assento humano).
static func _opening_reserve() -> int:
	if not RegionalThreatSystem.enabled():
		return 0
	var count := 0
	for index in GameManager.players.size():
		if GameManager.players[index].cities.is_empty() and RegionalThreatSystem.record_for_index(index).is_empty():
			count += 1
	return count

# ---------------------------------------------------------------------------
# Rodada global: esvaziamento + reposição
# ---------------------------------------------------------------------------

## Uma vez por rodada (HexGrid.process_monster_lairs, antes do reforço dos covis e da MonsterAI).
static func process_round(grid: HexGrid, turn: int) -> void:
	if not enabled or grid == null or turn <= last_processed_turn:
		return
	last_processed_turn = turn
	if _needs_lair_migration:
		_migrate_lairs(grid, turn)
	var alive := _alive_by_site(grid)
	_refresh_sites(grid, turn, alive)
	# V3 / Etapa 2: perigos espaciais (raízes expiram, infecção cresce/decai) e Vermes que emergem.
	MonsterHazardSystem.process_round(grid, turn, _live_hive_sites(grid))
	MonsterAbilitySystem.process_round(grid, turn)
	if targets.is_empty():
		# Save anterior à V3: alvo calculado na primeira fronteira de rodada (nunca dentro do load).
		eligible_count = eligible(grid).size()
		targets = MonsterEcologyData.targets_for(eligible_count)
		if rng.seed == 0:
			rng.seed = grid.map_seed + MonsterEcologyData.RNG_SALT
	var due := false
	var recovery_due := false
	for site in sites:
		if _reinforcement_due(grid, site, alive, turn):
			due = true
		if site.lair != HexGrid.NO_LAIR and int(site.get("leader_lost_turn", -1)) >= 0 \
			and turn - int(site.leader_lost_turn) >= MonsterEcologyData.LEADER_RECOVERY_DELAY \
			and grid.lair_role(site.lair) != HexGrid.LAIR_ROLE_GUARDIAN:
			recovery_due = true
	if turn < next_refill_turn and not due:
		return
	var has_deficit := false
	for value in deficits_by_tier().values():
		if int(value) > 0:
			has_deficit = true
			break
	if not due and not recovery_due and not has_deficit:
		next_refill_turn = turn + MonsterEcologyData.REFILL_INTERVAL
		return
	# Uma consulta de visão por civ por rodada com trabalho real; nunca por covil ou por frame.
	var blocked := MonsterEcologyPlanner.refill_blocked_tiles(grid, GameManager.players)
	var births := 0
	if turn >= next_refill_turn:
		births = _try_recovery(grid, alive, blocked, turn)
		if births == 0:
			births = _try_refill(grid, blocked, turn)
		next_refill_turn = turn + MonsterEcologyData.REFILL_INTERVAL
	if due and births < MonsterEcologyData.MAX_BIRTHS_PER_ROUND:
		_reinforce_sites(grid, alive, blocked, turn, MonsterEcologyData.MAX_BIRTHS_PER_ROUND - births)

static func _try_refill(grid: HexGrid, blocked: Dictionary, turn: int) -> int:
	var deficits := deficits_by_tier()
	var phase := WorldEventManager.world_phase
	var tier := MonsterEcologyPlanner.choose_refill_tier(phase, deficits, rng)
	if tier == "":
		return 0
	var species := MonsterEcologyData.species_of_tier(tier)
	var kind: String = species[rng.randi_range(0, species.size() - 1)]
	var group := MonsterEcologyData.group_size(kind)
	var anchors := capital_anchors()
	var anchor := MonsterEcologyPlanner.find_refill_anchor(grid, eligible(grid), tier, group, anchors, sites, depleted, blocked, turn, rng, kind, habitat_cache(grid))
	if anchor == HexGrid.NO_LAIR:
		return 0
	var site := _create_lair_site(grid, kind, anchor, SOURCE_REFILL, turn, anchors)
	emit_event("refill", kind, {"site": int(site.id), "coord": [anchor.x, anchor.y]})
	return group

static func _reinforcement_due(grid: HexGrid, site: Dictionary, alive: Dictionary, turn: int) -> bool:
	if site.lair == HexGrid.NO_LAIR or not grid.lairs_by_coord.has(site.lair):
		return false
	if grid.lair_role(site.lair) == HexGrid.LAIR_ROLE_GUARDIAN or leader_for_lair(site.lair) == null:
		return false
	return turn >= int(site.get("wake_turn", 0)) and turn >= int(site.get("next_reinforce_turn", 0)) \
		and int(alive.get(int(site.id), 0)) < MonsterEcologyData.group_size(String(site.species))

static func _safe_birth_tiles(grid: HexGrid, site: Dictionary, blocked: Dictionary, turn: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if blocked.has(site.lair) or not MonsterEcologyPlanner.depletion_ok(site.lair, depleted, turn):
		return result
	var anchors := capital_anchors()
	var tier := MonsterEcologyData.tier_of(String(site.species))
	for coord in MonsterEcologyPlanner.sorted_coords(grid.get_neighbors(site.lair)):
		if not blocked.has(coord) and _legal_lair_birth(grid, site, coord) \
			and MonsterEcologyPlanner.depletion_ok(coord, depleted, turn) \
			and MonsterEcologyPlanner.capital_distance_ok(coord, tier, anchors):
			result.append(coord)
	return result

## Reforça somente uma origem já existente, inclusive nos perfis opcionais. Novas regiões continuam
## usando a elegibilidade MAIN do planner. Uma criatura voadora pode voltar a um covil legado em lava.
static func _legal_lair_birth(grid: HexGrid, site: Dictionary, coord: Vector2i) -> bool:
	var tile := grid.get_tile(coord)
	var flies := bool(MonsterDatabase.KIND_DATA.get(String(site.species), {}).get("flies", false))
	if tile == null or (tile.blocks_land_units() and not (flies and tile.is_lava())) or tile.resource != "":
		return false
	if grid._zone_for(coord) != grid._zone_for(site.lair):
		return false
	return grid.get_unit_at(coord) == null and grid.get_city_at(coord) == null and grid.city_owning_tile(coord) == null \
		and not grid.buildings_by_coord.has(coord) and not grid.lairs_by_coord.has(coord) \
		and not grid.v2_portal_endpoint_index.has(coord)

static func _spawn_member(grid: HexGrid, site: Dictionary, coord: Vector2i) -> Unit:
	var unit := grid.spawn_monster_at(coord, String(site.species))
	unit.ecology_site_id = int(site.id)
	unit.source_lair_coord = site.lair
	# Recém-chegado não recebe uma ação ofensiva gratuita na mesma fronteira de rodada.
	unit.ability_state.lair_arrival_turn = last_processed_turn
	return unit

static func _reinforce_sites(grid: HexGrid, alive: Dictionary, blocked: Dictionary, turn: int, budget: int) -> void:
	var pending: Array[Dictionary] = []
	for site in sites:
		if _reinforcement_due(grid, site, alive, turn):
			pending.append(site)
	# O mais atrasado primeiro; nenhum covil monopoliza as vagas por posição no array.
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.id) < int(b.id) if int(a.next_reinforce_turn) == int(b.next_reinforce_turn) else int(a.next_reinforce_turn) < int(b.next_reinforce_turn))
	for site in pending:
		if budget <= 0:
			break
		var options := _safe_birth_tiles(grid, site, blocked, turn)
		if options.is_empty():
			continue
		_spawn_member(grid, site, options[0])
		site.next_reinforce_turn = turn + MonsterEcologyData.REINFORCE_INTERVAL
		budget -= 1
		emit_event("reinforce", String(site.species), {"site": int(site.id), "coord": [options[0].x, options[0].y]})

static func _try_recovery(grid: HexGrid, alive: Dictionary, blocked: Dictionary, turn: int) -> int:
	for site in sites:
		if site.lair == HexGrid.NO_LAIR or not grid.lairs_by_coord.has(site.lair) or leader_for_lair(site.lair) != null:
			continue
		if grid.lair_role(site.lair) == HexGrid.LAIR_ROLE_GUARDIAN:
			continue # oportunidade de recurso não vira pedágio recorrente
		var lost := int(site.get("leader_lost_turn", turn))
		if lost < 0 or turn - lost < MonsterEcologyData.LEADER_RECOVERY_DELAY:
			continue
		if int(alive.get(int(site.id), 0)) >= MonsterEcologyData.group_size(String(site.species)):
			continue
		var options := _safe_birth_tiles(grid, site, blocked, turn)
		if options.is_empty():
			continue
		_set_leader(site, _spawn_member(grid, site, options[0]))
		site.wake_turn = turn + MonsterEcologyData.NEW_LAIR_WAKE_DELAY
		site.next_reinforce_turn = int(site.wake_turn) + MonsterEcologyData.REINFORCE_INTERVAL
		emit_event("lair_reoccupied", String(site.species), {"site": int(site.id), "coord": [site.lair.x, site.lair.y]})
		return 1
	return 0

## Só a destruição da estrutura conquista a trégua. Invocação/morte de criatura não a dispara.
static func on_lair_destroyed(coord: Vector2i, turn: int) -> void:
	var site := site_for_lair(coord)
	if site.is_empty():
		return
	depleted.append({"coord": coord, "turn": turn})
	_sites_by_lair.erase(coord)
	_leaders.erase(int(site.id))
	# Guarda a âncora dos sobreviventes. Não os apaga nem os transforma em invasores sem lar.
	site.lair = HexGrid.NO_LAIR
	site.destroyed = true
	emit_event("site_depleted", String(site.species), {"site": int(site.id), "anchor": [coord.x, coord.y]})

## Conta membros vivos por sítio (uma varredura das unidades neutras); sítio sem ninguém se esvazia.
static func _refresh_sites(grid: HexGrid, turn: int, population: Dictionary = {}) -> void:
	var alive := population if not population.is_empty() else _alive_by_site(grid)
	var kept: Array[Dictionary] = []
	for site in sites:
		if site.lair != HexGrid.NO_LAIR and grid.lairs_by_coord.has(site.lair):
			if leader_for_lair(site.lair) == null and int(site.get("leader_lost_turn", -1)) < 0:
				site.leader_lost_turn = turn
			kept.append(site)
			continue
		if int(alive.get(int(site.id), 0)) > 0:
			kept.append(site)
			continue
		if not bool(site.get("destroyed", false)):
			depleted.append({"coord": site.anchor, "turn": turn})
			emit_event("site_depleted", String(site.species), {"site": int(site.id), "anchor": [site.anchor.x, site.anchor.y]})
		_sites_by_id.erase(int(site.id))
		_sites_by_lair.erase(site.lair)
		_leaders.erase(int(site.id))
	sites = kept
	var recent: Array[Dictionary] = []
	for entry in depleted:
		if turn - int(entry.turn) < MonsterEcologyData.REFILL_DEPLETED_COOLDOWN:
			recent.append(entry)
	depleted = recent

## Membros vivos por sítio, incluindo Vermes subterrâneos (fora de units_by_coord, mas vivos).
static func _alive_by_site(grid: HexGrid) -> Dictionary:
	var alive := {}
	for unit in grid.neutral_units():
		if unit.ecology_site_id >= 0:
			alive[unit.ecology_site_id] = int(alive.get(unit.ecology_site_id, 0)) + 1
	for worm in MonsterAbilitySystem.burrowed:
		if is_instance_valid(worm) and worm.ecology_site_id >= 0:
			alive[worm.ecology_site_id] = int(alive.get(worm.ecology_site_id, 0)) + 1
	return alive

static func site_population(grid: HexGrid, site_id: int) -> int:
	return int(_alive_by_site(grid).get(site_id, 0))

## Sítios com uma espécie viva que tenha Contaminação Micótica -> âncora (MonsterHazardSystem: infecção ativa).
## DORMENTE desde 2026-10-04: a Colmeia saiu do jogo (virou o Herói Corrompido) e nenhuma espécie tem a habilidade.
static func _live_hive_sites(grid: HexGrid) -> Dictionary:
	var result := {}
	for unit in grid.neutral_units():
		if unit.ecology_site_id >= 0 and MonsterAbilityData.species_has(unit.unit_data.visual_kind, MonsterAbilityData.MYCOTIC_CONTAMINATION):
			var site := site_by_id(unit.ecology_site_id)
			if not site.is_empty():
				result[int(site.id)] = site.anchor
	return result

static func sites_by_tier() -> Dictionary:
	var result := {}
	for tier in MonsterEcologyData.TIERS:
		result[tier] = 0
	for site in sites:
		if bool(site.get("destroyed", false)):
			continue
		var tier := MonsterEcologyData.tier_of(String(site.species))
		result[tier] = int(result.get(tier, 0)) + 1
	return result

static func deficits_by_tier() -> Dictionary:
	var current := sites_by_tier()
	var result := {}
	for tier in MonsterEcologyData.TIERS:
		var reserve := _opening_reserve() if tier == MonsterEcologyData.TIER_BASIC else 0
		result[tier] = maxi(0, int(targets.get(tier, 0)) - int(current.get(tier, 0)) - reserve)
	return result

# ---------------------------------------------------------------------------
# Diretiva de atividade (MonsterAI)
# ---------------------------------------------------------------------------

## {} = não é monstro da ecologia. Senão {mode "ecology", site_id, anchor, species, tier, phase, profile}.
## Sítio ausente (defensivo) ancora na posição atual.
static func monster_directive(unit: Unit) -> Dictionary:
	if not is_ecology_unit(unit):
		return {}
	var kind := unit.unit_data.visual_kind
	var site := site_by_id(unit.ecology_site_id)
	var phase := WorldEventManager.world_phase
	if not site.is_empty() and site.lair != HexGrid.NO_LAIR:
		if GameManager.hex_grid != null and GameManager.hex_grid.lair_role(site.lair) == HexGrid.LAIR_ROLE_GUARDIAN:
			return {"mode": "guardian", "anchor": site.anchor, "radius": int(MonsterDatabase.KIND_DATA.get(kind, {}).get("guard_radius", MonsterAI.GUARD_RADIUS))}
		if TurnManager.turn_number < int(site.get("wake_turn", 0)):
			return {"mode": "dormant", "anchor": site.anchor, "radius": MonsterAI.GUARD_RADIUS}
	return {
		"mode": "ecology", "site_id": unit.ecology_site_id, "anchor": site.anchor if not site.is_empty() else unit.coord,
		"species": kind, "tier": MonsterEcologyData.tier_of(kind), "phase": phase,
		"profile": MonsterActivityProfile.for_species(kind, phase),
	}

## Âncora para recolher o monstro da ecologia (Dragão ativo) — HexGrid.NO_LAIR se não for da ecologia.
static func home_anchor(unit: Unit) -> Vector2i:
	var site := site_for_unit(unit)
	return site.anchor if not site.is_empty() else HexGrid.NO_LAIR

## Rótulo player-facing do comportamento atual (TileInspector).
static func behavior_label(unit: Unit) -> String:
	var directive := monster_directive(unit)
	if directive.is_empty():
		return ""
	if String(directive.mode) != "ecology":
		return "Protege o covil" if String(directive.mode) == "guardian" else "Preparando-se — defende apenas os arredores"
	return MonsterActivityProfile.label(directive.profile)

# ---------------------------------------------------------------------------
# Telemetria (observabilidade pura: nenhum sistema de jogo escuta)
# ---------------------------------------------------------------------------

## EventBus.combat_ecology_event(action, info). info sempre traz species, tier ("" fora da ecologia),
## phase (id da era) e ecology (monstro de sítio ecológico?).
static func emit_event(action: String, kind: String, extra: Dictionary = {}, ecology: bool = true) -> void:
	var info := {"species": kind, "tier": MonsterEcologyData.tier_of(kind), "phase": WorldPhaseRules.id_name(WorldEventManager.world_phase), "ecology": ecology}
	info.merge(extra, true)
	EventBus.combat_ecology_event.emit(action, info)

static func emit_unit_event(action: String, unit: Unit, extra: Dictionary = {}) -> void:
	emit_event(action, unit.unit_data.visual_kind, extra, unit.ecology_site_id >= 0)

## CombatResolver: uma unidade de civilização morreu para um monstro neutro (ataque ou revide).
static func note_civ_unit_killed(killer: Unit, victim_owner: PlayerData) -> void:
	if killer == null or not is_instance_valid(killer) or killer.owner_player != null or victim_owner == null:
		return
	emit_unit_event("civ_unit_killed", killer, {"target": GameManager.players.find(victim_owner)})
	MonsterAbilitySystem.on_civ_unit_killed(killer, GameManager.hex_grid) # V3 / Etapa 2: Horda Crescente

## Contagens atuais: sítios e unidades da ecologia por tier/espécie, e todos os monstros neutros por tier
## (inclui regionais, Guardiões, covis legados e guardiões de evento; o Dragão não tem tier).
static func population_snapshot(grid: HexGrid) -> Dictionary:
	var units_by_tier := {}
	var units_by_species := {}
	var all_by_tier := {}
	for tier in MonsterEcologyData.TIERS:
		units_by_tier[tier] = 0
		all_by_tier[tier] = 0
	if grid != null:
		for unit in grid.neutral_units():
			var kind := unit.unit_data.visual_kind
			var tier := MonsterEcologyData.tier_of(kind)
			if tier == "":
				continue
			all_by_tier[tier] = int(all_by_tier[tier]) + 1
			if unit.ecology_site_id >= 0:
				units_by_tier[tier] = int(units_by_tier[tier]) + 1
				units_by_species[kind] = int(units_by_species.get(kind, 0)) + 1
	var sites_by_species := {}
	for site in sites:
		sites_by_species[String(site.species)] = int(sites_by_species.get(String(site.species), 0)) + 1
	return {
		"sites_by_tier": sites_by_tier(), "sites_by_species": sites_by_species,
		"units_by_tier": units_by_tier, "units_by_species": units_by_species, "all_neutral_by_tier": all_by_tier,
	}

# ---------------------------------------------------------------------------
# Dev-only (painel de Debug da HUD)
# ---------------------------------------------------------------------------

static func debug_summary(grid: HexGrid) -> String:
	var snapshot := population_snapshot(grid)
	var parts: Array[String] = []
	for tier in MonsterEcologyData.TIERS:
		parts.append("%s %d sítios/%d unid." % [MonsterEcologyData.tier_display(tier), int(snapshot.sites_by_tier[tier]), int(snapshot.units_by_tier[tier])])
	var species: Array[String] = []
	for kind in MonsterEcologyData.SPECIES_ORDER:
		species.append("%s %d" % [String(MonsterDatabase.KIND_DATA[kind].unit_name), int(snapshot.units_by_species.get(kind, 0))])
	return "Ecologia: %s | %s" % [" · ".join(parts), ", ".join(species)]

## Coordenada de um exemplar vivo da espécie (menor serial), ou NO_LAIR.
static func debug_example_coord(grid: HexGrid, kind: String) -> Vector2i:
	var best: Unit = null
	for unit in grid.neutral_units():
		if unit.unit_data.visual_kind == kind and (best == null or unit.serial_id < best.serial_id):
			best = unit
	return best.coord if best != null else HexGrid.NO_LAIR

# ---------------------------------------------------------------------------
# Persistência (bloco "combat_ecology" do save, v25)
# ---------------------------------------------------------------------------

static func to_save_dict() -> Dictionary:
	var saved_sites: Array = []
	for site in sites:
		saved_sites.append({
			"id": int(site.id), "species": String(site.species), "anchor": [site.anchor.x, site.anchor.y],
			"lair": [site.lair.x, site.lair.y], "created_turn": int(site.created_turn), "source": String(site.source),
			"raised_turn": int(site.get("raised_turn", -1)),
			"leader_lost_turn": int(site.get("leader_lost_turn", -1)),
			"wake_turn": int(site.get("wake_turn", 0)), "next_reinforce_turn": int(site.get("next_reinforce_turn", 0)),
			"destroyed": bool(site.get("destroyed", false)),
		})
	var saved_depleted: Array = []
	for entry in depleted:
		saved_depleted.append([entry.coord.x, entry.coord.y, int(entry.turn)])
	return {
		"lair_rules_version": 1, "last_processed_turn": last_processed_turn, "needs_lair_migration": _needs_lair_migration,
		"enabled": enabled, "sites": saved_sites, "next_site_id": next_site_id, "targets": targets.duplicate(),
		"eligible_count": eligible_count, "depleted": saved_depleted, "next_refill_turn": next_refill_turn,
		# STRING (mesmo motivo de monster_rng_state): o estado de 64 bits não sobrevive a um double do JSON.
		"rng_seed": str(rng.seed), "rng_state": str(rng.state), "migrated": migrated,
		# V3 / Etapa 2 (v26): raízes/infecção/cooldown de dano da infecção e Vermes subterrâneos.
		"hazards": MonsterHazardSystem.to_save_dict(), "burrowed": MonsterAbilitySystem.to_save_array(),
	}

## Load (depois dos monstros restaurados). Sem bloco (save ≤ v24): runtime inicializado vazio e LIGADO,
## sem nenhuma população retroativa aqui — a reposição normal começa na próxima fronteira de rodada.
## Monstro apontando para sítio inexistente volta a ser selvagem comum (ecology_site_id = -1).
static func load_save_dict(data: Variant, grid: HexGrid) -> void:
	reset()
	if typeof(data) != TYPE_DICTIONARY:
		enabled = GameManager.combat_ecology_on_new_match
		migrated = true
		_needs_lair_migration = true
		if grid != null:
			rng.seed = grid.map_seed + MonsterEcologyData.RNG_SALT
		next_refill_turn = TurnManager.turn_number + 1
		_orphan_unknown_units(grid)
		return
	enabled = bool(data.get("enabled", false))
	_needs_lair_migration = int(data.get("lair_rules_version", 0)) < 1 or bool(data.get("needs_lair_migration", false))
	last_processed_turn = int(data.get("last_processed_turn", -1))
	migrated = bool(data.get("migrated", false))
	next_site_id = int(data.get("next_site_id", 1))
	eligible_count = int(data.get("eligible_count", 0))
	next_refill_turn = int(data.get("next_refill_turn", TurnManager.turn_number + 1))
	var saved_targets: Variant = data.get("targets", {})
	if typeof(saved_targets) == TYPE_DICTIONARY:
		for tier in MonsterEcologyData.TIERS:
			if saved_targets.has(tier):
				targets[tier] = int(saved_targets[tier])
	for entry in data.get("sites", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var species := MonsterDatabase.canonical_kind(String(entry.get("species", ""))) # Colmeia (save antigo) -> Herói
		if not MonsterEcologyData.is_ecology_species(species):
			continue
		sites.append({
			"id": int(entry.get("id", -1)), "species": species, "anchor": _coord(entry.get("anchor")),
			"lair": _coord(entry.get("lair")), "created_turn": int(entry.get("created_turn", 0)), "source": String(entry.get("source", SOURCE_INITIAL)),
			"raised_turn": int(entry.get("raised_turn", -1)),
			"leader_lost_turn": int(entry.get("leader_lost_turn", -1)),
			"wake_turn": int(entry.get("wake_turn", 0)), "next_reinforce_turn": int(entry.get("next_reinforce_turn", TurnManager.turn_number + MonsterEcologyData.REINFORCE_INTERVAL)),
			"destroyed": bool(entry.get("destroyed", false)),
		})
		next_site_id = maxi(next_site_id, int(entry.get("id", 0)) + 1)
	for entry in data.get("depleted", []):
		if typeof(entry) == TYPE_ARRAY and (entry as Array).size() >= 3:
			depleted.append({"coord": Vector2i(int(entry[0]), int(entry[1])), "turn": int(entry[2])})
	var seed_text := String(data.get("rng_seed", ""))
	var state_text := String(data.get("rng_state", ""))
	if seed_text.is_valid_int():
		rng.seed = int(seed_text)
	elif grid != null:
		rng.seed = grid.map_seed + MonsterEcologyData.RNG_SALT
	if state_text.is_valid_int():
		rng.state = int(state_text)
	# V3 / Etapa 2: só restaura — nada emerge, expande ou causa dano no load (avança só na fronteira de rodada).
	MonsterAbilitySystem.load_save_array(data.get("burrowed", []), grid)
	MonsterHazardSystem.load_save_dict(data.get("hazards", {}), grid)
	_restore_indices(grid, int(data.get("lair_rules_version", 0)) < 1)
	_orphan_unknown_units(grid)

static func _restore_indices(grid: HexGrid, choose_missing: bool) -> void:
	_sites_by_id = {}
	_sites_by_lair = {}
	_leaders = {}
	for site in sites:
		_index_site(site)
	if grid == null:
		return
	var members := grid.neutral_units()
	for worm in MonsterAbilitySystem.burrowed:
		if is_instance_valid(worm):
			members.append(worm)
	for unit in members:
		var site := site_by_id(unit.ecology_site_id)
		if site.is_empty() or bool(site.get("destroyed", false)):
			continue
		if site.lair != HexGrid.NO_LAIR:
			unit.source_lair_coord = site.lair
		# Saves históricos atribuem serial 0 a todos os neutros. A marca persistida na própria
		# criatura é a identidade do líder; serial sozinho promoveria qualquer sobrevivente.
		if bool(unit.ability_state.get("lair_leader", false)) or (choose_missing and (not _leaders.has(int(site.id)) or unit.is_camp_boss)):
			_set_leader(site, unit)

## Saves anteriores: preserva todas as criaturas e seus atributos; materializa o covil na primeira
## rodada, nunca dentro de deserialize. Uma busca LOCAL por sítio, sem varredura do mapa.
static func _migrate_lairs(grid: HexGrid, turn: int) -> void:
	_needs_lair_migration = false
	for coord in grid.lair_coords.duplicate():
		register_lair(grid, coord, turn)
	for site in sites:
		if site.lair != HexGrid.NO_LAIR or bool(site.get("destroyed", false)):
			continue
		var options := MonsterEcologyPlanner.sorted_coords([site.anchor] + HexMetrics.coords_within(site.anchor, 2))
		options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da := HexMetrics.axial_distance(site.anchor, a)
			var db := HexMetrics.axial_distance(site.anchor, b)
			return a.x < b.x if da == db and a.x != b.x else (a.y < b.y if da == db else da < db))
		var chosen := HexGrid.NO_LAIR
		for coord in options:
			if MonsterEcologyPlanner.is_legal_spawn_tile(grid, coord) and MonsterEcologyPlanner.lair_clearance_ok(grid, coord):
				chosen = coord
				break
		if chosen == HexGrid.NO_LAIR:
			_needs_lair_migration = true
			continue
		grid.create_lair(chosen, String(site.species), HexGrid.LAIR_ROLE_ECOLOGY)
		site.lair = chosen
		_sites_by_lair[chosen] = site
		for unit in grid.neutral_units():
			if unit.ecology_site_id == int(site.id):
				unit.source_lair_coord = chosen
		var leader: Unit = _leaders.get(int(site.id))
		if leader != null and is_instance_valid(leader):
			leader.source_lair_coord = chosen

static func _orphan_unknown_units(grid: HexGrid) -> void:
	if grid == null:
		return
	var known := {}
	for site in sites:
		known[int(site.id)] = true
	for unit in grid.neutral_units():
		if unit.ecology_site_id >= 0 and not known.has(unit.ecology_site_id):
			unit.ecology_site_id = -1

static func _coord(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return HexGrid.NO_LAIR
