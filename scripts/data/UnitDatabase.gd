class_name UnitDatabase
extends RefCounted

## Roster de kinds que a cidade do JOGADOR pode produzir via producao normal
## (ver City.can_train, HUD._build_production_buttons) — fonte UNICA usada
## pra montar os botoes de producao dinamicamente, pedido do usuario: "ler
## dinamicamente todas as unidades cadastradas em UnitDatabase.gd", em vez
## de um botao fixo cadastrado a mao na cena toda vez que uma unidade nova
## nasce (foi exatamente isso que deixou stone_golem/shadow_summoner sem
## nenhum jeito de treinar de verdade quando entraram no jogo). Inclui as 4
## tropas raciais exclusivas (human_knight/dwarf_axeguard/orc_berserker/
## elf_ranger, ver RACE_UNIQUE_KIND abaixo) desde que o jogador ganhou a
## propria raca escolhivel na tela de titulo (CivilizationData.race,
## TitleScreen) — cada uma so fica DISPONIVEL de verdade (visivel na HUD e
## treinavel) se a raca do jogador bater, ver City.can_train() e
## HUD._on_tile_selected.
const PLAYER_TRAINABLE_KINDS: Array[String] = [
	"settler", "warrior", "archer", "cavalry", "catapult",
	"mage", "griffin", "treant", "stone_golem", "shadow_summoner",
	"human_knight", "dwarf_axeguard", "orc_berserker", "elf_ranger",
]

## Raca de fantasia (CivilizationData.race) -> kind da tropa exclusiva dela
## (ver UnitDatabase.create_unit abaixo) — pedido original do usuario:
## "insira outras civilizacoes de fantasia... voce cria tropas especificas
## pra essas civilizacoes", estendido depois pro JOGADOR tambem poder
## escolher a propria raca (TitleScreen) e ganhar a mesma exclusividade.
## "human" incluido de proposito (pedido do usuario: "elfo, anao, orc e
## humanos") — sem isso, escolher Humano na tela de titulo seria estranho
## na pratica, a UNICA das 4 opcoes sem nenhuma tropa propria.
const RACE_UNIQUE_KIND := {
	"human": "human_knight",
	"dwarf": "dwarf_axeguard",
	"orc": "orc_berserker",
	"elf": "elf_ranger",
}

## Inverso de RACE_UNIQUE_KIND (kind -> raca dona), ou "" se `kind` nao e
## nenhuma tropa racial — usado por City.can_train() (so a raca dona pode
## treinar) e BuildingDatabase.building_that_trains() (todas as 4 treinam
## no Quartel, mesmo predio do Guerreiro comum, ver comentario la).
static func race_for_unique_kind(kind: String) -> String:
	for race in RACE_UNIQUE_KIND.keys():
		if RACE_UNIQUE_KIND[race] == kind:
			return race
	return ""

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
		# Tropas magicas desbloqueadas pela nova arvore de tecnologia (ver
		# TechDatabase: forja_runica -> stone_golem, necromancia_pratica ->
		# shadow_summoner). Treinaveis de verdade via PLAYER_TRAINABLE_KINDS
		# acima, cada uma com seu proprio predio de treino em
		# BuildingDatabase (Bigorna Runica / Cripta Sombria).
		"stone_golem":
			data.unit_name = "Golem de Pedra"
			data.movement_points = 1.0 # pesado, nao sai correndo
			data.attack = 5.0
			data.defense = 6.0 # a maior defesa do elenco, guardiao de pedra viva
			data.max_hp = 20.0
			data.vision_range = 2
			data.can_found_city = false
			data.visual_kind = "stone_golem"
			data.production_cost = 32.0
		"shadow_summoner":
			data.unit_name = "Convocador de Sombras"
			data.movement_points = 2.0
			data.attack = 5.0
			data.defense = 1.0
			data.attack_range = 2
			data.max_hp = 9.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "shadow_summoner"
			data.ignores_terrain_defense = true
			data.regen_fraction = 0.1 # drena ecos da sombra pra se sustentar, mesmo padrao do Ent
			data.production_cost = 33.0
		# Tropas raciais exclusivas (ver RACE_UNIQUE_KIND acima) — cada
		# civilizacao de fantasia (CivilizationData.race, escolhida pelo
		# jogador na tela de titulo ou sorteada pra rival em
		# GameManager.RIVAL_CIVS) tem uma, alem do elenco comum acima.
		"human_knight":
			data.unit_name = "Cavaleiro Real"
			data.movement_points = 3.0 # mais agil que Cavalaria comum, mas nao tao rapido quanto o Patrulheiro Elfico
			data.attack = 5.0
			data.defense = 4.0 # maior defesa entre as 4 tropas raciais moveis (perde so pro Guarda-Machado Anao, que fica parado)
			data.max_hp = 15.0
			data.vision_range = 3
			data.can_found_city = false
			data.visual_kind = "human_knight"
			data.production_cost = 26.0
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
