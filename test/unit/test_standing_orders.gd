extends GutTest

## ORDENS PERMANENTES (marcha "mover até" e Explorar) — 2026-10-10, relato do usuário: "ele fica preso nessa rota sem
## eu poder atacar; às vezes ele parou do lado de um inimigo, mas o próximo turno já tá marcando pra andar".
## (1) A ordem anda com o movimento que SOBROU do turno que está acabando (GameManager._on_turn_changed chama
## HexGrid.run_standing_orders ANTES de reset_movement): no turno do jogador a unidade está inteira e pode atacar —
## coberto em test_game_manager.gd. (2) CONTATO: a ordem para (sem ser cancelada) quando um passo põe um inimigo NOVO
## ao alcance — este arquivo.

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _original_human_player: PlayerData
var _notices: Array[String] = []

func before_each():
	_original_human_player = GameManager.human_player
	hex_grid = HexGrid.new()
	hex_grid._ready()
	autofree(hex_grid)
	for q in range(-1, 10):
		for r in range(-2, 3):
			hex_grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	_notices.clear()
	EventBus.notify.connect(_on_notify)

func after_each():
	EventBus.notify.disconnect(_on_notify)
	GameManager.human_player = _original_human_player
	human.release_relations()
	rival.release_relations()

func _on_notify(text: String, _sfx: String) -> void:
	_notices.append(text)

func _unit(kind: String, owner: PlayerData, coord: Vector2i) -> Unit:
	return hex_grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner)

func _interruptions() -> Array[String]:
	return _notices.filter(func(text: String) -> bool: return text.contains("interrompeu"))

# --- Contato com inimigo ------------------------------------------------------------------------------------------------

func test_the_march_stops_when_a_step_brings_a_new_enemy_into_reach_and_keeps_the_order():
	var warrior := _unit("warrior", human, Vector2i(0, 0)) # 2 de movimento
	hex_grid.spawn_monster_at(Vector2i(2, -1), "goblin") # vizinho de (1,0), a 2 tiles de (0,0)
	warrior.move_order_target = Vector2i(6, 0)

	hex_grid.continue_move_order(warrior)

	assert_eq(warrior.coord, Vector2i(1, 0), "para no passo que encostou no goblin, em vez de seguir andando")
	assert_eq(warrior.movement_left, 1.0, "com o movimento que sobrou: dá para atacar agora mesmo")
	assert_eq(warrior.move_order_target, Vector2i(6, 0), "a ordem continua pendente (não é cancelada)")
	assert_eq(_interruptions().size(), 1, "o jogador é avisado uma vez")
	assert_true(_interruptions()[0].contains("a marcha"))

func test_an_enemy_already_in_reach_never_traps_the_march():
	var warrior := _unit("warrior", human, Vector2i(0, 0))
	hex_grid.spawn_monster_at(Vector2i(2, -1), "goblin")
	warrior.move_order_target = Vector2i(6, 0)
	hex_grid.continue_move_order(warrior) # contato novo: parou em (1,0)
	_notices.clear()

	# O jogador viu o goblin e não fez nada: no fim do turno a marcha segue (o contato não é mais novo).
	hex_grid.continue_move_order(warrior)
	assert_eq(warrior.coord, Vector2i(2, 0), "anda o movimento que sobrou")
	warrior.reset_movement()
	hex_grid.continue_move_order(warrior)
	assert_eq(warrior.coord, Vector2i(4, 0), "e continua no turno seguinte, afastando-se do goblin")
	assert_eq(_interruptions().size(), 0, "nenhum aviso repetido")

func test_only_enemies_interrupt_a_rival_at_peace_does_not_and_one_at_war_does():
	var warrior := _unit("warrior", human, Vector2i(0, 0))
	_unit("warrior", rival, Vector2i(2, -1))
	warrior.move_order_target = Vector2i(6, 0)

	hex_grid.continue_move_order(warrior)
	assert_eq(warrior.coord, Vector2i(2, 0), "em paz: passa ao lado sem parar")
	assert_eq(_interruptions().size(), 0)

	var second := _unit("warrior", human, Vector2i(0, 2))
	_unit("warrior", rival, Vector2i(2, 1)) # vizinho de (1,2)
	Diplomacy.declare_war(human, rival)
	second.move_order_target = Vector2i(6, 2)
	hex_grid.continue_move_order(second)
	assert_eq(second.coord, Vector2i(1, 2), "em guerra: para ao encostar")
	assert_eq(_interruptions().size(), 1)

func test_a_ranged_unit_stops_as_soon_as_the_enemy_enters_its_attack_range():
	var archer := _unit("warrior", human, Vector2i(0, 0))
	archer.unit_data.attack_range = 2
	hex_grid.spawn_monster_at(Vector2i(3, -1), "goblin") # a 2 tiles de (1,0), a 3 de (0,0)
	archer.move_order_target = Vector2i(6, 0)

	hex_grid.continue_move_order(archer)

	assert_eq(archer.coord, Vector2i(1, 0), "para onde já consegue atirar, sem encostar")
	assert_eq(archer.move_order_target, Vector2i(6, 0))

func test_arriving_next_to_an_enemy_finishes_the_order_without_an_interruption_notice():
	var warrior := _unit("warrior", human, Vector2i(0, 0))
	hex_grid.spawn_monster_at(Vector2i(2, -1), "goblin")
	warrior.move_order_target = Vector2i(1, 0)

	hex_grid.continue_move_order(warrior)

	assert_eq(warrior.coord, Vector2i(1, 0))
	assert_eq(warrior.move_order_target, Unit.NO_MOVE_ORDER, "chegou: a ordem acaba")
	assert_eq(_interruptions().size(), 0, "chegar ao destino não é interrupção")

func test_exploring_stops_on_new_contact_and_stays_on():
	for coord in hex_grid.tiles.keys(): # só a faixa r = 0 à frente continua inexplorada
		if coord.y != 0 or coord.x <= 0:
			hex_grid.visibility[coord] = HexGrid.Visibility.VISIBLE
	var scout := _unit("warrior", human, Vector2i(0, 0))
	hex_grid.spawn_monster_at(Vector2i(2, -1), "goblin")
	scout.exploring = true

	hex_grid.explore_step(scout)

	assert_eq(scout.coord, Vector2i(1, 0))
	assert_true(scout.exploring, "o modo Explorar continua ligado")
	assert_eq(_interruptions().size(), 1)
	assert_true(_interruptions()[0].contains("a exploração"))

func test_another_players_interruption_is_not_announced_to_the_human():
	var other := _unit("warrior", rival, Vector2i(0, 0))
	hex_grid.spawn_monster_at(Vector2i(2, -1), "goblin")
	other.move_order_target = Vector2i(6, 0)

	hex_grid.continue_move_order(other)

	assert_eq(other.coord, Vector2i(1, 0), "a regra vale para qualquer dono")
	assert_eq(_interruptions().size(), 0, "mas o aviso é só do jogador humano")
