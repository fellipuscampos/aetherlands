extends GutTest

## DURAÇÃO DOS EFEITOS TEMPORÁRIOS (2026-10-13) — relato do usuário: "alguns buffs só duram um turno... eu ativo o
## efeito no meu turno, o efeito fica ativo, eu dou próximo, e o efeito já acabou". Estes testes passam pela troca de
## turno DE VERDADE (TurnManager.end_turn, com a IA agindo dentro dela) para fixar o que "1 turno" cobre.

var grid: HexGrid
var human: PlayerData
var rival: PlayerData
var _original := {}
var _seen: Array = []
var _listener: Callable

const AEGIS := "v2_spell_sacred_aegis"
const MACABRE := "v2_spell_macabre_command"
const SILENCE := "v2_spell_silence"

func before_each():
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "debug_mode", "ai_controls_human_seat"]:
		_original[key] = GameManager.get(key)
	_original.turn = TurnManager.turn_number
	grid = HexGrid.new()
	add_child_autofree(grid)
	for q in range(-10, 11):
		for r in range(-10, 11):
			if absi(q + r) <= 10:
				grid.tiles[Vector2i(q, r)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	human = _player("Aurora")
	rival = _player("Crepúsculo")
	GameManager.players = [human, rival] as Array[PlayerData]
	GameManager.rival_players = [rival] as Array[PlayerData]
	GameManager.human_player = human
	GameManager.hex_grid = grid
	GameManager.state = GameManager.GameState.PLAYING
	GameManager.debug_mode = false
	GameManager.stagger_ai_turns = false
	GameManager.ai_controls_human_seat = false
	TurnManager.turn_number = 10
	grid.found_city(Vector2i(-7, 0), human, "Capital", true)
	grid.found_city(Vector2i(7, 0), rival, "Sombria", true)
	Diplomacy.declare_war(human, rival, "Fronteira", true)
	_seen.clear()

func after_each():
	if _listener.is_valid() and EventBus.combat_engagement.is_connected(_listener):
		EventBus.combat_engagement.disconnect(_listener)
	SelectionManager.reset()
	GameManager.is_turn_processing = false
	GameManager._ai_turn_queue.clear()
	for player in [human, rival]:
		player.release_relations()
	for key in ["players", "rival_players", "human_player", "hex_grid", "state", "stagger_ai_turns", "debug_mode", "ai_controls_human_seat"]:
		GameManager.set(key, _original[key])
	TurnManager.turn_number = _original.turn

func _player(civ_name: String) -> PlayerData:
	var civ := CivilizationData.new()
	civ.civ_name = civ_name
	return PlayerData.new(civ)

func _unit(coord: Vector2i, owner: PlayerData) -> Unit:
	return grid.spawn_unit(coord, UnitDatabase.create_unit("warrior"), owner)

## Um alvo do jogador com `status_id` ativado AGORA e um atacante da IA colado nele. Registra, no instante de cada
## ataque da IA, se o efeito estava valendo.
func _buffed_target_under_attack(status_id: String) -> Unit:
	var target := _unit(Vector2i(0, 0), human)
	target.hp = 3.0 # fraco: a IA ataca com certeza
	target.magic_status[status_id] = V2OwnerTurnEffect.expiry_for_now()
	_unit(Vector2i(1, 0), rival)
	_listener = func(_attacker_owner, _defender_owner, kind: String, coord: Vector2i):
		if kind == "unit" and coord == Vector2i(0, 0) and is_instance_valid(target):
			_seen.append({"turn": TurnManager.turn_number, "active": V2OwnerTurnEffect.is_active(target.magic_status, status_id),
				"spell_defense": V2MagicRuntime.defense_multiplier(target), "technique_defense": V2TechniqueRuntime.defense_multiplier(target, grid)})
	EventBus.combat_engagement.connect(_listener)
	return target

# --- O efeito cobre o turno dos inimigos -------------------------------------------------------------------------------------

func test_a_defensive_spell_cast_on_my_turn_is_still_up_when_the_enemy_attacks():
	_buffed_target_under_attack(AEGIS)

	TurnManager.end_turn()

	assert_false(_seen.is_empty(), "pré-condição: a IA atacou a unidade na fase dela")
	assert_true(_seen[0].active, "a Égide lançada no meu turno ainda valia quando o inimigo bateu")
	assert_almost_eq(float(_seen[0].spell_defense), 1.4, 0.0001, "e entrou na conta da Defesa")

func test_a_defensive_technique_activated_on_my_turn_is_still_up_when_the_enemy_attacks():
	_buffed_target_under_attack(V2DoctrineTechniqueDatabase.SHIELD_WALL)

	TurnManager.end_turn()

	assert_false(_seen.is_empty(), "pré-condição: a IA atacou a unidade na fase dela")
	assert_true(_seen[0].active, "a Muralha de Escudos ativada no meu turno ainda valia quando o inimigo bateu")
	assert_almost_eq(float(_seen[0].technique_defense), 1.35, 0.0001)

func test_the_effect_ends_when_my_next_turn_begins_not_before():
	var unit := _unit(Vector2i(-5, 3), human)
	unit.magic_status[AEGIS] = V2OwnerTurnEffect.expiry_for_now()
	assert_true(V2OwnerTurnEffect.is_active(unit.magic_status, AEGIS), "pré-condição: ativo no turno em que foi lançado")

	TurnManager.end_turn()

	assert_false(unit.magic_status.has(AEGIS), "meu turno seguinte começou: o efeito de 1 turno acabou")

func test_a_silence_cast_on_an_enemy_mage_lasts_through_that_enemy_turn():
	var mage := _unit(Vector2i(6, 1), rival)
	mage.magic_status[SILENCE] = V2OwnerTurnEffect.expiry_for_now()
	var silenced_during_enemy_phase := [false]
	var probe := func(_player, _city, _item, _result):
		# Emitido no meio da troca de turno, já com o número do turno novo — a fase da IA acontece neste intervalo.
		silenced_during_enemy_phase[0] = V2MagicRuntime.is_spellcasting_silenced(mage)
	EventBus.city_production_processed.connect(probe)

	TurnManager.end_turn()

	EventBus.city_production_processed.disconnect(probe)
	assert_true(silenced_during_enemy_phase[0], "o mago inimigo passou o turno dele silenciado")
	assert_false(V2MagicRuntime.is_spellcasting_silenced(mage), "e volta a conjurar quando o meu turno começa")

# --- O jogo deixa isso claro ---------------------------------------------------------------------------------------------

func test_the_combat_notice_names_the_effect_that_protected_the_unit():
	var target := _buffed_target_under_attack(AEGIS)
	target.hp = target.unit_data.max_hp # inteira: sobrevive ao golpe e o aviso é "resistiu"
	var notices: Array = []
	var capture := func(text: String, _kind: String): notices.append(text)
	EventBus.notify.connect(capture)

	CombatResolver.resolve(grid.get_unit_at(Vector2i(1, 0)), target, grid)

	EventBus.notify.disconnect(capture)
	assert_true(notices.any(func(text): return String(text).contains("resistiu") and String(text).contains("Protegido por Égide Sagrada")), str(notices))
	assert_eq(CombatResolver.defense_effects_note(_unit(Vector2i(-4, -4), human), grid), "", "sem efeito ativo, o aviso fica como sempre")

func test_an_ally_standing_next_to_a_shield_wall_is_named_too():
	var wall := _unit(Vector2i(0, 0), human)
	var neighbour := _unit(Vector2i(0, 1), human)
	wall.magic_status[V2DoctrineTechniqueDatabase.SHIELD_WALL] = V2OwnerTurnEffect.expiry_for_now()
	human.v2_research.debug_complete_branch(V2ResearchNode.TreeType.MILITARY_DOCTRINE, "guardian")
	assert_string_contains(CombatResolver.defense_effects_note(wall, grid), "Protegido por")
	assert_string_contains(CombatResolver.defense_effects_note(neighbour, grid), "(aliado ao lado)")

func test_the_wording_says_the_effect_covers_the_enemy_turn_and_the_chip_no_longer_reads_one_turn():
	var unit := _unit(Vector2i(-5, 3), human)
	unit.magic_status[AEGIS] = V2OwnerTurnEffect.expiry_for_now()
	var aegis := V2SpellDatabase.get_spell(AEGIS)
	assert_string_contains(V2SpellDatabase.effect_text(aegis), "vale durante todo o turno dos inimigos")
	assert_has(V2MagicRuntime.status_lines(unit), "%s — Ativa (%s)" % [aegis.display_name, V2OwnerTurnEffect.DURATION_ON_UNIT])
	var chips: Array = UnitPresenter._statuses(unit, true, grid).filter(func(entry): return String(entry.title) == aegis.display_name)
	assert_eq(chips.size(), 1)
	assert_eq(String(chips[0].duration_text), V2OwnerTurnEffect.CHIP_DURATION)
	assert_string_contains(String(chips[0].tooltip), "Dura o turno dos adversários")
	var chip := ContextUI.chip(chips[0].title, chips[0].tone, int(chips[0].turns), chips[0].tooltip, String(chips[0].duration_text))
	add_child_autofree(chip)
	assert_eq(chip.label.text, "%s · %s" % [aegis.display_name, V2OwnerTurnEffect.CHIP_DURATION], "nada de '1t', que parecia 'só este turno'")
	var poison := ContextUI.chip("Envenenado", AEStatusChip.Tone.NEGATIVE, 2)
	add_child_autofree(poison)
	assert_eq(poison.label.text, "Envenenado · 2t", "os estados contados em turnos próprios seguem com o contador")
