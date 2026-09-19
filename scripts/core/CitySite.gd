class_name CitySite
extends RefCounted

## EXPANSAO E FUNDACAO DE CIDADES (Task 22) -- regra estrutural de distancia
## + avaliacao estrategica de local, compartilhadas por jogador e IA.
##
## CAUSA RAIZ do problema ("IA funda colada numa cidade ja existente"):
##  - O jogador humano NAO tinha regra nenhuma (SelectionManager so' checava
##    "ja tem cidade neste tile"); a IA tinha SETTLE_MIN_DISTANCE=3 so' no
##    codigo dela (RivalAI._far_enough_from_cities), como excecao "so' pra IA".
##  - A IA escolhia o local por "quantos vizinhos imediatos tem recurso" (anel
##    de 6 tiles) -- nunca olhava coesao com as proprias cidades, espaco pra
##    crescer, seguranca, terreno, nem o territorio que a cidade REALMENTE usa
##    (raio 2). Com mais de 2 cidades, settle_toward_resources ainda varria o
##    mapa explorado INTEIRO com so' 0.15 de penalidade por tile de distancia
##    (cidades soltas a dezenas de tiles do imperio); com 1 cidade, o segundo
##    colonizador fundava no primeiro tile a 3 de distancia.
##
## SOLUCAO em duas camadas, ambas AQUI (nenhum `if ai`):
##  1. REGRA ESTRUTURAL: rejection_reason() vale pra qualquer colonizador
##     (WorldSetup.found_city_from_settler recusa; a HUD desabilita o botao e
##     explica o motivo). Distancia minima entre centros urbanos = min_city_
##     distance (4, ver a justificativa abaixo), de QUALQUER dono.
##  2. AVALIACAO: evaluate()/choose_site() pontuam um local de cidade pela
##     mesma unidade ("pontos" ~ um tile bom = ~1 ponto) somando valor local
##     (rendimento do territorio real da cidade, recursos com raridade e
##     retorno decrescente, Nodulos Arcanos), terreno, espaco pra crescer,
##     coesao com o imperio, seguranca (covil/monstro/pressao rival) e
##     valor estrategico. Coesao NUNCA e' regra absoluta: e' uma penalidade
##     que um local excepcional (ex: Nodulo + recursos raros) consegue pagar.
##
## POR QUE 4 (e nao 3 nem 5): a cidade comeca com 7 tiles (raio 1) e ganha 1
## tile de territorio por ponto de populacao (City._claim_frontier_tile), ou
## seja, raio ~2 (19 tiles) so' com populacao ~12 -- e cidade trabalha no
## maximo `population` tiles. Distancia 3 faz os raios 1 se tocarem ja' na
## fundacao (a IA antiga produzia isto: "cidade - 2 tiles - cidade");
## distancia 4 deixa 2 tiles livres entre as bordas iniciais e so' sobrepoe
## territorios de raio 2 de forma parcial; 5+ ja' desperdiça mapa em partidas
## de 4 civs. O valor ideal de espacamento (5..7, IDEAL_SPACING_*) NAO e' regra:
## e' o que a pontuacao prefere. Medido com o harness de metricas (ver
## Claude_updates.md).

## Distancia hexagonal minima entre QUALQUER par de centros urbanos (de
## qualquer dono). `static var` (nao const) so' pra experimentos de
## calibracao poderem sobrescrever -- mesmo padrao de RivalAI.WAR_OBJECTIVE_*.
static var min_city_distance: int = 4

const REASON_TERRAIN := "terrain"
const REASON_CITY := "city"
const REASON_BUILDING := "building"
const REASON_LAIR := "lair"
const REASON_TOO_CLOSE := "too_close"
const REASON_FOREIGN_TERRITORY := "foreign_territory"

## Territorio que a cidade REALMENTE usa (raio 2 = 18 tiles + centro) e o anel
## de "espaco pra crescer" logo alem dele.
const CATCHMENT_RADIUS := 2
const GROWTH_RING := 3
const MAX_RING := 3
## Peso do rendimento por anel (anel 1 = vizinhos imediatos, sempre
## trabalhaveis; anel 2 so' entra com populacao maior).
const RING_WEIGHTS := [1.0, 0.5]
## Tile que ja' cai no raio de uma cidade PROPRIA conta so' esta fracao (a
## cidade mais antiga tende a ficar com ele: e' territorio desperdicado).
const OVERLAP_OWN_FACTOR := 0.3
## Rendimento bruto -> pontos (mesma mistura de City._tile_claim_score: comida
## 1.5, producao 1.3, ouro 1.0), dividido pra um tile bom valer ~1 ponto.
const TILE_POINTS_DIVISOR := 4.0
## Recursos: pontos-base por tile de recurso x raridade; cada fonte do MESMO
## recurso que o jogador ja controla reduz o valor de mais uma (retorno
## decrescente -- o desconto de custo de cada recurso tem teto, ver
## ResourceDatabase.*_MAX). Nodulo Arcano e' o mais raro e o unico que a IA
## de estrategia Arcana quer de verdade.
const RESOURCE_BASE_POINTS := 1.0
const RESOURCE_RARITY := {"iron": 1.0, "horses": 1.0, "gems": 1.6, "silk": 1.6, "mana_node": 4.5}
const RESOURCE_REPEAT_DECAY := 0.25
const ARCANE_NODE_EXTRA_POINTS := 5.0
const DIVERSITY_POINTS_PER_TERRAIN := 0.3
const DIVERSITY_MAX_EXTRA_TERRAINS := 3
const COAST_POINTS := 0.5
## Defensibilidade: bonus de defesa do terreno do CENTRO (colina 0.5 -> 1.0
## ponto) + vizinhos que barram acesso (agua/montanha: gargalo natural).
const DEFENSE_POINTS_PER_BONUS := 2.0
const BARRIER_POINTS_PER_NEIGHBOR := 0.25
const BARRIER_MAX_NEIGHBORS := 3
## Espaco pra expansao: fracao do anel 3 ainda livre (trabalhavel, sem dono,
## fora do raio de qualquer cidade).
const SPACE_POINTS := 2.0
## Coesao (so' vale com pelo menos 1 cidade propria): faixa ideal de
## espacamento, penalidade por ficar apertado ou esticado, e penalidade extra
## de "enclave" alem de ENCLAVE_DISTANCE.
const IDEAL_SPACING_MIN := 5
const IDEAL_SPACING_MAX := 7
const CROWDING_PENALTY_PER_TILE := 2.5
const STRETCH_PENALTY_PER_TILE := 1.0
const ENCLAVE_DISTANCE := 11
const ENCLAVE_EXTRA_PENALTY_PER_TILE := 1.0
## Seguranca (sempre penalidades ADITIVAS, nunca bloqueio -- mesma filosofia
## de get_lair_danger_at): covil vivo (0..1 x peso), monstro movel num raio
## curto, cidade rival perto (HexGrid.is_under_rival_pressure).
const LAIR_DANGER_PENALTY := 14.0
const MONSTER_RADIUS := 5
const MONSTER_PENALTY_EACH := 0.6
const MONSTER_PENALTY_MAX_COUNT := 3
const RIVAL_PRESSURE_PENALTY := 3.0
## Bloquear a expansao rival: local a 5..8 tiles da cidade rival mais
## proxima, ainda sem dono, ganha um pequeno bonus (a terra seria dela).
const CONTEST_MIN_DISTANCE := 5
const CONTEST_MAX_DISTANCE := 8
const CONTEST_BONUS := 1.5

## Busca: raio em volta das cidades proprias, quantos candidatos passam pela
## pre-pontuacao barata pra avaliacao completa, e quantos caminhos checa.
const SEARCH_RADIUS := 12
const FULL_EVAL_LIMIT := 24
const PATH_CHECK_LIMIT := 8
const TRAVEL_PENALTY_PER_TILE := 0.12
## Abaixo disto o local e' "obviamente ruim" (deserto/gelo sem nada): o
## colonizador prefere explorar mais um pouco (SETTLE_PATIENCE_TURNS) antes
## de aceitar qualquer coisa, e a IA nem produz colonizador sem local aceitavel.
const MIN_ACCEPTABLE_SCORE := 6.0
const SETTLE_PATIENCE_TURNS := 10
## O alvo ja escolhido so' e' trocado se outro local for pelo menos isto
## melhor (evita oscilacao entre locais empatados).
const SWITCH_MARGIN := 1.5
## Turnos sem procurar de novo depois de uma busca que nao achou local
## aceitavel (ver RivalAI.decide_production).
const NO_SITE_RETRY_TURNS := 8

static var _ring_offsets: Array = []

# ---------------------------------------------------------------------------
# Regra estrutural
# ---------------------------------------------------------------------------

## "" = pode fundar cidade em `coord`; senao o codigo do motivo (REASON_*).
## Vale pra qualquer dono (`player` so' distingue territorio proprio do de
## outra civ).
static func rejection_reason(hex_grid: HexGrid, coord: Vector2i, player: PlayerData) -> String:
	var tile: HexTileData = hex_grid.get_tile(coord)
	if tile == null or tile.blocks_land_units():
		return REASON_TERRAIN
	if hex_grid.get_city_at(coord) != null:
		return REASON_CITY
	if hex_grid.lairs_by_coord.has(coord):
		return REASON_LAIR
	if hex_grid.buildings_by_coord.has(coord):
		return REASON_BUILDING
	for city in hex_grid.cities_by_coord.values():
		if HexMetrics.axial_distance(coord, city.coord) < min_city_distance:
			return REASON_TOO_CLOSE
	var territory_owner: City = hex_grid.city_owning_tile(coord)
	if territory_owner != null and territory_owner.owner_player != player:
		return REASON_FOREIGN_TERRITORY
	return ""

static func can_found(hex_grid: HexGrid, coord: Vector2i, player: PlayerData) -> bool:
	return rejection_reason(hex_grid, coord, player) == ""

static func reason_text(reason: String) -> String:
	match reason:
		REASON_TERRAIN:
			return "Terreno inadequado para fundar uma cidade."
		REASON_CITY:
			return "Ja existe uma cidade aqui."
		REASON_BUILDING:
			return "Ha uma construcao neste tile."
		REASON_LAIR:
			return "Ha um covil de monstros neste tile."
		REASON_TOO_CLOSE:
			return "Muito perto de outra cidade (distancia minima: %d tiles)." % min_city_distance
		REASON_FOREIGN_TERRITORY:
			return "Este tile pertence ao territorio de outra civilizacao."
	return ""

# ---------------------------------------------------------------------------
# Avaliacao de local
# ---------------------------------------------------------------------------

## Offsets axiais (dq, dr) a exatamente `ring` tiles do centro -- calculados
## uma vez (varrer vizinhos por BFS a cada candidato custaria caro).
static func _offsets_for(ring: int) -> Array:
	if _ring_offsets.is_empty():
		for i in range(MAX_RING):
			_ring_offsets.append([])
		for dq in range(-MAX_RING, MAX_RING + 1):
			for dr in range(-MAX_RING, MAX_RING + 1):
				var offset := Vector2i(dq, dr)
				var distance := HexMetrics.axial_distance(Vector2i.ZERO, offset)
				if distance >= 1 and distance <= MAX_RING:
					_ring_offsets[distance - 1].append(offset)
	return _ring_offsets[ring - 1]

static func tile_points(data: HexTileData) -> float:
	return (data.food_yield * 1.5 + data.production_yield * 1.3 + data.gold_yield) / TILE_POINTS_DIVISOR

## `known` = Dictionary de tiles conhecidos (PlayerData.explored_tiles) ou
## null (sem filtro de nevoa: HUD/testes/diagnostico). A IA nunca enxerga
## alem do que explorou.
static func build_context(hex_grid: HexGrid, player: PlayerData, known: Variant = null) -> Dictionary:
	var own_cities: Array[City] = []
	var foreign_cities: Array[City] = []
	var owner_of := {}
	for entry in hex_grid.cities_by_coord.values():
		var city: City = entry
		if city.owner_player == player:
			own_cities.append(city)
		else:
			foreign_cities.append(city)
		if not owner_of.has(city.coord):
			owner_of[city.coord] = city.owner_player
		for owned in city.owned_tiles:
			if not owner_of.has(owned):
				owner_of[owned] = city.owner_player
	var monsters: Array[Vector2i] = []
	for monster in hex_grid.neutral_units():
		if is_instance_valid(monster) and CityDefense.is_mobile_threat(monster):
			monsters.append(monster.coord)
	var controlled := {}
	for resource_id in ResourceDatabase.DISPLAY_NAMES:
		controlled[resource_id] = ResourceDatabase.count_controlled(player, hex_grid, resource_id)
	return {
		"known": known,
		"own_cities": own_cities,
		"foreign_cities": foreign_cities,
		"owner_of": owner_of,
		"monsters": monsters,
		"controlled": controlled,
		"arcane": StrategicAI.strategy(player) == CityIdentity.AXIS_ARCANA,
		"player": player,
	}

static func _nearest_distance(coord: Vector2i, cities: Array[City]) -> int:
	var best := 999999
	for city in cities:
		var distance := HexMetrics.axial_distance(coord, city.coord)
		if distance < best:
			best = distance
	return best

static func _is_known(context: Dictionary, coord: Vector2i) -> bool:
	var known: Variant = context.known
	return known == null or (known as Dictionary).has(coord)

static func _resource_points(resource_id: String, context: Dictionary) -> float:
	var rarity: float = RESOURCE_RARITY.get(resource_id, 1.0)
	var owned_before: int = context.controlled.get(resource_id, 0)
	# Rendimento proprio do recurso (ResourceDatabase.YIELDS, mesma mistura de
	# tile_points) + valor ESTRATEGICO por raridade, ambos com retorno decrescente.
	var bonus: Dictionary = ResourceDatabase.yield_for(resource_id)
	var yield_points: float = (float(bonus.food) * 1.5 + float(bonus.production) * 1.3 + float(bonus.gold) + float(bonus.mana) * 1.5) / TILE_POINTS_DIVISOR
	var points: float = (yield_points + RESOURCE_BASE_POINTS * rarity) / (1.0 + RESOURCE_REPEAT_DECAY * float(owned_before))
	if resource_id == "mana_node" and context.arcane:
		points += ARCANE_NODE_EXTRA_POINTS
	return points

## Penalidade de coesao pela distancia ate a cidade PROPRIA mais proxima
## (0 sem cidades proprias -- a primeira cidade nao tem imperio pra coesao).
static func cohesion_penalty(nearest_own_distance: int) -> float:
	if nearest_own_distance >= 999999:
		return 0.0
	var penalty := 0.0
	if nearest_own_distance < IDEAL_SPACING_MIN:
		penalty += CROWDING_PENALTY_PER_TILE * float(IDEAL_SPACING_MIN - nearest_own_distance)
	elif nearest_own_distance > IDEAL_SPACING_MAX:
		penalty += STRETCH_PENALTY_PER_TILE * float(nearest_own_distance - IDEAL_SPACING_MAX)
		if nearest_own_distance > ENCLAVE_DISTANCE:
			penalty += ENCLAVE_EXTRA_PENALTY_PER_TILE * float(nearest_own_distance - ENCLAVE_DISTANCE)
	return penalty

## Pre-pontuacao BARATA (centro + anel 1 + coesao) so' pra escolher quais
## candidatos merecem a avaliacao completa.
static func _quick_score(hex_grid: HexGrid, coord: Vector2i, context: Dictionary) -> float:
	var center: HexTileData = hex_grid.get_tile(coord)
	var score := tile_points(center)
	for offset in _offsets_for(1):
		var tile_coord: Vector2i = coord + offset
		var data: HexTileData = hex_grid.get_tile(tile_coord)
		if data == null or not data.can_be_worked() or not _is_known(context, tile_coord):
			continue
		var territory_owner: Variant = context.owner_of.get(tile_coord)
		if territory_owner != null and territory_owner != context.player:
			continue
		score += tile_points(data)
		if data.resource != "":
			score += RESOURCE_BASE_POINTS * RESOURCE_RARITY.get(data.resource, 1.0)
	return score - cohesion_penalty(_nearest_distance(coord, context.own_cities))

## Pontuacao completa de `coord` como local de cidade de `context.player`.
## Devolve {"total", "parts": {...}} -- as partes existem pra metricas/testes/
## inspecao ("por que a IA escolheu isto?"), nunca pra decisao separada.
static func evaluate(hex_grid: HexGrid, coord: Vector2i, context: Dictionary) -> Dictionary:
	var parts := {
		"land": 0.0, "resources": 0.0, "terrain": 0.0, "space": 0.0,
		"cohesion": 0.0, "security": 0.0, "defense": 0.0, "strategic": 0.0,
	}
	var player: PlayerData = context.player
	var own_cities: Array[City] = context.own_cities
	var foreign_cities: Array[City] = context.foreign_cities
	var owner_of: Dictionary = context.owner_of

	var center: HexTileData = hex_grid.get_tile(coord)
	if center == null:
		return {"total": -INF, "parts": parts}
	parts.terrain += tile_points(center)
	parts.defense += center.defense_bonus * DEFENSE_POINTS_PER_BONUS
	if hex_grid.is_coastal_tile(coord):
		parts.terrain += COAST_POINTS

	var terrain_kinds := {center.terrain_type: true}
	var blocked_neighbors := 0
	var unowned_catchment := 0
	var catchment_total := 0
	for ring in range(1, CATCHMENT_RADIUS + 1):
		var ring_weight: float = RING_WEIGHTS[ring - 1]
		for offset in _offsets_for(ring):
			var tile_coord: Vector2i = coord + offset
			var data: HexTileData = hex_grid.get_tile(tile_coord)
			if data == null:
				continue
			if ring == 1 and not data.can_be_worked() and data.blocks_land_units():
				blocked_neighbors += 1
			if not _is_known(context, tile_coord) or not data.can_be_worked():
				continue
			catchment_total += 1
			var territory_owner: Variant = owner_of.get(tile_coord)
			if territory_owner != null and territory_owner != player:
				continue
			if _nearest_distance(tile_coord, foreign_cities) <= CATCHMENT_RADIUS:
				continue
			if territory_owner == null:
				unowned_catchment += 1
			var factor := ring_weight
			if territory_owner == player or _nearest_distance(tile_coord, own_cities) <= CATCHMENT_RADIUS:
				factor *= OVERLAP_OWN_FACTOR
			terrain_kinds[data.terrain_type] = true
			parts.land += tile_points(data) * factor
			if data.resource != "":
				parts.resources += _resource_points(data.resource, context) * factor
	# Costa/oceano so' contam como barreira se realmente bloqueiam unidade
	# terrestre (ver HexTileData.blocks_land_units): Costa e' trabalhavel mas
	# tambem barra o acesso por terra.
	for offset in _offsets_for(1):
		var neighbor: HexTileData = hex_grid.get_tile(coord + offset)
		if neighbor != null and neighbor.can_be_worked() and neighbor.blocks_land_units():
			blocked_neighbors += 1
	parts.defense += BARRIER_POINTS_PER_NEIGHBOR * float(mini(blocked_neighbors, BARRIER_MAX_NEIGHBORS))
	parts.terrain += DIVERSITY_POINTS_PER_TERRAIN * float(clampi(terrain_kinds.size() - 2, 0, DIVERSITY_MAX_EXTRA_TERRAINS))

	# Espaco pra expansao: fracao do anel 3 ainda livre.
	var ring_tiles: Array = _offsets_for(GROWTH_RING)
	var free_tiles := 0
	for offset in ring_tiles:
		var tile_coord: Vector2i = coord + offset
		var data: HexTileData = hex_grid.get_tile(tile_coord)
		if data == null or not data.can_be_worked() or data.blocks_land_units() or not _is_known(context, tile_coord):
			continue
		if owner_of.has(tile_coord):
			continue
		if _nearest_distance(tile_coord, own_cities) <= CATCHMENT_RADIUS or _nearest_distance(tile_coord, foreign_cities) <= CATCHMENT_RADIUS:
			continue
		free_tiles += 1
	parts.space = SPACE_POINTS * float(free_tiles) / float(maxi(ring_tiles.size(), 1))

	var nearest_own := _nearest_distance(coord, own_cities)
	parts.cohesion = -cohesion_penalty(nearest_own)

	# Seguranca.
	parts.security -= LAIR_DANGER_PENALTY * hex_grid.get_lair_danger_at(coord)
	var monsters_near := 0
	for monster_coord in context.monsters:
		if HexMetrics.axial_distance(coord, monster_coord) <= MONSTER_RADIUS:
			monsters_near += 1
	parts.security -= MONSTER_PENALTY_EACH * float(mini(monsters_near, MONSTER_PENALTY_MAX_COUNT))
	var rival_pressure := hex_grid.is_under_rival_pressure(coord, player)
	if rival_pressure:
		parts.security -= RIVAL_PRESSURE_PENALTY

	# Valor estrategico: bloquear a expansao de uma civ rival.
	if not rival_pressure and not foreign_cities.is_empty() and catchment_total > 0:
		var nearest_foreign := _nearest_distance(coord, foreign_cities)
		if nearest_foreign >= CONTEST_MIN_DISTANCE and nearest_foreign <= CONTEST_MAX_DISTANCE and float(unowned_catchment) / float(catchment_total) >= 0.75:
			parts.strategic += CONTEST_BONUS

	var total := 0.0
	for key in parts:
		total += parts[key]
	return {"total": total, "parts": parts}

# ---------------------------------------------------------------------------
# Busca
# ---------------------------------------------------------------------------

## Candidatos VALIDOS (regra estrutural + conhecidos + sem unidade alheia)
## ate SEARCH_RADIUS tiles das cidades do jogador (ou de `unit`, se ainda nao
## tem nenhuma), ordenados pela avaliacao completa (com penalidade de viagem
## se `unit` != null). Cada entrada: {"coord", "score", "parts"}.
static func rank_sites(hex_grid: HexGrid, player: PlayerData, context: Dictionary, unit: Unit = null, limit: int = FULL_EVAL_LIMIT) -> Array:
	var anchors: Array[Vector2i] = []
	for city in context.own_cities:
		anchors.append(city.coord)
	if anchors.is_empty() and unit != null:
		anchors.append(unit.coord)
	var seen := {}
	var quick: Array = []
	for anchor in anchors:
		for dq in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
			for dr in range(maxi(-SEARCH_RADIUS, -dq - SEARCH_RADIUS), mini(SEARCH_RADIUS, -dq + SEARCH_RADIUS) + 1):
				var coord: Vector2i = anchor + Vector2i(dq, dr)
				if seen.has(coord):
					continue
				seen[coord] = true
				if not _is_known(context, coord):
					continue
				var occupant: Unit = hex_grid.get_unit_at(coord)
				if occupant != null and occupant != unit:
					continue
				if rejection_reason(hex_grid, coord, player) != "":
					continue
				quick.append({"coord": coord, "quick": _quick_score(hex_grid, coord, context)})
	quick.sort_custom(func(a, b): return a.quick > b.quick)
	var ranked: Array = []
	for entry in quick.slice(0, limit):
		var result := evaluate(hex_grid, entry.coord, context)
		var score: float = result.total
		if unit != null:
			score -= TRAVEL_PENALTY_PER_TILE * float(HexMetrics.axial_distance(unit.coord, entry.coord))
		ranked.append({"coord": entry.coord, "score": score, "parts": result.parts})
	ranked.sort_custom(func(a, b): return a.score > b.score)
	return ranked

## Escolhe o local de fundacao do colonizador `unit` (IA): melhor entrada
## alcancavel por terra com pontuacao >= MIN_ACCEPTABLE_SCORE (ou qualquer
## uma, se `accept_any`), com histerese em relacao ao alvo anterior.
## {} = nenhum local aceitavel.
static func choose_site(hex_grid: HexGrid, player: PlayerData, unit: Unit, accept_any: bool = false) -> Dictionary:
	var context := build_context(hex_grid, player, player.explored_tiles)
	var ranked := rank_sites(hex_grid, player, context, unit)
	var floor_score := -INF if accept_any else MIN_ACCEPTABLE_SCORE
	var best := {}
	var attempts := 0
	for entry in ranked:
		if entry.score < floor_score or attempts >= PATH_CHECK_LIMIT:
			break
		attempts += 1
		if _reachable(hex_grid, unit, entry.coord):
			best = entry
			break
	if best.is_empty() or unit.settle_target == Unit.NO_SETTLE_TARGET or unit.settle_target == best.coord:
		return best
	# Histerese: mantem o alvo anterior se ainda for valido, alcancavel e
	# quase tao bom quanto o melhor de agora.
	var target: Vector2i = unit.settle_target
	if rejection_reason(hex_grid, target, player) == "" and _reachable(hex_grid, unit, target):
		var result := evaluate(hex_grid, target, context)
		var target_score: float = result.total - TRAVEL_PENALTY_PER_TILE * float(HexMetrics.axial_distance(unit.coord, target))
		if target_score >= floor_score and best.score - target_score < SWITCH_MARGIN:
			return {"coord": target, "score": target_score, "parts": result.parts}
	return best

static func _reachable(hex_grid: HexGrid, unit: Unit, coord: Vector2i) -> bool:
	if coord == unit.coord:
		return true
	return not hex_grid.compute_path(unit.coord, coord, unit.owner_player, unit.unit_data.flies, unit.embarked).is_empty()

## Existe ALGUM local aceitavel pra uma cidade nova de `player`? (usado antes
## de a IA gastar producao num colonizador). "Conhecido" = explorado + o que
## ela enxerga agora.
static func has_acceptable_site(hex_grid: HexGrid, player: PlayerData) -> bool:
	var known: Dictionary = player.explored_tiles.duplicate()
	known.merge(hex_grid.compute_visible_tiles(player))
	var context := build_context(hex_grid, player, known)
	var ranked := rank_sites(hex_grid, player, context, null, 8)
	return not ranked.is_empty() and ranked[0].score >= MIN_ACCEPTABLE_SCORE
