extends GutTest

## V3 / Combat Ecology — Etapa 1: persistência (roster misto, sítio adotado, era, relógio de reposição, RNG),
## migração de save v24 (sem população retroativa no load; reposição só na fronteira de rodada), determinismo
## em mundos reais do laboratório, gates de colocação no mapa padrão, telemetria "combat_ecology" e custo.

const SAVE_PATH := "user://test_v3_ecology_world.json"
const SMALL_MAP := 61

var _original := {}
var _real_grid: HexGrid

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "map_width", "map_height", "rival_count", "human_race", "ai_controls_human_seat", "combat_ecology_on_new_match"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	GameManager.stagger_ai_turns = false

func after_each():
	if _real_grid != null and is_instance_valid(_real_grid):
		await BalanceMatchRunner.teardown_match(self, _real_grid)
	_real_grid = null
	V2AITacticalAI.clear_views()
	for key in _original:
		if key not in ["turn", "events"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(_original.events)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _small_match(index: int = 1) -> HexGrid:
	var config := BalanceSeedSet.match_config(index, 8)
	config.map_width = SMALL_MAP
	config.map_height = SMALL_MAP
	_real_grid = BalanceMatchRunner.setup_match(self, config)
	return _real_grid

func _snapshot(target: HexGrid) -> Dictionary:
	var sites: Array = []
	for site in MonsterEcologySystem.sites:
		sites.append([int(site.id), String(site.species), site.anchor, site.lair, int(site.created_turn), String(site.source)])
	var monsters: Array = []
	for unit in target.neutral_units():
		monsters.append([unit.coord, unit.unit_data.visual_kind, unit.ecology_site_id, unit.ecology_rest_until, unit.source_lair_coord, unit.is_camp_boss, snappedf(unit.hp, 0.01)])
	monsters.sort()
	var roles := {}
	for coord in target.lair_roles:
		roles[coord] = target.lair_roles[coord]
	var depleted: Array = []
	for entry in MonsterEcologySystem.depleted:
		depleted.append([entry.coord, int(entry.turn)])
	return {
		"enabled": MonsterEcologySystem.enabled, "sites": sites, "monsters": monsters, "roles": roles, "depleted": depleted,
		"targets": MonsterEcologySystem.targets.duplicate(), "next_site_id": MonsterEcologySystem.next_site_id,
		"next_refill_turn": MonsterEcologySystem.next_refill_turn, "rng_state": MonsterEcologySystem.rng.state,
		"phase": WorldEventManager.world_phase,
	}

func _save_and_reload(target: HexGrid) -> Dictionary:
	var before := _snapshot(target)
	assert_true(SaveManager.save_game(target, SAVE_PATH))
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(target, SAVE_PATH))
	return before

# --- Save / load --------------------------------------------------------------------------------------

func test_ecology_survives_save_and_load_without_duplication():
	var target := _small_match()
	assert_true(MonsterEcologySystem.enabled)
	assert_false(MonsterEcologySystem.sites.is_empty(), "mapa pequeno também recebe ecologia")
	# Estado vivo: era, roster misto (inclui espécie nova), descanso de raide, sítio esvaziado e relógio de reposição.
	WorldEventManager.world_phase = WorldPhaseRules.Phase.ASCENSION
	var victim: Dictionary = MonsterEcologySystem.sites[0]
	for unit in target.neutral_units():
		if unit.ecology_site_id == int(victim.id):
			target.remove_unit(unit)
	var some := target.neutral_units().filter(func(u): return u.ecology_site_id >= 0)
	some[0].ecology_rest_until = 17
	MonsterEcologySystem.next_refill_turn = 9
	MonsterEcologySystem.process_round(target, 4)
	assert_false(MonsterEcologySystem.depleted.is_empty())
	MonsterEcologySystem.rng.randf()
	var before := _save_and_reload(target)
	var after := _snapshot(target)
	assert_eq(after, before, "mesma população, sítios, papéis, memória, relógio e RNG")
	assert_eq(target.neutral_units().size(), before.monsters.size(), "nenhum monstro duplicado")
	# Mesmo futuro depois do load: o próximo sorteio do RNG da ecologia continua a sequência.
	var probe := MonsterEcologySystem.rng.randf()
	MonsterEcologySystem.rng.state = int(before.rng_state)
	assert_eq(MonsterEcologySystem.rng.randf(), probe)

func test_saved_version_is_26_and_carries_the_ecology_block():
	var target := _small_match(2)
	assert_eq(SaveManager.SAVE_VERSION, 26)
	assert_true(24 in SaveManager.MIGRATABLE_SAVE_VERSIONS)
	assert_true(25 in SaveManager.MIGRATABLE_SAVE_VERSIONS)
	assert_true(SaveManager.save_game(target, SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	assert_eq(int(data.version), 26)
	assert_true(data.has("combat_ecology"))
	assert_true(data.combat_ecology.has("hazards") and data.combat_ecology.has("burrowed"), "v26: perigos e Vermes subterrâneos")
	assert_eq((data.combat_ecology.sites as Array).size(), MonsterEcologySystem.sites.size())
	var with_site := 0
	for unit in data.neutral_units:
		assert_true(unit.has("ecology_site"))
		with_site += 1 if int(unit.ecology_site) >= 0 else 0
	assert_gt(with_site, 0)
	assert_false(data.has("combat_ecology_on_new_match"), "a flag de fixture nunca é salva")

func test_v24_save_loads_without_mass_spawn_and_refills_only_after_the_round_boundary():
	var target := _small_match(3)
	assert_true(SaveManager.save_game(target, SAVE_PATH))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	data.version = 24
	data.erase("combat_ecology")
	for unit in data.neutral_units:
		unit.erase("ecology_site")
		unit.erase("ecology_rest")
	data.lair_state.roles = (data.lair_state.roles as Array).filter(func(entry): return String(entry[2]) != HexGrid.LAIR_ROLE_ECOLOGY)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var neutral_in_file: int = (data.neutral_units as Array).size()
	WorldEventManager.reset_for_new_match()
	assert_true(SaveManager.load_game(target, SAVE_PATH), "save v24 carrega")
	assert_eq(target.neutral_units().size(), neutral_in_file, "nenhum spawn dentro do load")
	for unit in target.neutral_units():
		assert_eq(unit.ecology_site_id, -1, "monstros antigos preservados como estavam")
	assert_true(MonsterEcologySystem.enabled, "runtime inicializado")
	assert_true(MonsterEcologySystem.migrated)
	assert_true(MonsterEcologySystem.sites.is_empty(), "sem população retroativa")
	var turn := TurnManager.turn_number
	MonsterEcologySystem.process_round(target, turn)
	assert_eq(target.neutral_units().size(), neutral_in_file, "nada no mesmo turno do load")
	assert_false(MonsterEcologySystem.targets.is_empty(), "alvos calculados na fronteira de rodada, fora do load")
	var grown := false
	for next in range(turn + 1, turn + 8):
		MonsterEcologySystem.process_round(target, next)
		grown = grown or MonsterEcologySystem.sites.size() > 0
	assert_true(grown, "a reposição normal começa depois da fronteira")
	assert_lte(MonsterEcologySystem.sites.size(), 4, "gradual: no máximo um sítio por intervalo")

# --- Mundo real: gates e determinismo -------------------------------------------------------------------

func _real_world_state(index: int) -> Dictionary:
	_real_grid = BalanceMatchRunner.setup_match(self, BalanceSeedSet.match_config(index))
	var capitals: Array = []
	for player in GameManager.players:
		capitals.append(player.cities[0].coord)
	var survey := BalanceWorldSurvey.survey_ecology(_real_grid, capitals)
	var sites: Array = []
	for site in MonsterEcologySystem.sites:
		sites.append([String(site.species), MonsterEcologyData.tier_of(String(site.species)), site.anchor, String(site.source)])
	var units: Array = []
	for unit in _real_grid.neutral_units():
		if unit.ecology_site_id >= 0:
			units.append([unit.coord, unit.unit_data.visual_kind, unit.ecology_site_id])
	units.sort()
	var regional := BalanceWorldSurvey.survey_regional(_real_grid, capitals)
	await BalanceMatchRunner.teardown_match(self, _real_grid)
	_real_grid = null
	return {"survey": survey, "sites": sites, "units": units, "regional": regional}

func test_real_worlds_are_deterministic_and_pass_the_placement_gates():
	for index in [0, 1, 2, 3]:
		var first: Dictionary = await _real_world_state(index)
		var second: Dictionary = await _real_world_state(index)
		assert_eq(first.sites, second.sites, "match %d: sítios idênticos (espécie, tier, âncora, origem)" % index)
		assert_eq(first.units, second.units, "match %d: unidades idênticas" % index)
		var survey: Dictionary = first.survey
		for tier in MonsterEcologyData.TIERS:
			assert_eq(int(survey.capital_violations[tier]), 0, "match %d: zona de segurança %s" % [index, tier])
			assert_between(int(survey.sites_by_tier[tier]), int(MonsterEcologyData.TARGET_MIN[tier]), int(MonsterEcologyData.TARGET_MAX[tier]), "match %d: faixa %s" % [index, tier])
		for key in survey.invalid:
			if key != "resource":
				assert_eq(int(survey.invalid[key]), 0, "match %d: nenhum spawn inválido (%s)" % [index, key])
		for kind in MonsterEcologyData.SPECIES_ORDER:
			assert_gt(int(survey.units_by_species.get(kind, 0)), 0, "match %d: %s presente" % [index, kind])
		assert_lt(float(survey.distribution.max_half_share), 0.8, "match %d: sem 80%% numa metade" % index)
		assert_gte(int(survey.min_advanced_capital_distance), 14)
		for entry in first.regional:
			assert_true(bool(entry.exists), "ameaça regional preservada")
			assert_between(int(entry.distance), 7, 10)

# --- Telemetria e custo ---------------------------------------------------------------------------------

func test_lab_telemetry_has_the_combat_ecology_section_and_disconnects():
	var config := BalanceSeedSet.match_config(0, 12)
	config.map_width = SMALL_MAP
	config.map_height = SMALL_MAP
	var record: Dictionary = await BalanceMatchRunner.run_match(self, config, {"turn_cap": 12})
	assert_true(record.has("combat_ecology"))
	var eco: Dictionary = record.combat_ecology
	for key in ["initial", "by_species", "by_tier", "by_phase", "targets", "combats", "population_at", "population_at_end", "first_contact_turn", "first_monster_death_turn", "first_civ_unit_killed_turn"]:
		assert_true(eco.has(key), key)
	assert_true(eco.population_at.has("1") or TurnManager.turn_number >= 1)
	assert_eq(eco.by_species.size(), 12)
	for phase_key in ["FOUNDATION", "ASCENSION", "CONVERGENCE"]:
		assert_eq((eco.by_phase[phase_key] as Dictionary).size(), 3)
	assert_gt(int(eco.initial.units_by_tier.BASIC), 0)

func test_ecology_costs_nothing_per_frame_and_little_per_round():
	var target := _small_match(4)
	var rounds := 20
	var started := Time.get_ticks_usec()
	for turn in range(2, 2 + rounds):
		MonsterEcologySystem.process_round(target, turn)
	var per_round_ms := (Time.get_ticks_usec() - started) / 1000.0 / rounds
	assert_lt(per_round_ms, 25.0, "bookkeeping + reposição por rodada")
	var units := target.neutral_units().filter(func(u): return u.ecology_site_id >= 0)
	started = Time.get_ticks_usec()
	for unit in units:
		unit.reset_movement()
		MonsterAI.act_for_unit(unit, target, 30)
	var per_unit_ms := (Time.get_ticks_usec() - started) / 1000.0 / maxf(units.size(), 1.0)
	assert_lt(per_unit_ms, 5.0, "atividade por monstro reusa o loop da MonsterAI sem busca cara")
	var script: GDScript = load("res://scripts/core/MonsterEcologySystem.gd")
	assert_false(script.source_code.contains("func _process"), "nada por frame")
