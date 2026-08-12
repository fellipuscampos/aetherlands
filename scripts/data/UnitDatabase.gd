class_name UnitDatabase
extends RefCounted

static func create_unit(kind: String) -> UnitData:
	var data := UnitData.new()
	match kind:
		"settler":
			data.unit_name = "Colonizador"
			data.movement_points = 2.0
			data.attack = 0.0
			data.defense = 1.0
			data.max_hp = 8.0
			data.vision_range = 2
			data.can_found_city = true
			data.visual_kind = "settler"
			data.production_cost = 25.0
		"warrior":
			data.unit_name = "Guerreiro"
			data.movement_points = 2.0
			data.attack = 4.0
			data.defense = 3.0
			data.max_hp = 12.0
			data.vision_range = 2
			data.can_found_city = false
			data.visual_kind = "warrior"
			data.production_cost = 15.0
		"archer":
			data.unit_name = "Arqueiro"
			data.movement_points = 2.0
			data.attack = 3.0
			data.defense = 1.5
			data.attack_range = 2
			data.max_hp = 9.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "archer"
			data.production_cost = 18.0
		"cavalry":
			data.unit_name = "Cavaleiro"
			data.movement_points = 4.0
			data.attack = 5.0
			data.defense = 2.0
			data.max_hp = 14.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "cavalry"
			data.production_cost = 22.0
		"catapult":
			data.unit_name = "Catapulta"
			data.movement_points = 1.0
			data.attack = 6.0
			data.defense = 1.0
			data.attack_range = 2
			data.max_hp = 8.0
			data.vision_range = 2
			data.can_found_city = false
			data.visual_kind = "catapult"
			data.production_cost = 30.0
		"mage":
			data.unit_name = "Mago"
			data.movement_points = 2.0
			data.attack = 4.0
			data.defense = 1.0
			data.attack_range = 2
			data.max_hp = 8.0
			data.vision_range = 2
			data.can_found_city = false
			data.visual_kind = "mage"
			data.ignores_terrain_defense = true
			data.production_cost = 28.0
		"griffin":
			data.unit_name = "Grifo"
			data.movement_points = 4.0
			data.attack = 6.0
			data.defense = 3.0
			data.max_hp = 15.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "griffin"
			data.flies = true
			data.production_cost = 35.0
		"treant":
			data.unit_name = "Ent"
			data.movement_points = 1.0
			data.attack = 5.0
			data.defense = 5.0
			data.max_hp = 18.0
			data.vision_range = 2
			data.can_found_city = false
			data.visual_kind = "treant"
			data.regen_fraction = 0.15
			data.production_cost = 30.0
		# Tropas raciais exclusivas (ver RivalAI.RACE_UNIQUE_KIND) — cada
		# civilizacao de fantasia (CivilizationData.race) tem uma, alem do
		# elenco comum acima. Escopo desta rodada: so a IA rival produz
		# essas (RivalAI.decide_production), o jogador nao tem raca pra
		# desbloquear nenhuma delas ainda.
		"dwarf_axeguard":
			data.unit_name = "Guarda-Machado Anao"
			data.movement_points = 1.0 # pernas curtas, mas nao sai do lugar
			data.attack = 5.0
			data.defense = 5.0
			data.max_hp = 16.0
			data.vision_range = 2
			data.can_found_city = false
			data.visual_kind = "dwarf_axeguard"
			data.production_cost = 24.0
		"orc_berserker":
			data.unit_name = "Berserker Orc"
			data.movement_points = 2.0
			data.attack = 6.0 # o maior ataque corpo-a-corpo do jogo, de proposito
			data.defense = 1.0 # sem armadura nenhuma, todo o investimento e ofensivo
			data.max_hp = 10.0
			data.vision_range = 2
			data.can_found_city = false
			data.visual_kind = "orc_berserker"
			data.production_cost = 18.0
		"elf_ranger":
			data.unit_name = "Patrulheiro Elfico"
			data.movement_points = 3.0 # o mais agil entre as unidades terrestres
			data.attack = 3.5
			data.defense = 1.0
			data.attack_range = 3 # alcance maior que o Arqueiro comum (2)
			data.max_hp = 8.0
			data.vision_range = 4
			data.can_found_city = false
			data.visual_kind = "elf_ranger"
			data.production_cost = 26.0
	return data
