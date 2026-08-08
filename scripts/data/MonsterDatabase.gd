class_name MonsterDatabase
extends RefCounted

## Monstros neutros que guardam os Covis de Monstro espalhados pelo mapa
## (ver HexGrid._spawn_monster_lairs). Sao Unit comuns com owner_player ==
## null: nunca entram em nenhuma PlayerData.units, entao GameManager/RivalAI
## nunca os processam num turno — so ficam parados guardando o proprio tile
## pra sempre, ate alguem (jogador ou rival) atacar e vencer. Quem vence
## recebe unit_data.gold_reward em ouro (CombatResolver.resolve()).

const KINDS := ["goblin", "troll", "wyvern"]

## Pesos de sorteio (nao uniforme, ver random_kind): goblin e comum e fraco,
## troll incomum e resistente, vivern raro mas paga o maior premio — risco
## crescente casado com recompensa crescente, como convem a um covil.
const WEIGHTS := {"goblin": 60, "troll": 30, "wyvern": 10}

static func create_monster(kind: String) -> UnitData:
	var data := UnitData.new()
	data.movement_points = 0.0 # guardiao nunca sai do proprio tile
	match kind:
		"goblin":
			data.unit_name = "Goblin"
			data.attack = 3.0
			data.defense = 2.0
			data.max_hp = 8.0
			data.vision_range = 1
			data.visual_kind = "goblin"
			data.gold_reward = 15.0
		"troll":
			data.unit_name = "Troll"
			data.attack = 6.0
			data.defense = 4.0
			data.max_hp = 20.0
			data.vision_range = 1
			data.visual_kind = "troll"
			data.gold_reward = 35.0
		"wyvern":
			data.unit_name = "Vivern"
			data.attack = 8.0
			data.defense = 3.0
			data.max_hp = 16.0
			data.vision_range = 1
			data.visual_kind = "wyvern"
			data.gold_reward = 70.0
	return data

## Sorteio ponderado deterministico — `rng` ja vem semeado pelo chamador
## (HexGrid._spawn_monster_lairs usa map_seed), entao o resultado e 100%
## reproduzivel pra mesma semente de mapa.
static func random_kind(rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in KINDS:
		total += WEIGHTS[k]
	var roll = rng.randi_range(0, total - 1)
	var acc := 0
	for k in KINDS:
		acc += WEIGHTS[k]
		if roll < acc:
			return k
	return KINDS[0]
