class_name BalanceWorldSurvey
extends RefCounted

## Fase 33C — análise SOMENTE LEITURA do mundo inicial das partidas do seed set (sem jogar turnos).
## Mede, por assento: distância e tipo do covil mais próximo da capital, quantos covis existem em
## raios de 6/10/15 tiles e a distância do rival mais próximo; e, por partida, os turnos em que o
## gatilho real do Dragão (WorldEventTrigger.should_spawn_dragon) dispara até o cap. Usa o mesmo setup
## do laboratório (BalanceMatchRunner.setup_match) e nunca altera gameplay.

const RADII := [6, 10, 15]

static func survey_match(host: Node, config: Dictionary) -> Dictionary:
	var violations_before := WorldSetup.start_distance_violations
	var grid := BalanceMatchRunner.setup_match(host, config)
	var seats := []
	var capitals: Array = []
	for player in GameManager.players:
		capitals.append(player.cities[0].coord if not player.cities.is_empty() else Vector2i(999999, 999999))
	var main_lairs := 0
	for lair in grid.lair_coords:
		if grid._zone_for(lair) == HexGrid._Zone.MAIN:
			main_lairs += 1
	for seat in capitals.size():
		var capital: Vector2i = capitals[seat]
		var nearest := 999999
		var nearest_kind := ""
		var counts := {}
		for radius in RADII:
			counts[str(radius)] = 0
		for lair in grid.lair_coords:
			var distance := HexMetrics.axial_distance(capital, lair)
			if distance < nearest:
				nearest = distance
				nearest_kind = String(grid.lair_kind_by_coord.get(lair, ""))
			for radius in RADII:
				if distance <= radius:
					counts[str(radius)] += 1
		var rival_distance := 999999
		for other in capitals.size():
			if other != seat:
				rival_distance = mini(rival_distance, HexMetrics.axial_distance(capital, capitals[other]))
		seats.append({"seat": seat, "race": GameManager.players[seat].civ.race, "capital": [capital.x, capital.y], "nearest_lair": nearest, "nearest_lair_kind": nearest_kind, "lairs_within": counts, "nearest_rival": rival_distance, "capital_landmass": grid.land_component_size(capital)})
	# Fase 33D1: fairness de spawn — menor distância entre QUALQUER par de capitais e quantas vezes a
	# busca de tile inicial precisou violar a distância mínima (gate: 0).
	var min_pair := 999999
	for a in capitals.size():
		for b in range(a + 1, capitals.size()):
			min_pair = mini(min_pair, HexMetrics.axial_distance(capitals[a], capitals[b]))
	var dragon_triggers: Array = []
	for turn in range(WorldEventTrigger.DRAGON_TRIGGER_MIN_TURN, int(config.get("turn_cap", BalanceSeedSet.TURN_CAP)) + 1):
		if WorldEventTrigger.should_spawn_dragon(grid.map_seed, turn):
			dragon_triggers.append(turn)
	var regional := survey_regional(grid, capitals)
	var ecology := survey_ecology(grid, capitals) # V3 / Combat Ecology — Etapa 1 (antes dos Guardiões, que mudam o mapa)
	# Guardiões: a escolha real acontece na entrada da Ascensão (território maior). Aqui roda a MESMA função
	# sobre o mundo inicial — uma aproximação de cobertura/fairness, reportada como tal.
	RegionalThreatSystem.spawn_guardians(grid, TurnManager.turn_number)
	var guardians := survey_guardians(grid, capitals)
	var result := {
		"match_id": config.match_id,
		"seed": config.seed,
		"lairs_total": grid.lair_coords.size(),
		"lairs_main_zone": main_lairs,
		"lair_kinds": _kind_counts(grid),
		"seats": seats,
		"capital_count": capitals.size(),
		"min_capital_pair_distance": min_pair,
		"start_distance_violations": WorldSetup.start_distance_violations - violations_before,
		"dragon_trigger_turns": dragon_triggers,
		"regional": regional,
		"guardians": guardians,
		"ecology": ecology,
		"world": survey_world_profile(grid),
	}
	await BalanceMatchRunner.teardown_match(host, grid)
	return result

## Fase 33D2 — ameaça regional por assento (gate: existe, 7–10, mesmo componente, fora do corredor).
static func survey_regional(grid: HexGrid, capitals: Array) -> Array:
	var result: Array = []
	grid._ensure_land_components()
	for seat in capitals.size():
		var capital: Vector2i = capitals[seat]
		var record := RegionalThreatSystem.record_for_index(seat)
		var entry := {"seat": seat, "exists": false}
		if not record.is_empty() and String(record.state) != RegionalThreatSystem.STATE_NONE:
			var coord: Vector2i = record.coord
			var corridor_pairs := 0
			var in_corridor := 0
			for other in capitals.size():
				if other == seat or HexMetrics.axial_distance(capital, capitals[other]) >= RegionalThreatPlanner.CORRIDOR_RADIUS:
					continue
				corridor_pairs += 1
				if RegionalThreatPlanner.corridor_relation(capital, capitals[other], coord) == 2:
					in_corridor += 1
			var nearest_other := 999999
			for other in capitals.size():
				if other != seat:
					nearest_other = mini(nearest_other, HexMetrics.axial_distance(coord, capitals[other]))
			entry = {
				"seat": seat, "exists": true, "coord": [coord.x, coord.y], "kind": String(record.kind), "source": String(record.source),
				"distance": HexMetrics.axial_distance(capital, coord),
				"same_component": grid._land_components.get(coord, -1) == grid._land_components.get(capital, -2),
				"anchor_is_capital": record.anchor == capital,
				"visible_at_creation": bool(record.visible_at_creation),
				"wake_turn": int(record.wake_turn), "wake_delay": int(record.wake_turn) - int(record.created_turn),
				"corridor_pairs": corridor_pairs, "in_corridor": in_corridor,
				"nearest_other_capital": nearest_other,
				"relocated": int(record.relocated), "removed": int(record.removed), "preserved_close": int(record.preserved_close),
				"wild_lairs_under_7": _wild_lairs_within(grid, capital, RegionalThreatPlanner.RING_MIN - 1),
			}
		result.append(entry)
	return result

static func _wild_lairs_within(grid: HexGrid, capital: Vector2i, radius: int) -> int:
	var count := 0
	for lair_coord in grid.lair_coords:
		if grid.lair_role(lair_coord) == HexGrid.LAIR_ROLE_WILD and HexMetrics.axial_distance(capital, lair_coord) <= radius:
			count += 1
	return count

## Fase 33D2 — Guardiões Troll (sem gate 192/192: dependem do mapa).
static func survey_guardians(grid: HexGrid, capitals: Array) -> Dictionary:
	var sites: Array = []
	for site in WorldEventManager.guardian_sites:
		var nearest := 999999
		for capital in capitals:
			nearest = mini(nearest, HexMetrics.axial_distance(capital, site.resource_coord))
		sites.append({"resource": String(site.resource), "for_players": site.for_players.duplicate(), "nearest_capital": nearest, "resource_coord": [site.resource_coord.x, site.resource_coord.y]})
	return {"sites": sites, "stats": WorldEventManager.guardian_stats.duplicate(true)}

static func _kind_counts(grid: HexGrid) -> Dictionary:
	var result := {}
	for lair in grid.lair_coords:
		var kind := String(grid.lair_kind_by_coord.get(lair, ""))
		result[kind] = int(result.get(kind, 0)) + 1
	return result

# ---------------------------------------------------------------------------
# V3 / Combat Ecology — Etapa 1 (somente leitura do mundo inicial)
# ---------------------------------------------------------------------------

## Por mundo: contagens por espécie/tier, distância do hostil mais próximo a cada capital, distância mínima
## de ADVANCED às capitais, violações da zona de segurança (gate: 0), spawns em tile inválido (gate: 0) e
## distribuição espacial (metades/quadrantes pela MEDIANA da terra elegível, ou seja, ponderada por área).
static func survey_ecology(grid: HexGrid, capitals: Array) -> Dictionary:
	var snapshot := MonsterEcologySystem.population_snapshot(grid)
	var anchors: Array[Vector2i] = []
	for capital in capitals:
		anchors.append(capital)
	var units: Array[Unit] = []
	for unit in grid.neutral_units():
		if unit.ecology_site_id >= 0:
			units.append(unit)
	var violations := {}
	var invalid := {"water": 0, "city": 0, "territory_or_building": 0, "resource": 0, "lair_tile": 0, "event_marker": 0, "outside_main": 0}
	var min_advanced := 999999
	for tier in MonsterEcologyData.TIERS:
		violations[tier] = 0
	for unit in units:
		var tier := MonsterEcologyData.tier_of(unit.unit_data.visual_kind)
		var nearest := 999999
		for capital in anchors:
			nearest = mini(nearest, HexMetrics.axial_distance(capital, unit.coord))
		if nearest < int(MonsterEcologyData.CAPITAL_MIN_DISTANCE[tier]):
			violations[tier] = int(violations[tier]) + 1
		if tier == MonsterEcologyData.TIER_ADVANCED:
			min_advanced = mini(min_advanced, nearest)
		var tile: HexTileData = grid.get_tile(unit.coord)
		if tile == null or tile.blocks_land_units():
			invalid.water += 1
		if grid.get_city_at(unit.coord) != null:
			invalid.city += 1
		if grid.city_owning_tile(unit.coord) != null or grid.buildings_by_coord.has(unit.coord):
			invalid.territory_or_building += 1
		if tile != null and tile.resource != "":
			invalid.resource += 1
		if grid.lairs_by_coord.has(unit.coord):
			invalid.lair_tile += 1
		if MonsterEcologyPlanner._near_world_event_site(unit.coord):
			invalid.event_marker += 1
		if grid._zone_for(unit.coord) != HexGrid._Zone.MAIN:
			invalid.outside_main += 1
	var seats: Array = []
	for seat in anchors.size():
		var capital: Vector2i = anchors[seat]
		var entry := {"seat": seat, "nearest_any_hostile": 999999, "nearest_ecology": 999999, "nearest_by_tier": {}}
		for tier in MonsterEcologyData.TIERS:
			entry.nearest_by_tier[tier] = 999999
		for unit in grid.neutral_units():
			var distance := HexMetrics.axial_distance(capital, unit.coord)
			entry.nearest_any_hostile = mini(int(entry.nearest_any_hostile), distance)
			if unit.ecology_site_id >= 0:
				entry.nearest_ecology = mini(int(entry.nearest_ecology), distance)
				var tier := MonsterEcologyData.tier_of(unit.unit_data.visual_kind)
				entry.nearest_by_tier[tier] = mini(int(entry.nearest_by_tier[tier]), distance)
		seats.append(entry)
	return {
		"eligible": MonsterEcologySystem.eligible_count,
		"targets": MonsterEcologySystem.targets.duplicate(),
		"initial": MonsterEcologySystem.initial_stats.duplicate(true),
		"units_total": units.size(),
		"sites_total": MonsterEcologySystem.sites.size(),
		"sites_by_tier": snapshot.sites_by_tier, "sites_by_species": snapshot.sites_by_species,
		"units_by_tier": snapshot.units_by_tier, "units_by_species": snapshot.units_by_species,
		"all_neutral_by_tier": snapshot.all_neutral_by_tier,
		"capital_violations": violations, "invalid": invalid,
		"min_advanced_capital_distance": min_advanced,
		"seats": seats,
		"distribution": _ecology_distribution(grid, units),
		"habitat": survey_habitat(grid, anchors),
	}

## V3 / Etapa 4 — habitat por espécie neste mundo: sítios, score médio, fallback do setup, terreno da âncora, fração
## dos sítios na região do sinal preferido da espécie (sinal >= PREFERRED_MIN) contra a mesma fração na terra elegível
## (lift > 1 = agrupamento ecológico), distância ao sítio mais próximo da mesma espécie, maior fatia num quadrante e
## distância à capital mais próxima.
const PREFERRED_MIN := 0.5

static func preferred_signal(kind: String) -> String:
	var best := ""
	var best_weight := 0.0
	for key in MonsterHabitatProfile.profile_for(kind):
		var weight := float(MonsterHabitatProfile.profile_for(kind)[key])
		if key != "remote" and weight > best_weight:
			best_weight = weight
			best = key
	return best

static func survey_habitat(grid: HexGrid, anchors: Array[Vector2i]) -> Dictionary:
	var cache := MonsterEcologySystem.habitat_cache(grid)
	var land := MonsterEcologySystem.eligible(grid)
	var land_share := {}
	for kind in MonsterEcologyData.SPECIES_ORDER:
		var signal_key := preferred_signal(kind)
		if land_share.has(signal_key):
			continue
		var hits := 0
		for coord in land:
			if float(MonsterEcologyPlanner.habitat_features(grid, coord, cache).get(signal_key, 0.0)) >= PREFERRED_MIN:
				hits += 1
		land_share[signal_key] = float(hits) / float(maxi(land.size(), 1))
	var mid := Vector2.ZERO
	for coord in land:
		mid += RegionalThreatPlanner.cartesian(coord)
	mid /= float(maxi(land.size(), 1))
	var by_species := {}
	var initial_habitat: Dictionary = MonsterEcologySystem.initial_stats.get("habitat", {})
	for kind in MonsterEcologyData.SPECIES_ORDER:
		var anchors_of: Array[Vector2i] = []
		for site in MonsterEcologySystem.sites:
			if String(site.species) == kind:
				anchors_of.append(site.anchor)
		var signal_key := preferred_signal(kind)
		var entry := {"sites": anchors_of.size(), "score_sum": 0.0, "preferred_hits": 0, "terrain": {}, "nearest_same": [], "capital_distance": [], "quadrants": {"wn": 0, "en": 0, "ws": 0, "es": 0},
			"fallback": int(initial_habitat.get(kind, {}).get("fallback", 0)), "signal": signal_key, "land_share": snappedf(float(land_share.get(signal_key, 0.0)), 0.001)}
		for anchor in anchors_of:
			var feats := MonsterEcologyPlanner.habitat_features(grid, anchor, cache)
			entry.score_sum += MonsterHabitatProfile.score(kind, feats, MonsterHabitatProfile.remote_value(anchor, anchors)) # score real, mesmo no A/B
			if float(feats.get(signal_key, 0.0)) >= PREFERRED_MIN:
				entry.preferred_hits += 1
			var terrain := String(grid.tiles[anchor].display_name)
			entry.terrain[terrain] = int(entry.terrain.get(terrain, 0)) + 1
			var nearest := 999999
			for other in anchors_of:
				if other != anchor:
					nearest = mini(nearest, HexMetrics.axial_distance(anchor, other))
			if nearest < 999999:
				entry.nearest_same.append(nearest)
			var capital := 999999
			for a in anchors:
				capital = mini(capital, HexMetrics.axial_distance(a, anchor))
			entry.capital_distance.append(capital)
			var point := RegionalThreatPlanner.cartesian(anchor)
			entry.quadrants["%s%s" % ["w" if point.x < mid.x else "e", "n" if point.y < mid.y else "s"]] += 1
		by_species[kind] = entry
	return by_species

static func _ecology_distribution(grid: HexGrid, units: Array[Unit]) -> Dictionary:
	var land := MonsterEcologySystem.eligible(grid)
	var xs: Array[float] = []
	var ys: Array[float] = []
	for coord in land:
		var point := RegionalThreatPlanner.cartesian(coord)
		xs.append(point.x)
		ys.append(point.y)
	xs.sort()
	ys.sort()
	var mid_x: float = xs[xs.size() / 2] if not xs.is_empty() else 0.0
	var mid_y: float = ys[ys.size() / 2] if not ys.is_empty() else 0.0
	var quadrants := {"west_north": 0, "east_north": 0, "west_south": 0, "east_south": 0}
	var west := 0
	var north := 0
	for unit in units:
		var point := RegionalThreatPlanner.cartesian(unit.coord)
		var is_west := point.x < mid_x
		var is_north := point.y < mid_y
		west += 1 if is_west else 0
		north += 1 if is_north else 0
		quadrants["%s_%s" % ["west" if is_west else "east", "north" if is_north else "south"]] += 1
	var total := maxi(units.size(), 1)
	return {
		"west_share": snappedf(float(west) / total, 0.001), "north_share": snappedf(float(north) / total, 0.001),
		"max_half_share": snappedf(maxf(maxf(float(west), float(total - west)), maxf(float(north), float(total - north))) / total, 0.001),
		"quadrants": quadrants,
	}

## Agregado dos N mundos (gates da Etapa 1): cobertura por espécie, contagens, violações e distribuição.
static func summarize_ecology(surveys: Array) -> Dictionary:
	var coverage := {}
	var units_by_species := {}
	for kind in MonsterEcologyData.SPECIES_ORDER:
		coverage[kind] = 0
		units_by_species[kind] = []
	var totals := {"units": [], "sites": [], "eligible": [], "placement_ms": []}
	var by_tier := {}
	var sites_by_tier := {}
	for tier in MonsterEcologyData.TIERS:
		by_tier[tier] = []
		sites_by_tier[tier] = []
	var violations := 0
	var invalid := 0
	var max_half := 0.0
	var min_advanced := 999999
	var nearest_hostile: Array = []
	var nearest_ecology: Array = []
	var capitals_ok := 0
	var worlds := 0
	var regional_ok := 0
	var regional_total := 0
	var shortfalls := 0
	var adopted: Array = []
	var removed: Array = []
	var resource_units := 0
	for survey in surveys:
		var eco: Dictionary = survey.get("ecology", {})
		if eco.is_empty():
			continue
		worlds += 1
		if int(survey.get("capital_count", 0)) == 4 and int(survey.get("start_distance_violations", 1)) == 0:
			capitals_ok += 1
		for entry in survey.get("regional", []):
			regional_total += 1
			if bool(entry.get("exists", false)) and int(entry.get("distance", 0)) >= RegionalThreatPlanner.RING_MIN and int(entry.get("distance", 0)) <= RegionalThreatPlanner.RING_MAX:
				regional_ok += 1
		for kind in MonsterEcologyData.SPECIES_ORDER:
			var count := int(eco.units_by_species.get(kind, 0))
			units_by_species[kind].append(count)
			if count > 0:
				coverage[kind] += 1
		totals.units.append(int(eco.units_total))
		totals.sites.append(int(eco.sites_total))
		totals.eligible.append(int(eco.eligible))
		totals.placement_ms.append(float(eco.initial.get("placement_ms", 0.0)))
		adopted.append(int(eco.initial.get("adopted", 0)))
		removed.append(int(eco.initial.get("legacy_removed", 0)))
		shortfalls += (eco.initial.get("shortfall", {}) as Dictionary).size()
		for tier in MonsterEcologyData.TIERS:
			by_tier[tier].append(int(eco.units_by_tier.get(tier, 0)))
			sites_by_tier[tier].append(int(eco.sites_by_tier.get(tier, 0)))
			violations += int(eco.capital_violations.get(tier, 0))
		for key in eco.invalid:
			if key == "resource":
				resource_units += int(eco.invalid[key]) # informativo: chefe de covil legado adotado sobre recurso
			else:
				invalid += int(eco.invalid[key])
		max_half = maxf(max_half, float(eco.distribution.max_half_share))
		min_advanced = mini(min_advanced, int(eco.min_advanced_capital_distance))
		for seat in eco.seats:
			nearest_hostile.append(int(seat.nearest_any_hostile))
			nearest_ecology.append(int(seat.nearest_ecology))
	var tier_stats := {}
	var site_stats := {}
	for tier in MonsterEcologyData.TIERS:
		tier_stats[tier] = _stats(by_tier[tier])
		site_stats[tier] = _stats(sites_by_tier[tier])
	var species_stats := {}
	for kind in MonsterEcologyData.SPECIES_ORDER:
		species_stats[kind] = _stats(units_by_species[kind])
	return {
		"worlds": worlds, "capitals_ok": capitals_ok, "regional_ok": regional_ok, "regional_total": regional_total,
		"species_coverage": coverage, "units_by_species": species_stats,
		"units_by_tier": tier_stats, "sites_by_tier": site_stats,
		"units_total": _stats(totals.units), "sites_total": _stats(totals.sites), "eligible": _stats(totals.eligible),
		"placement_ms": _stats(totals.placement_ms), "shortfall_tiers": shortfalls,
		"legacy_adopted": _stats(adopted), "legacy_removed": _stats(removed),
		"capital_violations": violations, "invalid_spawns": invalid, "resource_tile_units": resource_units,
		"max_half_share": max_half, "min_advanced_capital_distance": min_advanced,
		"nearest_hostile_to_capital": _stats(nearest_hostile), "nearest_ecology_to_capital": _stats(nearest_ecology),
		"habitat": summarize_habitat(surveys),
	}

## Etapa 4 — agregado de habitat dos N mundos, por espécie (ver survey_habitat).
static func summarize_habitat(surveys: Array) -> Dictionary:
	var result := {}
	for kind in MonsterEcologyData.SPECIES_ORDER:
		var sites := 0
		var score_sum := 0.0
		var hits := 0
		var land_share_sum := 0.0
		var fallback := 0
		var worlds_with := 0
		var worlds := 0
		var terrain := {}
		var nearest: Array = []
		var capital: Array = []
		var max_quadrant: Array = []
		for survey in surveys:
			var entry: Dictionary = survey.get("ecology", {}).get("habitat", {}).get(kind, {})
			if entry.is_empty():
				continue
			worlds += 1
			sites += int(entry.sites)
			score_sum += float(entry.score_sum)
			hits += int(entry.preferred_hits)
			land_share_sum += float(entry.land_share)
			fallback += int(entry.fallback)
			worlds_with += 1 if int(entry.sites) > 0 else 0
			for name in entry.terrain:
				terrain[name] = int(terrain.get(name, 0)) + int(entry.terrain[name])
			nearest.append_array(entry.nearest_same)
			capital.append_array(entry.capital_distance)
			if int(entry.sites) >= 3:
				var top := 0
				for key in entry.quadrants:
					top = maxi(top, int(entry.quadrants[key]))
				max_quadrant.append(snappedf(float(top) / float(entry.sites), 0.01))
		var names := terrain.keys()
		names.sort_custom(func(a, b): return int(terrain[a]) > int(terrain[b]))
		var top_terrain := {}
		for name in names.slice(0, 3):
			top_terrain[name] = snappedf(float(terrain[name]) / float(maxi(sites, 1)), 0.01)
		var preferred_share := float(hits) / float(maxi(sites, 1))
		var land_share := land_share_sum / float(maxi(worlds, 1))
		result[kind] = {
			"sites": sites, "worlds_with_species": worlds_with, "worlds": worlds,
			"score_mean": snappedf(score_sum / float(maxi(sites, 1)), 0.001),
			"signal": preferred_signal(kind), "preferred_share": snappedf(preferred_share, 0.001), "land_share": snappedf(land_share, 0.001),
			"lift": snappedf(preferred_share / land_share, 0.01) if land_share > 0.0 else 0.0,
			"fallback": fallback, "fallback_share": snappedf(float(fallback) / float(maxi(sites, 1)), 0.001),
			"top_terrain": top_terrain, "nearest_same": _stats(nearest), "capital_distance": _stats(capital),
			"max_quadrant_share": _stats(max_quadrant),
		}
	return result

static func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += float(value)
	return {"n": sorted.size(), "min": sorted[0], "mean": snappedf(total / sorted.size(), 0.01), "median": sorted[sorted.size() / 2], "max": sorted.back()}


## V3 / Etapa 3 — perfil de mundo: tiles de bioma dos continentes especiais e terra fora da zona principal (gate do
## padrão 1.0: 0 e 0).
const SPECIAL_TERRAINS := [
	HexTileData.TerrainType.LAVA, HexTileData.TerrainType.LAVA_SEA, HexTileData.TerrainType.CRYSTAL,
	HexTileData.TerrainType.VOLCANIC_ROCK, HexTileData.TerrainType.VOLCANIC_HILLS, HexTileData.TerrainType.VOLCANIC_PEAKS,
	HexTileData.TerrainType.VOLCANIC_ASH, HexTileData.TerrainType.CRYSTAL_PEAKS, HexTileData.TerrainType.MYSTIC_SOIL,
	HexTileData.TerrainType.MYSTIC_SPRING,
]

static func survey_world_profile(grid: HexGrid) -> Dictionary:
	var special := 0
	var land_outside_main := 0
	var zones := {"volcanic": 0, "crystal": 0}
	for coord in grid.tiles:
		var tile: HexTileData = grid.tiles[coord]
		if tile.terrain_type in SPECIAL_TERRAINS:
			special += 1
		var zone := grid._zone_for(coord)
		if zone == HexGrid._Zone.VOLCANIC:
			zones.volcanic += 1
		elif zone == HexGrid._Zone.CRYSTAL:
			zones.crystal += 1
		if not tile.is_water() and zone != HexGrid._Zone.MAIN:
			land_outside_main += 1
	return {"profile": String(grid.world_profile.get("id", "")), "width": grid.map_width, "height": grid.map_height, "tiles": grid.tiles.size(), "special_terrain_tiles": special, "volcanic_zone_tiles": zones.volcanic, "crystal_zone_tiles": zones.crystal, "land_outside_main": land_outside_main}
