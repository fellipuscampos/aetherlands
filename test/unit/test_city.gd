extends GutTest

var _owned_players: Array[PlayerData] = []

func _track_player(civ: CivilizationData) -> PlayerData:
	var player := PlayerData.new(civ)
	_owned_players.append(player)
	return player

## Pedido do usuario, apos reportar que uma cidade recem-fundada spawnava
## um Colonizador sozinha sem ninguem escolher nada: "fundei uma cidade e
## fiquei dando next, e do nada uma hora spawnou um colonizador" — toda
## cidade nova nasce OCIOSA ("", ver comentario do campo em City.gd), NAO
## mais com "settler" pre-selecionado (isso sofria do mesmo bug que
## process_turn() ja corrige apos completar: produzir sem o jogador ter
## pedido).
func test_default_production_is_idle():
	var city := City.new()
	assert_eq(city.production_item, "")
	city.queue_free()

func test_set_production_changes_item_and_resets_progress():
	var city := City.new()
	city.stored_production = 10.0
	city.set_production("v2_unit_archer")
	assert_eq(city.production_item, "v2_unit_archer")
	assert_eq(city.stored_production, 0.0)
	city.queue_free()

func test_set_production_same_kind_keeps_progress():
	var city := City.new()
	city.set_production("settler") # cidade nasce ociosa (""), ver City.gd — precisa escolher antes de repetir a mesma escolha
	city.stored_production = 10.0
	city.set_production("settler") # MESMO kind de novo, nao deveria zerar
	assert_eq(city.stored_production, 10.0)
	city.queue_free()

## Regressao: abandonar um predio EM ANDAMENTO (trocar pra unidade ou
## outro predio antes de completar) precisa limpar pending_building_coord
## — senao o tile reservado ficava "preso" e o marcador de construcao
## (HexGrid.refresh_construction_markers) nunca saberia que a obra foi
## cancelada.
func test_set_production_clears_pending_coord_when_abandoning_a_building():
	var city := City.new()
	city.set_production("v2_building_market")
	city.pending_building_coord = Vector2i(3, 3)

	city.set_production("settler")

	assert_eq(city.pending_building_coord, City.NO_PENDING_COORD)
	city.queue_free()

func test_set_production_keeps_pending_coord_when_switching_between_units():
	var city := City.new()
	city.set_production("settler")
	city.pending_building_coord = Vector2i(3, 3) # nao deveria acontecer na pratica, so pra isolar o comportamento

	city.set_production("v2_unit_archer")

	assert_eq(city.pending_building_coord, Vector2i(3, 3), "trocar entre unidades (sem predio envolvido) nao deveria mexer no coord pendente")
	city.queue_free()
	city.queue_free()

func test_production_cost_matches_unit_database():
	var city := City.new()
	city.set_production("v2_unit_cavalier")
	assert_eq(city.production_cost(), UnitDatabase.create_unit("v2_unit_cavalier").production_cost)
	city.queue_free()

## --- Roadmap "Fase F"/G: mana passa a participar de _tile_claim_score ----
## F7 (diagnostico causal, ver conversa) achou um erro arquitetural GENERICO
## nesta formula: mana e um yield valido de effective_tile_yield(), mas
## nunca entrava na pontuacao de posse/trabalho de tile — 5/15 seeds nunca
## passavam de 2/3 Nodulos Arcanos mesmo com fartura deles no mapa (seed
## 1010: 14 Nodulos, so 1 jamais reivindicado por qualquer jogador). A
## formula raciocina sobre YIELD (data.resource == "mana_node" de proposito
## NAO aparece em lugar nenhum abaixo), nunca sobre o NOME do recurso — pra
## nao acoplar esta heuristica generica a um recurso especifico e ja cobrir
## qualquer terreno/efeito futuro que produza mana.

func test_process_turn_spawns_unit_once_production_cost_is_reached():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # producao 2/turno

	var city := City.new()
	city.coord = coord
	city.set_production("settler")

	var spawned := false
	for i in range(20):
		var result = city.process_turn(hex_grid)
		if result.spawn_unit_kind != "":
			spawned = true
			assert_eq(result.spawn_unit_kind, "settler")
			break

	assert_true(spawned, "cidade deveria ter completado a producao do Colonizador em 20 turnos")

	hex_grid.queue_free()
	city.queue_free()

## Mesmo cenario acima, mas verificando que process_turn() de fato ACUMULA
## producao turno apos turno em vez de ficar travado — e nao so que
## collect_yields() calcula certo isoladamente.
## Aetherlands V2, Fase 14: Produção ativa não vem mais do rendimento CRU do tile (CITY_CENTER_
## MIN_PRODUCTION era o piso da PRODUÇÃO V1, ver comentário histórico da constante) -- vem da base
## fixa de V2EconomyRuntime.city_production_income() (V2InfrastructureEconomyData.
## BASE_PRODUCTION_PER_CITY), que nunca depende de terreno. O ESPÍRITO do teste original
## (produção nunca fica travada em zero, mesmo em terreno ruim) continua válido, só a fonte mudou.
func test_process_turn_accumulates_production_even_on_zero_yield_terrain():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND) # producao 0/turno

	var city := City.new()
	city.coord = coord
	city.set_production("v2_building_market")

	# 2 turnos: bem longe do teto de armazenamento (FOOD_STORAGE_BASE=15,
	# comida liquida da Planicie sozinha e so 2/turno depois do consumo por
	# populacao) — fora do escopo deste teste, que so quer confirmar que a
	# producao NAO fica travada em zero.
	for i in range(2):
		city.process_turn(hex_grid)

	assert_eq(city.stored_production, V2InfrastructureEconomyData.BASE_PRODUCTION_PER_CITY * 2, "producao deveria avancar todo turno, nunca ficar travada em zero")

	hex_grid.queue_free()
	city.queue_free()

## production_item pode ser um id de predio (BuildingDatabase) em vez de um
## kind de unidade — production_cost() precisa checar la primeiro.
func test_production_cost_recognizes_building_id():
	var city := City.new()
	city.set_production("v2_building_market")
	assert_eq(city.production_cost(), BuildingDatabase.get_building("v2_building_market").production_cost)
	city.queue_free()

## Conclui, em ordem, a linha de pesquisa V2 até o nó que libera `unlock_id` (Fase 25: todo prédio
## construível é V2 e exige a pesquisa do dono).
func _unlock(player: PlayerData, unlock_id: String) -> void:
	var target := V2ResearchDatabase.node_for_unlock_id(unlock_id)
	for node in V2ResearchDatabase.nodes_for_branch(target.tree_type, target.branch):
		player.v2_research.complete_research(node.id)
		if node.id == target.id:
			return

func _owned_city() -> City:
	var city := City.new()
	city.owner_player = _track_player(CivilizationData.new())
	return city

func test_can_build_is_false_once_building_already_built():
	var city := _owned_city()
	_unlock(city.owner_player, "v2_building_guardian_hall")
	assert_true(city.can_build("v2_building_guardian_hall"))
	city.buildings["v2_building_guardian_hall"] = true
	assert_false(city.can_build("v2_building_guardian_hall"))
	city.queue_free()

func test_can_build_requires_the_owner_research():
	var city := _owned_city()
	assert_false(city.can_build("v2_building_guardian_hall"), "sem a pesquisa V2 o prédio não abre fila")
	city.queue_free()

## Fase 25: fora da progressão V2 só o Colonizador é treinável (UnitDatabase.CORE_TRAINABLE_KINDS),
## sem prédio; nenhuma tropa V1 abre fila, nem com o prédio V1 vestigial presente.
func test_can_train_settler_never_requires_a_building():
	var city := City.new()
	assert_true(city.can_train("settler"))
	city.queue_free()

func test_v1_troops_are_never_trainable():
	var city := _owned_city()
	city.buildings["barracks"] = true # vestígio V1 (saves antigos são sanitizados, mas o gate não depende disso)
	for kind in ["warrior", "men_at_arms", "archer", "cavalry", "catapult", "mage"]:
		assert_false(city.can_train(kind), kind)
	city.queue_free()

func test_v2_troop_needs_its_training_building_and_the_research():
	var city := _owned_city()
	city.owner_player.cities.append(city) # capacidade de Suprimentos base da cidade
	city.owner_player.gold = 1000.0
	_unlock(city.owner_player, "v2_unit_shieldbearer")
	assert_false(city.can_train("v2_unit_shieldbearer"), "pesquisa sem o Salão não basta")
	city.buildings["v2_building_guardian_hall"] = true
	assert_true(city.can_train("v2_unit_shieldbearer"))
	assert_false(city.can_train("v2_unit_archer"), "o Salão dos Guardiões não treina o Arqueiro")
	city.queue_free()

## Fase 16: Muralhas V1 foi substituída pelo projeto V2 de fortificação — nem com a tech ela volta.
func test_v1_walls_stay_unbuildable_even_with_its_tech_researched():
	var city := _owned_city()
	assert_false(city.can_build("walls"))
	city.queue_free()

## Vida/escudo da cidade (ver comentario de CITY_BASE_MAX_HP em City.gd) —
## pedido do usuario: "quero... estabelecer a vida da cidade, sempre
## mostrando na tela quanta vida ela tem, e o shield tambem, a partir do
## momento que voce construir a muralha".
## Fase 16: a vida máxima vem do Nível de Cidade V2 (I 24 / II 30 / III 36 / IV 44), não da população.
func test_max_hp_follows_city_level_not_population():
	var city := City.new()
	var hp_at_pop_1 = city.max_hp()
	assert_eq(city.max_hp(), hp_at_pop_1, "população não muda a vida da cidade")
	city.city_level = 3
	assert_eq(city.max_hp(), 36.0, "cidade mais desenvolvida é mais difícil de arrasar")
	city.queue_free()

func test_max_shield_is_zero_without_walls_built():
	var city := City.new()
	assert_eq(city.max_shield(), 0.0, "sem Muralhas construida, a cidade nao deveria ter escudo nenhum")
	city.queue_free()

func test_max_shield_is_positive_once_fortified():
	var city := City.new()
	city.buildings["walls"] = true
	assert_eq(city.max_shield(), 0.0, "o prédio V1 vestigial não dá escudo")
	city.fortification_level = 1
	assert_eq(city.max_shield(), 8.0)
	city.queue_free()

func test_setup_initializes_hp_to_max_and_shield_to_zero():
	var human := _track_player(CivilizationData.new())
	var city := City.new()

	city.setup(human, Vector2i(0, 0), "Capital")

	assert_almost_eq(city.hp, city.max_hp(), 0.01, "cidade recem-fundada deveria comecar com vida cheia")
	assert_eq(city.shield, 0.0, "cidade recem-fundada nao tem Muralhas construida ainda")
	city.queue_free()

## process_turn() cura vida/escudo aos poucos todo turno (mesmo espirito
## da cura de guarnicao de unidade, GameManager._heal_if_garrisoned) —
## sem isso, uma cidade que sobreviveu a um ataque ficaria ferida pra
## sempre, trivialmente capturavel por qualquer ataque seguinte.
func test_process_turn_regenerates_hp_over_time():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := _track_player(CivilizationData.new())
	var city := City.new()
	city.setup(human, coord, "Capital")
	city.hp = city.max_hp() * 0.5

	city.process_turn(hex_grid)

	assert_gt(city.hp, city.max_hp() * 0.5, "vida deveria regenerar um pouco a cada turno")
	assert_lte(city.hp, city.max_hp(), "regeneracao nunca deveria passar do maximo")

	hex_grid.queue_free()
	city.queue_free()

func test_process_turn_regenerates_shield_over_time_once_walls_is_built():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := _track_player(CivilizationData.new())
	var city := City.new()
	city.setup(human, coord, "Capital")
	city.fortification_level = 1
	city.shield = city.max_shield() * 0.5

	city.process_turn(hex_grid)

	assert_gt(city.shield, city.max_shield() * 0.5, "escudo deveria regenerar um pouco a cada turno")
	assert_lte(city.shield, city.max_shield(), "regeneracao nunca deveria passar do maximo")

	hex_grid.queue_free()
	city.queue_free()

## Roadmap de gameplay Fase 2: sitio (unidade inimiga adjacente por 2+
## turnos SEGUIDOS) suspende a regeneracao de HP — pedido do usuario:
## "comecar com UMA unica consequencia simples e legivel" em vez de um
## dreno novo, so desliga um bonus que ja existe. N=2 (nao 1) de proposito
## — o teste confirma que o PRIMEIRO turno de contato ainda regenera
## normalmente, so o segundo turno SEGUIDO suspende.
func test_process_turn_suspends_hp_regen_while_under_siege_for_two_turns():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	var enemy_coord := Vector2i(1, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[enemy_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := _track_player(CivilizationData.new())
	var rival := _track_player(CivilizationData.new())
	Diplomacy.declare_war(human, rival)
	var city := City.new()
	city.setup(human, coord, "Capital")
	city.hp = city.max_hp() * 0.5

	var enemy_unit := Unit.new()
	enemy_unit.setup(UnitDatabase.create_unit("warrior"), rival, enemy_coord)
	hex_grid.units_by_coord[enemy_coord] = enemy_unit

	city.process_turn(hex_grid) # 1o turno de contato: ainda regenera (sitio exige 2+)
	var hp_after_first_turn = city.hp
	assert_gt(hp_after_first_turn, city.max_hp() * 0.5, "primeiro turno de contato ainda deveria regenerar normalmente")

	city.process_turn(hex_grid) # 2o turno SEGUIDO com o mesmo inimigo adjacente: sitio de verdade agora

	assert_eq(city.hp, hp_after_first_turn, "com sitio de 2+ turnos, a regeneracao deveria ficar suspensa")

	hex_grid.queue_free()
	city.queue_free()
	enemy_unit.queue_free()

func test_process_turn_regenerates_normally_when_adjacent_unit_is_at_peace():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	var other_coord := Vector2i(1, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[other_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := _track_player(CivilizationData.new())
	var other := _track_player(CivilizationData.new()) # sem Diplomacy.declare_war — em paz
	var city := City.new()
	city.setup(human, coord, "Capital")
	city.hp = city.max_hp() * 0.5

	var other_unit := Unit.new()
	other_unit.setup(UnitDatabase.create_unit("warrior"), other, other_coord)
	hex_grid.units_by_coord[other_coord] = other_unit

	city.process_turn(hex_grid)
	city.process_turn(hex_grid)

	assert_almost_eq(city.hp, city.max_hp() * 0.5 + 2 * city.max_hp() * City.CITY_HP_REGEN_FRACTION, 0.01, "unidade em PAZ adjacente nao deveria contar como sitio")

	hex_grid.queue_free()
	city.queue_free()
	other_unit.queue_free()

## Covil de Monstro (owner_player == null) sempre conta como ameaca de
## sitio, mesmo sem estado de guerra formal — diplomacia nao existe pra
## monstro neutro.
func test_process_turn_suspends_regen_for_a_neutral_monster_adjacent():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	var monster_coord := Vector2i(1, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	hex_grid.tiles[monster_coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := _track_player(CivilizationData.new())
	var city := City.new()
	city.setup(human, coord, "Capital")
	city.hp = city.max_hp() * 0.5

	var monster := Unit.new()
	monster.setup(MonsterDatabase.create_monster("goblin"), null, monster_coord)
	hex_grid.units_by_coord[monster_coord] = monster

	city.process_turn(hex_grid)
	var hp_after_first_turn = city.hp
	city.process_turn(hex_grid)

	assert_eq(city.hp, hp_after_first_turn, "monstro neutro adjacente por 2+ turnos deveria suspender a regeneracao tambem")

	hex_grid.queue_free()
	city.queue_free()
	monster.queue_free()

## Aetherlands V2, Fase 13: número de prédios é limitado pelo City Level (V2CityLevelData),
## NUNCA mais por população — ver City.max_building_slots()/docs Fase 13.
func test_max_building_slots_comes_from_city_level_not_population():
	var city := City.new()
	city.city_level = 1
	assert_eq(city.max_building_slots(), 4)
	city.city_level = 2
	assert_eq(city.max_building_slots(), 7)
	city.city_level = 3
	assert_eq(city.max_building_slots(), 10)
	city.city_level = 4
	assert_eq(city.max_building_slots(), 13)
	# Mudar population sozinho não muda mais nada na estrutura urbana.
	assert_eq(city.max_building_slots(), 13)
	city.queue_free()

func test_can_build_respects_the_city_level_slot_limit_even_for_a_new_building():
	var city := _owned_city()
	_unlock(city.owner_player, "v2_building_market")
	city.city_level = 1 # 4 slots
	city.buildings["v2_building_guardian_hall"] = true
	city.buildings["v2_building_warrior_hall"] = true
	city.buildings["v2_building_ranger_camp"] = true
	city.buildings["v2_building_war_stable"] = true

	assert_false(city.can_build("v2_building_market"), "Cidade I so cabe 4 predios -- todos ja ocupados, nao deveria caber mais nenhum")

	city.city_level = 2 # 7 slots
	assert_true(city.can_build("v2_building_market"), "Cidade II abre espaco pro quinto predio")

	city.queue_free()

## Regressao: completar um predio precisa marcar buildings[id]=true (pra
## sempre, ver collect_yields()) e devolver built_kind pro GameManager
## notificar — diferente de unidade, nao spawna nada no grid.
##
## Pedido do usuario: "a partir do momento que voce funda a cidade, ele
## fica produzindo sem parar unidades... eu quero que... quando ela
## acabar, so produza outra se voce for la e por pra produzir de novo" —
## ANTES completar um predio trocava production_item de volta pra
## "settler" (que ai ficava se auto-reconstruindo pra sempre, mesmo bug).
## Agora fica OCIOSA ("") ate o jogador escolher o proximo item.
func test_process_turn_completes_building_and_goes_idle():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # producao 2/turno

	var city := City.new()
	city.coord = coord
	city.set_production("v2_building_market") # custa 20 producao

	var built := ""
	for i in range(20):
		var result = city.process_turn(hex_grid)
		if result.built_kind != "":
			built = result.built_kind
			break

	assert_eq(built, "v2_building_market", "cidade deveria ter completado o Mercado em 20 turnos")
	assert_true(city.buildings.has("v2_building_market"))
	assert_eq(city.production_item, "", "cidade deveria ficar OCIOSA apos completar, nao reconstruir sozinha nem trocar pra outro item automaticamente")

	hex_grid.queue_free()
	city.queue_free()

## Mesma mudanca de comportamento, pra UNIDADE — antes uma cidade
## produzindo Guarda (ou qualquer outra tropa) ficava reconstruindo a
## MESMA tropa pra sempre sozinha (production_item nunca era limpo apos
## spawnar); agora fica ociosa ate o jogador escolher de novo.
func test_process_turn_completes_a_unit_and_goes_idle():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS) # producao 2/turno

	var city := City.new()
	city.coord = coord
	city.set_production("settler")

	var spawned := ""
	for i in range(20):
		var result = city.process_turn(hex_grid)
		if result.spawn_unit_kind != "":
			spawned = result.spawn_unit_kind
			break

	assert_eq(spawned, "settler", "cidade deveria ter completado o Colonizador")
	assert_eq(city.production_item, "", "cidade deveria ficar OCIOSA apos completar a tropa, nao continuar produzindo a mesma sozinha")

	hex_grid.queue_free()
	city.queue_free()

## production_cost() precisa devolver 0.0 (nao o custo default de
## UnitDatabase.create_unit("")) pra uma cidade OCIOSA — senao qualquer
## chamador (HUD, marcador de construcao) leria um numero enganoso.
func test_production_cost_is_zero_when_idle():
	var city := City.new()
	city.set_production("v2_building_market")
	city.set_production("") # cancela/limpa producao direto

	assert_eq(city.production_item, "")
	assert_eq(city.production_cost(), 0.0)
	city.queue_free()

## Regressao central: uma cidade ociosa nunca deveria "completar" nada
## sozinha so por acumular producao — mesmo apos MUITOS turnos, sem o
## jogador escolher um item, spawn_unit_kind/built_kind ficam sempre
## vazios.
func test_process_turn_never_completes_anything_while_idle():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var city := City.new()
	city.coord = coord
	city.set_production("")

	for i in range(30):
		var result = city.process_turn(hex_grid)
		assert_eq(result.spawn_unit_kind, "", "cidade ociosa nao deveria spawnar unidade nenhuma sozinha")
		assert_eq(result.built_kind, "", "cidade ociosa nao deveria completar predio nenhum sozinho")

	hex_grid.queue_free()
	city.queue_free()

## Feature: o jogador escolhe ONDE o predio vai no mapa (como fundar
## cidade) — is_valid_building_tile() e o que valida essa escolha antes de
## SelectionManager aceitar o clique.
func test_is_valid_building_tile_accepts_a_free_land_neighbor():
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	var city := City.new()
	city.coord = Vector2i(0, 0)

	assert_true(city.is_valid_building_tile(HexGrid.NEIGHBOR_DIRS[0], hex_grid))

	hex_grid.queue_free()
	city.queue_free()

func test_is_valid_building_tile_rejects_non_neighbor():
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	hex_grid.tiles[Vector2i(5, 0)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var city := City.new()
	city.coord = Vector2i(0, 0)

	assert_false(city.is_valid_building_tile(Vector2i(5, 0), hex_grid), "tile longe demais da cidade nao deveria ser um destino valido")

	hex_grid.queue_free()
	city.queue_free()

func test_is_valid_building_tile_rejects_ocean():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var ocean_dir = HexGrid.NEIGHBOR_DIRS[0]
	hex_grid.tiles[center + ocean_dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.OCEAN)
	var city := City.new()
	city.coord = center

	assert_false(city.is_valid_building_tile(ocean_dir, hex_grid))

	hex_grid.queue_free()
	city.queue_free()

func test_is_valid_building_tile_rejects_tile_occupied_by_unit():
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	var target = HexGrid.NEIGHBOR_DIRS[0]
	var human := _track_player(CivilizationData.new())
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit("warrior"), human, target)
	hex_grid.units_by_coord[target] = unit
	var city := City.new()
	city.coord = Vector2i(0, 0)

	assert_false(city.is_valid_building_tile(target, hex_grid))

	hex_grid.queue_free()
	city.queue_free()
	unit.queue_free()

func test_is_valid_building_tile_rejects_tile_already_used_by_a_building():
	var hex_grid := _make_ring_hex_grid(Vector2i(0, 0))
	var target = HexGrid.NEIGHBOR_DIRS[0]
	hex_grid.buildings_by_coord[target] = true # so precisa existir a chave pra is_tile_building_site() acusar
	var city := City.new()
	city.coord = Vector2i(0, 0)

	assert_false(city.is_valid_building_tile(target, hex_grid))

	hex_grid.queue_free()
	city.queue_free()

## Regressao: process_turn() precisa gravar building_coords[id] e devolver
## built_coord SO quando o jogador de fato escolheu um tile
## (pending_building_coord) — ver SelectionManager.start_building_placement.
func test_process_turn_places_building_at_pending_coord():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var city := City.new()
	city.coord = coord
	city.set_production("v2_building_guardian_hall")
	city.pending_building_coord = Vector2i(1, 0)

	var built_coord = City.NO_PENDING_COORD
	for i in range(20):
		var result = city.process_turn(hex_grid)
		if result.built_kind != "":
			built_coord = result.built_coord
			break

	assert_eq(built_coord, Vector2i(1, 0))
	assert_eq(city.building_coords.get("v2_building_guardian_hall"), Vector2i(1, 0))
	assert_eq(city.pending_building_coord, City.NO_PENDING_COORD, "coord pendente deveria ser consumido ao completar")

	hex_grid.queue_free()
	city.queue_free()

## Graceful degrade: se production_item virou um predio sem passar pelo
## fluxo de posicionamento (ex: set_production() chamado direto, como em
## testes antigos), o predio ainda completa e conta pro bonus/limite — so
## nao ganha coordenada nem modelo 3D.
func test_process_turn_completes_building_without_a_coord_when_none_was_chosen():
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var city := City.new()
	city.coord = coord
	city.set_production("v2_building_guardian_hall")

	var built_kind := ""
	var built_coord = City.NO_PENDING_COORD
	for i in range(20):
		var result = city.process_turn(hex_grid)
		if result.built_kind != "":
			built_kind = result.built_kind
			built_coord = result.built_coord
			break

	assert_eq(built_kind, "v2_building_guardian_hall")
	assert_eq(built_coord, City.NO_PENDING_COORD)
	assert_false(city.building_coords.has("v2_building_guardian_hall"))

	hex_grid.queue_free()
	city.queue_free()

## Muralhas (BuildingData.self_placed = true) NUNCA passa por
## pending_building_coord (nem via SelectionManager, ver HUD._on_produce_
## pressed) — diferente do "graceful degrade" acima (que cobre um caso
## ACIDENTAL), aqui a ausencia de coord/modelo 3D e o comportamento
## PRETENDIDO: o efeito e o anel de muralha da PROPRIA cidade (ver City.
## _add_walls), acionado na hora que a producao completa (ver process_turn
## chamando _build_visual_procedural quando building.self_placed), sem
## esperar o proximo crescimento de populacao.
func test_process_turn_completes_the_fortification_project_and_refreshes_the_wall_ring():
	# Fase 16: o anel de muralha agora vem do projeto V2 de Fortificação (não mais do prédio V1).
	var hex_grid := HexGrid.new()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)

	var human := _track_player(CivilizationData.new())
	var city := City.new()
	city.setup(human, coord, "Capital") # _build_visual() inicializa _buildings_root, ver comentario abaixo
	city.city_level = 2
	city.set_production(V2FortificationData.project_id(1))
	var child_count_before = city._buildings_root.get_child_count()

	var level_up := 0
	for i in range(60):
		var result = city.process_turn(hex_grid)
		assert_eq(result.built_kind, "", "fortificação não gera prédio em tile")
		if result.fortification_level_up > 0:
			level_up = result.fortification_level_up
			break

	assert_eq(level_up, 1)
	assert_eq(city.fortification_level, 1)
	assert_false(city.buildings.has("walls"), "não entra em City.buildings")
	assert_eq(city.production_item, "")
	assert_gt(city._buildings_root.get_child_count(), child_count_before, "o anel de muralha deveria aparecer na hora, sem esperar a cidade crescer")

	hex_grid.queue_free()
	city.queue_free()

## Regressao geometrica: pedido do usuario ("se as celulas sao hexagonos, a
## muralha devem ser um conjunto de retas em cada aresta pra formar um
## hexagono ao redor da celula") — a versao anterior espalhava 6 blocos
## soltos num CIRCULO, todos no CIRCUNRAIO (onde ficam os VERTICES de um
## hexagono, nao o meio das arestas), com vaos largos entre eles — nunca
## fechava silhueta de hexagono nenhuma. Agora: 6 segmentos retos
## centralizados no APOTEMA (meio de cada aresta) + 6 pilares de canto
## EXATAMENTE nos vertices (HexMetrics.corner), fechando as juntas.
func test_walls_visual_forms_a_closed_hexagon_of_segments_and_corner_pillars():
	var human := _track_player(CivilizationData.new())
	var city := City.new()
	city.setup(human, Vector2i(0, 0), "Capital") # tile_radius default 1.0
	city.fortification_level = 1
	city._build_visual_procedural()

	var expected_wall_radius = city.tile_radius * City.WALL_RADIUS_FACTOR
	var expected_apothem = expected_wall_radius * 0.8660254
	var expected_segment_length = expected_wall_radius * City.WALL_SEGMENT_LENGTH_FACTOR
	var expected_pillar_radius = expected_wall_radius * City.WALL_PILLAR_RADIUS_FACTOR

	var segments: Array = []
	var pillars: Array = []
	for child in city._buildings_root.get_children():
		if child is MeshInstance3D:
			if child.mesh is BoxMesh and is_equal_approx(child.mesh.size.x, expected_segment_length):
				segments.append(child)
			elif child.mesh is CylinderMesh and is_equal_approx(child.mesh.top_radius, expected_pillar_radius):
				pillars.append(child)

	assert_eq(segments.size(), 6, "deveria ter exatamente 1 segmento reto por aresta do hexagono")
	assert_eq(pillars.size(), 6, "deveria ter exatamente 1 pilar por vertice do hexagono")

	# Cada segmento fica centralizado no APOTEMA (meio da aresta), NAO no
	# circunraio (onde ficam os vertices) — essa era a diferenca chave do
	# PRIMEIRO bug (segmentos flutuando alem da aresta de verdade).
	#
	# Regressao do SEGUNDO bug (posicao certa, ROTACAO errada — so este
	# assert de distancia nao pegava isso, deixou passar batido apesar da
	# muralha ficar visualmente toda torta/cruzada): confere que a direcao
	# de cada segmento (extremos calculados a partir da rotacao de
	# verdade, via transform.basis) fica PARALELA a direcao real da
	# aresta do hexagono correspondente, nao girada pro lado espelhado
	# errado.
	for seg in segments:
		var dist_from_center = Vector2(seg.position.x, seg.position.z).length()
		assert_almost_eq(dist_from_center, expected_apothem, 0.01, "segmento deveria ficar no apotema (meio da aresta), nao no circunraio")

		var half_length = expected_segment_length * 0.5
		var world_offset = seg.transform.basis * Vector3(half_length, 0, 0)
		var seg_dir = Vector2(world_offset.x, world_offset.z).normalized()

		# a posicao do segmento (angulo = 60*i graus) diz de qual aresta i
		# ele deveria fazer parte.
		var seg_angle_deg = rad_to_deg(atan2(seg.position.z, seg.position.x))
		var i = ((roundi(seg_angle_deg / 60.0) % 6) + 6) % 6
		var corner_a = HexMetrics.corner(expected_wall_radius, i)
		var corner_b = HexMetrics.corner(expected_wall_radius, (i + 1) % 6)
		var edge_dir = Vector2(corner_b.x - corner_a.x, corner_b.z - corner_a.z).normalized()

		var alignment = abs(seg_dir.dot(edge_dir)) # 1.0 = perfeitamente paralelo (ou anti-paralelo, tanto faz pra uma caixa simetrica)
		assert_almost_eq(alignment, 1.0, 0.01, "segmento deveria estar alinhado com a aresta real do hexagono, nao girado/cruzado em outro angulo")

	# Cada pilar fica EXATAMENTE num vertice do hexagono (so X/Z importam
	# aqui — Y e so a altura do pilar acima do chao).
	for i in range(6):
		var expected = HexMetrics.corner(expected_wall_radius, i)
		var found = false
		for pillar in pillars:
			var pillar_xz = Vector2(pillar.position.x, pillar.position.z)
			var expected_xz = Vector2(expected.x, expected.z)
			if pillar_xz.distance_to(expected_xz) < 0.01:
				found = true
				break
		assert_true(found, "deveria existir um pilar exatamente no vertice %d do hexagono" % i)

	city.queue_free()

## Pedido do usuario, apos ver a muralha pequena/mal-encaixada: "voce
## conseguiria fazer... como esse vermelho que tracei" (um hexagono do
## TAMANHO do proprio tile, nao de um raio local arbitrario) — confirma
## que a muralha de fato escala com o hex_size REAL do tile (HexGrid.
## hex_size, propagado via found_city -> City.setup -> tile_radius), nao
## um numero fixo desconectado do mapa.
func test_walls_visual_scales_with_the_real_tile_hex_size():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.hex_size = 2.0 # tile bem maior que o default (1.0)
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	var human := _track_player(CivilizationData.new())

	var city = hex_grid.found_city(coord, human, "Capital")
	city.fortification_level = 1
	city._build_visual_procedural()

	assert_almost_eq(city.tile_radius, 2.0, 0.01, "tile_radius deveria vir do hex_size real do HexGrid, nao ficar preso no default 1.0")

	var expected_apothem = (2.0 * City.WALL_RADIUS_FACTOR) * 0.8660254
	var found_segment_at_expected_radius = false
	for child in city._buildings_root.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var dist_from_center = Vector2(child.position.x, child.position.z).length()
			if is_equal_approx(dist_from_center, expected_apothem):
				found_segment_at_expected_radius = true
				break
	assert_true(found_segment_at_expected_radius, "muralha deveria acompanhar o hex_size 2.0, nao ficar presa numa escala fixa pequena")

	hex_grid.queue_free()

## ARVORES E RECURSOS (pedido do usuario: "evite sobreposicao ruim entre
## recursos; arvores; estruturas; cidades") -- fundar uma cidade num tile
## que ja tinha uma arvore decorativa plantada (ver HexGrid._rebuild_props)
## precisa remover essa arvore, senao o modelo da cidade nasce visualmente
## enterrado nela (confirmado com screenshot antes do fix).
func test_found_city_clears_tree_prop_planted_on_its_own_tile():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	hex_grid.tiles[coord] = TerrainDatabase.create_tile(HexTileData.TerrainType.FOREST)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis(), Vector3.ONE))
	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	hex_grid.add_child(mm_instance)
	hex_grid._props_tree_instance = mm_instance
	hex_grid._tree_coord_to_index[coord] = [0]

	var human := _track_player(CivilizationData.new())
	hex_grid.found_city(coord, human, "Capital")

	assert_false(hex_grid._tree_coord_to_index.has(coord), "arvore nao deveria continuar registrada no tile da cidade nova")

	hex_grid.queue_free()

## Mesmo pedido acima, agora pro prop 3D de RECURSO (minerio/cristal/etc) —
## um predio construido num tile com recurso nao pode deixar o prop antigo
## flutuando dentro/do lado do predio novo (confirmado com screenshot antes
## do fix: cristal flutuando no patio da cidade).
func test_place_building_clears_resource_prop_planted_on_its_tile():
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	var coord := Vector2i(0, 0)
	var tile = TerrainDatabase.create_tile(HexTileData.TerrainType.HILLS)
	tile.resource = "iron"
	hex_grid.tiles[coord] = tile

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis(), Vector3.ONE))
	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	hex_grid.add_child(mm_instance)
	hex_grid._resource_props_manager._instances["iron"] = mm_instance
	hex_grid._resource_props_manager._coord_to_index["iron"] = {coord: [0]}

	var human := _track_player(CivilizationData.new())
	hex_grid.place_building(coord, "v2_building_market", human)

	assert_false(hex_grid._resource_props_manager._coord_to_index["iron"].has(coord), "prop de recurso nao deveria continuar registrado no tile do predio novo")

	hex_grid.queue_free()

## --- Roadmap "arvore de 10 niveis" — cadeia de predios de upgrade --------
##
## Decisao explicita do plano: um "upgrade" (Quartel II/III/Elite,
## Estabulo II, Campo de Tiro II, etc.) e um predio NOVO e independente,
## nao substitui o anterior — mas ainda assim precisa dos MESMOS dois
## gates combinados que Estabulo/Quartel ja usam (requires_building E
## tech propria), agora numa cadeia de 3 elos (Quartel -> Quartel II ->
## Quartel III) em vez de 2.

func _make_ring_hex_grid(center: Vector2i) -> HexGrid:
	var hex_grid := HexGrid.new()
	hex_grid._ready()
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	return hex_grid

func after_each():
	for player in _owned_players:
		player.release_relations()
	_owned_players.clear()
