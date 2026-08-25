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
		"display_name": "Reino de Aldenmark",
		"tagline": "Honra no Aço, Ordem na Fé",
		"lore": "Advindos de outro mundo após um cataclismo devastador, os humanos organizavam-se inicialmente em feudos isolados. Contudo, as constantes ameaças de feras e monstros os obrigaram a se unificar em um vasto império fortemente militarizado, governado por um Rei e estruturado em grandes casas nobres. Convictos da supremacia de sua espécie e fiéis à fé trazida de seu mundo original, compensam a falta de magia inata refinando táticas de guerra ancestrais e ostentando uma doutrina militar implacável centralizada na sua lendária cavalaria.",
		"unique_unit_name": "Cavaleiro Real",
		"unique_unit_blurb": "Cavalaria pesada de elite protegida por armaduras de placas completas. Uma força de impacto devastadora que personifica a honra e o aço de Aldenmark no campo de batalha.",
	},
	"elf": {
		"display_name": "Império de Elenor",
		"tagline": "Os Primeiros Nascidos, Filhos do Sol",
		"lore": "Muito antes do surgimento das raças jovens, os Elfos cruzaram os véus do cosmos e se tornaram uma das primeiras raças conscientes a desbravar Aetherlands. Considerados seres semi-divinos, vivem sob uma rígida teocracia governada por um Rei-Deus e possuem uma maestria inigualável na Magia de Luz, venerando o próprio Sol como a manifestação suprema do divino. No passado, a semelhança entre suas doutrinas fez os humanos cogitarem a submissão ao domínio élfico, mas divergências culturais impediram que uma aliança duradoura se concretizasse.",
		"unique_unit_name": "Arqueiro Solar",
		"unique_unit_blurb": "Atiradores de elite imbuídos com a bênção do Rei-Deus. Seus disparos de pura luz arcana alcançam longas distâncias, ignorando defesas físicas e queimando a resistência dos alvos.",
	},
	"dwarf": {
		"display_name": "Liga dos Clãs de Ferro",
		"tagline": "Mestres do Aço, Guardiões da Riqueza",
		"lore": "Assim como as outras grandes raças, os Anões cruzaram os mundos e fincaram suas raízes nas profundezas de Aetherlands. Desprovidos de um governo centralizado, organizam-se em uma próspera rede de clãs e guildas autônomas, cujos acordos e pactos comerciais se unem firmemente diante das ameaças de guerra. Famosos por sua tenacidade física, aversão à luz da superfície e um apetite insaciável por ouro, dominaram a mineração e a forja a um nível inigualável, tornando suas armas e minérios indispensáveis para o comércio de todas as civilizações.",
		"unique_unit_name": "Guarda-Machado Anão",
		"unique_unit_blurb": "Infantaria pesada inamovível de choque. Possui a maior defesa física do jogo ao permanecer imóvel, servindo como uma verdadeira muralha de ferro e machado na linha de frente.",
	},
	"orc": {
		"display_name": "Horda dos Clãs Primordiais",
		"tagline": "A Ameaça Implacável, Senhores da Guerra",
		"lore": "A origem exata dos Orcs permanece um mistério: enquanto alguns acreditam que vieram de mundos distantes, outros sustentam que são nativos de Aetherlands ou até criados por forças obscuras. Organizados em tribos movidas por pilhagens, invasões e guerra, sua liderança é ditada unicamente pelo direito do mais forte, expandindo seus domínios enquanto o líder mantiver o respeito e o pavor de seus seguidores. Com uma taxa de multiplicação assustadora, são enxergados pelas outras civilizações como uma ameaça implacável, maligna e brutal.",
		"unique_unit_name": "Berserker da Horda",
		"unique_unit_blurb": "Infantaria leve de investida devastadora. Ganha bônus de dano à medida que perde vida no combate, tornando-se extremamente perigosa e incontrolável quando ferida.",
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
	_selected_rival_count = count

func _on_back_pressed() -> void:
	back_requested.emit()

func _on_start_game_pressed() -> void:
	var size: Dictionary = TitleScreen.MAP_SIZES.large
	new_game_requested.emit(
		size.width, size.height, kingdom_name_edit.text.strip_edges(), _selected_rival_count, "normal", _selected_race
	)
