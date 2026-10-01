class_name RegionalThreatSystem
extends RefCounted

## Fase 33D2 — runtime das AMEAÇAS DO MUNDO da Era do Despertar/Ascensão
## (docs/AETHERLANDS_STRATEGIC_PACING_OBJECTIVES_DESIGN.md §6/§7/§10).
##
## - Ameaça regional: exatamente UMA por civilização, criada quando a primeira capital REAL existe
##   (setup das capitais em GameManager._spawn_starting_forces; fundação manual via HexGrid.found_city),
##   nunca por captura. Ciclo DORMANT → AWAKE → RESOLVED, permanente, sem substituição.
## - Guardiões Troll: criados uma vez na entrada da Ascensão (WorldEventManager.advance_world_phase).
##
## Estado persistente em WorldEventManager (regional_threats, guardian_sites, flags); a colocação é do
## RegionalThreatPlanner; o covil em si vive no HexGrid (papel, população por covil). Só partidas NOVAS
## pós-D2 recebem ameaças (regional_threats_enabled) — um save antigo nunca ganha ameaça retroativa.
## O mundo não sabe quem é humano: tudo é por índice de assento.

const STATE_NONE := "NONE"
const STATE_DORMANT := "DORMANT"
const STATE_AWAKE := "AWAKE"
const STATE_RESOLVED := "RESOLVED"
const GUARDIAN_ACTIVE := "ACTIVE"

## População própria de um covil regional (chefe + até 2), contada por covil — fora do teto global.
const REGIONAL_POPULATION_CAP := 3
## Recompensas de destruir a ESTRUTURA por papel (substituem a do tipo, nunca somam). PROVISÓRIAS: a F33E
## mede e calibra. Nunca Conhecimento.
const REGIONAL_REWARDS := {
	"goblin": {"gold": 40.0, "mana": 0.0},
	"skeleton": {"gold": 40.0, "mana": 5.0},
}
const GUARDIAN_REWARD := {"gold": 75.0, "mana": 0.0}
## Teatro regional (Era do Despertar): raio a partir do covil = distância até a capital + margem — alcança
## os arredores da capital, nunca o mapa inteiro.
const THEATER_MARGIN := 3

## GameManager._spawn_starting_forces liga isto enquanto funda as capitais do setup: o planejamento acontece
## uma vez, com TODAS as âncoras conhecidas (senão a ameaça de um assento ignoraria o vizinho seguinte).
static var defer_planning := false

static func enabled() -> bool:
	return WorldEventManager.regional_threats_enabled

# ---------------------------------------------------------------------------
# Criação
# ---------------------------------------------------------------------------

## Chamado por HexGrid.found_city (não silenciosa). Planeja só na PRIMEIRA capital de uma civilização
## (qualquer assento) — segunda cidade, captura e load nunca criam ameaça.
static func on_city_founded(grid: HexGrid, player: PlayerData, city: City) -> void:
	if not enabled() or defer_planning or grid == null or player == null or city == null:
		return
	var index := GameManager.players.find(player)
	if index < 0 or not record_for_index(index).is_empty():
		return
	_plan_for(grid, player, index, city.coord)

## Fim do setup: planeja, na ordem dos assentos, todas as civilizações que já têm capital.
static func plan_pending(grid: HexGrid) -> void:
	if not enabled() or grid == null:
		return
	for index in GameManager.players.size():
		var player: PlayerData = GameManager.players[index]
		if player.cities.is_empty() or not record_for_index(index).is_empty():
			continue
		_plan_for(grid, player, index, player.cities[0].coord)

static func _plan_for(grid: HexGrid, player: PlayerData, index: int, capital: Vector2i) -> void:
	var turn := TurnManager.turn_number
	var placed := RegionalThreatPlanner.place_regional(grid, player, index, capital, _other_anchors(player), turn)
	var record := {
		"owner": index, "anchor": capital, "coord": placed.coord, "kind": String(placed.kind), "source": String(placed.source),
		"created_turn": turn, "wake_turn": int(placed.wake_turn), "state": STATE_DORMANT if placed.ok else STATE_NONE,
		"resolved_turn": -1, "resolved_by": -1, "discovered_by": [],
		"visible_at_creation": bool(placed.visible_at_creation), "explored_at_creation": bool(placed.explored_at_creation),
		"relocated": int(placed.relocated), "removed": int(placed.removed), "preserved_close": int(placed.preserved_close),
		"corridor_neighbors": int(placed.corridor_neighbors), "corridor_violation": bool(placed.corridor_violation),
	}
	WorldEventManager.regional_threats.append(record)
	if placed.ok:
		EventBus.regional_threat_created.emit(player, record.coord, record.kind)
		note_observation(grid, player)

## Âncoras das OUTRAS civilizações: capital da ameaça já planejada, primeira cidade ou, antes de fundar,
## o Colonizador inicial (o tile reservado em _spawn_starting_forces).
static func _other_anchors(player: PlayerData) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in GameManager.players.size():
		var other: PlayerData = GameManager.players[index]
		if other == player:
			continue
		var record := record_for_index(index)
		if not record.is_empty():
			result.append(record.anchor)
		elif not other.cities.is_empty():
			result.append(other.cities[0].coord)
		else:
			for unit in other.units:
				if is_instance_valid(unit) and unit.unit_data.can_found_city:
					result.append(unit.coord)
					break
	return result

# ---------------------------------------------------------------------------
# Ciclo de vida
# ---------------------------------------------------------------------------

## Uma vez por turno, no tick de covis (HexGrid.process_monster_lairs), antes do reforço.
static func process_turn(grid: HexGrid, turn: int) -> void:
	if not enabled():
		return
	for record in WorldEventManager.regional_threats:
		if String(record.state) != STATE_DORMANT or turn < int(record.wake_turn):
			continue
		if grid == null or not grid.lairs_by_coord.has(record.coord):
			continue
		record.state = STATE_AWAKE
		EventBus.regional_threat_awakened.emit(_player_at(int(record.owner)), record.coord, String(record.kind))

## Estrutura destruída (HexGrid._grant_lair_clear_reward). Recompensa já paga pelo HexGrid (pelo papel).
static func on_lair_destroyed(coord: Vector2i, role: String, resolver: PlayerData) -> void:
	var resolver_index := GameManager.players.find(resolver)
	var turn := TurnManager.turn_number
	match role:
		HexGrid.LAIR_ROLE_REGIONAL:
			var record := record_for_lair(coord)
			if record.is_empty() or String(record.state) == STATE_RESOLVED:
				return
			record.state = STATE_RESOLVED
			record.resolved_turn = turn
			record.resolved_by = resolver_index
			EventBus.world_threat_resolved.emit(role, _player_at(int(record.owner)), coord, resolver)
		HexGrid.LAIR_ROLE_GUARDIAN:
			var site := guardian_for_lair(coord)
			if site.is_empty() or String(site.state) == STATE_RESOLVED:
				return
			site.state = STATE_RESOLVED
			site.resolved_turn = turn
			site.resolved_by = resolver_index
			EventBus.world_threat_resolved.emit(role, null, coord, resolver)

## Descoberta = o tile do covil entrou no conhecimento da civilização (PlayerData.explored_tiles), pelas
## regras normais de visão. Chamado ao fim de HexGrid.recompute_fog e de V2AIWorldView.capture. Nunca
## revela nada: só registra/anuncia o que a civ já conhece.
static func note_observation(grid: HexGrid, player: PlayerData) -> void:
	if not enabled() or grid == null or player == null:
		return
	var index := GameManager.players.find(player)
	if index < 0:
		return
	for record in WorldEventManager.regional_threats:
		if String(record.state) in [STATE_DORMANT, STATE_AWAKE] and index not in record.discovered_by and player.explored_tiles.has(record.coord) and grid.lairs_by_coord.has(record.coord):
			record.discovered_by.append(index)
			EventBus.world_threat_discovered.emit(player, record.coord, HexGrid.LAIR_ROLE_REGIONAL)
	for site in WorldEventManager.guardian_sites:
		if String(site.state) == GUARDIAN_ACTIVE and index not in site.discovered_by and player.explored_tiles.has(site.coord) and grid.lairs_by_coord.has(site.coord):
			site.discovered_by.append(index)
			EventBus.world_threat_discovered.emit(player, site.coord, HexGrid.LAIR_ROLE_GUARDIAN)

## Entrada na Ascensão (WorldEventManager.advance_world_phase): cria os Guardiões uma única vez por partida.
static func spawn_guardians(grid: HexGrid, turn: int) -> void:
	if not enabled() or grid == null or WorldEventManager.guardians_spawned:
		return
	WorldEventManager.guardians_spawned = true
	var anchors := {}
	for index in GameManager.players.size():
		var player: PlayerData = GameManager.players[index]
		if player.cities.is_empty():
			continue
		var record := record_for_index(index)
		anchors[index] = record.anchor if not record.is_empty() else player.cities[0].coord
	var unresolved: Array[Vector2i] = []
	for record in WorldEventManager.regional_threats:
		if String(record.state) in [STATE_DORMANT, STATE_AWAKE]:
			unresolved.append(record.coord)
	var placed := RegionalThreatPlanner.place_guardians(grid, anchors, unresolved)
	WorldEventManager.guardian_stats = placed.stats
	for site in placed.sites:
		var entry := {
			"coord": site.coord, "resource_coord": site.resource_coord, "resource": String(site.resource),
			"kind": RegionalThreatPlanner.TROLL, "for_players": site.for_players.duplicate(), "created_turn": turn,
			"state": GUARDIAN_ACTIVE, "resolved_turn": -1, "resolved_by": -1, "discovered_by": [],
		}
		WorldEventManager.guardian_sites.append(entry)
		EventBus.guardian_site_spawned.emit(entry.coord, entry.resource_coord, entry.resource)
	for player in GameManager.players:
		note_observation(grid, player)

# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

static func record_for_index(index: int) -> Dictionary:
	for record in WorldEventManager.regional_threats:
		if int(record.owner) == index:
			return record
	return {}

static func record_for_player(player: PlayerData) -> Dictionary:
	return record_for_index(GameManager.players.find(player))

static func record_for_lair(coord: Vector2i) -> Dictionary:
	for record in WorldEventManager.regional_threats:
		if String(record.state) != STATE_NONE and record.coord == coord:
			return record
	return {}

static func guardian_for_lair(coord: Vector2i) -> Dictionary:
	for site in WorldEventManager.guardian_sites:
		if site.coord == coord:
			return site
	return {}

static func is_regional_lair_awake(coord: Vector2i) -> bool:
	var record := record_for_lair(coord)
	return not record.is_empty() and String(record.state) == STATE_AWAKE

## Recompensa do PAPEL (vazio = papel selvagem, usa a do tipo).
static func role_clear_reward(role: String, kind: String) -> Dictionary:
	match role:
		HexGrid.LAIR_ROLE_REGIONAL:
			return (REGIONAL_REWARDS.get(kind, REGIONAL_REWARDS[RegionalThreatPlanner.GOBLIN]) as Dictionary).duplicate()
		HexGrid.LAIR_ROLE_GUARDIAN:
			return GUARDIAN_REWARD.duplicate()
	return {}

## Como a MonsterAI deve tratar um monstro ligado a um covil com papel. {} = comportamento normal do tipo.
## - "dormant": guarda a porta do covil (raio de Guardião), nunca saqueia nem sai.
## - "regional": desperto na Era do Despertar — preso ao teatro regional (sem promoção a Invasor de mapa).
## - "guardian": Guardião Troll ancorado no próprio covil.
## Na Ascensão em diante, a ameaça regional sobrevivente volta ao comportamento normal do tipo.
static func monster_directive(unit: Unit, grid: HexGrid) -> Dictionary:
	if unit == null or grid == null or unit.source_lair_coord == HexGrid.NO_LAIR:
		return {}
	var coord := unit.source_lair_coord
	match grid.lair_role(coord):
		HexGrid.LAIR_ROLE_REGIONAL:
			var record := record_for_lair(coord)
			if record.is_empty():
				return {}
			if String(record.state) == STATE_DORMANT:
				return {"mode": "dormant", "anchor": coord, "radius": MonsterAI.GUARD_RADIUS}
			if String(record.state) == STATE_AWAKE and WorldEventManager.world_phase == WorldPhaseRules.Phase.FOUNDATION:
				return {"mode": "regional", "anchor": coord, "radius": HexMetrics.axial_distance(coord, record.anchor) + THEATER_MARGIN}
		HexGrid.LAIR_ROLE_GUARDIAN:
			var radius := int(MonsterDatabase.KIND_DATA.get(unit.unit_data.visual_kind, {}).get("guard_radius", MonsterAI.GUARD_RADIUS))
			return {"mode": "guardian", "anchor": coord, "radius": radius}
	return {}

## Promoção de bando a Invasor (MonsterAI) bloqueada para covis com papel enquanto o mundo está no
## Despertar (regional) e sempre para Guardiões.
static func blocks_invader_promotion(grid: HexGrid, lair_coord: Vector2i) -> bool:
	match grid.lair_role(lair_coord):
		HexGrid.LAIR_ROLE_REGIONAL:
			return WorldEventManager.world_phase == WorldPhaseRules.Phase.FOUNDATION or not is_regional_lair_awake(lair_coord)
		HexGrid.LAIR_ROLE_GUARDIAN:
			return true
	return false

## Estado player-facing do covil (TileInspector): "" se sem papel.
static func public_state_text(coord: Vector2i) -> String:
	var record := record_for_lair(coord)
	if record.is_empty():
		return ""
	match String(record.state):
		STATE_DORMANT:
			return "Adormecido"
		STATE_AWAKE:
			return "Desperto"
	return ""

## Objetivos WORLD THREAT / OPPORTUNITY derivados (nunca salvos): a ameaça regional da própria civ, só
## depois de descoberta por ela. status: active | resolved | resolved_by_other.
static func objectives_for(player: PlayerData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var index := GameManager.players.find(player)
	var record := record_for_index(index)
	if record.is_empty() or String(record.state) == STATE_NONE or index not in record.discovered_by:
		return result
	var status := "active"
	if String(record.state) == STATE_RESOLVED:
		status = "resolved" if int(record.resolved_by) == index else "resolved_by_other"
	result.append({
		"id": "regional_threat", "category": "world_threat", "title": "Ameaça regional",
		"text": "Um covil hostil ameaça os arredores de seu reino." if status == "active" else "A ameaça regional foi eliminada.",
		"target": record.coord, "status": status,
	})
	return result

static func _player_at(index: int) -> PlayerData:
	return GameManager.players[index] if index >= 0 and index < GameManager.players.size() else null

# ---------------------------------------------------------------------------
# Persistência (bloco "regional" de world_events)
# ---------------------------------------------------------------------------

static func to_save_dict() -> Dictionary:
	var threats: Array = []
	for record in WorldEventManager.regional_threats:
		var entry: Dictionary = record.duplicate(true)
		entry.anchor = [record.anchor.x, record.anchor.y]
		entry.coord = [record.coord.x, record.coord.y]
		threats.append(entry)
	var guardians: Array = []
	for site in WorldEventManager.guardian_sites:
		var entry: Dictionary = site.duplicate(true)
		entry.coord = [site.coord.x, site.coord.y]
		entry.resource_coord = [site.resource_coord.x, site.resource_coord.y]
		guardians.append(entry)
	return {
		"enabled": WorldEventManager.regional_threats_enabled,
		"threats": threats,
		"guardians": guardians,
		"guardians_spawned": WorldEventManager.guardians_spawned,
	}

## Save sem o bloco (≤ v22): ameaças desligadas, nada retroativo.
static func load_save_dict(data: Variant) -> void:
	WorldEventManager.regional_threats_enabled = false
	WorldEventManager.regional_threats = []
	WorldEventManager.guardian_sites = []
	WorldEventManager.guardians_spawned = false
	WorldEventManager.guardian_stats = {}
	if typeof(data) != TYPE_DICTIONARY:
		return
	WorldEventManager.regional_threats_enabled = bool(data.get("enabled", false))
	WorldEventManager.guardians_spawned = bool(data.get("guardians_spawned", false))
	for saved in data.get("threats", []):
		if typeof(saved) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = saved.duplicate(true)
		record.owner = int(saved.get("owner", -1))
		record.anchor = _coord(saved.get("anchor"))
		record.coord = _coord(saved.get("coord"))
		record.wake_turn = int(saved.get("wake_turn", -1))
		record.created_turn = int(saved.get("created_turn", -1))
		record.resolved_turn = int(saved.get("resolved_turn", -1))
		record.resolved_by = int(saved.get("resolved_by", -1))
		record.state = String(saved.get("state", STATE_NONE))
		record.discovered_by = _int_list(saved.get("discovered_by", []))
		WorldEventManager.regional_threats.append(record)
	for saved in data.get("guardians", []):
		if typeof(saved) != TYPE_DICTIONARY:
			continue
		var site: Dictionary = saved.duplicate(true)
		site.coord = _coord(saved.get("coord"))
		site.resource_coord = _coord(saved.get("resource_coord"))
		site.for_players = _int_list(saved.get("for_players", []))
		site.discovered_by = _int_list(saved.get("discovered_by", []))
		site.created_turn = int(saved.get("created_turn", -1))
		site.resolved_turn = int(saved.get("resolved_turn", -1))
		site.resolved_by = int(saved.get("resolved_by", -1))
		site.state = String(saved.get("state", GUARDIAN_ACTIVE))
		WorldEventManager.guardian_sites.append(site)

static func _coord(value: Variant) -> Vector2i:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return HexGrid.NO_LAIR

static func _int_list(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			if typeof(item) in [TYPE_INT, TYPE_FLOAT]:
				result.append(int(item))
	return result
