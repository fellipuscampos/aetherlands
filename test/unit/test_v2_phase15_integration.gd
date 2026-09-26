extends GutTest

## Aetherlands V2, Fase 15 — testes de INTEGRAÇÃO: provam que Economia, Território, Logística,
## Construtor e Militar compõem de verdade, não só cada peça isolada.
## §113 Expansão territorial: recurso fora do território -> anexação (Fase 13) -> melhoria.
## §114 Economia -> Logística -> Militar (fluxo obrigatório de 12 passos).
## §115 Déficit -> Tensão: Fazendas a 50% derrubam a capacidade e criam Tensão; corrigir o Ouro
##      devolve as Fazendas a 100% e a Tensão some.
## §123 Os mesmos sistemas valem para um rival (sem decisão estratégica de IA).
## §124 Recurso nunca gateia conteúdo militar.
## §129-131 Anti-hardcode nos runtimes e nenhum estado derivado em PlayerData.
## (O fluxo principal de 43 passos, §116, vive em test_v2_phase15_main_flow.gd — jogo real.)

const HALL := "v2_building_guardian_hall"
const MASTERY := "v2_building_guardian_mastery"
const FARM := "v2_building_farm"
const MARKET := "v2_building_market"
const WORKSHOP := "v2_building_workshop"
const ACADEMY := "v2_building_academy"
const SHIELD := "v2_unit_shieldbearer" # custo 1
const GUARDIAN := "v2_unit_guardian" # custo 2
const SENTINEL := "v2_unit_sentinel" # custo 3
const CHAMPION := "v2_legendary_guardian_champion" # custo 5
const BUILDER := "v2_unit_builder"

var _grids: Array[HexGrid] = []
var _players: Array[PlayerData] = []
var _original_human: PlayerData
var _original_grid: HexGrid

func before_each():
	_original_human = GameManager.human_player
	_original_grid = GameManager.hex_grid

func after_each():
	GameManager.human_player = _original_human
	GameManager.hex_grid = _original_grid
	for player in _players:
		player.release_relations()
	_players.clear()
	for grid in _grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_grids.clear()

## Grid de grama raio 3 com a capital em (0,0) (que já reivindica o anel de raio 1) e a Doutrina
## do Guardião pesquisada até `guardian_through`.
func _grid_with_city(guardian_through: int = 9) -> Dictionary:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-3, 4):
		for r in range(-3, 4):
			if absi(q + r) <= 3:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var player := PlayerData.new(CivilizationData.new())
	for n in range(1, guardian_through + 1):
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	_players.append(player)
	_grids.append(grid)
	var city := grid.found_city(Vector2i(0, 0), player, "Capital", true)
	return {"grid": grid, "player": player, "city": city}

## Completa, EM ORDEM, os nós N1..`tier` da linha econômica `branch`.
func _research_tier(player: PlayerData, branch: String, tier: int) -> void:
	var ids: Array = V2InfrastructureEconomyData.unlock_ids_for_branch(branch)
	for i in tier:
		var node := V2ResearchDatabase.node_for_unlock_id(ids[i])
		if not player.v2_research.is_completed(node.id):
			assert_true(player.v2_research.complete_research(node.id), "pesquisa %s" % node.id)

## Tiles livres do anel da capital (território próprio desde a fundação).
func _free_owned(s: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var city: City = s.city
	var grid: HexGrid = s.grid
	for coord in city.owned_tiles:
		if coord != city.coord and grid.get_unit_at(coord) == null:
			result.append(coord)
	return result

## "Produz" uma unidade: o MESMO gate da produção real (can_train) e ela nasce num tile livre.
func _produce(s: Dictionary, kind: String, coord: Vector2i) -> Unit:
	var city: City = s.city
	assert_true(city.can_train(kind), "can_train(%s): %s" % [kind, V2LogisticsRuntime.training_unavailable_reason(s.player, city, kind)])
	var unit: Unit = s.grid.spawn_unit(coord, UnitDatabase.create_unit(kind), s.player)
	unit.movement_left = unit.unit_data.movement_points
	return unit

# --- §113: City Level -> território -> recurso -> economia --------------------------------------------

func test_113_a_resource_outside_territory_is_annexed_then_improved():
	var s := _grid_with_city()
	var city: City = s.city
	var grid: HexGrid = s.grid
	var resource := Vector2i(2, 0) # distância 2: fora do anel de fundação
	var tile := TerrainDatabase.create_tile(HexTileData.TerrainType.JUNGLE)
	tile.resource = "gems"
	grid.tiles[resource] = tile
	var builder: Unit = grid.spawn_unit(resource, UnitDatabase.create_unit(BUILDER), s.player)
	builder.work_charges_remaining = 1
	builder.movement_left = builder.unit_data.movement_points
	assert_eq(V2ConstructorRuntime.unavailable_reason(builder, grid), "O recurso precisa estar no território de uma cidade própria.", "1. fora do território: não melhora")
	# Anexação manual da Fase 13: City Level II (raio 2) + 1 Ponto de Anexação.
	city.city_level = 2
	city.annexation_points = 1
	assert_true(city.can_annex_tile(resource, grid), city.annex_unavailable_reason(resource, grid))
	assert_true(city.annex_tile(resource, grid), "2. anexado pela mecânica da Fase 13")
	assert_eq(grid.city_owning_tile(resource), city)
	var gold_before := V2EconomyRuntime.city_gold_income(city)
	assert_true(V2ConstructorRuntime.improve_resource(builder, grid), "3. agora melhora")
	assert_almost_eq(V2EconomyRuntime.city_gold_income(city), gold_before + 4.0, 0.0001, "4. a Mina de Gemas vira Ouro real")

# --- §114: Economia -> Logística -> Militar ---------------------------------------------------------

func test_114_economy_logistics_military_flow():
	var s := _grid_with_city(3)
	var city: City = s.city
	var player: PlayerData = s.player
	city.buildings[HALL] = true
	player.gold = 1000.0
	var free := _free_owned(s)
	# 1. Cidade base: capacidade 4.
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(player), 4.0, 0.0001, "1. capacidade base")
	# 2. Produz Escudeiros até 4.
	var units: Array[Unit] = []
	for i in 4:
		units.append(_produce(s, SHIELD, free[i]))
	assert_eq(V2LogisticsRuntime.player_supply_used(player), 4, "2. 4 usados")
	# 3. A quinta é bloqueada, com o motivo claro.
	assert_false(city.can_train(SHIELD), "3. quinta bloqueada")
	assert_eq(V2LogisticsRuntime.training_unavailable_reason(player, city, SHIELD), "Suprimentos insuficientes: requer 1, disponíveis 0.")
	# 4-5. Pesquisa Abastecimento (Logística N1) e constrói a Fazenda.
	assert_false(city.can_build(FARM), "sem a pesquisa, sem Fazenda")
	_research_tier(player, "logistics", 1)
	assert_true(city.can_build(FARM), "4. Abastecimento libera a Fazenda")
	city.buildings[FARM] = true
	# 6. Capacidade 8.
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(player), 8.0, 0.0001, "6. capacidade 8")
	# 7. A quinta unidade é permitida.
	units.append(_produce(s, SHIELD, free[4]))
	assert_eq(V2LogisticsRuntime.player_supply_used(player), 5, "7. quinta produzida")
	# 8. Evoluir aumenta o usado (delta 1 -> 2).
	for n in [4, 5]:
		player.v2_research.complete_research("v2_doctrine_guardian_%d" % n)
	assert_true(V2UnitUpgrade.perform_upgrade(player, units[0], s.grid), V2UnitUpgrade.unavailable_upgrade_reason(player, units[0], s.grid))
	assert_eq(units[0].unit_data.visual_kind, GUARDIAN)
	assert_eq(V2LogisticsRuntime.player_supply_used(player), 6, "8. evolução soma o delta")
	# 9-10. Perde a Fazenda: Tensão (6 > 4), nenhuma unidade destruída.
	city.buildings.erase(FARM)
	assert_true(V2LogisticsRuntime.is_logistically_strained(player), "10. Tensão")
	assert_eq(player.units.size(), 5, "excesso nunca mata unidade")
	assert_almost_eq(V2LogisticsRuntime.combat_multiplier(units[1]), 0.85, 0.0001)
	# 11-12. Ganha um Haras: +4 de capacidade, a Tensão desaparece.
	city.resource_improvements[free[5]] = "v2_improvement_horse_ranch"
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(player), 8.0, 0.0001, "11. Haras: 4 + 4")
	assert_false(V2LogisticsRuntime.is_logistically_strained(player), "12. Tensão desaparece")
	assert_almost_eq(V2LogisticsRuntime.combat_multiplier(units[1]), 1.0, 0.0001)

# --- §115: Déficit -> Tensão ------------------------------------------------------------------------

func test_115_deficit_halves_farms_creating_tension_and_fixing_gold_clears_both():
	var s := _grid_with_city(3)
	var city: City = s.city
	var player: PlayerData = s.player
	var grid: HexGrid = s.grid
	city.city_level = 2 # até 2 cópias de Fazenda
	city.buildings[HALL] = true
	city.buildings[MASTERY] = true
	city.buildings[ACADEMY] = true
	city.buildings[FARM] = true
	city.repeatable_building_counts[FARM] = 2
	player.gold = 100.0
	# 1. Várias Fazendas sustentam o exército: capacidade 4 + 2x4 = 12, 10 usados.
	var placed := 0
	for coord in grid.tiles.keys():
		if placed >= 10:
			break
		if coord != city.coord and grid.get_unit_at(coord) == null:
			grid.spawn_unit(coord, UnitDatabase.create_unit(SHIELD), player)
			placed += 1
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(player), 12.0, 0.0001, "1. capacidade 12")
	assert_eq(V2LogisticsRuntime.player_supply_used(player), 10)
	assert_false(V2LogisticsRuntime.is_logistically_strained(player))
	assert_false(V2EconomyRuntime.is_gold_deficit(player), "caixa positivo: ainda sem Déficit")
	# 2. O upkeep (Salão 1 + Bastião 2 + Academia 1 + 2 Fazendas 2 = 6) supera a renda (2) e o caixa acaba.
	assert_almost_eq(V2EconomyRuntime.player_gold_upkeep(player), 6.0, 0.0001)
	player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(player), "2. Déficit")
	# 3-4. Fazendas (e a Academia) a 50%: a capacidade cai 12 -> 8.
	assert_true(V2EconomyRuntime.city_income_breakdown(city, "supply").deficit_discounted, "3. Fazendas a 50%")
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(player), 8.0, 0.0001, "4. capacidade cai")
	var academy_yield := V2InfrastructureEconomyData.yield_per_copy("v2_building_academy", 1)
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(city, "knowledge").building_total, academy_yield * 0.5, 0.0001, "Academia opera a 50% no deficit")
	# 5-6. 10 usados > 8: Tensão aparece — por causa do Déficit, sem nenhuma unidade nova.
	assert_true(V2LogisticsRuntime.is_logistically_strained(player), "6. Tensão aparece")
	# 7. Mina de Gemas corrige o líquido nominal: 2 + 4 = 6 >= 6.
	city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_gem_mine"
	# 8. Déficit desaparece (caixa ainda 0, mas o líquido nominal deixou de ser negativo).
	assert_false(V2EconomyRuntime.is_gold_deficit(player), "8. Déficit desaparece")
	# 9. Fazendas voltam a 100%.
	assert_false(V2EconomyRuntime.city_income_breakdown(city, "supply").deficit_discounted, "9. Fazendas a 100%")
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(player), 12.0, 0.0001)
	# 10. Tensão desaparece.
	assert_false(V2LogisticsRuntime.is_logistically_strained(player), "10. Tensão desaparece")

func test_in_deficit_upkeep_buildings_run_at_half_while_market_base_and_improvements_stay_full():
	var s := _grid_with_city(3)
	var city: City = s.city
	var player: PlayerData = s.player
	_research_tier(player, "economy", 1)
	city.city_level = 2
	for id in [MARKET, HALL, MASTERY, ACADEMY, WORKSHOP, FARM]:
		city.buildings[id] = true
	city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_iron_mine"
	# Renda nominal 2 + Mercado 4 = 6; upkeep 1 + 2 + 1 + 1 + 1 = 6 -> ainda não negativo.
	# Uma segunda cidade só com upkeep (+2 de renda base, +3 de upkeep) empurra pra -1.
	var second: City = s.grid.found_city(Vector2i(-3, 3), player, "Segunda", true)
	second.buildings["v2_building_warrior_hall"] = true
	second.buildings["v2_building_warrior_mastery"] = true
	player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(player), "pré-condição: Déficit")
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(city, "gold").building_total, 4.0, 0.0001, "Mercado a 100%")
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(city, "production").building_total, 1.0, 0.0001, "Oficina a 50% (2 -> 1)")
	var academy_yield := V2InfrastructureEconomyData.yield_per_copy("v2_building_academy", 1)
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(city, "knowledge").building_total, academy_yield * 0.5, 0.0001, "Academia opera a 50% no deficit")
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(city, "supply").building_total, 2.0, 0.0001, "Fazenda a 50% (4 -> 2)")
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(city, "gold").base, 2.0, 0.0001, "base intacta")
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(city, "production").improvement_total, 2.0, 0.0001, "Mina de Ferro intacta")

# --- §123: os mesmos sistemas valem para um rival ---------------------------------------------------

func test_123_supply_deficit_and_captured_economy_work_the_same_for_a_rival():
	var s := _grid_with_city(3) # s.player faz o papel do rival (nunca é GameManager.human_player)
	var city: City = s.city
	var rival: PlayerData = s.player
	GameManager.human_player = null
	city.buildings[HALL] = true
	rival.gold = 100.0
	for coord in _free_owned(s).slice(0, 4):
		s.grid.spawn_unit(coord, UnitDatabase.create_unit(SHIELD), rival)
	assert_eq(V2LogisticsRuntime.player_supply_used(rival), 4, "unidade V2 do rival consome Suprimentos")
	assert_false(city.can_train(SHIELD), "gate de Suprimentos vale pro rival")
	city.buildings[MASTERY] = true
	rival.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(rival), "Déficit vale pro rival")
	# Captura: prédio e melhoria passam a render pelo novo dono.
	var captor := PlayerData.new(CivilizationData.new())
	_players.append(captor)
	captor.gold = 100.0
	city.buildings[FARM] = true
	city.resource_improvements[Vector2i(1, 0)] = "v2_improvement_horse_ranch"
	city.change_owner(captor)
	rival.cities.erase(city)
	captor.cities.append(city)
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(captor), 4.0 + 4.0 + 4.0, 0.0001, "Fazenda e Haras capturados rendem pro novo dono")
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(rival), 0.0, 0.0001, "e deixam de render pro antigo")

# --- §124: recurso nunca gateia conteúdo militar ------------------------------------------------------

func test_124_resources_never_gate_military_training():
	var s := _grid_with_city(0)
	var city: City = s.city
	var player: PlayerData = s.player
	for n in range(1, 4):
		player.v2_research.complete_research("v2_doctrine_cavalry_%d" % n)
		player.v2_research.complete_research("v2_doctrine_warrior_%d" % n)
	city.buildings["v2_building_war_stable"] = true
	city.buildings["v2_building_warrior_hall"] = true
	player.gold = 100.0
	assert_eq(ResourceDatabase.count_controlled(player, s.grid, "horses"), 0, "pré-condição: nenhum Cavalo")
	assert_eq(ResourceDatabase.count_controlled(player, s.grid, "iron"), 0, "pré-condição: nenhum Ferro")
	assert_true(city.can_train("v2_unit_cavalier"), "Cavalaria sem Cavalos")
	assert_true(city.can_train("v2_unit_warrior"), "Guerreiro sem Ferro")

# --- §129-131: anti-hardcode e estado derivado ----------------------------------------------------------

func _code_without_comments(path: String) -> String:
	var lines: PackedStringArray = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var cut := line.find("#")
		lines.append(line if cut == -1 else line.substr(0, cut))
	return "\n".join(lines)

func test_130_runtime_files_never_name_concrete_units_buildings_or_improvements():
	for path in ["res://scripts/core/V2EconomyRuntime.gd", "res://scripts/core/V2LogisticsRuntime.gd", "res://scripts/core/CombatResolver.gd", "res://scripts/city/City.gd", "res://scripts/autoload/SelectionManager.gd"]:
		var code := _code_without_comments(path)
		for prefix in ["\"v2_unit_", "\"v2_legendary_", "\"v2_building_", "\"v2_improvement_"]:
			assert_false(code.contains(prefix), "%s cita um id concreto (%s...)" % [path, prefix])

func test_129_v2_runtimes_never_branch_on_a_resource_id():
	for path in ["res://scripts/core/V2EconomyRuntime.gd", "res://scripts/core/V2LogisticsRuntime.gd", "res://scripts/core/V2ConstructorRuntime.gd"]:
		var code := _code_without_comments(path)
		for resource_id in V2ResourceImprovementData.resource_ids():
			assert_false(code.contains("\"%s\"" % resource_id), "%s cita o recurso %s" % [path, resource_id])

func test_131_player_data_has_no_supply_deficit_or_tension_state():
	for property in PlayerData.new(CivilizationData.new()).get_property_list():
		var name := String(property.name).to_lower()
		for forbidden in ["supply", "deficit", "tension", "strained"]:
			assert_false(name.contains(forbidden), "PlayerData.%s deveria ser derivado, nunca estado" % property.name)

# --- Composição rápida (grid mínimo): Déficit bloqueia, Mercado recupera, Construtor melhora ---------

func test_end_to_end_economy_logistics_deficit_and_constructor_flow_survives_save_and_load():
	var s := _grid_with_city()

	# 1-3. Cidade nova: capacidade e renda de base, sem Déficit nem Tensão.
	assert_almost_eq(V2EconomyRuntime.player_supply_capacity(s.player), 4.0, 0.0001)
	assert_false(V2EconomyRuntime.is_gold_deficit(s.player))
	assert_false(V2LogisticsRuntime.is_logistically_strained(s.player))

	# 4-6. Salão + Escudeiro: produção normal, dentro da capacidade.
	s.player.gold = 50.0
	s.city.buildings[HALL] = true
	assert_true(s.city.can_train(SENTINEL), "com N9, a forma treinável do Salão é a Sentinela")
	var shield: Unit = s.grid.spawn_unit(Vector2i(1, 0), UnitDatabase.create_unit(SHIELD), s.player)
	assert_eq(V2LogisticsRuntime.player_supply_used(s.player), 1)

	# 7-9. Bastião + tenta a Sentinela (N7, custo 3): 1 (vivo) + 3 = 4, ainda cabe -- mas puxa o
	# upkeep pra cima o bastante pra abrir Déficit (upkeep 3, renda base 2, caixa raspando).
	s.city.buildings[MASTERY] = true
	s.player.gold = 0.0
	assert_true(V2EconomyRuntime.is_gold_deficit(s.player), "9. upkeep(3) > renda(2), caixa zerada -- Déficit")
	assert_eq(V2LogisticsRuntime.training_unavailable_reason(s.player, s.city, SENTINEL), "Déficit de Ouro: estabilize a economia antes de treinar novas tropas.", "10. Déficit é o motivo, não Suprimentos (que ainda cabia)")
	assert_false(s.city.can_build(FARM), "11. novo prédio com upkeep também bloqueado em Déficit")
	assert_eq(s.city.deficit_build_reason(FARM), "Déficit de Ouro: estabilize a economia antes de adicionar manutenção.")

	# 12-14. O Mercado é a rota de recuperação: sem upkeep, sempre liberado, mesmo em Déficit.
	s.player.v2_research.complete_research(V2ResearchDatabase.node_for_unlock_id(MARKET).id)
	assert_eq(s.city.deficit_build_reason(MARKET), "", "14. Mercado nunca é bloqueado pelo próprio Déficit")
	s.city.buildings[MARKET] = true
	assert_false(V2EconomyRuntime.is_gold_deficit(s.player), "15. renda(2+4=6) > upkeep(3) -- recuperado")

	# 16-18. Com o Déficit resolvido, a Sentinela agora só depende de Suprimentos (que cabia desde
	# o início: 1 vivo + 3 novo = 4 == capacidade 4).
	assert_true(s.city.can_train(SENTINEL), "16. Déficit não é mais o motivo -- Suprimentos já cabia")
	assert_true(V2LogisticsRuntime.can_afford_training(s.player, s.city, SENTINEL))

	# 19-21. Oficina + pesquisa: libera o Construtor pelo MESMO gate genérico (sem hardcode).
	s.player.v2_research.complete_research(V2ResearchDatabase.node_for_unlock_id(WORKSHOP).id)
	s.city.buildings[WORKSHOP] = true
	assert_true(s.city.can_train(BUILDER), "21. Oficina + pesquisa -- Construtor liberado")
	assert_eq(V2LogisticsRuntime.training_unavailable_reason(s.player, s.city, BUILDER), "", "Construtor nunca é barrado por Suprimentos (custo 0)")

	# 22-24. Território anexado com Ferro: dá cargas de nascimento (tier 1, sem pesquisa de
	# Indústria) e nasce o Construtor JÁ em cima do recurso.
	var iron_tile := TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	iron_tile.resource = "iron"
	s.grid.tiles[Vector2i(-2, 0)] = iron_tile
	s.city.owned_tiles.assign([Vector2i(-2, 0)])
	var builder: Unit = s.grid.spawn_unit(Vector2i(-2, 0), UnitDatabase.create_unit(BUILDER), s.player)
	builder.work_charges_remaining = V2ConstructorRuntime.charges_for_new_builder(s.player)
	builder.movement_left = builder.unit_data.movement_points
	assert_eq(builder.work_charges_remaining, 1, "24. tier 1 -- 1 carga")

	# 25-28. Melhora o recurso de verdade: dentro do território, instantâneo.
	assert_true(V2ConstructorRuntime.improve_resource(builder, s.grid))
	assert_true(builder.is_queued_for_deletion(), "28. carga única consumida -- Construtor some sem morte/XP")
	assert_false(builder in s.player.units)
	assert_eq(s.city.resource_improvements[Vector2i(-2, 0)], "v2_improvement_iron_mine")

	# 29-31. A melhoria já rende: +2 Produção local (tier 1), nunca descontada mesmo se houvesse Déficit.
	assert_almost_eq(V2EconomyRuntime.city_income_breakdown(s.city, "production").improvement_total, 2.0, 0.0001)

	# 32. Save/load de tudo isto (melhoria por coord, cargas do Construtor, Déficit/Tensão nunca
	# salvos e re-derivados idênticos): ver test_save_manager.gd, único fixture com mapa gerado
	# válido pro formato do save.
