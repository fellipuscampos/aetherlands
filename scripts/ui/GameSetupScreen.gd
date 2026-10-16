class_name GameSetupScreen
extends Control

## Tela de configuracao de nova partida — separada do Menu Principal
## (TitleScreen), mesmo fluxo em 2 telas do Civilization VI (Menu Principal
## -> tela dedicada de configuracao de partida), pedido do usuario:
## "reestruturação nos huds, nos menus... baseando em deixar parecido com
## os de civilization 6 a nivel de organização". TitleScreen.NewGameButton
## so abre esta tela (ver Main._on_new_game_setup_requested); esta tela e
## quem de fato monta os parametros e emite new_game_requested (MESMA
## assinatura de antes, so mudou QUEM emite — Main.gd nao precisou mudar a
## logica de _on_new_game_requested, so a origem da conexao).
##
## Dificuldade das IAs (2026-10-15, V2AIDifficulty): Fácil/Normal/Difícil voltaram, agora como modificador da
## ECONOMIA das IAs — a inteligência é uma só. Os nomes descrevem a vida da IA, como o usuário pediu ("fácil deixa
## tudo mais leve pra ela, difícil deixa tudo mais caro pra ela"); a dica embaixo diz o efeito em você. Botões
## montados em código (mesmo padrão do tamanho do mapa), logo depois da linha de rivais.
##
## Lobby pixelado: quatro cartas com retratos dos modelos reais, detalhes
## do povo e configuração da partida lado a lado. A área central pode
## rolar; Voltar, resumo das escolhas e Iniciar permanecem visíveis.
## As duas especialidades vêm de V2RaceBonusDatabase e a história é
## secundária, expansível, sem mudar regras ou opções da partida.

signal new_game_requested(width: int, height: int, kingdom_name: String, rival_count: int, difficulty: String, race: String)
signal back_requested

## Uma entrada por raca escolhivel — fonte unica pro painel de detalhe
## (_update_race_detail) E pros botoes da lista (montados a mao no .tscn,
## mas o TEXTO de cada um vem daqui via _label_race_buttons, pra "Humano"/
## "Elfo"/"Anao"/"Orc" nunca dessincronizar do display_name usado no
## painel).
const RACE_INFO := {
	"human": {
		"race_name": "Humanos",
		"display_name": "Reino de Aldenmark",
		"tagline": "Honra no Aço, Ordem na Fé",
		"lore": "Advindos de outro mundo após um cataclismo devastador, os humanos organizavam-se inicialmente em feudos isolados. Contudo, as constantes ameaças de feras e monstros os obrigaram a se unificar em um vasto império fortemente militarizado, governado por um Rei e estruturado em grandes casas nobres. Convictos da supremacia de sua espécie e fiéis à fé trazida de seu mundo original, compensam a falta de magia inata refinando táticas de guerra ancestrais e ostentando uma doutrina militar implacável centralizada na sua lendária cavalaria.",
	},
	"elf": {
		"race_name": "Elfos",
		"display_name": "Império de Elenor",
		"tagline": "Os Primeiros Nascidos, Filhos do Sol",
		"lore": "Muito antes do surgimento das raças jovens, os Elfos cruzaram os véus do cosmos e se tornaram uma das primeiras raças conscientes a desbravar Aetherlands. Considerados seres semi-divinos, vivem sob uma rígida teocracia governada por um Rei-Deus e possuem uma maestria inigualável na Magia de Luz, venerando o próprio Sol como a manifestação suprema do divino. No passado, a semelhança entre suas doutrinas fez os humanos cogitarem a submissão ao domínio élfico, mas divergências culturais impediram que uma aliança duradoura se concretizasse.",
	},
	"dwarf": {
		"race_name": "Anões",
		"display_name": "Liga dos Clãs de Ferro",
		"tagline": "Mestres do Aço, Guardiões da Riqueza",
		"lore": "Assim como as outras grandes raças, os Anões cruzaram os mundos e fincaram suas raízes nas profundezas de Aetherlands. Desprovidos de um governo centralizado, organizam-se em uma próspera rede de clãs e guildas autônomas, cujos acordos e pactos comerciais se unem firmemente diante das ameaças de guerra. Famosos por sua tenacidade física, aversão à luz da superfície e um apetite insaciável por ouro, dominaram a mineração e a forja a um nível inigualável, tornando suas armas e minérios indispensáveis para o comércio de todas as civilizações.",
	},
	"orc": {
		"race_name": "Orcs",
		"display_name": "Horda dos Clãs Primordiais",
		"tagline": "A Ameaça Implacável, Senhores da Guerra",
		"lore": "A origem exata dos Orcs permanece um mistério: enquanto alguns acreditam que vieram de mundos distantes, outros sustentam que são nativos de Aetherlands ou até criados por forças obscuras. Organizados em tribos movidas por pilhagens, invasões e guerra, sua liderança é ditada unicamente pelo direito do mais forte, expandindo seus domínios enquanto o líder mantiver o respeito e o pavor de seus seguidores. Com uma taxa de multiplicação assustadora, são enxergados pelas outras civilizações como uma ameaça implacável, maligna e brutal.",
	},
}

const RACE_COLORS := {
	"human": Color("d2a85b"),
	"elf": Color("73b96b"),
	"dwarf": Color("c98b55"),
	"orc": Color("b86455"),
}

@onready var kingdom_name_edit: LineEdit = $CenterBox/Box/RaceSection/Details/ConfigurationPanel/ConfigurationBox/KingdomNameEdit
@onready var human_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/HumanRaceButton
@onready var elf_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/ElfRaceButton
@onready var dwarf_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/DwarfRaceButton
@onready var orc_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/OrcRaceButton
@onready var race_name_label: Label = $CenterBox/Box/RaceSection/Details/RaceDetailPanel/RaceDetailBox/RaceNameLabel
@onready var race_tagline_label: Label = $CenterBox/Box/RaceSection/Details/RaceDetailPanel/RaceDetailBox/RaceTaglineLabel
@onready var race_lore_label: RichTextLabel = $CenterBox/Box/RaceSection/Details/RaceDetailPanel/RaceDetailBox/RaceLoreLabel
@onready var race_specialties_label: RichTextLabel = $CenterBox/Box/RaceSection/Details/RaceDetailPanel/RaceDetailBox/RaceSpecialtiesLabel
@onready var race_accent: ColorRect = $CenterBox/Box/RaceSection/Details/RaceDetailPanel/RaceDetailBox/RaceAccent
@onready var lore_button: Button = $CenterBox/Box/RaceSection/Details/RaceDetailPanel/RaceDetailBox/LoreButton
@onready var decrease_rivals_button: Button = $CenterBox/Box/RaceSection/Details/ConfigurationPanel/ConfigurationBox/ConfigurationRow/RivalCountRow/DecreaseRivalsButton
@onready var rival_count_value: Label = $CenterBox/Box/RaceSection/Details/ConfigurationPanel/ConfigurationBox/ConfigurationRow/RivalCountRow/RivalCountValue
@onready var increase_rivals_button: Button = $CenterBox/Box/RaceSection/Details/ConfigurationPanel/ConfigurationBox/ConfigurationRow/RivalCountRow/IncreaseRivalsButton
@onready var back_button: Button = $Footer/FooterRow/BackButton
@onready var start_game_button: Button = $Footer/FooterRow/StartGameButton
@onready var status_label: Label = $CenterBox/Box/RaceSection/Details/ConfigurationPanel/ConfigurationBox/StatusLabel
@onready var map_size_buttons: HBoxContainer = $CenterBox/Box/RaceSection/Details/ConfigurationPanel/ConfigurationBox/MapSizeButtons
@onready var map_size_hint: Label = $CenterBox/Box/RaceSection/Details/ConfigurationPanel/ConfigurationBox/MapSizeHint
@onready var map_rule_label: Label = $Footer/FooterRow/Summary/MapRuleLabel

const LOBBY_THEME := preload("res://scripts/ui/GameSetupTheme.gd")
var _race_cards: Dictionary = {}

var _selected_race := "human"
var _selected_rival_count := 1
## Tamanho do mapa (2026-10-10): id de WorldProfile.playable_sizes() — Pequeno/Médio/Grande, padrão Grande. Os botões
## saem dos perfis (nunca uma lista paralela aqui).
var _selected_map_size: String = String(WorldProfile.default_size().id)
var _map_size_group := ButtonGroup.new()
var _selected_difficulty: String = V2AIDifficulty.NORMAL
var _difficulty_group := ButtonGroup.new()
var difficulty_buttons: HBoxContainer
var difficulty_hint: Label

func _ready() -> void:
	_apply_accessibility_theme()
	Settings.accessibility_changed.connect(_apply_accessibility_theme)
	_label_race_buttons()
	_build_race_portraits()
	human_race_button.pressed.connect(_on_race_pressed.bind("human"))
	elf_race_button.pressed.connect(_on_race_pressed.bind("elf"))
	dwarf_race_button.pressed.connect(_on_race_pressed.bind("dwarf"))
	orc_race_button.pressed.connect(_on_race_pressed.bind("orc"))
	decrease_rivals_button.pressed.connect(_step_rivals.bind(-1))
	increase_rivals_button.pressed.connect(_step_rivals.bind(1))
	back_button.pressed.connect(_on_back_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	lore_button.pressed.connect(_on_lore_pressed)
	kingdom_name_edit.text_changed.connect(_validate_name)
	_build_map_size_buttons()
	_build_difficulty_selector()
	_update_race_detail(_selected_race)
	_update_rival_stepper()
	_update_map_size()
	get_viewport().size_changed.connect(_layout_for_viewport)
	visibility_changed.connect(_on_visibility_changed)
	_layout_for_viewport.call_deferred()
	human_race_button.call_deferred("grab_focus")

func _apply_accessibility_theme() -> void:
	theme = LOBBY_THEME.build(Settings.ui_scale_factor())
	_layout_for_viewport.call_deferred()

func _build_race_portraits() -> void:
	_race_cards = {"human":human_race_button, "elf":elf_race_button, "dwarf":dwarf_race_button, "orc":orc_race_button}
	for race in _race_cards:
		var button: Button = _race_cards[race]
		var emblem := TextureRect.new()
		emblem.name = "Emblem"
		emblem.texture = load(LOBBY_THEME.ART + "emblem_" + race + ".svg") as Texture2D
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(emblem)
		button.tooltip_text = RACE_INFO[race].display_name + "\n" + V2RaceBonusDatabase.summary(race)
		var portrait := TextureRect.new()
		portrait.name = "Portrait"
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.texture = load(LOBBY_THEME.ART + "city_" + race + ".png") as Texture2D
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.anchor_bottom = .75
		portrait.offset_left = 12
		portrait.offset_right = -12
		portrait.offset_top = 10
		button.add_child(portrait)
		var selected := Label.new()
		selected.name = "SelectedMark"
		selected.text = "✓"
		selected.add_theme_font_override("font", ThemeDB.fallback_font)
		selected.add_theme_color_override("font_color", Color("ffe3a3"))
		selected.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(selected)
		selected.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		selected.offset_left = -36
		selected.offset_right = -12
		selected.offset_top = 12
		selected.offset_bottom = 36

func _on_visibility_changed() -> void:
	if is_visible_in_tree() and is_node_ready():
		_layout_for_viewport.call_deferred()
		_race_cards.get(_selected_race, human_race_button).call_deferred("grab_focus")

func _layout_for_viewport() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport_rect().size
	var factor := Settings.ui_scale_factor()
	var compact := viewport_size.y < 800
	var width := minf(viewport_size.x - 64, 1320 * maxf(1.0, factor))
	var left := roundf((viewport_size.x - width) / 2)
	var edge := 24.0 if compact else 36.0
	var header: HBoxContainer = $Header
	$Header/Hint.visible = viewport_size.x > 1100 and factor <= 1.1
	$Header/Crest.custom_minimum_size = Vector2.ONE * (44 if compact else 56)
	$Header/Titles/TitleLabel.add_theme_font_size_override("font_size", roundi((36 if compact else 44) * factor))
	header.position = Vector2(left, edge)
	header.size = Vector2(width, header.get_combined_minimum_size().y)
	var footer: VBoxContainer = $Footer
	back_button.custom_minimum_size = Vector2(140 * factor, 52 * factor)
	start_game_button.custom_minimum_size = Vector2(250 * factor, 52 * factor)
	footer.size = Vector2(width, footer.get_combined_minimum_size().y)
	footer.position = Vector2(left, viewport_size.y - edge - footer.size.y)
	var scroll: ScrollContainer = $CenterBox
	scroll.position = Vector2(left, header.position.y + header.size.y + 20)
	scroll.size = Vector2(width, maxf(120, footer.position.y - scroll.position.y - 20))
	$CenterBox/Box/RaceSection.add_theme_constant_override("separation", 12 if compact else 16)
	var config: VBoxContainer = kingdom_name_edit.get_parent()
	config.add_theme_constant_override("separation", roundi((6 if compact else 10) * factor))
	config.get_node("NameHint").visible = not compact
	for button in map_size_buttons.get_children():
		button.custom_minimum_size = Vector2(90 * factor, 44 * factor)
	if difficulty_buttons != null:
		for button in difficulty_buttons.get_children():
			button.custom_minimum_size = Vector2(90 * factor, 44 * factor)
		difficulty_hint.visible = not compact
	kingdom_name_edit.custom_minimum_size.y = 44 * factor
	for button in [decrease_rivals_button, increase_rivals_button]:
		button.custom_minimum_size = Vector2.ONE * 44 * factor
	for button: Button in _race_cards.values():
		button.custom_minimum_size = Vector2(0, roundf((136 if compact else 190) * factor))
		button.get_node("Emblem").position = Vector2.ONE * roundf(16 * factor)
		button.get_node("Emblem").size = Vector2.ONE * roundf(24 * factor)
		button.get_node("SelectedMark").add_theme_font_size_override("font_size", roundi(18 * factor))
	_update_race_tiles()
	_configure_focus()

func _configure_focus() -> void:
	var cards: Array[Button] = [human_race_button, elf_race_button, dwarf_race_button, orc_race_button]
	var linear: Array[Control] = [human_race_button, elf_race_button, dwarf_race_button, orc_race_button, lore_button, kingdom_name_edit]
	for button in map_size_buttons.get_children():
		linear.append(button)
	for control in [decrease_rivals_button, increase_rivals_button]:
		if not control.disabled:
			linear.append(control)
	if difficulty_buttons != null:
		for button in difficulty_buttons.get_children():
			linear.append(button)
	for control in [back_button, start_game_button]:
		if not control.disabled:
			linear.append(control)
	for i in linear.size():
		var control := linear[i]
		control.focus_next = control.get_path_to(linear[(i + 1) % linear.size()])
		control.focus_previous = control.get_path_to(linear[posmod(i - 1, linear.size())])
	for i in cards.size():
		cards[i].focus_neighbor_left = cards[i].get_path_to(cards[maxi(0, i - 1)])
		cards[i].focus_neighbor_right = cards[i].get_path_to(cards[mini(cards.size() - 1, i + 1)])
		cards[i].focus_neighbor_bottom = cards[i].get_path_to(lore_button if i < 2 else kingdom_name_edit)
		cards[i].focus_neighbor_top = cards[i].get_path_to(cards[i])
	lore_button.focus_neighbor_top = lore_button.get_path_to(_race_cards.get(_selected_race, human_race_button))
	lore_button.focus_neighbor_bottom = lore_button.get_path_to(back_button)
	lore_button.focus_neighbor_right = lore_button.get_path_to(kingdom_name_edit)
	kingdom_name_edit.focus_neighbor_top = kingdom_name_edit.get_path_to(dwarf_race_button)
	kingdom_name_edit.focus_neighbor_bottom = kingdom_name_edit.get_path_to(map_size_buttons.get_child(0))
	var maps := map_size_buttons.get_children()
	for i in maps.size():
		var button: Button = maps[i]
		button.focus_neighbor_top = button.get_path_to(kingdom_name_edit)
		button.focus_neighbor_bottom = button.get_path_to(increase_rivals_button if not increase_rivals_button.disabled else decrease_rivals_button)
		button.focus_neighbor_left = button.get_path_to(maps[maxi(0, i - 1)])
		button.focus_neighbor_right = button.get_path_to(maps[mini(maps.size() - 1, i + 1)])
	var difficulty: Array = difficulty_buttons.get_children() if difficulty_buttons != null else []
	for button in [decrease_rivals_button, increase_rivals_button]:
		button.focus_neighbor_bottom = button.get_path_to(difficulty[1] if difficulty.size() > 1 else start_game_button)
		button.focus_neighbor_top = button.get_path_to(maps[1])
	for i in difficulty.size():
		var button: Button = difficulty[i]
		button.focus_neighbor_top = button.get_path_to(increase_rivals_button if not increase_rivals_button.disabled else decrease_rivals_button)
		button.focus_neighbor_bottom = button.get_path_to(start_game_button)
		button.focus_neighbor_left = button.get_path_to(difficulty[maxi(0, i - 1)])
		button.focus_neighbor_right = button.get_path_to(difficulty[mini(difficulty.size() - 1, i + 1)])
	back_button.focus_neighbor_right = back_button.get_path_to(start_game_button)
	back_button.focus_neighbor_top = back_button.get_path_to(lore_button)
	start_game_button.focus_neighbor_left = start_game_button.get_path_to(back_button)
	start_game_button.focus_neighbor_top = start_game_button.get_path_to(difficulty[1] if difficulty.size() > 1 else (increase_rivals_button if not increase_rivals_button.disabled else decrease_rivals_button))

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()

## Texto dos botoes da lista vem de RACE_INFO (nao hardcoded no .tscn) —
## fonte unica com o painel de detalhe, pra "Humano"/"Elfo"/"Anao"/"Orc"
## nunca dessincronizar de RACE_INFO.display_name.
func _label_race_buttons() -> void:
	human_race_button.text = RACE_INFO.human.race_name
	elf_race_button.text = RACE_INFO.elf.race_name
	dwarf_race_button.text = RACE_INFO.dwarf.race_name
	orc_race_button.text = RACE_INFO.orc.race_name

## Volta pro padrao (Humano, 1 rival, nome vazio) — chamado pelo Main.gd
## toda vez que a tela abre (ver _on_new_game_setup_requested), senao
## "Voltar" no meio de uma configuracao e clicar "Novo Jogo" de novo
## reabriria com os BOTOES no estado antigo mas _selected_* ja resetado
## (ou vice-versa), dessincronizado.
func reset_to_defaults() -> void:
	_selected_race = "human"
	_selected_rival_count = 1
	_selected_map_size = String(WorldProfile.default_size().id)
	_update_map_size()
	_selected_difficulty = V2AIDifficulty.NORMAL
	_update_difficulty()
	human_race_button.button_pressed = true
	kingdom_name_edit.text = ""
	status_label.text = ""
	_update_race_detail(_selected_race)
	_update_rival_stepper()
	_validate_name(kingdom_name_edit.text)
	$CenterBox.scroll_vertical = 0

func _on_race_pressed(race: String) -> void:
	_selected_race = race
	_update_race_detail(race)
	_validate_name(kingdom_name_edit.text)
	_update_summary()

## Espelha a raca selecionada no painel de detalhe grande (nome/epiteto/
## lore) — mesmo padrao "lista a esquerda, detalhe a
## direita atualiza ao trocar selecao" do seletor de civilizacao do
## Civilization, pedido do usuario: "quero um menu de racas tao elaborada
## quanto o civilization". RichTextLabel com BBCode (nao Label puro) pra a lore poder usar destaque.
func _update_race_detail(race: String) -> void:
	var info: Dictionary = RACE_INFO.get(race, RACE_INFO.human)
	race_name_label.text = info.display_name
	race_tagline_label.text = info.tagline
	race_lore_label.text = info.lore
	var effects := V2RaceBonusDatabase.effect_lines(race)
	race_specialties_label.text = "[b]Especialidades:[/b]\n• %s" % "\n• ".join(effects.slice(0, 2))
	race_accent.color = RACE_COLORS.get(race, UIThemeTokens.COLOR_ACCENT)
	race_lore_label.visible = false
	lore_button.text = "Conhecer história"
	_update_race_tiles()
	# Placeholder do campo de nome segue a raca selecionada — antes ficava
	# fixo em "Reino de Aldenmark" (nome humano) nao importa a raca
	# escolhida, o que junto do fallback tambem fixo em GameManager.
	# _default_kingdom_name_for_race fazia um jogador de Elfo/Anao/Orc que
	# nao digitasse nome proprio acabar com reino chamado "Aldenmark" mesmo
	# assim (bug relatado pelo usuario: "escolhi outro reino e iniciei com
	# o reino humano"). So atualiza o TEXTO fantasma — nunca sobrescreve um
	# nome que o jogador ja digitou (kingdom_name_edit.text continua dele).
	kingdom_name_edit.placeholder_text = info.display_name

func _build_map_size_buttons() -> void:
	for child in map_size_buttons.get_children():
		child.queue_free()
	for profile in WorldProfile.playable_sizes():
		var button := Button.new()
		button.name = "MapSize_%s" % profile.id
		button.text = String(profile.label)
		button.toggle_mode = true
		button.button_group = _map_size_group
		button.custom_minimum_size = Vector2(96, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = &"SetupMapButton"
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = _map_size_text(profile)
		button.pressed.connect(_on_map_size_pressed.bind(String(profile.id)))
		map_size_buttons.add_child(button)

func _build_difficulty_selector() -> void:
	var config: VBoxContainer = kingdom_name_edit.get_parent()
	var anchor_index := config.get_node("ConfigurationRow").get_index() + 1
	var title := Label.new()
	title.name = "DifficultyLabel"
	title.text = "Dificuldade das IAs"
	title.theme_type_variation = &"SetupBody"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	difficulty_buttons = HBoxContainer.new()
	difficulty_buttons.name = "DifficultyButtons"
	difficulty_buttons.add_theme_constant_override("separation", 8)
	for level in V2AIDifficulty.LEVELS:
		var button := Button.new()
		button.name = "Difficulty_%s" % level
		button.text = V2AIDifficulty.label(level)
		button.toggle_mode = true
		button.button_group = _difficulty_group
		button.custom_minimum_size = Vector2(96, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme_type_variation = &"SetupMapButton"
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = V2AIDifficulty.description(level)
		button.pressed.connect(_on_difficulty_pressed.bind(level))
		difficulty_buttons.add_child(button)
	difficulty_hint = Label.new()
	difficulty_hint.name = "DifficultyHint"
	difficulty_hint.theme_type_variation = &"SetupMuted"
	difficulty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	difficulty_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	config.add_child(title)
	config.move_child(title, anchor_index)
	config.add_child(difficulty_buttons)
	config.move_child(difficulty_buttons, anchor_index + 1)
	config.add_child(difficulty_hint)
	config.move_child(difficulty_hint, anchor_index + 2)
	_update_difficulty()

func _on_difficulty_pressed(level: String) -> void:
	_selected_difficulty = V2AIDifficulty.normalized(level)
	_update_difficulty()

func _update_difficulty() -> void:
	if difficulty_buttons == null:
		return
	for button in difficulty_buttons.get_children():
		(button as Button).set_pressed_no_signal(String(button.name) == "Difficulty_%s" % _selected_difficulty)
	difficulty_hint.text = V2AIDifficulty.description(_selected_difficulty) + " A inteligência das IAs é a mesma em todos os níveis."
	_update_summary()

func _on_map_size_pressed(size_id: String) -> void:
	_selected_map_size = size_id
	_update_map_size()

## Perfil escolhido (cai no padrão se o id não existir).
func selected_map_profile() -> Dictionary:
	var profile := WorldProfile.by_id(_selected_map_size)
	return profile if not profile.is_empty() else WorldProfile.default_size()

func _map_size_text(profile: Dictionary) -> String:
	return "%d × %d hexágonos · ~%d tiles de terra" % [int(profile.width), int(profile.height), WorldProfile.estimated_land_tiles(profile)]

func _update_map_size() -> void:
	var profile := selected_map_profile()
	for button in map_size_buttons.get_children():
		if button is Button:
			(button as Button).set_pressed_no_signal(String(button.name) == "MapSize_%s" % profile.id)
	map_size_hint.text = _map_size_text(profile)
	_update_summary()

func _update_summary() -> void:
	map_rule_label.text = "%s  ·  Mapa %s  ·  %d %s  ·  IAs: %s" % [RACE_INFO[_selected_race].race_name, selected_map_profile().label, _selected_rival_count, "rival" if _selected_rival_count == 1 else "rivais", V2AIDifficulty.label(_selected_difficulty)]
	map_rule_label.tooltip_text = "%s\n%s\n%s" % [RACE_INFO[_selected_race].display_name, selected_map_profile().label, _map_size_text(selected_map_profile())]

func _on_rival_count_pressed(count: int) -> void:
	_selected_rival_count = clampi(count, 1, 3)
	_update_rival_stepper()

func _step_rivals(delta: int) -> void:
	_on_rival_count_pressed(_selected_rival_count + delta)

func _update_rival_stepper() -> void:
	rival_count_value.text = str(_selected_rival_count)
	decrease_rivals_button.disabled = _selected_rival_count <= 1
	increase_rivals_button.disabled = _selected_rival_count >= 3
	_update_summary()
	_configure_focus.call_deferred()

func _update_race_tiles() -> void:
	var entries := {
		"human": human_race_button,
		"elf": elf_race_button,
		"dwarf": dwarf_race_button,
		"orc": orc_race_button,
	}
	for race in entries:
		var button: Button = entries[race]
		var selected: bool = str(race) == _selected_race
		button.set_pressed_no_signal(selected)
		for state in ["normal", "pressed", "hover", "hover_pressed"]:
			var style := LOBBY_THEME.panel(selected or state.begins_with("hover"), Settings.ui_scale_factor())
			style.set_content_margin(SIDE_TOP, button.custom_minimum_size.y * .75)
			style.set_content_margin(SIDE_BOTTOM, 12 * Settings.ui_scale_factor())
			button.add_theme_stylebox_override(state, style)
		var focus := LOBBY_THEME.TITLE_THEME._frame("button_focus", Settings.ui_scale_factor())
		button.add_theme_stylebox_override("focus", focus)
		if button.has_node("SelectedMark"):
			button.get_node("SelectedMark").visible = selected

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_lore_pressed() -> void:
	race_lore_label.visible = not race_lore_label.visible
	lore_button.text = "Ocultar história" if race_lore_label.visible else "Conhecer história"

func _validate_name(value: String) -> bool:
	var trimmed := value.strip_edges()
	if trimmed.is_empty():
		status_label.text = ""
		status_label.visible = false
		start_game_button.disabled = false
		return true
	if trimmed.length() < 2:
		status_label.text = "O nome precisa ter pelo menos 2 caracteres."
		status_label.visible = true
		status_label.modulate = Color("ffb09b")
		start_game_button.disabled = true
		return false
	status_label.text = ""
	status_label.visible = false
	start_game_button.disabled = false
	return true

func _on_start_game_pressed() -> void:
	if not _validate_name(kingdom_name_edit.text):
		kingdom_name_edit.grab_focus()
		return
	var size: Dictionary = selected_map_profile()
	var kingdom_name := kingdom_name_edit.text.strip_edges()
	if kingdom_name.is_empty():
		kingdom_name = RACE_INFO[_selected_race].display_name
	new_game_requested.emit(
		size.width, size.height, kingdom_name, _selected_rival_count, _selected_difficulty, _selected_race
	)
