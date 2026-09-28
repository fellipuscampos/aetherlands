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
## Dificuldade REMOVIDA do seletor (pedido do usuario: "tire as
## dificuldades, agora so tem normal, entao nao precisa nem exibir") —
## sempre emite "normal". GameManager.DIFFICULTY_MULTIPLIERS continua
## tendo "easy"/"hard" (com cobertura de teste propria, ver test_game_
## manager.gd/test_save_manager.gd) — so a ESCOLHA na UI saiu, nao o
## mecanismo, pra nao quebrar esse suporte existente por baixo.
##
## Selecao de raca reestruturada pra ficar "tao elaborada quanto o
## civilization" (pedido do usuario): lista de racas a esquerda + painel
## de detalhe a direita (nome, epiteto, lore) —
## mesmo padrao "lista + detalhe atualiza ao trocar selecao" da tela de
## civilizacao do Civ, so com portrait nenhum (o jogo inteiro e modelos
## procedurais, sem arte de personagem) — o "elaborado" aqui vem do TEXTO
## (lore), nao de uma imagem. Fase 25: a seção "Tropa Exclusiva" saiu. Fase 26: este mesmo painel
## explica as duas especialidades sistêmicas vindas de V2RaceBonusDatabase, sem conteúdo exclusivo.

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

@onready var kingdom_name_edit: LineEdit = $CenterBox/Box/KingdomNameEdit
@onready var human_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/HumanRaceButton
@onready var elf_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/ElfRaceButton
@onready var dwarf_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/DwarfRaceButton
@onready var orc_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/OrcRaceButton
@onready var race_name_label: Label = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/RaceNameLabel
@onready var race_tagline_label: Label = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/RaceTaglineLabel
@onready var race_lore_label: RichTextLabel = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/RaceLoreLabel
@onready var race_specialties_label: RichTextLabel = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/RaceSpecialtiesLabel
@onready var race_accent: ColorRect = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/RaceAccent
@onready var lore_button: Button = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/LoreButton
@onready var decrease_rivals_button: Button = $CenterBox/Box/ConfigurationRow/RivalCountRow/DecreaseRivalsButton
@onready var rival_count_value: Label = $CenterBox/Box/ConfigurationRow/RivalCountRow/RivalCountValue
@onready var increase_rivals_button: Button = $CenterBox/Box/ConfigurationRow/RivalCountRow/IncreaseRivalsButton
@onready var back_button: Button = $CenterBox/Box/FooterRow/BackButton
@onready var start_game_button: Button = $CenterBox/Box/FooterRow/StartGameButton
@onready var status_label: Label = $CenterBox/Box/StatusLabel

var _selected_race := "human"
var _selected_rival_count := 1

func _ready() -> void:
	_apply_accessibility_theme()
	Settings.accessibility_changed.connect(_apply_accessibility_theme)
	_label_race_buttons()
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
	_update_race_detail(_selected_race)
	_update_rival_stepper()
	human_race_button.call_deferred("grab_focus")

func _apply_accessibility_theme() -> void:
	theme = Settings.build_ui_theme()

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
	human_race_button.button_pressed = true
	kingdom_name_edit.text = ""
	status_label.text = ""
	_update_race_detail(_selected_race)
	_update_rival_stepper()

func _on_race_pressed(race: String) -> void:
	_selected_race = race
	_update_race_detail(race)

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

func _on_rival_count_pressed(count: int) -> void:
	_selected_rival_count = clampi(count, 1, 3)
	_update_rival_stepper()

func _step_rivals(delta: int) -> void:
	_on_rival_count_pressed(_selected_rival_count + delta)

func _update_rival_stepper() -> void:
	rival_count_value.text = str(_selected_rival_count)
	decrease_rivals_button.disabled = _selected_rival_count <= 1
	increase_rivals_button.disabled = _selected_rival_count >= 3

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
		var style := StyleBoxFlat.new()
		style.bg_color = UIThemeTokens.COLOR_SURFACE_RAISED if selected else UIThemeTokens.COLOR_SURFACE
		style.border_width_left = 1
		style.border_width_top = 3 if selected else 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = RACE_COLORS[race] if selected else UIThemeTokens.COLOR_BORDER
		style.corner_radius_top_left = UIThemeTokens.RADIUS_CONTROL
		style.corner_radius_top_right = UIThemeTokens.RADIUS_CONTROL
		style.corner_radius_bottom_left = UIThemeTokens.RADIUS_CONTROL
		style.corner_radius_bottom_right = UIThemeTokens.RADIUS_CONTROL
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("pressed", style)

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_lore_pressed() -> void:
	race_lore_label.visible = not race_lore_label.visible
	lore_button.text = "Ocultar história" if race_lore_label.visible else "Conhecer história"

func _validate_name(value: String) -> bool:
	var trimmed := value.strip_edges()
	if trimmed.is_empty():
		status_label.text = "Sem nome personalizado: será usado %s." % RACE_INFO[_selected_race].display_name
		start_game_button.disabled = false
		return true
	if trimmed.length() < 2:
		status_label.text = "O nome precisa ter pelo menos 2 caracteres."
		start_game_button.disabled = true
		return false
	status_label.text = ""
	start_game_button.disabled = false
	return true

func _on_start_game_pressed() -> void:
	if not _validate_name(kingdom_name_edit.text):
		kingdom_name_edit.grab_focus()
		return
	var size: Dictionary = TitleScreen.MAP_SIZES.large
	var kingdom_name := kingdom_name_edit.text.strip_edges()
	if kingdom_name.is_empty():
		kingdom_name = RACE_INFO[_selected_race].display_name
	new_game_requested.emit(
		size.width, size.height, kingdom_name, _selected_rival_count, "normal", _selected_race
	)
