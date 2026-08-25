class_name RaceTheme
extends RefCounted

## Camada de APRESENTACAO por raca pro ramo militar "mundano" da arvore de
## tecnologia (Quartel/Estabulo/Arquearia/Batedor Montado + as 4 tropas que
## elas liberam + os 3 predios de treino correspondentes) MAIS a tropa
## inicial "warrior"/Guarda (sem tech associada, mas igualmente "tropa
## basica" de cada civilizacao — pedido do usuario, numa rodada seguinte:
## "ta vindo ainda o guarda padrao quando escolho outra civilização, sendo
## que era pra vir a tropa basica de cada civilização"). Escopo original
## confirmado como so o ramo militar mundano (nao a arvore de magia
## inteira).
##
## Os ids MECANICOS (TechData.id/UnitData kind/BuildingData.id) nao mudam
## em NADA — mesmo custo, mesmos pre-requisitos, mesmas estatisticas, save
## compativel. Essa classe so guarda o TEXTO e o KIT DE ESTILO visual
## exibidos por cima, indexados por CivilizationData.race. "human" de
## proposito NAO entra nas tabelas: os getters caem no fallback (dado
## original de TechDatabase/UnitDatabase/BuildingDatabase) sempre que a
## raca nao e ana/orc/elfica OU o id nao e um dos escopados aqui — assim
## um jogador humano nunca ve diferenca nenhuma, e nao existe string
## duplicada que possa dessincronizar do dado original.
##
## Nomes alinhados com o lore ja existente em GameSetupScreen.RACE_INFO:
## Liga dos Clas de Ferro (ana, tema clã/forja/riqueza), Horda dos Clãs
## Primordiais (orc, tema horda/força bruta/lobos), Império de Elenor
## (élfico, teocracia SOLAR — dourado, não prateado, mesmo tema do
## Arqueiro Solar/Rei-Deus já estabelecido).

const _TECH_NAMES := {
	"dwarf": {
		"quartel": "Salão do Clã",
		"estabulo": "Currais de Javali",
		"arquearia": "Mestria com Bestas",
		"batedor_montado": "Batedores das Minas",
	},
	"orc": {
		"quartel": "Fossa de Guerra",
		"estabulo": "Currais de Lobos",
		"arquearia": "Caçada da Horda",
		"batedor_montado": "Batedores Lupinos",
	},
	"elf": {
		"quartel": "Salão da Guarda Solar",
		"estabulo": "Estábulo dos Corcéis Celestes",
		"arquearia": "Tradição do Arco de Luz",
		"batedor_montado": "Batedores Solares",
	},
}

const _TECH_DESCRIPTIONS := {
	"dwarf": {
		"quartel": "Os anciões de cada clã da Liga cravam suas machadinhas na mesma mesa de ferro e juram guardar as galerias e as forjas com o mesmo fervor — o alicerce de uma milícia clânica disciplinada, sem magia nenhuma envolvida, só aço e teimosia.",
		"estabulo": "Domar um javali das cavernas exige mais paciência que força — um mestre-tratador aprende a acalmar as presas e blindar o lombo do animal antes de qualquer curral abrigar uma montaria de guerra de verdade.",
		"arquearia": "Dedos grossos demais para um arco élfico encontram sua resposta na alavanca e na corda tensa de uma besta — um armeiro do clã formaliza a mira, o gatilho e a manutenção do mecanismo até virar segunda natureza.",
		"batedor_montado": "Quem já se perdeu numa galeria sem fim sabe: um batedor de javali que conhece cada veio e desvio das minas vale mais que um exército inteiro andando às cegas.",
	},
	"orc": {
		"quartel": "Os chefes de guerra da Horda cravam suas armas no chão de uma fossa comum e juram lealdade não a um rei, mas ao mais forte entre eles — o nascimento de uma milícia bruta, unida só pelo medo e pelo respeito.",
		"estabulo": "Um lobo das terras selvagens não se doma, se domina — um caçador experiente aprende a impor sua vontade sobre a alcateia até ela aceitar carregar um guerreiro nas costas sem tentar arrancar sua garganta.",
		"arquearia": "Puxar um arco curto correndo, sem parar para mirar direito, é um talento que se treina na caça de verdade, não em campo de tiro — a Horda formaliza o instinto do caçador em disciplina de guerra.",
		"batedor_montado": "Um batedor montado num lobo cheira o inimigo antes de vê-lo — a Horda aprende a soltar seus batedores mais rápidos e famintos bem à frente de qualquer invasão.",
	},
	"elf": {
		"quartel": "Sob a bênção do Rei-Deus, os primeiros guardiões de Elenor juram proteger os templos e as fronteiras com a mesma disciplina de um rito sagrado — uma milícia teocrática, não uma simples milícia.",
		"estabulo": "Os corcéis que pastam nos jardins suspensos de Elenor descendem, dizem os sacerdotes, de éguas abençoadas pelo próprio Sol — um mestre-cavalariço aprende os ritos necessários antes de qualquer um deles aceitar um cavaleiro.",
		"arquearia": "Um arco comum solta flecha; um arco tocado pela Magia de Luz solta um fragmento do próprio Sol — a tradição arqueira de Elenor funde disciplina física e devoção religiosa em uma única técnica.",
		"batedor_montado": "Vestidos de luz e velocidade, os batedores solares de Elenor cavalgam à frente de qualquer exército, carregando a visão do Rei-Deus para além do horizonte antes que qualquer sombra a alcance.",
	},
}

## "warrior" (Guarda, tropa inicial sempre disponivel sem predio nenhum)
## entrou aqui numa rodada seguinte — pedido do usuario: "ta vindo ainda o
## guarda padrao quando escolho outra civilização, sendo que era pra vir a
## tropa basica de cada civilização, o guarda é a tropa basica humana".
## Nao tem tech associada (diferente das outras 4), mas usa a MESMA tabela
## e o MESMO fallback universal — qualquer chamador que ja le
## RaceTheme.unit_name() pra "warrior" (HUD/UnitPanel/etc) ganha o nome
## tematico de graca, sem precisar de nenhum ajuste extra nesses arquivos.
const _UNIT_NAMES := {
	"dwarf": {
		"warrior": "Sentinela do Clã",
		"men_at_arms": "Guarda do Clã",
		"cavalry": "Cavaleiro de Javali",
		"archer": "Besteiro do Clã",
		"scout": "Batedor das Minas",
	},
	"orc": {
		"warrior": "Recruta da Horda",
		"men_at_arms": "Guerreiro da Horda",
		"cavalry": "Cavaleiro de Lobo",
		"archer": "Caçador da Horda",
		"scout": "Batedor Lupino",
	},
	"elf": {
		"warrior": "Sentinela de Elenor",
		"men_at_arms": "Guarda Solar",
		"cavalry": "Cavaleiro Celeste",
		"archer": "Arqueiro de Elenor",
		"scout": "Batedor Solar",
	},
}

const _BUILDING_NAMES := {
	"dwarf": {
		"barracks": "Salão do Clã",
		"stable": "Currais de Javali",
		"archery_range": "Forja de Bestas",
	},
	"orc": {
		"barracks": "Fossa de Guerra",
		"stable": "Currais de Lobos",
		"archery_range": "Posto de Caça",
	},
	"elf": {
		"barracks": "Salão da Guarda Solar",
		"stable": "Estábulo dos Corcéis Celestes",
		"archery_range": "Círculo de Luz",
	},
}

## metal_color: substitui os tons FIXOS de metal/madeira de arma (aço/cabo
## de machado/clava/arco) que hoje sao hardcoded em Unit.gd.
## mount_color: substitui a cor fixa de pelagem da montaria (Batedor) —
## Cavalaria comum continua tingida pela cor da civ, sem mudanca.
## barracks_color/stable_color/archery_range_color: substituem a cor de
## base (pedra/madeira) de cada um dos 3 predios de treino em Building.gd
## — CAMPOS SEPARADOS de proposito, um por predio: cada um ja tinha seu
## proprio material na versao original (pedra pro Quartel, madeira mais
## clara pro Estabulo, poste de madeira mais escura pro Campo de Tiro) —
## um campo so compartilhado faria o baseline "human" mudar de cor em pelo
## menos dois dos tres predios mesmo sem raca nenhuma tematizada. Os
## valores "human" abaixo sao EXATAMENTE os hardcoded que Building.gd
## tinha antes desta mudanca.
## scale: proporcao aplicada no no raiz da unidade (silhueta atarracada/
## esguia/bruta). "human" = baseline identico ao visual atual em AMBOS os
## arquivos, existe so pra STYLE_KITS.get() ter um fallback valido pra
## raca desconhecida.
const STYLE_KITS := {
	"human": {
		"metal_color": Color(0.65, 0.66, 0.68),
		"mount_color": Color(0.5, 0.36, 0.22),
		"barracks_color": Color(0.42, 0.4, 0.38),
		"stable_color": Color(0.55, 0.42, 0.28),
		"archery_range_color": Color(0.4, 0.28, 0.18),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	"dwarf": {
		"metal_color": Color(0.58, 0.46, 0.24),
		"mount_color": Color(0.32, 0.26, 0.2),
		"barracks_color": Color(0.46, 0.4, 0.32),
		"stable_color": Color(0.48, 0.36, 0.22),
		"archery_range_color": Color(0.36, 0.3, 0.24),
		"scale": Vector3(1.12, 0.75, 1.12),
	},
	"orc": {
		"metal_color": Color(0.35, 0.3, 0.24),
		"mount_color": Color(0.35, 0.33, 0.3),
		"barracks_color": Color(0.34, 0.3, 0.26),
		"stable_color": Color(0.4, 0.32, 0.2),
		"archery_range_color": Color(0.3, 0.24, 0.16),
		"scale": Vector3(1.1, 1.05, 1.1),
	},
	"elf": {
		"metal_color": Color(0.85, 0.72, 0.35),
		"mount_color": Color(0.88, 0.85, 0.78),
		"barracks_color": Color(0.62, 0.56, 0.42),
		"stable_color": Color(0.68, 0.58, 0.4),
		"archery_range_color": Color(0.55, 0.46, 0.3),
		"scale": Vector3(0.92, 1.1, 0.92),
	},
}

static func tech_name(tech_id: String, race: String) -> String:
	return _TECH_NAMES.get(race, {}).get(tech_id, TechDatabase.get_tech(tech_id).display_name)

static func tech_description(tech_id: String, race: String) -> String:
	return _TECH_DESCRIPTIONS.get(race, {}).get(tech_id, TechDatabase.get_tech(tech_id).description)

static func unit_name(kind: String, race: String) -> String:
	return _UNIT_NAMES.get(race, {}).get(kind, UnitDatabase.create_unit(kind).unit_name)

static func building_name(building_id: String, race: String) -> String:
	return _BUILDING_NAMES.get(race, {}).get(building_id, BuildingDatabase.get_building(building_id).display_name)

static func style_kit(race: String) -> Dictionary:
	return STYLE_KITS.get(race, STYLE_KITS.human)
