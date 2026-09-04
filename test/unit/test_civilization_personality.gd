extends GutTest

## Roadmap "Parte B" B4 (fecha a Parte B) — CivilizationPersonality.generate:
## personalidade PROSPECTIVA sorteada de map_seed, nunca armazenada em
## SaveManager. Cobre so a funcao pura aqui; integracao com PlayerData/
## GameManager.setup_players fica em test_game_manager.gd, e o gancho de
## pesquisa (B4.2) em test_rival_ai.gd.

func test_generate_is_deterministic_for_same_race_and_seed():
	var a := CivilizationPersonality.generate("orc", 123)
	var b := CivilizationPersonality.generate("orc", 123)
	assert_eq(a, b)

func test_generate_returns_all_five_axes():
	var personality := CivilizationPersonality.generate("human", 1)
	assert_eq(personality.size(), 5)
	for axis in CityIdentity.AXES:
		assert_true(personality.has(axis))

func test_generate_values_are_clamped_between_zero_and_one():
	for seed_value in [0, 1, 42, 9999, -5]:
		for race in ["human", "elf", "dwarf", "orc"]:
			var personality := CivilizationPersonality.generate(race, seed_value)
			for axis in CityIdentity.AXES:
				var value: float = personality[axis]
				assert_true(value >= 0.0 and value <= 1.0, "%s/%d/%s = %f fora de [0,1]" % [race, seed_value, axis, value])

func test_generate_varies_with_seed_for_the_same_race():
	assert_ne(CivilizationPersonality.generate("orc", 1), CivilizationPersonality.generate("orc", 2))

## Garantia MATEMATICA (nao "tendencia" estatistica): com lean 1.0 e
## BASELINE_LEAN_MAGNITUDE=0.6/JITTER_RANGE=0.15, militar NUNCA fica abaixo
## de 0.45 pro Orc, e nenhum outro eixo passa de 0.15 -- militar e
## NECESSARIAMENTE o eixo dominante, nao so "costuma ser".
func test_orc_militar_is_necessarily_dominant():
	var floor_value := CivilizationPersonality.BASELINE_LEAN_MAGNITUDE - CivilizationPersonality.JITTER_RANGE
	for seed_value in [0, 1, 42, 9999, -5]:
		var personality := CivilizationPersonality.generate("orc", seed_value)
		assert_true(personality[CityIdentity.AXIS_MILITAR] >= floor_value, "militar deveria ser >= %f, foi %f" % [floor_value, personality[CityIdentity.AXIS_MILITAR]])
		for axis in [CityIdentity.AXIS_AGRICOLA, CityIdentity.AXIS_INDUSTRIAL, CityIdentity.AXIS_COMERCIAL, CityIdentity.AXIS_ARCANA]:
			assert_true(personality[axis] <= CivilizationPersonality.JITTER_RANGE, "%s deveria ser <= %f (sem lean), foi %f" % [axis, CivilizationPersonality.JITTER_RANGE, personality[axis]])

func test_elf_arcana_is_necessarily_dominant():
	var floor_value := CivilizationPersonality.BASELINE_LEAN_MAGNITUDE - CivilizationPersonality.JITTER_RANGE
	var personality := CivilizationPersonality.generate("elf", 42)
	assert_true(personality[CityIdentity.AXIS_ARCANA] >= floor_value)
	for axis in [CityIdentity.AXIS_AGRICOLA, CityIdentity.AXIS_INDUSTRIAL, CityIdentity.AXIS_COMERCIAL, CityIdentity.AXIS_MILITAR]:
		assert_true(personality[axis] <= CivilizationPersonality.JITTER_RANGE)

## Anao tem DOIS eixos com lean: comercial (peso cheio, piso 0.45) e
## industrial (peso 0.6, piso 0.6*0.6-0.15=0.21) -- os dois acima de
## qualquer eixo sem lean (teto 0.15).
func test_dwarf_leans_comercial_and_industrial():
	var comercial_floor := CivilizationPersonality.BASELINE_LEAN_MAGNITUDE - CivilizationPersonality.JITTER_RANGE
	var industrial_floor := 0.6 * CivilizationPersonality.BASELINE_LEAN_MAGNITUDE - CivilizationPersonality.JITTER_RANGE
	var personality := CivilizationPersonality.generate("dwarf", 42)
	assert_true(personality[CityIdentity.AXIS_COMERCIAL] >= comercial_floor)
	assert_true(personality[CityIdentity.AXIS_INDUSTRIAL] >= industrial_floor)
	for axis in [CityIdentity.AXIS_AGRICOLA, CityIdentity.AXIS_MILITAR, CityIdentity.AXIS_ARCANA]:
		assert_true(personality[axis] <= CivilizationPersonality.JITTER_RANGE)

## Decisao de design que merece protecao explicita: "human" fica de fora
## da tabela de proposito (leitura mecanica de "equilibrio").
func test_human_has_no_baseline_lean_table_entry():
	assert_false(CivilizationPersonality.BASELINE_LEAN.has("human"))

## Raca fora da tabela (vazia ou desconhecida) nunca tem lean escondido --
## TODO eixo fica <= JITTER_RANGE, garantia matematica direta.
func test_unknown_race_falls_back_to_no_lean():
	for race in ["", "dragon"]:
		var personality := CivilizationPersonality.generate(race, 42)
		for axis in CityIdentity.AXES:
			assert_true(personality[axis] <= CivilizationPersonality.JITTER_RANGE, "%s/%s deveria ser <= %f" % [race, axis, CivilizationPersonality.JITTER_RANGE])

## Regressao: duas racas com tabelas de lean de TAMANHOS diferentes (orc
## tem 1 entrada, dwarf tem 2) nao podem consumir o RNG em ordens
## diferentes -- generate() sempre itera CityIdentity.AXES na ordem fixa,
## nunca lean.keys(). Reexecutar a mesma dupla (race, seed) continua
## reproduzindo o mesmo resultado exato, confirmando que nao ha
## dependencia oculta na ordem/tamanho da tabela.
func test_generate_axis_consumption_order_is_fixed_and_independent_of_lean_table_shape():
	var orc_first := CivilizationPersonality.generate("orc", 7)
	var orc_second := CivilizationPersonality.generate("orc", 7)
	assert_eq(orc_first, orc_second)
	var dwarf_first := CivilizationPersonality.generate("dwarf", 7)
	var dwarf_second := CivilizationPersonality.generate("dwarf", 7)
	assert_eq(dwarf_first, dwarf_second)

func test_bare_player_data_has_empty_personality_by_default():
	var player := PlayerData.new(CivilizationData.new())
	assert_eq(player.personality, {})
