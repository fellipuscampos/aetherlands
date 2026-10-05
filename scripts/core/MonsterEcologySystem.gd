class_name MonsterEcologySystem
extends RefCounted

## V3 / Combat Ecology — Etapa 1 (Foundation). Runtime da ecologia hostil do mundo
## (docs/AETHERLANDS_V3_IMPLEMENTATION.md, visão em docs/# Aetherlands V3 — Visão e Direção.md).
##
## Responsável SÓ por: registro de sítios ecológicos (espécie, tier derivado, âncora, covil opcional),
## população inicial de uma partida nova, alvo de população por tier, reposição gradual ponderada pela
## Era, diretiva de atividade por Era para a MonsterAI, telemetria (EventBus.combat_ecology_event) e
## persistência. NÃO duplica combate (CombatResolver), movimento/pathfinding (HexGrid), a ameaça regional
## (RegionalThreatSystem/Planner) nem eventos mundiais (Dragão/Relicário ficam fora do orçamento).
##
## Um SÍTIO é um grupo ancorado: covil herdado da seed (estrutura + papel HexGrid.LAIR_ROLE_ECOLOGY) ou
## só uma âncora territorial (sem estrutura, nem recompensa de covil — a ecologia não injeta ouro de
## estrutura no mapa). O monstro aponta para o sítio por Unit.ecology_site_id. Sítio sem nenhum membro
## vivo se esvazia (sai do registro, vira memória regional) e a reposição cria OUTRO sítio mais tarde,
## em outro lugar, fora da visão das civilizações.
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
	MonsterHazardSystem.reset() # V3 / Etapa 2: raízes, infecção, marcadores
	MonsterAbilitySystem.reset() # V3 / Etapa 2: Vermes subterrâneos

# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

static func site_by_id(site_id: int) -> Dictionary:
	for site in sites:
		if int(site.id) == site_id:
			return site
	return {}

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
		var room := maxi(0, int(targets[tier]) - int(count_by_tier[tier]))
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
			_create_site(grid, kind, anchor, HexGrid.NO_LAIR, SOURCE_INITIAL, turn, MonsterEcologyPlanner.group_tiles(grid, anchor, group, tier, anchors))
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
## existente com um sítio novo ao lado. Dragão e covis fora do continente principal ficam intocados.
static func _adopt_legacy_lairs(grid: HexGrid, anchors: Array[Vector2i], turn: int, count_by_tier: Dictionary, stats: Dictionary) -> void:
	for lair_coord in MonsterEcologyPlanner.sorted_coords(grid.lair_coords.duplicate()):
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
			if occupant != null and occupant.owner_player == null and not occupant.world_event_managed and occupant.source_event_id < 0 and occupant.source_lair_coord in [lair_coord, HexGrid.NO_LAIR]:
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
		count_by_tier[tier] = int(count_by_tier[tier]) + 1
		stats.adopted = int(stats.adopted) + 1

static func _create_site(grid: HexGrid, kind: String, anchor: Vector2i, lair: Vector2i, source: String, turn: int, members: Array[Vector2i]) -> Dictionary:
	var site := {"id": next_site_id, "species": kind, "anchor": anchor, "lair": lair, "created_turn": turn, "source": source}
	next_site_id += 1
	sites.append(site)
	for coord in members:
		var unit := grid.spawn_monster_at(coord, kind)
		unit.ecology_site_id = int(site.id)
		if lair != HexGrid.NO_LAIR:
			unit.source_lair_coord = lair
	return site

# ---------------------------------------------------------------------------
# Rodada global: esvaziamento + reposição
# ---------------------------------------------------------------------------

## Uma vez por rodada (HexGrid.process_monster_lairs, antes do reforço dos covis e da MonsterAI).
static func process_round(grid: HexGrid, turn: int) -> void:
	if not enabled or grid == null:
		return
	_refresh_sites(grid, turn)
	# V3 / Etapa 2: perigos espaciais (raízes expiram, infecção cresce/decai) e Vermes que emergem.
	MonsterHazardSystem.process_round(grid, turn, _live_hive_sites(grid))
	MonsterAbilitySystem.process_round(grid, turn)
	if targets.is_empty():
		# Save anterior à V3: alvo calculado na primeira fronteira de rodada (nunca dentro do load).
		eligible_count = eligible(grid).size()
		targets = MonsterEcologyData.targets_for(eligible_count)
		if rng.seed == 0:
			rng.seed = grid.map_seed + MonsterEcologyData.RNG_SALT
	if turn < next_refill_turn:
		return
	var deficits := deficits_by_tier()
	var phase := WorldEventManager.world_phase
	var tier := MonsterEcologyPlanner.choose_refill_tier(phase, deficits, rng)
	if tier == "":
		next_refill_turn = turn + 1
		return
	var species := MonsterEcologyData.species_of_tier(tier)
	var kind: String = species[rng.randi_range(0, species.size() - 1)]
	var group := MonsterEcologyData.group_size(kind)
	var anchors := capital_anchors()
	var blocked := MonsterEcologyPlanner.refill_blocked_tiles(grid, GameManager.players)
	var anchor := MonsterEcologyPlanner.find_refill_anchor(grid, eligible(grid), tier, group, anchors, sites, depleted, blocked, turn, rng, kind, habitat_cache(grid))
	if anchor == HexGrid.NO_LAIR:
		next_refill_turn = turn + 1
		return
	var site := _create_site(grid, kind, anchor, HexGrid.NO_LAIR, SOURCE_REFILL, turn, MonsterEcologyPlanner.group_tiles(grid, anchor, group, tier, anchors))
	next_refill_turn = turn + MonsterEcologyData.REFILL_INTERVAL
	emit_event("refill", kind, {"site": int(site.id), "coord": [anchor.x, anchor.y]})

## Conta membros vivos por sítio (uma varredura das unidades neutras); sítio sem ninguém se esvazia.
static func _refresh_sites(grid: HexGrid, turn: int) -> void:
	var alive := _alive_by_site(grid)
	var kept: Array[Dictionary] = []
	for site in sites:
		if int(alive.get(int(site.id), 0)) > 0:
			kept.append(site)
			continue
		depleted.append({"coord": site.anchor, "turn": turn})
		emit_event("site_depleted", String(site.species), {"site": int(site.id), "anchor": [site.anchor.x, site.anchor.y]})
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
		var tier := MonsterEcologyData.tier_of(String(site.species))
		result[tier] = int(result.get(tier, 0)) + 1
	return result

static func deficits_by_tier() -> Dictionary:
	var current := sites_by_tier()
	var result := {}
	for tier in MonsterEcologyData.TIERS:
		result[tier] = maxi(0, int(targets.get(tier, 0)) - int(current.get(tier, 0)))
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
	return MonsterActivityProfile.label(directive.profile) if not directive.is_empty() else ""

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
		})
	var saved_depleted: Array = []
	for entry in depleted:
		saved_depleted.append([entry.coord.x, entry.coord.y, int(entry.turn)])
	return {
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
		if grid != null:
			rng.seed = grid.map_seed + MonsterEcologyData.RNG_SALT
		next_refill_turn = TurnManager.turn_number + 1
		_orphan_unknown_units(grid)
		return
	enabled = bool(data.get("enabled", false))
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
	_orphan_unknown_units(grid)

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
