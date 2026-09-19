class_name TechTierBoard
extends VBoxContainer

## Visualizacao "tier-band" da arvore de Tecnologia MUNDANA — Roadmap
## "polimento e coesao" (estrutura original) + "polimento definitivo V1"
## (paleta/dado de familia/effect_text, rodada mais recente — ver
## comentarios inline abaixo). Substitui TechTree.gd (script antigo, ainda
## usado SO pela aba Magia, intocado) como script do node DoutrinaTree em
## HUD.tscn. Diferente do modelo de grafo antigo (colunas por profundidade
## de pre-requisito, componentes conexos, linhas desenhadas a mao), aqui a
## estrutura principal e o TIER (10 faixas horizontais, uma por nivel,
## empilhadas verticalmente dentro do ScrollContainer que ja existia) —
## pedido explicito do usuario: "tier deve ser a estrutura principal de
## layout; conexoes devem ser secundarias; nao usar componentes conexos
## como estrutura visual dominante".
##
## TechData.prerequisites (a ancora cosmetica que RivalAI/TechTree.gd ainda
## usam) aparece aqui SO no tooltip do card ("liga-se a: X"), nunca no corpo
## do card nem como linha desenhada entre cards — Roadmap "polimento
## definitivo V1" moveu isso pra fora do corpo (pedido: "nao colocar 6
## linhas de texto no card"); a razao original de nunca desenhar como linha
## continua valendo: com HFlowContainer/ScrollContainer a posicao final de
## cada card so existe DEPOIS do layout, entao uma linha reta entre cards em
## blocos de nivel/posicoes de scroll diferentes seria fragil pro ganho.
##
## Paleta LOCAL (Roadmap "polimento definitivo V1"): pedido explicito do
## usuario pra uma UI "com qualidade de 4X comercial" — carvao/aco/dourado
## discreto, SEM emoji, distinta do marrom/dourado saturado que UITheme.gd
## usa no resto do jogo (Magia inclusive). Decisao explicita: os consts
## COLOR_* abaixo NAO tocam UITheme.gd (isso afetaria Magia/HUD inteira,
## fora de escopo) — sao aplicados via add_theme_color_override direto em
## cada Label/Control criado aqui, nunca via theme_type_variation (que
## puxaria do Theme GLOBAL, ainda marrom/dourado). UITheme.panel_style()
## continua reusado pra stylebox (aceita cor arbitraria, nenhuma funcao
## nova).

signal tech_selected(id: String)

## "" = mostra todas as familias (default). Um dos FAMILY_* abaixo = so
## essa familia aparece renderizada — filtro e PURAMENTE de apresentacao,
## nunca muda quem esta disponivel/bloqueado (isso continua vindo de
## TechDatabase.available_techs/is_tier_unlocked, calculado sobre TODAS as
## techs do nivel, nunca sobre o subconjunto filtrado).
var active_family_filter: String = ""

# Espelham TechData.FAMILY_* direto (fonte unica desde "polimento
# definitivo V1") — mantidos aqui so pra nao quebrar quem ja referencia
# TechTierBoard.FAMILY_MILITAR etc (ex: HUD.gd, botoes de filtro).
const FAMILY_MILITAR := TechData.FAMILY_MILITAR
const FAMILY_ECONOMIA := TechData.FAMILY_ECONOMIA
const FAMILY_DEFESA := TechData.FAMILY_DEFESA
const FAMILY_EXPLORACAO := TechData.FAMILY_EXPLORACAO_UTILIDADE
const FAMILY_ORDER := [FAMILY_MILITAR, FAMILY_ECONOMIA, FAMILY_DEFESA, FAMILY_EXPLORACAO]
const FAMILY_LABELS := {
	FAMILY_MILITAR: "MILITAR",
	FAMILY_ECONOMIA: "ECONOMIA",
	FAMILY_DEFESA: "DEFESA",
	FAMILY_EXPLORACAO: "EXPLORAÇÃO / UTILIDADE",
}

## Cor de destaque de cada familia — usada SO no icone geometrico do card
## (TechFamilyIcon) e no cabecalho da lane dentro do nivel. Deliberadamente
## DIFERENTE das cores de estado (ACCENT_GOLD/COLOR_RESEARCHED abaixo) pra
## nao confundir "isso e Militar" com "isso esta pesquisando".
const FAMILY_COLOR := {
	FAMILY_MILITAR: Color(0.72, 0.35, 0.32),
	FAMILY_ECONOMIA: Color(0.42, 0.62, 0.55),
	FAMILY_DEFESA: Color(0.40, 0.52, 0.68),
	FAMILY_EXPLORACAO: Color(0.58, 0.48, 0.68),
}

# --- Paleta local (ver comentario de topo) ----------------------------------
const BG_LEVEL := Color(0.071, 0.078, 0.102, 1.0)
## Fundo dos BLOCOS de nivel (Roadmap "so o essencial", pedido explicito:
## "coloque uma cor diferente no background dos niveis... faça teoria das
## cores aí e aplique"). Teoria de cor aplicada: BG_LEVEL (a tela de
## fundo) e um tom FRIO (matiz azulado, ~220°, bem escuro/dessaturado) —
## em vez de ir pro branco/dourado claro (que quebraria contraste com o
## texto claro calibrado pra fundo ESCURO, e destoaria do resto da UI
## escura/premium construida ate aqui), a secao de nivel usa um tom
## ESCURO tambem, mas com contraste de TEMPERATURA: matiz QUENTE (~35°,
## proximo do dourado/bronze ja usado como acento e borda), levemente
## mais claro que a tela de fundo. Contraste frio/quente + um degrau de
## luminosidade e o suficiente pra cada "NIVEL" se ler como uma secao de
## conteudo distinta da tela, sem quebrar a paleta escura estabelecida.
const BG_SECTION := Color(0.125, 0.112, 0.090, 1.0)
const BG_CARD := Color(0.114, 0.125, 0.157, 1.0)
const BORDER_STEEL := Color(0.38, 0.42, 0.48, 1.0)
const BORDER_STEEL_BRIGHT := Color(0.62, 0.67, 0.74, 1.0)
const BORDER_BRONZE := Color(0.42, 0.34, 0.22, 1.0)
const ACCENT_GOLD := Color(0.83, 0.68, 0.32, 1.0)
const COLOR_RESEARCHED := Color(0.36, 0.62, 0.52, 1.0)
const TEXT_PRIMARY := Color(0.88, 0.89, 0.92, 1.0)
const TEXT_MUTED := Color(0.55, 0.58, 0.63, 1.0)
# Mais escuro que antes (era 0.38/0.40/0.44) — achado da analise visual:
# bloqueado e disponivel ficavam parecidos demais em contraste. Bloqueado
# agora recua de verdade.
const TEXT_LOCKED := Color(0.30, 0.31, 0.34, 1.0)

## Fonte de destaque SEM asset novo (pedido de sempre: nenhum arquivo
## externo) — FontVariation embrulha a fonte padrao do proprio Godot
## (ThemeDB.fallback_font) e aplica negrito sintetico (embolden) +
## espacamento entre letras. Da hierarquia tipografica real (titulo >
## nivel > card) sem precisar de um .ttf/.otf novo. Reusado por HUD.gd
## pro titulo principal "ARVORE DE TECNOLOGIA".
static func heading_font(embolden: float = 0.6, spacing: int = 1) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	variation.variation_embolden = embolden
	variation.spacing_glyph = spacing
	return variation

## Colunas fixas da grade de cards de cada lane de familia (Roadmap "so o
## essencial", pedido explicito: "todos os botoes do mesmo tamanho, do
## tamanho dos que tem quatro") — nenhuma lane hoje tem mais de 4 techs
## (ver TechDatabase.gd), entao 4 e o numero que faz toda lane parecer uma
## grade uniforme, com celulas vazias sobrando em vez de cards esticados.
const GRID_COLUMNS := 4

## Predios de "upgrade" (Quartel II/III/Elite, Estabulo II, Campo de Tiro
## II, Oficina II, Celeiro II, Mercado II, Muralhas II, Torre de Vigia,
## Fortaleza, Fortaleza Imperial, Grande Mercado/Arsenal/Emporio, Posto
## Comercial) — usado so pra rotular o card como "Melhoria/Upgrade" em vez
## de "Construção" (ver _tech_type_label). Mesma lista de BuildingDatabase.gd
## (os predios de upgrade do redesenho de 10 niveis + os novos do
## rebalanceamento "polimento definitivo V1").
const UPGRADE_BUILDING_IDS := {
	"barracks_2": true, "barracks_3": true, "barracks_elite": true,
	"archery_range_2": true, "stable_2": true, "workshop_2": true,
	"watchtower": true, "fortress": true, "grand_market": true,
	"grand_arsenal": true, "imperial_fortress": true, "grand_emporium": true,
	"granary_2": true, "market_2": true, "walls_2": true, "trading_post": true,
}

## Titulos SAO apresentacao pura — pedido explicito do usuario: "nao
## tratar esses titulos como conteudo mecanico". Provisorios (secao 3 do
## pedido original). A descricao de sabor de cada nivel (um paragrafo por
## tier) saiu da UI (Roadmap "menos poluido", pedido explicito: "retire
## esses micro textos... tudo, na verdade") — so o titulo continua.
const LEVEL_TITLES := {
	1: "Fundação", 2: "Primeiras Especializações", 3: "Expansão",
	4: "Guerra Especializada", 5: "Fortificação", 6: "Profissionalização",
	7: "Guerra Avançada", 8: "Poder do Reino", 9: "Poder Imperial",
	10: "Ápice da Civilização",
}

func rebuild(researched: Dictionary, current_research: String, research_progress: float, race: String = "human") -> void:
	for child in get_children():
		child.queue_free()

	var techs_by_tier: Dictionary = {} # int -> Array[TechData]
	for tech in TechDatabase.all_techs():
		if not techs_by_tier.has(tech.tier):
			techs_by_tier[tech.tier] = []
		techs_by_tier[tech.tier].append(tech)

	for tier in range(1, 11):
		var techs: Array = techs_by_tier.get(tier, [])
		add_child(_build_level_block(tier, techs, researched, current_research, research_progress, race))

## Testabilidade: acesso direto ao bloco de UM nivel (1-indexado) sem
## precisar navegar a arvore de nodes na mao — blocos sao adicionados na
## ordem 1..10 em rebuild(), entao o indice e sempre tier-1.
func level_block(tier: int) -> Control:
	if tier < 1 or tier > get_child_count():
		return null
	return get_child(tier - 1)

func _build_level_block(tier: int, techs: Array, researched: Dictionary, current_research: String, research_progress: float, race: String) -> Control:
	var tier_open := TechDatabase.is_tier_unlocked(tier, researched)
	var researched_in_tier := 0
	for t in techs:
		if researched.has(t.id):
			researched_in_tier += 1

	var block := PanelContainer.new()
	block.name = "Level%d" % tier
	# Visual chapado (pedido explicito: sem sombra/relevo) — corner_radius
	# menor (era 8) e with_shadow=false, mesmo tratamento dos cards.
	# Padding interno maior (era 8, o padrao de panel_style — pedido
	# explicito: "aumente o padding interno") — mais respiro ao redor do
	# conteudo do nivel.
	var level_style := UITheme.panel_style(BG_SECTION, BORDER_BRONZE, 1, 4, false)
	level_style.set_content_margin_all(18)
	block.add_theme_stylebox_override("panel", level_style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	block.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	box.add_child(header)

	# Roadmap "UI/UX exclusiva": titulo deixa de ser dourado — 10 titulos
	# dourados ao mesmo tempo na tela e exatamente o "dourado usado demais"
	# do pedido. Dourado fica reservado pra pesquisa em andamento, nunca
	# pro titulo de todo nivel.
	var title := Label.new()
	title.text = "NÍVEL %d — %s" % [tier, LEVEL_TITLES.get(tier, "").to_upper()]
	title.add_theme_color_override("font_color", TEXT_PRIMARY)
	title.add_theme_font_override("font", heading_font(0.5, 1))
	title.add_theme_font_size_override("font_size", UITheme.FONT_SIZE_SECTION)
	header.add_child(title)

	# Roadmap "so o essencial": nenhum texto de progresso/bloqueio no
	# cabecalho do nivel mais — pedido explicito ("tire esse 0/2, todos
	# precisam de 0/2 pra passar entao e indiferente ter isso"). O portao
	# "2 de N" continua sendo a MESMA mecanica de sempre (TechDatabase.
	# is_tier_unlocked) — so o texto que anunciava o numero desapareceu; um
	# nivel bloqueado se comunica pelos proprios cards (dessaturados, sem
	# clique), nao mais por uma frase no titulo.

	var by_family: Dictionary = {} # familia -> Array[TechData]
	for t in techs:
		var fam: String = t.display_family if t.display_family != "" else FAMILY_MILITAR
		if not by_family.has(fam):
			by_family[fam] = []
		by_family[fam].append(t)

	# Nenhuma lane tem mais de 4 techs (o maior caso hoje: Militar/Economia
	# no Nivel 6-7, ver TechDatabase.gd) — GRID_COLUMNS reflete isso.
	for fam in FAMILY_ORDER:
		if active_family_filter != "" and active_family_filter != fam:
			continue
		var fam_techs: Array = by_family.get(fam, [])
		if fam_techs.is_empty():
			continue
		var fam_box := VBoxContainer.new()
		fam_box.name = "Family_%s" % fam
		box.add_child(fam_box)
		var fam_header := HBoxContainer.new()
		fam_header.add_theme_constant_override("separation", 6)
		fam_box.add_child(fam_header)
		var fam_icon := TechFamilyIcon.new()
		fam_icon.custom_minimum_size = Vector2(12, 12)
		fam_icon.family = fam
		fam_icon.icon_color = FAMILY_COLOR.get(fam, TEXT_MUTED)
		fam_header.add_child(fam_icon)
		var fam_label := Label.new()
		fam_label.text = FAMILY_LABELS[fam]
		fam_label.add_theme_color_override("font_color", TEXT_MUTED)
		fam_header.add_child(fam_label)
		# GridContainer de colunas FIXAS (nao mais HFlowContainer) — pedido
		# explicito: "quero que os botoes tenham todos o mesmo tamanho,
		# pode deixar todos do tamanho dos card que tem quatro". Card com
		# SIZE_EXPAND_FILL divide a largura em 4 colunas IGUAIS sempre,
		# mesmo quando a lane tem menos de 4 techs (sobra celula vazia em
		# vez de esticar o card existente) — nativo do Godot, responsivo
		# (recalcula sozinho em qualquer resolucao).
		var grid := GridContainer.new()
		grid.name = "Cards"
		grid.columns = GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		fam_box.add_child(grid)
		for t in fam_techs:
			grid.add_child(_build_card(t, researched, current_research, research_progress, race, tier_open))

	return block

func _tech_type_label(tech: TechData) -> String:
	if tech.unlocks_unit != "":
		return "Unidade"
	if tech.unlocks_building != "":
		return "Melhoria/Upgrade" if UPGRADE_BUILDING_IDS.has(tech.unlocks_building) else "Construção"
	return "Utilidade/Flag"

## Card de UMA linha so (Roadmap "tela cheia", pedido explicito: "no
## Civilization os cards so tem um nome e um icone... deixa esses
## simbolos que representam a categoria, entao so vai ter Quartel — o que
## ele é, tipo Quartel - Construção e o icone na extremidade esquerda").
## Custo/effect_text/status por extenso/"liga-se a"/descricao de lore —
## tudo isso saiu do CORPO e vive so no tooltip (ver mais abaixo). Estado
## (pesquisada/pesquisando/disponivel/bloqueada) continua vindo so de
## `tier_open` (ja resolvido por nivel em _build_level_block) — nunca
## menciona pre-requisito especifico, regra de sempre.
func _build_card(tech: TechData, researched: Dictionary, current_research: String, research_progress: float, race: String, tier_open: bool) -> Control:
	var is_researched: bool = researched.has(tech.id)
	var is_researching: bool = tech.id == current_research
	var is_selectable: bool = tier_open and not is_researched and not is_researching

	var card := PanelContainer.new()
	card.name = "Card_%s" % tech.id
	# Card e so uma linha (Nome + "— Tipo"). Piso de 260 evita truncar o
	# Nome agressivo demais quando o TypeLabel (largura fixa, nunca
	# encolhe) reserva espaco pro texto mais longo ("— Melhoria/Upgrade").
	# SIZE_EXPAND_FILL sempre ligado agora — dentro do GridContainer de 4
	# colunas (ver _build_level_block), isso faz TODO card ter a MESMA
	# largura (a coluna), com celula vazia sobrando em vez de esticar —
	# pedido explicito: "todos os botoes do mesmo tamanho".
	card.custom_minimum_size = Vector2(260, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true

	var border_color: Color
	var bg_color: Color
	if is_researched:
		border_color = COLOR_RESEARCHED
		bg_color = BG_CARD
	elif is_researching:
		border_color = ACCENT_GOLD
		bg_color = BG_CARD
	elif tier_open:
		border_color = BORDER_STEEL_BRIGHT
		bg_color = BG_CARD
	else:
		# Contraste bem mais forte que disponivel (achado da analise
		# visual: bloqueado e disponivel ficavam parecidos demais) — quase
		# sem borda, fundo bem mais escuro.
		border_color = BG_CARD.darkened(0.5)
		bg_color = BG_CARD.darkened(0.55)
	# Visual CHAPADO (pedido explicito: "muita sombra, muita borda, efeito
	# pra caralho, parece powerpoint") — sem sombra (with_shadow=false),
	# borda fina de 1px, corner_radius pequeno. O "brilho" de pesquisando e
	# o hover-lightening da rodada anterior saíram — a lasca de progresso
	# (ver abaixo) e a simples troca de bg no hover já bastam.
	var normal_style := UITheme.panel_style(bg_color, border_color, 1, 4, false)
	# Padding interno maior (pedido explicito: "aumente o padding
	# interno") — era o padrao de panel_style (8), agora respira mais.
	normal_style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", normal_style)

	if is_selectable:
		var hover_style := UITheme.panel_style(BG_CARD.lightened(0.04), border_color, 1, 4, false)
		hover_style.set_content_margin_all(12)
		card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hover_style))
		card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", normal_style))

	# Roadmap "so o essencial" (revisao): a barra de destaque lateral saiu
	# (pedido explicito: "tire essa barrinha tambem") — a cor da BORDA do
	# card (border_color acima) ja comunica o estado sozinha, e o icone no
	# cabecalho da lane ja comunica a familia. Sem essa faixa, `box` vira
	# filho direto do card (nao precisa mais do wrapper `outer`+ColorRect).
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)

	# Sem icone de familia aqui dentro (pedido explicito: "tire os icones
	# dos retangulos... ja que o icone ja tem nos subtitulos") — o
	# icone que já aparece no cabecalho da lane (FAMILY_LABELS, "▲
	# MILITAR" etc) bastam pra identidade de familia, sem repetir dentro
	# de cada card.
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	box.add_child(name_row)

	# Nome (destaque, trunca com "…" se faltar espaco) + " — Tipo" (mais
	# discreto, NUNCA e o que trunca — achado da analise visual: "Nome —
	# Tipo" como uma string so cortava NO MEIO da palavra do tipo,
	# parecendo bug). "✓" so se ja pesquisada (glifo simples, mesma
	# familia de ▲●⬟◆ ja usados — nao e emoji).
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = ("%s ✓" % RaceTheme.tech_name(tech.id, race)) if is_researched else RaceTheme.tech_name(tech.id, race)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_researched:
		name_label.add_theme_color_override("font_color", COLOR_RESEARCHED)
	elif tier_open:
		name_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	else:
		name_label.add_theme_color_override("font_color", TEXT_LOCKED)
	name_row.add_child(name_label)

	var type_label := Label.new()
	type_label.name = "TypeLabel"
	type_label.text = "— %s" % _tech_type_label(tech)
	# SEM clip_text aqui de proposito — achado do playtest visual: clip_text
	# faz o Label reportar tamanho minimo ~0 pro container, e como este nao
	# expande, ficava espremido a quase nada (o texto sumia). Vocabulario
	# fixo e curto (Unidade/Construção/Melhoria-Upgrade/Utilidade-Flag), o
	# NameLabel (que de fato pode ser longo) e quem precisa/tem clip+ellipsis.
	if tier_open or is_researched:
		type_label.add_theme_color_override("font_color", TEXT_MUTED)
	else:
		type_label.add_theme_color_override("font_color", TEXT_LOCKED)
	name_row.add_child(type_label)

	# Lasca fina de progresso (2px) — so pra pesquisando, substitui a barra
	# grande + label separada da rodada anterior.
	if is_researching:
		var sliver := ProgressBar.new()
		sliver.min_value = 0.0
		sliver.max_value = tech.cost
		sliver.value = research_progress
		sliver.show_percentage = false
		sliver.custom_minimum_size = Vector2(0, 2)
		sliver.add_theme_stylebox_override("background", UITheme.panel_style(BG_CARD.darkened(0.2), BG_CARD.darkened(0.2), 0, 0, false))
		sliver.add_theme_stylebox_override("fill", UITheme.panel_style(ACCENT_GOLD, ACCENT_GOLD, 0, 0, false))
		box.add_child(sliver)

	# Tooltip: TUDO que saiu do corpo do card mora aqui agora (Roadmap
	# "tela cheia", pedido explicito: "ao passar o mouse aparece tudo,
	# custa tanto, precisa de tal pesquisa, o que é essa coisa") — tipo,
	# efeito honesto, status (com custo/progresso quando fizer sentido),
	# descricao de lore, ancora cosmetica de prerequisites.
	var tooltip_lines: Array[String] = ["Tipo: %s" % _tech_type_label(tech)]
	tooltip_lines.append("Efeito: %s" % (tech.effect_text if tech.effect_text != "" else "—"))
	if tech.unlocks_unit != "":
		var trainer := BuildingDatabase.building_that_trains(tech.unlocks_unit)
		if trainer:
			tooltip_lines.append("Treinamento exige %s na cidade." % trainer.display_name)
		var ability := UnitAbilities.description(tech.unlocks_unit)
		if ability != "":
			tooltip_lines.append(ability)
	if tech.unlocks_building != "":
		var building := BuildingDatabase.get_building(tech.unlocks_building)
		if building and building.requires_building != "":
			var prior := BuildingDatabase.get_building(building.requires_building)
			tooltip_lines.append("Construção exige %s na cidade." % prior.display_name)
	if is_researching:
		tooltip_lines.append("Pesquisando: %d/%d ciência" % [int(research_progress), int(tech.cost)])
	elif is_researched:
		tooltip_lines.append("Pesquisada")
	elif tier_open:
		tooltip_lines.append("Disponível · %d ciência" % int(tech.cost))
	else:
		tooltip_lines.append("Bloqueada")
	var description := RaceTheme.tech_description(tech.id, race)
	if description != "":
		tooltip_lines.append(description)
	if not tech.prerequisites.is_empty():
		var anchor_names: Array[String] = []
		for p in tech.prerequisites:
			var pt: TechData = TechDatabase.get_tech(p)
			if pt:
				anchor_names.append(RaceTheme.tech_name(pt.id, race))
		if not anchor_names.is_empty():
			tooltip_lines.append("Liga-se a: %s" % ", ".join(anchor_names))
	card.tooltip_text = "\n".join(tooltip_lines)

	if is_selectable:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_gui_input.bind(tech.id))

	return card

func _on_card_gui_input(event: InputEvent, tech_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tech_selected.emit(tech_id)
