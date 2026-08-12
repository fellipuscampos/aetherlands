extends GutTest

## Cobre os 3 comportamentos de monstro neutro (MonsterAI.gd): Guardiao
## (fica no territorio do proprio covil, so briga com quem invade),
## Invasor (marcha sobre a cidade inimiga mais proxima, briga so com quem
## encontra no caminho, NUNCA saqueia) e Cacador (patrulha atras de presa
## isolada/fraca, so ataca se favoravel). Harness espelha test_rival_ai.gd,
## mas troca TAMBEM GameManager.players (MonsterAI mira em todo mundo, nao
## so num par player/opponent especifico como RivalAI).

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_players: Array[PlayerData]

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_players = GameManager.players
	_created_units = []

	hex_grid = _build_flat_grid(10)

	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.hex_grid = hex_grid
	GameManager.human_player = human
	GameManager.players = [human, rival]

func after_each():
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	GameManager.players = _original_players
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()

## Bloco solido de GRASSLAND (todo coord dentro de `radius` do centro) —
## garante vizinhanca hexagonal completa (sem furo nas bordas), diferente
## de um mapa gerado, que tem oceano/bioma variado — precisamos de
## controle preciso de distancia/movimento pra estas asserções.
func _build_flat_grid(radius: int) -> HexGrid:
	var grid := HexGrid.new()
	grid._ready()
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var coord = Vector2i(q, r)
			if HexMetrics.axial_distance(coord, Vector2i.ZERO) <= radius:
				grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	return grid

func _make_monster(kind: String, coord: Vector2i, camp_boss: bool = false) -> Unit:
	return hex_grid.spawn_monster_at(coord, kind, camp_boss)

func _make_unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

# ---------------------------------------------------------------------------
# Guardiao
# ---------------------------------------------------------------------------

func test_guardian_stays_put_with_no_enemy_nearby():
	var guardian = _make_monster("goblin", Vector2i.ZERO)
	guardian.reset_movement()
	MonsterAI.take_turn(hex_grid)
	assert_eq(guardian.coord, Vector2i.ZERO, "guardiao sem inimigo por perto nao deveria se mover")

func test_guardian_never_detects_enemy_beyond_guard_radius():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var guardian = _make_monster("goblin", Vector2i.ZERO)
	guardian.reset_movement()
	_make_unit("warrior", human, Vector2i(5, 0)) # bem alem do GUARD_RADIUS (2)
	MonsterAI.take_turn(hex_grid)
	assert_eq(guardian.coord, Vector2i.ZERO, "inimigo fora do raio de guarda nao deveria ser detectado")

func test_guardian_attacks_enemy_within_attack_range():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	_make_monster("goblin", Vector2i.ZERO)
	var enemy = _make_unit("warrior", human, Vector2i(1, 0))
	var hp_before = enemy.hp
	MonsterAI.take_turn(hex_grid)
	assert_lt(enemy.hp, hp_before, "guardiao deveria atacar incondicionalmente um inimigo adjacente")

## Regressao critica: Guardiao persegue alvo dentro do proprio raio de
## guarda mas NUNCA sai dele (territorio ancorado no covil, nao na posicao
## atual do monstro).
func test_guardian_moves_toward_enemy_within_guard_radius_but_never_leaves_it():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var guardian = _make_monster("goblin", Vector2i.ZERO)
	guardian.reset_movement()
	_make_unit("warrior", human, Vector2i(2, 0)) # dentro do GUARD_RADIUS (2), fora do alcance de ataque (1)

	MonsterAI.take_turn(hex_grid)

	assert_ne(guardian.coord, Vector2i.ZERO, "guardiao deveria ter se movido em direcao ao inimigo")
	assert_lte(
		HexMetrics.axial_distance(Vector2i.ZERO, guardian.coord), MonsterAI.GUARD_RADIUS,
		"guardiao nunca deveria sair do proprio raio de guarda perseguindo um alvo"
	)

# ---------------------------------------------------------------------------
# Invasor
# ---------------------------------------------------------------------------

func test_invader_marches_toward_the_nearer_of_two_cities():
	var near_city = hex_grid.found_city(Vector2i(3, 0), human, "Cidade Perto")
	hex_grid.found_city(Vector2i(-8, 0), rival, "Cidade Longe")
	var invader = _make_monster("skeleton", Vector2i.ZERO) # skeleton = BEHAVIOR_INVADER por padrao
	invader.reset_movement()

	MonsterAI.take_turn(hex_grid)

	assert_gt(invader.coord.x, 0, "invasor deveria ter andado em direcao a cidade mais proxima (x positivo), nao a mais distante")
	assert_lt(
		HexMetrics.axial_distance(invader.coord, near_city.coord),
		HexMetrics.axial_distance(Vector2i.ZERO, near_city.coord),
		"invasor deveria ter se aproximado da cidade mais proxima"
	)

func test_invader_attacks_enemy_encountered_along_the_way():
	var enemy = _make_unit("warrior", human, Vector2i(1, 0))
	var invader = _make_monster("skeleton", Vector2i.ZERO)
	var hp_before = enemy.hp
	MonsterAI.take_turn(hex_grid)
	assert_lt(enemy.hp, hp_before, "invasor deveria atacar incondicionalmente quem encontra no caminho")

## Regressao critica (decisao aprovada com o usuario: invasor NAO saqueia
## nesta rodada): mesmo depois de varios turnos alcancando uma cidade
## indefesa, o invasor nunca deveria capturar-la nem conseguir pisar nela —
## compute_reachable ja bloqueia todo tile de cidade pra owner=null, e
## MonsterAI nunca chama hex_grid.capture_city.
func test_invader_reaching_an_undefended_city_never_captures_it():
	var city = hex_grid.found_city(Vector2i(2, 0), human, "Cidade Indefesa")
	var invader = _make_monster("skeleton", Vector2i.ZERO)

	for i in range(10):
		invader.reset_movement()
		MonsterAI.take_turn(hex_grid)

	assert_eq(city.owner_player, human, "cidade indefesa nunca deveria mudar de dono pra um monstro invasor")
	assert_null(hex_grid.get_unit_at(city.coord), "monstro invasor nunca deveria conseguir pisar no tile da cidade")

## Saque de Invasor (pedido do usuario: "Invasor que termina o turno num
## tile trabalhado por cidade saqueia a melhoria e tira ouro do dono") —
## nao confunde com o teste acima: a CIDADE em si continua inconquistavel/
## impisavel, so os tiles TRABALHADOS ao redor dela sao alvo de saque.
## movement_left forcado a 0 garante que o Invasor NAO se mova pra fora do
## tile trabalhado neste turno (sem hostil por perto pra brigar,
## MonsterAI._take_invader_turn tentaria marchar sobre a cidade).
func test_invader_ending_turn_on_worked_tile_pillages_it():
	var city = hex_grid.found_city(Vector2i(3, 0), human, "Capital")
	var worked_coord: Vector2i = city.worked_tiles[0]
	human.gold = 100.0

	var invader = _make_monster("skeleton", worked_coord) # Esqueleto = Invasor por padrao
	invader.movement_left = 0.0

	MonsterAI.take_turn(hex_grid, 10)

	assert_true(hex_grid.is_tile_pillaged(worked_coord, 10), "tile trabalhado deveria ficar marcado como pilhado")
	assert_eq(human.gold, 100.0 - MonsterAI.PILLAGE_GOLD_LOSS, "dono da cidade deveria perder o ouro do saque")

## Regressao: um tile ja pilhado nao deveria perder ouro DE NOVO todo turno
## que o Invasor continua parado nele — so quando a pilhagem anterior ja
## expirou (ver HexGrid.is_tile_pillaged/pillage_tile).
func test_invader_does_not_repillage_an_already_pillaged_tile():
	var city = hex_grid.found_city(Vector2i(3, 0), human, "Capital")
	var worked_coord: Vector2i = city.worked_tiles[0]
	human.gold = 100.0
	hex_grid.pillage_tile(worked_coord, 10, MonsterAI.PILLAGE_DURATION_TURNS)

	var invader = _make_monster("skeleton", worked_coord)
	invader.movement_left = 0.0

	MonsterAI.take_turn(hex_grid, 11)

	assert_eq(human.gold, 100.0, "tile ja pilhado nao deveria descontar ouro de novo enquanto a pilhagem anterior nao expirar")

## Regra de fantasia: 2+ Goblins OCIOSOS no mesmo covil sao promovidos a
## Invasor de uma vez; a promocao e permanente (nao volta a Guardiao depois).
func test_goblin_group_is_promoted_to_invader_at_threshold_and_stays_promoted():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var solo = _make_monster("goblin", Vector2i.ZERO)
	assert_eq(solo.monster_behavior_state, "", "precondicao: comportamento default (ocioso) antes de qualquer turno")

	MonsterAI.take_turn(hex_grid)
	assert_eq(solo.monster_behavior_state, "", "1 goblin sozinho (abaixo do limiar) nao deveria ser promovido")

	var second = _make_monster("goblin", hex_grid.get_neighbors(Vector2i.ZERO)[0])
	MonsterAI.take_turn(hex_grid)
	assert_eq(solo.monster_behavior_state, "invader", "grupo de 2+ goblins ociosos deveria ser promovido a Invasor")
	assert_eq(second.monster_behavior_state, "invader")

	MonsterAI.take_turn(hex_grid)
	assert_eq(solo.monster_behavior_state, "invader", "promocao a Invasor deveria ser permanente")

func test_camp_boss_is_never_promoted_to_invader():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var boss = _make_monster("goblin", Vector2i.ZERO, true)
	_make_monster("goblin", hex_grid.get_neighbors(Vector2i.ZERO)[0])
	_make_monster("goblin", hex_grid.get_neighbors(Vector2i.ZERO)[1])

	MonsterAI.take_turn(hex_grid)

	assert_eq(boss.monster_behavior_state, "", "o boss original do covil nunca deveria ser promovido a Invasor")

# ---------------------------------------------------------------------------
# Cacador
# ---------------------------------------------------------------------------

func test_hunter_attacks_isolated_prey_in_range():
	_make_monster("wyvern", Vector2i.ZERO)
	var prey = _make_unit("warrior", human, Vector2i(1, 0)) # adjacente, sem aliado por perto
	var hp_before = prey.hp
	MonsterAI.take_turn(hex_grid)
	assert_lt(prey.hp, hp_before, "cacador deveria atacar presa isolada ao alcance")

func test_hunter_does_not_attack_escorted_full_hp_prey():
	var hunter = _make_monster("wyvern", Vector2i.ZERO)
	var prey = _make_unit("warrior", human, Vector2i(1, 0))
	_make_unit("warrior", human, Vector2i(1, -1)) # aliado dentro do HUNTER_ISOLATION_RADIUS
	var hp_before = prey.hp

	MonsterAI.take_turn(hex_grid)

	assert_eq(prey.hp, hp_before, "cacador nao deveria atacar presa escoltada e saudavel")
	assert_eq(hunter.coord, Vector2i.ZERO, "sem presa elegivel, cacador nao deveria se mover")

func test_hunter_attacks_weak_prey_even_if_escorted():
	_make_monster("wyvern", Vector2i.ZERO)
	var prey = _make_unit("warrior", human, Vector2i(1, 0))
	prey.hp = prey.unit_data.max_hp * 0.2 # bem abaixo de HUNTER_WEAK_HP_FRACTION
	_make_unit("warrior", human, Vector2i(1, -1)) # escoltado, mas fraco o bastante pra ainda ser presa
	var hp_before = prey.hp

	MonsterAI.take_turn(hex_grid)

	assert_lt(prey.hp, hp_before, "presa fraca deveria ser atacada mesmo escoltada")
