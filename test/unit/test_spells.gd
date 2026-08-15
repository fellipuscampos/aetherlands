extends GutTest

## Cobre SpellDatabase (efeitos de gameplay pros feiticos que TechData.
## unlocks_spell ja nomeia) e SpellManager (custo DUPLO — cooldown de
## turnos E mana, ver Ponto 3 "Economia Arcana" — aplicacao de dano/cura,
## no-op seguro pra feitico sem SpellData cadastrado, em recarga, ou sem
## mana) — pedido do usuario: "permita que o jogador selecione o
## feitico... e aplique o efeito no mapa... gastando um custo em
## recursos/mana ou por cooldown de turnos" (Ponto 2, ja implementado) +
## "o botao Conjurar deve ficar desabilitado se o jogador nao tiver saldo
## de Mana suficiente... desconte a Mana do PlayerData" (Ponto 3).

var hex_grid: HexGrid
var caster: PlayerData
var target_owner: PlayerData
var _created_units: Array[Unit] = []

func before_each():
	_created_units = []
	hex_grid = HexGrid.new()
	hex_grid._ready()
	var center := Vector2i(0, 0)
	hex_grid.tiles[center] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	for dir in HexGrid.NEIGHBOR_DIRS:
		hex_grid.tiles[center + dir] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)

	caster = PlayerData.new(CivilizationData.new())
	# Mana de sobra por padrao (custo maximo cadastrado hoje e 40, Reanimar)
	# — os testes que especificamente cobrem bloqueio por mana insuficiente
	# reduzem isso explicitamente, ver test_cast_fails_* abaixo.
	caster.mana = 1000.0
	target_owner = PlayerData.new(CivilizationData.new())

func after_each():
	for unit in _created_units:
		if is_instance_valid(unit):
			unit.queue_free()
	hex_grid.queue_free()

func _make_unit(kind: String, player: PlayerData, coord: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.setup(UnitDatabase.create_unit(kind), player, coord)
	if player:
		player.units.append(unit)
	hex_grid.units_by_coord[coord] = unit
	_created_units.append(unit)
	return unit

func test_get_spell_returns_known_spell():
	var spell = SpellDatabase.get_spell("Lança de Arcana")
	assert_not_null(spell)
	assert_eq(spell.target_kind, "enemy_unit_in_vision")

func test_get_spell_returns_null_for_unknown_name():
	assert_null(SpellDatabase.get_spell("Feitico Que Nao Existe"))

func test_can_cast_false_without_the_tech_researched():
	assert_false(SpellManager.can_cast(caster, "Lança de Arcana", 1))

func test_can_cast_true_once_the_tech_is_researched():
	caster.researched_techs["invocacao_espiritos"] = true
	assert_true(SpellManager.can_cast(caster, "Lança de Arcana", 1))

func test_can_cast_false_while_on_cooldown():
	caster.researched_techs["invocacao_espiritos"] = true
	caster.spell_cooldowns["Lança de Arcana"] = 5

	assert_false(SpellManager.can_cast(caster, "Lança de Arcana", 3))
	assert_true(SpellManager.can_cast(caster, "Lança de Arcana", 5), "turno exatamente igual ao fim da recarga ja deveria liberar de novo")

func test_cast_applies_damage_and_sets_cooldown():
	caster.researched_techs["invocacao_espiritos"] = true
	var enemy = _make_unit("warrior", target_owner, Vector2i(1, 0))
	var hp_before = enemy.hp
	var mana_before = caster.mana

	var message = SpellManager.cast(caster, "Lança de Arcana", enemy, hex_grid, 1)

	assert_almost_eq(enemy.hp, hp_before - 6.0, 0.01)
	assert_eq(caster.spell_cooldowns["Lança de Arcana"], 1 + 3, "recarga (3 turnos) deveria comecar a contar a partir do turno da conjuracao")
	assert_almost_eq(caster.mana, mana_before - 25.0, 0.01, "Lança de Arcana custa 25 de mana")
	assert_true("dano" in message)

func test_cast_kills_and_removes_unit_when_hp_drops_to_zero():
	caster.researched_techs["invocacao_espiritos"] = true
	var enemy = _make_unit("warrior", target_owner, Vector2i(1, 0))
	enemy.hp = 5.0 # abaixo do dano do feitico (6) — deveria morrer

	SpellManager.cast(caster, "Lança de Arcana", enemy, hex_grid, 1)

	assert_false(hex_grid.units_by_coord.has(Vector2i(1, 0)), "unidade destruida deveria sumir do tabuleiro")
	assert_false(enemy in target_owner.units, "unidade destruida deveria sair da lista do dono")

func test_cast_heals_a_friendly_unit():
	caster.researched_techs["necromancia_pratica"] = true
	var ally = _make_unit("warrior", caster, Vector2i(1, 0)) # max_hp 12
	ally.hp = 4.0
	var mana_before = caster.mana

	var message = SpellManager.cast(caster, "Reanimar", ally, hex_grid, 1)

	assert_almost_eq(ally.hp, 4.0 + 12.0 * 0.5, 0.01, "Reanimar restaura 50% do HP MAXIMO, nao do HP atual")
	assert_almost_eq(caster.mana, mana_before - 40.0, 0.01, "Reanimar custa 40 de mana")
	assert_true("HP" in message)

func test_cast_heal_never_overheals_past_max_hp():
	caster.researched_techs["necromancia_pratica"] = true
	var ally = _make_unit("warrior", caster, Vector2i(1, 0))
	ally.hp = 11.0 # perto do teto (12)

	SpellManager.cast(caster, "Reanimar", ally, hex_grid, 1)

	assert_almost_eq(ally.hp, 12.0, 0.01)

func test_cast_a_spell_without_spelldata_is_a_safe_no_op():
	var enemy = _make_unit("warrior", target_owner, Vector2i(1, 0))
	var hp_before = enemy.hp

	var message = SpellManager.cast(caster, "Ruína Ígnea", enemy, hex_grid, 1)

	assert_almost_eq(enemy.hp, hp_before, 0.01, "feitico sem SpellData cadastrado nao deveria mudar nada")
	assert_true("não tem efeito" in message)

func test_cast_while_on_cooldown_does_not_reapply_the_effect():
	caster.researched_techs["invocacao_espiritos"] = true
	caster.spell_cooldowns["Lança de Arcana"] = 10
	var enemy = _make_unit("warrior", target_owner, Vector2i(1, 0))
	var hp_before = enemy.hp

	var message = SpellManager.cast(caster, "Lança de Arcana", enemy, hex_grid, 1)

	assert_almost_eq(enemy.hp, hp_before, 0.01, "feitico em recarga nao deveria aplicar efeito nenhum")
	assert_true("recarga" in message)

func test_has_enough_mana_false_below_the_spell_cost():
	caster.mana = 24.0 # Lança de Arcana custa 25
	assert_false(SpellManager.has_enough_mana(caster, "Lança de Arcana"))

func test_has_enough_mana_true_at_or_above_the_spell_cost():
	caster.mana = 25.0
	assert_true(SpellManager.has_enough_mana(caster, "Lança de Arcana"))

func test_has_enough_mana_false_for_a_spell_without_spelldata():
	caster.mana = 1000.0
	assert_false(SpellManager.has_enough_mana(caster, "Ruína Ígnea"), "feitico sem custo cadastrado nunca deveria contar como 'tem mana suficiente'")

func test_is_castable_requires_both_tech_cooldown_and_mana():
	# So a tecnologia, sem mana: nao castable.
	caster.researched_techs["invocacao_espiritos"] = true
	caster.mana = 0.0
	assert_false(SpellManager.is_castable(caster, "Lança de Arcana", 1))

	# Tecnologia + mana, mas em recarga: nao castable.
	caster.mana = 1000.0
	caster.spell_cooldowns["Lança de Arcana"] = 10
	assert_false(SpellManager.is_castable(caster, "Lança de Arcana", 1))

	# Os tres satisfeitos: castable.
	caster.spell_cooldowns.erase("Lança de Arcana")
	assert_true(SpellManager.is_castable(caster, "Lança de Arcana", 1))

## Regressao critica: mana insuficiente precisa bloquear o CAST de verdade
## (nao so o botao da HUD) — sem isso um jogador com 0 mana ainda
## conseguiria conjurar chamando a mesma logica que a HUD usa.
func test_cast_fails_with_insufficient_mana_and_applies_no_effect():
	caster.researched_techs["invocacao_espiritos"] = true
	caster.mana = 10.0 # menos que os 25 exigidos
	var enemy = _make_unit("warrior", target_owner, Vector2i(1, 0))
	var hp_before = enemy.hp

	var message = SpellManager.cast(caster, "Lança de Arcana", enemy, hex_grid, 1)

	assert_almost_eq(enemy.hp, hp_before, 0.01, "sem mana suficiente, o dano nao deveria ser aplicado")
	assert_almost_eq(caster.mana, 10.0, 0.01, "mana nao deveria ser descontada de uma conjuracao que falhou")
	assert_false(caster.spell_cooldowns.has("Lança de Arcana"), "conjuracao que falhou por falta de mana nao deveria gastar cooldown")
	assert_true("Mana insuficiente" in message)

func test_cooldown_ends_at_reflects_the_stored_turn():
	caster.spell_cooldowns["Lança de Arcana"] = 7
	assert_eq(SpellManager.cooldown_ends_at(caster, "Lança de Arcana"), 7)

func test_cooldown_ends_at_defaults_to_zero_when_never_cast():
	assert_eq(SpellManager.cooldown_ends_at(caster, "Lança de Arcana"), 0)
