extends GutTest

## Cobre WorldEventTrigger (Blocker #1 do contrato comportamental do
## Dragao, docs/DRAGON_EVENT_DESIGN.md): QUANDO o mundo cria um evento --
## deliberadamente separado de COMO o evento se comporta depois (isso e'
## WorldEvent/DragonEvent, ja coberto em outros arquivos). RNG proprio,
## independente do RNG de evento (que precisa de event_id, inexistente
## neste ponto) e do RNG global de decisao de IA.

var hex_grid: HexGrid
var _created_hex_grids: Array[HexGrid] = []

func before_each():
	_created_hex_grids = []
	hex_grid = HexGrid.new()
	hex_grid._ready()
	for x in range(5):
		for y in range(5):
			hex_grid.tiles[Vector2i(x, y)] = TerrainDatabase.create_tile(HexTileData.TerrainType.GRASSLAND)
	_created_hex_grids.append(hex_grid)

func after_each():
	for grid in _created_hex_grids:
		if is_instance_valid(grid):
			grid.queue_free()

## --- should_spawn_dragon ----------------------------------------------------

func test_should_spawn_dragon_is_always_false_before_the_minimum_turn():
	for turn in range(WorldEventTrigger.DRAGON_TRIGGER_MIN_TURN):
		assert_false(WorldEventTrigger.should_spawn_dragon(12345, turn), "turno %d e antes do minimo, nunca deveria disparar" % turn)

func test_should_spawn_dragon_is_deterministic_for_the_same_inputs():
	var turn := WorldEventTrigger.DRAGON_TRIGGER_MIN_TURN + 5
	var first := WorldEventTrigger.should_spawn_dragon(12345, turn)
	var second := WorldEventTrigger.should_spawn_dragon(12345, turn)
	assert_eq(first, second)

## Confirma que a condicao realmente LE o RNG (nunca um valor fixo/sempre-
## verdadeiro-ou-falso disfarcado) sem depender de estatistica sobre
## CHANCE_PER_TURN=2% -- amostrar o resultado BINARIO de poucas seeds pra
## uma chance tao baixa seria flaky por construcao (~36% de chance de nunca
## bater "true" em so 50 amostras mesmo com o codigo correto). Em vez
## disso, confirma direto que o valor CONTINUO por tras do corte
## (trigger_rng(...).randf()) varia entre seeds -- suficiente e nao-flaky.
func test_should_spawn_dragon_reads_a_varying_rng_value_across_seeds():
	var turn := WorldEventTrigger.DRAGON_TRIGGER_MIN_TURN + 5
	var rolls := {}
	for seed_value in range(10):
		rolls[WorldEventTrigger.trigger_rng(seed_value, DragonEvent.EVENT_TYPE, turn).randf()] = true
	assert_gt(rolls.size(), 1, "seeds diferentes deveriam produzir rolls diferentes, senao a condicao nao esta realmente lendo o RNG")

## O requisito mais importante: o RNG do trigger nao pode ser afetado por
## quanto o RNG global de IA (RivalAI.decide_war/decide_trade) ja consumiu
## -- mesma disciplina ja provada pra WorldEvent.event_rng().
func test_should_spawn_dragon_is_independent_of_global_ai_rng_activity():
	var turn := WorldEventTrigger.DRAGON_TRIGGER_MIN_TURN + 5
	var baseline := WorldEventTrigger.should_spawn_dragon(999, turn)

	randomize()
	for i in range(50):
		randi()

	var after_global_rng_usage := WorldEventTrigger.should_spawn_dragon(999, turn)
	assert_eq(baseline, after_global_rng_usage, "consumir o RNG global nao deveria alterar a decisao de trigger")

## --- choose_dragon_origin_region --------------------------------------------

func test_choose_dragon_origin_region_returns_a_real_tile_from_the_grid():
	var region := WorldEventTrigger.choose_dragon_origin_region(12345, 40, hex_grid)
	assert_true(hex_grid.tiles.has(region), "a regiao de origem deveria ser um tile que realmente existe no mapa")

func test_choose_dragon_origin_region_is_deterministic_for_the_same_inputs():
	var first := WorldEventTrigger.choose_dragon_origin_region(12345, 40, hex_grid)
	var second := WorldEventTrigger.choose_dragon_origin_region(12345, 40, hex_grid)
	assert_eq(first, second)

## --- Independencia da familia de RNG (contrato, "consequencia de
## determinismo") -- o trigger ocorre ANTES de existir event_id, entao seu
## RNG tem que ser uma familia SEPARADA da de WorldEvent.event_rng.
func test_trigger_rng_is_a_different_sequence_from_a_plain_seed_of_the_same_numbers():
	var trigger_roll := WorldEventTrigger.trigger_rng(12345, "dragon", 40).randi()
	var event_roll := WorldEvent.new().event_rng(12345, 40).randi() # event_id default -1, mas ainda assim uma formula DIFERENTE (nao usa event_type)
	# Nao afirma que os dois valores tem que ser diferentes matematicamente
	# (poderia coincidir por acaso) -- confirma so que sao CHAMADAS/formulas
	# distintas, uma dependendo de event_type (string), a outra de event_id
	# (int), nunca a mesma funcao reaproveitada por acidente.
	assert_ne(WorldEventTrigger.trigger_rng(12345, "dragon", 40).seed, WorldEvent.new().event_rng(12345, 40).seed, "a semente do RNG de trigger e a de RNG de evento deveriam vir de formulas diferentes")
