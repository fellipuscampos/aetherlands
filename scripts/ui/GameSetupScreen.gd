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
## de detalhe a direita (nome, epiteto, lore, tropa exclusiva com blurb) —
## mesmo padrao "lista + detalhe atualiza ao trocar selecao" da tela de
## civilizacao do Civ, so com portrait nenhum (o jogo inteiro e modelos
## procedurais, sem arte de personagem) — o "elaborado" aqui vem do TEXTO
## (lore + explicacao mecanica), nao de uma imagem.

signal new_game_requested(width: int, height: int, kingdom_name: String, rival_count: int, difficulty: String, race: String)
signal back_requested

## Uma entrada por raca escolhivel — fonte unica pro painel de detalhe
## (_update_race_detail) E pros botoes da lista (montados a mao no .tscn,
## mas o TEXTO de cada um vem daqui via _label_race_buttons, pra "Humano"/
## "Elfo"/"Anao"/"Orc" nunca dessincronizar do display_name usado no
## painel). Lore/epiteto conectados a mecanica REAL de cada tropa
## exclusiva (ver UnitDatabase.create_unit) — nao e so flavor solto, cada
## frase aponta pra um numero que existe de verdade no jogo.
const RACE_INFO := {
	"human": {
		"display_name": "Humano",
		"tagline": "Versátil e Ambicioso",
		"lore": "Espalhados por todos os cantos de Aetherlands, os reinos humanos prosperam através da adaptação e da diplomacia. Sem nenhuma vantagem natural marcante como anões ou elfos, os humanos compensam com disciplina militar e a lealdade inabalável de seus cavaleiros — um povo que constrói impérios não pela força bruta, mas pela ordem.",
		"unique_unit_name": "Cavaleiro Real",
		"unique_unit_blurb": "Um cavaleiro montado equilibrado, com a maior defesa entre as tropas raciais [b]móveis[/b] (perde só pro Guarda-Machado Anão, que fica parado) — a versatilidade humana em forma de aço e lança.",
	},
	"elf": {
		"display_name": "Elfo",
		"tagline": "Ancião e Ágil",
		"lore": "O Reino Élfico de Verdemata guarda os segredos das florestas mais antigas de Aetherlands. Vivendo em harmonia com a natureza há séculos, os elfos dominam a arte da mobilidade e do tiro certeiro, preferindo golpear de longe e desaparecer entre as árvores a travar combate corpo-a-corpo.",
		"unique_unit_name": "Patrulheiro Élfico",
		"unique_unit_blurb": "A tropa mais [b]ágil[/b] do jogo em terra, com o maior alcance de ataque e o maior alcance de visão do elenco inteiro — enxerga e atinge o inimigo antes de ser visto.",
	},
	"dwarf": {
		"display_name": "Anão",
		"tagline": "Inabalável e Resiliente",
		"lore": "Sob as montanhas de Ferroeste, os anões forjam impérios na pedra e no metal. Lentos para avançar mas quase impossíveis de derrubar, os clãs anões confiam na resistência de suas fileiras blindadas para vencer qualquer cerco — o que um anão conquista, um anão mantém.",
		"unique_unit_name": "Guarda-Machado Anão",
		"unique_unit_blurb": "A maior [b]defesa[/b] entre todas as tropas raciais do jogo — pernas curtas, mas uma parede de metal que não sai do lugar.",
	},
	"orc": {
		"display_name": "Orc",
		"tagline": "Selvagem e Implacável",
		"lore": "A Horda das Brumas segue a Xamã Skarn através de terras devastadas pela guerra, vivendo pelo combate e pela glória da batalha. Sem se preocupar com armadura ou disciplina de fileira, os berserkers orcs confiam na fúria bruta para esmagar qualquer inimigo antes que ele tenha chance de reagir.",
		"unique_unit_name": "Berserker Orc",
		"unique_unit_blurb": "O maior [b]ataque corpo-a-corpo[/b] do jogo, de propósito — e a menor defesa entre as tropas raciais, sem armadura nenhuma. Todo o investimento é ofensivo.",
	},
}

@onready var kingdom_name_edit: LineEdit = $CenterBox/Box/KingdomNameEdit
@onready var human_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/HumanRaceButton
@onready var elf_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/ElfRaceButton
@onready var dwarf_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/DwarfRaceButton
@onready var orc_race_button: Button = $CenterBox/Box/RaceSection/RaceListColumn/OrcRaceButton
@onready var race_name_label: Label = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/RaceNameLabel
@onready var race_tagline_label: Label = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/RaceTaglineLabel
@onready var race_lore_label: RichTextLabel = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/RaceLoreLabel
@onready var race_unique_name_label: Label = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/RaceUniqueNameLabel
@onready var race_unique_blurb_label: RichTextLabel = $CenterBox/Box/RaceSection/RaceDetailPanel/RaceDetailBox/RaceUniqueBlurbLabel
@onready var one_rival_button: Button = $CenterBox/Box/RivalCountRow/OneRivalButton
@onready var two_rivals_button: Button = $CenterBox/Box/RivalCountRow/TwoRivalsButton
@onready var three_rivals_button: Button = $CenterBox/Box/RivalCountRow/ThreeRivalsButton
@onready var back_button: Button = $CenterBox/Box/FooterRow/BackButton
@onready var start_game_button: Button = $CenterBox/Box/FooterRow/StartGameButton
@onready var status_label: Label = $CenterBox/Box/StatusLabel

var _selected_race := "human"
var _selected_rival_count := 1

func _ready() -> void:
	theme = UITheme.build()
	_label_race_buttons()
	human_race_button.pressed.connect(_on_race_pressed.bind("human"))
	elf_race_button.pressed.connect(_on_race_pressed.bind("elf"))
	dwarf_race_button.pressed.connect(_on_race_pressed.bind("dwarf"))
	orc_race_button.pressed.connect(_on_race_pressed.bind("orc"))
	one_rival_button.pressed.connect(_on_rival_count_pressed.bind(1))
	two_rivals_button.pressed.connect(_on_rival_count_pressed.bind(2))
	three_rivals_button.pressed.connect(_on_rival_count_pressed.bind(3))
	back_button.pressed.connect(_on_back_pressed)
	start_game_button.pressed.connect(_on_start_game_pressed)
	_update_race_detail(_selected_race)

## Texto dos botoes da lista vem de RACE_INFO (nao hardcoded no .tscn) —
## fonte unica com o painel de detalhe, pra "Humano"/"Elfo"/"Anao"/"Orc"
## nunca dessincronizar de RACE_INFO.display_name.
func _label_race_buttons() -> void:
	human_race_button.text = RACE_INFO.human.display_name
	elf_race_button.text = RACE_INFO.elf.display_name
	dwarf_race_button.text = RACE_INFO.dwarf.display_name
	orc_race_button.text = RACE_INFO.orc.display_name

## Volta pro padrao (Humano, 1 rival, nome vazio) — chamado pelo Main.gd
## toda vez que a tela abre (ver _on_new_game_setup_requested), senao
## "Voltar" no meio de uma configuracao e clicar "Novo Jogo" de novo
## reabriria com os BOTOES no estado antigo mas _selected_* ja resetado
## (ou vice-versa), dessincronizado.
func reset_to_defaults() -> void:
	_selected_race = "human"
	_selected_rival_count = 1
	human_race_button.button_pressed = true
	one_rival_button.button_pressed = true
	kingdom_name_edit.text = ""
	status_label.text = ""
	_update_race_detail(_selected_race)

func _on_race_pressed(race: String) -> void:
	_selected_race = race
	_update_race_detail(race)

## Espelha a raca selecionada no painel de detalhe grande (nome/epiteto/
## lore/tropa exclusiva) — mesmo padrao "lista a esquerda, detalhe a
## direita atualiza ao trocar selecao" do seletor de civilizacao do
## Civilization, pedido do usuario: "quero um menu de racas tao elaborada
## quanto o civilization". RichTextLabel com BBCode (nao Label puro) pra
## poder destacar em negrito o numero/mecanica real da tropa dentro do
## texto de lore (ver RACE_INFO acima), sem precisar de nenhum asset novo.
func _update_race_detail(race: String) -> void:
	var info: Dictionary = RACE_INFO.get(race, RACE_INFO.human)
	race_name_label.text = info.display_name
	race_tagline_label.text = info.tagline
	race_lore_label.text = info.lore
	race_unique_name_label.text = "Tropa Exclusiva: %s" % info.unique_unit_name
	race_unique_blurb_label.text = info.unique_unit_blurb

func _on_rival_count_pressed(count: int) -> void:
	_selected_rival_count = count

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_start_game_pressed() -> void:
	var size: Dictionary = TitleScreen.MAP_SIZES.large
	new_game_requested.emit(
		size.width, size.height, kingdom_name_edit.text.strip_edges(), _selected_rival_count, "normal", _selected_race
	)
