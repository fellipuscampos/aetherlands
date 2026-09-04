extends GutTest

## Roadmap de gameplay Fase 3 — identidade economica racial (RaceEconomy.gd).
## Decisao ja validada com o usuario: bonus MODESTOS, nao assimetria
## estrutural forte. Cobre tanto as funcoes puras de RaceEconomy quanto a
## integracao real via City.collect_yields()/GameManager._process_research.

func _make_player(race: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.race = race
	return PlayerData.new(civ)

## Regressao: sem raca definida (civ.race == "", o mesmo que todo teste
## pre-existente ja usa via CivilizationData.new()), nenhum bonus racial
## deveria se aplicar — comportamento identico ao de antes da Fase 3.
func test_apply_yield_bonus_does_nothing_without_a_recognized_race():
	var totals := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	RaceEconomy.apply_yield_bonus(totals, "", false, false)
	assert_eq(totals, {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0})

func test_dwarf_gets_gold_and_production_bonus_only_with_hills_or_iron():
	var totals_without := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	RaceEconomy.apply_yield_bonus(totals_without, "dwarf", false, false)
	assert_eq(totals_without, {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}, "sem Colina nem Ferro trabalhados, anao nao deveria ganhar bonus nenhum")

	var totals_with_hills := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	RaceEconomy.apply_yield_bonus(totals_with_hills, "dwarf", true, false)
	assert_almost_eq(totals_with_hills.gold, 10.0 * RaceEconomy.DWARF_GOLD_PRODUCTION_BONUS, 0.01)
	assert_almost_eq(totals_with_hills.production, 10.0 * RaceEconomy.DWARF_GOLD_PRODUCTION_BONUS, 0.01)
	assert_almost_eq(totals_with_hills.food, 10.0, 0.01, "bonus de anao nao deveria mexer em comida/mana")

func test_elf_gets_mana_bonus_only():
	var totals := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	RaceEconomy.apply_yield_bonus(totals, "elf", false, false)
	assert_almost_eq(totals.mana, 10.0 * RaceEconomy.ELF_MANA_BONUS, 0.01)
	assert_almost_eq(totals.food, 10.0, 0.01)
	assert_almost_eq(totals.production, 10.0, 0.01)
	assert_almost_eq(totals.gold, 10.0, 0.01)

func test_orc_gets_production_bonus_only():
	var totals := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	RaceEconomy.apply_yield_bonus(totals, "orc", false, false)
	assert_almost_eq(totals.production, 10.0 * RaceEconomy.ORC_PRODUCTION_BONUS, 0.01)
	assert_almost_eq(totals.gold, 10.0, 0.01)

func test_human_gets_a_small_bonus_to_every_yield():
	var totals := {"food": 10.0, "production": 10.0, "gold": 10.0, "mana": 10.0}
	RaceEconomy.apply_yield_bonus(totals, "human", false, false)
	assert_almost_eq(totals.food, 10.0 * RaceEconomy.HUMAN_ALL_YIELDS_BONUS, 0.01)
	assert_almost_eq(totals.production, 10.0 * RaceEconomy.HUMAN_ALL_YIELDS_BONUS, 0.01)
	assert_almost_eq(totals.gold, 10.0 * RaceEconomy.HUMAN_ALL_YIELDS_BONUS, 0.01)
	assert_almost_eq(totals.mana, 10.0 * RaceEconomy.HUMAN_ALL_YIELDS_BONUS, 0.01)

func test_science_multiplier_is_only_above_one_for_elf():
	assert_almost_eq(RaceEconomy.science_multiplier_for("elf"), RaceEconomy.ELF_SCIENCE_BONUS, 0.01)
	assert_almost_eq(RaceEconomy.science_multiplier_for("dwarf"), 1.0, 0.01)
	assert_almost_eq(RaceEconomy.science_multiplier_for(""), 1.0, 0.01)

func test_growth_multiplier_is_only_above_one_for_orc():
	assert_almost_eq(RaceEconomy.growth_multiplier_for("orc"), RaceEconomy.ORC_GROWTH_BONUS, 0.01)
	assert_almost_eq(RaceEconomy.growth_multiplier_for("elf"), 1.0, 0.01)

## Integracao: City.collect_yields() de verdade aplica o bonus de anao
## quando o tile TRABALHADO (nao so o da cidade) e Colina.
func test_city_collect_yields_applies_dwarf_bonus_on_worked_hills():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	var hill := Vector2i(1, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN) # sem yield de producao proprio, isola o efeito
	hex_grid.tiles[hill] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var dwarf_player := _make_player("dwarf")
	var city := hex_grid.found_city(center, dwarf_player, "Capital")
	city.worked_tiles = [hill]

	var human_player := _make_player("")
	var city_b := City.new()
	city_b.owner_player = human_player
	city_b.coord = center
	city_b.worked_tiles = [hill]

	var dwarf_gold = city.collect_yields(hex_grid).gold
	var human_gold = city_b.collect_yields(hex_grid).gold

	assert_gt(dwarf_gold, human_gold, "anao trabalhando uma Colina deveria render mais ouro que humano na mesma situacao")
	city_b.queue_free()
	hex_grid.queue_free()

## Integracao: GameManager._process_research aplica o multiplicador de
## ciencia do elfo.
func test_process_research_applies_elf_science_multiplier():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)

	var elf_player := _make_player("elf")
	var city = hex_grid.found_city(coord, elf_player, "Capital")
	city.population = 10
	elf_player.current_research = "canalizacao_base" # custo 25, bem mais que a ciencia de 1 turno

	GameManager._process_research(elf_player)

	assert_almost_eq(elf_player.research_progress, 10.0 * RaceEconomy.ELF_SCIENCE_BONUS, 0.01)
	hex_grid.queue_free()
