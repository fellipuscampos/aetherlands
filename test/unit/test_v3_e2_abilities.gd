extends GutTest

## V3 / Etapa 2 — identidade mecânica das 12 espécies: Goblin (raide de 2 + Saque Rápido + descanso), Esqueleto (bando,
## não se suicida, Horda Crescente com limites), Worg (sem cidade, Faro de Sangue), Aranha (Veneno), Troll
## (Regeneração), Wyvern (Sopro em cone + Chamas), Minotauro (Investida + empurrão/Abalado), Basilisco (Petrificação
## Parcial), Verme (Escavar → telegraph → Emergir sem redirecionar), Ancião (Raízes), Devorador (Fome Arcana + Barreira +
## Ruptura/Silêncio), Colmeia (infecção limitada e visível). Mais: duração justa humano × IA, Dragão não pausa a
## ecologia, save/load sem duplicar/ticar/emergir e dados das habilidades.

var _original := {}
var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _events: Array = []
var _connections: Array = []

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	_original.events = WorldEventManager.to_save_dict()
	GameManager.stagger_ai_turns = false
	_events.clear()
	var callable := func(action: String, info: Dictionary): _events.append([action, info.duplicate()])
	EventBus.combat_ecology_event.connect(callable)
	_connections.append([EventBus.combat_ecology_event, callable])
	_world()

func after_each():
	for entry in _connections:
		if (entry[0] as Signal).is_connected(entry[1]):
			(entry[0] as Signal).disconnect(entry[1])
	_connections.clear()
	for player in GameManager.players:
		player.release_relations()
	if grid != null and is_instance_valid(grid):
		grid.queue_free()
	grid = null
	for key in _original:
		if key not in ["turn", "events"]:
			GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn
	WorldEventManager.reset_for_new_match()
	WorldEventManager.from_save_dict(_original.events)

# --- Fixture ------------------------------------------------------------------------------------

func _player(name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = name
	civ.race = "human"
	return PlayerData.new(civ)

func _world(radius: int = 16) -> void:
	grid = HexGrid.new()
	add_child(grid)
	grid.map_seed = 99
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if absi(q + r) <= radius:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Assento 0")
	rival = _player("Assento 1")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.ai_controls_human_seat = false
	TurnManager.turn_number = 20
	WorldEventManager.reset_for_new_match(1)
	MonsterEcologySystem.enabled = true

func _monster(kind: String, coord: Vector2i, anchor: Vector2i = HexGrid.NO_LAIR) -> Unit:
	var site_anchor := coord if anchor == HexGrid.NO_LAIR else anchor
	var site := MonsterEcologySystem._create_site(grid, kind, site_anchor, HexGrid.NO_LAIR, MonsterEcologySystem.SOURCE_INITIAL, TurnManager.turn_number, [coord] as Array[Vector2i])
	return grid.get_unit_at(coord)

func _member(kind: String, coord: Vector2i, site_of: Unit) -> Unit:
	var unit := grid.spawn_monster_at(coord, kind)
	unit.ecology_site_id = site_of.ecology_site_id
	return unit

func _soldier(coord: Vector2i, owner: PlayerData = null, kind: String = "warrior") -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit(kind), owner if owner != null else human)

func _act(unit: Unit, turn: int) -> void:
	if not is_instance_valid(unit):
		return
	TurnManager.turn_number = turn
	unit.reset_movement()
	MonsterAI.act_for_unit(unit, grid, turn)

func _ability_events(id: String) -> Array:
	return _events.filter(func(e): return e[0] == "ability" and String(e[1].get("ability", "")) == id)

# --- Dados ---------------------------------------------------------------------------------------

func test_every_species_declares_player_facing_abilities_with_full_metadata():
	for kind in MonsterEcologyData.SPECIES_ORDER:
		var ids := MonsterAbilityData.for_species(kind)
		assert_false(ids.is_empty(), "%s tem pelo menos uma mecânica própria" % kind)
		for id in ids:
			var data := MonsterAbilityData.get_ability(id)
			for key in ["name", "description", "passive", "cooldown", "min_range", "max_range", "targeting", "ai"]:
				assert_true(data.has(key), "%s.%s" % [id, key])
	var all_ids := {}
	for kind in MonsterEcologyData.SPECIES_ORDER:
		for id in MonsterAbilityData.for_species(kind):
			assert_false(all_ids.has(id), "habilidade %s é de uma espécie só" % id)
			all_ids[id] = kind
	assert_eq(all_ids.size(), 13)

# --- Goblin --------------------------------------------------------------------------------------

func test_goblin_raids_steals_gold_retreats_and_rests():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	human.gold = 5.0
	var goblin := _monster("goblin", Vector2i(3, 0))
	var struck := -1
	for turn in range(12, 24):
		_act(goblin, turn)
		if not _ability_events(MonsterAbilityData.QUICK_PLUNDER).is_empty():
			struck = turn
			break
	assert_gt(struck, 0, "Goblin chega e golpeia a cidade")
	assert_eq(human.gold, 0.0, "rouba até 8, nunca deixa Ouro negativo")
	assert_eq(float(_ability_events(MonsterAbilityData.QUICK_PLUNDER)[0][1].gold_stolen), 5.0)
	assert_eq(city.owner_player, human, "não captura")
	assert_eq(goblin.ecology_rest_until, struck + 8, "descanso de 8 rodadas")
	_events.clear()
	for turn in range(struck + 1, struck + 8):
		_act(goblin, turn)
	assert_true(_ability_events(MonsterAbilityData.QUICK_PLUNDER).is_empty(), "sem cerco contínuo")
	assert_gt(HexMetrics.axial_distance(goblin.coord, city.coord), 1, "recua")

func test_at_most_two_goblins_share_one_raid():
	grid.found_city(Vector2i.ZERO, human, "Capital", true)
	var goblins: Array[Unit] = [_monster("goblin", Vector2i(5, 0)), _monster("goblin", Vector2i(0, 5)), _monster("goblin", Vector2i(-5, 5))]
	for goblin in goblins:
		_act(goblin, 12)
	var committed := goblins.filter(func(g): return MonsterAbilitySystem._coord(g.ability_state.get("raid_target")) == Vector2i.ZERO)
	assert_eq(committed.size(), 2, "o terceiro Goblin não entra no mesmo raide")

func test_goblin_plunder_and_pillage_never_pay_twice():
	var city := grid.found_city(Vector2i.ZERO, human, "Capital", true)
	human.gold = 100.0
	var goblin := _monster("goblin", Vector2i(1, 0))
	MonsterAbilitySystem.on_city_hit(goblin, city)
	assert_eq(human.gold, 92.0, "um golpe = um Saque Rápido")
	assert_eq(_ability_events(MonsterAbilityData.QUICK_PLUNDER).size(), 1)

# --- Esqueleto -----------------------------------------------------------------------------------

func test_skeleton_waits_for_its_band_before_raiding():
	grid.found_city(Vector2i.ZERO, human, "Capital", true)
	var first := _monster("skeleton", Vector2i(6, 0))
	var second := _member("skeleton", Vector2i(7, 0), first)
	_act(first, 12)
	assert_eq(MonsterAbilitySystem._coord(first.ability_state.get("raid_target")), HexGrid.NO_LAIR, "dois não bastam")
	_member("skeleton", Vector2i(6, 1), first)
	_act(first, 13)
	assert_eq(MonsterAbilitySystem._coord(first.ability_state.get("raid_target")), Vector2i.ZERO, "o bando de 3 parte")
	assert_not_null(second)

func test_skeleton_does_not_suicide_against_a_clearly_superior_target():
	var skeleton := _monster("skeleton", Vector2i(4, 0))
	_member("skeleton", Vector2i(6, 0), skeleton)
	var knight := _soldier(Vector2i(5, 0), human, "warrior")
	knight.unit_data.defense = 30.0
	knight.unit_data.attack = 30.0
	knight.unit_data.max_hp = 200.0
	knight.hp = 200.0
	assert_true(MonsterAI._ecology_clearly_bad(skeleton, knight, grid))
	_act(skeleton, 30)
	assert_true(_events.filter(func(e): return e[0] == "attack").is_empty(), "não ataca luta perdida")
	assert_true(is_instance_valid(skeleton) and skeleton.hp > 0.0)

func test_rising_horde_raises_one_per_round_up_to_six_and_never_from_event_skeletons():
	var skeleton := _monster("skeleton", Vector2i(0, 0))
	var site := MonsterEcologySystem.site_for_unit(skeleton)
	MonsterAbilitySystem.on_civ_unit_killed(skeleton, grid)
	assert_eq(MonsterEcologySystem.site_population(grid, int(site.id)), 2, "ergue 1")
	MonsterAbilitySystem.on_civ_unit_killed(skeleton, grid)
	assert_eq(MonsterEcologySystem.site_population(grid, int(site.id)), 2, "no máximo 1 por sítio por rodada")
	for turn in range(21, 30):
		TurnManager.turn_number = turn
		MonsterAbilitySystem.on_civ_unit_killed(skeleton, grid)
	assert_eq(MonsterEcologySystem.site_population(grid, int(site.id)), 6, "teto de 6 vivos por sítio")
	for unit in grid.neutral_units():
		assert_null(grid.get_city_at(unit.coord))
	var event_skeleton := grid.spawn_monster_at(Vector2i(8, 0), "skeleton")
	event_skeleton.source_event_id = 3
	var before := grid.neutral_units().size()
	TurnManager.turn_number = 40
	MonsterAbilitySystem.on_civ_unit_killed(event_skeleton, grid)
	assert_eq(grid.neutral_units().size(), before, "Esqueleto de evento/regional não multiplica")

func test_rising_horde_triggers_from_a_real_kill():
	var skeleton := _monster("skeleton", Vector2i(0, 0))
	var victim := _soldier(Vector2i(1, 0))
	victim.hp = 0.5
	_act(skeleton, 30)
	assert_false(is_instance_valid(victim) and victim.hp > 0.0)
	assert_eq(_ability_events(MonsterAbilityData.RISING_HORDE).size(), 1)

# --- Worg ----------------------------------------------------------------------------------------

func test_worg_never_targets_cities_and_prefers_isolated_prey():
	grid.found_city(Vector2i.ZERO, human, "Capital", true)
	var worg := _monster("worg", Vector2i(6, 0))
	for turn in range(12, 30):
		_act(worg, turn)
	assert_true(_events.filter(func(e): return e[0] == "city_attack").is_empty(), "Worg nunca caça cidade")
	assert_false(MonsterEcologyData.behavior("worg").city_hunt)
	assert_false(MonsterEcologyData.behavior("worg").improvement_hunt)
	# Presa: o isolado vence o escoltado mesmo um pouco mais longe.
	var escorted := _soldier(Vector2i(8, 2))
	_soldier(Vector2i(8, 3))
	var isolated := _soldier(Vector2i(10, -4), rival)
	grid.teleport_unit(worg, Vector2i(9, 0))
	var prey := MonsterAI._ecology_select_prey(worg, Vector2i(6, 0), 8, "isolated", grid, MonsterEcologyData.behavior("worg"))
	assert_eq(prey, isolated)
	assert_not_null(escorted)

func test_worg_hunt_bonus_only_against_isolated_targets():
	var worg := _monster("worg", Vector2i(0, 0))
	var behavior := MonsterEcologyData.behavior("worg")
	var lone := _soldier(Vector2i(1, 0))
	assert_almost_eq(MonsterAI._ecology_strike(worg, lone, grid, behavior), 1.25, 0.001, "+25% no isolado")
	_soldier(Vector2i(2, 0))
	assert_almost_eq(MonsterAI._ecology_strike(worg, lone, grid, behavior), 1.0, 0.001, "protegido: sem bônus")
	grid.remove_unit(grid.get_unit_at(Vector2i(2, 0)))
	var far_lone := _soldier(Vector2i(5, 0), rival)
	grid.remove_unit(lone)
	worg.reset_movement()
	var base_move := worg.movement_left
	MonsterAI._ecology_hunt(worg, grid, far_lone, Vector2i(0, 0), 8, behavior, 30)
	assert_eq(_ability_events(MonsterAbilityData.BLOOD_SCENT).filter(func(e): return e[1].has("isolated_hunted")).size(), 1, "+1 Movimento de perseguição")
	assert_eq(base_move, worg.unit_data.movement_points)

# --- Aranha / status ----------------------------------------------------------------------------

func test_spider_poison_applies_refreshes_without_stacking_and_ticks():
	var spider := _monster("giant_spider", Vector2i(0, 0))
	var victim := _soldier(Vector2i(1, 0))
	victim.unit_data.max_hp = 100.0
	victim.hp = 100.0
	_act(spider, 30)
	assert_true(UnitStatusEffects.is_active(victim, UnitStatusEffects.POISON), "Picada Venenosa envenena")
	var expiry := int(victim.magic_status[UnitStatusEffects.POISON])
	assert_eq(expiry, 30 + 3, "humano: 3 turnos próprios (30, 31, 32)")
	UnitStatusEffects.apply(victim, UnitStatusEffects.POISON, 3)
	assert_eq(int(victim.magic_status[UnitStatusEffects.POISON]), expiry, "reaplicar renova, não acumula")
	assert_eq(UnitStatusEffects.dot_amount(victim, UnitStatusEffects.POISON), 4.0, "4% de 100 com teto 4")
	var hp := victim.hp
	var ticks := 0
	for turn in range(30, 36):
		TurnManager.turn_number = turn
		UnitStatusEffects.process_round(GameManager.players, grid, turn)
		if victim.hp < hp:
			ticks += 1
			hp = victim.hp
	assert_eq(ticks, 3, "três ticks")
	assert_false(victim.magic_status.has(UnitStatusEffects.POISON), "limpo depois")
	assert_false(UnitStatusEffects.apply(spider, UnitStatusEffects.POISON, 3), "nunca em monstro/estrutura")

func test_status_duration_is_the_same_number_of_own_turns_for_human_and_ai():
	var human_unit := _soldier(Vector2i(0, 0), human)
	var ai_unit := _soldier(Vector2i(4, 0), rival)
	TurnManager.turn_number = 30 # fase dos monstros do turno 30
	UnitStatusEffects.apply(human_unit, UnitStatusEffects.PETRIFIED, 1)
	UnitStatusEffects.apply(ai_unit, UnitStatusEffects.PETRIFIED, 1)
	assert_eq(human_unit.movement_left, 0.0, "humano: o turno próprio seguinte é o 30 (já resetado) — zera agora")
	# Início do turno 31: reset de todos; a IA joga o próprio turno 31 petrificada, o humano já não.
	TurnManager.turn_number = 31
	human_unit.reset_movement()
	ai_unit.reset_movement()
	assert_gt(human_unit.movement_left, 0.0, "humano: 1 turno próprio")
	assert_eq(ai_unit.movement_left, 0.0, "IA: o turno próprio seguinte é o 31")
	TurnManager.turn_number = 32
	ai_unit.reset_movement()
	assert_gt(ai_unit.movement_left, 0.0, "IA: também só 1 turno próprio")

# --- Troll ---------------------------------------------------------------------------------------

func test_troll_regenerates_only_without_damage_since_last_turn():
	var troll := _monster("troll", Vector2i(0, 0))
	troll.hp = 10.0
	troll.took_damage_since_regen = false
	_act(troll, 30)
	assert_eq(troll.hp, 12.0, "10% da Vida máxima (20)")
	troll.hp = 8.0 # dano real
	assert_true(troll.took_damage_since_regen)
	_act(troll, 31)
	assert_eq(troll.hp, 8.0, "dano interrompe a regeneração neste ciclo")
	_act(troll, 32)
	assert_eq(troll.hp, 10.0, "volta no ciclo seguinte sem dano")

# --- Wyvern --------------------------------------------------------------------------------------

func test_wyvern_breath_cone_damage_burning_cooldown_and_no_city_targets():
	var wyvern := _monster("wyvern", Vector2i(0, 0))
	var primary := _soldier(Vector2i(2, 0))
	var area := MonsterAbilitySystem.breath_area(wyvern, Vector2i(2, 0), grid)
	assert_eq(area.size(), 2, "cone de 2 tiles atrás do alvo (nunca o raio inteiro)")
	for coord in area:
		assert_eq(HexMetrics.axial_distance(wyvern.coord, coord), 3)
	var behind := _soldier(area[0])
	for unit in [primary, behind]:
		unit.unit_data.max_hp = 100.0
		unit.hp = 100.0
	var p_damage := float(CombatResolver.predict(wyvern, primary, grid).damage_to_defender) * 0.9
	var s_damage := float(CombatResolver.predict(wyvern, behind, grid).damage_to_defender) * 0.6
	assert_true(MonsterAbilitySystem.try_active(wyvern, grid, Vector2i(0, 0), 9))
	assert_almost_eq(primary.hp, 100.0 - p_damage, 0.01, "90% no alvo")
	assert_almost_eq(behind.hp, 100.0 - s_damage, 0.01, "60% no cone")
	assert_true(UnitStatusEffects.is_active(primary, UnitStatusEffects.BURNING))
	assert_true(UnitStatusEffects.is_active(behind, UnitStatusEffects.BURNING))
	assert_eq(MonsterAbilitySystem.cooldown_remaining(wyvern, MonsterAbilityData.FLAME_BREATH), 3)
	assert_false(MonsterAbilitySystem.try_active(wyvern, grid, Vector2i(0, 0), 9), "em recarga")
	# Alvo dentro de cidade nunca é alvo do sopro.
	wyvern.magic_cooldowns.clear()
	grid.remove_unit(primary)
	grid.remove_unit(behind)
	var city := grid.found_city(Vector2i(0, 2), human, "Muralha", true)
	_soldier(Vector2i(0, 2))
	assert_false(MonsterAbilitySystem.try_active(wyvern, grid, Vector2i(0, 0), 9), "sem cerco automático")
	assert_not_null(city)

# --- Minotauro -----------------------------------------------------------------------------------

func test_minotaur_charge_lands_adjacent_hits_hard_and_knocks_back():
	var minotaur := _monster("minotaur", Vector2i(0, 0))
	var target := _soldier(Vector2i(3, 0))
	target.unit_data.max_hp = 200.0
	target.hp = 200.0
	var normal := float(CombatResolver.predict(minotaur, target, grid).damage_to_defender)
	assert_eq(MonsterAbilitySystem.charge_landing(minotaur, target, grid), Vector2i(2, 0))
	assert_true(MonsterAbilitySystem.try_active(minotaur, grid, Vector2i(0, 0), 9))
	assert_eq(minotaur.coord, Vector2i(2, 0), "termina colado, sem teleporte por cima de nada")
	assert_eq(target.coord, Vector2i(4, 0), "empurrado 1 tile para longe")
	assert_lt(target.hp, 200.0 - normal * 1.4, "~150% do golpe normal")
	assert_eq(MonsterAbilitySystem.cooldown_remaining(minotaur, MonsterAbilityData.CHARGE), 3)

func test_minotaur_blocked_knockback_staggers_and_blocked_line_has_no_charge():
	var minotaur := _monster("minotaur", Vector2i(0, 0))
	var target := _soldier(Vector2i(3, 0))
	target.unit_data.max_hp = 200.0
	target.hp = 200.0
	_soldier(Vector2i(4, 0)) # bloqueia o empurrão
	assert_true(MonsterAbilitySystem.try_active(minotaur, grid, Vector2i(0, 0), 9))
	assert_eq(target.coord, Vector2i(3, 0), "sem teleporte para tile ocupado")
	assert_true(UnitStatusEffects.is_active(target, UnitStatusEffects.STAGGERED), "Abalado")
	assert_almost_eq(UnitStatusEffects.defense_multiplier(target), 0.85, 0.001)
	var other := _monster("minotaur", Vector2i(0, 6))
	_soldier(Vector2i(1, 6)) # no meio do caminho
	var far := _soldier(Vector2i(3, 6))
	assert_eq(MonsterAbilitySystem.charge_landing(other, far, grid), HexGrid.NO_LAIR, "não atravessa unidades")

# --- Basilisco -----------------------------------------------------------------------------------

func test_basilisk_gaze_partially_petrifies_without_stacking():
	var basilisk := _monster("basilisk", Vector2i(0, 0))
	var target := _soldier(Vector2i(2, 0))
	assert_true(MonsterAbilitySystem.try_active(basilisk, grid, Vector2i(0, 0), 9))
	assert_true(UnitStatusEffects.is_active(target, UnitStatusEffects.PETRIFIED))
	assert_eq(target.movement_left, 0.0, "Movimento 0")
	assert_almost_eq(UnitStatusEffects.defense_multiplier(target), 0.8, 0.001, "−20% Defesa")
	assert_true(target.unit_data.can_basic_attack and target.can_receive_orders(), "ainda pode atacar")
	assert_eq(MonsterAbilitySystem.cooldown_remaining(basilisk, MonsterAbilityData.PETRIFYING_GAZE), 4)
	var expiry := int(target.magic_status[UnitStatusEffects.PETRIFIED])
	basilisk.magic_cooldowns.clear()
	assert_false(MonsterAbilitySystem.try_active(basilisk, grid, Vector2i(0, 0), 9), "não repete em quem já está petrificado")
	assert_eq(int(target.magic_status[UnitStatusEffects.PETRIFIED]), expiry)
	var far := _soldier(Vector2i(4, 0), rival)
	assert_false(MonsterAbilitySystem._in_ability_range(basilisk, far, MonsterAbilityData.PETRIFYING_GAZE, Vector2i.ZERO, 9), "alcance 2")

# --- Verme Colossal ------------------------------------------------------------------------------

func test_worm_burrows_telegraphs_and_emerges_where_it_said_without_retargeting():
	var worm := _monster("colossal_worm", Vector2i(0, 0))
	var target := _soldier(Vector2i(4, 0))
	TurnManager.turn_number = 30
	assert_true(MonsterAbilitySystem.try_active(worm, grid, Vector2i(0, 0), 9))
	assert_true(MonsterAbilitySystem.is_burrowed(worm))
	assert_null(grid.get_unit_at(Vector2i(0, 0)), "não bloqueia o tile de superfície")
	assert_false(worm in grid.neutral_units(), "não é alvo")
	assert_eq(MonsterAbilitySystem.telegraph_coords(), [Vector2i(4, 0)] as Array[Vector2i], "Rastro Subterrâneo no destino")
	assert_eq(MonsterEcologySystem.site_population(grid, worm.ecology_site_id), 1, "continua vivo para o sítio")
	MonsterAbilitySystem.process_round(grid, 30)
	assert_true(MonsterAbilitySystem.is_burrowed(worm), "fica 1 turno inteiro sob a terra")
	grid.teleport_unit(target, Vector2i(8, 0)) # o jogador sai da área
	TurnManager.turn_number = 31
	MonsterAbilitySystem.process_round(grid, 31)
	assert_false(MonsterAbilitySystem.is_burrowed(worm))
	assert_eq(worm.coord, Vector2i(4, 0), "emerge no destino gravado — sem perseguir o alvo")
	assert_eq(target.hp, target.unit_data.max_hp, "quem saiu escapou")
	assert_true(MonsterAbilitySystem.skips_turn(worm, 31), "emergir é a ação do turno")
	assert_eq(MonsterAbilitySystem.cooldown_remaining(worm, MonsterAbilityData.BURROW), 4)

func test_worm_emergence_hits_the_impact_tile_and_neighbours():
	var worm := _monster("colossal_worm", Vector2i(0, 0))
	var target := _soldier(Vector2i(4, 0))
	var neighbour := _soldier(Vector2i(4, 1))
	for unit in [target, neighbour]:
		unit.unit_data.max_hp = 200.0
		unit.hp = 200.0
	TurnManager.turn_number = 30
	MonsterAbilitySystem.try_active(worm, grid, Vector2i(0, 0), 9)
	TurnManager.turn_number = 31
	MonsterAbilitySystem.process_round(grid, 31)
	assert_ne(worm.coord, Vector2i(4, 0), "destino ocupado: emerge colado")
	assert_lt(target.hp, 200.0, "impacto")
	var emerge := _ability_events(MonsterAbilityData.BURROW).filter(func(e): return String(e[1].get("stage", "")) == "emerge")
	assert_eq(emerge.size(), 1)
	assert_gte(int(emerge[0][1].hits), 1)

func test_worm_mid_burrow_survives_save_and_load_without_emerging_or_duplicating():
	var worm := _monster("colossal_worm", Vector2i(0, 0))
	_soldier(Vector2i(4, 0))
	TurnManager.turn_number = 30
	MonsterAbilitySystem.try_active(worm, grid, Vector2i(0, 0), 9)
	var saved := MonsterAbilitySystem.to_save_array()
	assert_eq(saved.size(), 1)
	var serialized: Variant = JSON.parse_string(JSON.stringify(saved))
	MonsterAbilitySystem.reset()
	MonsterAbilitySystem.load_save_array(serialized, grid)
	assert_eq(MonsterAbilitySystem.burrowed.size(), 1, "sem duplicar")
	var loaded: Unit = MonsterAbilitySystem.burrowed[0]
	assert_true(MonsterAbilitySystem.is_burrowed(loaded), "o load nunca faz emergir")
	assert_eq(MonsterAbilitySystem.telegraph_coords(), [Vector2i(4, 0)] as Array[Vector2i], "telegraph restaurado")
	assert_null(grid.get_unit_at(Vector2i(0, 0)))
	assert_eq(int(loaded.magic_cooldowns.get(MonsterAbilityData.BURROW, 0)), int(worm.magic_cooldowns.get(MonsterAbilityData.BURROW, 0)))

# --- Ancião Arbóreo ------------------------------------------------------------------------------

func test_ancient_roots_up_to_four_tiles_for_three_rounds_and_roots_occupants():
	var ancient := _monster("arboreal_ancient", Vector2i(0, 0))
	var intruder := _soldier(Vector2i(2, 0))
	var base_cost := grid.terrain_step_cost(Vector2i(2, 0))
	TurnManager.turn_number = 30
	assert_true(MonsterAbilitySystem.try_active(ancient, grid, Vector2i(0, 0), 9))
	assert_eq(MonsterHazardSystem.roots.size(), 4, "até 4 zonas")
	for coord in MonsterHazardSystem.roots:
		assert_lte(HexMetrics.axial_distance(ancient.coord, coord), 2)
	assert_true(MonsterHazardSystem.is_root(Vector2i(2, 0)), "começa pelo tile ocupado")
	assert_true(UnitStatusEffects.is_active(intruder, UnitStatusEffects.ROOTED), "quem estava em cima fica Enraizado")
	assert_eq(grid.terrain_step_cost(Vector2i(2, 0)), base_cost + 2.0, "+2 para unidade de civilização")
	assert_eq(grid.terrain_step_cost(Vector2i(2, 0), null, false), base_cost, "monstros não pagam")
	assert_eq(grid.get_tile(Vector2i(2, 0)).terrain_type, HexTileData.TerrainType.GRASSLAND, "terreno-base intacto")
	for turn in range(31, 33):
		MonsterHazardSystem.process_round(grid, turn, {})
	assert_eq(MonsterHazardSystem.roots.size(), 4, "duram 3 rodadas")
	MonsterHazardSystem.process_round(grid, 33, {})
	assert_true(MonsterHazardSystem.roots.is_empty(), "expiram")
	assert_eq(grid.terrain_step_cost(Vector2i(2, 0)), base_cost)

func test_root_and_infection_state_round_trips():
	MonsterHazardSystem.add_roots(grid, [Vector2i(1, 1), Vector2i(2, 2)] as Array[Vector2i], 3)
	var hive := _monster("mycotic_hive", Vector2i(-5, 0))
	MonsterHazardSystem.process_round(grid, 21, {hive.ecology_site_id: Vector2i(-5, 0)})
	var saved: Variant = JSON.parse_string(JSON.stringify(MonsterHazardSystem.to_save_dict()))
	var roots_before := MonsterHazardSystem.roots.duplicate()
	var infected_before := MonsterHazardSystem.infected_count()
	MonsterHazardSystem.reset()
	MonsterHazardSystem.load_save_dict(saved, grid)
	assert_eq(MonsterHazardSystem.roots, roots_before)
	assert_eq(MonsterHazardSystem.infected_count(), infected_before, "sem expansão no load")

# --- Devorador de Mana ---------------------------------------------------------------------------

func test_arcane_hunger_drains_after_the_spell_once_per_round_without_negative_mana():
	var devourer := _monster("mana_devourer", Vector2i(0, 0))
	var caster := _soldier(Vector2i(2, 0), human, "v2_unit_sacred_cleric")
	human.mana = 4.0
	MonsterAbilitySystem.on_spell_cast(caster, grid)
	assert_eq(human.mana, 0.0, "drena até 6, nunca negativo")
	assert_almost_eq(devourer.arcane_barrier, 4.0, 0.001, "Mana drenada vira Barreira")
	human.mana = 50.0
	MonsterAbilitySystem.on_spell_cast(caster, grid)
	assert_eq(human.mana, 50.0, "uma vez por rodada por Devorador")
	TurnManager.turn_number = 21
	MonsterAbilitySystem.on_spell_cast(caster, grid)
	assert_eq(human.mana, 44.0)
	var cap := devourer.unit_data.max_hp * 0.15
	assert_almost_eq(devourer.arcane_barrier, cap, 0.001, "teto de 15% da Vida")
	var hp := devourer.hp
	devourer.hp = hp - 2.0
	assert_eq(devourer.hp, hp, "Barreira absorve dano antes da Vida")
	assert_almost_eq(devourer.arcane_barrier, cap - 2.0, 0.001)
	var magic: GDScript = load("res://scripts/core/V2MagicRuntime.gd")
	assert_true(magic.source_code.contains("MonsterAbilitySystem.on_spell_cast(unit, grid)"), "ligada DEPOIS do feitiço resolver (cast não é cancelado)")

func test_aether_rupture_silences_casters_only():
	var devourer := _monster("mana_devourer", Vector2i(0, 0))
	var warrior := _soldier(Vector2i(2, 0))
	assert_false(MonsterAbilitySystem.try_active(devourer, grid, Vector2i(0, 0), 9), "sem conjurador: ataque normal")
	grid.remove_unit(warrior)
	var mage := _soldier(Vector2i(2, 0), human, "v2_unit_sacred_cleric")
	assert_true(MonsterAbilitySystem._is_caster(mage))
	mage.unit_data.max_hp = 100.0
	mage.hp = 100.0
	assert_true(MonsterAbilitySystem.try_active(devourer, grid, Vector2i(0, 0), 9))
	assert_almost_eq(mage.hp, 100.0 - devourer.unit_data.attack * 0.8, 0.01, "80% do Ataque, mágico")
	assert_true(UnitStatusEffects.is_active(mage, UnitStatusEffects.SILENCED))
	assert_true(V2MagicRuntime.is_spellcasting_silenced(mage), "não pode conjurar")
	assert_eq(MonsterAbilitySystem.cooldown_remaining(devourer, MonsterAbilityData.AETHER_RUPTURE), 4)

# --- Colmeia Micótica ----------------------------------------------------------------------------

func test_hive_infection_grows_one_tile_per_round_to_radius_two_and_twelve_tiles():
	var hive := _monster("mycotic_hive", Vector2i(0, 0))
	var sites := {hive.ecology_site_id: Vector2i(0, 0)}
	MonsterHazardSystem.process_round(grid, 21, sites)
	assert_eq(MonsterHazardSystem.infected_count(), 7, "âncora + raio 1")
	MonsterHazardSystem.process_round(grid, 22, sites)
	assert_eq(MonsterHazardSystem.infected_count(), 8, "+1 por rodada")
	for turn in range(23, 60):
		MonsterHazardSystem.process_round(grid, turn, sites)
	assert_eq(MonsterHazardSystem.infected_count(), 12, "teto de 12")
	for coord in MonsterHazardSystem._infected:
		assert_lte(HexMetrics.axial_distance(Vector2i(0, 0), coord), 2, "raio máximo 2")

func test_infection_damages_once_per_turn_halves_healing_and_skips_cities():
	var hive := _monster("mycotic_hive", Vector2i(0, 0))
	var city := grid.found_city(Vector2i(0, 1), human, "Vizinha", true)
	MonsterHazardSystem.process_round(grid, 21, {hive.ecology_site_id: Vector2i(0, 0)})
	assert_false(MonsterHazardSystem.is_infected(Vector2i(0, 1)), "cidade nunca é infectada")
	var unit := _soldier(Vector2i(5, 0))
	unit.unit_data.max_hp = 100.0
	unit.hp = 100.0
	TurnManager.turn_number = 30
	grid.move_unit(unit, Vector2i(1, -1), 0.0)
	assert_eq(unit.hp, 97.0, "3% ao entrar (máx. 3)")
	grid.move_unit(unit, Vector2i(1, 0), 0.0)
	assert_eq(unit.hp, 97.0, "uma vez por turno")
	MonsterHazardSystem.process_turn_start(GameManager.players, grid)
	assert_eq(unit.hp, 97.0, "mesmo turno")
	TurnManager.turn_number = 31
	MonsterHazardSystem.process_turn_start(GameManager.players, grid)
	assert_eq(unit.hp, 94.0, "começar o turno ali também machuca")
	assert_eq(MonsterHazardSystem.heal_multiplier(unit), 0.5, "cura pela metade")
	assert_eq(city.hp, city.max_hp(), "sem DoT em cidade")

func test_hive_death_decays_infection_in_two_rounds():
	var hive := _monster("mycotic_hive", Vector2i(0, 0))
	var sites := {hive.ecology_site_id: Vector2i(0, 0)}
	for turn in range(21, 30):
		MonsterHazardSystem.process_round(grid, turn, sites)
	var peak := MonsterHazardSystem.infected_count()
	MonsterHazardSystem.process_round(grid, 30, {})
	assert_eq(MonsterHazardSystem.infected_count(), peak - int(ceil(peak / 2.0)), "metade no primeiro round")
	MonsterHazardSystem.process_round(grid, 31, {})
	assert_eq(MonsterHazardSystem.infected_count(), 0, "o resto no seguinte")

# --- Era / Dragão / IA ---------------------------------------------------------------------------

func test_species_city_hunt_rules():
	for kind in ["worg", "giant_spider", "troll", "minotaur", "basilisk", "colossal_worm", "arboreal_ancient", "mana_devourer", "mycotic_hive"]:
		assert_false(bool(MonsterEcologyData.behavior(kind).city_hunt), "%s não caça cidade" % kind)
	for kind in ["goblin", "skeleton", "wyvern"]:
		assert_true(bool(MonsterEcologyData.behavior(kind).city_hunt), "%s faz raide" % kind)

func test_dragon_event_does_not_pause_the_ecology():
	var worg := _monster("worg", Vector2i(8, 0))
	_soldier(Vector2i(10, -2))
	var dragon := DragonEvent.new()
	WorldEventManager.active_events.append(dragon)
	var legacy := grid.spawn_monster_at(Vector2i(-8, 0), "goblin")
	grid.create_lair(Vector2i(-12, 0), "goblin", HexGrid.LAIR_ROLE_WILD)
	assert_true(MonsterAI._recalled_by_dragon(legacy, grid), "selvagem legado mantém o recolhimento antigo")
	assert_false(MonsterAI._recalled_by_dragon(worg, grid), "ecologia não é recolhida")
	_act(worg, 40)
	WorldEventManager.active_events.erase(dragon)
	assert_false(_events.filter(func(e): return e[0] in ["move", "attack", "ability"]).is_empty(), "segue caçando durante o Dragão")

func test_ai_evades_a_visible_worm_impact_and_known_infection():
	var worm := _monster("colossal_worm", Vector2i(0, 0))
	var soldier := _soldier(Vector2i(4, 0), rival)
	TurnManager.turn_number = 30
	MonsterAbilitySystem.try_active(worm, grid, Vector2i(0, 0), 9)
	var visible := grid.compute_visible_tiles(rival)
	assert_true(MonsterHazardSystem.known_danger(Vector2i(4, 0), rival, visible))
	soldier.reset_movement()
	assert_true(MonsterHazardSystem.ai_evade(soldier, grid, visible), "sai do impacto previsto")
	assert_ne(soldier.coord, Vector2i(4, 0))
	var hidden := MonsterHazardSystem.known_danger(Vector2i(4, 0), human, {})
	assert_false(hidden, "telegraph não visto não é conhecido")

func test_known_infection_costs_more_on_paths_but_never_blocks():
	var hive := _monster("mycotic_hive", Vector2i(0, 0))
	MonsterHazardSystem.process_round(grid, 21, {hive.ecology_site_id: Vector2i(0, 0)})
	assert_eq(MonsterHazardSystem.path_penalty(Vector2i(1, 0), human), 0.0, "desconhecida não pesa (sem onisciência)")
	human.explored_tiles[Vector2i(1, 0)] = true
	assert_eq(MonsterHazardSystem.path_penalty(Vector2i(1, 0), human), MonsterHazardSystem.KNOWN_INFECTION_PATH_PENALTY)
	var path := grid.compute_path(Vector2i(4, 0), Vector2i(1, -1), human)
	assert_false(path.is_empty(), "nunca vira muro")

func test_inspector_lists_signature_abilities_and_statuses():
	var spider := _monster("giant_spider", Vector2i(0, 0))
	var lines: Array = TileInspector._monster_entry(spider, grid).lines
	assert_true("\n".join(lines).contains("Picada Venenosa"))
	var victim := _soldier(Vector2i(3, 0))
	UnitStatusEffects.apply(victim, UnitStatusEffects.POISON, 3)
	var status := "\n".join(TileInspector.status_effect_lines(victim))
	assert_true(status.contains("Envenenado") and status.contains("3 turnos"))
	var basilisk := _monster("basilisk", Vector2i(-4, 0))
	basilisk.magic_cooldowns[MonsterAbilityData.PETRIFYING_GAZE] = TurnManager.turn_number + 2
	assert_true("\n".join(TileInspector._monster_entry(basilisk, grid).lines).contains("recarga 2"))
