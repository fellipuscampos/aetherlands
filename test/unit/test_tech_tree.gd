extends GutTest

## Cobre TechTree.gd — a visualizacao de VERDADE da arvore de tecnologia
## (pedido do usuario: os menus antigos "nao tinham nenhuma arvore", so
## uma fileira de botoes soltos). _compute_tiers() e a base do layout:
## cada tecnologia vira uma coluna (tier) igual a profundidade de
## pre-requisito ate a raiz, e as linhas do grafo desenhado em _draw()
## dependem dessas mesmas posicoes.

func test_compute_tiers_roots_have_no_prerequisite_are_tier_zero():
	var tree := TechTree.new()
	var tiers = tree._compute_tiers()

	assert_eq(tiers["agriculture"], 0)
	assert_eq(tiers["mining"], 0)
	assert_eq(tiers["archery"], 0)
	assert_eq(tiers["animal_husbandry"], 0)
	assert_eq(tiers["arcane_studies"], 0)
	assert_eq(tiers["druidism"], 0)
	tree.queue_free()

func test_compute_tiers_respects_prerequisite_depth():
	var tree := TechTree.new()
	var tiers = tree._compute_tiers()

	assert_eq(tiers["horseback_riding"], 1, "depende de animal_husbandry (tier 0)")
	assert_eq(tiers["irrigation"], 1, "depende de agriculture (tier 0)")
	assert_eq(tiers["metalworking"], 1, "depende de mining (tier 0)")
	assert_eq(tiers["engineering"], 2, "depende de metalworking (tier 1)")
	assert_eq(tiers["griffin_training"], 2, "depende de horseback_riding (tier 1)")
	tree.queue_free()

func test_effect_summary_shows_unit_unlock():
	var tree := TechTree.new()
	var archery: TechData = TechDatabase.get_tech("archery")

	assert_eq(tree._effect_summary(archery), "Desbloqueia: Arqueiro")
	tree.queue_free()

func test_effect_summary_shows_yield_bonus():
	var tree := TechTree.new()
	var agriculture: TechData = TechDatabase.get_tech("agriculture")

	assert_eq(tree._effect_summary(agriculture), "+1 comida")
	tree.queue_free()

## rebuild() e o que monta os cards de verdade na arvore — cobre que cada
## tecnologia vira exatamente um card (child node) e que a posicao
## guardada em _node_rects bate com a coluna (tier) certa.
func test_rebuild_creates_one_card_per_technology():
	var tree := TechTree.new()
	tree.rebuild({}, "", 0.0)

	assert_eq(tree.get_child_count(), TechDatabase.all_techs().size())
	tree.queue_free()

func test_rebuild_positions_dependent_tech_in_a_later_column_than_its_prerequisite():
	var tree := TechTree.new()
	tree.rebuild({}, "", 0.0)

	var mining_x = tree._node_rects["mining"].position.x
	var metalworking_x = tree._node_rects["metalworking"].position.x

	assert_gt(metalworking_x, mining_x, "metalworking depende de mining, deveria ficar numa coluna mais a direita")
	tree.queue_free()
