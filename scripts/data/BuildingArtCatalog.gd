class_name BuildingArtCatalog
extends RefCounted

## Fonte ÚNICA da arte própria (assets/generated) de prédios e centros de cidade, POR RAÇA
## (CivilizationData.race). Só apresentação: o BuildingData de cada id é o mesmo para todas as
## civilizações (custo, treino, upkeep e gates nunca variam por raça). Quem consome:
## Building._build_visual (prédio no mapa), City._add_city_center_model (centro da cidade) e
## BuildingDatabase (model_scene_path padrão = arte humana).
##
## O visual segue SEMPRE o dono ATUAL: captura (HexGrid.capture_city) e load (SaveManager) já
## recriam prédios e centro com o novo dono, então uma cidade anã tomada por orcs vira orc.
##
## Regras de fallback (nunca um tile vazio, nunca um erro por arte ainda não feita):
## - Prédio: arte da raça -> arte humana -> BuildingData.model_scene_path.
## - Cidade: nível pedido da raça -> maior nível ABAIXO já feito para a raça -> nível humano.
##   Preferimos manter a identidade da raça a mostrar um castelo humano numa cidade orc; quando
##   o nível novo for exportado, basta adicioná-lo em CITY_ART e ele entra sozinho.
##
## Ao exportar uma arte nova: adicione o stem (nome da pasta = nome do .glb) aqui e rode
## `godot --headless --path . --import`. test_building_art_catalog.gd confere cada caminho e
## cruza com o `gameplay_building_id` dos *_report.json, então um asset esquecido ou trocado
## falha no teste em vez de aparecer errado em jogo.

const DEFAULT_RACE := "human"

## Raça -> pasta em assets/generated.
const RACE_FOLDERS := {
	"human": "humans",
	"dwarf": "dwarves",
	"elf": "elves",
	"orc": "orcs",
}

## Id de BuildingData -> raça -> stem do asset (pasta e arquivo .glb têm o mesmo nome).
const BUILDING_ART := {
	# Infraestrutura — uma única versão por categoria, sem evolução arquitetônica.
	"v2_building_market": {"human": "market_hex_v1", "dwarf": "dwarf_market_hex_v1", "elf": "elf_market_hex_v1", "orc": "orc_market_hex_v1"},
	"v2_building_farm": {"human": "farm_hex_v1", "dwarf": "dwarf_farm_hex_v1", "elf": "elf_farm_hex_v1", "orc": "orc_farm_hex_v1"},
	"v2_building_workshop": {"human": "workshop_hex_v1", "dwarf": "dwarf_workshop_hex_v1", "elf": "elf_workshop_hex_v1", "orc": "orc_workshop_hex_v1"},
	"v2_building_academy": {"human": "university_hex_v1", "dwarf": "dwarf_university_hex_v1", "elf": "elf_university_hex_v1", "orc": "orc_university_hex_v1"},
	"v2_building_arcane_shrine": {"human": "arcane_shrine_hex_v1", "dwarf": "dwarf_arcane_shrine_hex_v1", "elf": "elf_arcane_shrine_hex_v1", "orc": "orc_arcane_shrine_hex_v1"},
	# Doutrinas — prédio de treino (N2) e de Maestria (N8).
	"v2_building_guardian_hall": {"human": "guardian_hall_hex_v2", "dwarf": "dwarf_guardian_hall_hex_v1", "elf": "elf_guardian_hall_hex_v1", "orc": "orc_guardian_hall_hex_v1"},
	"v2_building_guardian_mastery": {"human": "guardian_mastery_hex_v1", "dwarf": "dwarf_guardian_mastery_hex_v1", "elf": "elf_guardian_mastery_hex_v1", "orc": "orc_guardian_mastery_hex_v1"},
	"v2_building_warrior_hall": {"human": "warrior_hall_hex_v1", "dwarf": "dwarf_warrior_hall_hex_v1", "elf": "elf_warrior_hall_hex_v1", "orc": "orc_warrior_hall_hex_v1"},
	"v2_building_warrior_mastery": {"human": "warrior_mastery_hex_v1", "dwarf": "dwarf_warrior_mastery_hex_v1", "elf": "elf_warrior_mastery_hex_v1", "orc": "orc_warrior_mastery_hex_v1"},
	"v2_building_ranger_camp": {"human": "ranger_camp_hex_v1", "dwarf": "dwarf_ranger_camp_hex_v1", "elf": "elf_ranger_camp_hex_v1", "orc": "orc_ranger_camp_hex_v1"},
	"v2_building_ranger_mastery": {"human": "ranger_mastery_hex_v1", "dwarf": "dwarf_ranger_mastery_hex_v1", "elf": "elf_ranger_mastery_hex_v1", "orc": "orc_ranger_mastery_hex_v1"},
	"v2_building_war_stable": {"human": "war_stable_hex_v1", "dwarf": "dwarf_war_stable_hex_v1", "elf": "elf_war_stable_hex_v1", "orc": "orc_war_stable_hex_v1"},
	"v2_building_cavalry_mastery": {"human": "cavalry_mastery_hex_v1", "dwarf": "dwarf_cavalry_mastery_hex_v1", "elf": "elf_cavalry_mastery_hex_v1", "orc": "orc_cavalry_mastery_hex_v1"},
	"v2_building_rogue_guild": {"human": "rogue_guild_hex_v1", "dwarf": "dwarf_rogue_guild_hex_v1", "elf": "elf_rogue_guild_hex_v1", "orc": "orc_rogue_guild_hex_v1"},
	"v2_building_rogue_mastery": {"human": "rogue_mastery_hex_v1", "dwarf": "dwarf_rogue_mastery_hex_v1", "elf": "elf_rogue_mastery_hex_v1", "orc": "orc_rogue_mastery_hex_v1"},
	"v2_building_siege_arsenal": {"human": "siege_arsenal_hex_v1", "dwarf": "dwarf_siege_arsenal_hex_v1", "elf": "elf_siege_arsenal_hex_v1", "orc": "orc_siege_arsenal_hex_v1"},
	"v2_building_grand_arsenal": {"human": "grand_arsenal_hex_v1", "dwarf": "dwarf_grand_arsenal_hex_v1", "elf": "elf_grand_arsenal_hex_v1", "orc": "orc_grand_arsenal_hex_v1"},
	# Escolas de Magia — prédio da Escola (N2) e estrutura ritual (N8).
	"v2_building_sacred_temple": {"human": "sacred_temple_hex_v1", "dwarf": "dwarf_sacred_temple_hex_v1", "elf": "elf_sacred_temple_hex_v1", "orc": "orc_sacred_temple_hex_v1"},
	"v2_building_sacred_ritual": {"human": "sacred_ritual_hex_v1", "dwarf": "dwarf_sacred_ritual_hex_v1", "elf": "elf_sacred_ritual_hex_v1", "orc": "orc_sacred_ritual_hex_v1"},
	"v2_building_infernal_sanctum": {"human": "infernal_sanctum_hex_v1", "dwarf": "dwarf_infernal_sanctum_hex_v1", "elf": "elf_infernal_sanctum_hex_v1", "orc": "orc_infernal_sanctum_hex_v1"},
	"v2_building_infernal_ritual": {"human": "infernal_ritual_hex_v1", "dwarf": "dwarf_infernal_ritual_hex_v1", "elf": "elf_infernal_ritual_hex_v1", "orc": "orc_infernal_ritual_hex_v1"},
	"v2_building_necromancy_ossuary": {"human": "necromancy_ossuary_hex_v1", "dwarf": "dwarf_necromancy_ossuary_hex_v1", "elf": "elf_necromancy_ossuary_hex_v1", "orc": "orc_necromancy_ossuary_hex_v1"},
	"v2_building_necromancy_ritual": {"human": "necromancy_ritual_hex_v1", "dwarf": "dwarf_necromancy_ritual_hex_v1", "elf": "elf_necromancy_ritual_hex_v1", "orc": "orc_necromancy_ritual_hex_v1"},
	"v2_building_druidic_circle": {"human": "druidic_circle_hex_v1", "dwarf": "dwarf_druidic_circle_hex_v1", "elf": "elf_druidic_circle_hex_v1", "orc": "orc_druidic_circle_hex_v1"},
	"v2_building_druidic_ritual": {"human": "druidic_ritual_hex_v1", "dwarf": "dwarf_druidic_ritual_hex_v1", "elf": "elf_druidic_ritual_hex_v1", "orc": "orc_druidic_ritual_hex_v1"},
	"v2_building_arcane_conclave": {"human": "arcane_conclave_hex_v1", "dwarf": "dwarf_arcane_conclave_hex_v1", "elf": "elf_arcane_conclave_hex_v1", "orc": "orc_arcane_conclave_hex_v1"},
	"v2_building_arcane_ritual": {"human": "arcane_ritual_hex_v1", "dwarf": "dwarf_arcane_ritual_hex_v1", "elf": "elf_arcane_ritual_hex_v1", "orc": "orc_arcane_ritual_hex_v1"},
	"v2_building_elemental_observatory": {"human": "elemental_observatory_hex_v1", "dwarf": "dwarf_elemental_observatory_hex_v1", "elf": "elf_elemental_observatory_hex_v1", "orc": "orc_elemental_observatory_hex_v1"},
	"v2_building_elemental_ritual": {"human": "elemental_ritual_hex_v1", "dwarf": "dwarf_elemental_ritual_hex_v1", "elf": "elf_elemental_ritual_hex_v1", "orc": "orc_elemental_ritual_hex_v1"},
}

## Raça -> City Level -> stem do asset. Níveis ausentes caem pela regra do cabeçalho.
const CITY_ART := {
	"human": {1: "city_level_1_hex_v1", 2: "city_level_2_hex_v1", 3: "city_level_3_hex_v1", 4: "city_level_4_hex_v1"},
	"dwarf": {1: "dwarf_city_level_1_hex_v1"},
	"elf": {1: "elf_city_level_1_hex_v1"},
	"orc": {1: "orc_city_level_1_hex_v1"},
}

## Fortificação separada do centro: nível local 1..3, mesma escala do tile.
## Raças ainda sem modelos mantêm a muralha procedural de City._add_walls.
const FORTIFICATION_ART := {
	"human": {1: "human_walls_level_1_hex_v1", 2: "human_walls_level_2_hex_v1", 3: "human_walls_level_3_hex_v1"},
	"elf": {1: "elf_walls_level_1_hex_v1", 2: "elf_walls_level_2_hex_v1", 3: "elf_walls_level_3_hex_v1"},
	"orc": {1: "orc_walls_level_1_hex_v1", 2: "orc_walls_level_2_hex_v1", 3: "orc_walls_level_3_hex_v1"},
	"dwarf": {1: "dwarf_walls_level_1_hex_v1", 2: "dwarf_walls_level_2_hex_v1", 3: "dwarf_walls_level_3_hex_v1"},
}

## Prefixo que identifica arte própria em metros (escala 1:1 com o tile), em oposição ao KayKit.
const GENERATED_PREFIX := "res://assets/generated/"

## Raça reconhecida pelo catálogo; "" ou desconhecida (ex.: PlayerData de teste) -> humana.
static func normalize_race(race: String) -> String:
	return race if RACE_FOLDERS.has(race) else DEFAULT_RACE

static func race_of(player: PlayerData) -> String:
	if player == null or player.civ == null:
		return DEFAULT_RACE
	return normalize_race(player.civ.race)

static func asset_path(race: String, stem: String) -> String:
	return "%s%s/buildings/%s/%s.glb" % [GENERATED_PREFIX, RACE_FOLDERS[normalize_race(race)], stem, stem]

## Arte própria do prédio para a raça; "" se nenhuma raça tem arte para este id (o chamador usa
## então o BuildingData.model_scene_path).
static func building_model_path(building_id: String, race: String) -> String:
	var by_race: Dictionary = BUILDING_ART.get(building_id, {})
	var key := normalize_race(race)
	if by_race.has(key):
		return asset_path(key, by_race[key])
	if by_race.has(DEFAULT_RACE):
		return asset_path(DEFAULT_RACE, by_race[DEFAULT_RACE])
	return ""

## Centro da cidade para a raça e o nível (já limitado a 1..4 pelo chamador).
static func city_model_path(level: int, race: String) -> String:
	var key := normalize_race(race)
	var by_level: Dictionary = CITY_ART[key]
	for candidate in range(level, 0, -1):
		if by_level.has(candidate):
			return asset_path(key, by_level[candidate])
	var human: Dictionary = CITY_ART[DEFAULT_RACE]
	return asset_path(DEFAULT_RACE, human[level]) if human.has(level) else ""

static func is_generated(path: String) -> bool:
	return path.begins_with(GENERATED_PREFIX)

static func fortification_model_path(level: int, race: String) -> String:
	var key := normalize_race(race)
	var by_level: Dictionary = FORTIFICATION_ART.get(key, {})
	return asset_path(key, by_level[level]) if by_level.has(level) else ""

## Tinge só as malhas `*_Faction` (bandeira/placa) com a cor do dono. Duplica o material para não
## alterar o recurso importado compartilhado; pedra, telhas e metal mantêm o atlas pintado.
static func apply_owner_color(model: Node3D, color: Color) -> void:
	for part: MeshInstance3D in model.find_children("*_Faction", "MeshInstance3D", true, false):
		var source_material := part.mesh.surface_get_material(0) as StandardMaterial3D
		if source_material != null:
			var faction_material := source_material.duplicate() as StandardMaterial3D
			faction_material.albedo_color = color
			part.material_override = faction_material
