extends GutTest

var hex_grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _created_units: Array[Unit] = []
var _original_human_player: PlayerData

func before_each():
	_original_human_player = GameManager.human_player
	_created_units = []

	hex_grid = HexGrid.new()
	# HexGrid so cria _cities_root/_tints_root (entre outros) em _ready(),
	# que o motor so chama quando o node entra na scene tree — precisa
	# disso pros testes de resolve_city_attack abaixo, que exercitam
	# hex_grid.found_city()/capture_city() de verdade (mesmo padrao ja
	# usado em test_hex_grid_movement.gd).
	hex_grid._ready()
	hex_grid.tiles[Vector2i(0, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	hex_grid.tiles[Vector2i(1, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[Vector2i(2, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	human = PlayerData.new(CivilizationData.new())
	GameManager.human_player = human
	rival = PlayerData.new(CivilizationData.new())

func after_each():
	GameManager.human_player = _original_human_player
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	hex_grid.queue_free()

func _make_unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

func test_melee_attack_damages_defender():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var defender = _make_unit("warrior", rival, Vector2i(1, 0))
	var hp_before = defender.hp

	CombatResolver.resolve(attacker, defender, hex_grid)

	assert_lt(defender.hp, hp_before, "defensor deveria ter tomado dano")

func test_attacker_loses_all_movement_after_attacking():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var defender = _make_unit("warrior", rival, Vector2i(1, 0))
	attacker.movement_left = 2.0

	CombatResolver.resolve(attacker, defender, hex_grid)

	assert_eq(attacker.movement_left, 0.0)

func test_lethal_damage_removes_defender_from_grid_and_owner():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var defender = _make_unit("warrior", rival, Vector2i(1, 0))
	defender.hp = 0.5 # qualquer dano mata

	CombatResolver.resolve(attacker, defender, hex_grid)

	assert_null(hex_grid.get_unit_at(Vector2i(1, 0)), "defensor morto devia sumir do grid")
	assert_false(rival.units.has(defender), "defensor morto devia sair da lista do dono")

## Regressao: arqueiro (attack_range=2) atacando de fora do alcance
## corpo-a-corpo do alvo nao deveria sofrer dano de volta — o defensor
## simplesmente nao alcança quem atirou nele.
func test_ranged_attack_outside_melee_range_has_no_counter_damage():
	var attacker = _make_unit("archer", human, Vector2i(0, 0))
	var defender = _make_unit("warrior", rival, Vector2i(2, 0))
	defender.hp = defender.unit_data.max_hp
	var attacker_hp_before = attacker.hp

	CombatResolver.resolve(attacker, defender, hex_grid)

	assert_eq(attacker.hp, attacker_hp_before)

func test_melee_attack_can_take_counter_damage():
	var attacker = _make_unit("settler", human, Vector2i(0, 0)) # ataque 0, so pra medir contra-ataque
	attacker.unit_data.attack = 1.0 # forca um ataque fraco pra garantir que o defensor sobrevive
	var defender = _make_unit("warrior", rival, Vector2i(1, 0))
	var attacker_hp_before = attacker.hp

	CombatResolver.resolve(attacker, defender, hex_grid)

	assert_lt(attacker.hp, attacker_hp_before, "atacante corpo-a-corpo deveria sofrer contra-ataque de um defensor que sobrevive")

## Cobre veterania (Unit.register_kill/veterancy_multiplier): abate sobe de
## nivel, promocao cura uma fracao do HP maximo, o defensor tambem ganha
## credito se sobreviver matando o atacante no contra-ataque, e o bonus de
## ataque/defesa realmente afeta o dano calculado.
func test_kill_increases_veterancy_level_and_title():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var defender = _make_unit("warrior", rival, Vector2i(1, 0))
	defender.hp = 0.5 # qualquer dano mata

	CombatResolver.resolve(attacker, defender, hex_grid)

	assert_eq(attacker.kills, 1)
	assert_eq(attacker.veterancy_level, 1)
	assert_eq(attacker.veterancy_title(), "Veterano")

func test_promotion_heals_a_fraction_of_max_hp():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	attacker.hp = 5.0 # bem abaixo do maximo (12)
	var defender = _make_unit("warrior", rival, Vector2i(1, 0))
	defender.hp = 0.5

	CombatResolver.resolve(attacker, defender, hex_grid)

	var expected = min(5.0 + attacker.unit_data.max_hp * Unit.PROMOTION_HEAL_FRACTION, attacker.unit_data.max_hp)
	assert_almost_eq(attacker.hp, expected, 0.01)

func test_defender_that_survives_and_kills_attacker_gets_credit():
	var attacker = _make_unit("settler", human, Vector2i(0, 0))
	attacker.unit_data.attack = 1.0
	attacker.hp = 0.5 # qualquer contra-ataque mata
	var defender = _make_unit("warrior", rival, Vector2i(1, 0))

	CombatResolver.resolve(attacker, defender, hex_grid)

	assert_eq(defender.kills, 1, "defensor que sobrevive e mata o atacante no contra-ataque deveria ganhar o abate")

func test_veteran_attacker_deals_more_damage_than_recruit():
	var recruit = _make_unit("warrior", human, Vector2i(0, 0))
	var defender_a = _make_unit("warrior", rival, Vector2i(1, 0))
	var recruit_result = CombatResolver.predict(recruit, defender_a, hex_grid)

	var veteran = _make_unit("warrior", human, Vector2i(2, 0))
	veteran.veterancy_level = 1
	var defender_b = _make_unit("warrior", rival, Vector2i(1, 0))
	var veteran_result = CombatResolver.predict(veteran, defender_b, hex_grid)

	assert_gt(veteran_result.damage_to_defender, recruit_result.damage_to_defender, "atacante veterano deveria causar mais dano que um recruta com o mesmo ataque base")

## Roadmap de gameplay Fase 2: bonus de flanqueamento — unidade aliada do
## ATACANTE adjacente ao ALVO (nao ao proprio atacante) da um multiplicador
## modesto de ataque extra, so contagem de adjacencia (sem direcao/angulo
## real, ver CombatResolver._flanking_multiplier).
func test_flanking_ally_adjacent_to_defender_increases_damage():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var defender = _make_unit("warrior", rival, Vector2i(1, 0))
	var result_alone = CombatResolver.predict(attacker, defender, hex_grid)

	_make_unit("warrior", human, Vector2i(2, 0)) # aliado do atacante, adjacente ao DEFENSOR (nao ao atacante)

	var result_flanked = CombatResolver.predict(attacker, defender, hex_grid)

	assert_gt(result_flanked.damage_to_defender, result_alone.damage_to_defender, "aliado adjacente ao defensor deveria aumentar o dano por flanqueamento")

func test_flanking_ignores_units_that_are_not_the_attackers_allies():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var defender = _make_unit("warrior", rival, Vector2i(1, 0))
	var result_alone = CombatResolver.predict(attacker, defender, hex_grid)

	_make_unit("warrior", rival, Vector2i(2, 0)) # do mesmo lado do DEFENSOR, nao do atacante

	var result_with_enemy_nearby = CombatResolver.predict(attacker, defender, hex_grid)

	assert_almost_eq(result_with_enemy_nearby.damage_to_defender, result_alone.damage_to_defender, 0.01, "unidade do lado do defensor nao deveria contar como flanqueamento do atacante")

## Mago (unit_data.ignores_terrain_defense) atira magia que ignora o bonus
## de defesa de terreno do defensor — colina (defense_bonus 0.5) protege
## contra guerreiro mas nao contra magia.
func test_mage_ignores_terrain_defense_bonus():
	var mage = _make_unit("mage", human, Vector2i(0, 0))
	var warrior = _make_unit("warrior", human, Vector2i(2, 0))
	var defender_a = _make_unit("warrior", rival, Vector2i(1, 0)) # HILLS
	var defender_b = _make_unit("warrior", rival, Vector2i(1, 0))

	var mage_result = CombatResolver.predict(mage, defender_a, hex_grid)
	var warrior_result = CombatResolver.predict(warrior, defender_b, hex_grid)

	assert_gt(mage_result.damage_to_defender, warrior_result.damage_to_defender, "mago deveria ignorar o bonus de defesa de colina, causando mais dano que um guerreiro com o mesmo ataque base")

## Muralhas (BuildingData.defense_bonus) somam ao multiplicador de defesa
## de uma unidade guarnicionada DENTRO da propria cidade — mesmo mecanismo
## do bonus de terreno, so que vindo de um predio em vez do tile.
func test_walls_building_reduces_damage_to_garrisoned_defender():
	var attacker_no_walls = _make_unit("warrior", human, Vector2i(0, 0))
	var defender_no_walls = _make_unit("warrior", rival, Vector2i(1, 0)) # HILLS, sem cidade
	var result_without_walls = CombatResolver.predict(attacker_no_walls, defender_no_walls, hex_grid)

	var city := City.new()
	city.owner_player = rival
	city.coord = Vector2i(1, 0)
	city.buildings["walls"] = true
	hex_grid.cities_by_coord[Vector2i(1, 0)] = city

	var attacker_with_walls = _make_unit("warrior", human, Vector2i(2, 0))
	var defender_with_walls = _make_unit("warrior", rival, Vector2i(1, 0))
	var result_with_walls = CombatResolver.predict(attacker_with_walls, defender_with_walls, hex_grid)

	assert_lt(
		result_with_walls.damage_to_defender, result_without_walls.damage_to_defender,
		"defensor guarnicionado numa cidade com Muralhas deveria tomar menos dano"
	)
	city.queue_free()

## Muralhas nao protegem contra magia, igual bonus de terreno (mesmo campo
## unit_data.ignores_terrain_defense gate os dois).
func test_mage_ignores_walls_defense_bonus():
	var city := City.new()
	city.owner_player = rival
	city.coord = Vector2i(1, 0)
	city.buildings["walls"] = true
	hex_grid.cities_by_coord[Vector2i(1, 0)] = city

	var mage = _make_unit("mage", human, Vector2i(0, 0))
	var warrior = _make_unit("warrior", human, Vector2i(2, 0))
	var defender_a = _make_unit("warrior", rival, Vector2i(1, 0))
	var defender_b = _make_unit("warrior", rival, Vector2i(1, 0))

	var mage_result = CombatResolver.predict(mage, defender_a, hex_grid)
	var warrior_result = CombatResolver.predict(warrior, defender_b, hex_grid)

	assert_gt(mage_result.damage_to_defender, warrior_result.damage_to_defender, "mago deveria ignorar tambem o bonus de defesa de Muralhas")
	city.queue_free()

## Fortificar (Unit.fortified, pedido do usuario: "as opções... mover,
## fortificar e explorar") — mesmo mecanismo de bonus de defesa de
## terreno/Muralhas, so que vindo da propria unidade estar parada.
func test_fortified_defender_takes_less_damage():
	var attacker_a = _make_unit("warrior", human, Vector2i(2, 0))
	var defender_not_fortified = _make_unit("warrior", rival, Vector2i(0, 0)) # GRASSLAND, sem bonus de terreno pra isolar o efeito
	var result_not_fortified = CombatResolver.predict(attacker_a, defender_not_fortified, hex_grid)

	var attacker_b = _make_unit("warrior", human, Vector2i(2, 0))
	var defender_fortified = _make_unit("warrior", rival, Vector2i(0, 0))
	defender_fortified.fortified = true
	var result_fortified = CombatResolver.predict(attacker_b, defender_fortified, hex_grid)

	assert_lt(
		result_fortified.damage_to_defender, result_not_fortified.damage_to_defender,
		"defensor fortificado deveria tomar menos dano que um identico sem fortificar"
	)

## Magia ignora fortificar tambem, igual bonus de terreno/Muralhas (mesmo
## campo unit_data.ignores_terrain_defense gate os tres).
func test_mage_ignores_fortify_defense_bonus():
	var mage = _make_unit("mage", human, Vector2i(2, 0))
	var warrior = _make_unit("warrior", human, Vector2i(2, 0))
	var defender_a = _make_unit("warrior", rival, Vector2i(0, 0))
	defender_a.fortified = true
	var defender_b = _make_unit("warrior", rival, Vector2i(0, 0))
	defender_b.fortified = true

	var mage_result = CombatResolver.predict(mage, defender_a, hex_grid)
	var warrior_result = CombatResolver.predict(warrior, defender_b, hex_grid)

	assert_gt(mage_result.damage_to_defender, warrior_result.damage_to_defender, "mago deveria ignorar tambem o bonus de defesa de Fortificar")

## Covil de Monstro (defender.owner_player == null, ver MonsterDatabase):
## derrotar o guardiao credita unit_data.gold_reward pro dono do atacante,
## nao so remove a unidade sem nenhum efeito.
func test_defeating_monster_lair_grants_gold_reward():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var monster := Unit.new()
	monster.setup(MonsterDatabase.create_monster("goblin"), null, Vector2i(1, 0))
	monster.hp = 0.5 # qualquer dano mata
	hex_grid.units_by_coord[Vector2i(1, 0)] = monster
	human.gold = 0.0

	CombatResolver.resolve(attacker, monster, hex_grid)

	assert_almost_eq(human.gold, MonsterDatabase.create_monster("goblin").gold_reward, 0.01)
	assert_null(hex_grid.get_unit_at(Vector2i(1, 0)), "guardiao derrotado deveria sumir do grid")

## Cobre CombatResolver.resolve_city_attack — pedido do usuario: "quero...
## estabelecer a vida da cidade... e o shield tambem... a partir do
## momento que voce construir a muralha... [o shield fica] abaixo da vida
## atual". Ate aqui, atacar uma cidade indefesa (sem unidade guarnicionada)
## capturava na hora, num unico clique (ver SelectionManager._attack_from_
## selected/RivalAI._engage ANTES desta mudanca) — agora e um dano de
## verdade contra hp/shield, so captura quando a vida zera.
## Desde a Fase 2 do roadmap (unificacao do bonus de Muralha, ver
## CombatResolver.resolve_city_attack), o dano bruto do ataque (4.0) ja
## sai reduzido por BuildingDatabase.defense_bonus_for({"walls":true})
## (0.5) ANTES de descontar do escudo — mesmo bonus que uma unidade
## guarnicionada ja recebia via predict(), agora tambem se aplica a uma
## cidade indefesa. 4.0 / (1+0.5) = 2.67.
func test_attacking_undefended_city_with_walls_damages_shield_before_hp():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0)) # attack 4.0
	var city = hex_grid.found_city(Vector2i(1, 0), rival, "Capital Rival")
	city.buildings["walls"] = true
	city.shield = city.max_shield()
	var hp_before = city.hp
	var expected_damage = 4.0 / 1.5 # attack / (1 + defense_bonus_for walls)

	CombatResolver.resolve_city_attack(attacker, city, hex_grid)

	assert_almost_eq(city.shield, city.max_shield() - expected_damage, 0.01, "escudo deveria absorver o dano (ja reduzido pela Muralha) primeiro")
	assert_eq(city.hp, hp_before, "vida nao deveria cair enquanto o escudo aguenta o dano sozinho")
	city.queue_free()

func test_attacking_undefended_city_overflow_damage_spills_into_hp():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0)) # attack 4.0
	var city = hex_grid.found_city(Vector2i(1, 0), rival, "Capital Rival")
	city.buildings["walls"] = true
	city.shield = 1.0 # menos que o dano (ja reduzido pela Muralha) do ataque
	var hp_before = city.hp
	var expected_damage = 4.0 / 1.5
	var expected_overflow = expected_damage - 1.0

	CombatResolver.resolve_city_attack(attacker, city, hex_grid)

	assert_eq(city.shield, 0.0, "escudo deveria zerar")
	assert_almost_eq(city.hp, hp_before - expected_overflow, 0.01, "sobra de dano (ja reduzido pela Muralha, menos o escudo) deveria cair na vida")
	city.queue_free()

func test_attacking_undefended_city_without_walls_damages_hp_directly():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0)) # attack 4.0
	var city = hex_grid.found_city(Vector2i(1, 0), rival, "Capital Rival")
	var hp_before = city.hp

	CombatResolver.resolve_city_attack(attacker, city, hex_grid)

	assert_almost_eq(city.hp, hp_before - 4.0, 0.01)
	assert_eq(city.shield, 0.0, "sem Muralhas construida, a cidade nao deveria ter escudo nenhum")
	city.queue_free()

func test_city_is_not_captured_by_a_single_attack_that_does_not_zero_its_hp():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var city = hex_grid.found_city(Vector2i(1, 0), rival, "Capital Rival")

	CombatResolver.resolve_city_attack(attacker, city, hex_grid)

	assert_eq(city.owner_player, rival, "um unico ataque fraco nao deveria capturar a cidade mais")
	assert_true(rival.cities.has(city))
	city.queue_free()

func test_city_is_captured_once_its_hp_reaches_zero():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var city = hex_grid.found_city(Vector2i(1, 0), rival, "Capital Rival")
	city.hp = 2.0 # qualquer ataque mata

	CombatResolver.resolve_city_attack(attacker, city, hex_grid)

	assert_eq(city.owner_player, human)
	assert_true(human.cities.has(city))
	assert_false(rival.cities.has(city))
	city.queue_free()

## Roadmap "Fase Macro" 5B.3-B -- atacante NEUTRO (Dragao/monstro, owner_
## player == null): raid, nunca captura. Sem este guard, hex_grid.
## capture_city(city, null) quebraria (new_owner.cities.append sobre
## null) -- protege exatamente o caminho que o Dragao passou a exercitar
## pela primeira vez (nenhum monstro atacava cidade diretamente antes).
func test_neutral_attacker_never_captures_a_city_even_at_zero_hp():
	var attacker = hex_grid.spawn_monster_at(Vector2i(0, 0), "dragon")
	var city = hex_grid.found_city(Vector2i(1, 0), rival, "Capital Rival")
	city.hp = 2.0 # qualquer ataque mataria uma cidade normal

	CombatResolver.resolve_city_attack(attacker, city, hex_grid)

	assert_eq(city.owner_player, rival, "ataque neutro nunca deveria capturar a cidade")
	assert_true(rival.cities.has(city))
	assert_almost_eq(city.hp, 1.0, 0.01, "cidade fica extremamente fragil, mas nunca chega a 0/muda de dono")
	attacker.queue_free()
	city.queue_free()

func test_attacker_loses_all_movement_after_attacking_a_city():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	attacker.movement_left = 2.0
	var city = hex_grid.found_city(Vector2i(1, 0), rival, "Capital Rival")

	CombatResolver.resolve_city_attack(attacker, city, hex_grid)

	assert_eq(attacker.movement_left, 0.0)
	city.queue_free()

## Cidade capturada comeca curada pro novo dono — pedido implicito (sem
## isso, uma cidade mal-capturada com a vida quase zerada ficaria
## trivialmente reconquistavel pelo dono anterior no proximo turno).
func test_capturing_a_city_via_attack_resets_hp_and_shield_for_new_owner():
	var attacker = _make_unit("warrior", human, Vector2i(0, 0))
	var city = hex_grid.found_city(Vector2i(1, 0), rival, "Capital Rival")
	city.buildings["walls"] = true
	city.hp = 1.0
	city.shield = 0.0

	CombatResolver.resolve_city_attack(attacker, city, hex_grid)

	assert_almost_eq(city.hp, city.max_hp(), 0.01, "cidade capturada deveria comecar curada pro novo dono")
	assert_almost_eq(city.shield, city.max_shield(), 0.01)
	city.queue_free()
