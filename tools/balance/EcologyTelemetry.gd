class_name EcologyTelemetry
extends RefCounted

## V3 / Combat Ecology — Etapa 1: seção "combat_ecology" do registro de partida do laboratório
## (BalanceTelemetry). Observador puro: escuta EventBus.combat_ecology_event / unit_removed /
## combat_engagement / world_phase_changed e lê MonsterEcologySystem.population_snapshot; nunca escreve
## estado de jogo. Etapa 1 é fundação: nada aqui é conclusão de balanceamento.

const POPULATION_CHECKPOINTS := [1, 30, 50, 75, 100, 150]
const COUNTER_KEYS := ["moves", "chases", "attacks", "city_attacks", "garrison_attacks", "pillages", "civ_units_killed", "monster_deaths", "refills", "sites_depleted"]

var initial: Dictionary = {}
var by_species: Dictionary = {}
var by_tier: Dictionary = {}
var by_phase: Dictionary = {}
var targets: Dictionary = {"attacks_by_seat": {}, "city_attacks_by_seat": {}, "pillages_by_seat": {}, "civ_units_killed_by_seat": {}}
var combats := {"monster_vs_civ": 0, "monster_initiated": 0, "civ_initiated": 0, "civ_initiated_on_ecology": 0}
var population_at: Dictionary = {}
var population_at_phase: Dictionary = {}
var first_contact_turn: Dictionary = {}
var first_monster_death_turn: Dictionary = {}
var first_civ_unit_killed_turn: Dictionary = {}
var cities_left_at_1hp := 0
## V3 / Etapa 2 — habilidades: por espécie (usos, alvos atingidos, dano, estados, abates) e por habilidade (soma de
## todo campo numérico do evento: gold_stolen, raised, healed, mana_drained, barrier, zones, isolated_hunted...).
var abilities_by_species: Dictionary = {}
var abilities: Dictionary = {}
var status_ticks: Dictionary = {} # status -> {ticks, damage, kills}
var infection := {"damage": 0.0, "ticks": 0, "kills": 0, "peak_tiles": 0}
var max_site_population: Dictionary = {} # espécie -> maior população viva de um sítio
var ai_evades := 0
var _connections: Array = []

func start(grid: HexGrid) -> void:
	for kind in MonsterEcologyData.SPECIES_ORDER:
		by_species[kind] = _counters()
	for tier in MonsterEcologyData.TIERS:
		by_tier[tier] = _counters()
	for phase_key in ["FOUNDATION", "ASCENSION", "CONVERGENCE"]:
		by_phase[phase_key] = {}
		for tier in MonsterEcologyData.TIERS:
			by_phase[phase_key][tier] = _counters()
	initial = MonsterEcologySystem.population_snapshot(grid)
	initial.enabled = MonsterEcologySystem.enabled
	initial.eligible = MonsterEcologySystem.eligible_count
	initial.targets = MonsterEcologySystem.targets.duplicate()
	var stats: Dictionary = MonsterEcologySystem.initial_stats
	initial.adopted = int(stats.get("adopted", 0))
	initial.legacy_removed = int(stats.get("legacy_removed", 0))
	initial.placement_ms = float(stats.get("placement_ms", 0.0))
	_connect(EventBus.combat_ecology_event, _on_ecology_event)
	_connect(EventBus.unit_removed, _on_unit_removed)
	_connect(EventBus.combat_engagement, _on_combat_engagement)
	_connect(EventBus.world_phase_changed, _on_world_phase_changed)

func on_turn_end(grid: HexGrid, turn: int) -> void:
	if turn in POPULATION_CHECKPOINTS:
		population_at[str(turn)] = _population(grid)
	infection.peak_tiles = maxi(int(infection.peak_tiles), MonsterHazardSystem.infected_count())
	if grid != null:
		var alive := MonsterEcologySystem._alive_by_site(grid)
		for site in MonsterEcologySystem.sites:
			var kind := String(site.species)
			max_site_population[kind] = maxi(int(max_site_population.get(kind, 0)), int(alive.get(int(site.id), 0)))

func finish(grid: HexGrid) -> Dictionary:
	for connection in _connections:
		if connection.signal_ref.is_connected(connection.callable):
			connection.signal_ref.disconnect(connection.callable)
	_connections.clear()
	return {
		"initial": initial, "by_species": by_species, "by_tier": by_tier, "by_phase": by_phase, "targets": targets,
		"combats": combats, "population_at": population_at, "population_at_phase": population_at_phase,
		"population_at_end": _population(grid),
		"first_contact_turn": first_contact_turn, "first_monster_death_turn": first_monster_death_turn,
		"first_civ_unit_killed_turn": first_civ_unit_killed_turn, "cities_left_at_1hp": cities_left_at_1hp,
		"abilities_by_species": abilities_by_species, "abilities": abilities, "status_ticks": status_ticks,
		"infection": infection, "max_site_population": max_site_population, "ai_evades": ai_evades,
	}

func connected_signal_count() -> int:
	return _connections.size()

func _connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
		_connections.append({"signal_ref": sig, "callable": callable})

func _counters() -> Dictionary:
	var result := {}
	for key in COUNTER_KEYS:
		result[key] = 0
	return result

func _population(grid: HexGrid) -> Dictionary:
	var snapshot := MonsterEcologySystem.population_snapshot(grid)
	return {"units_by_tier": snapshot.units_by_tier, "sites_by_tier": snapshot.sites_by_tier, "all_neutral_by_tier": snapshot.all_neutral_by_tier, "units_by_species": snapshot.units_by_species}

func _bump(kind: String, tier: String, phase_key: String, key: String) -> void:
	if by_species.has(kind):
		by_species[kind][key] = int(by_species[kind][key]) + 1
	if by_tier.has(tier):
		by_tier[tier][key] = int(by_tier[tier][key]) + 1
	if by_phase.has(phase_key) and by_phase[phase_key].has(tier):
		by_phase[phase_key][tier][key] = int(by_phase[phase_key][tier][key]) + 1

func _bump_seat(bucket: String, seat: int) -> void:
	if seat < 0:
		return
	targets[bucket][str(seat)] = int(targets[bucket].get(str(seat), 0)) + 1

func _on_ecology_event(action: String, info: Dictionary) -> void:
	var kind := String(info.get("species", ""))
	var tier := String(info.get("tier", ""))
	var phase_key := String(info.get("phase", ""))
	var seat := int(info.get("target", -1))
	var ecology := bool(info.get("ecology", true))
	var turn := TurnManager.turn_number
	match action:
		"move":
			_bump(kind, tier, phase_key, "moves")
			if String(info.get("reason", "")) == "chase":
				_bump(kind, tier, phase_key, "chases")
		"attack":
			_bump(kind, tier, phase_key, "attacks")
			_bump_seat("attacks_by_seat", seat)
		"city_attack":
			_bump(kind, tier, phase_key, "city_attacks")
			if bool(info.get("garrison", false)):
				_bump(kind, tier, phase_key, "garrison_attacks")
			_bump_seat("city_attacks_by_seat", seat)
			if float(info.get("city_hp", 99.0)) <= 1.0:
				cities_left_at_1hp += 1
		"pillage":
			_bump(kind, tier, phase_key, "pillages")
			_bump_seat("pillages_by_seat", seat)
		"civ_unit_killed":
			if tier != "" and ecology:
				_bump(kind, tier, phase_key, "civ_units_killed")
				_bump_seat("civ_units_killed_by_seat", seat)
				if not first_civ_unit_killed_turn.has(tier):
					first_civ_unit_killed_turn[tier] = turn
		"refill":
			_bump(kind, tier, phase_key, "refills")
		"site_depleted":
			_bump(kind, tier, phase_key, "sites_depleted")
		"ability":
			_on_ability(kind, info)
		"status_tick":
			var status := String(info.get("status", ""))
			if not status_ticks.has(status):
				status_ticks[status] = {"ticks": 0, "damage": 0.0, "kills": 0, "source": kind}
			status_ticks[status].ticks += 1
			status_ticks[status].damage = float(status_ticks[status].damage) + float(info.get("damage", 0.0))
			if bool(info.get("killed", false)):
				status_ticks[status].kills += 1
		"infection_damage":
			infection.ticks = int(infection.ticks) + 1
			infection.damage = float(infection.damage) + float(info.get("damage", 0.0))
			if bool(info.get("killed", false)):
				infection.kills = int(infection.kills) + 1
		"infection_spread":
			infection.peak_tiles = maxi(int(infection.peak_tiles), MonsterHazardSystem.infected_count())
		"ai_evade":
			ai_evades += 1
	if action in ["attack", "city_attack"] and tier != "" and not first_contact_turn.has(tier):
		first_contact_turn[tier] = turn

func _on_ability(kind: String, info: Dictionary) -> void:
	var id := String(info.get("ability", ""))
	if not abilities_by_species.has(kind):
		abilities_by_species[kind] = {"abilities_used": 0, "ability_hits": 0, "damage": 0.0, "statuses_applied": 0, "kills": 0}
	var species: Dictionary = abilities_by_species[kind]
	species.abilities_used = int(species.abilities_used) + 1
	species.ability_hits = int(species.ability_hits) + int(info.get("hits", 0))
	species.damage = float(species.damage) + float(info.get("damage", 0.0))
	species.statuses_applied = int(species.statuses_applied) + int(info.get("statuses", 0))
	species.kills = int(species.kills) + int(info.get("kills", 0))
	if not abilities.has(id):
		abilities[id] = {"uses": 0}
	var entry: Dictionary = abilities[id]
	entry.uses = int(entry.uses) + 1
	for key in info:
		if key in ["species", "tier", "phase", "ecology", "ability", "target"]:
			continue
		var value: Variant = info[key]
		if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			entry[key] = float(entry.get(key, 0.0)) + float(value)
		elif typeof(value) == TYPE_STRING:
			var bucket := "%s_%s" % [key, String(value)]
			entry[bucket] = int(entry.get(bucket, 0)) + 1

func _on_unit_removed(former_owner: PlayerData, unit: Unit) -> void:
	if former_owner != null or unit == null or unit.hp > 0.0 or unit.ecology_site_id < 0:
		return
	var kind := unit.unit_data.visual_kind
	var tier := MonsterEcologyData.tier_of(kind)
	_bump(kind, tier, WorldPhaseRules.id_name(WorldEventManager.world_phase), "monster_deaths")
	if tier != "" and not first_monster_death_turn.has(tier):
		first_monster_death_turn[tier] = TurnManager.turn_number

func _on_combat_engagement(attacker_owner: PlayerData, defender_owner: PlayerData, target_kind: String, target_coord: Vector2i) -> void:
	if (attacker_owner == null) == (defender_owner == null):
		return
	combats.monster_vs_civ += 1
	if attacker_owner == null:
		combats.monster_initiated += 1
		return
	combats.civ_initiated += 1
	if target_kind != "unit" or GameManager.hex_grid == null:
		return
	var defender: Unit = GameManager.hex_grid.get_unit_at(target_coord)
	if defender == null or defender.ecology_site_id < 0:
		return
	combats.civ_initiated_on_ecology += 1
	var tier := MonsterEcologyData.tier_of(defender.unit_data.visual_kind)
	if tier != "" and not first_contact_turn.has(tier):
		first_contact_turn[tier] = TurnManager.turn_number

func _on_world_phase_changed(_old_phase: int, new_phase: int, _turn: int, _cause: String) -> void:
	population_at_phase[WorldPhaseRules.id_name(new_phase)] = _population(GameManager.hex_grid)

# ---------------------------------------------------------------------------
# Agregado dos smokes (balance_lab --report grava ecology_summary.json)
# ---------------------------------------------------------------------------

## Soma/mediana da seção combat_ecology de N partidas: ações por tier por era, população nos checkpoints,
## alvos por assento, primeiras ocorrências, eliminações precoces e cidades por checkpoint.
static func summarize(records: Array) -> Dictionary:
	var phases := ["FOUNDATION", "ASCENSION", "CONVERGENCE"]
	var by_phase := {}
	for phase_key in phases:
		by_phase[phase_key] = {}
		for tier in MonsterEcologyData.TIERS:
			by_phase[phase_key][tier] = {}
	var by_species := {}
	var population := {}
	var seats := {"attacks_by_seat": {}, "city_attacks_by_seat": {}, "pillages_by_seat": {}, "civ_units_killed_by_seat": {}}
	var firsts := {"first_contact_turn": {}, "first_monster_death_turn": {}, "first_civ_unit_killed_turn": {}}
	var reached := {"ASCENSION": 0, "CONVERGENCE": 0}
	var eliminations := {"before_30": 0, "before_60": 0, "total": 0, "by_seat": {}}
	var cities_at := {}
	var one_hp := 0
	var combats := {}
	var matches := 0
	var abilities_by_species := {}
	var ability_totals := {}
	var status_totals := {}
	var infection_totals := {"damage": 0, "ticks": 0, "kills": 0, "peak_tiles": 0}
	var max_site := {}
	var research_gate := {"civs": 0, "violations": 0}
	var evades := 0
	for record in records:
		var eco: Dictionary = record.get("combat_ecology", {})
		if eco.is_empty():
			continue
		matches += 1
		var world: Dictionary = record.get("world_phase", {})
		if int(world.get("ascension_turn", -1)) > 0:
			reached.ASCENSION += 1
		if int(world.get("convergence_turn", -1)) > 0:
			reached.CONVERGENCE += 1
		for phase_key in phases:
			for tier in MonsterEcologyData.TIERS:
				_add_into(by_phase[phase_key][tier], eco.by_phase[phase_key][tier])
		for kind in eco.by_species:
			if not by_species.has(kind):
				by_species[kind] = {}
			_add_into(by_species[kind], eco.by_species[kind])
		for turn_key in eco.population_at:
			if not population.has(turn_key):
				population[turn_key] = {}
				for tier in MonsterEcologyData.TIERS:
					population[turn_key][tier] = {"units": [], "sites": [], "all_neutral": []}
			for tier in MonsterEcologyData.TIERS:
				population[turn_key][tier].units.append(int(eco.population_at[turn_key].units_by_tier[tier]))
				population[turn_key][tier].sites.append(int(eco.population_at[turn_key].sites_by_tier[tier]))
				population[turn_key][tier].all_neutral.append(int(eco.population_at[turn_key].all_neutral_by_tier[tier]))
		for bucket in seats:
			_add_into(seats[bucket], eco.targets.get(bucket, {}))
		for key in firsts:
			for tier in eco.get(key, {}):
				if not firsts[key].has(tier):
					firsts[key][tier] = []
				firsts[key][tier].append(int(eco[key][tier]))
		one_hp += int(eco.get("cities_left_at_1hp", 0))
		for kind in eco.get("abilities_by_species", {}):
			if not abilities_by_species.has(kind):
				abilities_by_species[kind] = {}
			_add_into(abilities_by_species[kind], eco.abilities_by_species[kind])
		for id in eco.get("abilities", {}):
			if not ability_totals.has(id):
				ability_totals[id] = {}
			_add_into(ability_totals[id], eco.abilities[id])
		for status in eco.get("status_ticks", {}):
			if not status_totals.has(status):
				status_totals[status] = {}
			_add_into(status_totals[status], eco.status_ticks[status])
		var match_infection: Dictionary = eco.get("infection", {})
		for key in ["damage", "ticks", "kills"]:
			infection_totals[key] = int(infection_totals[key]) + int(match_infection.get(key, 0))
		infection_totals.peak_tiles = maxi(int(infection_totals.peak_tiles), int(match_infection.get("peak_tiles", 0)))
		for kind in eco.get("max_site_population", {}):
			max_site[kind] = maxi(int(max_site.get(kind, 0)), int(eco.max_site_population[kind]))
		evades += int(eco.get("ai_evades", 0))
		for civ in record.get("civs", []):
			var milestones: Dictionary = civ.get("milestones", {})
			if milestones.has("first_research_selected"):
				research_gate.civs += 1
				if int(milestones.first_research_selected) < int(milestones.get("first_city_founded", 999999)):
					research_gate.violations += 1
		_add_into(combats, eco.get("combats", {}))
		for entry in record.get("elimination_order", []):
			eliminations.total += 1
			if int(entry.get("turn", 999)) < 30:
				eliminations.before_30 += 1
			if int(entry.get("turn", 999)) < 60:
				eliminations.before_60 += 1
			eliminations.by_seat[str(entry.get("index", -1))] = int(eliminations.by_seat.get(str(entry.get("index", -1)), 0)) + 1
		for civ in record.get("civs", []):
			for turn_key in civ.get("city_count_at", {}):
				if not cities_at.has(turn_key):
					cities_at[turn_key] = []
				cities_at[turn_key].append(int(civ.city_count_at[turn_key]))
	var population_summary := {}
	for turn_key in population:
		population_summary[turn_key] = {}
		for tier in MonsterEcologyData.TIERS:
			population_summary[turn_key][tier] = {
				"units": BalanceWorldSurvey._stats(population[turn_key][tier].units),
				"sites": BalanceWorldSurvey._stats(population[turn_key][tier].sites),
				"all_neutral": BalanceWorldSurvey._stats(population[turn_key][tier].all_neutral),
			}
	var first_summary := {}
	for key in firsts:
		first_summary[key] = {}
		for tier in firsts[key]:
			first_summary[key][tier] = BalanceWorldSurvey._stats(firsts[key][tier])
	var cities_summary := {}
	for turn_key in cities_at:
		cities_summary[turn_key] = BalanceWorldSurvey._stats(cities_at[turn_key])
	return {
		"matches": matches, "reached": reached, "by_phase": by_phase, "by_species": by_species,
		"population_at": population_summary, "targets": seats, "firsts": first_summary,
		"eliminations": eliminations, "cities_at": cities_summary, "cities_left_at_1hp": one_hp, "combats": combats,
		"abilities_by_species": abilities_by_species, "abilities": ability_totals, "status_ticks": status_totals,
		"infection": infection_totals, "max_site_population": max_site, "ai_evades": evades, "research_gate": research_gate,
	}

static func _add_into(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if typeof(source[key]) in [TYPE_INT, TYPE_FLOAT]:
			target[key] = int(target.get(key, 0)) + int(source[key])
