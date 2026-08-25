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

## Cobre _compute_rows: pedido do usuario ("a posicao dos cards esta
## errada... alinhar filho com o pai") — uma tech com UM SO pre-requisito e
## SEM disputa de linha (nenhuma outra tech do mesmo tier alinhando com o
## mesmo pai) deveria cair EXATAMENTE na mesma linha do proprio pai, nao
## mais espalhada por ordem alfabetica sem relacao com o pre-requisito.
func test_compute_rows_aligns_single_child_with_its_single_parent():
	var tree := TechTree.new()
	var tiers = tree._compute_tiers()
	var rows = tree._compute_rows(tiers)

	# pacto_florestal e o UNICO filho de alquimia_botanica em tier 1, entao
	# nao ha colisao pra empurrar ele pra outra linha.
	assert_eq(rows["pacto_florestal"], rows["alquimia_botanica"], "pacto_florestal deveria alinhar com a linha de alquimia_botanica, seu unico pre-requisito")
	tree.queue_free()

## Regressao especifica do bug reportado: Quartel tem DOIS filhos diretos
## (Estabulo e Arquearia) — como os dois nao podem ocupar a MESMA linha,
## pelo menos um deles precisa alinhar exatamente com Quartel (o outro e
## empurrado pra baixo), mas os DOIS continuam mais perto da linha de
## Quartel do que estariam com ordenacao alfabetica pura (que podia
## colocar Quartel na linha 2 e Estabulo/Arquearia em linhas distantes,
## misturadas com techs de magia sem relacao nenhuma no meio).
func test_compute_rows_keeps_quartels_children_close_to_its_row():
	var tree := TechTree.new()
	var tiers = tree._compute_tiers()
	var rows = tree._compute_rows(tiers)

	var quartel_row: int = rows["quartel"]
	assert_true(rows["estabulo"] == quartel_row or rows["arquearia"] == quartel_row, "pelo menos um filho direto de quartel deveria alinhar exatamente com a linha dele")
	assert_lte(abs(rows["estabulo"] - quartel_row), 1, "estabulo nao deveria ficar mais de 1 linha longe do proprio pai (quartel)")
	assert_lte(abs(rows["arquearia"] - quartel_row), 1, "arquearia nao deveria ficar mais de 1 linha longe do proprio pai (quartel)")
	tree.queue_free()

## Regressao complementar: Batedor Montado (filho unico de Estabulo) deveria
## alinhar exatamente com a linha de Estabulo, formando um fluxo reto
## Quartel -> Estabulo -> Batedor Montado (a "ramificacao" que o usuario
## pediu pra ficar legivel, em vez de ziguezaguear pela arvore).
func test_compute_rows_aligns_batedor_montado_with_estabulo():
	var tree := TechTree.new()
	var tiers = tree._compute_tiers()
	var rows = tree._compute_rows(tiers)

	assert_eq(rows["batedor_montado"], rows["estabulo"], "batedor_montado deveria alinhar com a linha de estabulo, seu unico pre-requisito")
	tree.queue_free()

## Pedido do usuario apos ver o resultado do alinhamento sozinho: "faca
## algo coeso, separe em grupo, nesse caso o grupo da doutrina fica
## separado dos demais... nao faz sentido ta tudo misturado". Doutrina
## (Quartel/Estabulo/Arquearia/Batedor Montado) e um COMPONENTE CONEXO
## isolado do resto da arvore (nenhuma aresta de pre-requisito liga ele a
## qualquer tech magica) — nenhuma tech FORA desse grupo deveria
## compartilhar linha com NENHUMA tech DENTRO dele, mesmo nos tiers em que
## os dois tem cards (ex: os dois tem tier 0). Nao assume que "o resto" e
## um bloco so: a arvore magica em si ja e 3 componentes independentes
## (raiz em canalizacao_base/alquimia_botanica/transmutacao_rocha, sem
## aresta nenhuma ligando um ao outro) — cada bloco ganha sua PROPRIA faixa
## de linhas exclusiva, entao a checagem certa e "nenhuma linha em comum",
## nao "todos numa direcao so".
func test_compute_rows_separates_the_doutrina_group_from_the_magic_group():
	var tree := TechTree.new()
	var tiers = tree._compute_tiers()
	var rows = tree._compute_rows(tiers)

	var doutrina_kinds := ["quartel", "estabulo", "arquearia", "batedor_montado"]
	var doutrina_rows := {}
	for kind in doutrina_kinds:
		doutrina_rows[rows[kind]] = true

	for tech in TechDatabase.all_techs():
		if tech.id in doutrina_kinds:
			continue
		assert_false(doutrina_rows.has(rows[tech.id]), "%s (fora do grupo Doutrina) nao deveria compartilhar linha com nenhuma tech do grupo Doutrina" % tech.id)
	tree.queue_free()

## _compute_components: duas techs de "school" DIFERENTE mas ligadas por
## pre-requisito (Transmutacao de Rochas -> Forja Runica -> Constructos de
## Guerra, escolas Transmutacao/Transmutacao/Transmutacao... troque por um
## par de schools realmente diferentes: Invocacao de Espiritos e Lordes dos
## Ventos, Arcanismo -> Elementalismo) continuam no MESMO componente —
## agrupamento e por CONECTIVIDADE de pre-requisito, nao por "school".
func test_compute_components_groups_by_prerequisite_connectivity_not_by_school():
	var tree := TechTree.new()
	var components = tree._compute_components()

	assert_eq(components["invocacao_espiritos"], components["lordes_dos_ventos"], "escolas diferentes (Arcanismo/Elementalismo) mas ligadas por pre-requisito, deveriam ser o MESMO componente")
	assert_ne(components["quartel"], components["invocacao_espiritos"], "Doutrina nao tem aresta nenhuma pra arvore magica, deveriam ser componentes DIFERENTES")

func test_compute_components_keeps_the_whole_doutrina_branch_together():
	var tree := TechTree.new()
	var components = tree._compute_components()

	assert_eq(components["quartel"], components["estabulo"])
	assert_eq(components["quartel"], components["arquearia"])
	assert_eq(components["quartel"], components["batedor_montado"])

## Regressao de nao-sobreposicao: mesmo alinhando filhos com pais, duas
## techs do MESMO tier nunca deveriam acabar na MESMA linha (os cards se
## sobreporiam visualmente) — cobre o caso de colisao real (Estabulo E
## Arquearia disputando a linha de Quartel).
func test_compute_rows_never_assigns_the_same_row_to_two_techs_in_the_same_tier():
	var tree := TechTree.new()
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
	tree.queue_free()

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
	var tree := TechTree.new()
	tree.rebuild({}, "", 0.0, "dwarf")

	var texts := _collect_label_texts(tree)
	assert_true(RaceTheme.tech_name("quartel", "dwarf") in texts, "deveria mostrar o nome tematico do anao pra quartel")
	assert_false("Quartel" in texts, "nome humano cru nao deveria aparecer pra um jogador anao")
	tree.queue_free()

## Default da raca ("human") preserva o comportamento de sempre — cobre
## quem chama rebuild() sem o 4o parametro (mesmo padrao dos testes
## antigos acima, ver test_rebuild_creates_one_card_per_technology).
func test_rebuild_defaults_to_human_names_when_race_is_omitted():
	var tree := TechTree.new()
	tree.rebuild({}, "", 0.0)

	var texts := _collect_label_texts(tree)
	assert_true("Quartel" in texts)
	tree.queue_free()

func test_effect_summary_uses_the_race_themed_unit_name():
	var tree := TechTree.new()
	var arquearia: TechData = TechDatabase.get_tech("arquearia")

	assert_eq(tree._effect_summary(arquearia, "elf"), "Desbloqueia: %s" % RaceTheme.unit_name("archer", "elf"))
	tree.queue_free()
