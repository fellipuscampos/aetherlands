class_name RaceTheme
extends RefCounted

## Camada de APRESENTACAO por raca: nome temático de algumas unidades (o Guarda inicial "warrior" e
## as tropas mundanas V1 que ainda podem existir em saves antigos) e o KIT DE ESTILO visual das
## unidades, indexados por CivilizationData.race. Os ids MECÂNICOS nunca mudam. "human" não entra nas
## tabelas de nome: os getters caem no dado original (UnitDatabase/BuildingDatabase).
##
## Fase 25: os nomes temáticos de tecnologias V1 e dos prédios de treino V1 saíram junto com eles.

## Qualquer chamador de RaceTheme.unit_name() (HUD/UnitPanel/inspetor) ganha o nome temático de graça.
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

## metal_color: substitui os tons FIXOS de metal/madeira de arma (aço/cabo
## de machado/clava/arco) que hoje sao hardcoded em Unit.gd.
## mount_color: substitui a cor fixa de pelagem da montaria (Batedor) —
## Cavalaria comum continua tingida pela cor da civ, sem mudanca.
## (Fase 25: as cores de base dos 3 predios de treino V1 -- Quartel/Estabulo/Campo de Tiro -- sairam
## junto com os proprios predios.)
## scale: proporcao aplicada no no raiz da unidade (silhueta atarracada/
## esguia/bruta). "human" = baseline identico ao visual atual em AMBOS os
## arquivos, existe so pra STYLE_KITS.get() ter um fallback valido pra
## raca desconhecida.
const STYLE_KITS := {
	"human": {
		"metal_color": Color(0.65, 0.66, 0.68),
		"mount_color": Color(0.5, 0.36, 0.22),
		"scale": Vector3(1.0, 1.0, 1.0),
	},
	"dwarf": {
		"metal_color": Color(0.58, 0.46, 0.24),
		"mount_color": Color(0.32, 0.26, 0.2),
		"scale": Vector3(1.12, 0.75, 1.12),
	},
	"orc": {
		"metal_color": Color(0.35, 0.3, 0.24),
		"mount_color": Color(0.35, 0.33, 0.3),
		"scale": Vector3(1.1, 1.05, 1.1),
	},
	"elf": {
		"metal_color": Color(0.85, 0.72, 0.35),
		"mount_color": Color(0.88, 0.85, 0.78),
		"scale": Vector3(0.92, 1.1, 0.92),
	},
}

static func unit_name(kind: String, race: String) -> String:
	return _UNIT_NAMES.get(race, {}).get(kind, UnitDatabase.create_unit(kind).unit_name)

static func building_name(building_id: String, _race: String = "") -> String:
	var building := BuildingDatabase.get_building(building_id)
	return building.display_name if building != null else building_id

static func style_kit(race: String) -> Dictionary:
	return STYLE_KITS.get(race, STYLE_KITS.human)
