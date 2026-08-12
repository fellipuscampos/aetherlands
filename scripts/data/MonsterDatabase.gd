class_name MonsterDatabase
extends RefCounted

## Monstros neutros: guardam Covis de Monstro espalhados pelo mapa (ver
## HexGrid._spawn_monster_lairs) e, desde a introducao de MonsterAI, agem
## por conta propria a cada turno (guardar territorio, marchar sobre uma
## cidade, cacar presa isolada — ver MonsterAI.gd). Sao Unit comuns com
## owner_player == null: nunca entram em nenhuma PlayerData.units, entao
## GameManager processa o turno deles separado do loop de jogador/rival
## (ver GameManager._on_turn_changed: reset_movement + MonsterAI.take_turn).
## Quem vence um monstro em combate recebe unit_data.gold_reward em ouro
## (CombatResolver.resolve()).

const BEHAVIOR_GUARDIAN := "guardian" # fica no territorio do covil, so briga com quem invade (ver MonsterAI._take_guardian_turn)
const BEHAVIOR_INVADER := "invader" # marcha sobre a cidade inimiga mais proxima, brigando com quem encontrar no caminho (ver MonsterAI._take_invader_turn)
const BEHAVIOR_HUNTER := "hunter" # patrulha uma area larga cacando presa isolada/fraca (ver MonsterAI._take_hunter_turn)

## Tabela central de dados por tipo — mesmo espirito de HexGrid._BIOME_TABLE
## (geracao de terreno): tudo que diferencia um tipo de monstro do outro
## fica AQUI, num dicionario so, em vez de espalhado por match/if-elif. Pra
## ajustar bioma/raridade/tamanho de grupo/comportamento de um tipo, mexe
## so aqui.
##
## Campos:
## - biomes: Array[HexTileData.TerrainType] onde esse tipo pode ser
##   sorteado pro COVIL (ver HexGrid._spawn_monster_lairs/random_kind
##   abaixo). Reforco/patrulha nao re-checam bioma — o covil ja fixou o
##   tipo, so a colocacao INICIAL depende de bioma.
## - weight: peso de sorteio entre os tipos ELEGIVEIS (bioma + ameaca) num
##   dado tile — nao e uma probabilidade global fixa, ver random_kind.
## - min_threat (0..1, ver HexGrid._threat_level): abaixo disso o tipo fica
##   INDISPONIVEL pro covil, nao so com peso baixo.
## - lair_cap: populacao maxima viva (guardiao incluso) que ESSE tipo
##   mantem na area do proprio covil (ver HexGrid._count_live_monsters_
##   near_lair) — substitui o antigo LAIR_SPAWN_CAP fixo unico.
## - batch_spawn: quantos nascem de uma vez quando o covil acerta o roll de
##   reforco (ver HexGrid._reinforce_lair) — Esqueleto nasce em grupo (3),
##   o resto nasce um de cada vez (1).
## - behavior: BEHAVIOR_* default do tipo (MonsterAI pode substituir por
##   instancia via Unit.monster_behavior_state, ver invader_promotable).
## - invader_promotable: se true, um grupo de 2+ unidades OCIOSAS (ainda no
##   comportamento default) desse tipo na area do covil e promovido pra
##   Invasor pela MonsterAI (ver INVADER_GROUP_THRESHOLD) — so faz sentido
##   pra tipos BEHAVIOR_GUARDIAN que devem "virar" agressivos em grupo
##   (Goblin); Esqueleto ja nasce Invasor, nao precisa de promocao.
## - clear_reward: ouro concedido por DESTRUIR o covil abandonado (entrar
##   no tile sem defensor, ver HexGrid.destroy_lair/_grant_lair_clear_
##   reward) — recompensa maior e de uma vez so, diferente de gold_reward
##   (que paga por matar CADA monstro individual em combate).
const KIND_DATA := {
	"goblin": {
		"biomes": [HexTileData.TerrainType.FOREST, HexTileData.TerrainType.PLAINS, HexTileData.TerrainType.GRASSLAND],
		"weight": 60, "min_threat": 0.0, "lair_cap": 4, "batch_spawn": 1,
		"behavior": BEHAVIOR_GUARDIAN, "invader_promotable": true,
		"unit_name": "Goblin", "attack": 3.0, "defense": 2.0, "max_hp": 8.0,
		"movement_points": 1.0, "vision_range": 1, "gold_reward": 15.0, "clear_reward": 75.0,
		"flies": false, "visual_kind": "goblin",
	},
	"troll": {
		"biomes": [HexTileData.TerrainType.MOUNTAINS, HexTileData.TerrainType.TAIGA, HexTileData.TerrainType.TUNDRA],
		"weight": 30, "min_threat": 0.3, "lair_cap": 2, "batch_spawn": 1,
		"behavior": BEHAVIOR_GUARDIAN, "invader_promotable": false,
		"unit_name": "Troll", "attack": 6.0, "defense": 4.0, "max_hp": 20.0,
		"movement_points": 1.0, "vision_range": 1, "gold_reward": 35.0, "clear_reward": 100.0,
		"flies": false, "visual_kind": "troll",
	},
	"wyvern": {
		"biomes": [HexTileData.TerrainType.LAVA, HexTileData.TerrainType.LAVA_SEA, HexTileData.TerrainType.CRYSTAL],
		"weight": 10, "min_threat": 0.65, "lair_cap": 2, "batch_spawn": 1,
		"behavior": BEHAVIOR_HUNTER, "invader_promotable": false,
		"unit_name": "Vivern", "attack": 8.0, "defense": 3.0, "max_hp": 16.0,
		"movement_points": 3.0, "vision_range": 1, "gold_reward": 70.0, "clear_reward": 130.0,
		"flies": true, "visual_kind": "wyvern",
	},
	"skeleton": {
		"biomes": [HexTileData.TerrainType.DESERT, HexTileData.TerrainType.TUNDRA],
		"weight": 25, "min_threat": 0.15, "lair_cap": 4, "batch_spawn": 3,
		"behavior": BEHAVIOR_INVADER, "invader_promotable": false,
		"unit_name": "Esqueleto", "attack": 4.0, "defense": 1.0, "max_hp": 6.0,
		"movement_points": 2.0, "vision_range": 1, "gold_reward": 10.0, "clear_reward": 85.0,
		"flies": false, "visual_kind": "skeleton",
	},
	"dragon": {
		"biomes": [HexTileData.TerrainType.LAVA],
		"weight": 5, "min_threat": 0.85, "lair_cap": 1, "batch_spawn": 1,
		"behavior": BEHAVIOR_HUNTER, "invader_promotable": false,
		"unit_name": "Dragao", "attack": 16.0, "defense": 8.0, "max_hp": 50.0,
		"movement_points": 2.0, "vision_range": 2, "gold_reward": 200.0, "clear_reward": 150.0,
		"flies": true, "visual_kind": "dragon",
	},
}
const KINDS := ["goblin", "troll", "wyvern", "skeleton", "dragon"] # ordem fixa (nao KIND_DATA.keys(), ver nota abaixo), usada por WEIGHTS-like iteracao e testes que esperam ordem estavel

## O ocupante ORIGINAL de um covil (spawnado por HexGrid._spawn_monster_
## lairs) multiplica HP/ataque em cima da tabela — le como um "chefao" de
## verdade guardando o proprio covil, nao so mais um reforco igual aos que
## nascem depois. Ver create_monster(is_camp_boss).
const CAMP_BOSS_HP_MULTIPLIER := 2.5
const CAMP_BOSS_ATTACK_MULTIPLIER := 1.3

## `is_camp_boss` distingue o ocupante ORIGINAL de um covil (sempre
## chamado assim por HexGrid._spawn_monster_lairs) de um reforco/patrulha
## comum (todo o resto, default false): o boss NUNCA se move
## (movement_points = 0, preserva o comportamento historico de "guardiao
## nunca sai do proprio tile" — ver test_create_monster_camp_boss_never_
## moves) e vem com HP/ataque multiplicados (CAMP_BOSS_HP_MULTIPLIER/
## CAMP_BOSS_ATTACK_MULTIPLIER). Um reforco comum usa movement_points de
## verdade da tabela — "ficar parado perto do covil" agora e uma ESCOLHA
## de IA (MonsterAI, comportamento Guardiao), nao mais uma trava de stat.
static func create_monster(kind: String, is_camp_boss: bool = false) -> UnitData:
	var info: Dictionary = KIND_DATA.get(kind, KIND_DATA["goblin"])
	var data := UnitData.new()
	data.unit_name = info.unit_name
	data.attack = info.attack * (CAMP_BOSS_ATTACK_MULTIPLIER if is_camp_boss else 1.0)
	data.defense = info.defense
	data.max_hp = info.max_hp * (CAMP_BOSS_HP_MULTIPLIER if is_camp_boss else 1.0)
	data.vision_range = info.vision_range
	data.visual_kind = info.visual_kind
	data.gold_reward = info.gold_reward
	data.flies = info.flies
	data.movement_points = 0.0 if is_camp_boss else info.movement_points
	return data

## Ouro pago por destruir o covil ABANDONADO (ver HexGrid.destroy_lair/
## _grant_lair_clear_reward) — kind desconhecido cai no valor do Goblin,
## mesmo fallback de create_monster acima.
static func lair_clear_reward(kind: String) -> float:
	return KIND_DATA.get(kind, KIND_DATA["goblin"]).get("clear_reward", 75.0)

## Sorteio ponderado deterministico — `rng` ja vem semeado pelo chamador
## (HexGrid._spawn_monster_lairs usa map_seed), entao o resultado e 100%
## reproduzivel pra mesma semente de mapa. `threat_level` (default 1.0 =
## "sem restricao de ameaca") filtra tipos cujo KIND_MIN_THREAT nao foi
## atingido; `terrain_type` (default -1 = "sem filtro de bioma", nunca um
## HexTileData.TerrainType valido de verdade, todos sao >= 0) filtra tipos
## cujo bioma nao inclui esse terreno. Os dois filtros se somam (E logico);
## se ninguem sobra, cai pro filtro so-por-ameaca (compat com chamadas
## antigas sem bioma); se AINDA ninguem sobra (bioma existe mas nenhum tipo
## elegivel por ameaca bate ali), cai pro mais fraco (KINDS[0], goblin).
static func random_kind(rng: RandomNumberGenerator, threat_level: float = 1.0, terrain_type: int = -1) -> String:
	var eligible := _eligible_kinds(threat_level, terrain_type)
	if eligible.is_empty():
		eligible = _eligible_kinds(threat_level, -1) # cai pro filtro so-por-ameaca (ignora bioma)
	if eligible.is_empty():
		eligible = [KINDS[0]] # sempre sobra pelo menos o mais fraco (min_threat 0.0, sem restricao de bioma)

	var total := 0
	for k in eligible:
		total += KIND_DATA[k].weight
	var roll = rng.randi_range(0, total - 1)
	var acc := 0
	for k in eligible:
		acc += KIND_DATA[k].weight
		if roll < acc:
			return k
	return eligible[0]

static func _eligible_kinds(threat_level: float, terrain_type: int) -> Array:
	var eligible: Array = []
	for k in KINDS:
		var info: Dictionary = KIND_DATA[k]
		if threat_level < info.min_threat:
			continue
		if terrain_type != -1 and not (terrain_type in info.biomes):
			continue
		eligible.append(k)
	return eligible
