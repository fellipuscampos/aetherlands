extends GutTest

## Cobre os 4 comportamentos de monstro neutro (MonsterAI.gd): Guardiao
## (fica no territorio do proprio covil, so briga com quem invade OU reage
## a cidade que se aproxima), Saqueador (Goblin por padrao -- busca
## ativamente presa fraca/isolada e se aproxima de cidade dentro de um
## raio maior que o Guardiao, mas ainda preso ao proprio covil), Invasor
## (marcha sobre a cidade inimiga mais proxima, briga so com quem encontra
## no caminho, NUNCA saqueia a cidade em si) e Cacador (patrulha atras de
## presa isolada/fraca, so ataca se favoravel). Harness espelha
## test_rival_ai.gd, mas troca TAMBEM GameManager.players (MonsterAI mira
## em todo mundo, nao so num par player/opponent especifico como RivalAI).
##
## COMPORTAMENTO DOS MONSTROS (rodada seguinte): Goblin default MUDOU de
## Guardiao pra Saqueador -- os testes de Guardiao abaixo que usam kind
## "goblin" forcam `monster_behavior_state = BEHAVIOR_GUARDIAN`
## explicitamente pra continuar testando Guardiao de verdade (raio
## generico GUARD_RADIUS=2, sem override -- goblin nao tem "guard_radius"
## proprio em KIND_DATA), preservando as distancias/asserções originais
## sem mudanca nenhuma. Troll (agora com guard_radius=5) tem sua propria
## secao de testes mais abaixo.

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _original_hex_grid: HexGrid
var _original_human_player: PlayerData
var _original_players: Array[PlayerData]
var _original_world_events: Array[WorldEvent]

func before_each():
	_original_hex_grid = GameManager.hex_grid
	_original_human_player = GameManager.human_player
	_original_players = GameManager.players
	_original_world_events = WorldEventManager.active_events
	WorldEventManager.active_events = []
	_created_units = []

	hex_grid = _build_flat_grid(10)

	human = PlayerData.new(CivilizationData.new())
	rival = PlayerData.new(CivilizationData.new())
	GameManager.hex_grid = hex_grid
	GameManager.human_player = human
	GameManager.players = [human, rival]

func after_each():
	hex_grid.queue_free()
	GameManager.hex_grid = _original_hex_grid
	GameManager.human_player = _original_human_player
	GameManager.players = _original_players
	WorldEventManager.active_events = _original_world_events
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
	guardian.monster_behavior_state = MonsterDatabase.BEHAVIOR_GUARDIAN
	guardian.reset_movement()
	_make_unit("warrior", human, Vector2i(5, 0)) # bem alem do GUARD_RADIUS (2)
	MonsterAI.take_turn(hex_grid)
	assert_eq(guardian.coord, Vector2i.ZERO, "inimigo fora do raio de guarda nao deveria ser detectado")

func test_guardian_attacks_enemy_within_attack_range():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var guardian = _make_monster("goblin", Vector2i.ZERO)
	guardian.monster_behavior_state = MonsterDatabase.BEHAVIOR_GUARDIAN
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
	guardian.monster_behavior_state = MonsterDatabase.BEHAVIOR_GUARDIAN
	guardian.reset_movement()
	_make_unit("warrior", human, Vector2i(2, 0)) # dentro do GUARD_RADIUS (2), fora do alcance de ataque (1)

	MonsterAI.take_turn(hex_grid)

	assert_ne(guardian.coord, Vector2i.ZERO, "guardiao deveria ter se movido em direcao ao inimigo")

## MonsterAI.begin_turn()/act_for_unit() sao a MESMA logica de take_turn(),
## so separada em duas partes pra GameManager poder espalhar por frames (ver
## GameManager.stagger_ai_turns) — confirma que a dupla continua produzindo
## o mesmo resultado de antes.
func test_begin_turn_and_act_for_unit_together_match_take_turn_behavior():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var guardian = _make_monster("goblin", Vector2i.ZERO)
	guardian.monster_behavior_state = MonsterDatabase.BEHAVIOR_GUARDIAN
	guardian.reset_movement()
	_make_unit("warrior", human, Vector2i(2, 0))

	MonsterAI.begin_turn(hex_grid)
	MonsterAI.act_for_unit(guardian, hex_grid, 0)

	assert_ne(guardian.coord, Vector2i.ZERO, "guardiao deveria ter se movido em direcao ao inimigo")
	assert_lte(
		HexMetrics.axial_distance(Vector2i.ZERO, guardian.coord), MonsterAI.GUARD_RADIUS,
		"guardiao nunca deveria sair do proprio raio de guarda perseguindo um alvo"
	)

## COMPORTAMENTO DOS MONSTROS (pedido do usuario: "trolls podem defender
## uma regiao maior... nao precisam atravessar meio continente"): Troll
## usa KIND_DATA.guard_radius=5 em vez do GUARD_RADIUS generico (2) --
## confirma que ele detecta (e persegue) um inimigo bem alem do raio
## generico, mas ainda dentro do proprio raio maior.
func test_troll_guardian_uses_a_wider_radius_than_the_generic_default():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "troll"
	var troll = _make_monster("troll", Vector2i.ZERO)
	troll.reset_movement()
	_make_unit("warrior", human, Vector2i(4, 0)) # alem do GUARD_RADIUS generico (2), dentro do raio proprio do Troll (5)

	MonsterAI.take_turn(hex_grid)

	assert_ne(troll.coord, Vector2i.ZERO, "troll deveria detectar e se mover em direcao a um inimigo dentro do proprio raio maior")

## Pedido do usuario: "se uma cidade... estiver suficientemente proximo ao
## covil, podem reagir agressivamente" -- Guardiao (Troll, raio 5) reage a
## uma cidade inimiga se aproximando do territorio, nao so' unidade.
func test_troll_guardian_reacts_to_a_nearby_enemy_city_not_just_units():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "troll"
	var troll = _make_monster("troll", Vector2i.ZERO)
	troll.reset_movement()
	hex_grid.found_city(Vector2i(4, 0), human, "Cidade Vizinha") # dentro do raio do Troll (5), sem unidade nenhuma por perto

	MonsterAI.take_turn(hex_grid)

	assert_ne(troll.coord, Vector2i.ZERO, "troll deveria se mover em direcao a cidade inimiga que se aproximou do territorio")

func test_troll_guardian_still_ignores_threats_beyond_its_own_radius():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "troll"
	var troll = _make_monster("troll", Vector2i.ZERO)
	troll.reset_movement()
	_make_unit("warrior", human, Vector2i(6, 0)) # alem do proprio raio do Troll (5)

	MonsterAI.take_turn(hex_grid)

	assert_eq(troll.coord, Vector2i.ZERO, "troll nao deveria detectar nada alem do proprio raio, mesmo sendo maior que o generico")

## AGGRO/TERRITORIO (pedido do usuario: "melhorias aparecem proximas" e'
## um dos gatilhos de reacao) -- predio conta igual cidade, nao so' unidade.
func test_troll_guardian_reacts_to_a_nearby_enemy_building_not_just_city():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "troll"
	var troll = _make_monster("troll", Vector2i.ZERO)
	troll.reset_movement()
	hex_grid.place_building(Vector2i(4, 0), "granary", human) # dentro do raio do Troll (5), sem cidade/unidade nenhuma por perto

	MonsterAI.take_turn(hex_grid)

	assert_ne(troll.coord, Vector2i.ZERO, "troll deveria se mover em direcao ao predio inimigo que se aproximou do territorio")

# ---------------------------------------------------------------------------
# Saqueador (Goblin por padrao) -- COMPORTAMENTO DOS MONSTROS: "goblins
# podem ser agressivos e oportunistas: saquear; atacar unidades fracas;
# ameacar melhorias; aproximar-se de cidades proximas", sempre preso ao
# proprio territorio (RAIDER_RADIUS), nunca atravessando o mapa como
# Invasor sozinho.
# ---------------------------------------------------------------------------

func test_raider_moves_toward_isolated_prey_beyond_the_generic_guard_radius():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var raider = _make_monster("goblin", Vector2i.ZERO) # default: Saqueador, sem override
	raider.reset_movement()
	_make_unit("warrior", human, Vector2i(3, 0)) # alem do GUARD_RADIUS generico (2), dentro do RAIDER_RADIUS (4)

	MonsterAI.take_turn(hex_grid)

	assert_ne(raider.coord, Vector2i.ZERO, "saqueador deveria buscar ativamente presa isolada bem alem do raio de um Guardiao comum")

func test_raider_never_leaves_its_own_territory_chasing_prey():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var raider = _make_monster("goblin", Vector2i.ZERO)
	raider.reset_movement()
	_make_unit("warrior", human, Vector2i(6, 0)) # bem alem do RAIDER_RADIUS (4)

	MonsterAI.take_turn(hex_grid)

	assert_eq(raider.coord, Vector2i.ZERO, "saqueador nunca deveria sair do proprio territorio atras de uma presa distante")

## "Atacar unidades fracas" nao e' incondicional feito o Guardiao -- reusa
## o mesmo criterio de presa valida do Cacador (_is_isolated_or_weak):
## unidade escoltada e saudavel NAO conta como alvo.
func test_raider_does_not_attack_an_escorted_full_hp_unit():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var raider = _make_monster("goblin", Vector2i.ZERO)
	var prey = _make_unit("warrior", human, Vector2i(1, 0))
	_make_unit("warrior", human, Vector2i(1, -1)) # aliado dentro do HUNTER_ISOLATION_RADIUS
	var hp_before = prey.hp

	MonsterAI.take_turn(hex_grid)

	assert_eq(prey.hp, hp_before, "saqueador oportunista nao deveria atacar uma unidade escoltada e saudavel")

func test_raider_attacks_weak_prey_even_if_escorted():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	_make_monster("goblin", Vector2i.ZERO)
	var prey = _make_unit("warrior", human, Vector2i(1, 0))
	prey.hp = prey.unit_data.max_hp * 0.2 # bem abaixo de HUNTER_WEAK_HP_FRACTION
	_make_unit("warrior", human, Vector2i(1, -1)) # escoltado, mas fraco o bastante pra ainda ser presa
	var hp_before = prey.hp

	MonsterAI.take_turn(hex_grid)

	assert_lt(prey.hp, hp_before, "saqueador deveria atacar presa fraca mesmo escoltada")

## "Ameacar melhorias" -- Saqueador tambem saqueia tile trabalhado, mesma
## mecanica do Invasor (_maybe_pillage_tile), mesmo sem nenhum inimigo
## por perto pra brigar.
func test_raider_pillages_a_worked_tile_like_an_invader():
	var city = hex_grid.found_city(Vector2i(3, 0), human, "Capital")
	var worked_coord: Vector2i = city.worked_tiles[0]
	human.gold = 100.0

	var raider = _make_monster("goblin", worked_coord)
	raider.movement_left = 0.0 # nao sai do tile trabalhado neste turno

	MonsterAI.take_turn(hex_grid, 10)

	assert_true(hex_grid.is_tile_pillaged(worked_coord, 10), "saqueador deveria saquear o tile trabalhado onde termina o turno")
	assert_eq(human.gold, 100.0 - MonsterAI.PILLAGE_GOLD_LOSS, "dono da cidade deveria perder o ouro do saque")

## Sem inimigo a vista, o Saqueador se aproxima de uma cidade DENTRO do
## proprio raio (ameaca de presenca), nunca de uma fora dele.
func test_raider_approaches_a_nearby_city_when_no_prey_is_available():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var raider = _make_monster("goblin", Vector2i.ZERO)
	raider.reset_movement()
	hex_grid.found_city(Vector2i(3, 0), human, "Cidade Proxima") # dentro do RAIDER_RADIUS (4)

	MonsterAI.take_turn(hex_grid)

	assert_ne(raider.coord, Vector2i.ZERO, "saqueador deveria se aproximar de uma cidade dentro do proprio raio, mesmo sem unidade nenhuma por perto")

## AGGRO/TERRITORIO: mesma logica, agora com predio no lugar de cidade.
func test_raider_approaches_a_nearby_building_when_no_prey_or_city_is_available():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var raider = _make_monster("goblin", Vector2i.ZERO)
	raider.reset_movement()
	hex_grid.place_building(Vector2i(3, 0), "granary", human) # dentro do RAIDER_RADIUS (4)

	MonsterAI.take_turn(hex_grid)

	assert_ne(raider.coord, Vector2i.ZERO, "saqueador deveria se aproximar de um predio inimigo dentro do proprio raio")

# ---------------------------------------------------------------------------
# Aggro / Territorio de Ameaca -- pedido do usuario: "o jogador ataca
# membros do covil" precisa ser um dos gatilhos de reacao. Um ataque bem
# sucedido contra QUALQUER morador do covil alerta o TERRITORIO inteiro
# (nao so' quem apanhou), ampliando temporariamente o raio de deteccao de
# Guardiao/Saqueador (ver HexGrid.alert_lair_near/MonsterAI.ALERT_RADIUS_
# BONUS).
# ---------------------------------------------------------------------------

func test_alerted_lair_temporarily_detects_threats_beyond_its_normal_radius():
	var original_turn = TurnManager.turn_number
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "troll"
	var victim_coord: Vector2i = HexGrid.NEIGHBOR_DIRS[0]
	var guardian_coord: Vector2i = HexGrid.NEIGHBOR_DIRS[3]
	var victim = _make_monster("troll", victim_coord)
	var guardian = _make_monster("troll", guardian_coord)
	guardian.reset_movement()
	_make_unit("warrior", human, Vector2i(6, 0)) # alem do guard_radius do Troll (5), dentro do raio alertado (5+3=8)

	TurnManager.turn_number = 1
	MonsterAI.take_turn(hex_grid, 1)
	assert_eq(guardian.coord, guardian_coord, "precondicao: sem alerta, inimigo alem do raio normal do Troll nao deveria ser detectado")

	var attacker_coord: Vector2i = victim_coord + HexGrid.NEIGHBOR_DIRS[0]
	var attacker = _make_unit("warrior", rival, attacker_coord)
	CombatResolver.resolve(attacker, victim, hex_grid) # ataca UM morador do covil (nao o guardian sendo testado)

	guardian.reset_movement()
	MonsterAI.take_turn(hex_grid, 2)

	assert_ne(guardian.coord, guardian_coord, "covil alertado (por outro membro ter apanhado) deveria detectar e se mover ate o inimigo, mesmo alem do raio normal")

	TurnManager.turn_number = original_turn

func test_lair_alert_expires_after_its_duration():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "troll"

	hex_grid.alert_lair_near(Vector2i.ZERO, 1)

	assert_true(hex_grid.is_lair_alerted(Vector2i.ZERO, 5), "alerta deveria continuar ativo bem antes de expirar")
	assert_false(hex_grid.is_lair_alerted(Vector2i.ZERO, 1 + HexGrid.LAIR_ALERT_DURATION_TURNS), "alerta deveria ter expirado exatamente na duracao configurada")
	assert_false(hex_grid.is_lair_alerted(Vector2i.ZERO, 1 + HexGrid.LAIR_ALERT_DURATION_TURNS + 10), "alerta deveria continuar expirado bem depois da duracao")

func test_attacking_a_monster_with_no_lair_does_not_error():
	var lone_monster = hex_grid.spawn_monster_at(Vector2i.ZERO, "goblin") # sem hex_grid.lair_coords nenhum registrado
	var attacker = _make_unit("warrior", human, Vector2i(1, 0))

	CombatResolver.resolve(attacker, lone_monster, hex_grid) # nao deveria travar/crashar sem covil pra alertar

	assert_true(true, "atacar um monstro sem covil associado nao deveria causar erro nenhum")

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

# ---------------------------------------------------------------------------
# Recolhido durante o Dragon World Event (pedido explicito do usuario):
# "os monstros do mapa param de atacar durante o evento do dragao, e voltam
# pra ficar ao redor dos seus covis... so voltam a agir normalmente quando
# acabar o evento". Cobre os 3 comportamentos (Guardiao/Invasor/Cacador) --
# todos ficam identicos (recolhidos) enquanto o evento existir.
# ---------------------------------------------------------------------------

func _register_active_dragon_event() -> DragonEvent:
	var event := DragonEvent.new()
	WorldEventManager.active_events.append(event)
	return event

func test_guardian_does_not_attack_an_adjacent_enemy_while_a_dragon_event_is_active():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	_make_monster("goblin", Vector2i.ZERO)
	var enemy = _make_unit("warrior", human, Vector2i(1, 0))
	var hp_before = enemy.hp
	_register_active_dragon_event()

	MonsterAI.take_turn(hex_grid)

	assert_eq(enemy.hp, hp_before, "guardiao nao deveria atacar ninguem enquanto o evento do Dragao estiver ativo")

func test_invader_does_not_march_or_pillage_while_a_dragon_event_is_active():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "skeleton"
	var invader = _make_monster("skeleton", Vector2i.ZERO) # skeleton = Invasor por padrao
	var city = hex_grid.found_city(Vector2i(3, 0), human, "Capital")
	_register_active_dragon_event()

	MonsterAI.take_turn(hex_grid)

	assert_eq(invader.coord, Vector2i.ZERO, "invasor recolhido ja esta no proprio covil -- nao deveria marchar em direcao a cidade nenhuma")
	city.queue_free()

func test_hunter_does_not_attack_isolated_prey_while_a_dragon_event_is_active():
	_make_monster("wyvern", Vector2i.ZERO)
	var prey = _make_unit("warrior", human, Vector2i(1, 0)) # adjacente, isolada -- normalmente seria atacada
	var hp_before = prey.hp
	_register_active_dragon_event()

	MonsterAI.take_turn(hex_grid)

	assert_eq(prey.hp, hp_before, "cacador recolhido nao deveria atacar presa nenhuma enquanto o evento do Dragao estiver ativo")

## Integracao real: um monstro que ja estava LONGE do proprio covil (ex.:
## Cacador no meio de uma patrulha) precisa efetivamente ANDAR de volta,
## nao so' ficar parado onde esta.
func test_monster_far_from_its_lair_moves_back_toward_it_while_a_dragon_event_is_active():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "wyvern"
	var hunter = _make_monster("wyvern", Vector2i(5, 0)) # bem longe do covil em (0,0)
	hunter.reset_movement()
	_register_active_dragon_event()

	MonsterAI.take_turn(hex_grid)

	var distance_after: float = HexMetrics.axial_distance(hunter.coord, Vector2i.ZERO)
	assert_lt(distance_after, 5.0, "monstro recolhido deveria ter avancado de volta em direcao ao proprio covil")

func test_monster_already_at_its_lair_stays_put_while_a_dragon_event_is_active():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var guardian = _make_monster("goblin", Vector2i.ZERO)
	guardian.reset_movement()
	_register_active_dragon_event()

	MonsterAI.take_turn(hex_grid)

	assert_eq(guardian.coord, Vector2i.ZERO, "monstro ja no proprio covil deveria continuar parado, nao vagar a toa")

## O requisito mais importante: assim que o evento acaba (removido de
## WorldEventManager.active_events, exatamente o que WorldEventManager.
## advance_turn ja faz sozinho quando is_completed()), o comportamento
## normal precisa voltar sem nenhuma flag/estado extra pra limpar --
## _is_dragon_event_active() e' inteiramente derivado da lista atual.
func test_normal_behavior_resumes_once_the_dragon_event_is_no_longer_active():
	hex_grid.lair_coords = [Vector2i.ZERO]
	hex_grid.lair_kind_by_coord[Vector2i.ZERO] = "goblin"
	var guardian = _make_monster("goblin", Vector2i.ZERO)
	guardian.monster_behavior_state = MonsterDatabase.BEHAVIOR_GUARDIAN
	var enemy = _make_unit("warrior", human, Vector2i(1, 0))
	var event := _register_active_dragon_event()
	MonsterAI.take_turn(hex_grid)
	assert_eq(enemy.hp, enemy.unit_data.max_hp, "pre-condicao: nao atacou enquanto o evento estava ativo")

	WorldEventManager.active_events.erase(event) # evento terminou (Completed)
	var hp_before = enemy.hp

	MonsterAI.take_turn(hex_grid)

	assert_lt(enemy.hp, hp_before, "com o evento terminado, o guardiao deveria voltar a atacar normalmente")
