class_name UnitArtCatalog
extends RefCounted

## Arte própria de tropas POR RAÇA (CivilizationData.race). Só apresentação: stats, custo, técnicas e
## id mecânico vêm de UnitDatabase.create_unit(kind) e são os mesmos para todas as civilizações. A arte
## humana continua declarada em UnitDatabase (é o padrão). O construtor humano também usa este catálogo,
## para adicionar gradualmente os modelos civis das outras raças.
##
## Ponto único de aplicação: Unit.setup()/apply_form() chamam for_owner(), então produção, IA, forças
## iniciais, upgrade (V2UnitUpgrade) e load (SaveManager) recebem a arte do dono sem código próprio.
##
## Cada entrada declara os NOMES REAIS dos clipes do GLB. Anões usam nomes minúsculos e técnicas
## próprias, animadas nos rigs anões; elfos e orcs seguem o padrão humano `<Prefixo>_Idle`...
## Colonizadores das três raças usam `idle`/`walk`.
## Clipe ausente = "" (a técnica cai no Attack comum e a Muralha não troca de postura, ver Unit.gd).
## test_unit_art_catalog.gd carrega cada GLB e confere cada clipe declarado.
##
## Ao exportar uma tropa nova de raça: adicionar a entrada em _entries() e rodar
## `godot --headless --path . --import`.

const RACE_FOLDERS := BuildingArtCatalog.RACE_FOLDERS

## O Guarda V1 ("warrior") só existe em saves antigos: usa a mesma arte do Guerreiro V2 da raça.
const KIND_ALIASES := {"warrior": "v2_unit_warrior"}

static var _cache: Dictionary = {}

static func _entries() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	# As seis linhas de Doutrina nas três raças (2026-10-09: elfos e orcs ganharam Patrulheiro, Cavalaria, Ladino e
	# Cerco; antes só Guardião e Guerreiro). Anões usam clipes minúsculos e técnicas próprias (_lowercase); elfos e orcs
	# repetem os prefixos e as técnicas da arte humana (UnitDatabase.*_CLIPS) com a mesma regra: a forma básica tem só a
	# 1ª técnica com clipe, as evoluções ganham a 2ª.
	_cache = {}
	_register_line(["v2_unit_shieldbearer", "v2_unit_guardian", "v2_unit_sentinel", "v2_legendary_guardian_champion"],
		{"dwarf": ["dwarf_shieldbearer_v1", "dwarf_guardian_v1", "dwarf_sentinel_v1", "dwarf_guardian_champion_v1"],
		"elf": ["elf_squire_v1", "elf_guardian_v1", "elf_sentinel_v1", "elf_guardian_champion_v1"],
		"orc": ["orc_squire_v1", "orc_guardian_v1", "orc_sentinel_v1", "orc_guardian_champion_v1"]},
		["Squire", "Guardian", "Sentinel", "Champion"], true,
		[{}, {}, {}, {}])
	_register_line(["v2_unit_warrior", "v2_unit_swordsman", "v2_unit_weapon_master", "v2_legendary_blade_hero"],
		{"dwarf": ["dwarf_warrior_v1", "dwarf_swordsman_v1", "dwarf_weapon_master_v1", "dwarf_blade_hero_v1"],
		"elf": ["elf_warrior_v1", "elf_swordsman_v1", "elf_weapon_master_v1", "elf_blade_hero_v1"],
		"orc": ["orc_warrior_v1", "orc_swordsman_v1", "orc_weapon_master_v1", "orc_blade_hero_v1"]},
		["Warrior", "Swordsman", "WeaponMaster", "BladeHero"], false,
		_line_techniques(UnitDatabase.WARRIOR_FIRST_CLIPS, UnitDatabase.WARRIOR_LINE_CLIPS))
	_register_line(["v2_unit_archer", "v2_unit_hunter", "v2_unit_elite_marksman", "v2_legendary_legend_hunter"],
		{"dwarf": ["dwarf_archer_v1", "dwarf_hunter_v1", "dwarf_elite_marksman_v1", "dwarf_legend_hunter_v1"],
		"elf": ["elf_archer_v1", "elf_hunter_v1", "elf_elite_marksman_v1", "elf_legend_hunter_v1"],
		"orc": ["orc_archer_v1", "orc_hunter_v1", "orc_elite_marksman_v1", "orc_legend_hunter_v1"]},
		["Archer", "Hunter", "EliteMarksman", "LegendHunter"], false,
		_line_techniques(UnitDatabase.RANGER_FIRST_CLIPS, UnitDatabase.RANGER_LINE_CLIPS))
	# Lendária da Cavalaria: anão monta o Senhor dos Carneiros; elfo e orc, o Cavaleiro de Grifo da raça.
	_register_line(["v2_unit_cavalier", "v2_unit_shock_cavalier", "v2_unit_armored_cavalier", "v2_legendary_griffon_rider"],
		{"dwarf": ["dwarf_cavalier_v1", "dwarf_shock_cavalier_v1", "dwarf_armored_cavalier_v1", "dwarf_ram_lord_v1"],
		"elf": ["elf_cavalier_v1", "elf_shock_cavalier_v1", "elf_armored_cavalier_v1", "elf_griffon_rider_v1"],
		"orc": ["orc_cavalier_v1", "orc_shock_cavalier_v1", "orc_armored_cavalier_v1", "orc_griffon_rider_v1"]},
		["Cavalier", "ShockCavalier", "ArmoredCavalier", "GriffonRider"], false,
		_line_techniques(UnitDatabase.CAVALRY_LINE_CLIPS, UnitDatabase.CAVALRY_LINE_CLIPS))
	_register_line(["v2_unit_rogue", "v2_unit_saboteur", "v2_unit_assassin", "v2_legendary_shadow_master"],
		{"dwarf": ["dwarf_rogue_v1", "dwarf_saboteur_v1", "dwarf_assassin_v1", "dwarf_shadow_master_v1"],
		"elf": ["elf_rogue_v1", "elf_saboteur_v1", "elf_assassin_v1", "elf_shadow_master_v1"],
		"orc": ["orc_rogue_v1", "orc_saboteur_v1", "orc_assassin_v1", "orc_shadow_master_v1"]},
		["Rogue", "Saboteur", "Assassin", "ShadowMaster"], false,
		_line_techniques(UnitDatabase.ROGUE_FIRST_CLIPS, UnitDatabase.ROGUE_LINE_CLIPS))
	_register_line(["v2_unit_catapult", "v2_unit_trebuchet", "v2_unit_bombard", "v2_legendary_siege_colossus"],
		{"dwarf": ["dwarf_catapult_v1", "dwarf_trebuchet_v1", "dwarf_bombard_v1", "dwarf_siege_colossus_v1"],
		"elf": ["elf_catapult_v1", "elf_trebuchet_v1", "elf_bombard_v1", "elf_siege_colossus_v1"],
		"orc": ["orc_catapult_v1", "orc_trebuchet_v1", "orc_bombard_v1", "orc_siege_colossus_v1"]},
		["Catapult", "Trebuchet", "Bombard", "SiegeColossus"], false,
		_line_techniques(UnitDatabase.SIEGE_FIRST_CLIPS, UnitDatabase.SIEGE_LINE_CLIPS))
	# Colonizador (Infraestrutura): modelo próprio por raça, só `idle`/`walk` (nunca ataca). O humano está em UnitDatabase.
	var settler := {}
	for race in ["dwarf", "elf", "orc"]:
		settler[race] = {"stem": "%s_settler_v1" % race, "idle": "idle", "walk": "walk", "attack": "",
			"shield_wall": "", "shield_wall_hold": "", "techniques": {}}
	_cache["settler"] = settler
	# Construtores civis derivados dos colonos de cada raça.
	# Um modelo próprio para cada uma das quatro raças jogáveis.
	_cache["v2_unit_builder"] = {
		"human": {"stem": "human_builder_v1", "idle": "idle", "walk": "walk", "work": "work", "attack": "",
			"shield_wall": "", "shield_wall_hold": "", "techniques": {}},
		"elf": {"stem": "elf_builder_v1", "idle": "idle", "walk": "walk", "work": "work", "attack": "",
			"shield_wall": "", "shield_wall_hold": "", "techniques": {}},
		"orc": {"stem": "orc_builder_v1", "idle": "idle", "walk": "walk", "work": "work", "attack": "",
			"shield_wall": "", "shield_wall_hold": "", "techniques": {}},
		"dwarf": {"stem": "dwarf_builder_v1", "idle": "idle", "walk": "walk", "work": "work", "attack": "",
			"shield_wall": "", "shield_wall_hold": "", "techniques": {}}
	}
	# Magos (2026-10-10): um por Escola e por raça, `<raça>_<escola>_v1`, com os mesmos três clipes dos humanos
	# (idle/walk e `spell`, a conjuração de TODOS os feitiços — UnitDatabase.MAGE_*_CLIP). Sem ataque básico.
	for kind in MAGE_SCHOOLS:
		var by_race := {}
		for race in ["dwarf", "elf", "orc"]:
			by_race[race] = {"stem": "%s_%s_v1" % [race, MAGE_SCHOOLS[kind]], "idle": UnitDatabase.MAGE_IDLE_CLIP,
				"walk": UnitDatabase.MAGE_WALK_CLIP, "attack": "", "cast": UnitDatabase.MAGE_CAST_CLIP,
				"shield_wall": "", "shield_wall_hold": "", "techniques": {}}
		_cache[kind] = by_race
	return _cache

## Escola de cada mago (kind -> sufixo da pasta do modelo).
const MAGE_SCHOOLS := {
	"v2_unit_sacred_cleric": "sacred_cleric",
	"v2_unit_infernal_warlock": "infernal_warlock",
	"v2_unit_necromancer": "necromancer",
	"v2_unit_druid": "druid",
	"v2_unit_arcanist": "arcanist",
	"v2_unit_elementalist": "elementalist",
}

## Técnicas com clipe por forma da linha: [básica, 1ª evolução, elite, lendária].
static func _line_techniques(first: Dictionary, line: Dictionary) -> Array:
	return [first, line, line, line]

## Uma linha de Doutrina: kinds[i] usa stems[raça][i]. Anões exportam clipes minúsculos próprios;
## elfos e orcs repetem os prefixos/clipes humanos da mesma forma.
static func _register_line(kinds: Array, stems: Dictionary, prefixes: Array, shield_wall: bool, techniques: Array) -> void:
	for i in kinds.size():
		var by_race := {}
		for race in stems:
			var stem: String = stems[race][i]
			by_race[race] = _lowercase(stem) if race == "dwarf" else _prefixed(stem, prefixes[i], shield_wall, techniques[i])
		_cache[kinds[i]] = by_race

## Clipes no padrão humano (`<prefixo>_Idle/_Walk/_Attack`, Muralha e técnicas opcionais).
static func _prefixed(stem: String, prefix: String, shield_wall: bool, techniques: Dictionary = {}) -> Dictionary:
	var technique_clips := {}
	for technique_id in techniques:
		technique_clips[technique_id] = prefix + String(techniques[technique_id])
	return {
		"stem": stem,
		"idle": prefix + "_Idle",
		"walk": prefix + "_Walk",
		"attack": prefix + "_Attack",
		"shield_wall": prefix + "_ShieldWall" if shield_wall else "",
		"shield_wall_hold": prefix + "_ShieldWallHold" if shield_wall else "",
		"techniques": technique_clips,
	}

## A forma básica tem a primeira técnica; as evoluções mantêm a primeira e ganham a segunda.
static func _lowercase(stem: String) -> Dictionary:
	var guardian := stem in ["dwarf_shieldbearer_v1", "dwarf_guardian_v1", "dwarf_sentinel_v1", "dwarf_guardian_champion_v1"]
	var techniques := {}
	if stem in ["dwarf_warrior_v1", "dwarf_swordsman_v1", "dwarf_weapon_master_v1", "dwarf_blade_hero_v1"]:
		techniques = {V2DoctrineTechniqueDatabase.POWER_STRIKE: "power_strike", V2DoctrineTechniqueDatabase.CLEAVE: "arc_attack"}
	elif stem in ["dwarf_archer_v1", "dwarf_hunter_v1", "dwarf_elite_marksman_v1", "dwarf_legend_hunter_v1"]:
		techniques = {V2DoctrineTechniqueDatabase.PRECISE_SHOT: "precise_shot", V2DoctrineTechniqueDatabase.VOLLEY: "volley"}
	elif stem in ["dwarf_cavalier_v1", "dwarf_shock_cavalier_v1", "dwarf_armored_cavalier_v1", "dwarf_ram_lord_v1"]:
		techniques = {V2DoctrineTechniqueDatabase.CHARGE: "charge", V2DoctrineTechniqueDatabase.TACTICAL_RETREAT: "tactical_retreat"}
	elif stem in ["dwarf_rogue_v1", "dwarf_saboteur_v1", "dwarf_assassin_v1", "dwarf_shadow_master_v1"]:
		techniques = {V2DoctrineTechniqueDatabase.SNEAK_ATTACK: "sneak_attack", V2DoctrineTechniqueDatabase.DISMANTLE: "dismantle"}
	elif stem in ["dwarf_catapult_v1", "dwarf_trebuchet_v1", "dwarf_bombard_v1", "dwarf_siege_colossus_v1"]:
		techniques = {V2DoctrineTechniqueDatabase.DEMOLITION_AMMO: "demolition_ammo", V2DoctrineTechniqueDatabase.PREPARED_BOMBARDMENT: "prepared_bombardment"}
	for pair: Array in [["dwarf_warrior_v1", V2DoctrineTechniqueDatabase.CLEAVE],
		["dwarf_archer_v1", V2DoctrineTechniqueDatabase.VOLLEY], ["dwarf_cavalier_v1", V2DoctrineTechniqueDatabase.TACTICAL_RETREAT],
		["dwarf_rogue_v1", V2DoctrineTechniqueDatabase.DISMANTLE], ["dwarf_catapult_v1", V2DoctrineTechniqueDatabase.PREPARED_BOMBARDMENT]]:
		if stem == pair[0]: techniques.erase(pair[1])
	return {"stem": stem, "idle": "idle", "walk": "walk", "attack": "attack",
		"shield_wall": "shield_wall" if guardian else "", "shield_wall_hold": "shield_wall_hold" if guardian else "", "techniques": techniques}

static func _art_kind(kind: String) -> String:
	return KIND_ALIASES.get(kind, kind)

## Entrada de arte da raça para o kind, ou {} (fica a arte padrão de UnitDatabase).
static func entry(kind: String, race: String) -> Dictionary:
	return _entries().get(_art_kind(kind), {}).get(BuildingArtCatalog.normalize_race(race), {})

static func model_path(kind: String, race: String) -> String:
	var art := entry(kind, race)
	if art.is_empty():
		return ""
	var normalized := BuildingArtCatalog.normalize_race(race)
	return "res://assets/generated/%s/%s/%s.glb" % [RACE_FOLDERS[normalized], art.stem, art.stem]

## EMBARQUE AUTOMÁTICO (2026-10-10): o barquinho da raça que substitui QUALQUER tropa dela na água (um barco = uma
## unidade; manifesto em assets/generated/embark_boats_manifest.json). A cena `.tscn` do pacote já aplica a escala de
## mapa (0,52, BOAT_SCALE) no filho `Visual`; a origem é a linha d'água. Frente do modelo em −Z: gira 180° para a frente
## +Z das unidades (Unit.walk_path vira para atan2(dx, dz)). Clipes `idle`/`walk`, em loop, com crossfade em Unit.
const BOAT_STEM := "%s_embark_boat_v1"
const BOAT_SCALE := 0.52
const BOAT_YAW_DEGREES := 180.0
const BOAT_IDLE_CLIP := "idle"
const BOAT_WALK_CLIP := "walk"
const BOAT_BLEND_TIME := 0.2

static func boat_scene_path(race: String) -> String:
	var normalized := BuildingArtCatalog.normalize_race(race)
	var stem := BOAT_STEM % normalized
	return "res://assets/generated/%s/%s/%s.tscn" % [RACE_FOLDERS[normalized], stem, stem]

static func boat_scene_path_for(owner: PlayerData) -> String:
	return boat_scene_path(BuildingArtCatalog.race_of(owner))

## Kinds com arte própria em alguma raça (para testes/validação).
static func registered_kinds() -> Array:
	return _entries().keys()

## UnitData com a arte da raça do dono. Sem entrada para a raça: devolve `data` intacto (mesma
## instância). Com entrada: devolve uma CÓPIA (duplicate profundo — todo campo de UnitData é @export),
## para nunca contaminar um UnitData compartilhado com outra unidade. Idempotente.
static func for_owner(data: UnitData, owner: PlayerData) -> UnitData:
	if data == null:
		return data
	var race := BuildingArtCatalog.race_of(owner)
	var art := entry(data.visual_kind, race)
	if art.is_empty():
		return data
	var path := model_path(data.visual_kind, race)
	if data.model_scene_path == path:
		return data
	var themed := data.duplicate(true) as UnitData
	themed.model_scene_path = path
	themed.animation_scene_path = path
	themed.merge_shared_walk_animation = false
	themed.idle_animation_override = art.idle
	themed.walk_animation_override = art.walk
	themed.work_animation_override = String(art.get("work", ""))
	themed.attack_animation_override = art.attack
	themed.cast_animation_override = String(art.get("cast", ""))
	themed.shield_wall_animation_override = art.shield_wall
	themed.shield_wall_hold_animation_override = art.shield_wall_hold
	themed.technique_animation_overrides = (art.techniques as Dictionary).duplicate()
	themed.animation_blend_time = UnitDatabase.GUARDIAN_LINE_BLEND_TIME
	# Altura própria de cada raça já está no modelo (anão 1,35 m, elfo 1,80 m, orc 2,00 m): 1:1, frente +Z.
	themed.model_scale_multiplier = 1.0
	themed.model_yaw_offset_degrees = 0.0
	return themed
