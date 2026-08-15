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

	assert_eq(tiers["canalizacao_base"], 0)
	assert_eq(tiers["alquimia_botanica"], 0)
	assert_eq(tiers["transmutacao_rocha"], 0)
	tree.queue_free()

func test_compute_tiers_respects_prerequisite_depth():
	var tree := TechTree.new()
	var tiers = tree._compute_tiers()

	assert_eq(tiers["invocacao_espiritos"], 1, "depende de canalizacao_base (tier 0)")
	assert_eq(tiers["pacto_florestal"], 1, "depende de alquimia_botanica (tier 0)")
	assert_eq(tiers["forja_runica"], 1, "depende de transmutacao_rocha (tier 0)")
	assert_eq(tiers["lordes_dos_ventos"], 2, "depende de invocacao_espiritos (tier 1)")
	assert_eq(tiers["constructos_de_guerra"], 2, "depende de forja_runica (tier 1)")
	assert_eq(tiers["cataclismo_elemental"], 3, "depende de constructos_de_guerra (tier 2)")
	tree.queue_free()

func test_effect_summary_shows_unit_unlock():
	var tree := TechTree.new()
	var invocacao_espiritos: TechData = TechDatabase.get_tech("invocacao_espiritos")

	assert_eq(tree._effect_summary(invocacao_espiritos), "Desbloqueia: Mago")
	tree.queue_free()

func test_effect_summary_shows_yield_bonus():
	var tree := TechTree.new()
	var alquimia_botanica: TechData = TechDatabase.get_tech("alquimia_botanica")

	assert_eq(tree._effect_summary(alquimia_botanica), "+1 comida")
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

	var transmutacao_rocha_x = tree._node_rects["transmutacao_rocha"].position.x
	var forja_runica_x = tree._node_rects["forja_runica"].position.x

	assert_gt(forja_runica_x, transmutacao_rocha_x, "forja_runica depende de transmutacao_rocha, deveria ficar numa coluna mais a direita")
	tree.queue_free()
