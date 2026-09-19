extends GutTest

## Cobre TechTierBoard.gd — a visualizacao "tier-band" da arvore de
## Tecnologia MUNDANA (Roadmap "polimento e coesao"): 10 faixas horizontais
## (uma por nivel), texto de bloqueio no CABECALHO do nivel (nunca "Requer
## <tech especifica>" por card), contador de progresso "X/2 pra liberar o
## proximo nivel", classificacao de familia (so apresentacao) e filtro (so
## apresentacao, nunca disponibilidade real). A arvore de Magia continua em
## TechTree.gd, testada em test_tech_tree.gd — nao repetido aqui.

func _card(board: TechTierBoard, tier: int, tech_id: String) -> Control:
	var block: Control = board.level_block(tier)
	return block.find_child("Card_%s" % tech_id, true, false) if block else null

func _label_text(node: Control, label_name: String) -> String:
	var label: Label = node.find_child(label_name, true, false) if node else null
	return label.text if label else ""

func test_rebuild_creates_exactly_10_level_blocks():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	assert_eq(board.get_child_count(), 10)
	for tier in range(1, 11):
		assert_not_null(board.level_block(tier), "Nivel %d deveria ter um bloco" % tier)
	board.queue_free()

## Item 10 do pedido: a UI nao mistura tecnologias de tiers diferentes — o
## bloco do Nivel N so contem cards de techs com tech.tier == N.
func test_ui_never_mixes_technologies_from_different_tiers():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	for tier in range(1, 11):
		var block: Control = board.level_block(tier)
		for tech in TechDatabase.all_techs():
			var card := block.find_child("Card_%s" % tech.id, true, false)
			if tech.tier == tier:
				assert_not_null(card, "%s (Nivel %d) deveria aparecer no bloco do Nivel %d" % [tech.id, tech.tier, tier])
			else:
				assert_null(card, "%s (Nivel %d) NAO deveria aparecer no bloco do Nivel %d" % [tech.id, tech.tier, tier])
	board.queue_free()

## Item 3: Nivel 1 aparece inicialmente desbloqueado — cards clicaveis
## (Roadmap "so o essencial": nao existe mais banner nenhum de bloqueio no
## cabecalho, so o titulo — ver test_level_header_has_only_the_title_no_
## progress_or_lock_text; o estado bloqueado/aberto e comunicado so pelos
## proprios cards agora).
func test_level_1_starts_unlocked_with_clickable_cards():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	var card := _card(board, 1, "guarda")
	assert_gt(card.gui_input.get_connections().size(), 0, "Nivel 1 deveria ter cards clicaveis desde o inicio")
	board.queue_free()

## Item 4: Nivel 2 permanece bloqueado (cards nao clicaveis) com so 1
## pesquisa do Nivel 1.
func test_level_2_stays_locked_with_only_one_tier_1_research():
	var board := TechTierBoard.new()
	board.rebuild({"quartel": true}, "", 0.0)

	var card := _card(board, 2, "homem_de_armas")
	assert_eq(card.gui_input.get_connections().size(), 0, "Nivel 2 deveria continuar bloqueado (nao clicavel) com so 1 pesquisa do Nivel 1")
	board.queue_free()

## Item 5: Nivel 2 e liberado (cards clicaveis) com 2 pesquisas do Nivel 1.
func test_level_2_unlocks_with_two_tier_1_researches():
	var board := TechTierBoard.new()
	board.rebuild({"quartel": true, "celeiro": true}, "", 0.0)

	var card := _card(board, 2, "homem_de_armas")
	assert_gt(card.gui_input.get_connections().size(), 0, "Nivel 2 deveria estar clicavel com 2 pesquisas do Nivel 1")
	board.queue_free()

## Item 6: nivel anterior continua disponivel (cards do Nivel 1 continuam
## selecionaveis) depois do Nivel 2 ser liberado.
func test_earlier_level_cards_remain_selectable_after_next_level_unlocks():
	var board := TechTierBoard.new()
	board.rebuild({"quartel": true, "celeiro": true}, "", 0.0)

	var card := _card(board, 1, "guarda")
	assert_eq(card.gui_input.get_connections().size(), 1, "Guarda (Nivel 1, ainda nao pesquisada) deveria continuar clicavel")
	board.queue_free()

## Item 7: card bloqueado mostra o motivo CORRETO — nunca "Requer <tech
## especifica>", so o estado visual (sem banner por card, ver comentario de
## TechTierBoard._build_card). O motivo de verdade fica so no cabecalho do
## nivel (ja coberto acima).
func test_locked_card_never_shows_a_specific_prerequisite_text():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0) # Nivel 2+ todos bloqueados

	var card := _card(board, 2, "homem_de_armas")
	var texts: Array[String] = []
	for child in card.get_children():
		_collect_label_texts(child, texts)
	for t in texts:
		assert_false(t.begins_with("Requer:"), "card nao deveria mostrar 'Requer: <tech>' — texto encontrado: %s" % t)
	board.queue_free()

func _collect_label_texts(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append(node.text)
	for child in node.get_children():
		_collect_label_texts(child, out)

## Roadmap "tela cheia": card virou UMA linha so ("Nome — Tipo"), status
## por extenso saiu do corpo e mora so no tooltip agora (ver testes de
## tooltip mais abaixo). No corpo, pesquisada ganha um "✓" no final do
## NameLabel — unico sinal textual de estado que sobrou no card em si.
func test_card_shows_researched_checkmark_in_the_name_label():
	var board := TechTierBoard.new()
	board.rebuild({"quartel": true}, "celeiro", 5.0)

	assert_true(_label_text(_card(board, 1, "quartel"), "NameLabel").ends_with("✓"))
	assert_false(_label_text(_card(board, 1, "celeiro"), "NameLabel").ends_with("✓"), "pesquisando ainda nao e pesquisada, nao deveria ter check")
	board.queue_free()

## Tooltip carrega o status por extenso agora (Roadmap "tela cheia" —
## "ao passar o mouse aparece tudo: custa tanto, o que é, etc").
func test_card_tooltip_shows_status_and_cost():
	var board := TechTierBoard.new()
	board.rebuild({"quartel": true}, "celeiro", 5.0)

	assert_true("Pesquisada" in _card(board, 1, "quartel").tooltip_text)
	assert_true("Pesquisando: 5/13 ciência" in _card(board, 1, "celeiro").tooltip_text)
	board.queue_free()

func test_card_tooltip_shows_available_status_with_cost():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0) # Nivel 1 aberto, nada pesquisado/pesquisando

	assert_true("Disponível · 13 ciência" in _card(board, 1, "quartel").tooltip_text)
	board.queue_free()

func test_card_tooltip_shows_blocked_status_for_a_locked_level():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0) # Nivel 2+ todos bloqueados

	assert_true("Bloqueada" in _card(board, 2, "homem_de_armas").tooltip_text)
	board.queue_free()

## Item 9: contador do nivel mostra progresso correto em 0/1/2 pesquisas.
## Um board FRESCO por chamada de proposito: rebuild() usa queue_free() nos
## filhos antigos (deferido pro fim do frame, nao imediato) — correto pra
## producao (evita liberar um card no meio do proprio evento de clique dele,
## ver comentario de TechTierBoard.rebuild), mas chamar rebuild() varias
## vezes SEGUIDAS no mesmo board dentro de um teste (sem nenhum frame
## processado entre elas) leria os nos ANTIGOS ainda vivos via
## level_block()/get_child(). Board novo por chamada evita o problema sem
## mexer no `queue_free()` da producao.
## Roadmap "so o essencial": nenhum texto de progresso/bloqueio sobra no
## cabecalho do nivel (pedido explicito: "tire esse 0/2, todos precisam de
## 0/2 pra passar entao e indiferente ter isso") — o header vira SO o
## titulo. A mecanica em si (TechDatabase.is_tier_unlocked) continua
## identica, so o texto que anunciava o numero desapareceu.
func test_level_header_has_only_the_title_no_progress_or_lock_text():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0) # Nivel 2 bloqueado, Nivel 1 aberto

	for tier in [1, 2, 10]:
		var block: Control = board.level_block(tier)
		var header: Control = block.get_child(0).get_child(0)
		assert_eq(header.get_child_count(), 1, "Nivel %d deveria ter so o titulo no cabecalho" % tier)
	board.queue_free()

## Item 11: filtro por familia NAO altera disponibilidade real — os cards
## de um nivel BLOQUEADO continuam nao-clicaveis, filtrado ou nao.
func test_family_filter_does_not_change_real_availability():
	# Board separado por rebuild() de proposito — ver comentario de
	# test_level_counter_shows_correct_progress sobre queue_free() deferido.
	var board_unfiltered := TechTierBoard.new()
	board_unfiltered.rebuild({"quartel": true, "celeiro": true}, "", 0.0) # abre Nivel 2, Nivel 3 continua bloqueado
	assert_not_null(_card(board_unfiltered, 2, "homem_de_armas"))
	var estabulo_unfiltered := _card(board_unfiltered, 3, "estabulo") # Militar
	assert_eq(estabulo_unfiltered.gui_input.get_connections().size(), 0, "Nivel 3 deveria estar bloqueado (nao clicavel)")
	board_unfiltered.queue_free()

	# Filtra so Economia: o card MILITAR some do Nivel 2, e o card
	# ECONOMICO do Nivel 3 (que o filtro mantem visivel) continua IGUALMENTE
	# bloqueado — a disponibilidade real nao muda so por causa do filtro.
	var board_filtered := TechTierBoard.new()
	board_filtered.active_family_filter = TechTierBoard.FAMILY_ECONOMIA
	board_filtered.rebuild({"quartel": true, "celeiro": true}, "", 0.0)
	assert_null(_card(board_filtered, 2, "homem_de_armas"), "filtro Economia deveria esconder o card militar")
	assert_not_null(_card(board_filtered, 2, "oficina"), "filtro Economia deveria continuar mostrando o card economico")
	var mercado_filtered := _card(board_filtered, 3, "mercado") # Economia
	assert_not_null(mercado_filtered, "filtro Economia deveria continuar mostrando o card economico do Nivel 3")
	assert_eq(mercado_filtered.gui_input.get_connections().size(), 0, "Nivel 3 deveria continuar bloqueado mesmo filtrado")
	board_filtered.queue_free()

## Classificacao de familia (Roadmap "polimento definitivo V1" — agora dado
## REAL em TechData.display_family, nao mais um dict hardcoded na UI) —
## cobertura por amostragem dos 4 baldes.
func test_family_classification_samples():
	assert_eq(TechDatabase.get_tech("quartel").display_family, TechTierBoard.FAMILY_MILITAR)
	assert_eq(TechDatabase.get_tech("guarda").display_family, TechTierBoard.FAMILY_MILITAR)
	assert_eq(TechDatabase.get_tech("celeiro").display_family, TechTierBoard.FAMILY_ECONOMIA)
	assert_eq(TechDatabase.get_tech("mercador").display_family, TechTierBoard.FAMILY_EXPLORACAO)
	assert_eq(TechDatabase.get_tech("muralhas").display_family, TechTierBoard.FAMILY_DEFESA)
	assert_eq(TechDatabase.get_tech("batedor").display_family, TechTierBoard.FAMILY_EXPLORACAO)
	assert_eq(TechDatabase.get_tech("general").display_family, TechTierBoard.FAMILY_MILITAR)
	# 3 reclassificacoes pedidas na revisao do plano (so o dado muda, tier/
	# custo/unlocks continuam identicos):
	assert_eq(TechDatabase.get_tech("estabulo_2").display_family, TechTierBoard.FAMILY_ECONOMIA, "estabulo_2 so desbloqueia predio, mesmo padrao de oficina_2")
	assert_eq(TechDatabase.get_tech("quartel_de_elite").display_family, TechTierBoard.FAMILY_EXPLORACAO, "quartel_de_elite so desbloqueia predio, mesmo padrao de grande_arsenal")
	assert_eq(TechDatabase.get_tech("lanceiro").display_family, TechTierBoard.FAMILY_DEFESA)

func test_every_technology_has_a_family_classification():
	for tech in TechDatabase.all_techs():
		assert_true(tech.display_family in TechTierBoard.FAMILY_ORDER, "%s deveria ter uma display_family valida" % tech.id)

func test_family_counts_match_the_documented_distribution():
	var counts := {TechTierBoard.FAMILY_MILITAR: 0, TechTierBoard.FAMILY_ECONOMIA: 0, TechTierBoard.FAMILY_DEFESA: 0, TechTierBoard.FAMILY_EXPLORACAO: 0}
	for tech in TechDatabase.all_techs():
		if counts.has(tech.display_family):
			counts[tech.display_family] += 1
	assert_eq(counts[TechTierBoard.FAMILY_MILITAR], 27)
	assert_eq(counts[TechTierBoard.FAMILY_ECONOMIA], 11)
	assert_eq(counts[TechTierBoard.FAMILY_DEFESA], 9)
	assert_eq(counts[TechTierBoard.FAMILY_EXPLORACAO], 8)

## Regra dura do pedido (revisao do plano): nenhum nivel pode ficar 100% de
## uma unica familia — Niveis 4 e 7 eram assim antes desta rodada.
func test_no_level_is_100_percent_a_single_family():
	var by_tier: Dictionary = {}
	for tech in TechDatabase.all_techs():
		if not by_tier.has(tech.tier):
			by_tier[tech.tier] = {}
		var fam_counts: Dictionary = by_tier[tech.tier]
		fam_counts[tech.display_family] = fam_counts.get(tech.display_family, 0) + 1
	for tier in by_tier.keys():
		var fam_counts: Dictionary = by_tier[tier]
		var total := 0
		for fam in fam_counts:
			total += fam_counts[fam]
		for fam in fam_counts:
			assert_lt(fam_counts[fam], total, "Nivel %d nao deveria ser 100%% %s" % [tier, fam])

## Tipo do card — Construcao/Melhoria-Upgrade/Unidade/Utilidade-Flag.
func test_tech_type_label_classification():
	var board := TechTierBoard.new()
	assert_eq(board._tech_type_label(TechDatabase.get_tech("quartel")), "Construção")
	assert_eq(board._tech_type_label(TechDatabase.get_tech("quartel_2")), "Melhoria/Upgrade")
	assert_eq(board._tech_type_label(TechDatabase.get_tech("guarda")), "Unidade")
	assert_eq(board._tech_type_label(TechDatabase.get_tech("navegacao")), "Utilidade/Flag")
	board.queue_free()

## Roadmap "tela cheia": effect_text saiu do corpo do card e mora no
## tooltip agora, junto do resto ("ao passar o mouse aparece tudo").
func test_card_tooltip_shows_honest_effect_text():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	var expected := "Efeito: %s" % TechDatabase.get_tech("quartel").effect_text
	assert_true(expected in _card(board, 1, "quartel").tooltip_text)
	board.queue_free()

## General e um caso honesto explicito do pedido: a mecanica de aura ainda
## nao existe, o effect_text tem que deixar isso claro (nunca prometer o
## efeito), mas continua aparecendo no card normalmente.
func test_general_effect_text_describes_the_implemented_aura():
	var text: String = TechDatabase.get_tech("general").effect_text
	assert_true(text.length() > 0)
	assert_true("25%" in text and "2 hexágonos" in text, "A descrição deve explicar o bônus real e sua proximidade.")

## Item da revisao do plano: "liga-se a" saiu do CORPO do card e virou
## tooltip — card.tooltip_text carrega a ancora cosmetica, nunca um Label
## visivel dentro do card.
func test_prerequisite_anchor_lives_in_tooltip_not_in_card_body():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	var card := _card(board, 2, "campo_de_tiro") # prerequisites = ["quartel"]
	assert_true("Liga-se a" in card.tooltip_text, "tooltip deveria carregar a ancora cosmetica")

	var texts: Array[String] = []
	_collect_label_texts(card, texts)
	for t in texts:
		assert_false(t.begins_with("liga-se a") or t.begins_with("Liga-se a"), "corpo do card nao deveria mostrar 'liga-se a' — encontrado: %s" % t)
	board.queue_free()

## Pedido explicito "polimento definitivo V1": nenhum emoji em lugar
## nenhum da arvore (nem banner de bloqueio, ja coberto acima, nem em
## nenhum outro Label do bloco de nivel inteiro).
func test_no_emoji_anywhere_in_a_level_block():
	var board := TechTierBoard.new()
	board.rebuild({"quartel": true}, "arqueiro", 3.0)

	var block: Control = board.level_block(2)
	var texts: Array[String] = []
	_collect_label_texts(block, texts)
	var emoji_chars := ["🔒", "⚔", "🛡", "💰", "🗺"]
	for t in texts:
		for e in emoji_chars:
			assert_false(e in t, "texto nao deveria conter emoji (%s): %s" % [e, t])
	board.queue_free()

## Roadmap "so o essencial": o icone de familia saiu de DENTRO do card
## (pedido explicito: "tire os icones dos retangulos... ja que o icone ja
## tem nos subtitulos") — continua so no cabecalho da lane (FAMILY_LABELS,
## "▲ MILITAR" etc), nunca duplicado dentro de cada card.
func test_card_has_no_family_icon_inside_it_anymore():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	var card := _card(board, 1, "quartel")
	var found: TechFamilyIcon = null
	for child in _all_descendants(card):
		if child is TechFamilyIcon:
			found = child
			break
	assert_null(found, "card nao deveria mais ter um TechFamilyIcon dentro — so a lane")
	board.queue_free()

## A lane de familia continua com o icone no cabecalho (unico lugar que
## sobrou pra identidade de familia por icone, ver comentario acima).
func test_family_lane_header_still_has_its_icon():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	var block: Control = board.level_block(1)
	var militar_lane := block.find_child("Family_militar", true, false)
	assert_not_null(militar_lane)
	var found: TechFamilyIcon = null
	for child in _all_descendants(militar_lane):
		if child is TechFamilyIcon:
			found = child
			break
	assert_not_null(found, "cabecalho da lane deveria continuar com o icone")
	board.queue_free()

## --- Roadmap "UI/UX exclusiva" ----------------------------------------------

## Titulo do nivel deixa de ser dourado (pedido explicito: "dourado usado
## demais" — 10 titulos dourados ao mesmo tempo na tela). Dourado continua
## reservado pra pesquisa em andamento/nivel atual na timeline, nunca pro
## titulo de todo nivel.
func test_level_title_is_not_gold_anymore():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	var block: Control = board.level_block(1)
	var header: Control = block.get_child(0).get_child(0)
	var title: Label = header.get_child(0)
	assert_eq(title.text.begins_with("NÍVEL 1"), true)
	assert_true(title.has_theme_color_override("font_color"))
	assert_ne(title.get_theme_color("font_color"), TechTierBoard.ACCENT_GOLD)
	board.queue_free()

## Roadmap "so o essencial": TODO card expande igual, dentro de um
## GridContainer de 4 colunas fixas — pedido explicito: "quero que os
## botoes tenham todos o mesmo tamanho, do tamanho dos que tem quatro".
## Uma lane com so 1 tech ("celeiro" em Economia no Nivel 1) usa a MESMA
## largura de coluna que uma lane cheia — a diferenca e a celula vazia
## sobrando, nao um card menor ou maior.
func test_every_card_expands_equally_regardless_of_lane_size():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	var quartel := _card(board, 1, "quartel") # lane Militar, 2 techs
	var celeiro := _card(board, 1, "celeiro") # lane Economia, 1 tech (sozinho)
	assert_eq(quartel.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(celeiro.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(quartel.custom_minimum_size.x, celeiro.custom_minimum_size.x)
	board.queue_free()

## Cada lane de familia usa um GridContainer de 4 colunas fixas (nunca
## mais de 4 techs numa lane hoje, ver TechDatabase.gd).
func test_family_lane_uses_a_4_column_grid():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	var militar_lane := board.level_block(1).find_child("Family_militar", true, false)
	var grid: GridContainer = militar_lane.find_child("Cards", true, false)
	assert_eq(grid.columns, 4)
	board.queue_free()

## Diferentes tamanhos de conteudo nao deveriam quebrar o layout — Nivel 6
## (8 techs, o maior) e Nivel 1 (4 techs, o menor) renderizam TODOS os
## cards sem erro.
func test_different_content_sizes_render_every_card_without_breaking():
	var board := TechTierBoard.new()
	board.rebuild({}, "", 0.0)

	var tier6_techs := 0
	for tech in TechDatabase.all_techs():
		if tech.tier == 6:
			tier6_techs += 1
			assert_not_null(_card(board, 6, tech.id), "%s deveria renderizar mesmo no maior nivel" % tech.id)
	assert_eq(tier6_techs, 8)

	var tier1_techs := 0
	for tech in TechDatabase.all_techs():
		if tech.tier == 1:
			tier1_techs += 1
			assert_not_null(_card(board, 1, tech.id), "%s deveria renderizar mesmo no menor nivel" % tech.id)
	assert_eq(tier1_techs, 4)
	board.queue_free()

func _all_descendants(node: Node) -> Array:
	var result: Array = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_all_descendants(child))
	return result
