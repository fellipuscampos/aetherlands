class_name MagicContent
extends RefCounted

## Catálogo V1: seis linhas independentes; ciência compartilhada com tecnologia.
const SCHOOLS := {
	"sagrada": {"name": "Sagrada", "caster": "cleric", "building": "light_church", "ritual_building": "grand_cathedral", "advanced": "hierophant", "names": ["Doutrina Sagrada", "Igreja da Luz", "Clérigo", "Cura Sagrada", "Purificação", "Hierofante", "Domínio Consagrado", "Grande Catedral", "Aurora Divina"]},
	"infernal": {"name": "Artes Infernais", "caster": "cultist", "building": "abyssal_altar", "ritual_building": "abyssal_portal", "advanced": "infernal_warlock", "names": ["Artes Infernais", "Altar Abissal", "Cultista", "Fogo Infernal", "Pacto de Sangue", "Bruxo Infernal", "Chuva de Enxofre", "Portal Abissal", "Manifestação do Arquidemônio"]},
	"necromancia": {"name": "Necromancia", "caster": "necromancer", "building": "whisper_crypt", "ritual_building": "black_mausoleum", "advanced": "grave_guardian", "names": ["Necromancia", "Cripta dos Sussurros", "Necromante", "Solo Amaldiçoado", "Erguer os Mortos", "Guardião Sepulcral", "Legião dos Mortos", "Mausoléu Negro", "Ascensão do Lich Ancião"]},
	"druidismo": {"name": "Druidismo", "caster": "druid", "building": "druid_circle", "ritual_building": "living_heart", "advanced": "woodland_beast", "names": ["Druidismo", "Círculo Druídico", "Druida", "Floresta Súbita", "Flores do Véu", "Fera do Bosque", "Erguer Cordilheira", "Coração da Terra Viva", "Domínio da Terra Viva"]},
	"arcanismo": {"name": "Arcanismo", "caster": "arcanist", "building": "arcane_tower", "ritual_building": "convergence_obelisk", "advanced": "arcane_golem", "names": ["Arcanismo", "Torre Arcana", "Arcanista", "Salto Arcano", "Selo de Mana", "Golem Arcano", "Portal de Campanha", "Obelisco de Convergência", "Grande Convergência"]},
	"elementalismo": {"name": "Elementalismo", "caster": "elementalist", "building": "elemental_conclave", "ritual_building": "four_winds_eye", "advanced": "storm_elemental", "names": ["Elementalismo", "Conclave Elemental", "Elementalista", "Relâmpago Encadeado", "Onda Glacial", "Elemental da Tempestade", "Frente de Tempestade", "Olho dos Quatro Ventos", "Cataclismo Elemental"]},
}
const COSTS := [16.0, 24.0, 36.0, 55.0, 85.0, 130.0, 195.0, 295.0, 445.0]
const TRAINABLE := ["cleric", "cultist", "necromancer", "druid", "arcanist", "elementalist", "hierophant", "infernal_warlock", "arcane_golem", "storm_elemental"]
const SUMMONED := ["bound_skeleton", "grave_guardian", "woodland_beast", "elder_lich", "archdemon", "lesser_demon"]
const EFFECTS := {
	"sagrada": ["heal", "purify", "", "consecrate", "aurora"],
	"infernal": ["hellfire", "blood_pact", "", "brimstone", "archdemon"],
	"necromancia": ["curse", "skeleton", "guardian", "legion", "lich"],
	"druidismo": ["forest", "veil", "beast", "mountains", "living_land"],
	"arcanismo": ["blink", "silence", "", "portal", "convergence"],
	"elementalismo": ["chain_lightning", "ice_wave", "", "storm", "cataclysm"],
}
const DESCRIPTIONS := {
	"heal": "Cura 30% da vida máxima de um aliado a até 3 hexágonos. Requer conjurador Sagrado.",
	"purify": "Remove maldições, lentidão e silêncio de um aliado e dissipa efeitos hostis no terreno.",
	"consecrate": "Consagra raio 2 por 5 turnos: purifica e regenera aliados; enfraquece mortos-vivos e demônios hostis.",
	"aurora": "Após 7 turnos, consagra raio 4 por 9 turnos, curando aliados e dissipando efeitos hostis.",
	"hellfire": "Causa 12 de dano ao alvo e 4 aos inimigos adjacentes. Pacto de Sangue aumenta o dano em 60%.",
	"blood_pact": "Sacrifica 30% da vida atual do conjurador para amplificar o próximo Fogo Infernal em até 3 turnos.",
	"brimstone": "Fogo abissal em raio 1 durante 4 turnos. Causa 5 de dano por turno, inclusive aos aliados.",
	"archdemon": "Após 7 turnos, manifesta um Arquidemônio autônomo que avança ao objetivo e invoca demônios menores.",
	"curse": "Amaldiçoa raio 1 por 4 turnos: inimigos vivos recebem 3 de dano por turno e perdem 20% de ataque.",
	"skeleton": "Invoca um Esqueleto adjacente. Máximo de 3 por Necromante; desaparece se perder seu invocador.",
	"guardian": "Invoca um Guardião resistente. Máximo de 1 por Necromante; manutenção de 2 mana por turno.",
	"legion": "Invoca até 4 mortos-vivos por 8 turnos. Mana e recarga limitam a reposição.",
	"lich": "Após 9 turnos, invoca um Lich autônomo. Avança com uma horda de até 10 mortos-vivos e evita combate corpo a corpo.",
	"forest": "Cria floresta por 5 turnos em um terreno livre e elegível. Preserva os recursos originais.",
	"veil": "Oculta aliados em raio 1 por 5 turnos. Inimigos adjacentes revelam; atacar revela por um turno.",
	"beast": "Invoca uma Fera do Bosque. Máximo de 1 por Druida; manutenção de 2 mana por turno.",
	"mountains": "Ergue até 3 montanhas adjacentes por 4 turnos. Nunca sobre cidades, edifícios ou unidades.",
	"living_land": "Após 7 turnos, transforma raio 4 por 9 turnos: florestas, ocultação e montanhas nas bordas livres.",
	"blink": "Teleporta o Arcanista até 3 hexágonos para um terreno visível, livre e transitável.",
	"silence": "Impede um conjurador inimigo de usar feitiços durante 2 turnos; ataques básicos continuam possíveis.",
	"portal": "Liga a posição do Arcanista a uma âncora própria visível por 5 turnos. Até 2 aliados adjacentes atravessam por turno; perder a âncora fecha o portal.",
	"convergence": "Após 7 turnos, transporta até 8 tropas da sede para um Nódulo controlado ou Obelisco próprio. Perder a âncora interrompe o ritual.",
	"chain_lightning": "Relâmpago salta entre até 3 inimigos próximos: 9, 6 e 4 de dano.",
	"ice_wave": "Causa 5 de dano em inimigos no raio 1 e reduz seu movimento pela metade durante 2 turnos.",
	"storm": "Tempestade em raio 2 por 5 turnos: 3 de dano por turno, lentidão e -25% de ataque à distância, inclusive para aliados.",
	"cataclysm": "Após 8 turnos, devasta raio 3 durante 7 turnos: 6 de dano por turno, lentidão e pilhagem. Cidades sofrem dano gradual, sem destruição instantânea.",
}

static func build_techs() -> Dictionary:
	var result := {}
	for school in SCHOOLS:
		var info: Dictionary = SCHOOLS[school]
		for tier in range(1, 10):
			var tech := TechData.new()
			tech.id = "%s_%d" % [school, tier]
			tech.tier = tier
			tech.school = info.name
			tech.display_name = info.names[tier - 1]
			tech.cost = COSTS[tier - 1]
			if tier > 1:
				tech.prerequisites = ["%s_%d" % [school, tier - 1]]
			match tier:
				1: tech.effect_text = "Abre %s. Cada cidade passa a produzir +1 mana por turno." % info.name
				2:
					tech.unlocks_building = info.building
					tech.effect_text = "Infraestrutura da escola: +4 mana por turno e treinamento de conjuradores."
				3:
					tech.unlocks_unit = info.caster
					tech.effect_text = "Conjurador frágil; habilita feitiços desta escola no campo de batalha."
				6:
					if school in ["necromancia", "druidismo"]:
						tech.unlocks_spell = tech.display_name
					else:
						tech.unlocks_unit = info.advanced
						tech.effect_text = "Desbloqueia %s; requer a infraestrutura da escola e manutenção em mana." % tech.display_name
				8:
					tech.unlocks_building = info.ritual_building
					tech.effect_text = "Estrutura de canalização: +8 mana por turno; necessária ao Grande Ritual."
				_: tech.unlocks_spell = tech.display_name
			if tech.unlocks_spell != "":
				var effect: String = EFFECTS[school][[4, 5, 6, 7, 9].find(tier)]
				tech.effect_text = DESCRIPTIONS[effect]
			tech.description = tech.effect_text
			result[tech.id] = tech
	var final := TechData.new()
	final.id = "transcendencia_arcana"
	final.display_name = "Transcendência Arcana"
	final.school = "Transcendência"
	final.tier = 10
	final.cost = 740
	final.unlocks_building = "arcane_sanctuary"
	final.effect_text = "Exige nível 9 em duas escolas. Libera o Santuário e a preparação da vitória por Transcendência."
	final.description = final.effect_text
	result[final.id] = final
	return result

static func add_buildings(result: Dictionary) -> void:
	for school in SCHOOLS:
		var info: Dictionary = SCHOOLS[school]
		for ritual in [false, true]:
			var data := BuildingData.new()
			data.id = info.ritual_building if ritual else info.building
			data.display_name = info.names[7 if ritual else 1]
			data.production_cost = 160.0 if ritual else 50.0
			data.bonus_mana = 8 if ritual else 4
			if ritual:
				data.requires_building = info.building
			else:
				data.trains_unit = info.caster
			result[data.id] = data

static func trainer_for(kind: String) -> String:
	for info in SCHOOLS.values():
		if kind in [info.caster, info.advanced]:
			return info.building
	return ""

static func school_for_building(id: String) -> String:
	for school in SCHOOLS:
		if id in [SCHOOLS[school].building, SCHOOLS[school].ritual_building]:
			return school
	return ""

static func create_unit(kind: String) -> UnitData:
	if not kind in TRAINABLE and not kind in SUMMONED:
		return null
	var data := UnitDatabase.create_unit("mage")
	data.visual_kind = kind
	data.magic_school = ""
	data.max_hp = 11.0
	data.defense = 2.0
	data.attack = 4.0
	data.attack_range = 2
	data.production_cost = 65.0
	data.mana_upkeep = 1.0
	var model_name := "arcane_caster"
	if kind in ["elder_lich", "archdemon", "lesser_demon"]:
		model_name = kind
	data.model_scene_path = "res://assets/generated/magic/%s/%s.glb" % [model_name, model_name]
	if kind == "bound_skeleton":
		data.model_scene_path = "res://assets/generated/skeletons/skeleton_blocky/skeleton_blocky.glb"
	data.animation_scene_path = data.model_scene_path
	data.model_scale_multiplier = 1.0
	data.model_yaw_offset_degrees = 0.0
	data.merge_shared_walk_animation = false
	data.idle_animation_override = "Idle"
	data.walk_animation_override = "Walk"
	data.attack_animation_override = "Attack"
	for school in SCHOOLS:
		var info: Dictionary = SCHOOLS[school]
		if kind == info.caster:
			data.magic_school = school
			data.unit_name = info.names[2]
		if kind == info.advanced:
			data.unit_name = info.names[5]
			data.production_cost = 110.0
			data.mana_upkeep = 2.0
			if school in ["sagrada", "infernal"]:
				data.magic_school = school
				data.max_hp = 15.0
				data.defense = 3.0
				data.attack = 5.0
				data.vision_range = 5
	if kind in ["arcane_golem", "grave_guardian", "woodland_beast"]:
		data.model_scene_path = UnitDatabase.create_unit("stone_golem" if kind != "woodland_beast" else "treant").model_scene_path
		data.animation_scene_path = ""
		data.ignores_terrain_defense = kind == "arcane_golem"
		data.max_hp = 30.0
		data.defense = 7.0
		data.attack = 8.0
		data.attack_range = 1
		data.movement_points = 1.0 if kind != "woodland_beast" else 3.0
		data.mana_upkeep = 3.0 if kind == "arcane_golem" else 2.0
	if kind == "storm_elemental":
		data.model_scene_path = ""
		data.animation_scene_path = ""
		data.max_hp = 22.0
		data.defense = 4.0
		data.attack = 7.0
		data.flies = true
		data.movement_points = 3.0
	if kind in ["bound_skeleton", "lesser_demon"]:
		data.ignores_terrain_defense = false
		data.unit_name = "Esqueleto Vinculado" if kind == "bound_skeleton" else "Demônio Menor"
		data.max_hp = 9.0 if kind == "bound_skeleton" else 14.0
		data.attack = 4.0 if kind == "bound_skeleton" else 6.0
		data.attack_range = 1
		data.mana_upkeep = 0.0
	if kind in ["elder_lich", "archdemon"]:
		data.unit_name = "Lich Ancião" if kind == "elder_lich" else "Arquidemônio"
		data.max_hp = 48.0 if kind == "elder_lich" else 100.0
		data.defense = 5.0 if kind == "elder_lich" else 9.0
		data.attack = 12.0 if kind == "elder_lich" else 15.0
		data.attack_range = 3 if kind == "elder_lich" else 1
		data.mana_upkeep = 5.0
		data.vision_range = 5
	return data

static func add_spells(result: Dictionary) -> void:
	for school in SCHOOLS:
		for index in range(5):
			var effect: String = EFFECTS[school][index]
			if effect == "":
				continue
			var tier: int = [4, 5, 6, 7, 9][index]
			var spell := SpellData.new()
			spell.name = SCHOOLS[school].names[tier - 1]
			spell.school = school
			spell.effect = effect
			spell.description = DESCRIPTIONS[effect]
			spell.category = "ritual" if tier == 9 else ("great_spell" if tier == 7 else "spell")
			spell.mana_cost = [18, 24, 45, 65, 300][index]
			spell.cooldown_turns = [3, 4, 6, 8, 25][index]
			spell.cast_range = 4 if tier >= 7 else 3
			spell.target_kind = "tile"
			result[spell.name] = spell
