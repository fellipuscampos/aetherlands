extends GutTest

## Cobre as funcoes PURAS de VictoryConditions.gd (Dominacao). Nenhum teste aqui muta estado de
## jogo real nem passa por GameManager/check_game_over.
##
## Fase 25: as vitorias V1 (Dominio Territorial, Ascensao Arcana) sairam; as vitorias ativas sao
## Dominacao, Supremacia Militar V2 e Transcendencia V2 (as duas ultimas em test_v2_*).

var _created_units: Array[Unit] = []
var _created_cities: Array[City] = []
var _created_hex_grids: Array[HexGrid] = []

func after_each():
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	for city in _created_cities:
		if is_instance_valid(city):
			city.queue_free()
	for grid in _created_hex_grids:
		if is_instance_valid(grid):
			grid.queue_free()
	_created_units = []
	_created_cities = []
	_created_hex_grids = []

func _make_city(coord: Vector2i, owned_tiles: Array[Vector2i] = []) -> City:
	var city := City.new()
	city.coord = coord
	city.owned_tiles = owned_tiles
	_created_cities.append(city)
	return city

func _make_unit(player: PlayerData) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit("warrior"), player, Vector2i(0, 0))
	player.units.append(unit)
	_created_units.append(unit)
	return unit

## --- Dominacao -----------------------------------------------------------

func test_dominance_achieved_when_all_others_eliminated():
	var human = PlayerData.new(CivilizationData.new())
	var rival = PlayerData.new(CivilizationData.new())
	var players: Array[PlayerData] = [human, rival]
	assert_true(VictoryConditions.is_dominance_achieved(human, players))

func test_dominance_not_achieved_while_a_rival_has_units():
	var human = PlayerData.new(CivilizationData.new())
	var rival = PlayerData.new(CivilizationData.new())
	_make_unit(rival)
	var players: Array[PlayerData] = [human, rival]
	assert_false(VictoryConditions.is_dominance_achieved(human, players))

func test_dominance_not_achieved_while_a_rival_has_a_city():
	var human = PlayerData.new(CivilizationData.new())
	var rival = PlayerData.new(CivilizationData.new())
	rival.cities.append(_make_city(Vector2i(0, 0)))
	var players: Array[PlayerData] = [human, rival]
	assert_false(VictoryConditions.is_dominance_achieved(human, players))

func test_dominance_progress_fraction_of_others_eliminated():
	var human = PlayerData.new(CivilizationData.new())
	var rival_a = PlayerData.new(CivilizationData.new()) # sem unidade/cidade -- ja "eliminado"
	var rival_b = PlayerData.new(CivilizationData.new())
	_make_unit(rival_b) # ainda vivo
	var players: Array[PlayerData] = [human, rival_a, rival_b]
	assert_almost_eq(VictoryConditions.dominance_progress(human, players), 0.5, 0.001)

func test_dominance_progress_is_zero_with_no_other_players():
	var human = PlayerData.new(CivilizationData.new())
	var players: Array[PlayerData] = [human]
	assert_eq(VictoryConditions.dominance_progress(human, players), 0.0)

## --- Dominio Territorial ---------------------------------------------------

## --- Ascensao Arcana --------------------------------------------------------
