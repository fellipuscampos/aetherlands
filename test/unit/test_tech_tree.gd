extends GutTest

## Cobre TechTree.gd — a visualizacao de VERDADE da arvore de tecnologia
## (pedido do usuario: os menus antigos "nao tinham nenhuma arvore", so
## uma fileira de botoes soltos). _compute_tiers() e a base do layout:
## cada tecnologia vira uma coluna (tier) igual a profundidade de
## pre-requisito ate a raiz, e as linhas do grafo desenhado em _draw()
## dependem dessas mesmas posicoes.

func test_compute_tiers_roots_have_no_prerequisite_are_tier_zero():
	var tree: TechTree = add_child_autofree(TechTree.new())
	var tiers = tree._compute_tiers()

	assert_eq(tiers["arcanismo_1"], 0)
	assert_eq(tiers["druidismo_1"], 0)
	assert_eq(tiers["sagrada_1"], 0)

func test_compute_tiers_respects_prerequisite_depth():
	var tree: TechTree = add_child_autofree(TechTree.new())
	var tiers = tree._compute_tiers()

	assert_eq(tiers["arcanismo_2"], 1, "depende de arcanismo_1 (tier 0)")
	assert_eq(tiers["druidismo_2"], 1, "depende de druidismo_1 (tier 0)")
	assert_eq(tiers["sagrada_2"], 1, "depende de sagrada_1 (tier 0)")
	assert_eq(tiers["arcanismo_3"], 2, "depende de arcanismo_2 (tier 1)")
	assert_eq(tiers["sagrada_3"], 2, "depende de sagrada_2 (tier 1)")
	assert_eq(tiers["sagrada_4"], 3, "depende de sagrada_3 (tier 2)")

func test_effect_summary_shows_unit_unlock():
	var tree: TechTree = add_child_autofree(TechTree.new())
	var invocacao_espiritos: TechData = MagicDatabase.get_tech("invocacao_espiritos")

	assert_eq(tree._effect_summary(invocacao_espiritos), "Desbloqueia: Mago")

func test_effect_summary_shows_yield_bonus():
	var tree: TechTree = add_child_autofree(TechTree.new())
	var alquimia_botanica: TechData = MagicDatabase.get_tech("alquimia_botanica")

	assert_eq(tree._effect_summary(alquimia_botanica), "+1 comida")

## rebuild() e o que monta os cards de verdade na arvore — cobre que cada
## tecnologia vira exatamente um card (child node) e que a posicao
## guardada em _node_rects bate com a coluna (tier) certa.
func test_rebuild_creates_one_card_per_technology():
	var tree: TechTree = add_child_autofree(TechTree.new())
	tree.rebuild({}, "", 0.0)

	assert_eq(tree.get_child_count(), TechDatabase.all_techs().size() + MagicDatabase.all_techs().size())

## Desde a separacao estrutural em TechDatabase/MagicDatabase, `category`
## escolhe qual BASE de dados a instancia usa (nao mais um filtro sobre uma
## unica base) — cada aba da HUD (Tecnologia/Magia) so deveria renderizar
## as techs da sua propria arvore, nunca as da outra.
func test_rebuild_with_doutrina_category_only_renders_tech_database_cards():
	var tree: TechTree = add_child_autofree(TechTree.new())
	tree.category = "doutrina"
	tree.rebuild({}, "", 0.0)

	assert_eq(tree.get_child_count(), TechDatabase.all_techs().size())
	for tech in MagicDatabase.all_techs():
		assert_false(tree._node_rects.has(tech.id), "%s e magica, nao deveria aparecer na arvore de Tecnologia" % tech.id)

func test_rebuild_with_magic_category_only_renders_magic_database_cards():
	var tree: TechTree = add_child_autofree(TechTree.new())
	tree.category = "magic"
	tree.rebuild({}, "", 0.0)

	assert_eq(tree.get_child_count(), MagicDatabase.all_techs().size())
	for tech in TechDatabase.all_techs():
		assert_false(tree._node_rects.has(tech.id), "%s e mundana, nao deveria aparecer na arvore de Magia" % tech.id)

func test_rebuild_positions_dependent_tech_in_a_later_column_than_its_prerequisite():
	var tree: TechTree = add_child_autofree(TechTree.new())
	tree.rebuild({}, "", 0.0)

	var sagrada_1_x = tree._node_rects["sagrada_1"].position.x
	var sagrada_2_x = tree._node_rects["sagrada_2"].position.x

	assert_gt(sagrada_2_x, sagrada_1_x, "sagrada_2 depende de sagrada_1, deveria ficar numa coluna mais a direita")

## Cobre _compute_rows: pedido do usuario ("a posicao dos cards esta
## errada... alinhar filho com o pai") — uma tech com UM SO pre-requisito e
## SEM disputa de linha (nenhuma outra tech do mesmo tier alinhando com o
## mesmo pai) deveria cair EXATAMENTE na mesma linha do proprio pai, nao
## mais espalhada por ordem alfabetica sem relacao com o pre-requisito.
func test_compute_rows_aligns_single_child_with_its_single_parent():
	var tree: TechTree = add_child_autofree(TechTree.new())
	var tiers = tree._compute_tiers()
	var rows = tree._compute_rows(tiers)

	# druidismo_2 e o UNICO filho de druidismo_1 em tier 1, entao
	# nao ha colisao pra empurrar ele pra outra linha.
	assert_eq(rows["druidismo_2"], rows["druidismo_1"], "druidismo_2 deveria alinhar com a linha de druidismo_1, seu unico pre-requisito")

## Regressao especifica do bug reportado: Quartel tem VARIOS filhos diretos
## (campo_de_tiro/homem_de_armas/estabulo/arsenal_de_cerco/homem_de_escudo,
## ver TechDatabase.gd — ancoras cosmeticas de prerequisites) — como eles
## nao podem ocupar a MESMA linha, pelo menos um precisa alinhar exatamente
## com Quartel (os outros sao empurrados pra baixo), mas nenhum fica muito
## longe da linha de Quartel.
func test_compute_rows_keeps_quartels_children_close_to_its_row():
	var tree: TechTree = add_child_autofree(TechTree.new())
	tree.category = "doutrina"
	var tiers = tree._compute_tiers()
	var rows = tree._compute_rows(tiers)

	var quartel_row: int = rows["quartel"]
	var children := ["campo_de_tiro", "homem_de_armas", "estabulo", "arsenal_de_cerco", "homem_de_escudo"]
	var aligned_exactly := false
	for child in children:
		if rows[child] == quartel_row:
			aligned_exactly = true
		assert_lte(abs(rows[child] - quartel_row), children.size(), "%s nao deveria ficar muito longe da linha do proprio pai (quartel)" % child)
	assert_true(aligned_exactly, "pelo menos um filho direto de quartel deveria alinhar exatamente com a linha dele")

## Regressao complementar: Muralhas e Torre de Vigia sao as DUAS opcoes do
## MESMO Nivel 5 (irmas, nao pai-filho — a ancora cosmetica de Torre de
## Vigia em Muralhas e so pra desenhar a linha de conexao entre as duas,
## ver TechDatabase.gd), entao disputam linha como raizes do grupo e NAO
## alinham entre si. Fortaleza (filho unico de Torre de Vigia, tier bem
## mais a frente, sem disputa de linha no proprio tier) e quem de fato
## deveria alinhar exatamente com a linha do "pai", formando um fluxo reto
## Torre de Vigia -> Fortaleza -> Fortaleza Imperial.
func test_compute_rows_aligns_fortaleza_with_torre_de_vigia():
	var tree: TechTree = add_child_autofree(TechTree.new())
	tree.category = "doutrina"
	var tiers = tree._compute_tiers()
	var rows = tree._compute_rows(tiers)

	assert_eq(rows["fortaleza"], rows["torre_de_vigia"], "fortaleza deveria alinhar com a linha de torre_de_vigia, seu unico pre-requisito")

## Pedido do usuario apos ver o resultado do alinhamento sozinho: "faca
## algo coeso, separe em grupo... nao faz sentido ta tudo misturado". Desde
## o redesenho de 10 niveis, a arvore de Tecnologia tem 3 grupos tematicos
## internos (militar, economia, defesa) mais 3 techs standalone (guarda/
## batedor/navegacao) — cada COMPONENTE CONEXO (ver _compute_components)
## ganha sua PROPRIA faixa de linhas exclusiva, entao nenhuma tech de um
## grupo deveria compartilhar linha com uma tech de outro grupo.
func test_compute_rows_separates_the_militar_group_from_the_economia_group():
	var tree: TechTree = add_child_autofree(TechTree.new())
	tree.category = "doutrina"
	var tiers = tree._compute_tiers()
	var rows = tree._compute_rows(tiers)

	var militar_kinds := ["quartel", "estabulo", "cavaleiro", "arsenal_de_cerco"]
	var militar_rows := {}
	for kind in militar_kinds:
		militar_rows[rows[kind]] = true

	var economia_kinds := ["celeiro", "oficina", "mercado", "mercador"]
	for kind in economia_kinds:
		assert_false(militar_rows.has(rows[kind]), "%s (grupo economia) nao deveria compartilhar linha com nenhuma tech do grupo militar" % kind)

## _compute_components: duas techs de "school" DIFERENTE mas ligadas por
## pre-requisito (Transmutacao de Rochas -> Forja Runica -> Constructos de
## Guerra, escolas Transmutacao/Transmutacao/Transmutacao... troque por um
## par de schools realmente diferentes: Invocacao de Espiritos e Lordes dos
## Ventos, Arcanismo -> Elementalismo) continuam no MESMO componente —
## agrupamento e por CONECTIVIDADE de pre-requisito, nao por "school".
func test_compute_components_groups_by_prerequisite_connectivity_not_by_school():
	var tree: TechTree = add_child_autofree(TechTree.new())
	var components = tree._compute_components()

	assert_eq(components["arcanismo_2"], components["arcanismo_3"], "escolas diferentes (Arcanismo/Elementalismo) mas ligadas por pre-requisito, deveriam ser o MESMO componente")
	assert_ne(components["quartel"], components["arcanismo_2"], "Tecnologia nao tem aresta nenhuma pra arvore de Magia, deveriam ser componentes DIFERENTES")

## Desde o redesenho de 10 niveis, o grupo "militar" (tronco principal da
## Tecnologia) e um so componente conexo bem maior — cobre so uma amostra
## representativa de nos espalhados por varios tiers, ligados por cadeia de
## ancoras cosmeticas (quartel -> estabulo -> estabulo_2 -> cavaleiro_
## imperial, ver TechDatabase.gd), ficando todos no MESMO componente que
## quartel. "economia" e "defesa" ficam em componentes DIFERENTES (nenhuma
## aresta cruzando os grupos).
func test_compute_components_keeps_the_militar_branch_together_and_separate_from_others():
	var tree: TechTree = add_child_autofree(TechTree.new())
	var components = tree._compute_components()

	assert_eq(components["quartel"], components["estabulo"])
	assert_eq(components["quartel"], components["arsenal_de_cerco"])
	assert_eq(components["quartel"], components["cavaleiro_imperial"])
	assert_eq(components["quartel"], components["exercito_supremo"])
	assert_ne(components["quartel"], components["celeiro"], "grupo economia deveria ser um componente separado do militar")
	assert_ne(components["quartel"], components["muralhas"], "grupo defesa deveria ser um componente separado do militar")

## Regressao de nao-sobreposicao: mesmo alinhando filhos com pais, duas
## techs do MESMO tier nunca deveriam acabar na MESMA linha (os cards se
## sobreporiam visualmente) — cobre o caso de colisao real (Estabulo E
## Arquearia disputando a linha de Quartel).
func test_compute_rows_never_assigns_the_same_row_to_two_techs_in_the_same_tier():
	var tree: TechTree = add_child_autofree(TechTree.new())
	var tiers = tree._compute_tiers()
	var rows = tree._compute_rows(tiers)

	var seen_rows_by_tier: Dictionary = {}
	for tech in TechDatabase.all_techs():
		var t: int = tiers[tech.id]
		var r: int = rows[tech.id]
		if not seen_rows_by_tier.has(t):
			seen_rows_by_tier[t] = []
		assert_false(r in seen_rows_by_tier[t], "%s colidiu com outra tech na mesma linha (%d) do tier %d" % [tech.id, r, t])
		seen_rows_by_tier[t].append(r)

## Coleta o texto de todo Label descendente de `node` — usado pelos testes
## de reskin racial abaixo pra confirmar que o nome TEMATICO aparece de
## verdade nos cards renderizados (nao so na tabela do RaceTheme).
func _collect_label_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	for child in node.get_children():
		if child is Label:
			texts.append(child.text)
		texts.append_array(_collect_label_texts(child))
	return texts

## Pedido do usuario: "essa arvore de tecnologia humana que fizemos, eu
## quero que faca uma equivalente pra cada civilizacao... mudando o nome
## das tropas e aparencia" — rebuild() recebe a raca do jogador humano e
## precisa mostrar o nome TEMATICO no card, nao o nome cru de TechData.
func test_rebuild_uses_the_race_themed_tech_name():
	var tree: TechTree = add_child_autofree(TechTree.new())
	tree.rebuild({}, "", 0.0, "dwarf")

	var texts := _collect_label_texts(tree)
	assert_true(RaceTheme.tech_name("quartel", "dwarf") in texts, "deveria mostrar o nome tematico do anao pra quartel")
	assert_false("Quartel" in texts, "nome humano cru nao deveria aparecer pra um jogador anao")

## Default da raca ("human") preserva o comportamento de sempre — cobre
## quem chama rebuild() sem o 4o parametro (mesmo padrao dos testes
## antigos acima, ver test_rebuild_creates_one_card_per_technology).
func test_rebuild_defaults_to_human_names_when_race_is_omitted():
	var tree: TechTree = add_child_autofree(TechTree.new())
	tree.rebuild({}, "", 0.0)

	var texts := _collect_label_texts(tree)
	assert_true("Quartel" in texts)

func test_effect_summary_uses_the_race_themed_unit_name():
	var tree: TechTree = add_child_autofree(TechTree.new())
	var arqueiro: TechData = TechDatabase.get_tech("arqueiro")

	assert_eq(tree._effect_summary(arqueiro, "elf"), "Desbloqueia: %s" % RaceTheme.unit_name("archer", "elf"))
