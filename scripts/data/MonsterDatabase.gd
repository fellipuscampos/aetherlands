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

const BEHAVIOR_GUARDIAN := "guardian" # fica no territorio do covil (raio configuravel, ver guard_radius/MonsterAI.GUARD_RADIUS), so briga com quem invade -- OU com cidade inimiga que se aproximar o bastante (ver MonsterAI._take_guardian_turn)
const BEHAVIOR_INVADER := "invader" # marcha sobre a cidade inimiga mais proxima do mapa INTEIRO, brigando com quem encontrar no caminho (ver MonsterAI._take_invader_turn)
const BEHAVIOR_HUNTER := "hunter" # patrulha uma area larga cacando presa isolada/fraca, so ataca se favoravel (ver MonsterAI._take_hunter_turn)
## COMPORTAMENTO DOS MONSTROS (pedido do usuario: "muitos monstros parecem
## extremamente passivos... quero uma revisao... cada tipo pode possuir
## comportamento proprio... goblins podem ser agressivos e oportunistas:
## saquear; atacar unidades fracas; ameacar melhorias; aproximar-se de
## cidades proximas"). Guardiao (radio pequeno, so reage a quem entra) era
## PASSIVO DEMAIS pro Goblin default -- Saqueador busca ATIVAMENTE presa
## fraca/isolada dentro de um raio MAIOR que o Guardiao mas ainda preso ao
## territorio do proprio covil (nunca atravessa o mapa como o Invasor);
## sem presa a vista, se aproxima da cidade mais proxima DENTRO do raio
## (pra ameacar os arredores/saquear, nunca pra capturar) e ainda saqueia
## tile trabalhado normalmente (mesma _maybe_pillage_tile do Invasor). Ver
## MonsterAI._take_raider_turn/RAIDER_RADIUS.
const BEHAVIOR_RAIDER := "raider"

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
## - global_cap: populacao maxima viva desse tipo em QUALQUER LUGAR do
##   mapa, somando TODOS os covis (ver HexGrid._count_alive_of_kind/
##   _global_cap_for) — pedido do usuario: "ponha um limite no spawn de
##   monstros... cada um so pode ter 5 vivos por vez, no caso dos vivern 2
##   vivos de uma vez e no dragao apenas 1". Independente de lair_cap: um
##   mapa grande pode ter VARIOS covis do mesmo tipo, cada um enchendo ate
##   o proprio lair_cap — sem este segundo teto, o total global do tipo
##   nao teria limite nenhum (ex: 3 covis de Vivern, lair_cap 2 cada,
##   dariam 6 Viverns vivos ao mesmo tempo sem essa checagem extra).
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
## - clear_reward: ouro concedido por DESTRUIR o covil abandonado (atacar
##   a LairStructure ate zerar o HP dela, ver CombatResolver.
##   resolve_lair_attack/HexGrid._grant_lair_clear_reward) — recompensa
##   maior e de uma vez so, diferente de gold_reward (que paga por matar
##   CADA monstro individual em combate).
## - clear_reward_mana: MESMO evento (destruir a estrutura), mas em Mana
##   em vez de ouro — pedido do usuario (RECOMPENSAS DE COVIS: "ouro;
##   recurso; mana; experiencia; combinacao; recompensa especifica por
##   tipo... escolha recompensas coerentes com os sistemas atuais").
##   0.0 (goblin/troll: bandido comum/brutamontes, sem ligacao arcana
##   nenhuma) pros tipos "mundanos"; so' os tipos com identidade
##   tematica arcana ja estabelecida ganham Mana — Esqueleto (morto-vivo,
##   residuo de necromancia) modesto, Vivern/Dragao (guardioes dos
##   continentes Vulcanico/de Cristal, ver comentario de biomes do Vivern
##   abaixo) o suficiente pra valer um feitico (SpellDatabase: feiticos
##   custam 25-60 de Mana). Sistema de Mana ja existe (PlayerData.mana,
##   gasto em feiticos) — reusado direto, sem inventar um "banco de
##   recurso" novo so' pra covil (Ferro/Gemas/Seda/Cavalos so existem como
##   YIELD de tile trabalhado, nao tem estoque nenhum pra depositar).
const KIND_DATA := {
	"goblin": {
		"biomes": [HexTileData.TerrainType.FOREST, HexTileData.TerrainType.PLAINS, HexTileData.TerrainType.GRASSLAND],
		"weight": 60, "min_threat": 0.0, "lair_cap": 4, "global_cap": 5, "batch_spawn": 1,
		# COMPORTAMENTO DOS MONSTROS: Saqueador (nao mais Guardiao) e' o
		# default -- Goblin sozinho/em duplas incomoda ativamente os
		# arredores do proprio covil; ao atingir INVADER_GROUP_THRESHOLD
		# ociosos, o bando inteiro ainda e promovido a Invasor de verdade
		# (invader_promotable, inalterado), virando uma invasao real.
		"behavior": BEHAVIOR_RAIDER, "invader_promotable": true,
		"unit_name": "Goblin", "attack": 3.0, "defense": 2.0, "max_hp": 8.0,
		"movement_points": 1.0, "vision_range": 1, "gold_reward": 15.0, "clear_reward": 75.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "goblin",
	},
	"troll": {
		"biomes": [HexTileData.TerrainType.MOUNTAINS, HexTileData.TerrainType.TAIGA, HexTileData.TerrainType.TUNDRA],
		"weight": 30, "min_threat": 0.3, "lair_cap": 2, "global_cap": 5, "batch_spawn": 1,
		# COMPORTAMENTO DOS MONSTROS (pedido do usuario: "trolls podem
		# defender uma regiao maior... nao precisam atravessar meio
		# continente... mas se uma cidade, unidade ou territorio estiver
		# suficientemente proximo, podem reagir"): continua Guardiao (nunca
		# sai do proprio territorio, ataque incondicional), so' com raio
		# MAIOR que o padrao (MonsterAI.GUARD_RADIUS=2) -- "guard_radius"
		# e' lido por MonsterAI._guard_radius_for, ausente pra qualquer
		# outro kind cai no padrao.
		"behavior": BEHAVIOR_GUARDIAN, "guard_radius": 5, "invader_promotable": false,
		"unit_name": "Troll", "attack": 6.0, "defense": 4.0, "max_hp": 20.0,
		"movement_points": 1.0, "vision_range": 1, "gold_reward": 35.0, "clear_reward": 100.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "troll",
	},
	"wyvern": {
		# Microbiomas dos continentes Vulcanico/de Cristal (VOLCANIC_ROCK/
		# PEAKS/ASH, CRYSTAL_PEAKS, MYSTIC_SOIL/SPRING) somados aqui —
		# sem isso, _spawn_monster_lairs (nao escopado por zona) cairia no
		# fallback "ignora bioma" de MonsterDatabase.random_kind pra
		# qualquer tile desses tipos novos, deixando Goblin/Troll/Esqueleto
		# nascerem nos continentes especiais e quebrando a identidade
		# tematica estrita pedida pelo usuario. Vivern vira "guardiao de
		# todo o continente especial", extensao natural do que ja cobria
		# (Lava/Mar de Lava/Cristal).
		"biomes": [
			HexTileData.TerrainType.LAVA, HexTileData.TerrainType.LAVA_SEA, HexTileData.TerrainType.CRYSTAL,
			HexTileData.TerrainType.VOLCANIC_ROCK, HexTileData.TerrainType.VOLCANIC_HILLS, HexTileData.TerrainType.VOLCANIC_PEAKS, HexTileData.TerrainType.VOLCANIC_ASH,
			HexTileData.TerrainType.CRYSTAL_PEAKS, HexTileData.TerrainType.MYSTIC_SOIL, HexTileData.TerrainType.MYSTIC_SPRING,
		],
		"weight": 10, "min_threat": 0.65, "lair_cap": 2, "global_cap": 2, "batch_spawn": 1,
		"behavior": BEHAVIOR_HUNTER, "invader_promotable": false,
		"unit_name": "Vivern", "attack": 8.0, "defense": 3.0, "max_hp": 16.0,
		"movement_points": 3.0, "vision_range": 1, "gold_reward": 70.0, "clear_reward": 130.0, "clear_reward_mana": 20.0,
		"flies": true, "visual_kind": "wyvern",
	},
	"skeleton": {
		"biomes": [HexTileData.TerrainType.DESERT, HexTileData.TerrainType.TUNDRA],
		"weight": 25, "min_threat": 0.15, "lair_cap": 4, "global_cap": 5, "batch_spawn": 3,
		"behavior": BEHAVIOR_INVADER, "invader_promotable": false,
		"unit_name": "Esqueleto", "attack": 4.0, "defense": 1.0, "max_hp": 6.0,
		"movement_points": 2.0, "vision_range": 1, "gold_reward": 10.0, "clear_reward": 85.0, "clear_reward_mana": 10.0,
		"flies": false, "visual_kind": "skeleton",
	},
	"dragon": {
		"biomes": [HexTileData.TerrainType.LAVA],
		"weight": 5, "min_threat": 0.85, "lair_cap": 1, "global_cap": 1, "batch_spawn": 1,
		"behavior": BEHAVIOR_HUNTER, "invader_promotable": false,
		"unit_name": "Dragao", "attack": 16.0, "defense": 8.0, "max_hp": 50.0,
		"movement_points": 2.0, "vision_range": 2, "gold_reward": 200.0, "clear_reward": 150.0, "clear_reward_mana": 35.0,
		"flies": true, "visual_kind": "dragon",
	},
	# ------------------------------------------------------------------
	# V3 / Combat Ecology — Etapa 1: espécies NOVAS do bestiário ecológico (tier em MonsterEcologyData).
	# V3 COMBAT ECOLOGY PLACEHOLDER — TUNE LATER: stats só funcionais (spawnar, mover, atacar, defender,
	# morrer), em bandas coerentes com o conteúdo existente — BASIC ≈ Goblin/Esqueleto, INTERMEDIATE ≈
	# Troll/Vivern, ADVANCED claramente acima e ainda abaixo do Dragão. Nenhuma habilidade (Etapas 2–4).
	# Fora de KINDS de propósito: nunca são sorteadas pelos covis da seed (random_kind); só a ecologia as
	# cria. biomes/weight/min_threat/caps existem só para leitores genéricos de KIND_DATA.
	"worg": {
		"biomes": [], "weight": 0, "min_threat": 1.0, "lair_cap": 2, "global_cap": 5, "batch_spawn": 1,
		"behavior": BEHAVIOR_GUARDIAN, "invader_promotable": false,
		"unit_name": "Worg", "attack": 4.0, "defense": 1.5, "max_hp": 8.0,
		"movement_points": 3.0, "vision_range": 1, "gold_reward": 15.0, "clear_reward": 75.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "worg",
	},
	"giant_spider": {
		"biomes": [], "weight": 0, "min_threat": 1.0, "lair_cap": 2, "global_cap": 5, "batch_spawn": 1,
		"behavior": BEHAVIOR_GUARDIAN, "invader_promotable": false,
		"unit_name": "Aranha Gigante", "attack": 3.5, "defense": 2.0, "max_hp": 9.0,
		"movement_points": 2.0, "vision_range": 1, "gold_reward": 15.0, "clear_reward": 75.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "giant_spider",
	},
	"minotaur": {
		"biomes": [], "weight": 0, "min_threat": 1.0, "lair_cap": 1, "global_cap": 5, "batch_spawn": 1,
		"behavior": BEHAVIOR_GUARDIAN, "invader_promotable": false,
		"unit_name": "Minotauro", "attack": 7.0, "defense": 3.5, "max_hp": 20.0,
		"movement_points": 2.0, "vision_range": 1, "gold_reward": 40.0, "clear_reward": 100.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "minotaur",
	},
	"basilisk": {
		"biomes": [], "weight": 0, "min_threat": 1.0, "lair_cap": 1, "global_cap": 5, "batch_spawn": 1,
		"behavior": BEHAVIOR_GUARDIAN, "invader_promotable": false,
		"unit_name": "Basilisco", "attack": 6.0, "defense": 5.0, "max_hp": 18.0,
		"movement_points": 1.0, "vision_range": 1, "gold_reward": 40.0, "clear_reward": 100.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "basilisk",
	},
	"colossal_worm": {
		"biomes": [], "weight": 0, "min_threat": 1.0, "lair_cap": 1, "global_cap": 5, "batch_spawn": 1,
		"behavior": BEHAVIOR_GUARDIAN, "invader_promotable": false,
		"unit_name": "Verme Colossal", "attack": 11.0, "defense": 5.0, "max_hp": 32.0,
		"movement_points": 2.0, "vision_range": 1, "gold_reward": 90.0, "clear_reward": 150.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "colossal_worm",
	},
	"arboreal_ancient": {
		"biomes": [], "weight": 0, "min_threat": 1.0, "lair_cap": 1, "global_cap": 5, "batch_spawn": 1,
		"behavior": BEHAVIOR_GUARDIAN, "invader_promotable": false,
		"unit_name": "Ancião Arbóreo", "attack": 9.0, "defense": 7.0, "max_hp": 36.0,
		"movement_points": 1.0, "vision_range": 1, "gold_reward": 90.0, "clear_reward": 150.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "arboreal_ancient",
	},
	"mana_devourer": {
		"biomes": [], "weight": 0, "min_threat": 1.0, "lair_cap": 1, "global_cap": 5, "batch_spawn": 1,
		"behavior": BEHAVIOR_GUARDIAN, "invader_promotable": false,
		"unit_name": "Devorador de Mana", "attack": 12.0, "defense": 4.0, "max_hp": 28.0,
		"movement_points": 2.0, "vision_range": 1, "gold_reward": 90.0, "clear_reward": 150.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "mana_devourer",
	},
	# Herói Corrompido — substitui PROVISORIAMENTE a Colmeia Micótica (2026-10-04): mesmo ataque/defesa/vida da
	# Colmeia; movimento 2 como os outros ADVANCED móveis (a Colmeia era estrutura quase imóvel). Sem habilidade
	# própria por enquanto: comportamento ADVANCED padrão (MonsterActivityProfile). Saves antigos: LEGACY_KINDS.
	"corrupted_hero": {
		"biomes": [], "weight": 0, "min_threat": 1.0, "lair_cap": 1, "global_cap": 5, "batch_spawn": 1,
		"behavior": BEHAVIOR_GUARDIAN, "invader_promotable": false,
		"unit_name": "Herói Corrompido", "attack": 8.0, "defense": 6.0, "max_hp": 34.0,
		"movement_points": 2.0, "vision_range": 1, "gold_reward": 80.0, "clear_reward": 150.0, "clear_reward_mana": 0.0,
		"flies": false, "visual_kind": "corrupted_hero",
	},
}

## Espécies retiradas -> substituta (saves antigos e chamadas legadas). A Colmeia Micótica saiu do jogo e virou o
## Herói Corrompido; um save com "mycotic_hive" carrega o Herói no lugar (nunca cai no fallback de Goblin).
const LEGACY_KINDS := {"mycotic_hive": "corrupted_hero"}

static func canonical_kind(kind: String) -> String:
	return String(LEGACY_KINDS.get(kind, kind))
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
## Crossfade (s) entre Idle/Walk/Attack dos monstros com modelo feito a
## mao no Blender (Goblin/Troll V3 e os V1 de HANDMADE_MODELS/Esqueleto)
## -- ver UnitData.animation_blend_time. Menor que
## Unit.MOVE_DURATION (0.35s por tile) pra o passo ja estar "andando" antes
## do fim do primeiro trecho.
const V3_ANIMATION_BLEND_TIME := 0.2

const SKELETON_V1_MODEL := "res://assets/generated/skeletons/skeleton_warrior_v1/skeleton_warrior_v1.glb"

## Especies do bestiario ecologico com modelo final: kind -> GLB + prefixo
## dos clipes (<prefix>_Idle/_Walk/_Attack). Ver o ramo HANDMADE_MODELS em
## create_monster().
const HANDMADE_MODELS := {
	"worg": {"path": "res://assets/generated/wargs/warg_v1/warg_v1.glb", "prefix": "Warg"},
	"minotaur": {"path": "res://assets/generated/minotaurs/minotaur_blocky_v1/minotaur_blocky_v1.glb", "prefix": "Minotaur"},
	"basilisk": {"path": "res://assets/generated/basilisks/basilisk_blocky_v1/basilisk_blocky_v1.glb", "prefix": "Basilisk"},
	# Wyvern: substitui a capsula+asas procedural de Unit._build_procedural_body (pousado; sem clipe de voo).
	"wyvern": {"path": "res://assets/generated/wyverns/wyvern_blocky_v1/wyvern_blocky_v1.glb", "prefix": "Wyvern"},
	# Aranha: GLB re-exportado do .blend animado por tools/art_pipeline/spider_export.py.
	"giant_spider": {"path": "res://assets/generated/spiders/giant_spider_v1/giant_spider_v1.glb", "prefix": "Spider"},
	# Devorador: flutua -- a altura de flutuacao ja esta na geometria (origem no chao).
	"mana_devourer": {"path": "res://assets/generated/mana_devourers/mana_devourer_v1/mana_devourer_v1.glb", "prefix": "ManaDevourer"},
	# Verme Colossal: verme-lacraia de areia, em pe (J) perto de 1 tile. Sem Walk (anda no Idle); Escavar toca
	# Worm_Burrow/Worm_Emerge ("burrow": true, ver Unit.play_burrow_visual/play_emerge_visual).
	"colossal_worm": {"path": "res://assets/generated/sand_worms/sand_worm_v1/sand_worm_v1.glb", "prefix": "Worm", "burrow": true},
	# Anciao Arboreo: golem de pedra/raiz que anda como gorila (Ancient Golem V2).
	"arboreal_ancient": {"path": "res://assets/generated/ancient_golems/ancient_golem_v2/ancient_golem_v2.glb", "prefix": "Golem"},
	# Herói Corrompido: cavaleiro velho e cansado, maça de ferro + escudo-torre (substitui a Colmeia).
	"corrupted_hero": {"path": "res://assets/generated/corrupted_heroes/corrupted_hero_v1/corrupted_hero_v1.glb", "prefix": "Hero", "block": true},
}

static func create_monster(kind: String, is_camp_boss: bool = false) -> UnitData:
	kind = canonical_kind(kind)
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
	# Identidade visual: segundo teste da 3D Asset Factory numa especie
	# NAO-humana (depois do Goblin) -- mesmo esqueleto/rig de 18 ossos,
	# HumanStyle magro/oco (slim_build+thin_arms, orbitas ocas via
	# body_blocky.build_head_parts eye_style="hollow", ver style/textures.
	# build_head_face_image), pele tom osso (MaterialLibrary.skin_color_
	# override). Substitui o modelo KayKit (Skeleton_Warrior.glb, CC0) que
	# era usado antes — Troll/Wyvern/Dragao continuam sem modelo
	# procedural equivalente por ora. Preset: presets/skeleton_blocky.json.
	if kind == "skeleton":
		# V1 feito a mao (2026-10): Esqueleto guerreiro do Blender (README em
		# assets/generated/skeletons/skeleton_warrior_v1), 1.85m com elmo,
		# rig proprio de 23 ossos. O skeleton_blocky antigo continua no disco,
		# so nao e mais referenciado (nem pelas Hostes, ver UnitDatabase.
		# _apply_skeleton_formation, que usa o MESMO modelo).
		data.model_scene_path = SKELETON_V1_MODEL
		data.animation_scene_path = SKELETON_V1_MODEL
		data.merge_shared_walk_animation = false
		data.idle_animation_override = "Skeleton_Idle"
		data.walk_animation_override = "Skeleton_Walk"
		data.attack_animation_override = "Skeleton_Attack"
		data.animation_blend_time = V3_ANIMATION_BLEND_TIME
		# Escala 1:1 direta agora (ver Unit.gd _build_model_body's
		# ASSET_FACTORY_PATH_PREFIX check): modelos da 3D Asset Factory
		# nao passam mais pela normalizacao MODEL_TARGET_HEIGHT/aabb.
		# size.y, entao model_scale_multiplier volta a ser 1.0 -- a
		# altura final agora e literalmente a altura "1.75" do preset
		# JSON, na mesma unidade do resto do jogo, sem nenhuma conta.
		#
		# Isso resolve, na raiz, uma saga inteira de tentativas de
		# calibrar esse numero: a normalizacao por aabb.size.y (formula
		# antiga) e algebricamente garantida a dar sempre MODEL_TARGET_
		# HEIGHT*mult, independente do aabb -- confirmado medindo de
		# varias formas (aabb local, global_transform.basis.get_scale(),
		# aabb em espaco de mundo) -- mas o Esqueleto renderizava ~1.28x
		# mais alto que essa formula previa no jogo de verdade, sem causa
		# raiz encontrada (nao era timing de animacao nem swing de braco
		# no Idle). O usuario perguntou "o caminho correto nao seria
		# deixar eles apenas com o tamanho do modelo 3d deles?" -- sim, e
		# eliminar a normalizacao (nao so recalibrar o multiplicador em
		# cima dela) e a correcao de verdade.
		data.model_scale_multiplier = 1.0
		data.model_yaw_offset_degrees = 0.0 # V1: frente ja em +Z, ver nota no goblin abaixo
	elif kind == "goblin":
		# Identidade visual: primeiro teste da 3D Asset Factory (tools/
		# asset_factory) numa especie NAO-humana — mesmo esqueleto/rig de
		# 18 ossos do Guarda/Colonizador, mas HumanStyle com proporcoes bem
		# diferentes (baixinho, cabeca enorme, magro) + pele/cabelo verdes
		# (MaterialLibrary.skin_color_override/hair_color_override, ver
		# tools/asset_factory/style/palette.py) + orelhas pontudas (style.
		# pointy_ears, ver body_blocky.build_head_parts) em vez de reusar a
		# cor de pele humana fixa. Preset: presets/goblin_blocky.json.
		# V3 (2026-10): substituido pelo Goblin saqueador feito a mao no
		# Blender (art_source/goblin_raider_v3, README em assets/generated/
		# goblins/goblin_raider_v3) -- rig proprio de 22 ossos, clipes
		# Goblin_Idle/Goblin_Walk/Goblin_Attack. GLB exportado por tools/
		# art_pipeline/goblin_raider_export.py. O goblin_blocky antigo da
		# Asset Factory continua no disco, so nao e mais referenciado.
		data.model_scene_path = "res://assets/generated/goblins/goblin_raider_v3/goblin_raider_v3.glb"
		data.animation_scene_path = "res://assets/generated/goblins/goblin_raider_v3/goblin_raider_v3.glb"
		data.merge_shared_walk_animation = false
		data.idle_animation_override = "Goblin_Idle"
		data.walk_animation_override = "Goblin_Walk"
		data.attack_animation_override = "Goblin_Attack"
		# Pedido do usuario: "andar nao comeca instantaneamente, os ossos tem
		# que ir de idle pra andando" -- os 3 clipes animam o mesmo conjunto
		# de ossos (conferido no import), entao o crossfade e limpo.
		data.animation_blend_time = V3_ANIMATION_BLEND_TIME
		# NAO é a mesma escala do Guarda/Colonizador -- um goblin TEM que
		# parecer mais baixo que um humano. Ver comentario do Colonizador
		# acima sobre por que o multiplicador nao pode ser copiado entre
		# personagens. "Deixe o goblin mais ou menos na altura da barriga
		# quase chegando no peito" (do Guarda) -- medido em compute_
		# measurements do proprio Guarda: z_spine_top (topo da barriga)
		# fica a 68.1% da altura total dele, z_chest_top a 85.5% -- "quase
		# chegando no peito" mira por volta de 80%.
		# Escala 1:1 direta agora (ver comentario longo do Esqueleto
		# acima e Unit.gd _build_model_body's ASSET_FACTORY_PATH_PREFIX
		# check) -- sem normalizacao por aabb, model_scale_multiplier
		# volta a 1.0. A altura final passa a ser literalmente o "height"
		# do preset (1.3m vs 1.8m do Guarda, ~72% -- perto do "quase
		# chegando no peito" pedido, sem precisar calcular multiplicador
		# nenhum). Se a proporcao ainda nao ficar certa, o ajuste agora e
		# no proprio preset (tools/asset_factory/presets/goblin_blocky.
		# json "height"), nao aqui.
		data.model_scale_multiplier = 1.0
		# V3: frente ja sai em +Z no glTF (-Y no Blender), a mesma convencao
		# de slide_to() -- sem o giro de 180 graus da Asset Factory antiga.
		data.model_yaw_offset_degrees = 0.0
	elif kind == "troll":
		# Identidade visual: terceiro teste da 3D Asset Factory numa
		# especie NAO-humana (depois do Goblin e do Esqueleto) -- mesmo
		# esqueleto/rig de 18 ossos, mas HumanStyle grande (sem slim_build/
		# thin_arms -- o "built" default, mais limb_slenderness 1.15 pra
		# ficar um pouco mais volumoso, SEM exagero -- ver nota abaixo) +
		# pele azul-acinzentada escura, olhos amarelos "slit", definicao de
		# musculo real (equipment.muscles, ver body_blocky.py) + tanga de
		# couro (pelvis_material="leather") + um porrete de log com
		# espinhos CURTOS (weapon="troll_club", ver equipment_blocky.
		# build_troll_club_parts) -- pedido do usuario com imagem de
		# referencia (um troll estilo Minecraft). Preset: presets/
		# troll_blocky.json.
		# V3 (2026-10): substituido pelo Troll refinado no Blender (art_source/
		# troll_blocky_v3, README em assets/generated/trolls/troll_blocky_v3)
		# -- rig proprio de 24 ossos, clipes Troll_Idle/Troll_Walk/
		# Troll_Attack, mesma altura de 2.5m. O troll_blocky antigo da Asset
		# Factory continua no disco, so nao e mais referenciado.
		data.model_scene_path = "res://assets/generated/trolls/troll_blocky_v3/troll_blocky_v3.glb"
		data.animation_scene_path = "res://assets/generated/trolls/troll_blocky_v3/troll_blocky_v3.glb"
		data.merge_shared_walk_animation = false
		data.idle_animation_override = "Troll_Idle"
		data.walk_animation_override = "Troll_Walk"
		data.attack_animation_override = "Troll_Attack"
		data.animation_blend_time = V3_ANIMATION_BLEND_TIME # ver nota no goblin acima
		# "pode ter 2x o tamanho de uma pessoa" (usuario) -- o que fazia
		# ele parecer MUITO maior que qualquer altura pedida nao era a
		# altura em si: ombros largos (shoulder_width_ratio 0.34 -> 0.27),
		# limb_slenderness exagerado (1.35 -> 1.15) e principalmente os
		# espinhos do porrete esticando bem pra LADOS (spike_len ~1.3x a
		# largura da cabeca do porrete -> 0.55x).
		# Escala 1:1 direta agora (ver comentario longo do Esqueleto acima
		# e Unit.gd _build_model_body ASSET_FACTORY_PATH_PREFIX check) --
		# model_scale_multiplier volta a 1.0, altura final = "height" do
		# preset. Redimensionado no editor Blender pra 2.5m (~1.4x o
		# Guarda de 1.8m) -- ajustar altura agora e so no proprio preset
		# (troll_blocky.json "height" + resalvar/reexportar), nao aqui.
		data.model_scale_multiplier = 1.0
		data.model_yaw_offset_degrees = 0.0 # V3: ver nota no goblin acima
	elif HANDMADE_MODELS.has(kind):
		# V1 feitos a mao no Blender (2026-10) -- substituem as silhuetas
		# provisorias de MonsterPlaceholderVisuals (que segue valendo pras
		# especies ainda sem modelo). Mesma receita do Goblin/Troll V3: escala
		# 1:1, frente em +Z (yaw 0), clipes com prefixo e crossfade (os 3
		# clipes de cada um animam o mesmo conjunto de ossos, conferido no
		# import). READMEs em assets/generated/<especie>/<nome>_v1.
		var model: Dictionary = HANDMADE_MODELS[kind]
		data.model_scene_path = model.path
		data.animation_scene_path = model.path
		data.merge_shared_walk_animation = false
		data.idle_animation_override = model.prefix + "_Idle"
		data.walk_animation_override = model.prefix + "_Walk"
		data.attack_animation_override = model.prefix + "_Attack"
		if model.get("burrow", false):
			data.burrow_animation_override = model.prefix + "_Burrow"
			data.emerge_animation_override = model.prefix + "_Emerge"
		if model.get("block", false):
			data.block_animation_override = model.prefix + "_Block"
		data.animation_blend_time = V3_ANIMATION_BLEND_TIME
		data.model_scale_multiplier = 1.0
		data.model_yaw_offset_degrees = 0.0
	return data

## Ouro pago por destruir o covil ABANDONADO (ver HexGrid.destroy_lair/
## _grant_lair_clear_reward) — kind desconhecido cai no valor do Goblin,
## mesmo fallback de create_monster acima.
static func lair_clear_reward(kind: String) -> float:
	return KIND_DATA.get(kind, KIND_DATA["goblin"]).get("clear_reward", 75.0)

## RECOMPENSAS DE COVIS: Mana paga pelo MESMO evento acima (ver comentario
## de clear_reward_mana no topo do arquivo) -- 0.0 pra kind desconhecido ou
## sem identidade arcana (goblin/troll), nunca negativo.
static func lair_clear_mana_reward(kind: String) -> float:
	return KIND_DATA.get(kind, {}).get("clear_reward_mana", 0.0)

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

## Como random_kind, mas restrito a tipos com flies=true — usado SO pra
## covis nascendo em tile de Lava/Mar de Lava (HexGrid._spawn_monster_
## lairs), onde um tipo terrestre ficaria fisicamente preso pra sempre
## (LAVA/LAVA_SEA bloqueiam unidade terrestre, ver HexTileData.
## blocks_land_units). Cai pro tipo voador mais fraco elegivel pro bioma
## (ignorando ameaca) se nenhum bater min_threat — NUNCA cai pro fallback
## biome-agnostico de random_kind (que poderia devolver um tipo
## terrestre); devolve "" (nao KINDS[0]) se mesmo assim nada servir, pro
## chamador pular esse candidato em vez de forcar um monstro que nao pode
## existir ali.
static func random_flying_kind(rng: RandomNumberGenerator, threat_level: float, terrain_type: int) -> String:
	var eligible: Array = _eligible_kinds(threat_level, terrain_type).filter(func(k): return KIND_DATA[k].flies)
	if eligible.is_empty():
		eligible = _eligible_kinds(0.0, terrain_type).filter(func(k): return KIND_DATA[k].flies)
	if eligible.is_empty():
		return ""

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
