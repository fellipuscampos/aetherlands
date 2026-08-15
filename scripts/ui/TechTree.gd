class_name TechTree
extends Control

## Visualizacao de VERDADE da arvore de tecnologia — antes disso o painel
## so mostrava "disponiveis agora" como uma fileira de botoes soltos +
## "ja pesquisadas" como uma frase de texto, sem NENHUMA nocao de arvore
## (pre-requisito, ramificacao). Isso era o item mais citado no pedido do
## usuario pra melhorar os menus. Agora: cada tecnologia e um "card"
## posicionado por TIER (profundidade de pre-requisito, calculada em
## _compute_tiers), com linhas conectando pre-requisito -> tecnologia
## desbloqueada (desenhadas em _draw()), e 4 estados visuais distintos
## (bloqueada/disponivel/pesquisando/pesquisada).

signal tech_selected(id: String)

## Card COMPACTO estilo Civilization (pedido do usuario, com print do Civ6
## ao lado: cards curtos, uma linha por fato, sem paragrafo de lore
## empilhado) — a descricao de lore NAO mora mais no corpo do card (ver
## _add_tech_card: virou tooltip, so aparece ao passar o mouse), entao o
## card voltou a caber em bem menos altura que a versao anterior (178, que
## tentava espremer nome+efeito+ritual+lore+custo tudo junto e ainda
## precisava de clip_contents pra nao vazar). 150 cobre confortavelmente o
## pior caso realista (escola + nome em 2 linhas + efeito/ritual numa
## linha so + barra de progresso + rotulo de turno) com folga.
const NODE_SIZE := Vector2(210.0, 150.0)
## Espacamento entre colunas/linhas — aumentado (pedido do usuario: "ajuste
## o espacamento horizontal entre as colunas dos Tiers pra o fluxo... ficar
## amplo e legivel") agora que o modal ocupa 85% da tela (ver TechPanel em
## HUD.tscn, anchors em vez de offset fixo) em vez do tamanho fixo antigo,
## que deixava tudo espremido com scroll. COL_GAP tambem e o corredor onde
## _draw() roteia a dobra vertical das linhas de pre-requisito — ver
## comentario la.
const COL_GAP := 90.0
const ROW_GAP := 22.0
const MARGIN := Vector2(20.0, 20.0)

## Cor de acento por escola de magia (TechData.school) — puramente
## decorativo (chip de texto no topo do card), nunca substitui a cor de
## BORDA do card (essa continua sinalizando o estado — pesquisada/
## pesquisando/disponivel/bloqueada, ver _add_tech_card) pra nao perder a
## clareza da arvore. School sem entrada aqui (ou "") cai em COLOR_TEXT_
## MUTED.
const SCHOOL_COLORS := {
	"Arcanismo": Color(0.42, 0.66, 0.86),
	"Alquimia": Color(0.62, 0.72, 0.28),
	"Transmutação": Color(0.78, 0.55, 0.24),
	"Naturalismo": Color(0.4, 0.68, 0.36),
	"Geomancia": Color(0.68, 0.52, 0.3),
	"Elementalismo": Color(0.84, 0.42, 0.24),
	"Necromancia": Color(0.6, 0.36, 0.68),
}

var _node_rects: Dictionary = {} # id -> Rect2, posicao final de cada card (usado por _draw() pra ligar as linhas)

func rebuild(researched: Dictionary, current_research: String, research_progress: float) -> void:
	for child in get_children():
		child.queue_free()
	_node_rects.clear()

	var tiers := _compute_tiers()
	var by_tier: Dictionary = {} # tier(int) -> Array[TechData]
	for tech in TechDatabase.all_techs():
		var t: int = tiers[tech.id]
		if not by_tier.has(t):
			by_tier[t] = []
		by_tier[t].append(tech)
	for t in by_tier.keys():
		by_tier[t].sort_custom(func(a, b): return a.display_name < b.display_name)

	var max_tier := 0
	var max_rows := 1
	for t in by_tier.keys():
		max_tier = max(max_tier, t)
		max_rows = max(max_rows, by_tier[t].size())

	for tier in range(max_tier + 1):
		var techs_here: Array = by_tier.get(tier, [])
		for row in range(techs_here.size()):
			var tech: TechData = techs_here[row]
			var pos = MARGIN + Vector2(tier * (NODE_SIZE.x + COL_GAP), row * (NODE_SIZE.y + ROW_GAP))
			_node_rects[tech.id] = Rect2(pos, NODE_SIZE)
			_add_tech_card(tech, pos, researched, current_research, research_progress)

	custom_minimum_size = Vector2(
		(max_tier + 1) * (NODE_SIZE.x + COL_GAP) - COL_GAP + MARGIN.x * 2,
		max_rows * (NODE_SIZE.y + ROW_GAP) - ROW_GAP + MARGIN.y * 2
	)
	queue_redraw()

## Tier = quantos passos de pre-requisito ate a raiz (0 = sem pre-
## requisito nenhum). Relaxamento iterativo em vez de recursao: o grafo e
## uma DAG bem pequena (12 nos hoje), entao performance nunca importa, mas
## isso evita ter que lidar com ciclo/ordem de visita na mao.
func _compute_tiers() -> Dictionary:
	var tiers := {}
	var techs = TechDatabase.all_techs()
	for t in techs:
		tiers[t.id] = 0
	var changed := true
	var safety := 0
	while changed and safety < 20:
		changed = false
		safety += 1
		for t in techs:
			var desired := 0
			for p in t.prerequisites:
				desired = max(desired, int(tiers.get(p, 0)) + 1)
			if tiers[t.id] < desired:
				tiers[t.id] = desired
				changed = true
	return tiers

func _add_tech_card(tech: TechData, pos: Vector2, researched: Dictionary, current_research: String, research_progress: float) -> void:
	var prereqs_met := true
	for p in tech.prerequisites:
		if not researched.has(p):
			prereqs_met = false
			break
	var is_researched: bool = researched.has(tech.id)
	var is_researching: bool = tech.id == current_research
	var is_selectable: bool = prereqs_met and not is_researched and not is_researching

	var card := PanelContainer.new()
	card.position = pos
	card.custom_minimum_size = NODE_SIZE
	card.size = NODE_SIZE
	# Trava de seguranca (pedido do usuario: "texto... NUNCA ultrapasse a
	# borda do card nem atropele o custo/requerimentos"): a lore que antes
	# vazava foi pro tooltip (ver mais abaixo), entao isto raramente
	# dispara agora — mas um nome de tecnologia bem longo em 2 linhas + a
	# lista "Requer: X, Y" de uma tech com varios pre-requisitos ainda
	# podia, em tese, passar da altura fixa do card (Container do Godot nao
	# encolhe filhos abaixo do minimo deles, so deixa vazar visualmente sem
	# isto). clip_contents corta qualquer overflow na propria borda do card
	# em vez de deixar vazar por cima do proximo card.
	card.clip_contents = true

	var border_color: Color
	if is_researched:
		border_color = UITheme.COLOR_SUCCESS
	elif is_researching:
		border_color = UITheme.COLOR_ACCENT
	elif prereqs_met:
		border_color = UITheme.COLOR_BORDER_BRIGHT
	else:
		border_color = UITheme.COLOR_TEXT_MUTED
	var bg_color = UITheme.COLOR_BG_PANEL_LIGHT if (prereqs_met or is_researched) else UITheme.COLOR_BG_PANEL.darkened(0.3)
	card.add_theme_stylebox_override("panel", UITheme.panel_style(bg_color, border_color, 2))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)

	if tech.school != "":
		var school_label := Label.new()
		school_label.theme_type_variation = &"MutedLabel"
		school_label.text = tech.school.to_upper()
		school_label.add_theme_color_override("font_color", _school_color(tech.school))
		box.add_child(school_label)

	var name_label := Label.new()
	name_label.text = tech.display_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not prereqs_met and not is_researched:
		name_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	box.add_child(name_label)

	# Efeito (unidade/bioma) + ritual NUMA linha so (era duas linhas
	# separadas) — pedido do usuario, "se baseie em como Civilization faz":
	# card denso e curto, um fato por linha, nao uma pilha de paragrafos.
	# _effect_summary() continua devolvendo so a parte de unidade/bioma
	# (mantido assim de proposito pra nao quebrar quem ja testa essa funcao
	# isoladamente) — o ritual e concatenado aqui na hora de montar o card.
	var effect_text := _effect_summary(tech)
	if tech.unlocks_spell != "":
		if effect_text != "":
			effect_text = "%s · Ritual: %s" % [effect_text, tech.unlocks_spell]
		else:
			effect_text = "Ritual: %s" % tech.unlocks_spell
	if effect_text != "":
		var effect_label := Label.new()
		effect_label.theme_type_variation = &"MutedLabel"
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_label.text = effect_text
		if tech.unlocks_spell != "":
			effect_label.add_theme_color_override("font_color", UITheme.COLOR_ACCENT)
		box.add_child(effect_label)

	# Lore/sabor (TechData.description) virou TOOLTIP em vez de texto fixo
	# no corpo do card — mesmo padrao do Civ6 (a arvore mostra so o
	# essencial denso; a descricao completa aparece ao passar o mouse).
	# Era exatamente o texto que antes vazava por cima do custo/pre-
	# requisito em techs com lore mais longa (ex: Cataclismo Elemental).
	if tech.description != "":
		card.tooltip_text = tech.description

	if is_researching:
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = tech.cost
		bar.value = research_progress
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		box.add_child(bar)
		var progress_label := Label.new()
		progress_label.theme_type_variation = &"MutedLabel"
		progress_label.text = "%d/%d ciencia" % [int(research_progress), int(tech.cost)]
		box.add_child(progress_label)
	elif is_researched:
		var done_label := Label.new()
		done_label.theme_type_variation = &"MutedLabel"
		done_label.add_theme_color_override("font_color", UITheme.COLOR_SUCCESS)
		done_label.text = "Pesquisada"
		box.add_child(done_label)
	else:
		var cost_label := Label.new()
		cost_label.theme_type_variation = &"MutedLabel"
		cost_label.text = "%d ciencia" % int(tech.cost)
		box.add_child(cost_label)
		if not prereqs_met:
			var prereq_names: Array[String] = []
			for p in tech.prerequisites:
				var pt: TechData = TechDatabase.get_tech(p)
				if pt:
					prereq_names.append(pt.display_name)
			var locked_label := Label.new()
			locked_label.theme_type_variation = &"MutedLabel"
			locked_label.add_theme_color_override("font_color", UITheme.COLOR_DANGER)
			locked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			locked_label.text = "Requer: %s" % ", ".join(prereq_names)
			box.add_child(locked_label)

	if is_selectable:
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_gui_input.bind(tech.id))

	add_child(card)

func _on_card_gui_input(event: InputEvent, tech_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tech_selected.emit(tech_id)

func _school_color(school: String) -> Color:
	return SCHOOL_COLORS.get(school, UITheme.COLOR_TEXT_MUTED)

func _effect_summary(tech: TechData) -> String:
	if tech.unlocks_unit != "":
		return "Desbloqueia: %s" % UnitDatabase.create_unit(tech.unlocks_unit).unit_name
	var parts: Array[String] = []
	if tech.bonus_food > 0:
		parts.append("+%d comida" % tech.bonus_food)
	if tech.bonus_production > 0:
		parts.append("+%d producao" % tech.bonus_production)
	if tech.bonus_gold > 0:
		parts.append("+%d ouro" % tech.bonus_gold)
	return ", ".join(parts) if parts.size() > 0 else ""

## Uma linha "em cotovelo" (3 segmentos ortogonais) por aresta de pre-
## requisito, do centro-direito do card de origem ate o centro-esquerdo do
## card desbloqueado — pedido do usuario: "melhore o desenho das conexoes
## pra saírem do centro direito do card de origem e entrarem no centro
## esquerdo do card de destino sem atravessar o texto dos cards". Uma
## linha RETA diagonal entre linhas diferentes cruzava por cima de
## qualquer card que estivesse no meio do caminho; a dobra vertical fica
## sempre no MEIO do COL_GAP entre as duas colunas — um corredor vazio,
## nenhum card e desenhado ali — entao o segmento vertical nunca cruza
## nada, e os dois segmentos horizontais ficam contidos na propria altura
## da linha (row) de origem/destino, nunca atravessando o card de outra
## tecnologia no meio do caminho.
func _draw() -> void:
	for tech in TechDatabase.all_techs():
		if not _node_rects.has(tech.id):
			continue
		var to_rect: Rect2 = _node_rects[tech.id]
		for p in tech.prerequisites:
			if not _node_rects.has(p):
				continue
			var from_rect: Rect2 = _node_rects[p]
			var from_point = from_rect.position + Vector2(from_rect.size.x, from_rect.size.y * 0.5)
			var to_point = to_rect.position + Vector2(0.0, to_rect.size.y * 0.5)
			var mid_x = (from_point.x + to_point.x) * 0.5
			var points := PackedVector2Array([
				from_point,
				Vector2(mid_x, from_point.y),
				Vector2(mid_x, to_point.y),
				to_point,
			])
			draw_polyline(points, UITheme.COLOR_BORDER, 2.0, true)
